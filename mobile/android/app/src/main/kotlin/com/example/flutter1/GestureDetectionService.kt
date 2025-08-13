package com.pentagon.ghostouch

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
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
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class GestureDetectionService : Service(), HandLandmarkerHelper.LandmarkerListener, LifecycleOwner, TrainingCoordinator.TrainingListener {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private var handLandmarkerHelper: HandLandmarkerHelper? = null
    private var gestureClassifier: GestureClassifier? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private lateinit var backgroundExecutor: ExecutorService
    private var lastActionTimestamp: Long = 0
    private lateinit var trainingCoordinator: TrainingCoordinator

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
        trainingCoordinator = TrainingCoordinator(this, this) // TrainingCoordinator 인스턴스화
    }

    override fun onModelReady() {
        Log.d(TAG, "새로운 모델이 준비되었습니다. GestureClassifier를 재로드합니다.")
        // GestureClassifier를 재인스턴스화하여 새로운 모델을 로드하도록 함
        gestureClassifier?.close() // 기존 인터프리터 닫기
        gestureClassifier = GestureClassifier(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ghostouch 실행 중")
            .setContentText("백그라운드에서 제스처를 인식하고 있습니다.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()
        startForeground(NOTIFICATION_ID, notification)

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
        if (isAppInForeground) return // 앱이 포그라운드면 바로 리턴

        val gesture = gestureClassifier?.classifyGesture(resultBundle.results.firstOrNull() ?: return) ?: return
        if (gesture == "none") return

        val gestureName = gesture.substringBefore(" (").trim()
        val now = System.currentTimeMillis()
        if (now - lastActionTimestamp > ACTION_COOLDOWN_MS) {
            Log.d(TAG, "Action executed for gesture: $gestureName")
            val actionExecutor = ActionExecutor(this)
            actionExecutor.executeActionForGesture(gestureName)
            lastActionTimestamp = now
        }
    }

    override fun onError(error: String, errorCode: Int) {
        Log.e(TAG, "Hand landmark detection error: $error")
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        backgroundExecutor.shutdown()
        handLandmarkerHelper?.clearHandLandmarker()
        gestureClassifier?.close()
        cameraProvider?.unbindAll()
        Log.d(TAG, "서비스 종료됨")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(CHANNEL_ID, "Gesture Detection Service Channel", NotificationManager.IMPORTANCE_DEFAULT)
            getSystemService(NotificationManager::class.java).createNotificationChannel(serviceChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
