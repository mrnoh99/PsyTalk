package com.example.moimtalk

import android.content.pm.ActivityInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import com.example.moimtalk.data.CalendarEvent
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRealtimeSync
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Room
import com.example.moimtalk.data.RoomFile
import com.example.moimtalk.data.friendlySupabaseError
import com.example.moimtalk.ui.CreateRoomScreen
import com.example.moimtalk.ui.LoginScreen
import com.example.moimtalk.ui.RoomListScreen
import com.example.moimtalk.ui.RoomScreen
import com.example.moimtalk.ui.ApprovalScreen
import com.example.moimtalk.ui.isAdminRole
import com.example.moimtalk.ui.PendingApprovalScreen
import com.example.moimtalk.ui.WardStatusScreen
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

// =====================================================================
//  ViewModel
// =====================================================================
class MoimViewModel : ViewModel() {

    var loggedIn by mutableStateOf(MoimRepository.currentUserId() != null)
    var myProfile by mutableStateOf<Profile?>(null)
    var rooms by mutableStateOf<List<Room>>(emptyList())
    var messages by mutableStateOf<List<Message>>(emptyList())
    var events by mutableStateOf<List<CalendarEvent>>(emptyList())
    var files by mutableStateOf<List<RoomFile>>(emptyList())
    var profilesById by mutableStateOf<Map<String, Profile>>(emptyMap())
    // 채팅 첨부 path → 서명 URL 캐시 (방 구성원만 발급됨)
    var attachmentUrls by mutableStateOf<Map<String, String>>(emptyMap())
    var error by mutableStateOf<String?>(null)
    var notice by mutableStateOf<String?>(null)
    var loading by mutableStateOf(false)
    // 모임방 설정(멤버 관리)에서 보여줄 현재 방 멤버 id 목록
    var roomMemberIds by mutableStateOf<List<String>>(emptyList())
    var roomMembersLoaded by mutableStateOf(false)
    var roomMemberCounts by mutableStateOf<Map<String, Int>>(emptyMap())

    private var activeRoom: String? = null
    private var memberListRoomId: String? = null
    private var roomPollJob: Job? = null
    private var messagePollJob: Job? = null

    /** Realtime + 방 목록 Flow 구독 (로그인 후·포그라운드 복귀 시 호출) */
    fun ensureRealtime() {
        if (!loggedIn) return
        MoimRealtimeSync.start(
            scope = viewModelScope,
            onRoomsList = { list -> rooms = list },
            onRoomsRefetch = { refetchRoomsQuiet() },
            onRoomMembersChanged = { onRoomMembersChangedOnly() },
            onProfilesChanged = { reloadProfiles() },
            onWardChanged = { loadWardStatus() },
            onActiveRoomChanged = { rid -> refreshActiveRoom(rid) },
        )
    }

    /** room_members 변경 등 RLS 재조회용 (오류 팝업 없음) */
    private suspend fun refetchRoomsQuiet() {
        try {
            rooms = MoimRepository.rooms()
            loadRoomMemberCounts()
        } catch (_: Exception) {
        }
    }

    /** Realtime 보조 — 12초마다 방 목록 재조회 (웹·다른 기기 변경 누락 방지) */
    fun startRoomListPolling() {
        roomPollJob?.cancel()
        roomPollJob = viewModelScope.launch {
            while (isActive && loggedIn) {
                delay(12_000)
                refetchRoomsQuiet()
            }
        }
    }

    fun stopRoomListPolling() {
        roomPollJob?.cancel()
        roomPollJob = null
    }

    /** Realtime 보조 — 열린 방 메시지·일정·자료 3초 폴링 (WS 누락 방지) */
    private fun startMessagePolling() {
        messagePollJob?.cancel()
        messagePollJob = viewModelScope.launch {
            activeRoom?.let { refreshActiveRoom(it) }
            while (isActive) {
                delay(3_000)
                activeRoom?.let { refreshActiveRoom(it) }
            }
        }
    }

