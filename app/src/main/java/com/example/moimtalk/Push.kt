package com.example.moimtalk

import android.content.Context
import com.onesignal.OneSignal
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

// =====================================================================
//  푸시 알림 (OneSignal) — 새 메시지 알림
//  · local.properties 에 onesignal.app.id 설정 (docs/PUBLISH_ANDROID.md)
//  · 발송은 Supabase Edge Function(notify-message) 이 담당합니다.
// =====================================================================
object Push {
    /** 앱 시작 시 1회 (MoimApp.onCreate). App ID 미설정 시 초기화 생략. */
    fun configure(context: Context) {
        val appId = BuildConfig.ONESIGNAL_APP_ID.trim()
        if (appId.isEmpty()) return
        OneSignal.initWithContext(context, appId)
        CoroutineScope(Dispatchers.IO).launch {
            runCatching { OneSignal.Notifications.requestPermission(true) }
        }
    }

    /** 로그인 후: 이 기기를 supabase 사용자 id 와 연결 (발송 대상 지정용) */
    fun login(userId: String) {
        if (BuildConfig.ONESIGNAL_APP_ID.trim().isEmpty()) return
        runCatching { OneSignal.login(userId) }
    }

    /** 로그아웃 시 연결 해제 */
    fun logout() {
        if (BuildConfig.ONESIGNAL_APP_ID.trim().isEmpty()) return
        runCatching { OneSignal.logout() }
    }
}
