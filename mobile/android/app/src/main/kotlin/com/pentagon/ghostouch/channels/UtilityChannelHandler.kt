package com.pentagon.ghostouch.channels

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import com.pentagon.ghostouch.gesture.detection.GestureDetectionService
import com.pentagon.ghostouch.gesture.training.TrainingCoordinator
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class UtilityChannelHandler(private val context: Context) {
    
    fun handleToggle(call: MethodCall, result: MethodChannel.Result, getAvailableGestures: () -> Map<String, String>) {
        when (call.method) {
            "startGestureService" -> {
                val intent = Intent(context, GestureDetectionService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(null)
            }
            "stopGestureService" -> {
                val intent = Intent(context, GestureDetectionService::class.java)
                context.stopService(intent)
                result.success(null)
            }
            "checkCameraPermission" -> {
                val hasCameraPermission = ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.CAMERA
                ) == PackageManager.PERMISSION_GRANTED
                
                val hasWriteSettingsPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.System.canWrite(context)
                } else true
                
                // 두 권한이 모두 있어야 true 반환
                result.success(hasCameraPermission && hasWriteSettingsPermission)
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
                    val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("toggle_state", state).apply()
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "State argument is missing", null)
                }
            }
            "getToggleState" -> {
                val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
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
                    val serverUrl = TrainingCoordinator.getServerUrl(context)
                    result.success(serverUrl)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get server URL: ${e.message}", null)
                }
            }
            else -> result.notImplemented()
        }
    }
    
    fun handleTaskId(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getTaskId" -> {
                val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
                val taskId = prefs.getString("current_task_id", "default_task_id") ?: "default_task_id"
                result.success(taskId)
            }
            else -> result.notImplemented()
        }
    }
    
    fun handleControlApp(call: MethodCall, result: MethodChannel.Result, openExternalApp: (String) -> Unit) {
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
    
    fun handleBackground(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setBackgroundTimeout" -> {
                val minutes = call.argument<Int>("minutes")
                if (minutes != null) {
                    try {
                        val actualMinutes = minutes
                        
                        // SharedPreferences에 설정 저장
                        val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
                        prefs.edit().putInt("background_timeout_minutes", actualMinutes).apply()
                        
                        // GestureDetectionService에 설정 전달
                        val intent = Intent(context, GestureDetectionService::class.java)
                        intent.action = "ACTION_SET_BACKGROUND_TIMEOUT"
                        intent.putExtra("timeout_minutes", actualMinutes)
                        context.startService(intent)
                        
                        Log.d("UtilityChannelHandler", "Background timeout set to $actualMinutes minutes")
                        result.success("Background timeout set successfully")
                    } catch (e: Exception) {
                        Log.e("UtilityChannelHandler", "Failed to set background timeout", e)
                        result.error("SET_TIMEOUT_FAILED", "Failed to set timeout: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Minutes argument is required", null)
                }
            }
            "getBackgroundTimeout" -> {
                try {
                    val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
                    val minutes = prefs.getInt("background_timeout_minutes", 0) // 기본값 0 (설정 안 함)
                    result.success(minutes)
                } catch (e: Exception) {
                    result.error("GET_TIMEOUT_FAILED", "Failed to get timeout: ${e.message}", null)
                }
            }
            else -> result.notImplemented()
        }
    }
    
    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}