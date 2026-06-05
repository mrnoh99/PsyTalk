import Foundation
import SwiftUI

// =====================================================================
//  ViewModel — Android MoimViewModel 과 동일 상태/로직
// =====================================================================
@MainActor
final class MoimViewModel: ObservableObject {

    @Published var loggedIn: Bool = MoimRepository.currentUserId() != nil
    @Published var myProfile: Profile?
    @Published var rooms: [Room] = []
    @Published var messages: [Message] = []
    @Published var events: [CalendarEvent] = []
    @Published var files: [RoomFile] = []
    @Published var profilesById: [String: Profile] = [:]
    // 채팅 첨부 path → 서명 URL 캐시 (방 구성원만 발급됨)
    @Published var attachmentUrls: [String: String] = [:]
    // 읽음 표시: #1 방별 안읽은 수, #2 메시지별 안읽은 사람 수
    @Published var unreadByRoom: [String: Int] = [:]
    @Published var unreadByMsg: [String: Int] = [:]
    // 방별 마지막 메시지 (방 목록 미리보기)
    @Published var lastMsgByRoom: [String: LastMsg] = [:]
    // 개인 고정 방 순서 (room id, 최대 5)
    @Published var roomPins: [String] = []
    @Published var error: String?
    @Published var notice: String?
    @Published var loading = false

    func signUp(email: String, password: String, name: String, memberType: String) {
        Task {
            loading = true; error = nil; notice = nil
            do {
                try await MoimRepository.signUp(email: email, password: password, name: name, memberType: memberType)
                if MoimRepository.currentUserId() != nil {
                    myProfile = try await MoimRepository.myProfile()
                    rooms = try await MoimRepository.rooms()
                    if let list = try? await MoimRepository.allProfiles() {
                        profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                    }
                    loggedIn = true
                    if let uid = MoimRepository.currentUserId() { Push.login(uid) }
                    bindRealtime()
                } else {
                    notice = "가입이 접수되었습니다. 전체관리자 승인 후 로그인하여 이용할 수 있습니다."
                }
            } catch { self.error = "회원가입: \(error.localizedDescription)" }
            loading = false
        }
    }

    private var activeRoom: String?
    private var messagePollTask: Task<Void, Never>?
    init() {
        if MoimRepository.currentUserId() != nil {
            bindRealtime()
        }
    }

    /// Realtime 구독 (이미 연결 중이면 재구독)
    private func bindRealtime() {
        Task { await rebindRealtime() }
    }

    private func rebindRealtime() async {
        await MoimRealtimeSync.shared.start(
            onRooms: { await self.loadRoomsFromRealtime() },
            onRoomMembers: { await self.onRoomMembersChangedOnly() },
            onProfiles: { await self.loadProfilesFromRealtime() },
            onWard: { await self.loadWardStatusFromRealtime() },
            onRoomData: { await self.refreshActiveRoom($0) }
        )
    }

    /// 앱 복귀·다른 클라이언트 변경 반영
    func refreshOnForeground() {
        guard loggedIn else { return }
        loadRooms()
        Task {
            await rebindRealtime()
            if let rid = activeRoom { await refreshActiveRoom(rid) }
        }
    }

    private func loadRoomsFromRealtime() async {
        do {
            myProfile = try await MoimRepository.myProfile()
            rooms = try await MoimRepository.rooms()
            unreadByRoom = (try? await MoimRepository.unreadCounts()) ?? unreadByRoom
            lastMsgByRoom = (try? await MoimRepository.roomLastMessages()) ?? lastMsgByRoom
        } catch { /* 조용히 재시도 — 다음 이벤트에서 갱신 */ }
    }

    /// 가입 신청·승인 상태 등 profiles 변경 시 (관리자 가입 승인 목록·배지 갱신)
    private func loadProfilesFromRealtime() async {
        guard let list = try? await MoimRepository.allProfiles() else { return }
        profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        if let uid = MoimRepository.currentUserId(), let me = profilesById[uid] {
            myProfile = me
        }
    }

