package com.example.moimtalk.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage
import kotlin.time.Duration.Companion.hours
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

object MoimRepository {

    private const val FILES_BUCKET = "room-files"
    private const val CHAT_BUCKET = "chat-files"   // 채팅 첨부(비공개·방 구성원만)

    fun currentUserId(): String? =
        supabase.auth.currentSessionOrNull()?.user?.id

    /** Android: 파일 선택 등으로 백그라운드 복귀 시 세션 재로딩 완료까지 대기 */
    suspend fun ensureAuthReady() {
        supabase.auth.awaitInitialization()
    }

    suspend fun signIn(email: String, password: String) {
        supabase.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
    }

    suspend fun signOut() {
        supabase.auth.signOut()
    }

    /** 회원가입: 이름·직군을 메타데이터로 전달 → 트리거가 profiles 생성 */
    suspend fun signUp(email: String, password: String, name: String, memberType: String) {
        supabase.auth.signUpWith(Email) {
            this.email = email
            this.password = password
            data = buildJsonObject {
                put("name", name)
                put("member_type", memberType)
            }
        }
    }

    suspend fun myProfile(): Profile {
        val uid = currentUserId() ?: error("Not logged in")
        return supabase.from("profiles").select {
            filter { eq("id", uid) }
        }.decodeList<Profile>()
            .firstOrNull()
            ?: error("프로필이 없습니다")
    }

    suspend fun rooms(): List<Room> =
        supabase.from("rooms").select {
            order("sort_order", Order.ASCENDING)
        }.decodeList()

    /** 모임방 생성 (카톡식): 방 추가 + 참석자(생성자 + 선택 회원) 등록 */
    suspend fun createRoom(
        name: String,
        memberIds: List<String>,
        color: String? = null,
        iconBytes: ByteArray? = null,
        iconName: String? = null,
    ): String {
        val uid = currentUserId() ?: error("Not logged in")
        val roomId = java.util.UUID.randomUUID().toString()
        val order = (System.currentTimeMillis() / 1000).toInt()
        val iconUrl = if (iconBytes != null) uploadToStorage(roomId, iconName ?: "icon.png", iconBytes) else null
        supabase.from("rooms").insert(
            RoomInsert(id = roomId, name = name, sortOrder = order, createdBy = uid, color = color, iconUrl = iconUrl)
        )
        val members = (memberIds + uid).distinct().map { RoomMemberInsert(roomId = roomId, userId = it) }
        supabase.from("room_members").insert(members)
        return roomId
    }

    /** 방 이름 변경 (생성자 또는 관리자, RLS 로 강제) */
    suspend fun updateRoomName(roomId: String, name: String) {
        supabase.from("rooms").update(RoomNameUpdate(name = name)) {
            filter { eq("id", roomId) }
        }
    }

    /** 방 정보 변경: 이름·방표식 색상·사진 (생성자/관리자, RLS). setIcon=true 면 icon_url 갱신(사진 또는 제거) */
    suspend fun updateRoomAppearance(
        roomId: String,
        name: String,
        color: String?,
        iconBytes: ByteArray?,
        iconName: String?,
        clearIcon: Boolean,
    ) {
        val newIconUrl = if (iconBytes != null) uploadToStorage(roomId, iconName ?: "icon.png", iconBytes) else null
        supabase.from("rooms").update({
            set("name", name)
            set("color", color)
            if (iconBytes != null) set("icon_url", newIconUrl)
            else if (clearIcon) set<String?>("icon_url", null)
        }) { filter { eq("id", roomId) } }
    }

    /** 모임방 삭제 (생성자 또는 관리자, RLS 로 강제). 회원·메시지·일정·자료는 CASCADE 삭제. */
    suspend fun deleteRoom(roomId: String) {
        supabase.from("rooms").delete { filter { eq("id", roomId) } }
    }

    /** 내가 가입한 방 id 목록 (홈 목록에서 superadmin/admin 도 가입 방만 표시) */
    suspend fun myRoomIds(): List<String> {
        val uid = currentUserId() ?: return emptyList()
        return supabase.from("room_members").select(Columns.list("room_id", "user_id")) {
            filter { eq("user_id", uid) }
        }.decodeList<RoomMemberInsert>().map { it.roomId }
    }

