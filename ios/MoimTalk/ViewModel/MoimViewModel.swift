import Foundation
import SwiftUI
import Supabase

// =====================================================================
//  ViewModel — Android MoimViewModel 과 동일 상태/로직
// =====================================================================
@MainActor
final class MoimViewModel: ObservableObject {

    @Published var loggedIn: Bool = MoimRepository.hasValidSession()
    @Published var myProfile: Profile?
    @Published var rooms: [Room] = []
    @Published var messages: [Message] = []
    @Published var reactions: [Reaction] = []        // 활성 방 이모지 리액션
    @Published var replyTarget: Message?             // 답장 대상(작성 중)
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
    // 내가 가입한 방 id (홈 목록에서 superadmin/admin 도 가입 방만 표시; 관리자 콘솔은 전체 rooms)
    @Published var myRoomIds: Set<String> = []
    @Published var error: String?
    @Published var notice: String?
    @Published var loading = false

    // 설정 화면 (내 정보 / 방 순서 / 회원 검색)
    @Published var settingsTab: String = "myInfo"   // myInfo | order | search
    @Published var memberSearchQ: String = ""
    @Published var memberSearchSort: String = "name"   // name | type
    // 관리자 콘솔 회원 관리 정렬
    @Published var memAdminSort: String = "name"       // name | type

    func signUp(email: String, password: String, name: String, memberType: String, phone: String, intro: String, deviceType: String, deviceEmail: String) {
        Task {
            loading = true; error = nil; notice = nil
            do {
                try await MoimRepository.signUp(email: email, password: password, name: name, memberType: memberType, phone: phone, intro: intro, deviceType: deviceType, deviceEmail: deviceEmail)
                if MoimRepository.currentUserId() != nil {
                    myProfile = try await MoimRepository.myProfile()
                    rooms = try await MoimRepository.rooms()
                    if let list = try? await MoimRepository.allProfiles() {
                        profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                    }
                    loggedIn = true
                    bindRealtime()
                } else {
                    notice = "가입이 접수되었습니다. 전체관리자 승인 후 로그인하여 이용할 수 있습니다."
                }
            } catch { reportError("회원가입", error) }
            loading = false
        }
    }

    private var activeRoom: String?
    private var roomLoadGeneration: UInt64 = 0
    private var openRoomTask: Task<Void, Never>?
    private var messagePollTask: Task<Void, Never>?
    private var foregroundRefreshTask: Task<Void, Never>?
    private var authListenerTask: Task<Void, Never>?

    init() {
        if MoimRepository.hasValidSession() {
            bindRealtime()
        }
        startAuthListener()
    }

