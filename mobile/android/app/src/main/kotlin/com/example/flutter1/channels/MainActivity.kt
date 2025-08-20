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
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry
import org.json.JSONObject
import java.io.File
import com.pentagon.ghostouch.gesture.TrainingCoordinator
import com.pentagon.ghostouch.gesture.GestureDetectionService
import com.pentagon.ghostouch.ui.HandDetectionViewFactory
import com.pentagon.ghostouch.ui.HandDetectionPlatformView
import com.pentagon.ghostouch.ui.PermissionsFragment

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
                android.util.Log.d("MainActivity", "Received toggle state broadcast: $newState")
                
                // Flutter에 즉시 알림
                try {
                    toggleChannel.invokeMethod("onToggleStateChanged", newState)
                    android.util.Log.d("MainActivity", "Notified Flutter about toggle state change: $newState")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to notify Flutter", e)
                }
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
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("hand_detection_view", HandDetectionViewFactory(this, flutterEngine.dartExecutor.binaryMessenger))

        // 토글 채널 초기화
        toggleChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        toggleChannel.setMethodCallHandler { call, result ->
            utilityChannelHandler.handleToggle(call, result) { getAvailableGestures() }
        }

        // 제스처-액션 매핑을 위한 새로운 MethodChannel
        val MAPPING_CHANNEL = "com.pentagon.ghostouch/mapping"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPPING_CHANNEL).setMethodCallHandler { call, result ->
            gestureChannelHandler.handleMapping(call, result)
        }

        // 학습 관련 MethodChannel
        val TRAINING_CHANNEL = "com.pentagon.ghostouch/training"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRAINING_CHANNEL).setMethodCallHandler { call, result ->
            trainingChannelHandler.handleTraining(call, result)
        }

        // Task ID 관련 MethodChannel 
        val TASK_ID_CHANNEL = "com.pentagon.gesture/task-id"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_ID_CHANNEL).setMethodCallHandler { call, result ->
            utilityChannelHandler.handleTaskId(call, result)
        }

        // Hand Detection 관련 MethodChannel - MainActivity에서 직접 처리
        val HAND_DETECTION_CHANNEL = "com.pentagon.ghostouch/hand_detection"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAND_DETECTION_CHANNEL).setMethodCallHandler { call, result ->
            android.util.Log.d("MainActivity", "Hand detection method called: ${call.method}")
            when (call.method) {
                "startCollecting" -> {
                    val gestureName = call.argument<String>("gestureName")
                    android.util.Log.d("MainActivity", "startCollecting called with gesture: $gestureName")
                    if (gestureName != null) {
                        // PlatformView에 직접 호출 또는 대기열에 저장
                        handDetectionPlatformView?.let { platformView ->
                            android.util.Log.d("MainActivity", "Calling startCollecting on PlatformView")
                            platformView.startCollectingFromMainActivity(gestureName)
                            result.success(null)
                        } ?: run {
                            android.util.Log.d("MainActivity", "PlatformView not ready, saving gesture for later: $gestureName")
                            pendingGestureName = gestureName
                            result.success(null) // 일단 성공으로 응답
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Gesture name is required", null)
                    }
                }
                "stopCollecting" -> {
                    android.util.Log.d("MainActivity", "stopCollecting called")
                    result.success(null)
                }
                "saveGesture" -> {
                    val gestureName = call.argument<String>("gestureName")
                    android.util.Log.d("MainActivity", "saveGesture called with gesture: $gestureName")
                    if (gestureName != null) {
                        try {
                            // 1. 수집된 데이터 서버로 업로드 시작
                            handDetectionPlatformView?.uploadCollectedData()
                            
                            // 2. 업데이트된 레이블 맵 파일 로드 (나중에 확인용)
                            val updatedLabelMapFile = File(filesDir, "updated_label_map.json")
                            if (updatedLabelMapFile.exists()) {
                                android.util.Log.d("MainActivity", "Updated label map found, gesture '$gestureName' should already be included")
                            } else {
                                android.util.Log.w("MainActivity", "Updated label map not found, gesture might not be properly saved")
                            }
                            
                            // 3. 모델 파일 확인
                            val currentModelCode = TrainingCoordinator.currentModelCode
                            val currentModelFileName = TrainingCoordinator.currentModelFileName
                            android.util.Log.d("MainActivity", "Current model: $currentModelCode ($currentModelFileName)")
                            
                            // 4. 성공 응답
                            result.success("Gesture '$gestureName' upload started successfully")
                            android.util.Log.d("MainActivity", "Gesture '$gestureName' upload process started")
                            
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Failed to save gesture '$gestureName'", e)
                            result.error("SAVE_FAILED", "Failed to save gesture: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Gesture name is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // GestureRegisterPage용 MethodChannel들
        val LIST_GESTURE_CHANNEL = "com.pentagon.ghostouch/list-gesture"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIST_GESTURE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "list-gesture" -> {
                    try {
                        val gestureMap = getAvailableGestures()
                        val gestureList = gestureMap.keys.map { getKoreanGestureName(it) }
                        result.success(gestureList)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get gesture list: ${e.message}", null)
                    }
                }
                "check-duplicate" -> {
                    try {
                        val gestureName = call.argument<String>("gestureName")
                        if (gestureName != null) {
                            val trimmedName = gestureName.trim()
                            
                            // 1. 공백 체크
                            if (trimmedName.isEmpty()) {
                                result.success(mapOf(
                                    "isDuplicate" to true,
                                    "message" to "공백은 등록할 수 없습니다."
                                ))
                                return@setMethodCallHandler
                            }
                            
                            // 2. 특수문자 및 길이 체크
                            if (trimmedName.length > 20) {
                                result.success(mapOf(
                                    "isDuplicate" to true,
                                    "message" to "제스처 이름은 20자 이하로 입력해주세요."
                                ))
                                return@setMethodCallHandler
                            }
                            
                            // 3. 금지된 문자 체크 (선택사항)
                            val forbiddenChars = listOf("/", "\\", ":", "*", "?", "\"", "<", ">", "|")
                            if (forbiddenChars.any { trimmedName.contains(it) }) {
                                result.success(mapOf(
                                    "isDuplicate" to true,
                                    "message" to "특수문자는 사용할 수 없습니다."
                                ))
                                return@setMethodCallHandler
                            }
                            
                            // 4. 실제 중복 체크
                            val gestureMap = getAvailableGestures()
                            val koreanGestureList = gestureMap.keys.map { getKoreanGestureName(it) }
                            
                            // 영어 키도 확인 (서버로 전송될 때는 영어 키 사용)
                            val englishGestureList = gestureMap.keys.toList()
                            
                            // "제스처" 부분을 제거한 순수 이름 리스트
                            val pureGestureNames = koreanGestureList.map { it.replace(" 제스처", "").trim() }
                            val inputWithoutGesture = trimmedName.replace(" 제스처", "").trim()
                            
                            // 디버깅 로그
                            android.util.Log.d("MainActivity", "Available Korean gestures: $koreanGestureList")
                            android.util.Log.d("MainActivity", "Available English gestures: $englishGestureList")
                            android.util.Log.d("MainActivity", "Pure gesture names: $pureGestureNames")
                            android.util.Log.d("MainActivity", "Checking duplicate for: '$trimmedName'")
                            android.util.Log.d("MainActivity", "Input without '제스처': '$inputWithoutGesture'")
                            
                            // 중복 검사: 전체 이름, 영어 키, 순수 이름 모두 확인
                            val isDuplicateKorean = koreanGestureList.contains(trimmedName)
                            val isDuplicateEnglish = englishGestureList.contains(trimmedName)
                            val isDuplicatePure = pureGestureNames.contains(inputWithoutGesture)
                            val isDuplicate = isDuplicateKorean || isDuplicateEnglish || isDuplicatePure
                            
                            android.util.Log.d("MainActivity", "Is duplicate (Korean): $isDuplicateKorean")
                            android.util.Log.d("MainActivity", "Is duplicate (English): $isDuplicateEnglish")
                            android.util.Log.d("MainActivity", "Is duplicate (Pure): $isDuplicatePure")
                            android.util.Log.d("MainActivity", "Is duplicate (Final): $isDuplicate")
                            
                            result.success(mapOf(
                                "isDuplicate" to isDuplicate,
                                "message" to if (isDuplicate) "이미 등록된 이름입니다." else "등록할 수 있는 이름입니다."
                            ))
                        } else {
                            result.error("INVALID_ARGUMENT", "Gesture name is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to check duplicate: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        val RESET_GESTURE_CHANNEL = "com.pentagon.ghostouch/reset-gesture"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RESET_GESTURE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "reset" -> {
                    try {
                        resetToOriginalModel()
                        result.success("제스처가 초기화되었습니다.")
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to reset gestures: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ControlAppPage용 MethodChannel
        val CONTROL_APP_CHANNEL = "com.pentagon.ghostouch/control-app"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_APP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openApp" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName != null) {
                        try {
                            openExternalApp(packageName)
                            result.success("App launched successfully")
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", "Failed to launch app: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 백그라운드 자동 꺼짐 기능용 MethodChannel
        val BACKGROUND_CHANNEL = "com.pentagon.ghostouch/background"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBackgroundTimeout" -> {
                    val minutes = call.argument<Int>("minutes")
                    if (minutes != null) {
                        try {
                            // -1은 10초 테스트 모드를 의미
                            val actualMinutes = minutes
                            
                            // SharedPreferences에 설정 저장
                            val prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
                            prefs.edit().putInt("background_timeout_minutes", actualMinutes).apply()
                            
                            // GestureDetectionService에 설정 전달
                            val intent = Intent(this, GestureDetectionService::class.java)
                            intent.action = "ACTION_SET_BACKGROUND_TIMEOUT"
                            intent.putExtra("timeout_minutes", actualMinutes)
                            startService(intent)
                            
                            android.util.Log.d("MainActivity", "Background timeout set to $actualMinutes minutes")
                            result.success("Background timeout set successfully")
                        } catch (e: Exception) {
                            android.util.Log.e("MainActivity", "Failed to set background timeout", e)
                            result.error("SET_TIMEOUT_FAILED", "Failed to set timeout: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Minutes argument is required", null)
                    }
                }
                "getBackgroundTimeout" -> {
                    try {
                        val prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
                        val minutes = prefs.getInt("background_timeout_minutes", 0) // 기본값 0 (설정 안 함)
                        result.success(minutes)
                    } catch (e: Exception) {
                        result.error("GET_TIMEOUT_FAILED", "Failed to get timeout: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun getAvailableGestures(): Map<String, String> {
        val gestureMap = mutableMapOf<String, String>()
        
        try {
            // 먼저 업데이트된 레이블 맵 파일이 있는지 확인
            val updatedLabelMapFile = File(filesDir, "updated_label_map.json")
            val jsonString: String
            
            if (updatedLabelMapFile.exists()) {
                jsonString = updatedLabelMapFile.readText()
            } else {
                // 기본 레이블 맵 파일 사용
                jsonString = assets.open("basic_label_map.json").bufferedReader().use { it.readText() }
            }
            
            val jsonObject = JSONObject(jsonString)
            val iterator = jsonObject.keys()
            
            while (iterator.hasNext()) {
                val key = iterator.next()
                val value = jsonObject.getInt(key)
                gestureMap[key] = key // 영어 키를 그대로 사용
            }
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to load gesture map: ${e.message}")
            // 오류 발생 시 기본 제스처들만 반환
            gestureMap["scissors"] = "scissors"
            gestureMap["rock"] = "rock"
            gestureMap["paper"] = "paper"
            gestureMap["hs"] = "hs"
        }
        
        return gestureMap
    }

    private fun getKoreanGestureName(englishKey: String): String {
        // 기본 제스처들의 한글 매핑
        val defaultMapping = mapOf(
            "scissors" to "가위 제스처",
            "rock" to "주먹 제스처", 
            "paper" to "보 제스처",
            "hs" to "한성대 제스처"
        )
        
        // 기본 매핑에 있으면 해당 한글명 반환, 없으면 사용자 정의 제스처로 표시
        return defaultMapping[englishKey] ?: "$englishKey 제스처"
    }

    private fun resetToOriginalModel() {
        try {
            // 1. 기본 모델 파일로 복원
            val originalModelFile = File(filesDir, "basic_gesture_model.tflite")
            if (!originalModelFile.exists()) {
                // assets에서 기본 모델 복사
                assets.open("basic_gesture_model.tflite").use { inputStream ->
                    originalModelFile.outputStream().use { outputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }
                android.util.Log.d("MainActivity", "Original model restored from assets")
            }

            // 2. 기본 레이블 맵으로 복원
            val labelMapFile = File(filesDir, "updated_label_map.json")
            if (labelMapFile.exists()) {
                labelMapFile.delete()
            }
            android.util.Log.d("MainActivity", "Updated label map deleted, will use basic_label_map.json")

            // 3. 모델 정보 초기화
            TrainingCoordinator.currentModelCode = "base_v1"
            TrainingCoordinator.currentModelFileName = "basic_gesture_model.tflite"
            
            val prefs = getSharedPreferences(TrainingCoordinator.PREFS_NAME, MODE_PRIVATE)
            prefs.edit()
                .putString(TrainingCoordinator.MODEL_CODE_PREFS_KEY, "base_v1")
                .putString(TrainingCoordinator.MODEL_FILENAME_PREFS_KEY, "basic_gesture_model.tflite")
                .apply()

            // 4. 제스처 서비스에 모델 리로드 알림
            val intent = Intent(this, GestureDetectionService::class.java)
            intent.action = "ACTION_RELOAD_MODEL"
            startService(intent)

            android.util.Log.d("MainActivity", "Gesture model reset to original successfully")
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to reset gesture model", e)
            throw e
        }
    }

    private fun openExternalApp(packageIdentifier: String) {
        try {
            android.util.Log.d("MainActivity", "Opening service: $packageIdentifier")
            
            // 각 서비스의 웹사이트 URL로 브라우저에서 열기
            val url = when (packageIdentifier) {
                "youtube" -> "https://www.youtube.com"
                "netflix" -> "https://www.netflix.com"
                "coupang" -> "https://www.coupangplay.com"
                "tving" -> "https://www.tving.com"
                "disney" -> "https://www.disneyplus.com"
                "tmap" -> "https://www.tmap.co.kr"
                "kakaomap" -> "https://map.kakao.com"
                else -> "https://www.google.com/search?q=$packageIdentifier"
            }

            android.util.Log.d("MainActivity", "Opening URL: $url")

            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            
            android.util.Log.d("MainActivity", "Successfully opened: $packageIdentifier in browser")
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to open service: $packageIdentifier", e)
            throw e
        }
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 브로드캐스트 리시버 등록 (API 33+ 대응)
        val filter = IntentFilter("com.pentagon.ghostouch.TOGGLE_STATE_CHANGED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(toggleStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(toggleStateReceiver, filter)
        }
        android.util.Log.d("MainActivity", "Broadcast receiver registered")
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(toggleStateReceiver)
            android.util.Log.d("MainActivity", "Broadcast receiver unregistered")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to unregister receiver", e)
        }
    }

    override fun onStart() {
        super.onStart()
        GestureDetectionService.isAppInForeground = true
        android.util.Log.d("MainActivity", "onStart: isAppInForeground set to TRUE")
    }

    override fun onStop() {
        super.onStop()
        GestureDetectionService.isAppInForeground = false
        android.util.Log.d("MainActivity", "onStop: isAppInForeground set to FALSE - background timer should start")
        
        // 서비스에 직접 백그라운드 상태 알림
        try {
            val intent = Intent(this, GestureDetectionService::class.java)
            intent.action = "ACTION_APP_WENT_BACKGROUND"
            startService(intent)
            android.util.Log.d("MainActivity", "Sent background notification to service")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to notify service about background state", e)
        }
    }

    override fun onResume() {
        super.onResume()
        GestureDetectionService.isAppInForeground = true
        android.util.Log.d("MainActivity", "onResume: isAppInForeground set to TRUE")
    }

    override fun onPause() {
        super.onPause()
        android.util.Log.d("MainActivity", "onPause called (but using onStop for background detection)")
    }
}