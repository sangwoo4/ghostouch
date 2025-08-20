package com.pentagon.ghostouch.actions

import android.content.Context
import android.media.AudioManager
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import android.os.Build
import android.util.Log

class MediaController(private val context: Context) {

    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null

    fun adjustVolume(direction: Int) {
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
            
            Log.d("MediaController", "볼륨 $action 성공: $currentVolume/$maxVolume")
        } catch (e: Exception) {
            Log.e("MediaController", "볼륨 조절 중 오류 발생: ${e.message}", e)
        }
    }
    
    fun toggleMute() {
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
                    Log.d("MediaController", "음소거 설정됨")
                } else {
                    // 음소거 해제
                    audioManager.adjustStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        AudioManager.ADJUST_UNMUTE,
                        AudioManager.FLAG_SHOW_UI
                    )
                    Log.d("MediaController", "음소거 해제됨")
                }
            } else {
                // API 23 미만에서는 볼륨을 0으로 설정/복원
                val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                if (currentVolume > 0) {
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, AudioManager.FLAG_SHOW_UI)
                    Log.d("MediaController", "볼륨을 0으로 설정")
                } else {
                    val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxVolume / 2, AudioManager.FLAG_SHOW_UI)
                    Log.d("MediaController", "볼륨을 ${maxVolume / 2}로 복원")
                }
            }
        } catch (e: Exception) {
            Log.e("MediaController", "음소거 토글 중 오류 발생: ${e.message}", e)
        }
    }
    
    fun toggleFlashlight() {
        try {
            if (cameraManager == null) {
                cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                // 후면 카메라 찾기
                cameraId = cameraManager?.cameraIdList?.find { id ->
                    val characteristics = cameraManager?.getCameraCharacteristics(id)
                    val facing = characteristics?.get(CameraCharacteristics.LENS_FACING)
                    val hasFlash = characteristics?.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                    facing == CameraCharacteristics.LENS_FACING_BACK && hasFlash
                }
            }
            
            // SharedPreferences에서 현재 플래시 상태 확인
            val flashPrefs = context.getSharedPreferences("flashlight_state", Context.MODE_PRIVATE)
            val currentFlashState = flashPrefs.getBoolean("is_flash_on", false)
            
            cameraId?.let { id ->
                val newFlashState = !currentFlashState
                cameraManager?.setTorchMode(id, newFlashState)
                
                // 새로운 상태를 SharedPreferences에 저장
                flashPrefs.edit().putBoolean("is_flash_on", newFlashState).apply()
                
                Log.d("MediaController", "플래시 ${if (newFlashState) "켜짐" else "꺼짐"}")
            } ?: run {
                Log.e("MediaController", "플래시를 지원하는 카메라를 찾을 수 없습니다")
            }
        } catch (e: Exception) {
            Log.e("MediaController", "플래시 토글 중 오류 발생: ${e.message}", e)
        }
    }
}