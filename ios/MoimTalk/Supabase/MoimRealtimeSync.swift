import Foundation
import Supabase

/// Supabase Realtime — 방 목록·채팅·일정·자료·병실 현황을 수 초 이내로 동기화 (Android MoimRealtimeSync.kt 와 동일)
@MainActor
final class MoimRealtimeSync {
    static let shared = MoimRealtimeSync()

    private let debounceNs: UInt64 = 400_000_000
    private var started = false
    private var globalChannel: RealtimeChannel?
    private var roomChannel: RealtimeChannel?
    private var globalTasks: [Task<Void, Never>] = []
    private var roomTasks: [Task<Void, Never>] = []
    private var roomsDebounce: Task<Void, Never>?
    private var roomDebounce: Task<Void, Never>?
    private var onRoomData: ((String) async -> Void)?

    func start(
        onRooms: @escaping () async -> Void,
        onWard: @escaping () async -> Void,
        onRoomData: @escaping (String) async -> Void
    ) async {
        guard !started else { return }
        started = true
        self.onRoomData = onRoomData

        let channel = supabase.channel("moim-global")
        let roomsStream = channel.postgresChange(AnyAction.self, schema: "public", table: "rooms")
        let membersStream = channel.postgresChange(AnyAction.self, schema: "public", table: "room_members")
        let wardStream = channel.postgresChange(AnyAction.self, schema: "public", table: "ward_status")
        await channel.subscribe()
        globalChannel = channel

        globalTasks.append(Task {
            for await _ in roomsStream { await self.scheduleRooms(onRooms) }
        })
        globalTasks.append(Task {
            for await _ in membersStream { await self.scheduleRooms(onRooms) }
        })
        globalTasks.append(Task {
            for await _ in wardStream { await onWard() }
        })
    }

    func setActiveRoom(_ roomId: String?) async {
        await stopRoomChannel()
        guard let roomId, let onRoomData else { return }

        let channel = supabase.channel("moim-room-\(roomId)")
        let filter = "room_id=eq.\(roomId)"
        let msgStream = channel.postgresChange(AnyAction.self, schema: "public", table: "messages", filter: filter)
        let calStream = channel.postgresChange(AnyAction.self, schema: "public", table: "calendar_events", filter: filter)
        let fileStream = channel.postgresChange(AnyAction.self, schema: "public", table: "room_files", filter: filter)
        await channel.subscribe()
        roomChannel = channel

        for stream in [msgStream, calStream, fileStream] {
            roomTasks.append(Task {
                for await _ in stream {
                    await self.scheduleRoom(roomId, onRoomData)
                }
            })
        }
    }

    func stop() async {
        started = false
        onRoomData = nil
        globalTasks.forEach { $0.cancel() }
        globalTasks.removeAll()
        roomsDebounce?.cancel()
        roomsDebounce = nil
        await stopRoomChannel()
        if let ch = globalChannel {
            await ch.unsubscribe()
        }
        globalChannel = nil
    }

    private func stopRoomChannel() async {
        roomTasks.forEach { $0.cancel() }
        roomTasks.removeAll()
        roomDebounce?.cancel()
        roomDebounce = nil
        if let ch = roomChannel {
            await ch.unsubscribe()
        }
        roomChannel = nil
    }

    private func scheduleRooms(_ block: @escaping () async -> Void) async {
        roomsDebounce?.cancel()
        roomsDebounce = Task {
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
}
