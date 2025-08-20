package com.pentagon.ghostouch.actions

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AppLauncher(private val context: Context) {

    fun openApp(packageName: String) {
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
                    Log.d("AppLauncher", "앱 실행 성공 (명시적 Intent): $packageName")
                    return
                } catch (e: Exception) {
                    Log.w("AppLauncher", "명시적 Intent 실행 실패: ${e.message}")
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
                    Log.d("AppLauncher", "앱 실행 성공 (기본 Intent): $packageName")
                    return
                } catch (directException: Exception) {
                    Log.w("AppLauncher", "직접 실행 실패, PendingIntent 방법 시도: ${directException.message}")
                    
                    // 방법 3: PendingIntent 사용
                    try {
                        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                        
                        val pendingIntent = PendingIntent.getActivity(context, 0, intent, flags)
                        pendingIntent.send()
                        Log.d("AppLauncher", "앱 실행 성공 (PendingIntent): $packageName")
                        return
                    } catch (pendingException: Exception) {
                        Log.e("AppLauncher", "PendingIntent 실행도 실패: ${pendingException.message}")
                    }
                }
            }
            
            Log.e("AppLauncher", "앱을 찾을 수 없거나 모든 실행 방법 실패: $packageName")
        } catch (e: Exception) {
            Log.e("AppLauncher", "앱 실행 중 예상치 못한 오류: ${e.message}", e)
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
            Log.w("AppLauncher", "명시적 Intent 생성 실패: ${e.message}")
            null
        }
    }
}