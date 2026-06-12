import Foundation
import UIKit
import OneSignalFramework

// =====================================================================
//  OneSignal 푸시 알림 (웹/Android 와 동일 백엔드 notify-message 사용)
//  · external_id = 회원 id(Supabase user id) 로 연결 → 그 회원에게 푸시
//  · appId 가 비어 있으면 전체 비활성
//  · APNs 키 업로드·Push 권한 등 설정은 docs/PUSH_SETUP.md 참고
// =====================================================================
enum Push {
    static let appId = "4e52339e-a96e-4eeb-bdd9-3a11ce2f9f18"   // 비우면 비활성

    /// App init 에서 1회
    static func start(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        guard !appId.isEmpty else { return }
        OneSignal.initialize(appId, withLaunchOptions: launchOptions)
    }

    /// 로그인/세션복원 시 이 회원 id 로 구독 연결. 새 로그인이면 권한도 요청.
    static func login(_ userId: String, requestPermission requestPerm: Bool = true) {
        guard !appId.isEmpty else { return }
        OneSignal.login(userId)
        if requestPerm {
            OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: true)
        }
    }

    /// 로그아웃 시 구독 연결 해제
    static func logout() {
        guard !appId.isEmpty else { return }
        OneSignal.logout()
    }
}
