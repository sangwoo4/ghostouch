package com.pentagon.ghostouch

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

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
        private const val MIN_CONFIDENCE_THRESHOLD = 0.5f // 신뢰도 임계값 (낮춤)
        private const val TARGET_FRAME_COUNT = 100 // 목표 프레임 수
        
        // Static 변수로 인스턴스 재생성에도 상태 유지
        @JvmStatic
        var isCollecting: Boolean = false
        @JvmStatic
        var collectedFrames: MutableList<List<Float>> = mutableListOf()
        @JvmStatic
        var currentGestureName: String? = null
        @JvmStatic
        var totalFrameAttempts: Int = 0
    }

    init {
        setupView()
        setupMethodChannel()
        // MainActivity에 자신을 등록
        MainActivity.handDetectionPlatformView = this
        Log.d("HandDetectionPlatformView", "PlatformView registered with MainActivity")
        
        // 대기 중인 제스처가 있다면 즉시 처리
        MainActivity.pendingGestureName?.let { gestureName ->
            Log.d("HandDetectionPlatformView", "Processing pending gesture: $gestureName")
            startCollecting(gestureName)
            MainActivity.pendingGestureName = null // 처리 완료 후 제거
        }
    }

    private fun setupView() {
        backgroundExecutor = Executors.newSingleThreadExecutor()

        // 권한 승인 콜백 등록
        PermissionsFragment.onPermissionGrantedCallback = {
            activity.runOnUiThread {
                containerView.removeAllViews()
                setupCamera()
            }
        }

        if (PermissionsFragment.hasPermissions(context)) {
            setupCamera()
        } else {
            showPermissionRequiredView()
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
                        try {
                            uploadCollectedData()
                            result.success("Gesture upload started successfully")
                        } catch (e: Exception) {
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
        Log.d("HandDetectionPlatformView", "isCollecting changed from $isCollecting to true")
        isCollecting = true
        currentGestureName = gestureName
        collectedFrames.clear()
        totalFrameAttempts = 0
        // Optionally, send a signal to Flutter that collection has started
        mainHandler.post {
            methodChannel.invokeMethod("collectionStarted", null)
        }
        Log.d("HandDetectionPlatformView", "Collection setup complete. isCollecting: $isCollecting")
    }

    // MainActivity에서 호출할 수 있는 public 메서드
    fun startCollectingFromMainActivity(gestureName: String) {
        Log.d("HandDetectionPlatformView", "startCollectingFromMainActivity called with: $gestureName")
        startCollecting(gestureName)
    }

    private fun stopCollecting() {
        Log.d("HandDetectionPlatformView", "Stopping collection.")
        isCollecting = false

        if (collectedFrames.isNotEmpty()) {
            val gestureName = currentGestureName ?: "unknown"
            Log.d("HandDetectionPlatformView", "Uploading ${collectedFrames.size} frames for gesture: $gestureName")
            trainingCoordinator?.uploadAndTrain(gestureName, collectedFrames)
        }
        
        currentGestureName = null
        // Optionally, send a signal to Flutter that collection has stopped
        mainHandler.post {
            methodChannel.invokeMethod("collectionComplete", null)
        }
    }

    // 저장하기 버튼 클릭 시 호출될 새로운 메서드
    fun uploadCollectedData() {
        if (collectedFrames.isNotEmpty()) {
            val gestureName = currentGestureName ?: "unknown"
            Log.d("HandDetectionPlatformView", "Now uploading ${collectedFrames.size} frames for gesture: $gestureName")
            trainingCoordinator?.uploadAndTrain(gestureName, collectedFrames)
        } else {
            Log.w("HandDetectionPlatformView", "No frames to upload")
        }
        
        // 업로드 후 데이터 정리
        collectedFrames.clear()
        currentGestureName = null
    }

    // TrainingCoordinator에서 task_id를 받았을 때 Flutter에 알림
    fun notifyTaskIdReady(taskId: String) {
        Log.d("HandDetectionPlatformView", "Task ID ready: $taskId, notifying Flutter")
        mainHandler.post {
            methodChannel.invokeMethod("taskIdReady", mapOf("taskId" to taskId))
        }
    }

    // TrainingService에서 제스처 목록 새로고침 요청 시 Flutter에 알림
    fun notifyGestureListRefresh() {
        Log.d("HandDetectionPlatformView", "Notifying Flutter to refresh gesture list")
        mainHandler.post {
            // GestureSettingsPage의 메소드 채널을 통해 알림
            val gestureSettingsChannel = MethodChannel(binaryMessenger, "com.pentagon.ghostouch/toggle")
            gestureSettingsChannel.invokeMethod("refreshGestureList", null)
        }
    }

    private fun showPermissionRequiredView() {
        val linearLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(60, 60, 60, 60)
        }

        val textView = TextView(context).apply {
            text = "카메라 권한이 필요합니다.\n손 제스처 인식을 위해 카메라 접근 권한을 허용해주세요."
            textSize = 18f
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            setPadding(0, 0, 0, 40)
            setLineSpacing(8f, 1.2f)
        }

        val settingsButton = Button(context).apply {
            text = "설정에서 권한 허용하기"
            textSize = 16f
            setPadding(40, 20, 40, 20)
            setOnClickListener {
                openAppSettings()
            }
        }

        val refreshButton = Button(context).apply {
            text = "권한 허용 후 새로고침"
            textSize = 16f
            setPadding(40, 20, 40, 20)
            setOnClickListener {
                checkPermissionAndSetupCamera()
            }
        }

        linearLayout.addView(textView)
        linearLayout.addView(settingsButton)
        linearLayout.addView(refreshButton)

        containerView.addView(linearLayout, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    private fun checkPermissionAndSetupCamera() {
        if (PermissionsFragment.hasPermissions(context)) {
            containerView.removeAllViews()
            setupCamera()
        } else {
            val textView = TextView(context).apply {
                text = "아직 카메라 권한이 허용되지 않았습니다.\n설정에서 권한을 허용한 후 다시 시도해주세요."
                textSize = 16f
                textAlignment = View.TEXT_ALIGNMENT_CENTER
                setPadding(40, 40, 40, 40)
                setLineSpacing(8f, 1.2f)
            }

            containerView.removeAllViews()
            containerView.addView(textView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))

            containerView.postDelayed({
                containerView.removeAllViews()
                showPermissionRequiredView()
            }, 3000)
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
            containerView.addView(previewView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))

            overlayView = OverlayView(context, null)
            containerView.addView(overlayView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))

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
            .build()
            .also {
                it.setAnalyzer(backgroundExecutor) { imageProxy ->
                    if (handLandmarkerHelper?.isClose() == false) {
                        detectHand(imageProxy)
                    }
                }
            }

        cameraProvider.unbindAll()

        try {
            // 직접 전달받은 activity 사용
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
        val handLandmarkerResult = resultBundle.results.firstOrNull()
        if (handLandmarkerResult != null) {
            // Collect frames if collecting is enabled
            if (isCollecting) {
                totalFrameAttempts++
                Log.d("HandDetectionPlatformView", "Collection attempt #$totalFrameAttempts")
                
                val worldLandmarks = handLandmarkerResult.worldLandmarks().firstOrNull()
                val handedness = handLandmarkerResult.handedness().firstOrNull()?.firstOrNull()
                
                Log.d("HandDetectionPlatformView", "WorldLandmarks size: ${worldLandmarks?.size ?: 0}, Required: 21")
                
                if (worldLandmarks != null && worldLandmarks.size == 21) {
                    // MediaPipe handedness confidence 확인
                    val confidence = handedness?.score() ?: 0.0f
                    Log.d("HandDetectionPlatformView", "Handedness confidence: ${String.format("%.2f", confidence)}, Threshold: $MIN_CONFIDENCE_THRESHOLD")
                    
                    if (confidence >= MIN_CONFIDENCE_THRESHOLD) {
                        val flatLandmarks = worldLandmarks.map { listOf(it.x(), it.y(), it.z()) }.flatten()
                        val handednessValue = when (handedness?.categoryName()) {
                            "Left" -> 0.0f // 왼손
                            "Right" -> 1.0f // 오른손
                            else -> -1.0f // 알 수 없는 경우 (오류 방지 또는 처리 필요)
                        }
                        val fullLandmarkVector = flatLandmarks.toMutableList().apply { add(handednessValue) }
                        collectedFrames.add(fullLandmarkVector)
                        
                        Log.d("HandDetectionPlatformView", "Frame accepted: ${collectedFrames.size}/$TARGET_FRAME_COUNT (confidence: ${String.format("%.2f", confidence)})")
                        
                        // Send progress update to Flutter
                        val progress = (collectedFrames.size / TARGET_FRAME_COUNT.toDouble() * 100).toInt().coerceAtMost(100)
                        mainHandler.post {
                            methodChannel.invokeMethod("updateProgress", progress)
                        }

                        // Auto-complete when target frames are collected
                        if (collectedFrames.size >= TARGET_FRAME_COUNT) {
                            Log.d("HandDetectionPlatformView", "Target frames ($TARGET_FRAME_COUNT) collected from $totalFrameAttempts attempts. Auto-completing collection.")
                            // stopCollecting() 메소드 호출로 서버 업로드도 함께 처리
                            stopCollecting()
                        }
                    } else {
                        Log.d("HandDetectionPlatformView", "Frame rejected: Low confidence (${String.format("%.2f", confidence)} < $MIN_CONFIDENCE_THRESHOLD)")
                    }
                } else {
                    Log.d("HandDetectionPlatformView", "Frame rejected: Hand not detected or incomplete landmarks (${worldLandmarks?.size ?: 0}/21)")
                }
            } else {
                Log.d("HandDetectionPlatformView", "Not collecting (isCollecting: $isCollecting)")
            }

            // 학습 중이 아닐 때만 제스처 분류 수행
            val gesture = if (isCollecting) {
                "none" // 학습 중일 때는 제스처명 표시 안함
            } else {
                gestureClassifier?.classifyGesture(handLandmarkerResult) ?: "none"
            }

            overlayView?.post {
                overlayView?.setResults(
                    handLandmarkerResult,
                    resultBundle.inputImageHeight,
                    resultBundle.inputImageWidth,
                    RunningMode.LIVE_STREAM,
                    gesture,
                    isFrontCamera = true, // Assuming front camera is always used here
                    rotationDegrees = resultBundle.rotationDegrees,
                    handednesses = handLandmarkerResult.handednesses()
                )
            }
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
        containerView.addView(textView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
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