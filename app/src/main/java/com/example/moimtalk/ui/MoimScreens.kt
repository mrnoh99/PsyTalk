package com.example.moimtalk.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.moimtalk.MoimViewModel
import com.example.moimtalk.R
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Room

@Composable
fun LoginScreen(vm: MoimViewModel) {
    var email by remember { mutableStateOf("") }
    var pw by remember { mutableStateOf("") }
    var signup by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var memberType by remember { mutableStateOf("의국") }
    val memberTypes = listOf("교실", "의국", "심리실", "연구실", "PA", "간호사", "SW", "보조원")

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MoimPaper)
            .verticalScroll(rememberScrollState())
            .imePadding()
            .padding(28.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(Modifier.height(40.dp))
        Image(
            painter = painterResource(R.drawable.aumc_psy_logo),
            contentDescription = "AUMC PSY",
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .size(88.dp)
                .clip(RoundedCornerShape(20.dp))
        )
        Spacer(Modifier.height(20.dp))
        Text("아주 정신", fontSize = 34.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
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
        if (signup) {
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("이름") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))
            Text("직군", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Spacer(Modifier.height(6.dp))
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                memberTypes.forEach { t ->
                    val on = memberType == t
                    Text(
                        t, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                        color = if (on) Color.White else MoimInk,
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .clickable { memberType = t }
                            .background(if (on) typeColor(t) else MoimWhite)
                            .padding(horizontal = 12.dp, vertical = 7.dp)
                    )
                }
            }
        }
        vm.error?.let { err ->
            Spacer(Modifier.height(10.dp))
            Text(err, color = MoimAdmin, fontSize = 13.sp, lineHeight = 18.sp)
        }
        vm.notice?.let { n ->
            Spacer(Modifier.height(10.dp))
            Text(n, color = catColor("work"), fontSize = 13.sp, lineHeight = 18.sp)
        }
        Spacer(Modifier.height(22.dp))
        Button(
            onClick = {
                if (signup) vm.signUp(email.trim(), pw, name.trim(), memberType)
                else vm.login(email.trim(), pw)
            },
            enabled = !vm.loading,
            colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            shape = RoundedCornerShape(13.dp)
        ) {
            Text(if (vm.loading) "처리 중..." else if (signup) "회원가입" else "로그인", fontSize = 16.sp)
        }
        Spacer(Modifier.height(14.dp))
        Text(
            if (signup) "이미 계정이 있나요?  로그인" else "계정이 없나요?  회원가입",
            color = MoimAccent, fontSize = 13.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .clickable { signup = !signup; vm.error = null; vm.notice = null }
                .padding(8.dp)
        )
    }
}

@Composable
fun PendingApprovalScreen(vm: MoimViewModel) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MoimPaper)
            .padding(30.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("⏳", fontSize = 46.sp)
        Spacer(Modifier.height(16.dp))
        Text("관리자 승인 대기 중", fontSize = 19.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
        Spacer(Modifier.height(10.dp))
        Text(
            "가입이 접수되었습니다.\n관리자가 승인하면 이용할 수 있습니다.",
            fontSize = 14.sp, color = MoimSub, lineHeight = 21.sp,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center
        )
        vm.myProfile?.let { p ->
            Spacer(Modifier.height(8.dp))
            Text("${p.name} · ${p.memberType}", fontSize = 12.sp, color = MoimSub)
        }
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = { vm.loadRooms() },
            colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
            shape = RoundedCornerShape(13.dp)
        ) { Text("다시 확인") }
        Spacer(Modifier.height(6.dp))
        TextButton(onClick = { vm.logout() }) { Text("로그아웃", color = MoimSub) }
    }
}

// 방 목록의 전체관리자용 가입 승인 진입 배너
@Composable
private fun ApprovalBanner(pending: Int, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(MoimAccent)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("🛡", fontSize = 18.sp)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text("가입 승인", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            Text(
                if (pending > 0) "승인 대기 ${pending}명" else "대기 없음",
                color = Color(0xFFBDB4AB), fontSize = 11.5.sp
            )
        }
        if (pending > 0) {
            Text(
                "$pending", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp,
                modifier = Modifier
                    .background(MoimAdmin, CircleShape)
                    .padding(horizontal = 8.dp, vertical = 3.dp)
            )
        } else {
            Text("›", color = Color(0xFFBDB4AB), fontSize = 18.sp)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ApprovalScreen(vm: MoimViewModel, onBack: () -> Unit) {
    val members = vm.profilesById.values.sortedWith(compareBy({ it.approved }, { it.role }, { it.name }))
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("가입 승인", fontWeight = FontWeight.Bold) },
                navigationIcon = { TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MoimPaper)
            )
        },
        containerColor = MoimPaper
    ) { pad ->
        LazyColumn(
            modifier = Modifier
                .padding(pad)
                .fillMaxSize()
                .padding(16.dp)
        ) {
            item {
                Text("미승인자가 위에 표시됩니다. 승인하면 앱을 이용할 수 있습니다.", fontSize = 12.sp, color = MoimSub)
                Spacer(Modifier.height(12.dp))
            }
            if (members.isEmpty()) {
                item { Text("멤버 정보가 없습니다.", fontSize = 13.sp, color = MoimSub) }
            } else {
                items(members) { p -> ApprovalRow(p, vm) }
            }
        }
    }
}