    private fun stopMessagePolling() {
        messagePollJob?.cancel()
        messagePollJob = null
    }

    /** 앱이 다시 보일 때(웹 등 다른 클라이언트 변경 반영) */
    fun refreshOnForeground() {
        if (!loggedIn) return
        viewModelScope.launch {
            try {
                MoimRepository.ensureAuthReady()
                if (MoimRepository.currentUserId() == null) return@launch
                refetchRoomsQuiet()
                reloadProfiles()
                activeRoom?.let { refreshActiveRoom(it) }
            } catch (_: Exception) {
                // 사진·파일 선택기 복귀 등 일시적 네트워크/세션 지연 — 조용히 무시
            }
        }
        ensureRealtime()
    }

    /** 가입 신청·승인 상태 등 profiles 변경 시 (관리자 가입 승인 목록 갱신) */
    fun reloadProfiles() {
        viewModelScope.launch {
            try {
                profilesById = MoimRepository.allProfiles().associateBy { it.id }
                MoimRepository.currentUserId()?.let { uid ->
                    profilesById[uid]?.let { myProfile = it }
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun refreshActiveRoom(roomId: String) {
        if (activeRoom != roomId) return
        viewModelScope.launch {
            try {
                messages = MoimRepository.messages(roomId)
                resolveAttachments()
            } catch (_: Exception) {
            }
            loadRoomData(roomId)
        }
    }

    fun signUp(email: String, pw: String, name: String, memberType: String) {
        viewModelScope.launch {
            loading = true; error = null; notice = null
            try {
                MoimRepository.signUp(email, pw, name, memberType)
                if (MoimRepository.currentUserId() != null) {
                    myProfile = MoimRepository.myProfile()
                    rooms = MoimRepository.rooms()
                    profilesById = runCatching { MoimRepository.allProfiles().associateBy { it.id } }.getOrDefault(emptyMap())
                    loggedIn = true
                    ensureRealtime()
                    startRoomListPolling()
                } else {
                    notice = "가입이 접수되었습니다. 전체관리자 승인 후 로그인하여 이용할 수 있습니다."
                }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "회원가입")
            }
            loading = false
        }
    }

    fun login(email: String, pw: String) {
        viewModelScope.launch {
            loading = true
            error = null
            try {
                MoimRepository.signIn(email, pw)
                try {
                    myProfile = MoimRepository.myProfile()
                } catch (e: Exception) {
                    throw Exception("프로필 조회: ${e.message}", e)
                }
                try {
                    rooms = MoimRepository.rooms()
                } catch (e: Exception) {
                    throw Exception("방 목록 조회: ${e.message}", e)
                }
                loggedIn = true
                ensureRealtime()
                startRoomListPolling()
            } catch (e: Exception) {
                loggedIn = false
                try {
                    MoimRepository.signOut()
                } catch (_: Exception) {
                }
                error = friendlySupabaseError(e, "로그인")
            }
            loading = false
        }
    }

    fun logout() {
        stopRoomListPolling()
        MoimRealtimeSync.stop(viewModelScope)
        viewModelScope.launch {
            try {
                MoimRepository.signOut()
            } catch (_: Exception) {
            }
            loggedIn = false
            rooms = emptyList()
            myProfile = null
        }
    }

    fun loadRooms() {
        viewModelScope.launch {
            try {
                MoimRepository.ensureAuthReady()
                if (MoimRepository.currentUserId() == null) return@launch
                myProfile = MoimRepository.myProfile()
                rooms = MoimRepository.rooms()
                loadRoomMemberCounts()
                try {
                    profilesById = MoimRepository.allProfiles().associateBy { it.id }
                } catch (_: Exception) {
                    // 이름 표시는 선택적 — 실패해도 진행
                }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "데이터 불러오기")
            }
        }
    }

    fun openRoom(room: Room) {
        activeRoom = room.id
        MoimRealtimeSync.setActiveRoom(viewModelScope, room.id)
        startMessagePolling()
        viewModelScope.launch {
            messages = emptyList()
            events = emptyList()
            files = emptyList()
            try {
                messages = MoimRepository.messages(room.id)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "메시지 불러오기")
            }
            loadRoomData(room.id)
        }
    }

    private fun loadRoomData(roomId: String) {
        viewModelScope.launch {
            try {
                events = MoimRepository.events(roomId)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "일정 불러오기")
            }
            try {
                files = MoimRepository.files(roomId)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "자료 불러오기")
            }
        }
    }

    fun closeRoom() {
        stopMessagePolling()
        activeRoom = null
        MoimRealtimeSync.setActiveRoom(viewModelScope, null)
        messages = emptyList()
        events = emptyList()
        files = emptyList()
    }

    // ── 캘린더 ──
    fun createEvent(
        title: String,
        startAt: String,
        place: String?,
        link: String?,
        scope: String?,
        description: String?,
        presenter: String?,
        keywords: List<String>,
        attachments: List<Pair<String, ByteArray>>,
        onDone: () -> Unit,
    ) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.createEvent(
                    rid, title, startAt, place, link, scope, description, presenter, keywords, attachments,
                )
                events = MoimRepository.events(rid)
                files = MoimRepository.files(rid)
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "일정 등록")
            }
        }
    }

    fun updateEvent(
        eventId: String,
        title: String,
        startAt: String,
        place: String?,
        link: String?,
        scope: String?,
        description: String?,
        presenter: String?,
        keywords: List<String>,
        keptUrls: List<String>,
        keptNames: List<String>,
        newAttachments: List<Pair<String, ByteArray>>,
        onDone: () -> Unit,
    ) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.updateEvent(
                    eventId, rid, title, startAt, place, link, scope, description, presenter, keywords,
                    keptUrls, keptNames, newAttachments,
                )
                events = MoimRepository.events(rid)
                files = MoimRepository.files(rid)
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "일정 수정")
            }
        }
    }

    // ── 자료실 ──
    fun uploadFile(
        fileName: String,
        bytes: ByteArray,
        description: String?,
        keywords: List<String>,
        onDone: () -> Unit,
    ) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.uploadRoomFile(rid, fileName, bytes, description, keywords)
                files = MoimRepository.files(rid)
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "자료 업로드")
            }
        }
    }

    fun deleteFile(fileId: String, fileUrl: String?, onDone: () -> Unit) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.deleteRoomFile(fileId, fileUrl)
                files = MoimRepository.files(rid)
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "자료 삭제")
            }
        }
    }

    fun canManageFile(uploadedBy: String): Boolean {
        val role = myProfile?.role
        return role == "superadmin" || role == "admin" || uploadedBy == MoimRepository.currentUserId()
    }

    // ── 잔여 병실 현황 (메모) ──
    var wardStatus by mutableStateOf("")
    var wardStatusUpdatedAt by mutableStateOf<String?>(null)

    fun loadWardStatus() {
        viewModelScope.launch {
            try {
                val w = MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "잔여 병실 현황 불러오기")
            }
        }
    }

    fun saveWardStatus(content: String, onDone: () -> Unit) {
        viewModelScope.launch {
            try {
                MoimRepository.updateWardStatus(content)
                val w = MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "잔여 병실 현황 저장")
            }
        }
    }

    fun approveUser(userId: String, approved: Boolean) {
        viewModelScope.launch {
            try {
                MoimRepository.setApproved(userId, approved)
                profilesById = MoimRepository.allProfiles().associateBy { it.id }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "승인 변경")
            }
        }
    }

    fun createRoom(name: String, memberIds: List<String>, onDone: () -> Unit) {
        val trimmed = name.trim()
        // 같은 이름의 모임방 금지 (보이는 방 기준 즉시 검사 + DB 유니크 인덱스가 최종 강제)
        if (rooms.any { it.category == "custom" && it.name.equals(trimmed, ignoreCase = false) }) {
            error = "같은 이름의 모임방이 이미 있습니다. 다른 이름을 사용하세요."
            return
        }
        viewModelScope.launch {
            try {
                MoimRepository.createRoom(trimmed, memberIds)
                rooms = MoimRepository.rooms()
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "방 만들기")
            }
        }
    }

    /** 모임방 삭제 (생성자/관리자). 성공 시 방 목록 갱신 후 onDone. */
    fun deleteRoom(room: Room, onDone: () -> Unit = {}) {
        viewModelScope.launch {
            try {
                MoimRepository.deleteRoom(room.id)
                rooms = MoimRepository.rooms()
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "모임방 삭제")
            }
        }
    }

    /** room_members 변경 시 멤버 목록·인원만 갱신 (방 목록은 Realtime 에서 loadRooms 로 처리) */
    private fun onRoomMembersChangedOnly() {
        memberListRoomId?.let { loadRoomMembers(it) }
        loadRoomMemberCounts()
    }

    fun loadRoomMemberCounts() {
        viewModelScope.launch {
            roomMemberCounts = try {
                MoimRepository.roomMemberCounts()
            } catch (_: Exception) {
                emptyMap()
            }
        }
    }

    /** 현재 방의 멤버 목록을 불러와 roomMemberIds 에 저장 */
    fun loadRoomMembers(roomId: String) {
        memberListRoomId = roomId
        roomMembersLoaded = false
        viewModelScope.launch {
            try {
                roomMemberIds = MoimRepository.roomMemberIds(roomId)
            } catch (e: Exception) {
                roomMemberIds = emptyList()
                error = friendlySupabaseError(e, "멤버 목록")
            }
            roomMembersLoaded = true
        }
    }

    /** 멤버 내보내기 (생성자/관리자). 성공 시 멤버 목록 갱신. */
    fun removeRoomMember(roomId: String, userId: String) {
        viewModelScope.launch {
            try {
                MoimRepository.removeRoomMember(roomId, userId)
                roomMemberIds = MoimRepository.roomMemberIds(roomId)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "멤버 내보내기")
            }
        }
    }

    /** 구성원 초대 (방에 멤버 추가). 성공 시 멤버 목록 갱신. */
    fun inviteRoomMember(roomId: String, userId: String) {
        viewModelScope.launch {
            try {
                MoimRepository.addRoomMembers(roomId, listOf(userId))
                roomMemberIds = MoimRepository.roomMemberIds(roomId)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "구성원 초대")
            }
        }
    }

    fun renameRoom(room: Room, newName: String, onDone: () -> Unit = {}) {
        val trimmed = newName.trim()
        if (trimmed.isEmpty() || trimmed == room.name) { onDone(); return }
        viewModelScope.launch {
            try {
                MoimRepository.updateRoomName(room.id, trimmed)
                rooms = MoimRepository.rooms()
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "방 이름 변경")
            }
        }
    }

    fun nameOf(userId: String): String = profilesById[userId]?.name ?: "?"

    // 본인 제외 + 승인된 멤버만 (대기 중인 가입자는 방에 추가 불가)
    fun otherProfiles(): List<Profile> =
        profilesById.values
            .filter { it.id != MoimRepository.currentUserId() && it.approved != false }
            .sortedBy { it.name }

    fun canEditEvent(e: CalendarEvent): Boolean {
        val role = myProfile?.role
        if (role == "superadmin" || role == "admin") return true
        return e.ownerId == MoimRepository.currentUserId()
    }

    fun send(text: String) {
        val rid = activeRoom
        if (rid == null) return
        viewModelScope.launch {
            try {
                MoimRepository.sendMessage(rid, text)
                messages = MoimRepository.messages(rid)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "전송")
            }
        }
    }

    /** 본인이 쓴 메시지(텍스트/사진/파일) 삭제 */
    fun deleteMessage(id: String) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.deleteMessage(id)
                messages = MoimRepository.messages(rid)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "메시지 삭제")
            }
        }
    }

    /** 카톡식 첨부 전송 (type = image | file) */
    fun sendAttachment(fileName: String, bytes: ByteArray, type: String) {
        val rid = activeRoom
        if (rid == null) return
        viewModelScope.launch {
            try {
                MoimRepository.sendAttachment(rid, fileName, bytes, type)
                messages = MoimRepository.messages(rid)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "첨부 전송")
            }
        }
    }

    fun isMine(m: Message): Boolean {
        return m.senderId == MoimRepository.currentUserId()
    }

    /** 채팅 첨부(path) → 서명 URL 해석. messages 변경 시 호출(LaunchedEffect). */
    fun resolveAttachments() {
        val paths = messages.mapNotNull { it.attachmentUrl }
            .filter { it.isNotBlank() && !attachmentUrls.containsKey(it) }
            .distinct()
        if (paths.isEmpty()) return
        viewModelScope.launch {
            val map = attachmentUrls.toMutableMap()
            for (p in paths) MoimRepository.chatSignedUrl(p)?.let { map[p] = it }
            attachmentUrls = map
        }
    }
}

