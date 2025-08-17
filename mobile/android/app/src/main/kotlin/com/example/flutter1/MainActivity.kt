package com.pentagon.ghostouch

import android.Manifest
import android.content.Intent
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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.pentagon.ghostouch/toggle"
    private lateinit var trainingCoordinator: TrainingCoordinator
    
    companion object {
        var handDetectionPlatformView: HandDetectionPlatformView? = null
        var pendingGestureName: String? = null // 대기 중인 제스처 이름
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        trainingCoordinator = TrainingCoordinator(this)

        // 네이티브 뷰 팩토리 등록
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("hand_detection_view", HandDetectionViewFactory(this, flutterEngine.dartExecutor.binaryMessenger))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startGestureService" -> {
                    val intent = Intent(this, GestureDetectionService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopGestureService" -> {
                    val intent = Intent(this, GestureDetectionService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                "checkCameraPermission" -> {
                    val hasPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPermission)
                }
                "functionToggle" -> {
                    println("✅ functionToggle 호출됨 (안드로이드)")
                    result.success(null)
                }
                "openSettings" -> {
                    println("⚙️ openSettings 호출됨")
                    openAppSettings()
                    result.success(null)
                }
                "setToggleState" -> {
                    val state = call.argument<Boolean>("state")
                    if (state != null) {
                        val prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
                        prefs.edit().putBoolean("toggle_state", state).apply()
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "State argument is missing", null)
                    }
                }
                "getToggleState" -> {
                    val prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
                    val state = prefs.getBoolean("toggle_state", false) // 기본값 false
                    result.success(state)
                }
                "getAvailableGestures" -> {
                    try {
                        val gestureMap = getAvailableGestures()
                        result.success(gestureMap)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get available gestures: ${e.message}", null)
                    }
                }
                "getServerUrl" -> {
                    try {
                        val serverUrl = TrainingCoordinator.getServerUrl(this)
                        result.success(serverUrl)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get server URL: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 제스처-액션 매핑을 위한 새로운 MethodChannel
        val MAPPING_CHANNEL = "com.pentagon.ghostouch/mapping"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPPING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setGestureAction" -> {
                    val gesture = call.argument<String>("gesture")
                    val action = call.argument<String>("action")

                    if (gesture != null && action != null) {
                        val prefs = getSharedPreferences("gesture_mappings", MODE_PRIVATE)
                        prefs.edit().putString("gesture_action_$gesture", action).apply()
                        result.success("매핑 저장 성공: $gesture -> $action")
                    } else {
                        result.error("INVALID_ARGUMENTS", "제스처 또는 액션 인수가 없습니다.", null)
                    }
                }
                "getGestureAction" -> {
                    val gesture = call.argument<String>("gesture")
                    if (gesture != null) {
                        val prefs = getSharedPreferences("gesture_mappings", MODE_PRIVATE)
                        // 저장된 값이 없으면 "none"을 기본값으로 반환
                        val action = prefs.getString("gesture_action_$gesture", "none")
                        result.success(action)
                    } else {
                        result.error("INVALID_ARGUMENTS", "제스처 인수가 없습니다.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 학습 관련 MethodChannel
        val TRAINING_CHANNEL = "com.pentagon.ghostouch/training"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRAINING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTraining" -> {
                    val gestureName = call.argument<String>("gestureName")
                    val frames = call.argument<ArrayList<ArrayList<Double>>>("frames")

                    if (gestureName != null && frames != null) {
                        trainingCoordinator.uploadAndTrain(gestureName, frames.map { it.map { d -> d.toFloat() } })
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "제스처 이름 또는 프레임이 없습니다.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Task ID 관련 MethodChannel 
        val TASK_ID_CHANNEL = "com.pentagon.gesture/task-id"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TASK_ID_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTaskId" -> {
                    val prefs = getSharedPreferences("app_settings", MODE_PRIVATE)
                    val taskId = prefs.getString("current_task_id", "default_task_id") ?: "default_task_id"
                    result.success(taskId)
                }
                else -> result.notImplemented()
            }
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

    override fun onResume() {
        super.onResume()
        GestureDetectionService.isAppInForeground = true
        android.util.Log.d("MainActivity", "onResume: isAppInForeground set to TRUE")
    }

    override fun onPause() {
        super.onPause()
        GestureDetectionService.isAppInForeground = false
        android.util.Log.d("MainActivity", "onPause: isAppInForeground set to FALSE")
    }
}