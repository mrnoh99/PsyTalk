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
    @Published var loading = false

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

    // ── 병실 잔여 현황 (메모) ──
    @Published var wardStatus: String = ""
    @Published var wardStatusUpdatedAt: String?

    func loadWardStatus() {
        Task {
            do {
                let w = try await MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
            } catch { self.error = "병실현황 불러오기: \(error.localizedDescription)" }
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
            } catch { self.error = "병실현황 저장: \(error.localizedDescription)" }
        }
    }

    func createRoom(name: String, memberIds: [String], onDone: @escaping () -> Void) {
        Task {
            do {
                _ = try await MoimRepository.createRoom(name: name, memberIds: memberIds)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { self.error = "방 만들기: \(error.localizedDescription)" }
        }
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
        profilesById.values
            .filter { $0.id != MoimRepository.currentUserId() }
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
