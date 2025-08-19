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
                            val newModelCode = result?.optString("model_code")
                            
                            if (!modelUrl.isNullOrEmpty() && !newModelCode.isNullOrEmpty()) {
                                val newModelFileName = modelUrl.substring(modelUrl.lastIndexOf('/') + 1)
                                updateModelInfo(newModelCode, newModelFileName)
                                downloadAndSaveModel(modelUrl, newModelFileName, gestureName)
                            } else {
                                Log.e(TAG, "SUCCESS but modelUrl or newModelCode is missing!")
                                updateNotification("모델 학습 실패: 서버 응답 오류")
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

    private fun downloadAndSaveModel(url: String, modelFileName: String, gestureName: String) {
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
                val modelFile = File(filesDir, modelFileName)
                try {
                    response.body?.byteStream()?.use { inputStream ->
                        FileOutputStream(modelFile).use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    Log.d(TAG, "Model successfully downloaded and saved to ${modelFile.absolutePath}")
                    updateLabelMap(gestureName)
                    notifyServiceOfNewModel()
                    notifyGestureListRefresh()
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

    private fun updateLabelMap(newGestureName: String) {
    try {
        val labelMapFile = File(filesDir, TrainingCoordinator.LABEL_MAP_FILE_NAME)

        // 1) 현재 라벨맵 불러오기 (gesture -> index)
        val currentMap: MutableMap<String, Int> = if (labelMapFile.exists()) {
            val jsonObj = JSONObject(labelMapFile.readText())
            buildMap {
                val it = jsonObj.keys()
                while (it.hasNext()) {
                    val k = it.next()
                    put(k, jsonObj.getInt(k))
                }
            }.toMutableMap()
        } else {
            val jsonString = assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
            val jsonObj = JSONObject(jsonString)
            buildMap {
                val it = jsonObj.keys()
                while (it.hasNext()) {
                    val k = it.next()
                    put(k, jsonObj.getInt(k))
                }
            }.toMutableMap()
        }

        // 2) 이미 존재하면 아무 것도 하지 않음 (서버 인덱스 보존)
        if (currentMap.containsKey(newGestureName)) {
            Log.d(TAG, "Label map unchanged. '$newGestureName' already exists with index=${currentMap[newGestureName]}")
        } else {
            // 3) 새 라벨은 현재 최대 인덱스 + 1 로만 추가 (정렬 금지, 재번호 금지)
            val nextIndex = (currentMap.values.maxOrNull() ?: -1) + 1
            currentMap[newGestureName] = nextIndex
            Log.d(TAG, "Added new label '$newGestureName' with index=$nextIndex")
        }

        // 4) 그대로 저장 (키 순서 강제/정렬 X)
        val out = JSONObject()
        // JSONObject는 내부적으로 순서를 보장하지 않지만, 인덱스는 값으로 보존되므로 문제 없음
        currentMap.forEach { (k, v) -> out.put(k, v) }
        labelMapFile.writeText(out.toString(4))

        Log.d(TAG, "Label map persisted without reindexing: $out")
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

    private fun notifyGestureListRefresh() {
        try {
            // MainActivity의 HandDetectionPlatformView를 통해 Flutter에 알림
            MainActivity.handDetectionPlatformView?.let { platformView ->
                platformView.notifyGestureListRefresh()
                Log.d(TAG, "Notified Flutter to refresh gesture list")
            } ?: run {
                Log.w(TAG, "HandDetectionPlatformView not available for gesture list refresh notification")
            }
            
            // GestureRegisterPage에도 알림 (브로드캐스트 방식)
            val intent = Intent("com.pentagon.ghostouch.GESTURE_LIST_UPDATED")
            sendBroadcast(intent)
            Log.d(TAG, "Broadcast sent for gesture list update")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify gesture list refresh", e)
        }
    }

    private fun updateModelInfo(newModelCode: String, newModelFileName: String) {
        // Update the static variables for immediate use
        TrainingCoordinator.currentModelCode = newModelCode
        TrainingCoordinator.currentModelFileName = newModelFileName

        // Also save to SharedPreferences to persist across process death
        val prefs = getSharedPreferences(TrainingCoordinator.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(TrainingCoordinator.MODEL_CODE_PREFS_KEY, newModelCode)
            .putString(TrainingCoordinator.MODEL_FILENAME_PREFS_KEY, newModelFileName)
            .commit()
        Log.d(TAG, "Updated model info in-memory and on-disk. Code: $newModelCode, FileName: $newModelFileName")
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