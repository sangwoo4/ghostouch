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

    // Data collection state
    private var isCollecting: Boolean = false
    private var collectedFrames: MutableList<List<Float>> = mutableListOf()
    private var currentGestureName: String? = null

    init {
        setupView()
        setupMethodChannel()
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
                else -> result.notImplemented()
            }
        }
    }

    private fun startCollecting(gestureName: String) {
        Log.d("HandDetectionPlatformView", "Starting collection for gesture: $gestureName")
        isCollecting = true
        currentGestureName = gestureName
        collectedFrames.clear()
        // Optionally, send a signal to Flutter that collection has started
        mainHandler.post {
            methodChannel.invokeMethod("collectionStarted", null)
        }
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
                trainingCoordinator = TrainingCoordinator(context, object : TrainingCoordinator.TrainingListener {
                    override fun onModelReady() {
                        Log.d("HandDetectionPlatformView", "New model is ready. Reloading HandLandmarkerHelper and GestureClassifier.")
                        // Optionally, notify Flutter that a new model is ready
                        mainHandler.post {
                            methodChannel.invokeMethod("modelReady", null)
                        }
                        // Reinitialize HandLandmarkerHelper to load the new model
                        handLandmarkerHelper?.clearHandLandmarker()
                        handLandmarkerHelper = HandLandmarkerHelper(
                            context = context,
                            runningMode = RunningMode.LIVE_STREAM,
                            handLandmarkerHelperListener = this@HandDetectionPlatformView
                        )
                        // Reinitialize GestureClassifier to load the new label map
                        gestureClassifier?.close()
                        gestureClassifier = GestureClassifier(context)
                    }
                })
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
                val worldLandmarks = handLandmarkerResult.worldLandmarks().firstOrNull()
                if (worldLandmarks != null) {
                    val flatLandmarks = worldLandmarks.map { listOf(it.x(), it.y(), it.z()) }.flatten()
                    collectedFrames.add(flatLandmarks)

                    // Send progress update to Flutter
                    val progress = (collectedFrames.size / 100.0 * 100).toInt().coerceAtMost(100)
                    mainHandler.post {
                        methodChannel.invokeMethod("updateProgress", progress)
                    }

                    // Auto-complete when 100 frames are collected
                    if (collectedFrames.size >= 100) {
                        Log.d("HandDetectionPlatformView", "100 frames collected. Auto-completing collection.")
                        isCollecting = false
                        mainHandler.post {
                            methodChannel.invokeMethod("collectionComplete", null)
                        }
                    }
                }
            }

            val gesture = gestureClassifier?.classifyGesture(handLandmarkerResult)

            overlayView?.post {
                overlayView?.setResults(
                    handLandmarkerResult,
                    resultBundle.inputImageHeight,
                    resultBundle.inputImageWidth,
                    RunningMode.LIVE_STREAM,
                    gesture ?: "none",
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
        trainingCoordinator?.shutdown()
    }
} 