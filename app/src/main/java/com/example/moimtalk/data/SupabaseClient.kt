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
    install(Auth) {
        // 사진·파일 선택기 등 외부 앱 전환 시 세션을 Initializing 으로 리셋하지 않음
        enableLifecycleCallbacks = false
    }
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
    val approved: Boolean = false,    // 관리자 가입 승인 (기본값 불승인: 값이 없으면 승인 대기)
    val withdrawn: Boolean = false,   // 탈퇴(비활성): 글·자료는 남기되 활동·로그인 불가
    val phone: String? = null,        // 전화번호
    val intro: String? = null,        // 자기소개 (내 정보 변경)
    val email: String? = null,        // 이메일 (auth.users 와 동기화 — 회원 검색·관리 표시용)
    @SerialName("device_type") val deviceType: String? = null,    // iphone | android (앱 설치용)
    @SerialName("device_email") val deviceEmail: String? = null,  // 앱 설치용 연결 이메일
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val color: String? = null,        // 프로필 아바타 색상(hex), null=직군 기본색
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("phone_updated_at") val phoneUpdatedAt: String? = null,
)

@Serializable
data class Room(
    val id: String,
    val name: String,
    val category: String,             // notice | group | work | research | custom | direct
    @SerialName("post_policy") val postPolicy: String,  // restricted | members
    @SerialName("sort_order") val sortOrder: Int = 999,
    @SerialName("default_view") val defaultView: String? = null,
    @SerialName("created_by") val createdBy: String? = null,
    val color: String? = null,                          // 방표식 색상(hex), null=카테고리 기본색
    @SerialName("icon_url") val iconUrl: String? = null, // 방표식 사진 URL, null=색+이름
    @SerialName("dm_key") val dmKey: String? = null,    // 1:1 DM 식별 키('a_b'), 일반/모임방은 null
)

// 모임방 생성 DTO (사용자가 카톡처럼 방 생성)
@Serializable
data class RoomInsert(
    val id: String,
    val name: String,
    val category: String = "custom",
    @SerialName("post_policy") val postPolicy: String = "members",
    @SerialName("sort_order") val sortOrder: Int,
    @SerialName("created_by") val createdBy: String,
    val color: String? = null,
    @SerialName("icon_url") val iconUrl: String? = null,
)

@Serializable
data class RoomMemberInsert(
    @SerialName("room_id") val roomId: String,
    @SerialName("user_id") val userId: String,
)

// 방 이름 수정 DTO (생성자 또는 관리자만, RLS 로 강제)
@Serializable
data class RoomNameUpdate(
    val name: String,
)

@Serializable
data class Message(
    val id: String,
    @SerialName("room_id") val roomId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String? = null,
    val type: String = "text",                          // text | image | file
    @SerialName("attachment_url") val attachmentUrl: String? = null,
    @SerialName("attachment_name") val attachmentName: String? = null,
    @SerialName("reply_to") val replyTo: String? = null,   // 답장 대상 메시지 id
    @SerialName("created_at") val createdAt: String,
)

// 이모지 리액션
@Serializable
data class Reaction(
    val id: String? = null,
    @SerialName("message_id") val messageId: String,
    @SerialName("user_id") val userId: String,
    val emoji: String,
)

@Serializable
data class ReactionInsert(
    @SerialName("message_id") val messageId: String,
    @SerialName("user_id") val userId: String,
    val emoji: String,
)

