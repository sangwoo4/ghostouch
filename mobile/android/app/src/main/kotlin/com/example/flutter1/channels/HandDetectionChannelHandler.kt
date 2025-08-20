package com.pentagon.ghostouch.channels

import android.content.Context
import android.util.Log
import com.pentagon.ghostouch.gesture.TrainingCoordinator
import com.pentagon.ghostouch.ui.HandDetectionPlatformView
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class HandDetectionChannelHandler(
    private val context: Context,
    private val getHandDetectionPlatformView: () -> HandDetectionPlatformView?,
    private val setPendingGestureName: (String?) -> Unit,
    private val getPendingGestureName: () -> String?
) {
    
    fun handleHandDetection(call: MethodCall, result: MethodChannel.Result) {
        Log.d("HandDetectionChannelHandler", "Hand detection method called: ${call.method}")
        when (call.method) {
            "startCollecting" -> {
                val gestureName = call.argument<String>("gestureName")
                Log.d("HandDetectionChannelHandler", "startCollecting called with gesture: $gestureName")
                if (gestureName != null) {
                    // PlatformView에 직접 호출 또는 대기열에 저장
                    getHandDetectionPlatformView()?.let { platformView ->
                        Log.d("HandDetectionChannelHandler", "Calling startCollecting on PlatformView")
                        platformView.startCollectingFromMainActivity(gestureName)
                        result.success(null)
                    } ?: run {
                        Log.d("HandDetectionChannelHandler", "PlatformView not ready, saving gesture for later: $gestureName")
                        setPendingGestureName(gestureName)
                        result.success(null) // 일단 성공으로 응답
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Gesture name is required", null)
                }
            }
            "stopCollecting" -> {
                Log.d("HandDetectionChannelHandler", "stopCollecting called")
                result.success(null)
            }
            "saveGesture" -> {
                val gestureName = call.argument<String>("gestureName")
                Log.d("HandDetectionChannelHandler", "saveGesture called with gesture: $gestureName")
                if (gestureName != null) {
                    try {
                        // 1. 수집된 데이터 서버로 업로드 시작
                        getHandDetectionPlatformView()?.uploadCollectedData()
                        
                        // 2. 업데이트된 레이블 맵 파일 로드 (나중에 확인용)
                        val updatedLabelMapFile = File(context.filesDir, "updated_label_map.json")
                        if (updatedLabelMapFile.exists()) {
                            Log.d("HandDetectionChannelHandler", "Updated label map found, gesture '$gestureName' should already be included")
                        } else {
                            Log.w("HandDetectionChannelHandler", "Updated label map not found, gesture might not be properly saved")
                        }
                        
                        // 3. 모델 파일 확인
                        val currentModelCode = TrainingCoordinator.currentModelCode
                        val currentModelFileName = TrainingCoordinator.currentModelFileName
                        Log.d("HandDetectionChannelHandler", "Current model: $currentModelCode ($currentModelFileName)")
                        
                        // 4. 성공 응답
                        result.success("Gesture '$gestureName' upload started successfully")
                        Log.d("HandDetectionChannelHandler", "Gesture '$gestureName' upload process started")
                        
                    } catch (e: Exception) {
                        Log.e("HandDetectionChannelHandler", "Failed to save gesture '$gestureName'", e)
                        result.error("SAVE_FAILED", "Failed to save gesture: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Gesture name is required", null)
                }
            }
            else -> result.notImplemented()
        }
    }
}