    /** 방 참여 회원의 user_id 목록 (같은 방 참여자·생성자·관리자 조회 — RLS) */
    suspend fun roomMemberIds(roomId: String): List<String> =
        supabase.from("room_members").select(Columns.list("room_id", "user_id")) {
            filter { eq("room_id", roomId) }
        }.decodeList<RoomMemberInsert>().map { it.userId }

    /** 방별 참여 인원 (관리자 콘솔·목록용) */
    suspend fun roomMemberCounts(): Map<String, Int> =
        supabase.from("room_members").select(Columns.list("room_id", "user_id"))
            .decodeList<RoomMemberInsert>()
            .groupBy { it.roomId }
            .mapValues { it.value.size }

    /** 회원 내보내기 (생성자 또는 관리자, RLS 로 강제) */
    suspend fun removeRoomMember(roomId: String, userId: String) {
        supabase.from("room_members").delete {
            filter { eq("room_id", roomId); eq("user_id", userId) }
        }
    }

    /** 방 나가기: 본인 회원 자격 삭제 (생성자가 아닌 모임방, RLS 로 본인만 허용) */
    suspend fun leaveRoom(roomId: String) {
        val uid = currentUserId() ?: return
        supabase.from("room_members").delete {
            filter { eq("room_id", roomId); eq("user_id", uid) }
        }
    }

    /** 회원 탈퇴: 본인 데이터 정리 후 계정 삭제 (전체관리자 불가 — RPC 로 강제) */
    suspend fun deleteAccount() {
        supabase.postgrest.rpc("moim_delete_my_account")
    }

    /** 구성원 초대 (방에 회원 추가). 이미 참여 중이면 무시. */
    suspend fun addRoomMembers(roomId: String, userIds: List<String>) {
        if (userIds.isEmpty()) return
        val rows = userIds.map { RoomMemberInsert(roomId = roomId, userId = it) }
        try {
            supabase.from("room_members").insert(rows)
        } catch (e: Exception) {
            if (!isDuplicateKeyError(e)) throw e
        }
    }

    suspend fun messages(roomId: String): List<Message> =
        supabase.from("messages").select {
            filter { eq("room_id", roomId) }
            order("created_at", Order.ASCENDING)
        }.decodeList()

    /** 본인이 쓴 메시지(텍스트/사진/파일) 삭제. RLS 로 본인·관리자만 허용 */
    suspend fun deleteMessage(id: String) {
        supabase.from("messages").delete { filter { eq("id", id) } }
    }

    // ── 읽음 추적 ──
    /** 이 방을 본 것으로 표시(현재 사용자 last_read_at = now) */
    suspend fun markRead(roomId: String) {
        supabase.postgrest.rpc("moim_mark_read", buildJsonObject { put("p_room", roomId) })
    }

    /** 방별 안읽은 메시지 수 (현재 사용자) */
    suspend fun unreadCounts(): Map<String, Int> =
        supabase.postgrest.rpc("moim_unread_counts")
            .decodeList<UnreadRoomRow>().associate { it.roomId to it.cnt.toInt() }

    /** 방별 마지막 메시지 (방 목록 미리보기) */
    suspend fun roomLastMessages(): Map<String, LastMsg> =
        supabase.postgrest.rpc("moim_room_last_messages")
            .decodeList<LastMsg>().associateBy { it.roomId }

    /** 개인 고정 방 순서 (room id 목록) */
    suspend fun roomPins(): List<String> =
        supabase.from("room_pins").select(Columns.list("room_id", "position")) {
            order("position", Order.ASCENDING)
        }.decodeList<RoomPinRow>().map { it.roomId }

    /** 고정 방 순서 저장 (최대 5, 배열 순서) */
    suspend fun setRoomPins(ids: List<String>) {
        supabase.postgrest.rpc("moim_set_room_pins", buildJsonObject {
            put("p_rooms", buildJsonArray { ids.take(5).forEach { add(it) } })
        })
    }

