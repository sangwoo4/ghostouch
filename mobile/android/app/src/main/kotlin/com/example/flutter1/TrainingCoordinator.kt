package com.pentagon.ghostouch

import android.content.Context
import android.content.Intent
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
import android.os.Build
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Manages the initial training request to the server.
 * The actual polling for results is delegated to TrainingService.
 */
class TrainingCoordinator(private val context: Context) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val baseUrl: String

    init {
        val appInfo = context.packageManager.getApplicationInfo(
            context.packageName,
            PackageManager.GET_META_DATA
        )
        val serverIp = appInfo.metaData.getString("com.pentagon.ghostouch.SERVER_IP")
        val serverPort = appInfo.metaData.getInt("com.pentagon.ghostouch.SERVER_PORT")

        baseUrl = if (serverIp == null || serverPort == 0) {
            Log.e(TAG, "Server IP or Port not found in AndroidManifest.xml metadata.")
            "http://localhost:8000" // Fallback or error handling
        } else {
            "http://$serverIp:$serverPort"
        }
    }

    companion object {
        private const val TAG = "TrainingCoordinator"
        const val CUSTOM_MODEL_NAME = "custom_model.tflite"
        const val LABEL_MAP_FILE_NAME = "updated_label_map.json"
        private const val MODEL_CODE_PREFS_KEY = "current_model_code"
    }

    fun uploadAndTrain(gestureName: String, frames: List<List<Float>>) {
        Log.d(TAG, "Preparing to upload ${frames.size} frames for gesture: $gestureName")

        if (frames.size < 100) {
            Log.w(TAG, "Not enough frames collected to start training. Required: 100, Found: ${frames.size}")
            return
        }

        val currentModelCode = getCurrentModelCode()
        val currentLabelMap = getCurrentLabelMap()

        val jsonPayload = JSONObject().apply {
            put("model_code", currentModelCode)
            put("gesture", gestureName)
            put("current_labels", currentLabelMap)
            put("landmarks", JSONArray(frames.map { JSONArray(it.map { v -> v.toDouble() }) }))
        }

        val requestBody = jsonPayload.toString().toRequestBody("application/json; charset=utf-8".toMediaType())
        val request = Request.Builder().url("$baseUrl/train").post(requestBody).build()

        Log.d(TAG, "Sending training request to $baseUrl/train")

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Training request failed", e)
                // Optionally, notify UI of this initial failure
            }

            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    Log.e(TAG, "Server returned an error on /train: ${response.code} ${response.message}")
                    return
                }

                try {
                    val jsonResponse = JSONObject(response.body?.string())
                    val taskId = jsonResponse.optString("task_id", null)
                    if (taskId != null) {
                        Log.d(TAG, "Training task started successfully. Task ID: $taskId. Delegating to TrainingService.")
                        // Delegate polling to the foreground service
                        val serviceIntent = Intent(context, TrainingService::class.java).apply {
                            putExtra("task_id", taskId)
                            putExtra("gesture_name", gestureName)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent)
                        } else {
                            context.startService(serviceIntent)
                        }
                    } else {
                        Log.e(TAG, "Could not find 'task_id' in the server response.")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse /train response", e)
                }
            }
        })
    }

    private fun getCurrentModelCode(): String {
        val prefs = context.getSharedPreferences("training_prefs", Context.MODE_PRIVATE)
        return prefs.getString(MODEL_CODE_PREFS_KEY, "base_v1") ?: "base_v1"
    }

    private fun getCurrentLabelMap(): JSONObject {
        return try {
            val labelMapFile = File(context.filesDir, LABEL_MAP_FILE_NAME)
            if (labelMapFile.exists()) {
                JSONObject(labelMapFile.readText())
            } else {
                val jsonString = context.assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
                JSONObject(jsonString)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get current label map", e)
            JSONObject() // Return empty object if error
        }
    }
}