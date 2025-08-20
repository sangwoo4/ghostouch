package com.pentagon.ghostouch.gesture

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import com.pentagon.ghostouch.actions.ActionExecutor
import com.pentagon.ghostouch.R

class GestureDetectionService : Service(), HandLandmarkerHelper.LandmarkerListener, LifecycleOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private var handLandmarkerHelper: HandLandmarkerHelper? = null
    private var gestureClassifier: GestureClassifier? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private lateinit var backgroundExecutor: ExecutorService
    private var lastActionTimestamp: Long = 0
    private lateinit var trainingCoordinator: TrainingCoordinator
    private lateinit var backgroundTimeoutManager: BackgroundTimeoutManager

    companion object {
        private const val TAG = "GestureDetectionService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "GestureDetectionChannel"
        private const val ACTION_COOLDOWN_MS: Long = 1500

        @JvmStatic
        var isAppInForeground = true // 앱 시작 시에는 true로 시작
    }

    override val lifecycle: Lifecycle get() = lifecycleRegistry

    override fun onCreate() {
        super.onCreate()
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
        Log.d(TAG, "서비스 생성됨")
        backgroundExecutor = Executors.newSingleThreadExecutor()
        createNotificationChannel()
        trainingCoordinator = TrainingCoordinator(this) // TrainingCoordinator 인스턴스화
        backgroundTimeoutManager = BackgroundTimeoutManager(this)
        
        // 저장된 백그라운드 타임아웃 설정 로드
        backgroundTimeoutManager.loadBackgroundTimeoutSetting()
    }
    
    private fun reloadModel() {
        backgroundExecutor.execute {
            Log.d(TAG, "백그라운드에서 GestureClassifier 재로드 중...")
            // GestureClassifier를 재인스턴스화하여 새로운 모델을 로드하도록 함
            gestureClassifier?.close() // 기존 인터프리터 닫기
            gestureClassifier = GestureClassifier(this)
            Log.d(TAG, "GestureClassifier 재로드 완료")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ghostouch 실행 중")
            .setContentText("백그라운드에서 제스처를 인식하고 있습니다.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()
        
        // 권한 상태에 따라 적절한 foreground service type 사용
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val hasCameraPermission = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.CAMERA
                ) == PackageManager.PERMISSION_GRANTED
                
                val hasForegroundCameraPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    ContextCompat.checkSelfPermission(
                        this, Manifest.permission.FOREGROUND_SERVICE_CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                } else true
                
                if (hasCameraPermission && hasForegroundCameraPermission) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                }
                Log.d(TAG, "Foreground service started with appropriate type")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start foreground service with specific type", e)
                // 폴백: 기본 startForeground 사용
                startForeground(NOTIFICATION_ID, notification)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        when (intent?.action) {
            "ACTION_START_TRAINING" -> {
                val gestureName = intent.getStringExtra("gestureName")
                val frames = intent.getSerializableExtra("frames") as? ArrayList<ArrayList<Double>>
                if (gestureName != null && frames != null) {
                    // Double을 Float으로 변환
                    val floatFrames = frames.map { innerList ->
                        innerList.map { it.toFloat() }
                    }
                    trainingCoordinator.uploadAndTrain(gestureName, floatFrames)
                } else {
                    Log.e(TAG, "학습 시작을 위한 제스처 이름 또는 프레임이 누락되었습니다.")
                }
            }
            "ACTION_RELOAD_MODEL" -> {
                Log.d(TAG, "새로운 모델 로드 요청 받음")
                reloadModel()
            }
            "ACTION_SET_BACKGROUND_TIMEOUT" -> {
                val timeoutMinutes = intent.getIntExtra("timeout_minutes", 0)
                backgroundTimeoutManager.setBackgroundTimeout(timeoutMinutes, isAppInForeground) { stopSelfAndNotify() }
            }
            "ACTION_APP_WENT_BACKGROUND" -> {
                Log.d(TAG, "Received background notification from MainActivity")
                if (backgroundTimeoutManager.getTimeoutMinutes() != 0) {
                    Log.d(TAG, "Starting background timer due to app going background")
                    backgroundTimeoutManager.startBackgroundTimerIfNeeded { stopSelfAndNotify() }
                }
            }
            else -> {
                // 서비스가 시작될 때 항상 카메라 준비
                setupCamera()
            }
        }

        return START_STICKY
    }

    private fun setupCamera() {
        // 무거운 모델 로딩 등은 백그라운드에서 처리
        backgroundExecutor.execute {
            if (handLandmarkerHelper == null) {
                handLandmarkerHelper = HandLandmarkerHelper(
                    context = this,
                    runningMode = RunningMode.LIVE_STREAM,
                    handLandmarkerHelperListener = this
                )
            }
            if (gestureClassifier == null) {
                gestureClassifier = GestureClassifier(this)
            }
        }

        // 카메라 프로바이더 가져오기 및 바인딩 (UI 스레드에서 처리)
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()
            bindCameraUseCases()
        }, ContextCompat.getMainExecutor(this))
    }

    private fun bindCameraUseCases() {
        val cameraProvider = cameraProvider ?: return
        val imageAnalyzer = ImageAnalysis.Builder()
            .setTargetAspectRatio(androidx.camera.core.AspectRatio.RATIO_4_3)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
            .also {
                it.setAnalyzer(backgroundExecutor) { imageProxy ->
                    handLandmarkerHelper?.detectLiveStream(imageProxy, true)
                }
            }
        val cameraSelector = CameraSelector.Builder().requireLensFacing(CameraSelector.LENS_FACING_FRONT).build()

        try {
            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(this, cameraSelector, imageAnalyzer)
        } catch (exc: Exception) {
            Log.e(TAG, "Failed to bind camera use cases", exc)
        }
    }

    override fun onResults(resultBundle: HandLandmarkerHelper.ResultBundle) {
        // 백그라운드 타이머 관리
        if (isAppInForeground) {
            // 앱이 포그라운드로 돌아왔을 때 백그라운드 타이머 취소
            if (backgroundTimeoutManager.hasActiveTimer()) {
                Log.d(TAG, "App returned to foreground, cancelling background timer")
                backgroundTimeoutManager.cancelBackgroundTimer()
            }
        } else {
            // 앱이 백그라운드일 때 타이머 시작
            if (backgroundTimeoutManager.getTimeoutMinutes() != 0 && !backgroundTimeoutManager.hasActiveTimer()) {
                Log.d(TAG, "App is in background, starting timer (timeout: ${backgroundTimeoutManager.getTimeoutMinutes()})")
                backgroundTimeoutManager.startBackgroundTimerIfNeeded { stopSelfAndNotify() }
            }
        }

        val gesture = gestureClassifier?.classifyGesture(resultBundle.results.firstOrNull() ?: return) ?: return
        if (gesture == "none") return

        // 백그라운드에 있을 때만 제스처 액션 실행
        if (!isAppInForeground) {
            val gestureName = gesture.substringBefore(" (").trim()
            val now = System.currentTimeMillis()
            if (now - lastActionTimestamp > ACTION_COOLDOWN_MS) {
                Log.d(TAG, "Action executed for gesture: $gestureName (app in background)")
                val actionExecutor = ActionExecutor(this)
                actionExecutor.executeActionForGesture(gestureName)
                lastActionTimestamp = now
            }
        } else {
            Log.d(TAG, "Gesture detected but app is in foreground, skipping action execution")
        }
    }

    override fun onError(error: String, errorCode: Int) {
        Log.e(TAG, "Hand landmark detection error: $error")
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        backgroundTimeoutManager.cancelBackgroundTimer() // 타이머 정리
        backgroundExecutor.shutdown()
        handLandmarkerHelper?.clearHandLandmarker()
        gestureClassifier?.close()
        cameraProvider?.unbindAll()
        Log.d(TAG, "서비스 종료됨")
    }
    
    // 서비스 종료 및 알림
    private fun stopSelfAndNotify() {
        Log.d(TAG, "Service stopping due to background timeout")
        
        // SharedPreferences에서 토글 상태를 false로 업데이트
        val prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
        prefs.edit().putBoolean("toggle_state", false).apply()
        Log.d(TAG, "Toggle state set to false due to background timeout")
        
        // Flutter에 즉시 토글 상태 변경 알림 (브로드캐스트 사용)
        try {
            val intent = Intent("com.pentagon.ghostouch.TOGGLE_STATE_CHANGED")
            intent.putExtra("state", false)
            sendBroadcast(intent)
            Log.d(TAG, "Sent broadcast about toggle state change")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send broadcast about toggle state change", e)
        }
        
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(CHANNEL_ID, "Gesture Detection Service Channel", NotificationManager.IMPORTANCE_DEFAULT)
            getSystemService(NotificationManager::class.java).createNotificationChannel(serviceChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
