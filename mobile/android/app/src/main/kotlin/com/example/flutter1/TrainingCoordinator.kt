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
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class TrainingCoordinator(private val context: Context, private val listener: TrainingListener?) {

    private val client = OkHttpClient()
    private val pollingExecutor: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private var pollingFuture: ScheduledFuture<*>? = null

    interface TrainingListener {
        fun onModelReady()
    }

    companion object {
        private const val TAG = "TrainingCoordinator"
        const val CUSTOM_MODEL_NAME = "custom_model.tflite"
    }

    private val baseUrl: String by lazy {
        getServerUrlFromManifest()
    }

    private fun getServerUrlFromManifest(): String {
        return try {
            val packageManager = context.packageManager
            val applicationInfo = packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            val metaData = applicationInfo.metaData
            
            val serverIp = metaData?.getString("com.pentagon.ghostouch.SERVER_IP") ?: "10.0.2.2"
            val serverPort = metaData?.getInt("com.pentagon.ghostouch.SERVER_PORT", 8000).toString()
            
            val url = "http://$serverIp:$serverPort"
            Log.d(TAG, "Server URL from manifest: $url")
            url
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read server config from manifest, using default", e)
            "http://10.0.2.2:8000"
        }
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
                            startPolling(taskId)
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

    private fun startPolling(taskId: String) {
        pollingFuture = pollingExecutor.scheduleAtFixedRate({ 
            val request = Request.Builder()
                .url("$baseUrl/status/$taskId")
                .get()
                .build()

            client.newCall(request).enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    Log.e(TAG, "Polling request for task $taskId failed", e)
                }

                override fun onResponse(call: Call, response: Response) {
                    if (!response.isSuccessful) {
                        Log.e(TAG, "Server returned an error on /status: ${response.code} ${response.message}")
                        return
                    }

                    val responseBody = response.body?.string() ?: return

                    try {
                        val jsonResponse = JSONObject(responseBody)
                        val status = jsonResponse.optString("status", "")
                        Log.d(TAG, "Polling for task $taskId: Status is $status")

                        when (status) {
                            "SUCCESS" -> {
                                pollingFuture?.cancel(true)
                                Log.d(TAG, "Training successfully completed for task $taskId.")
                                val result = jsonResponse.optJSONObject("result")
                                val modelUrl = result?.optString("model_url")
                                if (!modelUrl.isNullOrEmpty()) {
                                    downloadAndSaveModel(modelUrl)
                                } else {
                                    Log.e(TAG, "Status is SUCCESS but model_url is missing or empty.")
                                }
                            }
                            "FAILURE", "ERROR" -> {
                                Log.e(TAG, "Training failed for task $taskId. Info: ${jsonResponse.optString("error_info")}")
                                pollingFuture?.cancel(true)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse /status response", e)
                    }
                }
            })
        }, 0, 2, TimeUnit.SECONDS)
    }

    private fun downloadAndSaveModel(url: String) {
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

    fun shutdown() {
        pollingExecutor.shutdownNow()
    }
}