@Composable
private fun ApprovalRow(p: Profile, vm: MoimViewModel) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 9.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MoimWhite, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(38.dp)
                .background(typeColor(p.memberType), RoundedCornerShape(11.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(p.name.take(3), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.width(11.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(p.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Text("${p.memberType} · ${roleLabel(p.role)}", fontSize = 11.5.sp, color = MoimSub)
        }
        if (!p.approved) {
            Text(
                "승인", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .clickable { vm.approveUser(p.id, true) }
                    .background(catColor("work"))
                    .padding(horizontal = 14.dp, vertical = 7.dp)
            )
        } else {
            Text(
                "✓ 승인취소", color = MoimSub, fontSize = 11.5.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .clickable { vm.approveUser(p.id, false) }
                    .background(MoimBg)
                    .padding(horizontal = 12.dp, vertical = 7.dp)
            )
        }
    }
}

private fun roleLabel(role: String): String = when (role) {
    "superadmin" -> "전체관리자"
    "admin" -> "관리자"
    else -> "멤버"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomListScreen(
    vm: MoimViewModel,
    onOpen: (Room) -> Unit,
    onWard: () -> Unit,
    onCreateRoom: () -> Unit,
    onApprovals: () -> Unit
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
                    Text("아주 정신", fontSize = 20.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
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
        containerColor = MoimPaper
    ) { pad ->
        LazyColumn(
            modifier = Modifier
                .padding(pad)
                .fillMaxSize()
        ) {
            item { WardStatusBanner(onWard) }
            if (profile != null && isSuperAdmin(profile.role)) {
                item { ApprovalBanner(vm.profilesById.values.count { !it.approved }, onApprovals) }
            }
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
                        action = "＋ 만들기",
                        onAction = onCreateRoom
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
            val label = if (room.category != "custom") room.name else "#"
            Text(
                label,
                color = Color.White,
                fontWeight = FontWeight.ExtraBold,
                fontSize = 10.5.sp,
                lineHeight = 12.sp,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 3.dp)
            )
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
    // 이름 변경이 반영되도록 최신 방 정보를 vm.rooms 에서 조회
    val liveRoom = vm.rooms.firstOrNull { it.id == room.id } ?: room
    // 주간 학술활동 등 default_view='week' 방은 열자마자 캘린더(주간 목록)로 (프로토타입과 동일)
    var tab by remember { mutableStateOf(if (room.defaultView == "week") "cal" else "chat") }
    var input by remember { mutableStateOf("") }
    var showRename by remember { mutableStateOf(false) }
    var renameText by remember { mutableStateOf("") }
    var showSettings by remember { mutableStateOf(false) }
    val profile = vm.myProfile
    val canPost = canPostInRoom(profile, room)

    if (showSettings) {
        RoomSettingsDialog(
            vm = vm,
            room = liveRoom,
            onDismiss = { showSettings = false },
            onDeleted = { showSettings = false; onBack() }
        )
    }

    if (showRename) {
        AlertDialog(
            onDismissRequest = { showRename = false },
            title = { Text("방 이름 변경") },
            text = {
                OutlinedTextField(
                    value = renameText,
                    onValueChange = { renameText = it },
                    singleLine = true,
                    label = { Text("방 이름") }
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.renameRoom(liveRoom, renameText)
                    showRename = false
                }) { Text("저장") }
            },
            dismissButton = {
                TextButton(onClick = { showRename = false }) { Text("취소") }
            }
        )
    }

    Scaffold(
        topBar = {
            Column(modifier = Modifier.background(MoimPaper)) {
                TopAppBar(
                    title = {
                        Column {
                            Text(liveRoom.name, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text(catLabel(liveRoom.category), fontSize = 12.sp, color = MoimSub)
                        }
                    },
                    navigationIcon = {
                        TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) }
                    },
                    actions = {
                        if (canRenameRoom(profile, liveRoom)) {
                            TextButton(onClick = {
                                renameText = liveRoom.name
                                showRename = true
                            }) { Text("✏️", fontSize = 17.sp) }
                        }
                        if (canManageRoom(profile, liveRoom)) {
                            TextButton(onClick = {
                                vm.loadRoomMembers(liveRoom.id)
                                showSettings = true
                            }) { Text("⚙️", fontSize = 17.sp) }
                        }
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
                isMine = vm::isMine,
                nameOf = vm::nameOf
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
    isMine: (Message) -> Boolean,
    nameOf: (String) -> String
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
            items(messages) { m -> MessageBubble(m, isMine(m), nameOf(m.senderId)) }
        }
    }
}

@Composable
fun MessageBubble(m: Message, mine: Boolean, senderName: String) {
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
                Text(senderName.take(3), color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.width(8.dp))
        }
        val bg = if (mine) MoimYellow else MoimWhite
        val shape = if (mine) {
            RoundedCornerShape(topStart = 16.dp, topEnd = 5.dp, bottomEnd = 16.dp, bottomStart = 16.dp)
        } else {
            RoundedCornerShape(topStart = 5.dp, topEnd = 16.dp, bottomEnd = 16.dp, bottomStart = 16.dp)
        }
        Column(horizontalAlignment = if (mine) Alignment.End else Alignment.Start) {
            if (!mine) {
                Text(
                    senderName,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color(0xFF6B635C),
                    modifier = Modifier.padding(bottom = 3.dp, start = 2.dp)
                )
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
}

// 방 목록 맨 위 고정 배너 — 탭하면 병실현황 페이지로
@Composable
private fun WardStatusBanner(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 10.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFFEA7317))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("🛏", fontSize = 20.sp)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text("병실 잔여 현황", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
            Text("남 · 여 잔여 병상 보기", color = Color(0xFFFFE9D6), fontSize = 11.5.sp)
        }
        Text("›", color = Color.White, fontSize = 20.sp)
    }
}

// 병실 잔여 현황 — 메모 형식 자유 텍스트 (편집 → 게시, 모두에게 공유)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WardStatusScreen(vm: MoimViewModel, onBack: () -> Unit) {
    var editing by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }
    LaunchedEffect(Unit) { vm.loadWardStatus() }

    val updatedLabel = vm.wardStatusUpdatedAt?.let {
        runCatching {
            java.time.OffsetDateTime.parse(it)
                .atZoneSameInstant(java.time.ZoneId.of("Asia/Seoul"))
                .format(java.time.format.DateTimeFormatter.ofPattern("M/d HH:mm"))
        }.getOrNull()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("병실 잔여 현황", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) }
                },
                actions = {
                    if (!editing) {
                        TextButton(onClick = { draft = vm.wardStatus; editing = true }) {
                            Text("편집", fontWeight = FontWeight.Bold)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MoimPaper)
            )
        },
        containerColor = MoimPaper
    ) { pad ->
        Column(
            modifier = Modifier
                .padding(pad)
                .fillMaxSize()
                .padding(16.dp)
        ) {
            if (editing) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    placeholder = {
                        Text("예:\n- 남자\n다인실: 0자리 (1자리 EICU 전과예정)\n3인실(APICU): 0자리")
                    }
                )
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(
                        onClick = { editing = false },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = MoimLine, contentColor = MoimInk)
                    ) { Text("취소") }
                    Button(
                        onClick = { vm.saveWardStatus(draft) { editing = false } },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = MoimAccent)
                    ) { Text("게시") }
                }
            } else {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("🛏", fontSize = 22.sp)
                    Spacer(Modifier.width(8.dp))
                    Text("병실 잔여 현황", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, color = MoimInk)
                }
                updatedLabel?.let {
                    Spacer(Modifier.height(4.dp))
                    Text("최종 수정: $it", fontSize = 11.sp, color = MoimSub)
                }
                Spacer(Modifier.height(14.dp))
                if (vm.wardStatus.isBlank()) {
                    EmptyBox("🛏", "작성된 내용이 없습니다", "우측 상단 ‘편집’을 눌러\n병실 잔여 현황을 작성하세요.")
                } else {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f)
                            .clip(RoundedCornerShape(15.dp))
                            .background(MoimWhite)
                            .padding(16.dp)
                            .verticalScroll(rememberScrollState())
                    ) {
                        Text(vm.wardStatus, fontSize = 15.sp, color = MoimInk, lineHeight = 24.sp)
                    }
                }
            }
        }
    }
}

