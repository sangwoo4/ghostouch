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

class GestureDetectionService : Service(), HandLandmarkerHelper.LandmarkerListener, LifecycleOwner {

    private val lifecycleRegistry = LifecycleRegistry(this)
    private var handLandmarkerHelper: HandLandmarkerHelper? = null
    private var gestureClassifier: GestureClassifier? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private lateinit var backgroundExecutor: ExecutorService

    companion object {
        private const val TAG = "GestureDetectionService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "GestureDetectionChannel"
    }

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry

    override fun onCreate() {
        super.onCreate()
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
        Log.d(TAG, "서비스 생성됨")
        createNotificationChannel()
        backgroundExecutor = Executors.newSingleThreadExecutor()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        Log.d(TAG, "서비스 시작됨")
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ghostouch 실행 중")
            .setContentText("백그라운드에서 제스처를 인식하고 있습니다.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            setupCamera()
        } else {
            Log.e(TAG, "카메라 권한이 없어 서비스를 시작할 수 없습니다.")
            stopSelf() // 권한 없으면 서비스 중지
        }

        return START_STICKY
    }

    private fun setupCamera() {
        backgroundExecutor.execute {
            handLandmarkerHelper = HandLandmarkerHelper(
                context = this,
                runningMode = RunningMode.LIVE_STREAM,
                handLandmarkerHelperListener = this
            )
            gestureClassifier = GestureClassifier(this)

            val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
            cameraProviderFuture.addListener({
                cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases()
            }, ContextCompat.getMainExecutor(this))
        }
    }

    private fun bindCameraUseCases() {
        val cameraProvider = cameraProvider ?: return

        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
            .build()

        val imageAnalyzer = ImageAnalysis.Builder()
            .setTargetAspectRatio(androidx.camera.core.AspectRatio.RATIO_4_3)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
            .also {
                it.setAnalyzer(backgroundExecutor) { imageProxy ->
                    if (handLandmarkerHelper?.isClose() == false) {
                        handLandmarkerHelper?.detectLiveStream(imageProxy, isFrontCamera = true)
                    } else {
                        // Helper is closed, just close the image and drop the frame.
                        imageProxy.close()
                    }
                }
            }

        cameraProvider.unbindAll()

        try {
            cameraProvider.bindToLifecycle(
                this, cameraSelector, imageAnalyzer
            )
            Log.d(TAG, "백그라운드 카메라 바인딩 성공")
        } catch (exc: Exception) {
            Log.e(TAG, "백그라운드 카메라 바인딩 실패", exc)
        }
    }

    override fun onResults(resultBundle: HandLandmarkerHelper.ResultBundle) {
        val handLandmarkerResult = resultBundle.results.firstOrNull()
        if (handLandmarkerResult != null) {
            val gesture = gestureClassifier?.classifyGesture(handLandmarkerResult)
            if (gesture != null && gesture != "none") {
                Log.d(TAG, "인식된 제스처: $gesture")
                // TODO: 인식된 제스처에 따라 특정 동작 수행 (예: 이벤트 버스, 브로드캐스트)
            }
        }
    }

    override fun onError(error: String, errorCode: Int) {
        Log.e(TAG, "손 감지 오류: $error")
    }

    override fun onDestroy() {
        super.onDestroy()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        // Shut down the background executor first.
        backgroundExecutor.shutdown()
        try {
            // Wait for the executor to terminate.
            if (!backgroundExecutor.awaitTermination(50, java.util.concurrent.TimeUnit.MILLISECONDS)) {
                backgroundExecutor.shutdownNow()
            }
        } catch (e: InterruptedException) {
            backgroundExecutor.shutdownNow()
        }

        // Now, safely close other resources.
        cameraProvider?.unbindAll()
        handLandmarkerHelper?.clearHandLandmarker()
        gestureClassifier?.close()
        Log.d(TAG, "서비스 종료됨")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Gesture Detection Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
