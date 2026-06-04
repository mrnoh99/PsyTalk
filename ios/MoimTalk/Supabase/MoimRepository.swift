import Foundation
import Supabase

// =====================================================================
//  모든 Supabase 호출 — Android MoimRepository.kt 와 동일
// =====================================================================
enum MoimRepository {

    static let filesBucket = "room-files"

    static func currentUserId() -> String? {
        supabase.auth.currentUser?.id.uuidString.lowercased()
    }

    static func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    static func signOut() async throws {
        try await supabase.auth.signOut()
    }

    static func myProfile() async throws -> Profile {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let rows: [Profile] = try await supabase.from("profiles")
            .select().eq("id", value: uid).execute().value
        guard let p = rows.first else { throw AppError.message("프로필이 없습니다") }
        return p
    }

    static func rooms() async throws -> [Room] {
        try await supabase.from("rooms")
            .select().order("sort_order", ascending: true).execute().value
    }

    static func allProfiles() async throws -> [Profile] {
        try await supabase.from("profiles").select().execute().value
    }

    /// 모임방 생성 (카톡식): 방 추가 + 참석자(생성자 + 선택 멤버) 등록
    @discardableResult
    static func createRoom(name: String, memberIds: [String]) async throws -> String {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let roomId = UUID().uuidString.lowercased()
        let order = Int(Date().timeIntervalSince1970)
        let room = RoomInsert(id: roomId, name: name, sortOrder: order, createdBy: uid)
        try await supabase.from("rooms").insert(room).execute()
        let ids = Array(Set(memberIds + [uid]))
        let members = ids.map { RoomMemberInsert(roomId: roomId, userId: $0) }
        try await supabase.from("room_members").insert(members).execute()
        return roomId
    }

    // ── 채팅 ──
    static func messages(roomId: String) async throws -> [Message] {
        try await supabase.from("messages")
            .select().eq("room_id", value: roomId)
            .order("created_at", ascending: true).execute().value
    }

    static func sendMessage(roomId: String, text: String) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let payload = MessageInsert(roomId: roomId, senderId: uid, content: text)
        try await supabase.from("messages").insert(payload).execute()
    }

    // ── 캘린더 ──
    static func events(roomId: String) async throws -> [CalendarEvent] {
        try await supabase.from("calendar_events")
            .select().eq("room_id", value: roomId)
            .order("start_at", ascending: true).execute().value
    }

    static func createEvent(
        roomId: String, title: String, startAt: String,
        place: String?, link: String?, scope: String?, description: String?,
        keywords: [String],
        attachmentName: String?, attachmentData: Data?, attachmentDesc: String?
    ) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        var url: String?
        var name: String?
        if let data = attachmentData, let fn = attachmentName, !fn.isEmpty {
            url = try await uploadToStorage(roomId: roomId, fileName: fn, data: data)
            name = fn
        }
        let payload = CalendarEventInsert(
            roomId: roomId, title: title, startAt: startAt,
            place: place, link: link, scope: scope, description: description,
            keywords: keywords, ownerId: uid,
            attachmentUrl: url, attachmentName: name,
            attachmentDesc: (attachmentDesc?.isEmpty == false) ? attachmentDesc : nil
        )
        try await supabase.from("calendar_events").insert(payload).execute()
    }

    static func updateEvent(
        eventId: String, title: String, startAt: String,
        place: String?, link: String?, scope: String?, description: String?, keywords: [String]
    ) async throws {
        let payload = CalendarEventUpdate(
            title: title, startAt: startAt, place: place, link: link,
            scope: scope, description: description, keywords: keywords
        )
        try await supabase.from("calendar_events").update(payload)
            .eq("id", value: eventId).execute()
    }

    // ── 자료실 ──
    static func files(roomId: String) async throws -> [RoomFile] {
        try await supabase.from("room_files")
            .select().eq("room_id", value: roomId)
            .order("created_at", ascending: false).execute().value
    }

    static func uploadRoomFile(
        roomId: String, fileName: String, data: Data,
        description: String?, keywords: [String]
    ) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let url = try await uploadToStorage(roomId: roomId, fileName: fileName, data: data)
        let payload = RoomFileInsert(
            roomId: roomId, fileName: fileName, fileUrl: url,
            description: (description?.isEmpty == false) ? description : nil,
            keywords: keywords, uploadedBy: uid, source: "upload"
        )
        try await supabase.from("room_files").insert(payload).execute()
    }

    // ── 병실 잔여 현황 (메모) ──
    static func wardStatus() async throws -> WardStatus {
        let rows: [WardStatus] = try await supabase.from("ward_status")
            .select().eq("id", value: 1).execute().value
        return rows.first ?? WardStatus()
    }

    static func updateWardStatus(content: String) async throws {
        let nowIso = ISO8601DateFormatter().string(from: Date())
        let payload = WardStatusUpdate(content: content, updatedBy: currentUserId(), updatedAt: nowIso)
        try await supabase.from("ward_status").update(payload).eq("id", value: 1).execute()
    }

    /// Storage('room-files' 버킷) 업로드 후 공개 URL 반환
    static func uploadToStorage(roomId: String, fileName: String, data: Data) async throws -> String {
        let safe = fileName.replacingOccurrences(
            of: "[^A-Za-z0-9._가-힣-]", with: "_", options: .regularExpression)
        let path = "\(roomId)/\(Int(Date().timeIntervalSince1970 * 1000))_\(safe)"
        let bucket = supabase.storage.from(filesBucket)
        try await bucket.upload(path, data: data, options: FileOptions(upsert: true))
        return try bucket.getPublicURL(path: path).absoluteString
    }
}