// 모임방 설정 — 멤버 내보내기 + 모임방 삭제 (생성자/관리자만)
@Composable
fun RoomSettingsDialog(
    vm: MoimViewModel,
    room: Room,
    onDismiss: () -> Unit,
    onDeleted: () -> Unit,
) {
    var confirmDelete by remember { mutableStateOf(false) }
    var kickTarget by remember { mutableStateOf<String?>(null) }
    val memberIds = vm.roomMemberIds

    // 모임방 삭제 확인
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("모임방 삭제") },
            text = { Text("‘${room.name}’ 모임방을 삭제할까요?\n채팅·일정·자료가 모두 삭제되며 되돌릴 수 없습니다.") },
            confirmButton = {
                TextButton(onClick = {
                    confirmDelete = false
                    vm.deleteRoom(room) { onDeleted() }
                }) { Text("삭제", color = MoimAdmin, fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("취소") } }
        )
    }

    // 멤버 내보내기 확인
    kickTarget?.let { uid ->
        AlertDialog(
            onDismissRequest = { kickTarget = null },
            title = { Text("멤버 내보내기") },
            text = { Text("‘${vm.nameOf(uid)}’ 님을 이 모임방에서 내보낼까요?") },
            confirmButton = {
                TextButton(onClick = {
                    vm.removeRoomMember(room.id, uid)
                    kickTarget = null
                }) { Text("내보내기", color = MoimAdmin, fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { kickTarget = null }) { Text("취소") } }
        )
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("모임방 설정", fontWeight = FontWeight.Bold) },
        text = {
            Column(modifier = Modifier
                .heightIn(max = 380.dp)
                .verticalScroll(rememberScrollState())) {
                Text("참여 멤버 (${memberIds.size}명)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
                Spacer(Modifier.height(8.dp))
                if (memberIds.isEmpty()) {
                    Text("멤버 정보를 불러오는 중…", fontSize = 13.sp, color = MoimSub)
                }
                memberIds.forEach { uid ->
                    val isCreator = uid == room.createdBy
                    val isMe = uid == MoimRepository.currentUserId()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            vm.nameOf(uid) + when {
                                isCreator -> " (방장)"
                                isMe -> " (나)"
                                else -> ""
                            },
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MoimInk,
                            modifier = Modifier.weight(1f)
                        )
                        // 방장은 내보낼 수 없음
                        if (!isCreator) {
                            TextButton(onClick = { kickTarget = uid }) {
                                Text("내보내기", fontSize = 13.sp, color = MoimAdmin)
                            }
                        }
                    }
                }
                Spacer(Modifier.height(14.dp))
                HorizontalDivider(color = MoimLine)
                Spacer(Modifier.height(12.dp))
                Button(
                    onClick = { confirmDelete = true },
                    modifier = Modifier.fillMaxWidth().height(46.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MoimAdmin),
                    shape = RoundedCornerShape(11.dp)
                ) {
                    Text("이 모임방 삭제", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("닫기") } }
    )
}

