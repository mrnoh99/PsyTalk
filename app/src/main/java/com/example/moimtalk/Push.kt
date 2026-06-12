package com.example.moimtalk

import android.content.Context
import com.onesignal.OneSignal
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

// =====================================================================
//  OneSignal 푸시 알림 (웹/iOS 와 동일 백엔드 notify-message 사용)
//  · external_id = 회원 id(Supabase user id) 로 연결 → 그 회원에게 푸시
//  · APP_ID 가 비어 있으면 전체 비활성(빌드/실행에 영향 없음)
//  · 설정(대시보드 FCM 자격증명 등)은 docs/PUSH_SETUP.md 참고
// =====================================================================
object Push {
    const val APP_ID = "4e52339e-a96e-4eeb-bdd9-3a11ce2f9f18"   // 비우면 비활성

    /** Application.onCreate 에서 1회 */
    fun init(context: Context) {
        if (APP_ID.isBlank()) return
        runCatching { OneSignal.initWithContext(context, APP_ID) }
    }

    /** 로그인/세션복원 시 이 회원 id 로 구독 연결. 새 로그인이면 권한도 요청. */
    fun login(userId: String, requestPerm: Boolean = true) {
        if (APP_ID.isBlank()) return
        runCatching { OneSignal.login(userId) }
        if (requestPerm) requestPermission()
    }

    /** 로그아웃 시 구독 연결 해제 */
    fun logout() {
        if (APP_ID.isBlank()) return
        runCatching { OneSignal.logout() }
    }

    /** Android 13+ 알림 권한 요청 (이미 허용이면 무시) */
    fun requestPermission() {
        if (APP_ID.isBlank()) return
        CoroutineScope(Dispatchers.IO).launch {
            runCatching { OneSignal.Notifications.requestPermission(true) }
        }
    }
}
