import Foundation
import Supabase

/// Supabase Realtime — 방 목록·채팅·일정·자료·병실 현황을 수 초 이내로 동기화 (Android MoimRealtimeSync.kt 와 동일)
@MainActor
final class MoimRealtimeSync {
    static let shared = MoimRealtimeSync()

    private let debounceNs: UInt64 = 250_000_000
    private let reconnectNs: UInt64 = 2_000_000_000
    private var globalChannel: RealtimeChannelV2?
    private var roomChannel: RealtimeChannelV2?
    private var globalTasks: [Task<Void, Never>] = []
    private var roomTasks: [Task<Void, Never>] = []
    private var roomListDebounce: Task<Void, Never>?
    private var profilesDebounce: Task<Void, Never>?
    private var roomDebounce: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var onRooms: (() async -> Void)?
    private var onRoomMembers: (() async -> Void)?
    private var onProfiles: (() async -> Void)?
    private var onWard: (() async -> Void)?
    private var onRoomData: ((String) async -> Void)?

    /// 구독 시작(이미 연결 중이면 재구독 — 백그라운드 복귀·다른 클라이언트 동기화)
    func start(
        onRooms: @escaping () async -> Void,
        onRoomMembers: @escaping () async -> Void,
        onProfiles: @escaping () async -> Void,
        onWard: @escaping () async -> Void,
        onRoomData: @escaping (String) async -> Void
    ) async {
        await stop()
        self.onRooms = onRooms
        self.onRoomMembers = onRoomMembers
        self.onProfiles = onProfiles
        self.onWard = onWard
        self.onRoomData = onRoomData

        let channel = supabase.channel("moim-global")
        let roomsStream = channel.postgresChange(AnyAction.self, schema: "public", table: "rooms")
        let membersStream = channel.postgresChange(AnyAction.self, schema: "public", table: "room_members")
        let profilesStream = channel.postgresChange(AnyAction.self, schema: "public", table: "profiles")
        let wardStream = channel.postgresChange(AnyAction.self, schema: "public", table: "ward_status")
        try? await channel.subscribeWithError()
        globalChannel = channel

        globalTasks.append(listen(roomsStream) { await self.scheduleRoomListRefresh() })
        globalTasks.append(listen(membersStream) { await self.scheduleRoomListRefresh() })
        globalTasks.append(listen(profilesStream) { await self.scheduleProfiles(onProfiles) })
        globalTasks.append(listen(wardStream) { await onWard() })
        watchChannelStatus(channel)

        // 구독 직후 1회 동기화
        await scheduleRoomListRefresh(immediate: true)
    }

    func setActiveRoom(_ roomId: String?) async {
        await stopRoomChannel()
        guard let roomId, let onRoomData else { return }

        let channel = supabase.channel("moim-room-\(roomId)")
        let filter = "room_id=eq.\(roomId)"
        let msgStream = channel.postgresChange(AnyAction.self, schema: "public", table: "messages", filter: filter)
        let calStream = channel.postgresChange(AnyAction.self, schema: "public", table: "calendar_events", filter: filter)
        let fileStream = channel.postgresChange(AnyAction.self, schema: "public", table: "room_files", filter: filter)
        try? await channel.subscribeWithError()
        roomChannel = channel
        for stream in [msgStream, calStream, fileStream] {
            roomTasks.append(listen(stream) { await self.scheduleRoom(roomId, onRoomData) })
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
        onRooms = nil
        onRoomMembers = nil
        onProfiles = nil
        onWard = nil
        onRoomData = nil
        globalTasks.forEach { $0.cancel() }
        globalTasks.removeAll()
        roomListDebounce?.cancel()
        roomListDebounce = nil
        profilesDebounce?.cancel()
        profilesDebounce = nil
        statusTask?.cancel()
        statusTask = nil
        await stopRoomChannel()
        if let ch = globalChannel {
            await supabase.removeChannel(ch)
        }
        globalChannel = nil
    }

    private func stopRoomChannel() async {
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
        guard let onRooms, let onRoomMembers, let onProfiles, let onWard, let onRoomData else { return }
        await start(
            onRooms: onRooms,
            onRoomMembers: onRoomMembers,
            onProfiles: onProfiles,
            onWard: onWard,
            onRoomData: onRoomData
        )
    }
}
