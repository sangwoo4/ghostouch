package com.pentagon.ghostouch

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.FileWriter
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class TrainingCoordinator(private val context: Context, private val listener: TrainingListener?) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
    private var pollingExecutor: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private var pollingFuture: ScheduledFuture<*>? = null

    private val baseUrl: String

    init {
        val appInfo = context.packageManager.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA
        )
        val serverIp = appInfo.metaData.getString("com.pentagon.ghostouch.SERVER_IP")
        val serverPort = appInfo.metaData.getInt("com.pentagon.ghostouch.SERVER_PORT")

        if (serverIp == null || serverPort == 0) {
            Log.e(TAG, "Server IP or Port not found in AndroidManifest.xml metadata.")
            baseUrl = "http://localhost:8000" // Fallback or error handling
        } else {
            baseUrl = "http://$serverIp:$serverPort"
            Log.d(TAG, "Server URL from manifest: $baseUrl")
        }
    }

    interface TrainingListener {
        fun onModelReady()
    }

    companion object {
        private const val TAG = "TrainingCoordinator"
        const val CUSTOM_MODEL_NAME = "custom_model.tflite"
        const val LABEL_MAP_FILE_NAME = "updated_label_map.json"
    }

    fun uploadAndTrain(gestureName: String, frames: List<List<Float>>) {
        Log.d(TAG, "Preparing to upload ${frames.size} frames for gesture: $gestureName")

        if (frames.size < 100) {
            Log.w(TAG, "Not enough frames collected to start training. Required: 100, Found: ${frames.size}")
            return
        }

        val jsonPayload = JSONObject()
        jsonPayload.put("model_code", "base_v1")
        jsonPayload.put("gesture", gestureName)
        
        val landmarksJsonArray = JSONArray()
        for (frame in frames) {
            val frameJsonArray = JSONArray()
            for (value in frame) {
                frameJsonArray.put(value.toDouble())
            }
            landmarksJsonArray.put(frameJsonArray)
        }
        jsonPayload.put("landmarks", landmarksJsonArray)

        val requestBody = jsonPayload.toString().toRequestBody("application/json; charset=utf-8".toMediaType())

        val request = Request.Builder()
            .url("$baseUrl/train")
            .post(requestBody)
            .build()

        Log.d(TAG, "Sending training request to $baseUrl/train")

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Training request failed", e)
            }

            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    Log.e(TAG, "Server returned an error on /train: ${response.code} ${response.message}")
                    return
                }

                val responseBody = response.body?.string()
                if (responseBody != null) {
                    try {
                        val jsonResponse = JSONObject(responseBody)
                        val taskId = jsonResponse.optString("task_id", null)
                        if (taskId != null) {
                            Log.d(TAG, "Training task started successfully. Task ID: $taskId")
                            startPolling(taskId, gestureName)
                        } else {
                            Log.e(TAG, "Could not find 'task_id' in the server response.")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse /train response", e)
                    }
                }
            }
        })
    }

    private fun startPolling(taskId: String, gestureName: String) {
        // Ensure we have a fresh executor for polling
        if (pollingExecutor.isShutdown || pollingExecutor.isTerminated) {
            Log.w(TAG, "PollingExecutor was shutdown, creating new one...")
            pollingExecutor = Executors.newSingleThreadScheduledExecutor()
        }
        
        Log.d(TAG, "Starting polling for task $taskId with 2 second interval")
        
        try {
            pollingFuture = pollingExecutor.scheduleAtFixedRate({ 
                Log.d(TAG, "Polling attempt for task $taskId...")
                try {
                    val request = Request.Builder()
                        .url("$baseUrl/status/$taskId")
                        .get()
                        .build()

                    Log.d(TAG, "Making HTTP request to: $baseUrl/status/$taskId")

                    client.newCall(request).enqueue(object : Callback {
                        override fun onFailure(call: Call, e: IOException) {
                            Log.e(TAG, "Polling request for task $taskId failed", e)
                            // Don't cancel polling on network failure - keep trying
                        }

                        override fun onResponse(call: Call, response: Response) {
                            try {
                                Log.d(TAG, "Received response for task $taskId, code: ${response.code}")
                                
                                if (!response.isSuccessful) {
                                    Log.e(TAG, "Server returned an error on /status: ${response.code} ${response.message}")
                                    return
                                }

                                val responseBody = response.body?.string() ?: return
                                Log.d(TAG, "Response body for task $taskId: $responseBody")

                                val jsonResponse = JSONObject(responseBody)
                                val status = jsonResponse.optString("status", "")
                                Log.d(TAG, "Polling for task $taskId: Status is $status")

                                when (status) {
                                    "SUCCESS" -> {
                                        pollingFuture?.cancel(true)
                                        Log.d(TAG, "Training successfully completed for task $taskId.")
                                        val result = jsonResponse.optJSONObject("result")
                                        val modelUrl = result?.optString("tflite_url")
                                        val modelCode = result?.optString("model_code")

                                        if (!modelUrl.isNullOrEmpty()) {
                                            Log.d(TAG, "New model URL: $modelUrl")
                                            Log.d(TAG, "Model code: $modelCode")
                                            downloadAndSaveModel(modelUrl)
                                            updateLabelMap(gestureName)
                                        } else {
                                            Log.e(TAG, "Status is SUCCESS but tflite_url is missing or empty.")
                                        }
                                    }
                                    "PROGRESS" -> {
                                        val progress = jsonResponse.optJSONObject("progress")
                                        val currentStep = progress?.optString("current_step", "진행 중...")
                                        Log.d(TAG, "Task $taskId in progress: $currentStep")
                                    }
                                    "PENDING" -> {
                                        Log.d(TAG, "Task $taskId is pending...")
                                    }
                                    "FAILURE", "ERROR" -> {
                                        Log.e(TAG, "Training failed for task $taskId. Info: ${jsonResponse.optString("error_info")}")
                                        pollingFuture?.cancel(true)
                                    }
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to parse /status response for task $taskId", e)
                                // Don't cancel polling on parse failure - keep trying
                            }
                        }
                    })
                } catch (e: Exception) {
                    Log.e(TAG, "Exception in polling task $taskId", e)
                    // Don't let exception stop the scheduled task
                }
            }, 0, 2, TimeUnit.SECONDS)
            
            Log.d(TAG, "Polling scheduled successfully for task $taskId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start polling for task $taskId", e)
        }
    }

    private fun downloadAndSaveModel(url: String, labelMap: JSONObject? = null) {
        Log.d(TAG, "Downloading new model from: $url")
        val request = Request.Builder().url(url).build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Failed to download model", e)
            }

            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    Log.e(TAG, "Failed to download model: ${response.code} ${response.message}")
                    return
                }

                val modelFile = File(context.filesDir, CUSTOM_MODEL_NAME)
                try {
                    response.body?.byteStream()?.use { inputStream ->
                        FileOutputStream(modelFile).use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    Log.d(TAG, "Model successfully downloaded and saved to ${modelFile.absolutePath}")
                    listener?.onModelReady()
                } catch (e: IOException) {
                    Log.e(TAG, "Failed to save model to file", e)
                }
            }
        })
    }

    private fun updateLabelMap(gestureName: String) {
        try {
            val labelMapFile = File(context.filesDir, LABEL_MAP_FILE_NAME)
            val jsonObject: JSONObject

            if (labelMapFile.exists()) {
                val jsonString = labelMapFile.readText()
                jsonObject = JSONObject(jsonString)
            } else {
                // Fallback to basic_label_map.json from assets if updated_label_map.json doesn't exist
                val jsonString = context.assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
                jsonObject = JSONObject(jsonString)
            }

            // Find the maximum existing index
            var maxIndex = -1
            jsonObject.keys().forEach { key ->
                val index = jsonObject.getInt(key)
                if (index > maxIndex) {
                    maxIndex = index
                }
            }

            // Assign the new index (maxIndex + 1)
            val newIndex = maxIndex + 1

            // Add or update the new gesture and its index
            jsonObject.put(gestureName, newIndex)

            // Write the updated JSON back to the file
            labelMapFile.writeText(jsonObject.toString(4)) // Use 4 for indentation for readability
            Log.d(TAG, "Label map updated successfully with $gestureName:$newIndex")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update label map", e)
        }
    }

    fun shutdown() {
        pollingExecutor.shutdownNow()
    }
}
