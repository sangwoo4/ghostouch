package com.pentagon.ghostouch.channels

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry
import org.json.JSONObject
import java.io.File
import com.pentagon.ghostouch.gesture.training.TrainingCoordinator
import com.pentagon.ghostouch.gesture.detection.GestureDetectionService
import com.pentagon.ghostouch.ui.camera.HandDetectionViewFactory
import com.pentagon.ghostouch.ui.camera.HandDetectionPlatformView
import com.pentagon.ghostouch.ui.permissions.PermissionsFragment

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.pentagon.ghostouch/toggle"
    private lateinit var trainingCoordinator: TrainingCoordinator
    private lateinit var toggleChannel: MethodChannel
    
    // Channel Handlers
    private lateinit var gestureChannelHandler: GestureChannelHandler
    private lateinit var trainingChannelHandler: TrainingChannelHandler
    private lateinit var handDetectionChannelHandler: HandDetectionChannelHandler
    private lateinit var utilityChannelHandler: UtilityChannelHandler
    
    // 토글 상태 변경 브로드캐스트 리시버
    private val toggleStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.pentagon.ghostouch.TOGGLE_STATE_CHANGED") {
                val newState = intent.getBooleanExtra("state", false)
                runCatching {
                    toggleChannel.invokeMethod("onToggleStateChanged", newState)
                    android.util.Log.d("MainActivity", "Toggle state changed: $newState")
                }.onFailure { android.util.Log.e("MainActivity", "Failed to notify Flutter", it) }
            }
        }
    }
    
    companion object {
        var handDetectionPlatformView: HandDetectionPlatformView? = null
        var pendingGestureName: String? = null // 대기 중인 제스처 이름
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        trainingCoordinator = TrainingCoordinator(this)
        
        // Initialize channel handlers
        gestureChannelHandler = GestureChannelHandler(this)
        trainingChannelHandler = TrainingChannelHandler(trainingCoordinator)
        handDetectionChannelHandler = HandDetectionChannelHandler(
            this,
            { handDetectionPlatformView },
            { pendingGestureName = it },
            { pendingGestureName }
        )
        utilityChannelHandler = UtilityChannelHandler(this)

        // 네이티브 뷰 팩토리 등록
        flutterEngine.platformViewsController.registry
            .registerViewFactory("hand_detection_view", HandDetectionViewFactory(this, flutterEngine.dartExecutor.binaryMessenger))

        // 채널들 초기화
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        toggleChannel = MethodChannel(messenger, CHANNEL).apply {
            setMethodCallHandler { call, result -> utilityChannelHandler.handleToggle(call, result) { getAvailableGestures() } }
        }
        
        // 매핑 채널
        MethodChannel(messenger, "com.pentagon.ghostouch/mapping").setMethodCallHandler { call, result ->
            gestureChannelHandler.handleMapping(call, result)
        }
        
        // 훈련 채널
        MethodChannel(messenger, "com.pentagon.ghostouch/training").setMethodCallHandler { call, result ->
            trainingChannelHandler.handleTraining(call, result)
        }
        
        // 태스크 ID 채널
        MethodChannel(messenger, "com.pentagon.gesture/task-id").setMethodCallHandler { call, result ->
            utilityChannelHandler.handleTaskId(call, result)
        }

        // Hand Detection 채널
        MethodChannel(messenger, "com.pentagon.ghostouch/hand_detection").setMethodCallHandler { call, result ->
            when (call.method) {
                "startCollecting" -> handleStartCollecting(call, result)
                "stopCollecting" -> result.success(null)
                "saveGesture" -> handleSaveGesture(call, result)
                else -> result.notImplemented()
            }
        }

        // 제스처 리스트 채널
        MethodChannel(messenger, "com.pentagon.ghostouch/list-gesture").setMethodCallHandler { call, result ->
            when (call.method) {
                "list-gesture" -> runCatching {
                    result.success(getAvailableGestures().keys.map { getKoreanGestureName(it) })
                }.onFailure { result.error("ERROR", "Failed to get gesture list: ${it.message}", null) }
                "check-duplicate" -> handleDuplicateCheck(call, result)
                else -> result.notImplemented()
            }
        }
        
        // 제스처 리셋 채널
        MethodChannel(messenger, "com.pentagon.ghostouch/reset-gesture").setMethodCallHandler { call, result ->
            when (call.method) {
                "reset" -> runCatching {
                    resetToOriginalModel()
                    result.success("제스처가 초기화되었습니다.")
                }.onFailure { result.error("ERROR", "Failed to reset gestures: ${it.message}", null) }
                else -> result.notImplemented()
            }
        }
        
        // 컨트롤 앱 채널
        MethodChannel(messenger, "com.pentagon.ghostouch/control-app").setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName != null) {
                        runCatching {
                            openExternalApp(packageName)
                            result.success("App launched successfully")
                        }.onFailure { result.error("LAUNCH_FAILED", "Failed to launch app: ${it.message}", null) }
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // 백그라운드 채널
        MethodChannel(messenger, "com.pentagon.ghostouch/background").setMethodCallHandler { call, result ->
            utilityChannelHandler.handleBackground(call, result)
        }
    }

    private fun handleStartCollecting(call: MethodCall, result: MethodChannel.Result) {
        val gestureName = call.argument<String>("gestureName")
        if (gestureName != null) {
            handDetectionPlatformView?.startCollectingFromMainActivity(gestureName)
                ?: run { pendingGestureName = gestureName }
            result.success(null)
        } else {
            result.error("INVALID_ARGUMENT", "Gesture name is required", null)
        }
    }
    
    private fun handleSaveGesture(call: MethodCall, result: MethodChannel.Result) {
        val gestureName = call.argument<String>("gestureName")
        if (gestureName != null) {
            runCatching {
                handDetectionPlatformView?.uploadCollectedData()
                result.success("Gesture '$gestureName' upload started successfully")
            }.onFailure { result.error("SAVE_FAILED", "Failed to save gesture: ${it.message}", null) }
        } else {
            result.error("INVALID_ARGUMENT", "Gesture name is required", null)
        }
    }
    
    private fun handleDuplicateCheck(call: MethodCall, result: MethodChannel.Result) {
        val gestureName = call.argument<String>("gestureName")
        if (gestureName != null) {
            val trimmedName = gestureName.trim()
            val validationResult = validateGestureName(trimmedName)
            if (validationResult.first) {
                result.success(mapOf("isDuplicate" to true, "message" to validationResult.second))
                return
            }
            
            val gestureMap = getAvailableGestures()
            val isDuplicate = checkGestureDuplicate(trimmedName, gestureMap)
            result.success(mapOf(
                "isDuplicate" to isDuplicate,
                "message" to if (isDuplicate) "이미 등록된 이름입니다." else "등록할 수 있는 이름입니다."
            ))
        } else {
            result.error("INVALID_ARGUMENT", "Gesture name is required", null)
        }
    }
    
    private fun validateGestureName(name: String): Pair<Boolean, String> {
        return when {
            name.isEmpty() -> true to "공백은 등록할 수 없습니다."
            name.length > 20 -> true to "제스처 이름은 20자 이하로 입력해주세요."
            listOf("/", "\\", ":", "*", "?", "\"", "<", ">", "|").any { name.contains(it) } -> 
                true to "특수문자는 사용할 수 없습니다."
            else -> false to ""
        }
    }
    
    private fun checkGestureDuplicate(name: String, gestureMap: Map<String, String>): Boolean {
        val koreanGestureList = gestureMap.keys.map { getKoreanGestureName(it) }
        val pureGestureNames = koreanGestureList.map { it.replace(" 제스처", "").trim() }
        val inputWithoutGesture = name.replace(" 제스처", "").trim()
        
        return koreanGestureList.contains(name) || 
               gestureMap.keys.contains(name) || 
               pureGestureNames.contains(inputWithoutGesture)
    }

    private fun getAvailableGestures(): Map<String, String> = runCatching {
        val labelMapFile = File(filesDir, "updated_label_map.json")
        val jsonString = if (labelMapFile.exists()) {
            labelMapFile.readText()
        } else {
            assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
        }
        
        JSONObject(jsonString).keys().asSequence().associateWith { it }
    }.getOrElse {
        android.util.Log.e("MainActivity", "Failed to load gesture map: ${it.message}")
        mapOf("scissors" to "scissors", "rock" to "rock", "paper" to "paper", "hs" to "hs")
    }

    private fun getKoreanGestureName(englishKey: String): String = mapOf(
        "scissors" to "가위 제스처", "rock" to "주먹 제스처", 
        "paper" to "보 제스처", "hs" to "한성대 제스처"
    )[englishKey] ?: "$englishKey 제스처"

    private fun resetToOriginalModel() {
        val originalModelFile = File(filesDir, "basic_gesture_model.tflite")
        if (!originalModelFile.exists()) {
            assets.open("basic_gesture_model.tflite").use { it.copyTo(originalModelFile.outputStream()) }
        }
        
        File(filesDir, "updated_label_map.json").delete()
        
        TrainingCoordinator.apply {
            currentModelCode = "base_v1"
            currentModelFileName = "basic_gesture_model.tflite"
        }
        
        getSharedPreferences(TrainingCoordinator.PREFS_NAME, MODE_PRIVATE).edit()
            .putString(TrainingCoordinator.MODEL_CODE_PREFS_KEY, "base_v1")
            .putString(TrainingCoordinator.MODEL_FILENAME_PREFS_KEY, "basic_gesture_model.tflite")
            .apply()
            
        startService(Intent(this, GestureDetectionService::class.java).apply {
            action = "ACTION_RELOAD_MODEL"
        })
    }

    private fun openExternalApp(packageIdentifier: String) {
        val url = mapOf(
            "youtube" to "https://www.youtube.com",
            "netflix" to "https://www.netflix.com", 
            "coupang" to "https://www.coupangplay.com",
            "tving" to "https://www.tving.com",
            "disney" to "https://www.disneyplus.com",
            "tmap" to "https://www.tmap.co.kr",
            "kakaomap" to "https://map.kakao.com"
        )[packageIdentifier] ?: "https://www.google.com/search?q=$packageIdentifier"
        
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val filter = IntentFilter("com.pentagon.ghostouch.TOGGLE_STATE_CHANGED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(toggleStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(toggleStateReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        runCatching { unregisterReceiver(toggleStateReceiver) }
    }

    override fun onStart() {
        super.onStart()
        GestureDetectionService.isAppInForeground = true
    }

    override fun onStop() {
        super.onStop()
        GestureDetectionService.isAppInForeground = false
        runCatching {
            startService(Intent(this, GestureDetectionService::class.java).apply {
                action = "ACTION_APP_WENT_BACKGROUND"
            })
        }
    }

    override fun onResume() {
        super.onResume()
        GestureDetectionService.isAppInForeground = true
    }

    override fun onPause() = super.onPause()
}
