package com.pentagon.ghostouch.actions

import android.content.Context
import android.util.Log
import android.media.AudioManager

class ActionExecutor(private val context: Context) {

    private val prefs = context.getSharedPreferences("gesture_mappings", Context.MODE_PRIVATE)
    private val appLauncher = AppLauncher(context)
    private val mediaController = MediaController(context)
    private val systemController = SystemController(context)

    fun executeActionForGesture(gesture: String) {
        // SharedPreferences에서 "gesture_action_rock" 같은 키로 저장된 값을 불러옴
        val action = prefs.getString("gesture_action_$gesture", null)

        Log.d("ActionExecutor", "실행 요청: $gesture -> $action")

        when (action) {
            "action_open_memo" -> appLauncher.openApp("com.samsung.android.app.notes")
            "action_open_dialer" -> appLauncher.openApp("com.samsung.android.dialer")
            "action_open_messages" -> appLauncher.openApp("com.samsung.android.messaging")
            "action_open_camera" -> appLauncher.openApp("com.sec.android.app.camera")
            "action_open_gallery" -> appLauncher.openApp("com.sec.android.gallery3d")
            "action_open_clock" -> appLauncher.openApp("com.sec.android.app.clockpackage")
            "action_open_calendar" -> appLauncher.openApp("com.samsung.android.calendar")
            "action_open_calculator" -> appLauncher.openApp("com.sec.android.app.popupcalculator")
            "action_open_contacts" -> appLauncher.openApp("com.samsung.android.app.contacts")
            "action_open_settings" -> appLauncher.openApp("com.android.settings")
            "action_volume_up" -> mediaController.adjustVolume(AudioManager.ADJUST_RAISE)
            "action_volume_down" -> mediaController.adjustVolume(AudioManager.ADJUST_LOWER)
            "action_volume_mute" -> mediaController.toggleMute()
            "action_flashlight_toggle" -> mediaController.toggleFlashlight()
            "action_brightness_up" -> systemController.adjustBrightness(true)
            "action_brightness_down" -> systemController.adjustBrightness(false)
        }
        // TODO: 다른 액션들(예: 스크린캡쳐)에 대한 처리 로직 추가
    }
}
