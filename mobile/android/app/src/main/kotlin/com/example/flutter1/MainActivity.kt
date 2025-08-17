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