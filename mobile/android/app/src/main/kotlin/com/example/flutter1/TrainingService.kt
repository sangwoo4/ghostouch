package com.pentagon.ghostouch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class TrainingService : Service() {

    private lateinit var pollingExecutor: ScheduledExecutorService
    private val client = OkHttpClient()
    private lateinit var baseUrl: String

    private var nullResponseCounter = 0
    private var pollingStartTime = 0L

    companion object {
        private const val TAG = "TrainingService"
        private const val NOTIFICATION_ID = 101
        private const val CHANNEL_ID = "TrainingServiceChannel"
        private const val MAX_NULL_RESPONSE_RETRIES = 3
        private const val POLLING_TIMEOUT_MS = 120000L // 2 minutes
    }

    override fun onCreate() {
        super.onCreate()
        pollingExecutor = Executors.newSingleThreadScheduledExecutor()
        val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        val serverIp = appInfo.metaData?.getString("com.pentagon.ghostouch.SERVER_IP")
        val serverPort = appInfo.metaData?.getInt("com.pentagon.ghostouch.SERVER_PORT") ?: 0
        baseUrl = if (serverIp == null || serverPort == 0) {
            "http://localhost:8000"
        } else {
            "http://$serverIp:$serverPort"
        }
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val taskId = intent?.getStringExtra("task_id")
        val gestureName = intent?.getStringExtra("gesture_name")

        if (taskId == null || gestureName == null) {
            Log.e(TAG, "Task ID or Gesture Name is null. Stopping service.")
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = createNotification("모델 학습이 진행 중입니다...")
        startForeground(NOTIFICATION_ID, notification)

        startPolling(taskId, gestureName)

        return START_STICKY
    }

    private fun startPolling(taskId: String, gestureName: String) {
        nullResponseCounter = 0
        pollingStartTime = System.currentTimeMillis()
        Log.d(TAG, "Starting polling for task $taskId. Timeout is set to ${POLLING_TIMEOUT_MS / 1000} seconds.")
        startSinglePoll(taskId, gestureName)
    }

    private fun startSinglePoll(taskId: String, gestureName: String) {
        if (System.currentTimeMillis() - pollingStartTime > POLLING_TIMEOUT_MS) {
            Log.e(TAG, "Polling timed out after ${POLLING_TIMEOUT_MS / 1000} seconds. Stopping poll.")
            updateNotification("모델 학습 실패: 시간 초과")
            stopSelfAfterDelay()
            return
        }

        if (pollingExecutor.isShutdown) return

        val request = Request.Builder().url("$baseUrl/status/$taskId").get().build()
        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Request failed for task $taskId", e)
                scheduleNextPoll(taskId, gestureName)
            }

            override fun onResponse(call: Call, response: Response) {
                try {
                    if (!response.isSuccessful) {
                        Log.e(TAG, "Server error: ${response.code} ${response.message}")
                        scheduleNextPoll(taskId, gestureName)
                        return
                    }

                    val responseBody = response.body?.string()
                    if (responseBody.isNullOrEmpty()) {
                        nullResponseCounter++
                        Log.w(TAG, "Response body is null or empty. Retry attempt $nullResponseCounter/$MAX_NULL_RESPONSE_RETRIES.")
                        if (nullResponseCounter >= MAX_NULL_RESPONSE_RETRIES) {
                            Log.e(TAG, "Max retries reached. Stopping poll and treating as FAILED.")
                            updateNotification("모델 학습 실패: 서버 응답 없음")
                            stopSelfAfterDelay()
                        } else {
                            scheduleNextPoll(taskId, gestureName)
                        }
                        return
                    }

                    nullResponseCounter = 0
                    val jsonResponse = JSONObject(responseBody)
                    val status = jsonResponse.optString("status", "")
                    Log.d(TAG, "Status: $status")

                    when (status) {
                        "SUCCESS" -> {
                            val result = jsonResponse.optJSONObject("result")
                            val modelUrl = result?.optString("tflite_url")
                            if (!modelUrl.isNullOrEmpty()) {
                                downloadAndSaveModel(modelUrl, gestureName)
                            } else {
                                Log.e(TAG, "SUCCESS but no model URL!")
                                updateNotification("모델 학습 실패: 모델 URL 없음")
                                stopSelfAfterDelay()
                            }
                        }
                        "PROGRESS" -> {
                            val progress = jsonResponse.optJSONObject("progress")?.optString("current_step", "진행 중...")
                            updateNotification("모델 학습 중: $progress")
                            scheduleNextPoll(taskId, gestureName)
                        }
                        "PENDING" -> {
                            scheduleNextPoll(taskId, gestureName)
                        }
                        else -> { // FAILURE, ERROR, or Unknown
                            val errorInfo = jsonResponse.optString("error_info", "Unknown error")
                            Log.e(TAG, "Training failed: $errorInfo")
                            updateNotification("모델 학습 실패: $errorInfo")
                            stopSelfAfterDelay()
                        }
                    }
                } catch (t: Throwable) {
                    Log.e(TAG, "Error processing response", t)
                    scheduleNextPoll(taskId, gestureName)
                }
            }
        })
    }

    private fun scheduleNextPoll(taskId: String, gestureName: String) {
        if (!pollingExecutor.isShutdown) {
            pollingExecutor.schedule({ startSinglePoll(taskId, gestureName) }, 5, TimeUnit.SECONDS)
        }
    }

    private fun downloadAndSaveModel(url: String, gestureName: String) {
        val request = Request.Builder().url(url).build()
        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Failed to download model", e)
                updateNotification("모델 다운로드 실패")
                stopSelfAfterDelay()
            }

            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    Log.e(TAG, "Failed to download model: ${response.code}")
                    updateNotification("모델 다운로드 실패")
                    stopSelfAfterDelay()
                    return
                }
                val modelFile = File(filesDir, TrainingCoordinator.CUSTOM_MODEL_NAME)
                try {
                    response.body?.byteStream()?.use { inputStream ->
                        FileOutputStream(modelFile).use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    Log.d(TAG, "Model successfully downloaded and saved to ${modelFile.absolutePath}")
                    updateLabelMap(gestureName)
                    notifyServiceOfNewModel()
                    updateNotification("모델 학습 완료")
                    stopSelfAfterDelay()
                } catch (e: IOException) {
                    Log.e(TAG, "Failed to save model to file", e)
                    updateNotification("모델 저장 실패")
                    stopSelfAfterDelay()
                }
            }
        })
    }

    private fun updateLabelMap(gestureName: String) {
        try {
            val labelMapFile = File(filesDir, TrainingCoordinator.LABEL_MAP_FILE_NAME)
            val jsonObject = if (labelMapFile.exists()) {
                JSONObject(labelMapFile.readText())
            } else {
                val jsonString = assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
                JSONObject(jsonString)
            }

            if (jsonObject.has(gestureName)) return

            val maxIndex = jsonObject.keys().asSequence().map { jsonObject.getInt(it) }.maxOrNull() ?: -1
            jsonObject.put(gestureName, maxIndex + 1)

            labelMapFile.writeText(jsonObject.toString(4))
            Log.d(TAG, "Label map updated successfully.")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to update label map", e)
        }
    }

    private fun notifyServiceOfNewModel() {
        try {
            val intent = Intent(this, GestureDetectionService::class.java)
            intent.action = "ACTION_RELOAD_MODEL"
            startService(intent)
            Log.d(TAG, "Notified GestureDetectionService of new model")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify service", e)
        }
    }

    private fun createNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ghostouch 학습")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher) // Ensure you have this icon
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = createNotification(text)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Training Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun stopSelfAfterDelay() {
        // Stop foreground and remove notification, then stop the service
        // A small delay can prevent abrupt removal
        pollingExecutor.schedule({ 
            stopForeground(true)
            stopSelf()
        }, 1000, TimeUnit.MILLISECONDS)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::pollingExecutor.isInitialized && !pollingExecutor.isShutdown) {
            pollingExecutor.shutdownNow()
        }
        Log.d(TAG, "Service destroyed.")
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}