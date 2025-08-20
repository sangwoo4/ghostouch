package com.pentagon.ghostouch.channels

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class GestureChannelHandler(private val context: Context) {
    
    fun handleMapping(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setGestureAction" -> {
                val gesture = call.argument<String>("gesture")
                val action = call.argument<String>("action")

                if (gesture != null && action != null) {
                    val prefs = context.getSharedPreferences("gesture_mappings", Context.MODE_PRIVATE)
                    prefs.edit().putString("gesture_action_$gesture", action).apply()
                    result.success("매핑 저장 성공: $gesture -> $action")
                } else {
                    result.error("INVALID_ARGUMENTS", "제스처 또는 액션 인수가 없습니다.", null)
                }
            }
            "getGestureAction" -> {
                val gesture = call.argument<String>("gesture")
                if (gesture != null) {
                    val prefs = context.getSharedPreferences("gesture_mappings", Context.MODE_PRIVATE)
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
    
    fun handleGestureList(call: MethodCall, result: MethodChannel.Result, getAvailableGestures: () -> Map<String, String>, getKoreanGestureName: (String) -> String) {
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
                            return
                        }
                        
                        // 2. 특수문자 및 길이 체크
                        if (trimmedName.length > 20) {
                            result.success(mapOf(
                                "isDuplicate" to true,
                                "message" to "제스처 이름은 20자 이하로 입력해주세요."
                            ))
                            return
                        }
                        
                        // 3. 금지된 문자 체크 (선택사항)
                        val forbiddenChars = listOf("/", "\\", ":", "*", "?", "\"", "<", ">", "|")
                        if (forbiddenChars.any { trimmedName.contains(it) }) {
                            result.success(mapOf(
                                "isDuplicate" to true,
                                "message" to "특수문자는 사용할 수 없습니다."
                            ))
                            return
                        }
                        
                        // 4. 실제 중복 체크
                        val gestureMap = getAvailableGestures()
                        val koreanGestureList = gestureMap.keys.map { getKoreanGestureName(it) }
                        
                        // 영어 키도 확인 (서버로 전송될 때는 영어 키 사용)
                        val englishGestureList = gestureMap.keys.toList()
                        
                        // "제스처" 부분을 제거한 순수 이름 리스트
                        val pureGestureNames = koreanGestureList.map { it.replace(" 제스처", "").trim() }
                        val inputWithoutGesture = trimmedName.replace(" 제스처", "").trim()
                        
                        // 중복 검사: 전체 이름, 영어 키, 순수 이름 모두 확인
                        val isDuplicateKorean = koreanGestureList.contains(trimmedName)
                        val isDuplicateEnglish = englishGestureList.contains(trimmedName)
                        val isDuplicatePure = pureGestureNames.contains(inputWithoutGesture)
                        val isDuplicate = isDuplicateKorean || isDuplicateEnglish || isDuplicatePure
                        
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
    
    fun handleGestureReset(call: MethodCall, result: MethodChannel.Result, resetToOriginalModel: () -> Unit) {
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