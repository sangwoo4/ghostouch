package com.pentagon.ghostouch

import android.content.Context
import android.content.Intent
import android.util.Log

class ActionExecutor(private val context: Context) {

    private val prefs = context.getSharedPreferences("gesture_mappings", Context.MODE_PRIVATE)

    fun executeActionForGesture(gesture: String) {
        // SharedPreferences에서 "gesture_action_rock" 같은 키로 저장된 값을 불러옴
        val action = prefs.getString("gesture_action_$gesture", null)

        Log.d("ActionExecutor", "실행 요청: $gesture -> $action")

        // "action_open_memo" 동작이 지정된 경우, 메모장 앱 실행
        if (action == "action_open_memo") {
            // 삼성 노트 앱의 패키지 이름입니다. 다른 메모장 앱을 원하시면 이 부분을 수정해야 합니다.
            openApp("com.samsung.android.app.notes")
        }
        // TODO: 다른 액션들(예: 스크린캡쳐)에 대한 처리 로직 추가
    }

    private fun openApp(packageName: String) {
        try {
            val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                Log.d("ActionExecutor", "앱 실행 성공: $packageName")
            } else {
                Log.e("ActionExecutor", "앱을 찾을 수 없습니다. 설치되어 있는지 확인해주세요: $packageName")
            }
        } catch (e: Exception) {
            Log.e("ActionExecutor", "앱 실행 중 오류 발생", e)
        }
    }
}
