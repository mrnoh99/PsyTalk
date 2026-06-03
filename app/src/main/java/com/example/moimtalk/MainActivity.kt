package com.example.moimtalk

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Room
import kotlinx.coroutines.launch

// ===== 테마 색 =====
private val Paper = Color(0xFFF5F1EA)
private val Ink = Color(0xFF231F1C)
private val Accent = Color(0xFF2B2825)
private val Yellow = Color(0xFFFFE45C)
private val Sub = Color(0xFF8A817A)

private fun catColor(category: String): Color {
    return when (category) {
        "notice" -> Color(0xFFB5651D)
        "group" -> Color(0xFF4A6FA5)
        "work" -> Color(0xFF3D8361)
        "research" -> Color(0xFF6D597A)
        else -> Color(0xFF8A817A)
    }
}

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
                loggedIn = true
                loadRooms()
            } catch (e: Exception) {
                error = "로그인 실패: " + e.message
            }
            loading = false
        }
    }

    fun logout() {
        viewModelScope.launch {
            try {
                MoimRepository.signOut()
            } catch (e: Exception) {
                // 무시
            }
            loggedIn = false
            rooms = emptyList()
        }
    }

    fun loadRooms() {
        viewModelScope.launch {
            try {
                myProfile = MoimRepository.myProfile()
                rooms = MoimRepository.rooms()
            } catch (e: Exception) {
                error = e.message
            }
        }
    }

    fun openRoom(room: Room) {
        viewModelScope.launch {
            activeRoom = room.id
            try {
                messages = MoimRepository.messages(room.id)
            } catch (e: Exception) {
                error = e.message
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
                error = "전송 실패: " + e.message
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

    LaunchedEffect(vm.loggedIn) {
        if (vm.loggedIn) {
            vm.loadRooms()
        }
    }

    if (!vm.loggedIn) {
        LoginScreen(vm)
    } else if (openedRoom == null) {
        RoomListScreen(vm) { room ->
            openedRoom = room
            vm.openRoom(room)
        }
    } else {
        ChatScreen(vm, openedRoom!!) {
            vm.closeRoom()
            openedRoom = null
        }
    }
}

// ===== 로그인 =====
@Composable
fun LoginScreen(vm: MoimViewModel) {
    var email by remember { mutableStateOf("") }
    var pw by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Paper)
            .padding(28.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Text("모임톡", fontSize = 34.sp, fontWeight = FontWeight.ExtraBold, color = Ink)
        Text("정신건강의학과", fontSize = 15.sp, color = Sub)
        Spacer(Modifier.height(32.dp))
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("이메일") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = pw,
            onValueChange = { pw = it },
            label = { Text("비밀번호") },
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth()
        )
        val err = vm.error
        if (err != null) {
            Spacer(Modifier.height(10.dp))
            Text(err, color = Color(0xFFC0452F), fontSize = 13.sp)
        }
        Spacer(Modifier.height(22.dp))
        Button(
            onClick = { vm.login(email.trim(), pw) },
            enabled = !vm.loading,
            colors = ButtonDefaults.buttonColors(containerColor = Accent),
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(13.dp)
        ) {
            Text(if (vm.loading) "로그인 중..." else "로그인", fontSize = 16.sp)
        }
    }
}

// ===== 방 목록 =====
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomListScreen(vm: MoimViewModel, onOpen: (Room) -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("모임톡", fontWeight = FontWeight.ExtraBold)
                        val p = vm.myProfile
                        if (p != null) {
                            Text(p.name + " · " + p.memberType, fontSize = 12.sp, color = Sub)
                        }
                    }
                },
                actions = {
                    TextButton(onClick = { vm.logout() }) { Text("로그아웃") }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Paper)
            )
        },
        containerColor = Paper
    ) { pad ->
        LazyColumn(
            modifier = Modifier
                .padding(pad)
                .fillMaxSize()
        ) {
            items(vm.rooms) { room ->
                RoomRow(room, onOpen)
            }
        }
    }
}

@Composable
fun RoomRow(room: Room, onOpen: (Room) -> Unit) {
    val c = catColor(room.category)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(46.dp)
                .background(c, RoundedCornerShape(15.dp)),
            contentAlignment = Alignment.Center
        ) {
            val label = if (room.category != "custom") room.sortOrder.toString() else "#"
            Text(label, color = Color.White, fontWeight = FontWeight.ExtraBold)
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(room.name, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = Ink)
            val desc = if (room.postPolicy == "restricted") "공지 · 관리자/지정작성자" else "멤버 누구나"
            Text(desc, fontSize = 12.sp, color = Sub)
        }
        TextButton(onClick = { onOpen(room) }) { Text("열기") }
    }
    HorizontalDivider(color = Color(0x22000000))
}

// ===== 채팅 =====
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(vm: MoimViewModel, room: Room, onBack: () -> Unit) {
    var input by remember { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(room.name, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    TextButton(onClick = onBack) { Text("‹ 뒤로") }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Paper)
            )
        },
        bottomBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Paper)
                    .padding(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = input,
                    onValueChange = { input = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("메시지 입력") },
                    singleLine = true,
                    shape = RoundedCornerShape(22.dp)
                )
                Spacer(Modifier.width(8.dp))
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .background(Yellow, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    TextButton(onClick = {
                        if (input.isNotBlank()) {
                            vm.send(input.trim())
                            input = ""
                        }
                    }) {
                        Text("전송", color = Ink, fontSize = 12.sp)
                    }
                }
            }
        },
        containerColor = Color(0xFFE9E4DD)
    ) { pad ->
        LazyColumn(
            modifier = Modifier
                .padding(pad)
                .fillMaxSize()
                .padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(vm.messages) { m ->
                MessageBubble(m, vm.isMine(m))
            }
        }
    }
}

@Composable
fun MessageBubble(m: Message, mine: Boolean) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start
    ) {
        val bg = if (mine) Yellow else Color.White
        Box(
            modifier = Modifier
                .widthIn(max = 260.dp)
                .background(bg, RoundedCornerShape(16.dp))
                .padding(horizontal = 12.dp, vertical = 9.dp)
        ) {
            Text(m.content ?: "", color = Ink, fontSize = 15.sp)
        }
    }
}
