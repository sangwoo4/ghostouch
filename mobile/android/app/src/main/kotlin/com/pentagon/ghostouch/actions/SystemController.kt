package com.pentagon.ghostouch.actions

import android.content.Context
import android.os.Build
import android.provider.Settings

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
                }
            }
        } catch (_: Exception) {
            // 오류 발생 시 무시 (필요하면 예외 처리 추가 가능)
        }
    }
}