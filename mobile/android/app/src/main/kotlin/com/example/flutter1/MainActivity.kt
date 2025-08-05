package com.pentagon.ghostouch

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.platform.PlatformViewRegistry

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.pentagon.ghostouch/toggle"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 네이티브 뷰 팩토리 등록
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("hand_detection_view", HandDetectionViewFactory(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "functionToggle" -> {
                    println("✅ functionToggle 호출됨 (안드로이드)")
                    result.success(null)
                }
                "openSettings" -> {
                    println("⚙️ openSettings 호출됨")
                    openAppSettings()
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
}