    /** 방의 메시지별 안읽은 사람 수 */
    suspend fun messageUnreadCounts(roomId: String): Map<String, Int> =
        supabase.postgrest.rpc("moim_message_unread_counts", buildJsonObject { put("p_room", roomId) })
            .decodeList<UnreadMsgRow>().associate { it.messageId to it.unread }

    suspend fun sendMessage(roomId: String, text: String) {
        val uid = currentUserId() ?: error("Not logged in")
        supabase.from("messages").insert(
            MessageInsert(roomId = roomId, senderId = uid, content = text)
        )
    }

    /** 카톡식 첨부 전송: 공개 room-files 업로드 후 공개 URL 을 담아 메시지 삽입 (type = image | file) */
    suspend fun sendAttachment(roomId: String, fileName: String, bytes: ByteArray, type: String) {
        val uid = currentUserId() ?: error("Not logged in")
        val url = uploadToStorage(roomId, fileName, bytes)
        supabase.from("messages").insert(
            MessageInsert(
                roomId = roomId, senderId = uid, content = null, type = type,
                attachmentUrl = url, attachmentName = fileName,
            )
        )
    }

    // ── 회원 이름 표시용 (작성자·업로더) ──
    suspend fun allProfiles(): List<Profile> =
        supabase.from("profiles").select().decodeList()

    /** 가입 승인/취소 (전체관리자만 — RLS 로 강제) */
    suspend fun setApproved(userId: String, approved: Boolean) {
        supabase.from("profiles").update({ set("approved", approved) }) { filter { eq("id", userId) } }
    }

    /** 가입 승인 (관리자·전체관리자 — RPC). 신규 가입자 approved=true */
    suspend fun approveUser(userId: String) {
        supabase.postgrest.rpc("moim_approve_user", buildJsonObject { put("p_user", userId) })
    }

    /** 역할 지정 (전체관리자만 — RLS). role: user | admin */
    suspend fun updateRole(userId: String, role: String) {
        supabase.from("profiles").update({ set("role", role) }) { filter { eq("id", userId) } }
    }

    /** 회원 계정 비활성화 (전체관리자 — RPC). 글·자료 보존, 로그인·활동 차단 */
    suspend fun adminWithdraw(userId: String) {
        supabase.postgrest.rpc("moim_admin_withdraw", buildJsonObject { put("p_user", userId) })
    }

    // ── 캘린더 ──
    suspend fun events(roomId: String): List<CalendarEvent> =
        supabase.from("calendar_events").select {
            filter { eq("room_id", roomId) }
            order("start_at", Order.ASCENDING)
        }.decodeList()

    /** 일정 등록. 첨부 바이트가 있으면 Storage 업로드 후 URL 을 함께 저장한다. */
    suspend fun createEvent(
        roomId: String,
        title: String,
        startAt: String,
        place: String?,
        link: String?,
        scope: String?,
        description: String?,
        presenter: String?,
        keywords: List<String>,
        attachments: List<Pair<String, ByteArray>>,
    ) {
        val uid = currentUserId() ?: error("Not logged in")
        val urls = mutableListOf<String>()
        val names = mutableListOf<String>()
        for ((fileName, bytes) in attachments) {
            urls += uploadToStorage(roomId, fileName, bytes)
            names += fileName
        }
        supabase.from("calendar_events").insert(
            CalendarEventInsert(
                roomId = roomId,
                title = title,
                startAt = startAt,
                place = place,
                link = link,
                scope = scope,
                description = description,
                presenter = presenter?.takeIf { it.isNotBlank() },
                keywords = keywords,
                ownerId = uid,
                attachmentUrl = null,
                attachmentName = null,
                attachmentDesc = null,
                attachmentUrls = urls,
                attachmentNames = names,
            )
        )
    }

    /** 일정 삭제 (작성자/관리자/교실·의국·비서·심리실 — RLS 로 강제) */
    suspend fun deleteEvent(eventId: String) {
        supabase.from("calendar_events").delete { filter { eq("id", eventId) } }
    }

