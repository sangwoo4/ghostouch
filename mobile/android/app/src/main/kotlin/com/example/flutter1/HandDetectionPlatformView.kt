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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class HandDetectionPlatformView(
    private val context: Context,
    viewId: Int,
    args: Any?,
    private val activity: FlutterActivity
) : PlatformView, HandLandmarkerHelper.LandmarkerListener {

    private val containerView: FrameLayout = FrameLayout(context)
    private var previewView: PreviewView? = null
    private var overlayView: OverlayView? = null
    private var handLandmarkerHelper: HandLandmarkerHelper? = null
    private var gestureClassifier: GestureClassifier? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private lateinit var backgroundExecutor: ExecutorService

    init {
        setupView()
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
                it.setAnalyzer(backgroundExecutor) { image ->
                    detectHand(image)
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
        cameraProvider?.unbindAll()
        handLandmarkerHelper?.clearHandLandmarker()
        gestureClassifier?.close()
    }
}