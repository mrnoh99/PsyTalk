package com.example.moimtalk

import android.content.Context
import com.onesignal.OneSignal
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

// =====================================================================
//  푸시 알림 (OneSignal) — 새 메시지 알림
//  · ONESIGNAL_APP_ID 를 OneSignal 대시보드의 App ID 로 교체하세요.
//  · 발송은 Supabase Edge Function(notify-message) 이 담당합니다.
// =====================================================================
object Push {
    const val ONESIGNAL_APP_ID = "ONESIGNAL_APP_ID"   // ← OneSignal App ID 로 교체

    /** 앱 시작 시 1회 (MoimApp.onCreate) */
    fun configure(context: Context) {
        OneSignal.initWithContext(context, ONESIGNAL_APP_ID)
        CoroutineScope(Dispatchers.IO).launch {
            runCatching { OneSignal.Notifications.requestPermission(true) }
        }
    }

    /** 로그인 후: 이 기기를 supabase 사용자 id 와 연결 (발송 대상 지정용) */
    fun login(userId: String) {
        runCatching { OneSignal.login(userId) }
    }

    /** 로그아웃 시 연결 해제 */
    fun logout() {
        runCatching { OneSignal.logout() }
    }
}
