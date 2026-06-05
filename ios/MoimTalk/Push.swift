import Foundation
#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

// =====================================================================
//  푸시 알림 (OneSignal) — 새 메시지 알림
//  · ONESIGNAL_APP_ID 를 OneSignal 대시보드의 App ID 로 바꾸세요.
//  · OneSignal 패키지가 추가되기 전에도 컴파일되도록 #if canImport 로 감쌌습니다.
//  · 발송은 Supabase Edge Function(notify-message) 이 담당합니다.
// =====================================================================
enum Push {
    static let oneSignalAppId = "ONESIGNAL_APP_ID"   // ← OneSignal App ID 로 교체

    /// 앱 시작 시 1회 (MoimTalkApp.init)
    static func configure() {
        #if canImport(OneSignalFramework)
        OneSignal.initialize(oneSignalAppId, withLaunchOptions: nil)
        OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: true)
        #endif
    }

    /// 로그인 후: 이 기기를 supabase 사용자 id 와 연결 (발송 대상 지정용)
    static func login(_ userId: String) {
        #if canImport(OneSignalFramework)
        OneSignal.login(userId)
        #endif
    }

    /// 로그아웃 시 연결 해제
    static func logout() {
        #if canImport(OneSignalFramework)
        OneSignal.logout()
        #endif
    }
}
