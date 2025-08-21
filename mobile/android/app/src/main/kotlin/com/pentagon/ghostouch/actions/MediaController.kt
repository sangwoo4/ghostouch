package com.pentagon.ghostouch.actions

import android.content.Context
import android.media.AudioManager
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import android.os.Build
import android.util.Log

class MediaController(private val context: Context) {
    
    private val audioManager by lazy { context.getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    private val cameraManager by lazy { context.getSystemService(Context.CAMERA_SERVICE) as CameraManager }
    private val flashCameraId by lazy { 
        cameraManager.cameraIdList.find { id ->
            val characteristics = cameraManager.getCameraCharacteristics(id)
            characteristics.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK &&
            characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
    }

    fun adjustVolume(direction: Int) = runCatching {
        audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, AudioManager.FLAG_SHOW_UI)
        Log.d("MediaController", "볼륨 ${if (direction == AudioManager.ADJUST_RAISE) "증가" else "감소"}")
    }.onFailure { Log.e("MediaController", "볼륨 조절 실패", it) }
    
    fun toggleMute() = runCatching {
        val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val action = if (currentVolume > 0) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE
            audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, action, AudioManager.FLAG_SHOW_UI)
        } else {
            val volume = if (currentVolume > 0) 0 else audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC) / 2
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volume, AudioManager.FLAG_SHOW_UI)
        }
        Log.d("MediaController", "음소거 ${if (currentVolume > 0) "설정" else "해제"}")
    }.onFailure { Log.e("MediaController", "음소거 토글 실패", it) }
    
    fun toggleFlashlight() = runCatching {
        flashCameraId?.let { id ->
            val prefs = context.getSharedPreferences("flashlight_state", Context.MODE_PRIVATE)
            val isOn = !prefs.getBoolean("is_flash_on", false)
            cameraManager.setTorchMode(id, isOn)
            prefs.edit().putBoolean("is_flash_on", isOn).apply()
            Log.d("MediaController", "플래시 ${if (isOn) "켜짐" else "꺼짐"}")
        } ?: Log.e("MediaController", "플래시 지원 카메라 없음")
    }.onFailure { Log.e("MediaController", "플래시 토글 실패", it) }
}