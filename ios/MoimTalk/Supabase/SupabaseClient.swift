import Foundation
import Supabase

// =====================================================================
//  Supabase 클라이언트 (앱 전역 싱글톤) — Android SupabaseClient.kt 와 동일 값
// =====================================================================
let supabaseURLString = "https://orkbcprkfloosyttfybg.supabase.co"

let supabase = SupabaseClient(
    supabaseURL: URL(string: supabaseURLString)!,
    supabaseKey: SUPABASE_ANON_KEY,
    options: SupabaseClientOptions(
        auth: .init(emitLocalSessionAsInitialSession: true)
    )
)

// anon 키 (Android 와 동일). 노출되어도 RLS 로 보호되는 공개 키.
let SUPABASE_ANON_KEY = [
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ya2JjcHJrZmxvb3N5dHRmeWJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NzAyNjAsImV4cCI6MjA5NjA0NjI2MH0",
    "ju2bN3gWERBIdfs9WaMUDVJCkj_bAjtgmeXwgu-RxUo"
].joined(separator: ".")

// 공통 에러
enum AppError: LocalizedError {
    case notLoggedIn
    case message(String)
    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "로그인이 필요합니다"
        case .message(let m): return m
        }
    }
}