// 모임방 만들기 (카톡처럼 누구나) — 이름 + 참여 멤버 선택
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateRoomScreen(vm: MoimViewModel, onBack: () -> Unit) {
    var name by remember { mutableStateOf("") }
    var selected by remember { mutableStateOf(setOf<String>()) }
    val people = vm.otherProfiles()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("새 모임방", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MoimPaper)
            )
        },
        containerColor = MoimPaper
    ) { pad ->
        Column(
            modifier = Modifier
                .padding(pad)
                .fillMaxSize()
                .padding(16.dp)
        ) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("방 이름 (예: 우울증 연구모임)") },
                singleLine = true,
                shape = RoundedCornerShape(11.dp)
            )
            Spacer(Modifier.height(14.dp))
            Text("참여 멤버 선택", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Spacer(Modifier.height(8.dp))
            LazyColumn(modifier = Modifier.weight(1f)) {
                if (people.isEmpty()) {
                    item {
                        Text(
                            "표시할 멤버가 없습니다.",
                            fontSize = 13.sp, color = MoimSub,
                            modifier = Modifier.padding(8.dp)
                        )
                    }
                }
                items(people) { p ->
                    val on = selected.contains(p.id)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 7.dp)
                            .clip(RoundedCornerShape(11.dp))
                            .clickable { selected = if (on) selected - p.id else selected + p.id }
                            .background(if (on) Color(0xFFFFF8E0) else MoimWhite)
                            .padding(10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(32.dp)
                                .background(typeColor(p.memberType), RoundedCornerShape(10.dp)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(p.name.take(3), color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.width(10.dp))
                        Text(p.name, fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold, color = MoimInk, modifier = Modifier.weight(1f))
                        Text(
                            p.memberType,
                            fontSize = 9.sp, fontWeight = FontWeight.Bold, color = Color.White,
                            modifier = Modifier
                                .background(typeColor(p.memberType), RoundedCornerShape(5.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(if (on) "✓" else "○", color = if (on) MoimAccent else MoimLine, fontWeight = FontWeight.Bold)
                    }
                }
            }
            Spacer(Modifier.height(10.dp))
            Button(
                onClick = {
                    val nm = name.trim().ifBlank { "새 모임방" }
                    vm.createRoom(nm, selected.toList()) { onBack() }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
                shape = RoundedCornerShape(13.dp)
            ) {
                Text("방 만들기 (${selected.size + 1}명)", fontSize = 15.sp, fontWeight = FontWeight.Bold)
            }
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