// 방별 마지막 메시지 (방 목록 미리보기)
@Serializable
data class LastMsg(
    @SerialName("room_id") val roomId: String,
    val content: String? = null,
    val type: String = "text",
    @SerialName("attachment_name") val attachmentName: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

// 개인 고정 방 (순서)
@Serializable
data class RoomPinRow(@SerialName("room_id") val roomId: String)

// 읽음 추적 RPC 결과
@Serializable
data class UnreadRoomRow(@SerialName("room_id") val roomId: String, val cnt: Long)

@Serializable
data class UnreadMsgRow(@SerialName("message_id") val messageId: String, val unread: Int)

// 메시지 삽입용 DTO (id/created_at 은 DB가 생성)
@Serializable
data class MessageInsert(
    @SerialName("room_id") val roomId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String? = null,
    val type: String = "text",                          // text | image | file
    @SerialName("attachment_url") val attachmentUrl: String? = null,
    @SerialName("attachment_name") val attachmentName: String? = null,
    @SerialName("reply_to") val replyTo: String? = null,
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
    val presenter: String? = null,
    val keywords: List<String> = emptyList(),
    @SerialName("owner_id") val ownerId: String,
    @SerialName("attachment_url") val attachmentUrl: String? = null,
    @SerialName("attachment_name") val attachmentName: String? = null,
    @SerialName("attachment_desc") val attachmentDesc: String? = null,
    /** NULL = 레거시 단일 컬럼만 사용. 빈 배열 = 첨부 없음(삭제 반영). */
    @SerialName("attachment_urls") val attachmentUrls: List<String>? = null,
    @SerialName("attachment_names") val attachmentNames: List<String>? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

/** 일정 첨부 목록 — attachment_urls 가 NULL 이 아니면 빈 배열 포함 배열만 사용 */
fun CalendarEvent.attachmentPairs(): List<Pair<String, String>> {
    if (attachmentUrls != null) {
        val urls = attachmentUrls!!
        val names = attachmentNames ?: emptyList()
        return urls.mapIndexed { i, u -> (names.getOrElse(i) { "첨부파일" }) to u }
    }
    if (!attachmentUrl.isNullOrBlank()) {
        return listOf((attachmentName ?: "첨부파일") to attachmentUrl!!)
    }
    return emptyList()
}

// 일정 삽입용 DTO (id/created_at/updated_at 은 DB가 생성)
@Serializable
data class CalendarEventInsert(
    @SerialName("room_id") val roomId: String,
    val title: String,
    @SerialName("start_at") val startAt: String,
    val place: String? = null,
    val link: String? = null,
    val scope: String? = null,
    val description: String? = null,
    val presenter: String? = null,
    val keywords: List<String> = emptyList(),
    @SerialName("owner_id") val ownerId: String,
    @SerialName("attachment_url") val attachmentUrl: String? = null,
    @SerialName("attachment_name") val attachmentName: String? = null,
    @SerialName("attachment_desc") val attachmentDesc: String? = null,
    @SerialName("attachment_urls") val attachmentUrls: List<String> = emptyList(),
    @SerialName("attachment_names") val attachmentNames: List<String> = emptyList(),
)

// 일정 수정용 DTO (작성자 본인 + 관리자만, 요구사항 6)
@Serializable
data class CalendarEventUpdate(
    val title: String,
    @SerialName("start_at") val startAt: String,
    val place: String? = null,
    val link: String? = null,
    val scope: String? = null,
    val description: String? = null,
    val keywords: List<String> = emptyList(),
)

@Serializable
data class RoomFile(
    val id: String,
    @SerialName("room_id") val roomId: String,
    @SerialName("file_name") val fileName: String,
    @SerialName("file_url") val fileUrl: String,
    val description: String? = null,
    val keywords: List<String> = emptyList(),
    @SerialName("uploaded_by") val uploadedBy: String,
    val source: String = "upload",          // upload | calendar
    @SerialName("calendar_event_id") val calendarEventId: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

// 자료실 직접 업로드 DTO
@Serializable
data class RoomFileInsert(
    @SerialName("room_id") val roomId: String,
    @SerialName("file_name") val fileName: String,
    @SerialName("file_url") val fileUrl: String,
    val description: String? = null,
    val keywords: List<String> = emptyList(),
    @SerialName("uploaded_by") val uploadedBy: String,
    val source: String = "upload",
)

// 잔여 병실 현황 (단일 행, 메모 형식 자유 텍스트)
@Serializable
data class WardStatus(
    val id: Int = 1,
    val content: String = "",
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class WardStatusUpdate(
    val content: String,
    @SerialName("updated_by") val updatedBy: String? = null,
    @SerialName("updated_at") val updatedAt: String,
)
