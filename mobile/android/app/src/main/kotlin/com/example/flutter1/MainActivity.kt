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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.pentagon.ghostouch/toggle"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
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
