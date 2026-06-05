@file:OptIn(io.github.jan.supabase.annotations.SupabaseExperimental::class)

package com.example.moimtalk.data

import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.selectAsFlow
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Supabase Realtime — 방 목록·채팅·일정·자료·병실 현황 동기화.
 * 방 목록: postgrest selectAsFlow(rooms) + room_members postgres 변경 시 재조회.
 */
object MoimRealtimeSync {

    private const val DEBOUNCE_MS = 250L

    private var roomsFlowJob: Job? = null
    private var globalChannel: RealtimeChannel? = null
    private var roomChannel: RealtimeChannel? = null
    private var globalSetupJob: Job? = null
    private var roomSetupJob: Job? = null
    private val globalJobs = mutableListOf<Job>()
    private val roomJobs = mutableListOf<Job>()
    private var roomListDebounce: Job? = null
    private var profilesDebounce: Job? = null
    private var roomDebounce: Job? = null
    private var roomListener: (suspend (String) -> Unit)? = null
    private var activeRoomId: String? = null
    private var roomStatusJob: Job? = null
    private var stopping = false

    private var onRoomsList: ((List<Room>) -> Unit)? = null
    private var onRoomsRefetch: (suspend () -> Unit)? = null
    private var onRoomMembersChanged: (suspend () -> Unit)? = null
    private var onProfilesChanged: (suspend () -> Unit)? = null
    private var onWardChanged: (suspend () -> Unit)? = null

    fun start(
        scope: CoroutineScope,
        onRoomsList: (List<Room>) -> Unit,
        onRoomsRefetch: suspend () -> Unit,
        onRoomMembersChanged: suspend () -> Unit,
        onProfilesChanged: suspend () -> Unit,
        onWardChanged: suspend () -> Unit,
        onActiveRoomChanged: suspend (String) -> Unit,
    ) {
        this.onRoomsList = onRoomsList
        this.onRoomsRefetch = onRoomsRefetch
        this.onRoomMembersChanged = onRoomMembersChanged
        this.onProfilesChanged = onProfilesChanged
        this.onWardChanged = onWardChanged
        this.roomListener = onActiveRoomChanged
        stopping = false

        startRoomsFlow(scope)
        startGlobalChannel(scope)
        activeRoomId?.let { setActiveRoom(scope, it) }
    }

    /** rooms 테이블 Realtime Flow — 웹 postgres_changes(rooms) 와 동일 */
    private fun startRoomsFlow(scope: CoroutineScope) {
        roomsFlowJob?.cancel()
        roomsFlowJob = scope.launch {
            runCatching { supabase.realtime.connect() }
            supabase.from("rooms")
                .selectAsFlow(Room::id)
                .catch { scheduleRoomListRefetch(scope) }
                .collect { list ->
                    onRoomsList?.invoke(list.sortedBy { it.sortOrder })
                }
        }
    }

    /** room_members·profiles·ward_status — 기존 글로벌 채널 */
    private fun startGlobalChannel(scope: CoroutineScope) {
        globalSetupJob?.cancel()
        globalSetupJob = scope.launch {
            stopGlobalChannelInternal()
            runCatching { supabase.realtime.connect() }
            val ch = supabase.channel("moim-global")
            val membersFlow = ch.postgresChangeFlow<PostgresAction>(schema = "public") {
                table = "room_members"
            }
            val profilesFlow = ch.postgresChangeFlow<PostgresAction>(schema = "public") {
                table = "profiles"
            }
            val wardFlow = ch.postgresChangeFlow<PostgresAction>(schema = "public") {
                table = "ward_status"
            }
            ch.subscribe(blockUntilSubscribed = true)
            globalChannel = ch
            globalJobs.clear()
            globalJobs.add(
                membersFlow.onEach { scheduleRoomListRefetch(scope) }.launchIn(this),
            )
            globalJobs.add(
                profilesFlow.onEach { scheduleProfiles(scope) }.launchIn(this),
            )
            globalJobs.add(
                wardFlow.onEach { onWardChanged?.invoke() }.launchIn(this),
            )
            scheduleRoomListRefetch(scope, immediate = true)
        }
    }

