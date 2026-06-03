package com.example.moimtalk.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.moimtalk.MoimViewModel
import com.example.moimtalk.R
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.Room

@Composable
fun LoginScreen(vm: MoimViewModel) {
    var email by remember { mutableStateOf("") }
    var pw by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MoimPaper)
            .padding(28.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Image(
            painter = painterResource(R.drawable.aumc_psy_logo),
            contentDescription = "AUMC PSY",
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .size(88.dp)
                .clip(RoundedCornerShape(20.dp))
        )
        Spacer(Modifier.height(20.dp))
        Text("모임톡", fontSize = 34.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
        Text("정신건강의학과", fontSize = 15.sp, color = MoimSub)
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
        vm.error?.let { err ->
            Spacer(Modifier.height(10.dp))
            Text(err, color = MoimAdmin, fontSize = 13.sp, lineHeight = 18.sp)
        }
        Spacer(Modifier.height(22.dp))
        Button(
            onClick = { vm.login(email.trim(), pw) },
            enabled = !vm.loading,
            colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(13.dp)
        ) {
            Text(if (vm.loading) "로그인 중..." else "로그인", fontSize = 16.sp)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomListScreen(
    vm: MoimViewModel,
    onOpen: (Room) -> Unit,
    onAdmin: () -> Unit
) {
    val profile = vm.myProfile
    val defaultRooms = vm.rooms.filter { it.category != "custom" }.sortedBy { it.sortOrder }
    val customRooms = vm.rooms.filter { it.category == "custom" }.sortedBy { it.sortOrder }

    Scaffold(
        topBar = {
            Column(modifier = Modifier.background(MoimPaper)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 18.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("모임톡", fontSize = 20.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        viewBadgeText(profile),
                        fontSize = 10.5.sp,
                        fontWeight = FontWeight.Bold,
                        color = MoimAccent,
                        modifier = Modifier
                            .background(MoimYellow, RoundedCornerShape(20.dp))
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = { vm.logout() }) { Text("로그아웃", fontSize = 12.sp) }
                }
                HorizontalDivider(color = MoimLine)
                profile?.let { p ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState())
                            .background(Color(0xFFFFF8E0))
                            .padding(horizontal = 14.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(7.dp)
                    ) {
                        Text("👁", fontSize = 11.sp, color = MoimSub, fontWeight = FontWeight.Bold)
                        ViewChip(p.name, p.memberType, selected = true)
                    }
                    HorizontalDivider(color = MoimLine)
                }
            }
        },
        containerColor = MoimPaper,
        bottomBar = {
            if (profile != null && isSuperAdmin(profile.role)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onAdmin)
                        .background(MoimAccent)
                        .padding(horizontal = 18.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(32.dp)
                            .background(MoimAdmin, RoundedCornerShape(10.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("🛡", fontSize = 15.sp)
                    }
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text("관리자 콘솔", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(
                            "전체관리자 전용 · 멤버/방/권한",
                            color = Color(0xFFBDB4AB),
                            fontSize = 11.sp
                        )
                    }
                    Text("›", color = Color(0xFFBDB4AB), fontSize = 18.sp)
                }
            }
        }
    ) { pad ->
        LazyColumn(
            modifier = Modifier
                .padding(pad)
                .fillMaxSize()
        ) {
            if (vm.rooms.isEmpty()) {
                item { EmptyBox("🔒", "아직 들어간 방이 없어요", "전체관리자가 방에 배정하면\n여기에 표시됩니다.") }
            } else {
                if (defaultRooms.isNotEmpty()) {
                    item { SectionHead("📌 기본 방 (우선순위)") }
                    items(defaultRooms) { room -> RoomRow(room, onOpen) }
                }
                item {
                    SectionHead(
                        title = "👥 모임 방",
                        action = if (profile != null && isAdminRole(profile.role)) "＋ 만들기" else null,
                        onAction = onAdmin
                    )
                }
                if (customRooms.isEmpty()) {
                    item {
                        Text(
                            "아직 모임방이 없습니다.",
                            modifier = Modifier.padding(horizontal = 18.dp, vertical = 12.dp),
                            color = MoimSub,
                            fontSize = 13.sp
                        )
                    }
                } else {
                    items(customRooms) { room -> RoomRow(room, onOpen) }
                }
            }
            vm.error?.let { err ->
                item {
                    Text(
                        err,
                        color = MoimAdmin,
                        fontSize = 12.sp,
                        modifier = Modifier.padding(18.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun ViewChip(name: String, memberType: String, selected: Boolean) {
    val bg = if (selected) MoimAccent else MoimWhite
    val fg = if (selected) Color.White else MoimInk
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(bg)
            .padding(start = 5.dp, end = 10.dp, top = 5.dp, bottom = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        Box(
            modifier = Modifier
                .size(19.dp)
                .background(typeColor(memberType), RoundedCornerShape(6.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(memberType.take(1), fontSize = 9.sp, color = Color.White, fontWeight = FontWeight.ExtraBold)
        }
        Text(name, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = fg)
    }
}

@Composable
private fun SectionHead(title: String, action: String? = null, onAction: (() -> Unit)? = null) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp, vertical = 8.dp)
            .padding(top = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = MoimSub, letterSpacing = 0.6.sp)
        if (action != null && onAction != null) {
            Text(
                action,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = MoimAccent,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(onClick = onAction)
                    .background(MoimWhite)
                    .padding(horizontal = 10.dp, vertical = 5.dp)
            )
        }
    }
}

@Composable
fun RoomRow(room: Room, onOpen: (Room) -> Unit) {
    val c = catColor(room.category)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onOpen(room) }
            .padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .background(c, RoundedCornerShape(16.dp)),
            contentAlignment = Alignment.Center
        ) {
            val label = if (room.category != "custom") room.sortOrder.toString() else "#"
            Text(label, color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    catLabel(room.category),
                    fontSize = 9.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color.White,
                    modifier = Modifier
                        .background(c, RoundedCornerShape(5.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                )
                Text(room.name, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MoimInk)
            }
            val desc = if (room.postPolicy == "restricted") {
                "공지 · 관리자/지정작성자"
            } else {
                "멤버 누구나"
            }
            Text(desc, fontSize = 12.5.sp, color = MoimSub, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Text("›", color = MoimSub, fontSize = 20.sp)
    }
    HorizontalDivider(color = MoimLine.copy(alpha = 0.4f))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomScreen(vm: MoimViewModel, room: Room, onBack: () -> Unit) {
    var tab by remember { mutableStateOf("chat") }
    var input by remember { mutableStateOf("") }
    val profile = vm.myProfile
    val canPost = canPostInRoom(profile, room)

    Scaffold(
        topBar = {
            Column(modifier = Modifier.background(MoimPaper)) {
                TopAppBar(
                    title = {
                        Column {
                            Text(room.name, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text(catLabel(room.category), fontSize = 12.sp, color = MoimSub)
                        }
                    },
                    navigationIcon = {
                        TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = MoimPaper)
                )
                Row(modifier = Modifier.fillMaxWidth()) {
                    listOf("chat" to "💬 채팅", "files" to "📁 자료실", "cal" to "📅 캘린더").forEach { (id, label) ->
                        val on = tab == id
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .clickable { tab = id }
                                .padding(vertical = 12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                label,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (on) MoimInk else MoimSub
                            )
                            Spacer(Modifier.height(8.dp))
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth(0.6f)
                                    .height(2.5.dp)
                                    .background(if (on) MoimYellow else Color.Transparent)
                            )
                        }
                    }
                }
                HorizontalDivider(color = MoimLine)
            }
        },
        bottomBar = {
            if (tab == "chat") {
                if (canPost) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MoimPaper)
                            .padding(horizontal = 12.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OutlinedTextField(
                            value = input,
                            onValueChange = { input = it },
                            modifier = Modifier.weight(1f),
                            placeholder = { Text("메시지 입력") },
                            singleLine = true,
                            shape = RoundedCornerShape(20.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        Box(
                            modifier = Modifier
                                .size(33.dp)
                                .background(MoimYellow, CircleShape)
                                .clickable {
                                    if (input.isNotBlank()) {
                                        vm.send(input.trim())
                                        input = ""
                                    }
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Text("➤", fontSize = 14.sp)
                        }
                    }
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(0xFFF3EDE3))
                            .padding(14.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "🔒 공지 전용 방 · 관리자와 지정 작성자만 글을 쓸 수 있어요",
                            fontSize = 12.5.sp,
                            color = MoimSub,
                            fontWeight = FontWeight.SemiBold,
                            lineHeight = 18.sp
                        )
                    }
                }
            }
        },
        containerColor = if (tab == "chat") MoimBg else MoimPaper
    ) { pad ->
        when (tab) {
            "chat" -> ChatPane(
                modifier = Modifier.padding(pad),
                messages = vm.messages,
                isMine = vm::isMine
            )
            "files" -> FilesPane(
                vm = vm,
                canUpload = canPost,
                modifier = Modifier.padding(pad)
            )
            else -> CalendarPane(
                vm = vm,
                room = room,
                canPost = canPost,
                modifier = Modifier.padding(pad)
            )
        }
    }
}

@Composable
private fun ChatPane(
    modifier: Modifier,
    messages: List<Message>,
    isMine: (Message) -> Boolean
) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "2026년 6월 3일 화요일",
                    fontSize = 11.sp,
                    color = Color.White,
                    modifier = Modifier
                        .background(Color(0x2E000000), RoundedCornerShape(20.dp))
                        .padding(horizontal = 12.dp, vertical = 4.dp)
                )
            }
        }
        if (messages.isEmpty()) {
            item {
                Text(
                    "대화를 시작해보세요",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(32.dp),
                    color = MoimSub,
                    fontSize = 14.sp
                )
            }
        } else {
            items(messages) { m -> MessageBubble(m, isMine(m)) }
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
        if (!mine) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(MoimSub, RoundedCornerShape(13.dp)),
                contentAlignment = Alignment.Center
            ) {
                Text("?", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.width(8.dp))
        }
        val bg = if (mine) MoimYellow else MoimWhite
        val shape = if (mine) {
            RoundedCornerShape(topStart = 16.dp, topEnd = 5.dp, bottomEnd = 16.dp, bottomStart = 16.dp)
        } else {
            RoundedCornerShape(topStart = 5.dp, topEnd = 16.dp, bottomEnd = 16.dp, bottomStart = 16.dp)
        }
        Box(
            modifier = Modifier
                .widthIn(max = 225.dp)
                .background(bg, shape)
                .padding(horizontal = 12.dp, vertical = 9.dp)
        ) {
            Text(m.content.orEmpty(), color = MoimInk, fontSize = 14.5.sp, lineHeight = 20.sp)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminPlaceholderScreen(onBack: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("관리자 콘솔", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    TextButton(onClick = onBack) { Text("‹", color = Color.White, fontSize = 25.sp) }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MoimAccent)
            )
        },
        containerColor = MoimPaper
    ) { pad ->
        Column(
            modifier = Modifier
                .padding(pad)
                .fillMaxSize()
                .padding(24.dp)
        ) {
            Text("멤버 풀 · 방 관리 · 작성자 지정", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            Spacer(Modifier.height(8.dp))
            Text(
                "HTML 프로토타입의 관리자 화면은 웹에서 구현되어 있습니다.\n" +
                    "앱에서는 Supabase 연동 후 단계적으로 추가할 예정입니다.",
                color = MoimSub,
                fontSize = 14.sp,
                lineHeight = 20.sp
            )
        }
    }
}

@Composable
private fun EmptyBox(emoji: String, title: String, subtitle: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.padding(30.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(emoji, fontSize = 38.sp)
        Spacer(Modifier.height(12.dp))
        Text(title, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MoimInk)
        Spacer(Modifier.height(6.dp))
        Text(subtitle, fontSize = 13.sp, color = MoimSub, lineHeight = 18.sp)
    }
}
