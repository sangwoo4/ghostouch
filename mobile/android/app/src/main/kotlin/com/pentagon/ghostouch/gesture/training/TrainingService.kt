package com.pentagon.ghostouch.gesture.training

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
import com.pentagon.ghostouch.channels.MainActivity
import com.pentagon.ghostouch.R
import com.pentagon.ghostouch.gesture.detection.GestureDetectionService
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
        baseUrl = "http://${serverIp ?: "localhost"}:${if (serverPort == 0) 8000 else serverPort}"
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val taskId = intent?.getStringExtra("task_id")
        val gestureName = intent?.getStringExtra("gesture_name")

        if (taskId == null || gestureName == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, createNotification("모델 학습이 진행 중입니다..."))
        startPolling(taskId, gestureName)
        return START_STICKY
    }

    private fun startPolling(taskId: String, gestureName: String) {
        nullResponseCounter = 0
        pollingStartTime = System.currentTimeMillis()
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
                scheduleNextPoll(taskId, gestureName)
            }

            override fun onResponse(call: Call, response: Response) {
                runCatching {
                    if (!response.isSuccessful) {
                        scheduleNextPoll(taskId, gestureName)
                        return
                    }

                    val responseBody = response.body?.string()
                    if (responseBody.isNullOrEmpty()) {
                        if (++nullResponseCounter >= MAX_NULL_RESPONSE_RETRIES) {
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

                    when (status) {
                        "SUCCESS" -> handleSuccess(jsonResponse, gestureName)
                        "PROGRESS" -> {
                            val progress = jsonResponse.optJSONObject("progress")?.optString("current_step", "진행 중...")
                            updateNotification("모델 학습 중: $progress")
                            scheduleNextPoll(taskId, gestureName)
                        }
                        "PENDING" -> scheduleNextPoll(taskId, gestureName)
                        else -> {
                            updateNotification("모델 학습 실패: ${jsonResponse.optString("error_info", "Unknown error")}")
                            stopSelfAfterDelay()
                        }
                    }
                }.onFailure { scheduleNextPoll(taskId, gestureName) }
            }
        })
    }

    private fun scheduleNextPoll(taskId: String, gestureName: String) {
        if (!pollingExecutor.isShutdown) {
            pollingExecutor.schedule({ startSinglePoll(taskId, gestureName) }, 5, TimeUnit.SECONDS)
        }
    }

    private fun handleSuccess(jsonResponse: JSONObject, gestureName: String) {
        val result = jsonResponse.optJSONObject("result")
        val modelUrl = result?.optString("tflite_url")
        val newModelCode = result?.optString("model_code")
        
        if (modelUrl.isNullOrEmpty() || newModelCode.isNullOrEmpty()) {
            updateNotification("모델 학습 실패: 서버 응답 오류")
            stopSelfAfterDelay()
            return
        }
        
        val newModelFileName = modelUrl.substring(modelUrl.lastIndexOf('/') + 1)
        updateModelInfo(newModelCode, newModelFileName)
        downloadAndSaveModel(modelUrl, newModelFileName, gestureName)
    }
    
    private fun downloadAndSaveModel(url: String, modelFileName: String, gestureName: String) {
        client.newCall(Request.Builder().url(url).build()).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                updateNotification("모델 다운로드 실패")
                stopSelfAfterDelay()
            }

            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    updateNotification("모델 다운로드 실패")
                    stopSelfAfterDelay()
                    return
                }
                
                runCatching {
                    response.body?.byteStream()?.use { inputStream ->
                        File(filesDir, modelFileName).outputStream().use { outputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    updateLabelMap(gestureName)
                    notifyServiceOfNewModel()
                    notifyGestureListRefresh()
                    updateNotification("모델 학습 완료")
                    stopSelfAfterDelay()
                }.onFailure {
                    updateNotification("모델 저장 실패")
                    stopSelfAfterDelay()
                }
            }
        })
    }

    private fun updateLabelMap(newGestureName: String) = runCatching {
        val labelMapFile = File(filesDir, TrainingCoordinator.LABEL_MAP_FILE_NAME)
        val currentMap = loadLabelMap(labelMapFile).toMutableMap()
        
        if (!currentMap.containsKey(newGestureName)) {
            currentMap[newGestureName] = (currentMap.values.maxOrNull() ?: -1) + 1
        }
        
        val out = JSONObject().apply { currentMap.forEach { (k, v) -> put(k, v) } }
        labelMapFile.writeText(out.toString(4))
    }.onFailure { Log.e(TAG, "Failed to update label map", it) }
    
    private fun loadLabelMap(labelMapFile: File): Map<String, Int> {
        val jsonString = if (labelMapFile.exists()) {
            labelMapFile.readText()
        } else {
            assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
        }
        
        val jsonObj = JSONObject(jsonString)
        return buildMap {
            jsonObj.keys().forEach { key -> put(key, jsonObj.getInt(key)) }
        }
    }

    private fun notifyServiceOfNewModel() = runCatching {
        startService(Intent(this, GestureDetectionService::class.java).apply {
            action = "ACTION_RELOAD_MODEL"
        })
    }.onFailure { Log.e(TAG, "Failed to notify service", it) }

    private fun notifyGestureListRefresh() = runCatching {
        MainActivity.handDetectionPlatformView?.notifyGestureListRefresh()
        sendBroadcast(Intent("com.pentagon.ghostouch.GESTURE_LIST_UPDATED"))
    }.onFailure { Log.e(TAG, "Failed to notify gesture list refresh", it) }

    private fun updateModelInfo(newModelCode: String, newModelFileName: String) {
        TrainingCoordinator.apply {
            currentModelCode = newModelCode
            currentModelFileName = newModelFileName
        }
        
        getSharedPreferences(TrainingCoordinator.PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putString(TrainingCoordinator.MODEL_CODE_PREFS_KEY, newModelCode)
            .putString(TrainingCoordinator.MODEL_FILENAME_PREFS_KEY, newModelFileName)
            .commit()
    }

    private fun createNotification(text: String): Notification = 
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ghostouch 학습")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()

    private fun updateNotification(text: String) {
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, createNotification(text))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Training Service Channel", NotificationManager.IMPORTANCE_DEFAULT)
            )
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
    }

    override fun onBind(intent: Intent?): IBinder? = null
}