import Foundation
import Supabase

// =====================================================================
//  모든 Supabase 호출 — Android MoimRepository.kt 와 동일
// =====================================================================
enum MoimRepository {

    static let filesBucket = "room-files"
    static let chatBucket = "chat-files"   // 채팅 첨부(비공개·방 구성원만)

    static func currentUserId() -> String? {
        supabase.auth.currentUser?.id.uuidString.lowercased()
    }

    static func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    static func signOut() async throws {
        try await supabase.auth.signOut()
    }

    /// 회원가입: 이름·직군을 메타데이터로 전달 → 트리거가 profiles 생성
    static func signUp(email: String, password: String, name: String, memberType: String) async throws {
        try await supabase.auth.signUp(
            email: email, password: password,
            data: ["name": .string(name), "member_type": .string(memberType)]
        )
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

    /// 역할 지정 (전체관리자만 — RLS 로 강제). role: user | admin | superadmin
    static func updateRole(userId: String, role: String) async throws {
        try await supabase.from("profiles").update(["role": role]).eq("id", value: userId).execute()
    }

    /// 이름 변경 (전체관리자 또는 본인 — RLS 로 강제)
    static func updateName(userId: String, name: String) async throws {
        try await supabase.from("profiles").update(["name": name]).eq("id", value: userId).execute()
    }

    /// 가입 승인/취소 (전체관리자만 — RLS 로 강제)
    static func setApproved(userId: String, approved: Bool) async throws {
        try await supabase.from("profiles").update(["approved": approved]).eq("id", value: userId).execute()
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

    /// 방 이름 변경 (생성자 또는 관리자 — RLS 로 강제)
    static func updateRoomName(roomId: String, name: String) async throws {
        try await supabase.from("rooms").update(["name": name]).eq("id", value: roomId).execute()
    }

    /// 모임방 삭제 (생성자 또는 관리자 — RLS). 멤버·메시지·일정·자료는 CASCADE 삭제.
    static func deleteRoom(roomId: String) async throws {
        try await supabase.from("rooms").delete().eq("id", value: roomId).execute()
    }

    /// 방 참여 멤버 user_id 목록 (같은 방 참여자·생성자·관리자 — RLS)
    static func roomMemberIds(roomId: String) async throws -> [String] {
        let rows: [RoomMemberRow] = try await supabase.from("room_members")
            .select("room_id,user_id").eq("room_id", value: roomId).execute().value
        return rows.map { $0.userId }
    }

    /// 방별 참여 인원 (관리자 콘솔용)
    static func roomMemberCounts() async throws -> [String: Int] {
        let rows: [RoomMemberRow] = try await supabase.from("room_members")
            .select("room_id,user_id").execute().value
        var counts: [String: Int] = [:]
        for row in rows {
            counts[row.roomId, default: 0] += 1
        }
        return counts
    }

    /// 멤버 내보내기 (생성자 또는 관리자 — RLS)
    static func removeRoomMember(roomId: String, userId: String) async throws {
        try await supabase.from("room_members").delete()
            .eq("room_id", value: roomId).eq("user_id", value: userId).execute()
    }

    /// 구성원 초대 (방에 멤버 추가 — 방 생성자/관리자, RLS). 이미 참여 중이면 무시.
    static func addRoomMembers(roomId: String, userIds: [String]) async throws {
        guard !userIds.isEmpty else { return }
        let rows = userIds.map { RoomMemberInsert(roomId: roomId, userId: $0) }
        do {
            try await supabase.from("room_members").insert(rows).execute()
        } catch {
            if !isDuplicateKeyError(error) { throw error }
        }
    }

    private static func isDuplicateKeyError(_ error: Error) -> Bool {
        let m = error.localizedDescription.lowercased()
        return m.contains("23505") || m.contains("duplicate key")
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

    /// 카톡식 첨부 전송: 공개 room-files 업로드 후 공개 URL 을 담아 메시지 삽입 (type = image | file)
    static func sendAttachment(roomId: String, fileName: String, data: Data, type: String) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let url = try await uploadToStorage(roomId: roomId, fileName: fileName, data: data)
        let payload = MessageInsert(
            roomId: roomId, senderId: uid, content: nil, type: type,
            attachmentUrl: url, attachmentName: fileName
        )
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
        presenter: String?, keywords: [String],
        attachments: [(name: String, data: Data)]
    ) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        var urls = [String]()
        var names = [String]()
        for a in attachments {
            urls.append(try await uploadToStorage(roomId: roomId, fileName: a.name, data: a.data))
            names.append(a.name)
        }
        let payload = CalendarEventInsert(
            roomId: roomId, title: title, startAt: startAt,
            place: place, link: link, scope: scope, description: description,
            presenter: (presenter?.isEmpty == false) ? presenter : nil,
            keywords: keywords, ownerId: uid,
            attachmentUrls: urls, attachmentNames: names
        )
        try await supabase.from("calendar_events").insert(payload).execute()
    }

    static func updateEvent(
        eventId: String, roomId: String, title: String, startAt: String,
        place: String?, link: String?, scope: String?, description: String?,
        presenter: String?, keywords: [String],
        keptUrls: [String], keptNames: [String], newAttachments: [(name: String, data: Data)]
    ) async throws {
        // 유지할 기존 첨부 + 새로 올린 첨부를 합쳐 배열로 저장
        var urls = keptUrls
        var names = keptNames
        for a in newAttachments {
            urls.append(try await uploadToStorage(roomId: roomId, fileName: a.name, data: a.data))
            names.append(a.name)
        }
        let fields: [String: AnyJSON] = [
            "title": .string(title),
            "start_at": .string(startAt),
            "place": place.map { AnyJSON.string($0) } ?? .null,
            "link": link.map { AnyJSON.string($0) } ?? .null,
            "scope": scope.map { AnyJSON.string($0) } ?? .null,
            "description": description.map { AnyJSON.string($0) } ?? .null,
            "presenter": presenter.map { AnyJSON.string($0) } ?? .null,
            "keywords": .array(keywords.map { AnyJSON.string($0) }),
            "attachment_url": .null,
            "attachment_name": .null,
            "attachment_desc": .null,
            "attachment_urls": .array(urls.map { AnyJSON.string($0) }),
            "attachment_names": .array(names.map { AnyJSON.string($0) }),
        ]
        try await supabase.from("calendar_events").update(fields).eq("id", value: eventId).execute()
    }

    // ── 자료실 ──
    /// 자료 삭제: room_files 행 + Storage 객체(best-effort). 올린이/관리자만(RLS).
    static func deleteRoomFile(fileId: String, fileUrl: String?) async throws {
        if let url = fileUrl {
            let marker = "/\(filesBucket)/"
            if let r = url.range(of: marker) {
                let path = String(url[r.upperBound...])
                _ = try? await supabase.storage.from(filesBucket).remove(paths: [path])
            }
        }
        try await supabase.from("room_files").delete().eq("id", value: fileId).execute()
    }

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

    // ── 잔여 병실 현황 (메모) ──
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

    /// 첨부 URL 통과(공개 URL 이면 그대로, 과거 비공개 path 면 서명 URL 발급)
    static func chatSignedUrl(_ path: String) async -> String? {
        if path.hasPrefix("http") { return path }
        return try? await supabase.storage.from(chatBucket)
            .createSignedURL(path: path, expiresIn: 3600).absoluteString
    }
}