    fun setActiveRoom(scope: CoroutineScope, roomId: String?) {
        activeRoomId = roomId
        roomSetupJob?.cancel()
        roomSetupJob = scope.launch {
            stopRoomInternal()
            if (roomId == null) return@launch
            val listener = roomListener ?: return@launch
            runCatching { supabase.realtime.connect() }
            val ch = supabase.channel("moim-room-$roomId")
            val flows = listOf("messages", "calendar_events", "room_files").map { table ->
                ch.postgresChangeFlow<PostgresAction>(schema = "public") {
                    this.table = table
                    filter("room_id", FilterOperator.EQ, roomId)
                }
            }
            ch.subscribe(blockUntilSubscribed = true)
            roomChannel = ch
            roomJobs.clear()
            flows.forEach { flow ->
                roomJobs.add(
                    flow.onEach { scheduleRoom(scope, roomId, listener) }.launchIn(this),
                )
            }
            watchRoomChannelStatus(scope, ch, roomId)
        }
    }

    /** 채널 끊김 시 현재 방 Realtime 재구독 (iOS watchChannelStatus 와 동일) */
    private fun watchRoomChannelStatus(
        scope: CoroutineScope,
        ch: RealtimeChannel,
        roomId: String,
    ) {
        roomStatusJob?.cancel()
        roomStatusJob = scope.launch {
            ch.status.collect { status ->
                if (status != RealtimeChannel.Status.UNSUBSCRIBED || stopping) return@collect
                delay(2_000)
                if (stopping || activeRoomId != roomId) return@collect
                setActiveRoom(scope, roomId)
            }
        }
    }

    fun stop(scope: CoroutineScope) {
        stopping = true
        roomsFlowJob?.cancel()
        roomsFlowJob = null
        globalSetupJob?.cancel()
        roomSetupJob?.cancel()
        globalSetupJob = null
        roomSetupJob = null
        scope.launch {
            stopRoomInternal()
            stopGlobalChannelInternal()
            activeRoomId = null
            roomListener = null
            onRoomsList = null
            onRoomsRefetch = null
            onRoomMembersChanged = null
            onProfilesChanged = null
            onWardChanged = null
            stopping = false
        }
    }

    private suspend fun stopGlobalChannelInternal() {
        globalJobs.forEach { it.cancel() }
        globalJobs.clear()
        roomListDebounce?.cancel()
        roomListDebounce = null
        profilesDebounce?.cancel()
        profilesDebounce = null
        val ch = globalChannel
        globalChannel = null
        if (ch != null) {
            runCatching { ch.unsubscribe() }
            awaitUnsubscribed(ch)
        }
    }

    private suspend fun stopRoomInternal() {
        roomStatusJob?.cancel()
        roomStatusJob = null
        roomJobs.forEach { it.cancel() }
        roomJobs.clear()
        roomDebounce?.cancel()
        roomDebounce = null
        val ch = roomChannel
        roomChannel = null
        if (ch != null) {
            runCatching { ch.unsubscribe() }
            awaitUnsubscribed(ch)
        }
    }

    private suspend fun awaitUnsubscribed(ch: RealtimeChannel) {
        if (ch.status.value == RealtimeChannel.Status.UNSUBSCRIBED) return
        runCatching {
            ch.status.first { it == RealtimeChannel.Status.UNSUBSCRIBED }
        }
    }

    /** room_members 변경·초대 시 RLS 가시성 반영 — API 재조회 */
    private fun scheduleRoomListRefetch(scope: CoroutineScope, immediate: Boolean = false) {
        if (stopping) return
        roomListDebounce?.cancel()
        roomListDebounce = scope.launch {
            if (!immediate) delay(DEBOUNCE_MS)
            onRoomsRefetch?.invoke()
            onRoomMembersChanged?.invoke()
        }
    }

    private fun scheduleProfiles(scope: CoroutineScope) {
        profilesDebounce?.cancel()
        profilesDebounce = scope.launch {
            delay(DEBOUNCE_MS)
            onProfilesChanged?.invoke()
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