    /** 일정 수정 (작성자 본인 + 관리자, RLS 로 강제). 첨부는 변경하지 않는다. */
    suspend fun updateEvent(
        eventId: String,
        roomId: String,
        title: String,
        startAt: String,
        place: String?,
        link: String?,
        scope: String?,
        description: String?,
        presenter: String?,
        keywords: List<String>,
        keptUrls: List<String>,
        keptNames: List<String>,
        newAttachments: List<Pair<String, ByteArray>>,
    ) {
        // 유지할 기존 첨부 + 새로 올린 첨부를 합쳐서 배열로 저장
        val urls = keptUrls.toMutableList()
        val names = keptNames.toMutableList()
        for ((fileName, bytes) in newAttachments) {
            urls += uploadToStorage(roomId, fileName, bytes)
            names += fileName
        }
        supabase.from("calendar_events").update({
            set("title", title)
            set("start_at", startAt)
            set("place", place)
            set("link", link)
            set("scope", scope)
            set("description", description)
            set("presenter", presenter)
            set("keywords", keywords)
            set<String?>("attachment_url", null)
            set<String?>("attachment_name", null)
            set<String?>("attachment_desc", null)
            set("attachment_urls", urls)
            set("attachment_names", names)
        }) { filter { eq("id", eventId) } }
    }

    // ── 자료실 ──
    suspend fun files(roomId: String): List<RoomFile> =
        supabase.from("room_files").select {
            filter { eq("room_id", roomId) }
            order("created_at", Order.DESCENDING)
        }.decodeList()

    /** 자료 삭제: room_files 행 삭제 + Storage 객체 best-effort 삭제 (올린이/관리자, RLS 강제) */
    suspend fun deleteRoomFile(fileId: String, fileUrl: String?) {
        fileUrl?.let { url ->
            val marker = "/$FILES_BUCKET/"
            val idx = url.indexOf(marker)
            if (idx >= 0) {
                val path = url.substring(idx + marker.length)
                runCatching { supabase.storage.from(FILES_BUCKET).delete(path) }
            }
        }
        supabase.from("room_files").delete { filter { eq("id", fileId) } }
    }

    /** 자료실 직접 업로드: Storage 업로드 후 room_files 메타데이터 저장 */
    suspend fun uploadRoomFile(
        roomId: String,
        fileName: String,
        bytes: ByteArray,
        description: String?,
        keywords: List<String>,
    ) {
        val uid = currentUserId() ?: error("Not logged in")
        val url = uploadToStorage(roomId, fileName, bytes)
        supabase.from("room_files").insert(
            RoomFileInsert(
                roomId = roomId,
                fileName = fileName,
                fileUrl = url,
                description = description?.takeIf { it.isNotBlank() },
                keywords = keywords,
                uploadedBy = uid,
                source = "upload",
            )
        )
    }

    // ── 잔여 병실 현황 (메모) ──
    suspend fun wardStatus(): WardStatus =
        supabase.from("ward_status").select {
            filter { eq("id", 1) }
        }.decodeList<WardStatus>().firstOrNull() ?: WardStatus()

    suspend fun updateWardStatus(content: String) {
        val uid = currentUserId()
        val nowIso = java.time.OffsetDateTime.now().toString()
        supabase.from("ward_status").update(
            WardStatusUpdate(content = content, updatedBy = uid, updatedAt = nowIso)
        ) { filter { eq("id", 1) } }
    }

    /** 파일을 Storage('room-files' 버킷)에 올리고 공개 URL 을 반환 */
    private suspend fun uploadToStorage(roomId: String, fileName: String, bytes: ByteArray): String {
        val safe = fileName.replace(Regex("[^A-Za-z0-9._가-힣-]"), "_")
        val path = "$roomId/${System.currentTimeMillis()}_$safe"
        val bucket = supabase.storage.from(FILES_BUCKET)
        bucket.upload(path, bytes) { upsert = true }
        return bucket.publicUrl(path)
    }

    /** 첨부 URL 통과(공개 URL 이면 그대로, 과거 비공개 path 면 서명 URL 발급) */
    suspend fun chatSignedUrl(path: String): String? = try {
        if (path.startsWith("http")) path
        else supabase.storage.from(CHAT_BUCKET).createSignedUrl(path, 1.hours)
    } catch (_: Exception) {
        null
    }
}
