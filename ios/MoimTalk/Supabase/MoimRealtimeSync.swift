import Foundation
import Supabase

/// Supabase Realtime — 방 목록·채팅·일정·자료·병실 현황을 수 초 이내로 동기화 (Android MoimRealtimeSync.kt 와 동일)
@MainActor
final class MoimRealtimeSync {
    static let shared = MoimRealtimeSync()

    private let debounceNs: UInt64 = 100_000_000
    private let reconnectNs: UInt64 = 2_000_000_000
    private var globalChannel: RealtimeChannelV2?
    private var roomChannel: RealtimeChannelV2?
    private var globalTasks: [Task<Void, Never>] = []
    private var roomTasks: [Task<Void, Never>] = []
    private var roomListDebounce: Task<Void, Never>?
    private var profilesDebounce: Task<Void, Never>?
    private var roomDebounce: Task<Void, Never>?
    private var messagesDebounce: Task<Void, Never>?
    private var roomStatusTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var activeRoomId: String?
    private var onRooms: (() async -> Void)?
    private var onRoomMembers: (() async -> Void)?
    private var onProfiles: (() async -> Void)?
    private var onWard: (() async -> Void)?
    private var onRoomData: ((String) async -> Void)?
    /// 전역 messages 변경 — 닫혀 있는 방의 안읽음 배지·미리보기 갱신(web·Android 와 통일)
    private var onMessage: (() async -> Void)?
    /// bindRealtime() 중복 호출 시 subscribe 이후 postgresChange 가 등록되는 레이스 방지
    private var bindGeneration: UInt64 = 0
    private var roomBindGeneration: UInt64 = 0

    /// 구독 시작(이미 연결 중이면 재구독 — 백그라운드 복귀·다른 클라이언트 동기화)
    func start(
        onRooms: @escaping () async -> Void,
        onRoomMembers: @escaping () async -> Void,
        onProfiles: @escaping () async -> Void,
        onWard: @escaping () async -> Void,
        onMessage: @escaping () async -> Void,
        onRoomData: @escaping (String) async -> Void
    ) async {
        bindGeneration &+= 1
        let gen = bindGeneration

        await stop()
        guard gen == bindGeneration else { return }

        self.onRooms = onRooms
        self.onRoomMembers = onRoomMembers
        self.onProfiles = onProfiles
        self.onWard = onWard
        self.onMessage = onMessage
        self.onRoomData = onRoomData

        // postgresChange 는 subscribe() 전에 모두 등록해야 함 (supabase-swift 2.46+)
        let channel = await freshChannel(named: "moim-global")
        let roomsStream = channel.postgresChange(AnyAction.self, schema: "public", table: "rooms")
        let membersStream = channel.postgresChange(AnyAction.self, schema: "public", table: "room_members")
        let profilesStream = channel.postgresChange(AnyAction.self, schema: "public", table: "profiles")
        let wardStream = channel.postgresChange(AnyAction.self, schema: "public", table: "ward_status")
        let wardDutyStream = channel.postgresChange(AnyAction.self, schema: "public", table: "ward_duty")
        let messagesStream = channel.postgresChange(AnyAction.self, schema: "public", table: "messages")

        globalTasks.append(listen(roomsStream) { await self.scheduleRoomListRefresh() })
        globalTasks.append(listen(membersStream) { await self.scheduleRoomListRefresh() })
        globalTasks.append(listen(profilesStream) { await self.scheduleProfiles(onProfiles) })
        globalTasks.append(listen(wardStream) { await onWard() })
        globalTasks.append(listen(wardDutyStream) { await onWard() })
        globalTasks.append(listen(messagesStream) { await self.scheduleMessages() })

        guard gen == bindGeneration else {
            globalTasks.forEach { $0.cancel() }
            globalTasks.removeAll()
            await supabase.removeChannel(channel)
            return
        }

        try? await channel.subscribeWithError()
        guard gen == bindGeneration else {
            globalTasks.forEach { $0.cancel() }
            globalTasks.removeAll()
            await supabase.removeChannel(channel)
            return
        }

        globalChannel = channel
        watchChannelStatus(channel)

        // 구독 직후 1회 동기화
        await scheduleRoomListRefresh(immediate: true)

        // bindRealtime() 재호출 시 열린 방 Realtime 재구독 (Android ensureRealtime 과 동일)
        if let id = activeRoomId {
            await setActiveRoom(id)
        }
    }

