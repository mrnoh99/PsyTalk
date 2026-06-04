package com.example.moimtalk.data

import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch

/**
 * Supabase Realtime — 방 목록·채팅·일정·자료·병실 현황을 수 초 이내로 동기화.
 * Android MoimViewModel 과 연동.
 */
object MoimRealtimeSync {

    private const val DEBOUNCE_MS = 400L

    private var roomsChannel: RealtimeChannel? = null
    private var roomChannel: RealtimeChannel? = null
    private val globalJobs = mutableListOf<Job>()
    private val roomJobs = mutableListOf<Job>()
    private var roomsDebounce: Job? = null
    private var roomDebounce: Job? = null

    fun start(
        scope: CoroutineScope,
        onRoomsChanged: suspend () -> Unit,
        onWardChanged: suspend () -> Unit,
        onActiveRoomChanged: suspend (String) -> Unit,
    ) {
        stop(scope)
        val ch = supabase.channel("moim-global")
        for (table in listOf("rooms", "room_members")) {
            ch.postgresChangeFlow<PostgresAction>(schema = "public") {
                this.table = table
            }.onEach {
                scheduleRooms(scope, onRoomsChanged)
            }.launchIn(scope).also { globalJobs.add(it) }
        }
        ch.postgresChangeFlow<PostgresAction>(schema = "public") {
            table = "ward_status"
        }.onEach {
            scope.launch { onWardChanged() }
        }.launchIn(scope).also { globalJobs.add(it) }

        scope.launch { ch.subscribe() }
        roomsChannel = ch
        roomListener = onActiveRoomChanged
    }

    private var roomListener: (suspend (String) -> Unit)? = null

    fun setActiveRoom(scope: CoroutineScope, roomId: String?) {
        stopRoomChannel(scope)
        if (roomId == null) return
        val listener = roomListener ?: return
        val ch = supabase.channel("moim-room-$roomId")
        for (table in listOf("messages", "calendar_events", "room_files")) {
            ch.postgresChangeFlow<PostgresAction>(schema = "public") {
                this.table = table
                filter = "room_id=eq.$roomId"
            }.onEach {
                scheduleRoom(scope, roomId, listener)
            }.launchIn(scope).also { roomJobs.add(it) }
        }
        scope.launch { ch.subscribe() }
        roomChannel = ch
    }

    fun stop(scope: CoroutineScope) {
        globalJobs.forEach { it.cancel() }
        globalJobs.clear()
        roomsDebounce?.cancel()
        roomsDebounce = null
        stopRoomChannel(scope)
        val global = roomsChannel
        roomsChannel = null
        roomListener = null
        if (global != null) {
            scope.launch { runCatching { global.unsubscribe() } }
        }
    }

    private fun stopRoomChannel(scope: CoroutineScope) {
        roomJobs.forEach { it.cancel() }
        roomJobs.clear()
        roomDebounce?.cancel()
        roomDebounce = null
        val room = roomChannel
        roomChannel = null
        if (room != null) {
            scope.launch { runCatching { room.unsubscribe() } }
        }
    }

    private fun scheduleRooms(scope: CoroutineScope, block: suspend () -> Unit) {
        roomsDebounce?.cancel()
        roomsDebounce = scope.launch {
            delay(DEBOUNCE_MS)
            block()
        }
    }

    private fun scheduleRoom(
        scope: CoroutineScope,
        roomId: String,
        block: suspend (String) -> Unit,
    ) {
        roomDebounce?.cancel()
        roomDebounce = scope.launch {
            delay(DEBOUNCE_MS)
            block(roomId)
        }
    }
}
