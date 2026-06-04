package com.example.moimtalk

import android.content.pm.ActivityInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import com.example.moimtalk.data.CalendarEvent
import com.example.moimtalk.data.Message
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
import com.example.moimtalk.ui.PendingApprovalScreen
import com.example.moimtalk.ui.WardStatusScreen
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
    var error by mutableStateOf<String?>(null)
    var notice by mutableStateOf<String?>(null)
    var loading by mutableStateOf(false)
    // 모임방 설정(멤버 관리)에서 보여줄 현재 방 멤버 id 목록
    var roomMemberIds by mutableStateOf<List<String>>(emptyList())

    private var activeRoom: String? = null

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
                } else {
                    notice = "가입 완료! 이메일 인증 후 로그인하세요."
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
                myProfile = MoimRepository.myProfile()
                rooms = MoimRepository.rooms()
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
        viewModelScope.launch {
            activeRoom = room.id
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
        activeRoom = null
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

    // ── 병실 잔여 현황 (메모) ──
    var wardStatus by mutableStateOf("")
    var wardStatusUpdatedAt by mutableStateOf<String?>(null)

    fun loadWardStatus() {
        viewModelScope.launch {
            try {
                val w = MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "병실현황 불러오기")
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
                error = friendlySupabaseError(e, "병실현황 저장")
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

    /** 현재 방의 멤버 목록을 불러와 roomMemberIds 에 저장 */
    fun loadRoomMembers(roomId: String) {
        viewModelScope.launch {
            roomMemberIds = try {
                MoimRepository.roomMemberIds(roomId)
            } catch (_: Exception) {
                emptyList()
            }
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

    fun isMine(m: Message): Boolean {
        return m.senderId == MoimRepository.currentUserId()
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

    LaunchedEffect(vm.loggedIn) {
        if (vm.loggedIn) {
            vm.loadRooms()
        }
    }

    when {
        !vm.loggedIn -> LoginScreen(vm)
        vm.myProfile?.approved == false -> PendingApprovalScreen(vm)
        showWard -> WardStatusScreen(vm = vm, onBack = { showWard = false })
        showCreateRoom -> CreateRoomScreen(vm = vm, onBack = { showCreateRoom = false })
        showApprovals -> ApprovalScreen(vm = vm, onBack = { showApprovals = false })
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
