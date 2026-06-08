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

    static func currentUserEmail() -> String? {
        supabase.auth.currentUser?.email
    }

    static func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    static func signOut() async throws {
        try await supabase.auth.signOut()
    }

    /// 회원가입: 이름·직군·핸드폰·소개를 메타데이터로 전달 → 트리거가 profiles 생성/보강
    static func signUp(email: String, password: String, name: String, memberType: String, phone: String, intro: String, deviceType: String, deviceEmail: String) async throws {
        try await supabase.auth.signUp(
            email: email, password: password,
            data: ["name": .string(name), "member_type": .string(memberType),
                   "phone": .string(phone), "intro": .string(intro),
                   "device_type": .string(deviceType), "device_email": .string(deviceEmail)]
        )
    }

    /// 핸드폰번호 → 이메일 조회 (핸드폰 로그인용). 없으면 nil
    static func emailForPhone(_ phone: String) async throws -> String? {
        let res: String? = try await supabase.rpc("moim_email_for_phone", params: ["p_phone": phone]).execute().value
        return res
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

    /// 내 정보 변경: 자기소개(intro)·직군(member_type)·아바타(avatar_url)·색상(color) — RPC(본인 안전 컬럼만)
    static func updateMyProfile(intro: String?, memberType: String?, avatarUrl: String?, color: String?,
                                deviceType: String? = nil, deviceEmail: String? = nil) async throws {
        let params: [String: AnyJSON] = [
            "p_intro": intro.map { AnyJSON.string($0) } ?? .null,
            "p_member_type": memberType.map { AnyJSON.string($0) } ?? .null,
            "p_avatar_url": avatarUrl.map { AnyJSON.string($0) } ?? .null,
            "p_color": color.map { AnyJSON.string($0) } ?? .null,
            "p_device_type": deviceType.map { AnyJSON.string($0) } ?? .null,
            "p_device_email": deviceEmail.map { AnyJSON.string($0) } ?? .null,
        ]
        try await supabase.rpc("moim_update_my_profile", params: params).execute()
    }

    /// 1:1 DM 열기(없으면 생성) — 상대 user id 를 받아 방 id 반환 (RPC)
    static func openDirect(otherId: String) async throws -> String {
        let rid: String = try await supabase.rpc("moim_open_direct", params: ["p_other": otherId]).execute().value
        return rid
    }

    /// 비밀번호 변경 — 클라이언트 auth.update (전체관리자는 DB 트리거가 차단)
    static func changePassword(_ newPassword: String) async throws {
        try await supabase.auth.update(user: UserAttributes(password: newPassword))
    }

    /// 프로필 사진 업로드 → 공개 room-files 버킷에 저장하고 공개 URL 반환
    static func uploadProfileAvatar(data: Data, ext: String) async throws -> String {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let safeExt = ext.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
        let e = safeExt.isEmpty ? "png" : safeExt
        let path = "profiles/\(uid)/avatar_\(Int(Date().timeIntervalSince1970 * 1000)).\(e)"
        let bucket = supabase.storage.from(filesBucket)
        try await bucket.upload(path, data: data, options: FileOptions(upsert: true))
        return try bucket.getPublicURL(path: path).absoluteString
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

    /// 가입 승인 (관리자·전체관리자 — RPC). 신규 가입자 approved=true
    static func approveUser(userId: String) async throws {
        try await supabase.rpc("moim_approve_user", params: ["p_user": userId]).execute()
    }

    /// 회원 계정 비활성화 (전체관리자 — RPC). 글·자료는 보존, 로그인·활동 차단
    static func adminWithdraw(userId: String) async throws {
        try await supabase.rpc("moim_admin_withdraw", params: ["p_user": userId]).execute()
    }

    /// 비활성 계정 복구(재활성화) (전체관리자 — RPC). 승인 복구 + 로그인 차단 해제
    static func reactivate(userId: String) async throws {
        try await supabase.rpc("moim_reactivate_user", params: ["p_user": userId]).execute()
    }

    /// 모임방 생성 (카톡식): 방 추가 + 참석자(생성자 + 선택 회원) 등록
    @discardableResult
    static func createRoom(name: String, memberIds: [String], color: String? = nil, iconData: Data? = nil, iconName: String? = nil) async throws -> String {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let roomId = UUID().uuidString.lowercased()
        let order = Int(Date().timeIntervalSince1970)
        var iconUrl: String? = nil
        if let d = iconData { iconUrl = try await uploadToStorage(roomId: roomId, fileName: iconName ?? "icon.png", data: d) }
        let room = RoomInsert(id: roomId, name: name, sortOrder: order, createdBy: uid, color: color, iconUrl: iconUrl)
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

    /// icon_url 을 null 로도 명시 설정할 수 있는 방 정보 변경 페이로드
    private struct RoomAppearancePayload: Encodable {
        let name: String
        let color: String?
        let setIcon: Bool
        let iconUrl: String?
        enum K: String, CodingKey { case name, color; case iconUrl = "icon_url" }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: K.self)
            try c.encode(name, forKey: .name)
            try c.encodeIfPresent(color, forKey: .color)
            if setIcon {
                if let u = iconUrl { try c.encode(u, forKey: .iconUrl) } else { try c.encodeNil(forKey: .iconUrl) }
            }
        }
    }

    /// 방 정보 변경: 이름·방표식 색상·사진 (생성자/관리자 — RLS). clearIcon=true 면 사진 제거(null)
    static func updateRoomAppearance(roomId: String, name: String, color: String?, iconData: Data?, iconName: String?, clearIcon: Bool) async throws {
        var iconUrl: String? = nil
        var setIcon = false
        if let d = iconData {
            iconUrl = try await uploadToStorage(roomId: roomId, fileName: iconName ?? "icon.png", data: d)
            setIcon = true
        } else if clearIcon {
            setIcon = true
        }
        let payload = RoomAppearancePayload(name: name, color: color, setIcon: setIcon, iconUrl: iconUrl)
        try await supabase.from("rooms").update(payload).eq("id", value: roomId).execute()
    }

    /// 모임방 삭제 (생성자 또는 관리자 — RLS). 회원·메시지·일정·자료는 CASCADE 삭제.
    static func deleteRoom(roomId: String) async throws {
        try await supabase.from("rooms").delete().eq("id", value: roomId).execute()
    }

    /// 내가 가입한 방 id 목록 (홈 목록에서 superadmin/admin 도 가입 방만 표시)
    static func myRoomIds() async throws -> [String] {
        guard let uid = currentUserId() else { return [] }
        let rows: [RoomMemberRow] = try await supabase.from("room_members")
            .select("room_id,user_id").eq("user_id", value: uid).execute().value
        return rows.map { $0.roomId }
    }

    /// 방 참여 회원 user_id 목록 (같은 방 참여자·생성자·관리자 — RLS)
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

    /// 회원 내보내기 (생성자 또는 관리자 — RLS)
    static func removeRoomMember(roomId: String, userId: String) async throws {
        try await supabase.from("room_members").delete()
            .eq("room_id", value: roomId).eq("user_id", value: userId).execute()
    }

    /// 방 나가기: 본인 회원 자격 삭제 (생성자가 아닌 모임방, RLS 로 본인만 허용)
    static func leaveRoom(roomId: String) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        try await supabase.from("room_members").delete()
            .eq("room_id", value: roomId).eq("user_id", value: uid).execute()
    }

    /// 회원 탈퇴: 본인 데이터 정리 후 계정 삭제 (전체관리자 불가 — RPC 로 강제)
    static func deleteAccount() async throws {
        try await supabase.rpc("moim_delete_my_account").execute()
    }

    /// 구성원 초대 (방에 회원 추가 — 방 생성자/관리자, RLS). 이미 참여 중이면 무시.
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

    private static func isJwtExpired(_ error: Error) -> Bool {
        let m = error.localizedDescription.lowercased()
        return m.contains("jwt expired") || m.contains("invalid jwt") || m.contains("invalid claim")
    }

    private static func withFreshSession<T>(_ block: () async throws -> T) async throws -> T {
        do {
            return try await block()
        } catch {
            guard isJwtExpired(error) else { throw error }
            try await supabase.auth.refreshSession()
            return try await block()
        }
    }

    static func ensureFreshSession() async {
        guard currentUserId() != nil else { return }
        try? await supabase.auth.refreshSession()
    }

    // ── 채팅 ──
    static func messages(roomId: String) async throws -> [Message] {
        try await supabase.from("messages")
            .select().eq("room_id", value: roomId)
            .order("created_at", ascending: true).execute().value
    }

    /// 본인이 쓴 메시지(텍스트/사진/파일) 삭제. RLS 로 본인·관리자만 허용
    static func deleteMessage(id: String) async throws {
        try await supabase.from("messages").delete().eq("id", value: id).execute()
    }

    // ── 읽음 추적 ──
    static func markRead(roomId: String) async throws {
        try await supabase.rpc("moim_mark_read", params: ["p_room": roomId]).execute()
    }
    static func unreadCounts() async throws -> [String: Int] {
        let rows: [UnreadRoomRow] = try await supabase.rpc("moim_unread_counts").execute().value
        return Dictionary(rows.map { ($0.roomId, $0.cnt) }, uniquingKeysWith: { a, _ in a })
    }
    static func messageUnreadCounts(roomId: String) async throws -> [String: Int] {
        let rows: [UnreadMsgRow] = try await supabase.rpc("moim_message_unread_counts", params: ["p_room": roomId]).execute().value
        return Dictionary(rows.map { ($0.messageId, $0.unread) }, uniquingKeysWith: { a, _ in a })
    }
    static func roomLastMessages() async throws -> [String: LastMsg] {
        let rows: [LastMsg] = try await supabase.rpc("moim_room_last_messages").execute().value
        return Dictionary(rows.map { ($0.roomId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    // 개인 고정 방 순서
    static func roomPins() async throws -> [String] {
        let rows: [RoomPinRow] = try await supabase.from("room_pins")
            .select("room_id, position").order("position").execute().value
        return rows.map { $0.roomId }
    }
    static func setRoomPins(_ ids: [String]) async throws {
        try await supabase.rpc("moim_set_room_pins", params: ["p_rooms": Array(ids.prefix(5))]).execute()
    }

    static func sendMessage(roomId: String, text: String, replyTo: String? = nil) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let payload = MessageInsert(roomId: roomId, senderId: uid, content: text, replyTo: replyTo)
        try await supabase.from("messages").insert(payload).execute()
    }

    // ── 이모지 리액션 ──
    static func roomReactions(roomId: String) async throws -> [Reaction] {
        try await supabase.rpc("moim_room_reactions", params: ["p_room": roomId]).execute().value
    }

    /// 리액션 토글: 내 같은 이모지가 있으면 취소, 없으면 추가
    static func toggleReaction(messageId: String, emoji: String) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let mine: [Reaction] = try await supabase.from("message_reactions")
            .select().eq("message_id", value: messageId).eq("user_id", value: uid).eq("emoji", value: emoji)
            .execute().value
        if mine.isEmpty {
            try await supabase.from("message_reactions")
                .insert(ReactionInsert(messageId: messageId, userId: uid, emoji: emoji)).execute()
        } else {
            try await supabase.from("message_reactions").delete()
                .eq("message_id", value: messageId).eq("user_id", value: uid).eq("emoji", value: emoji).execute()
        }
    }

    /// 카톡식 첨부 전송: 공개 room-files 업로드 후 공개 URL 을 담아 메시지 삽입 (type = image | file)
    static func sendAttachment(roomId: String, fileName: String, data: Data, type: String, caption: String? = nil) async throws {
        guard let uid = currentUserId() else { throw AppError.notLoggedIn }
        let url = try await uploadToStorage(roomId: roomId, fileName: fileName, data: data)
        let cap = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = MessageInsert(
            roomId: roomId, senderId: uid, content: cap.flatMap { $0.isEmpty ? nil : $0 }, type: type,
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
        attachments: [(name: String, data: Data)],
        repeatRule: String = "none",
        repeatCount: Int = 1
    ) async throws {
        try await withFreshSession {
            guard let uid = currentUserId() else { throw AppError.notLoggedIn }
            var urls = [String]()
            var names = [String]()
            for a in attachments {
                urls.append(try await uploadToStorage(roomId: roomId, fileName: a.name, data: a.data))
                names.append(a.name)
            }
            let startAts = expandRepeatStartAts(baseStartAt: startAt, rule: repeatRule, count: repeatCount)
            let payloads = startAts.map { at in
                CalendarEventInsert(
                    roomId: roomId, title: title, startAt: at,
                    place: place, link: link, scope: scope, description: description,
                    presenter: (presenter?.isEmpty == false) ? presenter : nil,
                    keywords: keywords, ownerId: uid,
                    attachmentUrls: urls, attachmentNames: names
                )
            }
            try await supabase.from("calendar_events").insert(payloads).execute()
        }
    }

    /// 일정 삭제 (작성자/관리자/교실·의국·비서·심리실 — RLS 로 강제)
    static func deleteEvent(id: String) async throws {
        try await withFreshSession {
            try await supabase.from("calendar_events").delete().eq("id", value: id).execute()
        }
    }

    static func updateEvent(
        eventId: String, roomId: String, title: String, startAt: String,
        place: String?, link: String?, scope: String?, description: String?,
        presenter: String?, keywords: [String],
        keptUrls: [String], keptNames: [String], newAttachments: [(name: String, data: Data)]
    ) async throws {
        try await withFreshSession {
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

    // ── 당직표 ──
    static func wardDuties(from: String, to: String) async throws -> [WardDuty] {
        try await supabase.from("ward_duty")
            .select()
            .gte("duty_date", value: from)
            .lte("duty_date", value: to)
            .order("duty_date", ascending: true)
            .execute().value
    }

    static func upsertWardDuty(
        dutyDate: String, profDay: String, residentDay: String, residentNight: String,
        residentOutpatient1: String, residentOutpatient2: String
    ) async throws {
        try await withFreshSession {
            guard let uid = currentUserId() else { throw AppError.notLoggedIn }
            let now = ISO8601DateFormatter().string(from: Date())
            let payload = WardDutyUpsert(
                dutyDate: dutyDate, profDay: profDay, residentDay: residentDay, residentNight: residentNight,
                residentOutpatient1: residentOutpatient1, residentOutpatient2: residentOutpatient2,
                updatedBy: uid, updatedAt: now
            )
            let existing = try await wardDuties(from: dutyDate, to: dutyDate)
            if existing.isEmpty {
                try await supabase.from("ward_duty").insert(payload).execute()
            } else {
                try await supabase.from("ward_duty").update(payload).eq("duty_date", value: dutyDate).execute()
            }
        }
    }

    /// Storage object key — ASCII only (Supabase/S3 rejects non-ASCII in key). DB에는 원본 파일명 저장.
    private static func storageObjectKey(roomId: String, fileName: String) -> String {
        let rawExt = (fileName as NSString).pathExtension
        let ext = rawExt.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
            .lowercased()
        let e = ext.isEmpty ? "bin" : String(ext.prefix(16))
        let token = UUID().uuidString.lowercased().prefix(8)
        return "\(roomId)/\(Int(Date().timeIntervalSince1970 * 1000))_\(token).\(e)"
    }

    /// Storage('room-files' 버킷) 업로드 후 공개 URL 반환
    static func uploadToStorage(roomId: String, fileName: String, data: Data) async throws -> String {
        let path = storageObjectKey(roomId: roomId, fileName: fileName)
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
