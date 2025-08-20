package com.pentagon.ghostouch.gesture.management

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log

class BackgroundTimeoutManager(private val context: Context) {
    
    private var backgroundTimeoutMinutes: Int = 0 // 0이면 자동 꺼짐 없음
    private var backgroundStartTime: Long = 0
    private val backgroundTimeoutHandler = Handler(Looper.getMainLooper())
    private var backgroundTimeoutRunnable: Runnable? = null
    
    companion object {
        private const val TAG = "BackgroundTimeoutManager"
    }
    
    // 백그라운드 타임아웃 설정 로드
    fun loadBackgroundTimeoutSetting() {
        val prefs = context.getSharedPreferences("app_settings", Context.MODE_PRIVATE)
        backgroundTimeoutMinutes = prefs.getInt("background_timeout_minutes", 0)
        Log.d(TAG, "Loaded background timeout setting: $backgroundTimeoutMinutes minutes")
    }
    
    // 백그라운드 타임아웃 설정
    fun setBackgroundTimeout(minutes: Int, isAppInForeground: Boolean, stopSelfAndNotify: () -> Unit) {
        backgroundTimeoutMinutes = minutes
        Log.d(TAG, "Background timeout set to $minutes minutes (isAppInForeground: $isAppInForeground)")
        
        if (minutes != 0 && !isAppInForeground) {
            // 이미 백그라운드에 있다면 타이머 재시작 (minutes가 -1이나 양수일 때)
            Log.d(TAG, "App is in background, starting timer immediately")
            cancelBackgroundTimer() // 기존 타이머 취소
            startBackgroundTimerIfNeeded(stopSelfAndNotify)
        } else if (minutes == 0) {
            // 설정이 0이면 타이머 취소
            Log.d(TAG, "Timeout disabled, cancelling timer")
            cancelBackgroundTimer()
        } else {
            Log.d(TAG, "App is in foreground, timer will start when app goes to background")
        }
    }
    
    // 백그라운드 타이머 시작 (필요한 경우에만)
    fun startBackgroundTimerIfNeeded(stopSelfAndNotify: () -> Unit) {
        if (backgroundTimeoutMinutes == 0) return // 자동 꺼짐 설정이 없으면 리턴
        if (backgroundTimeoutRunnable != null) return // 이미 타이머가 실행 중이면 리턴
        
        val currentTime = System.currentTimeMillis()
        if (backgroundStartTime == 0L) {
            backgroundStartTime = currentTime
        }
        
        // 분을 밀리초로 변환
        val timeoutMillis = backgroundTimeoutMinutes * 60 * 1000L
        
        val elapsedMillis = currentTime - backgroundStartTime
        val remainingMillis = timeoutMillis - elapsedMillis
        
        if (remainingMillis <= 0) {
            // 이미 시간이 지났으면 바로 서비스 종료
            stopSelfAndNotify()
            return
        }
        
        // 남은 시간만큼 타이머 설정
        backgroundTimeoutRunnable = Runnable {
            Log.d(TAG, "Background timeout reached after ${backgroundTimeoutMinutes}분. Stopping service.")
            stopSelfAndNotify()
        }
        
        backgroundTimeoutHandler.postDelayed(backgroundTimeoutRunnable!!, remainingMillis)
        
        val remainingMinutes = remainingMillis / (1000 * 60)
        Log.d(TAG, "Background timer started. Will stop service in ${remainingMinutes}분.")
    }
    
    // 백그라운드 타이머 취소
    fun cancelBackgroundTimer() {
        backgroundTimeoutRunnable?.let {
            backgroundTimeoutHandler.removeCallbacks(it)
            backgroundTimeoutRunnable = null
            backgroundStartTime = 0L
            Log.d(TAG, "Background timer cancelled.")
        }
    }
    
    fun hasActiveTimer(): Boolean = backgroundTimeoutRunnable != null
    
    fun getTimeoutMinutes(): Int = backgroundTimeoutMinutes
}