    private func loadWardStatusFromRealtime() async {
        do {
            let w = try await MoimRepository.wardStatus()
            wardStatus = w.content
            wardStatusUpdatedAt = w.updatedAt
        } catch { }
    }

    private func refreshActiveRoom(_ roomId: String) async {
        guard activeRoom == roomId else { return }
        do { messages = try await MoimRepository.messages(roomId: roomId) } catch { }
        markActiveRead()
        await loadRoomData(roomId)
        resolveAttachments()
    }

    /// Realtime 보조 — 열린 방 메시지·일정·자료 3초 폴링 (WS 누락 방지, Android 와 동일)
    private func startMessagePolling() {
        messagePollTask?.cancel()
        messagePollTask = Task {
            if let rid = activeRoom {
                await refreshActiveRoom(rid)
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, let rid = activeRoom else { return }
                await refreshActiveRoom(rid)
            }
        }
    }

    private func stopMessagePolling() {
        messagePollTask?.cancel()
        messagePollTask = nil
    }

    func login(email: String, password: String) {
        Task {
            loading = true; error = nil
            do {
                try await MoimRepository.signIn(email: email, password: password)
                myProfile = try await MoimRepository.myProfile()
                rooms = try await MoimRepository.rooms()
                loggedIn = true
                if let uid = MoimRepository.currentUserId() { Push.login(uid) }
                bindRealtime()
            } catch {
                loggedIn = false
                try? await MoimRepository.signOut()
                self.error = "로그인: \(error.localizedDescription)"
            }
            loading = false
        }
    }

    func logout() {
        stopMessagePolling()
        Push.logout()
        Task {
            await MoimRealtimeSync.shared.stop()
            try? await MoimRepository.signOut()
            loggedIn = false
            rooms = []; myProfile = nil
        }
    }

    func loadRooms() {
        Task {
            do {
                myProfile = try await MoimRepository.myProfile()
                rooms = try await MoimRepository.rooms()
                loadRoomMemberCounts()
                loadUnreadCounts()
                loadLastMessages()
                loadRoomPins()
                if let list = try? await MoimRepository.allProfiles() {
                    profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                }
            } catch {
                self.error = "데이터 불러오기: \(error.localizedDescription)"
            }
        }
    }

    func openRoom(_ room: Room) {
        activeRoom = room.id
        messages = []; events = []; files = []
        Task {
            await MoimRealtimeSync.shared.setActiveRoom(room.id)
            do { messages = try await MoimRepository.messages(roomId: room.id) }
            catch { self.error = "메시지 불러오기: \(error.localizedDescription)" }
            await loadRoomData(room.id)
            resolveAttachments()
            startMessagePolling()
            markActiveRead()
        }
    }

    private func loadRoomData(_ roomId: String) async {
        do { events = try await MoimRepository.events(roomId: roomId) }
        catch { self.error = "일정 불러오기: \(error.localizedDescription)" }
        do { files = try await MoimRepository.files(roomId: roomId) }
        catch { self.error = "자료 불러오기: \(error.localizedDescription)" }
    }

    func closeRoom() {
        stopMessagePolling()
        activeRoom = nil
        Task { await MoimRealtimeSync.shared.setActiveRoom(nil) }
        messages = []; events = []; files = []
    }

