package com.pentagon.ghostouch

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.content.ComponentName
import android.media.AudioManager

class ActionExecutor(private val context: Context) {

    private val prefs = context.getSharedPreferences("gesture_mappings", Context.MODE_PRIVATE)

    fun executeActionForGesture(gesture: String) {
        // SharedPreferences에서 "gesture_action_rock" 같은 키로 저장된 값을 불러옴
        val action = prefs.getString("gesture_action_$gesture", null)

        Log.d("ActionExecutor", "실행 요청: $gesture -> $action")

        when (action) {
            "action_open_memo" -> openApp("com.samsung.android.app.notes")
            "action_open_dialer" -> openApp("com.samsung.android.dialer")
            "action_open_messages" -> openApp("com.samsung.android.messaging")
            "action_open_camera" -> openApp("com.sec.android.app.camera")
            "action_open_gallery" -> openApp("com.sec.android.gallery3d")
            "action_open_clock" -> openApp("com.sec.android.app.clockpackage")
            "action_open_calendar" -> openApp("com.samsung.android.calendar")
            "action_open_calculator" -> openApp("com.sec.android.app.popupcalculator")
            "action_open_contacts" -> openApp("com.samsung.android.app.contacts")
            "action_open_settings" -> openApp("com.android.settings")
            "action_volume_up" -> adjustVolume(AudioManager.ADJUST_RAISE)
            "action_volume_down" -> adjustVolume(AudioManager.ADJUST_LOWER)
            "action_volume_mute" -> toggleMute()
        }
        // TODO: 다른 액션들(예: 스크린캡쳐)에 대한 처리 로직 추가
    }

    private fun openApp(packageName: String) {
        try {
            // 방법 1: 명시적 Intent로 메인 액티비티 직접 실행
            val mainIntent = createExplicitLaunchIntent(packageName)
            if (mainIntent != null) {
                try {
                    mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    mainIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                    mainIntent.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                    mainIntent.addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
                    
                    context.startActivity(mainIntent)
                    Log.d("ActionExecutor", "앱 실행 성공 (명시적 Intent): $packageName")
                    return
                } catch (e: Exception) {
                    Log.w("ActionExecutor", "명시적 Intent 실행 실패: ${e.message}")
                }
            }
            
            // 방법 2: 기존 방법 시도
            val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                try {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                    intent.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                    
                    context.startActivity(intent)
                    Log.d("ActionExecutor", "앱 실행 성공 (기본 Intent): $packageName")
                    return
                } catch (directException: Exception) {
                    Log.w("ActionExecutor", "직접 실행 실패, PendingIntent 방법 시도: ${directException.message}")
                    
                    // 방법 3: PendingIntent 사용
                    try {
                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                        
                        val pendingIntent = PendingIntent.getActivity(context, 0, intent, flags)
                        pendingIntent.send()
                        Log.d("ActionExecutor", "앱 실행 성공 (PendingIntent): $packageName")
                        return
                    } catch (pendingException: Exception) {
                        Log.e("ActionExecutor", "PendingIntent 실행도 실패: ${pendingException.message}")
                    }
                }
            }
            
            Log.e("ActionExecutor", "앱을 찾을 수 없거나 모든 실행 방법 실패: $packageName")
        } catch (e: Exception) {
            Log.e("ActionExecutor", "앱 실행 중 예상치 못한 오류: ${e.message}", e)
        }
    }
    
    private fun createExplicitLaunchIntent(packageName: String): Intent? {
        return try {
            val pm = context.packageManager
            val launchIntent = pm.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                val component = launchIntent.component
                if (component != null) {
                    Intent().apply {
                        setComponent(component)
                        action = Intent.ACTION_MAIN
                        addCategory(Intent.CATEGORY_LAUNCHER)
                    }
                } else null
            } else null
        } catch (e: Exception) {
            Log.w("ActionExecutor", "명시적 Intent 생성 실패: ${e.message}")
            null
        }
    }
    
    private fun adjustVolume(direction: Int) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.adjustStreamVolume(
                AudioManager.STREAM_MUSIC, 
                direction, 
                AudioManager.FLAG_SHOW_UI
            )
            
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val action = if (direction == AudioManager.ADJUST_RAISE) "증가" else "감소"
            
            Log.d("ActionExecutor", "볼륨 $action 성공: $currentVolume/$maxVolume")
        } catch (e: Exception) {
            Log.e("ActionExecutor", "볼륨 조절 중 오류 발생: ${e.message}", e)
        }
    }
    
    private fun toggleMute() {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                if (currentVolume > 0) {
                    // 음소거
                    audioManager.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_MUTE,
                        AudioManager.FLAG_SHOW_UI
                    )
                    Log.d("ActionExecutor", "음소거 설정됨")
                } else {
                    // 음소거 해제
                    audioManager.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_UNMUTE,
                        AudioManager.FLAG_SHOW_UI
                    )
                    Log.d("ActionExecutor", "음소거 해제됨")
                }
            } else {
                // API 23 미만에서는 볼륨을 0으로 설정/복원
                val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                if (currentVolume > 0) {
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, AudioManager.FLAG_SHOW_UI)
                    Log.d("ActionExecutor", "볼륨을 0으로 설정")
                } else {
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxVolume / 2, AudioManager.FLAG_SHOW_UI)
                    Log.d("ActionExecutor", "볼륨을 ${maxVolume / 2}로 복원")
                }
            }
        } catch (e: Exception) {
            Log.e("ActionExecutor", "음소거 토글 중 오류 발생: ${e.message}", e)
        }
    }
}