    func setActiveRoom(_ roomId: String?) async {
        activeRoomId = roomId
        await stopRoomChannel()
        guard let roomId, let onRoomData else { return }

        roomBindGeneration &+= 1
        let gen = roomBindGeneration

        let channel = await freshChannel(named: "moim-room-\(roomId)")
        let roomFilter: RealtimePostgresFilter = .eq("room_id", value: roomId)
        let msgStream = channel.postgresChange(AnyAction.self, schema: "public", table: "messages", filter: roomFilter)
        let calStream = channel.postgresChange(AnyAction.self, schema: "public", table: "calendar_events", filter: roomFilter)
        let fileStream = channel.postgresChange(AnyAction.self, schema: "public", table: "room_files", filter: roomFilter)

        roomTasks.append(listen(msgStream) { await onRoomData(roomId) })
        roomTasks.append(listen(calStream) { await self.scheduleRoom(roomId, onRoomData) })
        roomTasks.append(listen(fileStream) { await self.scheduleRoom(roomId, onRoomData) })

        guard gen == roomBindGeneration, activeRoomId == roomId else {
            roomTasks.forEach { $0.cancel() }
            roomTasks.removeAll()
            await supabase.removeChannel(channel)
            return
        }

        try? await channel.subscribeWithError()
        guard gen == roomBindGeneration, activeRoomId == roomId else {
            roomTasks.forEach { $0.cancel() }
            roomTasks.removeAll()
            await supabase.removeChannel(channel)
            return
        }

        roomChannel = channel
        watchRoomChannelStatus(channel, roomId: roomId)
    }

    /// 캐시된 채널이 이미 subscribe 된 상태면 제거 후 새 인스턴스 반환
    private func freshChannel(named name: String) async -> RealtimeChannelV2 {
        let existing = supabase.channel(name)
        if existing.status == .subscribed || existing.status == .subscribing {
            await supabase.removeChannel(existing)
        }
        return supabase.channel(name)
    }

    private func watchRoomChannelStatus(_ channel: RealtimeChannelV2, roomId: String) {
        roomStatusTask?.cancel()
        roomStatusTask = Task {
            for await status in channel.statusChange {
                if status == .subscribed { continue }
                try? await Task.sleep(nanoseconds: reconnectNs)
                guard !Task.isCancelled, activeRoomId == roomId else { return }
                await setActiveRoom(roomId)
            }
        }
    }

    private func listen<S: AsyncSequence>(
        _ stream: S,
        _ handler: @escaping () async -> Void
    ) -> Task<Void, Never> where S.Element: Sendable {
        Task {
            do {
                for try await _ in stream { await handler() }
            } catch {
                // 채널 해제·구독 종료 시 스트림 종료 — 무시
            }
        }
    }

    func stop() async {
        bindGeneration &+= 1
        onRooms = nil
        onRoomMembers = nil
        onProfiles = nil
        onWard = nil
        onMessage = nil
        onRoomData = nil
        globalTasks.forEach { $0.cancel() }
        globalTasks.removeAll()
        roomListDebounce?.cancel()
        roomListDebounce = nil
        profilesDebounce?.cancel()
        profilesDebounce = nil
        messagesDebounce?.cancel()
        messagesDebounce = nil
        statusTask?.cancel()
        statusTask = nil
        await stopRoomChannel()
        if let ch = globalChannel {
            await supabase.removeChannel(ch)
        }
        globalChannel = nil
    }

    private func stopRoomChannel() async {
        roomBindGeneration &+= 1
        roomStatusTask?.cancel()
        roomStatusTask = nil
        roomTasks.forEach { $0.cancel() }
        roomTasks.removeAll()
        roomDebounce?.cancel()
        roomDebounce = nil
        if let ch = roomChannel {
            await supabase.removeChannel(ch)
        }
        roomChannel = nil
    }

    /// rooms·room_members 변경 — 웹 debouncedLoadRooms 와 동일
    private func scheduleRoomListRefresh(immediate: Bool = false) async {
        roomListDebounce?.cancel()
        roomListDebounce = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: debounceNs)
            }
            guard !Task.isCancelled else { return }
            await onRooms?()
            await onRoomMembers?()
        }
    }

    private func scheduleProfiles(_ block: @escaping () async -> Void) async {
        profilesDebounce?.cancel()
        profilesDebounce = Task {
            try? await Task.sleep(nanoseconds: debounceNs)
            guard !Task.isCancelled else { return }
            await block()
        }
    }

    /// 전역 messages 변경 — 안읽음·미리보기만 가볍게 갱신(web debouncedLoadUnread 와 동일)
    private func scheduleMessages() async {
        messagesDebounce?.cancel()
        messagesDebounce = Task {
            try? await Task.sleep(nanoseconds: debounceNs)
            guard !Task.isCancelled else { return }
            await onMessage?()
        }
    }

    private func scheduleRoom(_ roomId: String, _ block: @escaping (String) async -> Void) async {
        roomDebounce?.cancel()
        roomDebounce = Task {
            try? await Task.sleep(nanoseconds: debounceNs)
            guard !Task.isCancelled else { return }
            await block(roomId)
        }
    }

    private func watchChannelStatus(_ channel: RealtimeChannelV2) {
        statusTask?.cancel()
        statusTask = Task {
            for await status in channel.statusChange {
                if status == .subscribed { continue }
                try? await Task.sleep(nanoseconds: reconnectNs)
                guard !Task.isCancelled else { return }
                await reconnectIfBound()
            }
        }
    }

    private func reconnectIfBound() async {
        guard let onRooms, let onRoomMembers, let onProfiles, let onWard, let onMessage, let onRoomData else { return }
        await start(
            onRooms: onRooms,
            onRoomMembers: onRoomMembers,
            onProfiles: onProfiles,
            onWard: onWard,
            onMessage: onMessage,
            onRoomData: onRoomData
        )
    }
}
