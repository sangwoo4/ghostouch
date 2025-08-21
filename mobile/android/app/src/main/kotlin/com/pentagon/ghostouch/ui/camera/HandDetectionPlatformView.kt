package com.pentagon.ghostouch.ui.camera

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.mediapipe.tasks.vision.core.RunningMode
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import com.pentagon.ghostouch.gesture.detection.HandLandmarkerHelper
import com.pentagon.ghostouch.gesture.detection.GestureClassifier
import com.pentagon.ghostouch.gesture.training.TrainingCoordinator
import com.pentagon.ghostouch.ui.permissions.PermissionsFragment
import com.pentagon.ghostouch.channels.MainActivity

class HandDetectionPlatformView(
    private val context: Context,
    viewId: Int,
    args: Any?,
    private val activity: FlutterActivity,
    private val binaryMessenger: BinaryMessenger
) : PlatformView, HandLandmarkerHelper.LandmarkerListener {

    private val containerView: FrameLayout = FrameLayout(context)
    private var previewView: PreviewView? = null
    private var overlayView: OverlayView? = null
    private var handLandmarkerHelper: HandLandmarkerHelper? = null
    private var gestureClassifier: GestureClassifier? = null
    private var trainingCoordinator: TrainingCoordinator? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private lateinit var backgroundExecutor: ExecutorService
    private lateinit var methodChannel: MethodChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val MIN_CONFIDENCE_THRESHOLD = 0.5f // 신뢰도 임계값
        private const val TARGET_FRAME_COUNT = 100        // 목표 프레임 수

        @JvmStatic var isCollecting: Boolean = false
        @JvmStatic var collectedFrames: MutableList<List<Float>> = mutableListOf()
        @JvmStatic var currentGestureName: String? = null
        @JvmStatic var totalFrameAttempts: Int = 0
    }

    init {
        setupView()
        setupMethodChannel()
        MainActivity.handDetectionPlatformView = this
        Log.d("HandDetectionPlatformView", "PlatformView registered with MainActivity")

        MainActivity.pendingGestureName?.let { gestureName ->
            Log.d("HandDetectionPlatformView", "Processing pending gesture: $gestureName")
            startCollecting(gestureName)
            MainActivity.pendingGestureName = null
        }
    }

    private fun setupView() {
        backgroundExecutor = Executors.newSingleThreadExecutor()

        // 권한 승인 콜백: 권한 허용되면 카메라 다시 세팅
        PermissionsFragment.onPermissionGrantedCallback = {
            activity.runOnUiThread {
                containerView.removeAllViews()
                setupCamera()
            }
        }

        if (PermissionsFragment.hasPermissions(context)) {
            setupCamera()
        } else {
            // 커스텀 권한 안내 UI를 사용하지 않으므로, 여기서는 로그만 남기고 종료
            Log.w("HandDetectionPlatformView", "Camera permissions are not granted. View will remain empty.")
        }
    }

    private fun setupMethodChannel() {
        methodChannel = MethodChannel(binaryMessenger, "com.pentagon.ghostouch/hand_detection")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCollecting" -> {
                    val gestureName = call.argument<String>("gestureName")
                    if (gestureName != null) {
                        startCollecting(gestureName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Gesture name is required", null)
                    }
                }
                "stopCollecting" -> {
                    stopCollecting()
                    result.success(null)
                }
                "saveGesture" -> {
                    val gestureName = call.argument<String>("gestureName")
                    Log.d("HandDetectionPlatformView", "saveGesture called with gesture: $gestureName")
                    if (gestureName != null) {
                        runCatching {
                            uploadCollectedData()
                        }.onSuccess {
                            result.success("Gesture upload started successfully")
                        }.onFailure { e ->
                            Log.e("HandDetectionPlatformView", "Failed to upload gesture data", e)
                            result.error("UPLOAD_FAILED", "Failed to upload gesture: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Gesture name is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startCollecting(gestureName: String) {
        Log.d("HandDetectionPlatformView", "Starting collection for gesture: $gestureName")
        isCollecting = true
        currentGestureName = gestureName
        collectedFrames.clear()
        totalFrameAttempts = 0

        mainHandler.post {
            methodChannel.invokeMethod("collectionStarted", null)
        }
    }

    fun startCollectingFromMainActivity(gestureName: String) = startCollecting(gestureName)

    private fun stopCollecting() {
        Log.d("HandDetectionPlatformView", "Stopping collection.")
        isCollecting = false

        if (collectedFrames.isNotEmpty()) {
            val gestureName = currentGestureName ?: "unknown"
            Log.d("HandDetectionPlatformView", "Uploading ${collectedFrames.size} frames for gesture: $gestureName")
            trainingCoordinator?.uploadAndTrain(gestureName, collectedFrames)
        }

        currentGestureName = null
        mainHandler.post {
            methodChannel.invokeMethod("collectionComplete", null)
        }
    }

    fun uploadCollectedData() {
        if (collectedFrames.isNotEmpty()) {
            val gestureName = currentGestureName ?: "unknown"
            Log.d("HandDetectionPlatformView", "Now uploading ${collectedFrames.size} frames for gesture: $gestureName")
            trainingCoordinator?.uploadAndTrain(gestureName, collectedFrames)
        } else {
            Log.w("HandDetectionPlatformView", "No frames to upload")
        }

        collectedFrames.clear()
        currentGestureName = null
    }

    // TrainingCoordinator -> Flutter (taskId 전달)
    fun notifyTaskIdReady(taskId: String) {
        Log.d("HandDetectionPlatformView", "Task ID ready: $taskId, notifying Flutter")
        mainHandler.post {
            methodChannel.invokeMethod("taskIdReady", mapOf("taskId" to taskId))
        }
    }

    // TrainingService -> Flutter (제스처 목록 갱신)
    fun notifyGestureListRefresh() {
        Log.d("HandDetectionPlatformView", "Notifying Flutter to refresh gesture list")
        mainHandler.post {
            MethodChannel(binaryMessenger, "com.pentagon.ghostouch/toggle")
                .invokeMethod("refreshGestureList", null)
        }
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun setupCamera() {
        try {
            Log.d("HandDetectionPlatformView", "Setting up camera...")

            previewView = PreviewView(context).apply {
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                scaleType = PreviewView.ScaleType.FILL_CENTER
            }
            containerView.addView(
                previewView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            )

            overlayView = OverlayView(context, null)
            containerView.addView(
                overlayView,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            )

            backgroundExecutor.execute {
                handLandmarkerHelper = HandLandmarkerHelper(
                    context = context,
                    runningMode = RunningMode.LIVE_STREAM,
                    handLandmarkerHelperListener = this
                )
                gestureClassifier = GestureClassifier(context)
                trainingCoordinator = TrainingCoordinator(context)
            }

            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            cameraProviderFuture.addListener({
                cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases()
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) {
            Log.e("HandDetectionPlatformView", "Failed to setup camera", e)
        }
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases() {
        val cameraProvider = cameraProvider ?: return
        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_FRONT)
            .build()

        preview = Preview.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .build()

        imageAnalyzer = ImageAnalysis.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build().also {
                it.setAnalyzer(backgroundExecutor) { imageProxy ->
                    if (handLandmarkerHelper?.isClose() == false) {
                        detectHand(imageProxy)
                    }
                }
            }

        cameraProvider.unbindAll()

        try {
            camera = cameraProvider.bindToLifecycle(
                activity, cameraSelector, preview, imageAnalyzer
            )
            preview?.setSurfaceProvider(previewView?.surfaceProvider)
            Log.d("HandDetectionPlatformView", "Camera bound successfully with MainActivity")
        } catch (exc: Exception) {
            Log.e("HandDetectionPlatformView", "Use case binding failed", exc)
            showErrorMessage("카메라 연결 실패: ${exc.message}")
        }
    }

    private fun detectHand(imageProxy: ImageProxy) {
        handLandmarkerHelper?.detectLiveStream(
            imageProxy = imageProxy,
            isFrontCamera = true
        )
    }

    override fun onResults(resultBundle: HandLandmarkerHelper.ResultBundle) {
        val handLandmarkerResult = resultBundle.results.firstOrNull() ?: return

        if (isCollecting) {
            totalFrameAttempts++

            val worldLandmarks = handLandmarkerResult.worldLandmarks().firstOrNull()
            val handedness = handLandmarkerResult.handedness().firstOrNull()?.firstOrNull()

            if (worldLandmarks != null && worldLandmarks.size == 21) {
                val confidence = handedness?.score() ?: 0.0f
                if (confidence >= MIN_CONFIDENCE_THRESHOLD) {
                    val flatLandmarks = worldLandmarks
                        .flatMap { listOf(it.x(), it.y(), it.z()) }
                    val handednessValue = when (handedness?.categoryName()) {
                        "Left" -> 0.0f
                        "Right" -> 1.0f
                        else -> -1.0f
                    }
                    collectedFrames.add(flatLandmarks + handednessValue)

                    val progress = (collectedFrames.size / TARGET_FRAME_COUNT.toDouble() * 100)
                        .toInt().coerceAtMost(100)
                    mainHandler.post {
                        methodChannel.invokeMethod("updateProgress", progress)
                    }

                    if (collectedFrames.size >= TARGET_FRAME_COUNT) {
                        stopCollecting()
                    }
                }
            }
        }

        // 학습 중이 아닐 때만 제스처 분류
        val gesture = if (isCollecting) "none"
        else gestureClassifier?.classifyGesture(handLandmarkerResult) ?: "none"

        overlayView?.post {
            overlayView?.setResults(
                handLandmarkerResult,
                resultBundle.inputImageHeight,
                resultBundle.inputImageWidth,
                RunningMode.LIVE_STREAM,
                gesture,
                isFrontCamera = true,
                rotationDegrees = resultBundle.rotationDegrees,
                handednesses = handLandmarkerResult.handednesses()
            )
        }
    }

    override fun onError(error: String, errorCode: Int) {
        Log.e("HandDetectionPlatformView", "Hand detection error: $error")
        showErrorMessage("손 감지 오류: $error")
    }

    private fun showErrorMessage(message: String) {
        val textView = TextView(context).apply {
            text = message
            textSize = 16f
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            setPadding(40, 40, 40, 40)
        }

        containerView.removeAllViews()
        containerView.addView(
            textView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
    }

    override fun getView(): View = containerView

    override fun dispose() {
        backgroundExecutor.shutdown()
        try {
            if (!backgroundExecutor.awaitTermination(50, java.util.concurrent.TimeUnit.MILLISECONDS)) {
                backgroundExecutor.shutdownNow()
            }
        } catch (e: InterruptedException) {
            backgroundExecutor.shutdownNow()
        }
        cameraProvider?.unbindAll()
        handLandmarkerHelper?.clearHandLandmarker()
        gestureClassifier?.close()
    }
}