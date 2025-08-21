package com.pentagon.ghostouch.actions

import android.content.Context
import android.content.Intent
import android.util.Log

class AppLauncher(private val context: Context) {

    /**
     * 지정 패키지의 런처 액티비티 실행
     * @return 실행 성공 여부
     */
    fun openApp(packageName: String): Boolean {
        return try {
            val pm = context.packageManager
            val intent = pm.getLaunchIntentForPackage(packageName)
                ?: run {
                    Log.e("AppLauncher", "런처 인텐트를 찾을 수 없음: $packageName")
                    return false
                }

            // 필요한 최소 플래그만 추가
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            // 혹시 액션/카테고리가 비어있다면 보강 (대부분 이미 세팅되어 옴)
            if (intent.action == null) intent.action = Intent.ACTION_MAIN
            if (intent.categories == null || intent.categories?.isEmpty() == true) {
                intent.addCategory(Intent.CATEGORY_LAUNCHER)
            }

            context.startActivity(intent)
            Log.d("AppLauncher", "앱 실행 성공: $packageName")
            true
        } catch (e: Exception) {
            Log.e("AppLauncher", "앱 실행 실패: $packageName, ${e.message}", e)
            false
        }
    }
}