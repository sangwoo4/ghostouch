package com.pentagon.ghostouch.actions

import android.content.Context
import android.os.Build
import android.provider.Settings
import android.util.Log

class SystemController(private val context: Context) {

    fun adjustBrightness(increase: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.System.canWrite(context)) {
                    val currentBrightness = Settings.System.getInt(
                        context.contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS,
                        127
                    )
                    
                    val maxBrightness = 255
                    val step = 25
                    val newBrightness = if (increase) {
                        (currentBrightness + step).coerceAtMost(maxBrightness)
                    } else {
                        (currentBrightness - step).coerceAtLeast(1)
                    }
                    
                    Settings.System.putInt(
                        context.contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS,
                        newBrightness
                    )
                    
                    val action = if (increase) "증가" else "감소"
                    Log.d("SystemController", "화면 밝기 $action: $newBrightness/$maxBrightness")
                } else {
                    Log.e("SystemController", "시스템 설정 쓰기 권한이 없습니다")
                }
            } else {
                Log.e("SystemController", "Android 6.0 이상에서만 지원됩니다")
            }
        } catch (e: Exception) {
            Log.e("SystemController", "화면 밝기 조절 중 오류 발생: ${e.message}", e)
        }
    }
}