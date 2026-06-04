package com.example.moimtalk

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
import androidx.compose.material3.MaterialTheme
import com.example.moimtalk.data.CalendarEvent
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Room
import com.example.moimtalk.data.RoomFile
import com.example.moimtalk.data.friendlySupabaseError
import com.example.moimtalk.ui.AdminPlaceholderScreen
import com.example.moimtalk.ui.CreateRoomScreen
import com.example.moimtalk.ui.LoginScreen
import com.example.moimtalk.ui.RoomListScreen
import com.example.moimtalk.ui.RoomScreen
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
    var loading by mutableStateOf(false)

    private var activeRoom: String? = null

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
        keywords: List<String>,
        attachmentName: String?,
        attachmentBytes: ByteArray?,
        attachmentDesc: String?,
        onDone: () -> Unit,
    ) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.createEvent(
                    rid, title, startAt, place, link, scope, description, keywords,
                    attachmentName, attachmentBytes, attachmentDesc,
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
        keywords: List<String>,
        onDone: () -> Unit,
    ) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.updateEvent(eventId, title, startAt, place, link, scope, description, keywords)
                events = MoimRepository.events(rid)
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

    fun createRoom(name: String, memberIds: List<String>, onDone: () -> Unit) {
        viewModelScope.launch {
            try {
                MoimRepository.createRoom(name, memberIds)
                rooms = MoimRepository.rooms()
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "방 만들기")
            }
        }
    }

    fun nameOf(userId: String): String = profilesById[userId]?.name ?: "?"

    fun otherProfiles(): List<Profile> =
        profilesById.values.filter { it.id != MoimRepository.currentUserId() }.sortedBy { it.name }

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
    var showAdmin by remember { mutableStateOf(false) }
    var showWard by remember { mutableStateOf(false) }
    var showCreateRoom by remember { mutableStateOf(false) }

    LaunchedEffect(vm.loggedIn) {
        if (vm.loggedIn) {
            vm.loadRooms()
        }
    }

    when {
        !vm.loggedIn -> LoginScreen(vm)
        showAdmin -> AdminPlaceholderScreen(onBack = { showAdmin = false })
        showWard -> WardStatusScreen(vm = vm, onBack = { showWard = false })
        showCreateRoom -> CreateRoomScreen(vm = vm, onBack = { showCreateRoom = false })
        openedRoom == null -> RoomListScreen(
            vm = vm,
            onOpen = { room ->
                openedRoom = room
                vm.openRoom(room)
            },
            onAdmin = { showAdmin = true },
            onWard = { showWard = true },
            onCreateRoom = { showCreateRoom = true }
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
}
