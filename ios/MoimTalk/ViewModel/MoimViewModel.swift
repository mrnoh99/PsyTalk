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
                } else {
                    notice = "가입 완료! 이메일 인증 후 로그인하세요."
                }
            } catch { self.error = "회원가입: \(error.localizedDescription)" }
            loading = false
        }
    }

    private var activeRoom: String?

    func login(email: String, password: String) {
        Task {
            loading = true; error = nil
            do {
                try await MoimRepository.signIn(email: email, password: password)
                myProfile = try await MoimRepository.myProfile()
                rooms = try await MoimRepository.rooms()
                loggedIn = true
            } catch {
                loggedIn = false
                try? await MoimRepository.signOut()
                self.error = "로그인: \(error.localizedDescription)"
            }
            loading = false
        }
    }

    func logout() {
        Task {
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
            do { messages = try await MoimRepository.messages(roomId: room.id) }
            catch { self.error = "메시지 불러오기: \(error.localizedDescription)" }
            await loadRoomData(room.id)
        }
    }

    private func loadRoomData(_ roomId: String) async {
        do { events = try await MoimRepository.events(roomId: roomId) }
        catch { self.error = "일정 불러오기: \(error.localizedDescription)" }
        do { files = try await MoimRepository.files(roomId: roomId) }
        catch { self.error = "자료 불러오기: \(error.localizedDescription)" }
    }

    func closeRoom() {
        activeRoom = nil
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
    func loadRoomMembers(_ roomId: String) {
        Task {
            roomMemberIds = (try? await MoimRepository.roomMemberIds(roomId: roomId)) ?? []
        }
    }

    /// 멤버 내보내기 (생성자/관리자)
    func removeRoomMember(roomId: String, userId: String) {
        Task {
            do {
                try await MoimRepository.removeRoomMember(roomId: roomId, userId: userId)
                roomMemberIds = (try? await MoimRepository.roomMemberIds(roomId: roomId)) ?? []
            } catch { self.error = "멤버 내보내기: \(error.localizedDescription)" }
        }
    }

    /// 모임방 관리 권한 (custom 방에 한해 생성자 또는 관리자)
    func canManageRoom(_ room: Room) -> Bool {
        guard room.category == "custom" else { return false }
        if let r = myProfile?.role, r == "superadmin" || r == "admin" { return true }
        return room.createdBy != nil && room.createdBy == MoimRepository.currentUserId()
    }

    /// 같은 이름 모임방 등 친화적 오류 메시지
    private func friendlyError(_ error: Error) -> String {
        let m = error.localizedDescription
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
