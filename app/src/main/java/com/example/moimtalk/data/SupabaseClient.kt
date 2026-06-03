package com.example.moimtalk.data

import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// =====================================================================
//  Supabase 클라이언트 (앱 전역 싱글톤)
//  아래 두 값을 본인 프로젝트 값으로 교체하세요.
// =====================================================================
private const val SUPABASE_URL = "https://orkbcprkfloosyttfybg.supabase.co"
private const val SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ya2JjcHJrZmxvb3N5dHRmeWJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0NzAyNjAsImV4cCI6MjA5NjA0NjI2MH0.ju2bN3gWERBIdfs9WaMUDVJCkj_bAjtgmeXwgu-RxUo"  // anon 키

val supabase = createSupabaseClient(
    supabaseUrl = SUPABASE_URL,
    supabaseKey = SUPABASE_KEY
) {
    install(Auth)
    install(Postgrest)
    install(Realtime)
    install(Storage)
}

// =====================================================================
//  데이터 모델 — DB 스키마와 1:1 (컬럼은 snake_case → @SerialName 매핑)
// =====================================================================

@Serializable
data class Profile(
    val id: String,
    val name: String,
    @SerialName("member_type") val memberType: String,
    val role: String,                 // superadmin | admin | user
    @SerialName("avatar_url") val avatarUrl: String? = null,
)

@Serializable
data class Room(
    val id: String,
    val name: String,
    val category: String,             // notice | group | work | research | custom
    @SerialName("post_policy") val postPolicy: String,  // restricted | members
    @SerialName("sort_order") val sortOrder: Int = 999,
    @SerialName("default_view") val defaultView: String? = null,
)

@Serializable
data class Message(
    val id: String,
    @SerialName("room_id") val roomId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String? = null,
    val type: String = "text",
    @SerialName("created_at") val createdAt: String,
)

// 메시지 삽입용 DTO (id/created_at 은 DB가 생성)
@Serializable
data class MessageInsert(
    @SerialName("room_id") val roomId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String,
    val type: String = "text",
)

@Serializable
data class CalendarEvent(
    val id: String,
    @SerialName("room_id") val roomId: String,
    val title: String,
    @SerialName("start_at") val startAt: String,
    val place: String? = null,
    val link: String? = null,
    val scope: String? = null,
    val description: String? = null,
    val keywords: List<String> = emptyList(),
    @SerialName("owner_id") val ownerId: String,
)
