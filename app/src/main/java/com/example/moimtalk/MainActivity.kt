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
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Room
import com.example.moimtalk.data.friendlySupabaseError
import com.example.moimtalk.ui.AdminPlaceholderScreen
import com.example.moimtalk.ui.LoginScreen
import com.example.moimtalk.ui.RoomListScreen
import com.example.moimtalk.ui.RoomScreen
import kotlinx.coroutines.launch

// =====================================================================
//  ViewModel
// =====================================================================
class MoimViewModel : ViewModel() {

    var loggedIn by mutableStateOf(MoimRepository.currentUserId() != null)
    var myProfile by mutableStateOf<Profile?>(null)
    var rooms by mutableStateOf<List<Room>>(emptyList())
    var messages by mutableStateOf<List<Message>>(emptyList())
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
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "데이터 불러오기")
            }
        }
    }

    fun openRoom(room: Room) {
        viewModelScope.launch {
            activeRoom = room.id
            try {
                messages = MoimRepository.messages(room.id)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "메시지 불러오기")
            }
        }
    }

    fun closeRoom() {
        activeRoom = null
        messages = emptyList()
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

    LaunchedEffect(vm.loggedIn) {
        if (vm.loggedIn) {
            vm.loadRooms()
        }
    }

    when {
        !vm.loggedIn -> LoginScreen(vm)
        showAdmin -> AdminPlaceholderScreen(onBack = { showAdmin = false })
        openedRoom == null -> RoomListScreen(
            vm = vm,
            onOpen = { room ->
                openedRoom = room
                vm.openRoom(room)
            },
            onAdmin = { showAdmin = true }
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