    func send(_ text: String) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.sendMessage(roomId: rid, text: text)
                messages = try await MoimRepository.messages(roomId: rid)
            } catch { self.error = "전송: \(error.localizedDescription)" }
        }
    }

    /// 방별 안읽은 수 갱신 (방 목록)
    func loadUnreadCounts() {
        Task { do { unreadByRoom = try await MoimRepository.unreadCounts() } catch {} }
    }

    /// 방별 마지막 메시지 갱신 (방 목록)
    func loadLastMessages() {
        Task { do { lastMsgByRoom = try await MoimRepository.roomLastMessages() } catch {} }
    }

    /// 개인 고정 방 순서 불러오기
    func loadRoomPins() {
        Task { do { roomPins = try await MoimRepository.roomPins() } catch {} }
    }
    /// 고정 방 순서 저장 (최대 5)
    func saveRoomPins(_ ids: [String]) {
        Task {
            do { try await MoimRepository.setRoomPins(ids); roomPins = Array(ids.prefix(5)) }
            catch { self.error = "방 순서 저장: \(error.localizedDescription)" }
        }
    }

    /// 현재 방 읽음 처리 + 안읽은 수 갱신
    func markActiveRead() {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.markRead(roomId: rid)
                unreadByMsg = try await MoimRepository.messageUnreadCounts(roomId: rid)
                unreadByRoom = try await MoimRepository.unreadCounts()
            } catch {}
        }
    }

    /// 본인이 쓴 메시지(텍스트/사진/파일) 삭제
    func deleteMessage(_ id: String) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.deleteMessage(id: id)
                messages = try await MoimRepository.messages(roomId: rid)
            } catch { self.error = "메시지 삭제: \(error.localizedDescription)" }
        }
    }

    /// 카톡식 첨부 전송 (type = image | file)
    func sendAttachment(fileName: String, data: Data, type: String) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.sendAttachment(roomId: rid, fileName: fileName, data: data, type: type)
                messages = try await MoimRepository.messages(roomId: rid)
                resolveAttachments()
            } catch { self.error = "첨부 전송: \(error.localizedDescription)" }
        }
    }

    /// 채팅 첨부(path) → 서명 URL 해석 (방 구성원만). messages 변경 시 호출.
    func resolveAttachments() {
        let paths = messages.compactMap { $0.attachmentUrl }
            .filter { !$0.isEmpty && attachmentUrls[$0] == nil }
        guard !paths.isEmpty else { return }
        Task {
            var map = attachmentUrls
            for p in Set(paths) {
                if let u = await MoimRepository.chatSignedUrl(p) { map[p] = u }
            }
            attachmentUrls = map
        }
    }

    func createEvent(
        title: String, startAt: String, place: String?, link: String?,
        scope: String?, description: String?, presenter: String?, keywords: [String],
        attachments: [(name: String, data: Data)],
        onDone: @escaping () -> Void
    ) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.createEvent(
                    roomId: rid, title: title, startAt: startAt, place: place, link: link,
                    scope: scope, description: description, presenter: presenter, keywords: keywords,
                    attachments: attachments)
                events = try await MoimRepository.events(roomId: rid)
                files = try await MoimRepository.files(roomId: rid)
                onDone()
            } catch { self.error = "일정 등록: \(error.localizedDescription)" }
        }
    }

    func deleteEvent(_ id: String) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.deleteEvent(id: id)
                events = try await MoimRepository.events(roomId: rid)
            } catch { self.error = "일정 삭제: \(error.localizedDescription)" }
        }
    }

    func updateEvent(
        eventId: String, title: String, startAt: String, place: String?, link: String?,
        scope: String?, description: String?, presenter: String?, keywords: [String],
        keptUrls: [String], keptNames: [String], newAttachments: [(name: String, data: Data)],
        onDone: @escaping () -> Void
    ) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.updateEvent(
                    eventId: eventId, roomId: rid, title: title, startAt: startAt, place: place, link: link,
                    scope: scope, description: description, presenter: presenter, keywords: keywords,
                    keptUrls: keptUrls, keptNames: keptNames, newAttachments: newAttachments)
                events = try await MoimRepository.events(roomId: rid)
                files = try await MoimRepository.files(roomId: rid)
                onDone()
            } catch { self.error = "일정 수정: \(error.localizedDescription)" }
        }
    }

    func uploadFile(
        fileName: String, data: Data, description: String?, keywords: [String],
        onDone: @escaping () -> Void
    ) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.uploadRoomFile(
                    roomId: rid, fileName: fileName, data: data, description: description, keywords: keywords)
                files = try await MoimRepository.files(roomId: rid)
                onDone()
            } catch { self.error = "자료 업로드: \(error.localizedDescription)" }
        }
    }

    // ── 잔여 병실 현황 (메모) ──
    @Published var wardStatus: String = ""
    @Published var wardStatusUpdatedAt: String?

    func loadWardStatus() {
        Task {
            do {
                let w = try await MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
            } catch { self.error = "잔여 병실 현황 불러오기: \(error.localizedDescription)" }
        }
    }

    func saveWardStatus(_ content: String, onDone: @escaping () -> Void) {
        Task {
            do {
                try await MoimRepository.updateWardStatus(content: content)
                let w = try await MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
                onDone()
            } catch { self.error = "잔여 병실 현황 저장: \(error.localizedDescription)" }
        }
    }

    func createRoom(name: String, memberIds: [String], onDone: @escaping () -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        // 같은 이름의 모임방 금지 (보이는 방 기준 즉시 검사 + DB 유니크 인덱스가 최종 강제)
        if rooms.contains(where: { $0.category == "custom" && $0.name == trimmed }) {
            self.error = "같은 이름의 모임방이 이미 있습니다. 다른 이름을 사용하세요."
            return
        }
        Task {
            do {
                _ = try await MoimRepository.createRoom(name: trimmed, memberIds: memberIds)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { self.error = "방 만들기: \(friendlyError(error))" }
        }
    }

    /// 모임방 삭제 (생성자/관리자)
    func deleteRoom(_ room: Room, onDone: @escaping () -> Void) {
        Task {
            do {
                try await MoimRepository.deleteRoom(roomId: room.id)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { self.error = "모임방 삭제: \(error.localizedDescription)" }
        }
    }

    /// 현재 방 멤버 id 목록
    @Published var roomMemberIds: [String] = []
    @Published var roomMembersLoaded = false
    @Published var roomMemberCounts: [String: Int] = [:]
    private var memberListRoomId: String?

    func loadRoomMemberCounts() {
        Task {
            roomMemberCounts = (try? await MoimRepository.roomMemberCounts()) ?? [:]
        }
    }

    func loadRoomMembers(_ roomId: String) {
        memberListRoomId = roomId
        roomMembersLoaded = false
        Task {
            do {
                roomMemberIds = try await MoimRepository.roomMemberIds(roomId: roomId)
            } catch {
                roomMemberIds = []
                self.error = "멤버 목록: \(error.localizedDescription)"
            }
            roomMembersLoaded = true
        }
    }

    private func onRoomMembersChangedOnly() async {
        if let rid = memberListRoomId { loadRoomMembers(rid) }
        loadRoomMemberCounts()
    }

    /// 멤버 내보내기 (생성자/관리자)
    func removeRoomMember(roomId: String, userId: String) {
        Task {
            do {
                try await MoimRepository.removeRoomMember(roomId: roomId, userId: userId)
                roomMemberIds = (try? await MoimRepository.roomMemberIds(roomId: roomId)) ?? []
                loadRoomMemberCounts()
            } catch { self.error = "멤버 내보내기: \(error.localizedDescription)" }
        }
    }

    /// 구성원 초대 (방에 멤버 추가 — 관리자 콘솔)
    func inviteRoomMember(roomId: String, userId: String) {
        Task {
            do {
                try await MoimRepository.addRoomMembers(roomId: roomId, userIds: [userId])
                roomMemberIds = (try? await MoimRepository.roomMemberIds(roomId: roomId)) ?? []
                loadRoomMemberCounts()
            } catch { self.error = "구성원 초대: \(error.localizedDescription)" }
        }
    }

    /// 전체관리자 여부 (관리자 콘솔의 방 삭제 권한)
    var isSuperAdmin: Bool { myProfile?.role == "superadmin" }

    /// 모임방 관리 권한: 관리자는 모든 방, 그 외는 custom 방 생성자
    func canManageRoom(_ room: Room) -> Bool {
        if let r = myProfile?.role, r == "superadmin" || r == "admin" { return true }
        guard room.category == "custom" else { return false }
        return room.createdBy != nil && room.createdBy == MoimRepository.currentUserId()
    }

    /// 방 나가기 권한: 본인이 만들지 않은 모임방(custom) — 관리자·생성자가 아닌 경우
    func canLeaveRoom(_ room: Room) -> Bool {
        room.category == "custom" && !canManageRoom(room)
    }

    /// 방 나가기 (본인이 만들지 않은 모임방). 성공 시 방 목록으로 복귀
    func leaveRoom(_ room: Room, onDone: @escaping () -> Void) {
        Task {
            do {
                try await MoimRepository.leaveRoom(roomId: room.id)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { self.error = "방 나가기: \(error.localizedDescription)" }
        }
    }

    /// 회원 탈퇴 (본인 데이터 정리 후 계정 삭제, 전체관리자 불가). 성공 시 로그아웃
    func deleteAccount() {
        Task {
            do {
                try await MoimRepository.deleteAccount()
                logout()
            } catch { self.error = "회원 탈퇴: \(error.localizedDescription)" }
        }
    }

    /// 같은 이름 모임방 등 친화적 오류 메시지
    private func friendlyError(_ error: Error) -> String {
        let m = error.localizedDescription
        if m.contains("42P17") || m.lowercased().contains("infinite recursion") {
            return "room_members 보안 정책 오류입니다. Supabase에서 room_manage.sql 을 다시 실행하세요."
        }
        if m.contains("23505") || m.lowercased().contains("duplicate key") || m.contains("rooms_custom_name_unique") {
            return "같은 이름의 모임방이 이미 있습니다. 다른 이름을 사용하세요."
        }
        return m
    }

    func renameRoom(_ room: Room, to name: String, onDone: @escaping () -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != room.name else { onDone(); return }
        Task {
            do {
                try await MoimRepository.updateRoomName(roomId: room.id, name: trimmed)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { self.error = "방 이름 변경: \(error.localizedDescription)" }
        }
    }

    func setRole(_ userId: String, to role: String) {
        Task {
            do {
                try await MoimRepository.updateRole(userId: userId, role: role)
                let list = try await MoimRepository.allProfiles()
                profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                if userId == MoimRepository.currentUserId() { myProfile = profilesById[userId] }
            } catch { self.error = "역할 변경: \(error.localizedDescription)" }
        }
    }

    func setApproved(_ userId: String, _ approved: Bool) {
        Task {
            do {
                try await MoimRepository.setApproved(userId: userId, approved: approved)
                let list = try await MoimRepository.allProfiles()
                profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                if userId == MoimRepository.currentUserId() { myProfile = profilesById[userId] }
            } catch { self.error = "승인 변경: \(error.localizedDescription)" }
        }
    }

    func setName(_ userId: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                try await MoimRepository.updateName(userId: userId, name: trimmed)
                let list = try await MoimRepository.allProfiles()
                profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                if userId == MoimRepository.currentUserId() { myProfile = profilesById[userId] }
            } catch { self.error = "이름 변경: \(error.localizedDescription)" }
        }
    }

    var otherProfiles: [Profile] {
        // 본인 제외 + 승인된 멤버만 (대기 중인 가입자는 방에 추가 불가)
        profilesById.values
            .filter { $0.id != MoimRepository.currentUserId() && ($0.approved ?? true) }
            .sorted { $0.name < $1.name }
    }

    func deleteFile(fileId: String, fileUrl: String?, onDone: @escaping () -> Void) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.deleteRoomFile(fileId: fileId, fileUrl: fileUrl)
                files = try await MoimRepository.files(roomId: rid)
                onDone()
            } catch { self.error = "자료 삭제: \(error.localizedDescription)" }
        }
    }

    func canManageFile(_ uploadedBy: String) -> Bool {
        if let r = myProfile?.role, r == "superadmin" || r == "admin" { return true }
        return uploadedBy == MoimRepository.currentUserId()
    }

    func name(of userId: String) -> String { profilesById[userId]?.name ?? "?" }

    func isMine(_ m: Message) -> Bool { m.senderId == MoimRepository.currentUserId() }

    func canEditEvent(_ e: CalendarEvent) -> Bool {
        if let r = myProfile?.role, r == "superadmin" || r == "admin" { return true }
        return e.ownerId == MoimRepository.currentUserId()
    }
}
