package com.example.moimtalk.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.storage.storage

object MoimRepository {

    private const val FILES_BUCKET = "room-files"

    fun currentUserId(): String? =
        supabase.auth.currentSessionOrNull()?.user?.id

    suspend fun signIn(email: String, password: String) {
        supabase.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
    }

    suspend fun signOut() {
        supabase.auth.signOut()
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

    /** 모임방 생성 (카톡식): 방 추가 + 참석자(생성자 + 선택 멤버) 등록 */
    suspend fun createRoom(name: String, memberIds: List<String>): String {
        val uid = currentUserId() ?: error("Not logged in")
        val roomId = java.util.UUID.randomUUID().toString()
        val order = (System.currentTimeMillis() / 1000).toInt()
        supabase.from("rooms").insert(
            RoomInsert(id = roomId, name = name, sortOrder = order, createdBy = uid)
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

    suspend fun messages(roomId: String): List<Message> =
        supabase.from("messages").select {
            filter { eq("room_id", roomId) }
            order("created_at", Order.ASCENDING)
        }.decodeList()

    suspend fun sendMessage(roomId: String, text: String) {
        val uid = currentUserId() ?: error("Not logged in")
        supabase.from("messages").insert(
            MessageInsert(roomId = roomId, senderId = uid, content = text)
        )
    }

    // ── 멤버 이름 표시용 (작성자·업로더) ──
    suspend fun allProfiles(): List<Profile> =
        supabase.from("profiles").select().decodeList()

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
                attachmentUrls = urls,
                attachmentNames = names,
            )
        )
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

    // ── 병실 잔여 현황 (메모) ──
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
}