    /// supabase-swift emitLocalSessionAsInitialSession — 만료·로그아웃 시 loggedIn 동기화
    private func startAuthListener() {
        authListenerTask?.cancel()
        authListenerTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                await self.handleAuthChange(event: event, session: session)
            }
        }
    }

    private func handleAuthChange(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .initialSession:
            if let session, !session.isExpired {
                loggedIn = true
                if myProfile == nil {
                    bindRealtime()
                    loadRooms()
                }
            } else if session == nil {
                loggedIn = false
            }
        case .signedIn, .tokenRefreshed:
            guard let session, !session.isExpired else { return }
            let wasLoggedIn = loggedIn
            loggedIn = true
            if !wasLoggedIn {
                bindRealtime()
                loadRooms()
            }
        case .signedOut:
            stopMessagePolling()
            loggedIn = false
            rooms = []
            myProfile = nil
        default:
            break
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
        await loadProfilesFromRealtime()
    }

    /// 앱 복귀·다른 클라이언트 변경 반영 (사진 선택기 등 잠깐 나갔다 올 때도 호출됨)
    func refreshOnForeground() {
        guard loggedIn else { return }
        loadRooms()
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = Task {
            await MoimRepository.ensureFreshSession()
            guard !Task.isCancelled else { return }
            await rebindRealtime()
            guard !Task.isCancelled, let rid = activeRoom else { return }
            await refreshActiveRoom(rid)
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
        refreshWardDutiesQuiet()
    }

    private func refreshActiveRoom(_ roomId: String) async {
        guard !Task.isCancelled, activeRoom == roomId else { return }
        let gen = roomLoadGeneration
        do { messages = try await MoimRepository.messages(roomId: roomId) }
        catch { guard !isBenignCancellation(error) else { return } }
        guard !Task.isCancelled, activeRoom == roomId, gen == roomLoadGeneration else { return }
        reactions = (try? await MoimRepository.roomReactions(roomId: roomId)) ?? []
        markActiveRead()
        await loadRoomData(roomId, generation: gen)
        guard !Task.isCancelled, activeRoom == roomId, gen == roomLoadGeneration else { return }
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

    func login(idInput: String, password: String) {
        Task {
            loading = true; error = nil
            do {
                // 이메일 또는 핸드폰번호 로그인: @ 없으면 핸드폰번호로 보고 이메일을 조회
                var email = idInput
                if !idInput.contains("@") {
                    if let e = try? await MoimRepository.emailForPhone(idInput) { email = e }
                    else { throw NSError(domain: "moim", code: 1, userInfo: [NSLocalizedDescriptionKey: "등록되지 않은 핸드폰번호입니다. 이메일로 로그인하거나 번호를 확인하세요."]) }
                }
                try await MoimRepository.signIn(email: email, password: password)
                myProfile = try await MoimRepository.myProfile()
                rooms = try await MoimRepository.rooms()
                if let list = try? await MoimRepository.allProfiles() {
                    profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                }
                loggedIn = true
                bindRealtime()
            } catch {
                loggedIn = false
                try? await MoimRepository.signOut()
                reportError("로그인", error)
            }
            loading = false
        }
    }

    func logout() {
        stopMessagePolling()
        Task {
            await MoimRealtimeSync.shared.stop()
            try? await MoimRepository.signOut()
            loggedIn = false
            rooms = []; myProfile = nil
        }
    }

    func loadProfiles() {
        Task { await loadProfilesFromRealtime() }
    }

    func loadRooms() {
        Task {
            do {
                myProfile = try await MoimRepository.myProfile()
                rooms = try await MoimRepository.rooms()
                if let ids = try? await MoimRepository.myRoomIds() { myRoomIds = Set(ids) }
                loadRoomMemberCounts()
                loadUnreadCounts()
                loadLastMessages()
                loadRoomPins()
                await loadProfilesFromRealtime()
            } catch {
                reportError("데이터 불러오기", error)
            }
        }
    }

    func openRoom(_ room: Room) {
        openRoomTask?.cancel()
        stopMessagePolling()
        roomLoadGeneration &+= 1
        let gen = roomLoadGeneration
        activeRoom = room.id
        messages = []; events = []; files = []; reactions = []; replyTarget = nil
        openRoomTask = Task {
            await MoimRealtimeSync.shared.setActiveRoom(room.id)
            guard !Task.isCancelled, activeRoom == room.id, gen == roomLoadGeneration else { return }
            do {
                messages = try await MoimRepository.messages(roomId: room.id)
                reactions = (try? await MoimRepository.roomReactions(roomId: room.id)) ?? []
            }
            catch { reportError("메시지 불러오기", error) }
            guard !Task.isCancelled, activeRoom == room.id, gen == roomLoadGeneration else { return }
            await loadRoomData(room.id, generation: gen)
            guard !Task.isCancelled, activeRoom == room.id, gen == roomLoadGeneration else { return }
            resolveAttachments()
            startMessagePolling()
            markActiveRead()
        }
    }

    private func loadRoomData(_ roomId: String, generation: UInt64? = nil) async {
        let gen = generation ?? roomLoadGeneration
        guard !Task.isCancelled, activeRoom == roomId, gen == roomLoadGeneration else { return }
        do { events = try await MoimRepository.events(roomId: roomId) }
        catch { reportError("일정 불러오기", error) }
        guard !Task.isCancelled, activeRoom == roomId, gen == roomLoadGeneration else { return }
        do { files = try await MoimRepository.files(roomId: roomId) }
        catch { reportError("자료 불러오기", error) }
    }

    func closeRoom() {
        roomLoadGeneration &+= 1
        openRoomTask?.cancel()
        openRoomTask = nil
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = nil
        stopMessagePolling()
        activeRoom = nil
        Task { await MoimRealtimeSync.shared.setActiveRoom(nil) }
        messages = []; events = []; files = []
    }

    func send(_ text: String) {
        guard let rid = activeRoom else { return }
        let replyId = replyTarget?.id
        replyTarget = nil
        Task {
            do {
                try await MoimRepository.sendMessage(roomId: rid, text: text, replyTo: replyId)
                messages = try await MoimRepository.messages(roomId: rid)
            } catch { reportError("전송", error) }
        }
    }

    /// 답장 대상 설정/해제
    func setReply(_ m: Message?) { replyTarget = m }

    /// 이모지 리액션 토글 (내 같은 이모지 있으면 취소)
    func toggleReaction(_ messageId: String, _ emoji: String) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.toggleReaction(messageId: messageId, emoji: emoji)
                reactions = (try? await MoimRepository.roomReactions(roomId: rid)) ?? reactions
            } catch { reportError("리액션", error) }
        }
    }

    /// 메시지 id 로 조회 (답장 인용 표시용)
    func message(by id: String) -> Message? { messages.first { $0.id == id } }

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
            catch { reportError("방 순서 저장", error) }
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
            } catch { reportError("메시지 삭제", error) }
        }
    }

    /// 카톡식 첨부 전송 (type = image | file)
    func sendAttachment(fileName: String, data: Data, type: String, caption: String? = nil) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.sendAttachment(roomId: rid, fileName: fileName, data: data, type: type, caption: caption)
                messages = try await MoimRepository.messages(roomId: rid)
                resolveAttachments()
            } catch { reportError("첨부 전송", error) }
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
        repeatRule: String = "none",
        repeatCount: Int = 1,
        onDone: @escaping () -> Void
    ) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.createEvent(
                    roomId: rid, title: title, startAt: startAt, place: place, link: link,
                    scope: scope, description: description, presenter: presenter, keywords: keywords,
                    attachments: attachments, repeatRule: repeatRule, repeatCount: repeatCount)
                events = try await MoimRepository.events(roomId: rid)
                files = try await MoimRepository.files(roomId: rid)
                onDone()
            } catch { reportError("일정 등록", error) }
        }
    }

    func deleteEvent(_ id: String) {
        guard let rid = activeRoom else { return }
        Task {
            do {
                try await MoimRepository.deleteEvent(id: id)
                events = try await MoimRepository.events(roomId: rid)
            } catch { reportError("일정 삭제", error) }
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
            } catch { reportError("일정 수정", error) }
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
            } catch { reportError("자료 업로드", error) }
        }
    }

    // ── 잔여 병실 현황 (메모) ──
    @Published var wardStatus: String = ""
    @Published var wardStatusUpdatedAt: String?

    // ── 당직표 ──
    @Published var wardDuties: [String: WardDuty] = [:]
    @Published var wardDutyMonth: Date?
    @Published var wardTodayDuty: WardDuty?

    func loadWardStatus() {
        Task {
            do {
                let w = try await MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
            } catch { reportError("잔여 병실 현황 불러오기", error) }
        }
    }

    func loadWardDuties(month: Date) {
        wardDutyMonth = month
        Task {
            do {
                let cal = CalDate.cal
                let comps = cal.dateComponents([.year, .month], from: month)
                guard let start = cal.date(from: comps),
                      let range = cal.range(of: .day, in: .month, for: start),
                      let end = cal.date(byAdding: .day, value: range.count - 1, to: start) else { return }
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                fmt.timeZone = CalDate.kst
                let list = try await MoimRepository.wardDuties(from: fmt.string(from: start), to: fmt.string(from: end))
                wardDuties = Dictionary(uniqueKeysWithValues: list.map { ($0.dutyDate, $0) })
            } catch { reportError("당직표 불러오기", error) }
        }
    }

    func refreshWardDutiesQuiet() {
        if let m = wardDutyMonth { loadWardDuties(month: m) }
        loadWardTodayDuty()
    }

    func loadWardTodayDuty() {
        Task {
            do {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                fmt.timeZone = CalDate.kst
                let key = fmt.string(from: CalDate.today())
                wardTodayDuty = try await MoimRepository.wardDuties(from: key, to: key).first
            } catch { }
        }
    }

    func saveWardDuty(
        dutyDate: String, profDay: String, residentDay: String, residentNight: String,
        residentOutpatient1: String, residentOutpatient2: String,
        onDone: @escaping () -> Void
    ) {
        Task {
            do {
                try await MoimRepository.upsertWardDuty(
                    dutyDate: dutyDate, profDay: profDay, residentDay: residentDay, residentNight: residentNight,
                    residentOutpatient1: residentOutpatient1, residentOutpatient2: residentOutpatient2)
                if let m = wardDutyMonth { loadWardDuties(month: m) }
                loadWardTodayDuty()
                onDone()
            } catch { reportError("당직표 저장", error) }
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
            } catch { reportError("잔여 병실 현황 저장", error) }
        }
    }

    func createRoom(name: String, memberIds: [String], color: String? = nil, iconData: Data? = nil, iconName: String? = nil, onDone: @escaping () -> Void) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        // 같은 이름의 모임방 금지 (보이는 방 기준 즉시 검사 + DB 유니크 인덱스가 최종 강제)
        if rooms.contains(where: { $0.category == "custom" && $0.name == trimmed }) {
            self.error = "같은 이름의 모임방이 이미 있습니다. 다른 이름을 사용하세요."
            return
        }
        Task {
            do {
                _ = try await MoimRepository.createRoom(name: trimmed, memberIds: memberIds, color: color, iconData: iconData, iconName: iconName)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { reportError("방 만들기", error, friendly: friendlyError) }
        }
    }

    /// 모임방 삭제 (생성자/관리자)
    func deleteRoom(_ room: Room, onDone: @escaping () -> Void) {
        Task {
            do {
                try await MoimRepository.deleteRoom(roomId: room.id)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { reportError("모임방 삭제", error) }
        }
    }

    /// 현재 방 회원 id 목록
    @Published var roomMemberIds: [String] = []
    @Published var roomMembersLoaded = false
    @Published var roomMemberCounts: [String: Int] = [:]
    @Published private(set) var memberListRoomId: String?

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
                reportError("회원 목록", error)
            }
            roomMembersLoaded = true
        }
    }

    private func onRoomMembersChangedOnly() async {
        if let rid = memberListRoomId { loadRoomMembers(rid) }
        loadRoomMemberCounts()
    }

    /// 회원 내보내기 (생성자/관리자)
    func removeRoomMember(roomId: String, userId: String) {
        Task {
            do {
                try await MoimRepository.removeRoomMember(roomId: roomId, userId: userId)
                roomMemberIds = (try? await MoimRepository.roomMemberIds(roomId: roomId)) ?? []
                loadRoomMemberCounts()
            } catch { reportError("회원 내보내기", error) }
        }
    }

    /// 구성원 초대 (방에 회원 추가 — 관리자 콘솔)
    func inviteRoomMember(roomId: String, userId: String) {
        Task {
            do {
                try await MoimRepository.addRoomMembers(roomId: roomId, userIds: [userId])
                roomMemberIds = (try? await MoimRepository.roomMemberIds(roomId: roomId)) ?? []
                loadRoomMemberCounts()
            } catch { reportError("구성원 초대", error) }
        }
    }

    /// 전체관리자 여부 (관리자 콘솔의 방 삭제 권한)
    var isSuperAdmin: Bool { myProfile?.role == "superadmin" }

    /// 모임방 관리 권한: 관리자는 모든 방, 그 외는 custom 방 생성자
    func canManageRoom(_ room: Room) -> Bool {
        // 기본 방(과 전체공지·주간 학술활동 등 비-모임방)의 설정(⚙️)은 전체관리자만
        if room.category != "custom" { return isSuperAdmin }
        if let r = myProfile?.role, r == "superadmin" || r == "admin" { return true }
        return room.createdBy != nil && room.createdBy == MoimRepository.currentUserId()
    }

    /// 방 나가기 권한: 본인이 만들지 않은 모임방(custom) — 관리자·생성자가 아닌 경우
    func canLeaveRoom(_ room: Room) -> Bool {
        room.category == "custom" && !canManageRoom(room)
    }

    /// 방 삭제 권한: 모임방(custom)에 한해 생성자(본인이 만든 방) 또는 전체관리자(superadmin)
    func canDeleteRoom(_ room: Room) -> Bool {
        guard room.category == "custom" else { return false }
        if isSuperAdmin { return true }
        return room.createdBy != nil && room.createdBy == MoimRepository.currentUserId()
    }

    /// 방 나가기 (본인이 만들지 않은 모임방). 성공 시 방 목록으로 복귀
    func leaveRoom(_ room: Room, onDone: @escaping () -> Void) {
        Task {
            do {
                try await MoimRepository.leaveRoom(roomId: room.id)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { reportError("방 나가기", error) }
        }
    }

    /// 회원 탈퇴 (본인 데이터 정리 후 계정 삭제, 전체관리자 불가). 성공 시 로그아웃
    func deleteAccount() {
        Task {
            do {
                try await MoimRepository.deleteAccount()
                logout()
            } catch { reportError("회원 탈퇴", error) }
        }
    }

    // ── 내 정보 변경 / 회원 검색(1:1 DM) ──

    /// 설정 화면에서 startDirect 등으로 열 방을 RootView 가 관찰해 화면 전환
    @Published var pendingOpenRoom: Room?

    /// 내 정보 저장: 새 사진이 있으면 먼저 업로드 후 intro/member_type/avatar_url/color 갱신
    func saveMyInfo(intro: String, memberType: String, color: String?, avatarData: Data?, avatarExt: String?, clearAvatar: Bool, deviceType: String? = nil, deviceEmail: String? = nil, onDone: @escaping () -> Void) {
        Task {
            do {
                var avatarUrl: String? = clearAvatar ? nil : myProfile?.avatarUrl
                if let d = avatarData {
                    avatarUrl = try await MoimRepository.uploadProfileAvatar(data: d, ext: avatarExt ?? "jpg")
                }
                let trimmed = intro.trimmingCharacters(in: .whitespaces)
                let mt = memberType.trimmingCharacters(in: .whitespaces)
                let de = (deviceEmail ?? "").trimmingCharacters(in: .whitespaces)
                try await MoimRepository.updateMyProfile(
                    intro: trimmed.isEmpty ? nil : trimmed,
                    memberType: mt.isEmpty ? nil : mt,
                    avatarUrl: avatarUrl,
                    color: color,
                    deviceType: (deviceType?.isEmpty == false) ? deviceType : nil,
                    deviceEmail: de.isEmpty ? nil : de
                )
                if let list = try? await MoimRepository.allProfiles() {
                    profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                    if let uid = MoimRepository.currentUserId() { myProfile = profilesById[uid] }
                }
                notice = "내 정보가 저장되었습니다."
                onDone()
            } catch { reportError("내 정보 저장", error) }
        }
    }

    /// 비밀번호 변경 (전체관리자 계정은 변경 불가 — 클라이언트 1차 방어 + DB 트리거 최종 강제)
    func changeMyPassword(_ newPassword: String, onResult: @escaping (Bool, String) -> Void) {
        if (myProfile?.role == "superadmin") {
            onResult(false, "전체관리자 계정의 비밀번호는 변경할 수 없습니다.")
            return
        }
        Task {
            do {
                try await MoimRepository.changePassword(newPassword)
                onResult(true, "비밀번호가 변경되었습니다.")
            } catch {
                guard !isBenignCancellation(error) else { return }
                onResult(false, "변경 실패: \(error.localizedDescription)")
            }
        }
    }

    /// 1:1 DM 열기: 상대 user id → 방 id → 방 목록 갱신 후 해당 방 열기
    func startDirect(otherId: String) {
        Task {
            do {
                let rid = try await MoimRepository.openDirect(otherId: otherId)
                rooms = try await MoimRepository.rooms()
                if let ids = try? await MoimRepository.myRoomIds() { myRoomIds = Set(ids) }
                if let room = rooms.first(where: { $0.id == rid }) {
                    pendingOpenRoom = room
                }
            } catch { reportError("대화 열기", error) }
        }
    }

    /// 방 닫기·전환 등으로 Task 가 취소된 경우 — 사용자에게 오류로 보이지 않음
    private func isBenignCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }

    private func reportError(_ prefix: String, _ error: Error, friendly: ((Error) -> String)? = nil) {
        guard !isBenignCancellation(error) else { return }
        self.error = "\(prefix): \(friendly?(error) ?? error.localizedDescription)"
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
            } catch { reportError("방 이름 변경", error) }
        }
    }

    /// 방 정보 변경: 이름·방표식 색상·사진
    func updateRoomAppearance(_ room: Room, name: String, color: String?, iconData: Data?, iconName: String?, clearIcon: Bool, onDone: @escaping () -> Void = {}) {
        let trimmed = name.trimmingCharacters(in: .whitespaces).isEmpty ? room.name : name.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                try await MoimRepository.updateRoomAppearance(roomId: room.id, name: trimmed, color: color, iconData: iconData, iconName: iconName, clearIcon: clearIcon)
                rooms = try await MoimRepository.rooms()
                onDone()
            } catch { reportError("방 정보 변경", error) }
        }
    }

    func setRole(_ userId: String, to role: String) {
        Task {
            do {
                try await MoimRepository.updateRole(userId: userId, role: role)
                let list = try await MoimRepository.allProfiles()
                profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                if userId == MoimRepository.currentUserId() { myProfile = profilesById[userId] }
            } catch { reportError("역할 변경", error) }
        }
    }

    func setApproved(_ userId: String, _ approved: Bool) {
        Task {
            do {
                try await MoimRepository.setApproved(userId: userId, approved: approved)
                let list = try await MoimRepository.allProfiles()
                profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
                if userId == MoimRepository.currentUserId() { myProfile = profilesById[userId] }
            } catch { reportError("승인 변경", error) }
        }
    }

    /// 가입 승인 (관리자·전체관리자 — RPC)
    func approveUser(_ userId: String) {
        Task {
            do {
                try await MoimRepository.approveUser(userId: userId)
                let list = try await MoimRepository.allProfiles()
                profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            } catch { reportError("가입 승인", error) }
        }
    }

    /// 회원 계정 비활성화 (전체관리자 — RPC). 글·자료는 보존
    func adminDeactivate(_ userId: String) {
        Task {
            do {
                try await MoimRepository.adminWithdraw(userId: userId)
                let list = try await MoimRepository.allProfiles()
                profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            } catch { reportError("계정 비활성화", error) }
        }
    }

    /// 비활성 계정 복구(재활성화) (전체관리자 — RPC)
    func reactivate(_ userId: String) {
        Task {
            do {
                try await MoimRepository.reactivate(userId: userId)
                let list = try await MoimRepository.allProfiles()
                profilesById = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            } catch { reportError("계정 복구", error) }
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
            } catch { reportError("이름 변경", error) }
        }
    }

    var otherProfiles: [Profile] {
        // 본인 제외 + 승인된 회원만 (대기 중인 가입자는 방에 추가 불가)
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
            } catch { reportError("자료 삭제", error) }
        }
    }

    func canManageFile(_ uploadedBy: String) -> Bool {
        if let r = myProfile?.role, r == "superadmin" || r == "admin" { return true }
        return uploadedBy == MoimRepository.currentUserId()
    }

    func name(of userId: String) -> String { profilesById[userId]?.name ?? "?" }

    // ── 1:1 DM 표시 헬퍼 (dm_key 'a_b' 에서 상대방 계산) ──

    /// DM 방의 상대 user id
    func dmOtherId(_ room: Room) -> String? {
        guard room.category == "direct", let key = room.dmKey else { return nil }
        let ids = key.split(separator: "_").map(String.init)
        guard ids.count == 2, let me = MoimRepository.currentUserId() else { return nil }
        return ids[0] == me ? ids[1] : ids[0]
    }
    /// DM 방의 상대 프로필
    func dmOther(_ room: Room) -> Profile? {
        guard let id = dmOtherId(room) else { return nil }
        return profilesById[id]
    }
    /// 방 표시 이름 — DM 이면 상대 이름, 그 외엔 방 이름
    func roomDisplayName(_ room: Room) -> String {
        if room.category == "direct" { return dmOther(room)?.name ?? "(알 수 없음)" }
        return room.name
    }

    func isMine(_ m: Message) -> Bool { m.senderId == MoimRepository.currentUserId() }

    func canEditEvent(_ e: CalendarEvent) -> Bool {
        if let r = myProfile?.role, r == "superadmin" || r == "admin" { return true }
        return e.ownerId == MoimRepository.currentUserId()
    }
}
