package com.pentagon.ghostouch.gesture.training

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import com.pentagon.ghostouch.channels.MainActivity
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

        // Load the last known model code from disk to initialize the static variable
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        currentModelCode = prefs.getString(MODEL_CODE_PREFS_KEY, "base_v1") ?: "base_v1"
        currentModelFileName = prefs.getString(MODEL_FILENAME_PREFS_KEY, "basic_gesture_model.tflite") ?: "basic_gesture_model.tflite"
        Log.d(TAG, "Initialized TrainingCoordinator with model_code: $currentModelCode and model_filename: $currentModelFileName")
    }

    companion object {
        private const val TAG = "TrainingCoordinator"
        const val LABEL_MAP_FILE_NAME = "updated_label_map.json"
        const val PREFS_NAME = "training_prefs"
        const val MODEL_CODE_PREFS_KEY = "current_model_code"
        const val MODEL_FILENAME_PREFS_KEY = "current_model_filename"

        @JvmStatic
        var currentModelCode: String = "base_v1"
        @JvmStatic
        var currentModelFileName: String = "basic_gesture_model.tflite"

        fun getServerUrl(context: Context): String {
            val appInfo = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA
            )
            val serverIp = appInfo.metaData?.getString("com.pentagon.ghostouch.SERVER_IP")
            val serverPort = appInfo.metaData?.getInt("com.pentagon.ghostouch.SERVER_PORT") ?: 0

            return if (serverIp == null || serverPort == 0) {
                Log.e(TAG, "Server IP or Port not found in AndroidManifest.xml metadata.")
                "http://localhost:8000" // Fallback
            } else {
                "http://$serverIp:$serverPort"
            }
        }
    }

    fun uploadAndTrain(gestureName: String, frames: List<List<Float>>) {
        Log.d(TAG, "Preparing to upload ${frames.size} frames for gesture: $gestureName")

        if (frames.isEmpty()) {
            Log.w(TAG, "Frame list is empty, cannot start training.")
            return
        }

        val jsonPayload = JSONObject().apply {
            put("model_code", currentModelCode)
            put("gesture", gestureName)
            put("landmarks", JSONArray(frames.map { JSONArray(it.map { v -> v.toDouble() }) }))
        }

        val requestBody = jsonPayload.toString().toRequestBody("application/json; charset=utf-8".toMediaType())
        val request = Request.Builder().url("$baseUrl/train").post(requestBody).build()

        Log.d(TAG, "Sending training request to $baseUrl/train with payload: $jsonPayload")

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Training request failed", e)
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
                        
                        // SharedPreferences에 실제 task_id 저장
                        val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
                        prefs.edit().putString("current_task_id", taskId).apply()
                        Log.d(TAG, "Saved task_id to SharedPreferences: $taskId")
                        
                        // Flutter에 task_id 전달하여 폴링 시작하도록 알림
                        MainActivity.handDetectionPlatformView?.let { platformView ->
                            platformView.notifyTaskIdReady(taskId)
                        }
                        
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