// =====================================================================
//  Activity
// =====================================================================
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 폰은 세로 고정, 태블릿(sw600dp)은 회전 허용
        if (resources.getBoolean(R.bool.portrait_only)) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }
        setContent {
            MaterialTheme {
                App()
            }
        }
    }
}

@Composable
fun App(vm: MoimViewModel = viewModel()) {
    var openedRoom by remember { mutableStateOf<Room?>(null) }
    var showWard by remember { mutableStateOf(false) }
    var showCreateRoom by remember { mutableStateOf(false) }
    var showApprovals by remember { mutableStateOf(false) }

    val lifecycleOwner = LocalLifecycleOwner.current

    LaunchedEffect(vm.loggedIn) {
        if (vm.loggedIn) {
            vm.loadRooms()
            vm.ensureRealtime()
            vm.startRoomListPolling()
        } else {
            vm.stopRoomListPolling()
        }
    }

    // cold start: 저장된 세션을 불러온 뒤 자동 로그인
    LaunchedEffect(Unit) {
        MoimRepository.ensureAuthReady()
        if (!vm.loggedIn && MoimRepository.currentUserId() != null) {
            vm.loggedIn = true
        }
    }

    DisposableEffect(lifecycleOwner, vm.loggedIn) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && vm.loggedIn) {
                vm.refreshOnForeground()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // 다른 기기·웹에서 방 삭제 시 열린 방 자동 닫기
    LaunchedEffect(vm.rooms, openedRoom?.id) {
        val id = openedRoom?.id ?: return@LaunchedEffect
        if (vm.rooms.none { it.id == id }) {
            vm.closeRoom()
            openedRoom = null
        }
    }

    when {
        !vm.loggedIn -> LoginScreen(vm)
        // 기본값 불승인: approved 가 true 가 아니면(false·미설정) 승인 대기
        vm.myProfile != null && vm.myProfile?.approved != true -> PendingApprovalScreen(vm)
        showWard -> WardStatusScreen(vm = vm, onBack = { showWard = false })
        showCreateRoom -> CreateRoomScreen(vm = vm, onBack = { showCreateRoom = false })
        showApprovals && vm.myProfile?.let { isAdminRole(it.role) } == true ->
            ApprovalScreen(vm = vm, onBack = { showApprovals = false })
        openedRoom == null -> RoomListScreen(
            vm = vm,
            onOpen = { room ->
                openedRoom = room
                vm.openRoom(room)
            },
            onWard = { showWard = true },
            onCreateRoom = { showCreateRoom = true },
            onApprovals = { showApprovals = true }
        )
        else -> RoomScreen(
            vm = vm,
            room = openedRoom!!,
            onBack = {
                vm.closeRoom()
                openedRoom = null
            }
        )
    }

    // 전역 오류 표시 (등록/수정/업로드 실패 원인이 보이도록)
    vm.error?.let { msg ->
        AlertDialog(
            onDismissRequest = { vm.error = null },
            confirmButton = { TextButton(onClick = { vm.error = null }) { Text("확인") } },
            title = { Text("오류") },
            text = { Text(msg) }
        )
    }
}
