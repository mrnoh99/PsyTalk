package com.example.moimtalk.ui

import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.zIndex
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import coil.compose.AsyncImage
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.moimtalk.MoimViewModel
import com.example.moimtalk.R
import com.example.moimtalk.data.LastMsg
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Room

@Composable
fun LoginScreen(vm: MoimViewModel) {
    var email by remember { mutableStateOf("") }
    var pw by remember { mutableStateOf("") }
    var pwConfirm by remember { mutableStateOf("") }
    var signup by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var intro by remember { mutableStateOf("") }
    var memberType by remember { mutableStateOf("의국") }
    val memberTypes = listOf("교실", "의국", "심리실", "연구실", "PA", "간호사", "SW", "보조원", "생명사랑", "비서", "의국동문", "심리실 동문", "기타")

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
            label = { Text(if (signup) "이메일" else "이메일 또는 핸드폰번호") },
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
                value = pwConfirm,
                onValueChange = { pwConfirm = it },
                label = { Text("비밀번호 확인") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                isError = pwConfirm.isNotEmpty() && pw != pwConfirm,
                modifier = Modifier.fillMaxWidth()
            )
            if (pwConfirm.isNotEmpty()) {
                Text(
                    if (pw == pwConfirm) "✓ 비밀번호가 일치합니다" else "비밀번호가 일치하지 않습니다",
                    color = if (pw == pwConfirm) catColor("work") else MoimAdmin,
                    fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp)
                )
            }
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("이름") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = phone,
                onValueChange = { phone = it },
                label = { Text("핸드폰번호 (예: 010-1234-5678)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = intro,
                onValueChange = { intro = it },
                label = { Text("간단한 소개 (예: 3년차 전공의)") },
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
                if (signup) vm.signUp(email.trim(), pw, name.trim(), memberType, phone.trim(), intro.trim())
                else vm.login(email.trim(), pw)
            },
            enabled = !vm.loading && (!signup || (pw.isNotEmpty() && pw == pwConfirm)),
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

// 방 목록의 관리자(전체관리자·관리자) 전용 가입 승인 진입 배너
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
            Text("관리자 콘솔", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            Text(
                if (pending > 0) "가입 승인 대기 ${pending}명" else "가입 승인 · 회원/방 관리",
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

// 관리자 콘솔 — 가입승인 / 회원관리 / 방관리. 관리자는 '가입 승인'만, 전체관리자는 전부.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminConsoleScreen(vm: MoimViewModel, onBack: () -> Unit) {
    val isSuper = vm.myProfile?.role == "superadmin"
    val tabs = if (isSuper) listOf("가입 승인", "회원 관리", "방 관리") else listOf("가입 승인")
    var tab by remember { mutableStateOf(0) }
    val collator = remember { java.text.Collator.getInstance(java.util.Locale.KOREAN) }
    LaunchedEffect(Unit) { vm.loadRoomMemberCounts() }

    // 방 관리: 방 선택 시 구성원 편집/삭제 다이얼로그
    var manageRoom by remember { mutableStateOf<Room?>(null) }
    manageRoom?.let { r ->
        RoomSettingsDialog(vm = vm, room = r, onDismiss = { manageRoom = null }, onDeleted = { manageRoom = null })
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("관리자 콘솔", fontWeight = FontWeight.Bold) },
                navigationIcon = { TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MoimPaper)
            )
        },
        containerColor = MoimPaper
    ) { pad ->
        Column(modifier = Modifier.padding(pad).fillMaxSize()) {
            if (tabs.size > 1) {
                Row(modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 4.dp)) {
                    tabs.forEachIndexed { i, t ->
                        SortChip(t, tab == i) { tab = i }
                        if (i < tabs.lastIndex) Spacer(Modifier.width(8.dp))
                    }
                }
            }
            when (tabs[tab]) {
                "가입 승인" -> ApprovalTab(vm, collator)
                "회원 관리" -> MemberManageTab(vm, collator)
                else -> RoomManageTab(vm) { r -> vm.loadRoomMembers(r.id); manageRoom = r }
            }
        }
    }
}

@Composable
private fun ApprovalTab(vm: MoimViewModel, collator: java.text.Collator) {
    var byType by remember { mutableStateOf(false) }
    // 신규 가입자(미승인 + 미탈퇴, 전체관리자 제외)
    val base = vm.profilesById.values.filter { it.role != "superadmin" && !it.withdrawn && !it.approved }
    val cmp: Comparator<Profile> = if (byType) Comparator { a, b ->
        val t = collator.compare(a.memberType, b.memberType); if (t != 0) t else collator.compare(a.name, b.name)
    } else Comparator { a, b -> collator.compare(a.name, b.name) }
    val members = base.sortedWith(cmp)
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        item {
            Row(modifier = Modifier.padding(bottom = 10.dp)) {
                SortChip("가나다순", !byType) { byType = false }
                Spacer(Modifier.width(8.dp))
                SortChip("직군별", byType) { byType = true }
            }
            Text("신규 가입자를 ‘승인’하면 바로 앱을 이용할 수 있고, 회원 관리 명단으로 이동합니다. (전체관리자 제외)", fontSize = 12.sp, color = MoimSub)
            Spacer(Modifier.height(12.dp))
        }
        if (members.isEmpty()) {
            item { Text("승인 대기 중인 신규 가입자가 없습니다.", fontSize = 13.sp, color = MoimSub) }
        } else if (byType) {
            members.groupBy { it.memberType }.forEach { (type, list) ->
                item { Text("$type · ${list.size}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = typeColor(type), modifier = Modifier.padding(top = 4.dp, bottom = 6.dp)) }
                items(list, key = { it.id }) { p -> ApprovalRow(p, vm) }
            }
        } else {
            items(members, key = { it.id }) { p -> ApprovalRow(p, vm) }
        }
    }
}

@Composable
private fun MemberManageTab(vm: MoimViewModel, collator: java.text.Collator) {
    var byType by remember { mutableStateOf(false) }
    // 승인된 회원(미탈퇴, 전체관리자 제외)
    val base = vm.profilesById.values.filter { it.role != "superadmin" && !it.withdrawn && it.approved }
    val cmp: Comparator<Profile> = if (byType) Comparator { a, b ->
        val t = collator.compare(a.memberType, b.memberType); if (t != 0) t else collator.compare(a.name, b.name)
    } else Comparator { a, b -> collator.compare(a.name, b.name) }
    val members = base.sortedWith(cmp)
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        item {
            Row(modifier = Modifier.padding(bottom = 10.dp)) {
                SortChip("가나다순", !byType) { byType = false }
                Spacer(Modifier.width(8.dp))
                SortChip("직군별", byType) { byType = true }
            }
            Text("관리자 지위 지정 / 계정 비활성화. (전체관리자 제외)", fontSize = 12.sp, color = MoimSub)
            Spacer(Modifier.height(12.dp))
        }
        if (members.isEmpty()) {
            item { Text("승인된 회원이 없습니다.", fontSize = 13.sp, color = MoimSub) }
        } else if (byType) {
            members.groupBy { it.memberType }.forEach { (type, list) ->
                item { Text("$type · ${list.size}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = typeColor(type), modifier = Modifier.padding(top = 4.dp, bottom = 6.dp)) }
                items(list, key = { it.id }) { p -> MemberManageRow(p, vm) }
            }
        } else {
            items(members, key = { it.id }) { p -> MemberManageRow(p, vm) }
        }
    }
}

@Composable
private fun RoomManageTab(vm: MoimViewModel, onManage: (Room) -> Unit) {
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        item {
            Text("🏠 방 관리 · ${vm.rooms.size}개 · 방을 눌러 구성원 편집", fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = MoimSub, modifier = Modifier.padding(bottom = 10.dp))
        }
        items(vm.rooms, key = { it.id }) { r -> RoomManageRow(r, vm.roomMemberCounts[r.id] ?: 0, onManage) }
    }
}

@Composable
private fun SortChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold,
        color = if (selected) Color.White else MoimSub,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .background(if (selected) MoimAccent else MoimBg)
            .padding(horizontal = 14.dp, vertical = 7.dp)
    )
}

@Composable
private fun ApprovalRow(p: Profile, vm: MoimViewModel) {
    var confirmApprove by remember { mutableStateOf(false) }
    if (confirmApprove) {
        AlertDialog(
            onDismissRequest = { confirmApprove = false },
            title = { Text("가입 승인") },
            text = { Text("‘${p.name}’ 님의 가입을 승인할까요?\n승인하면 앱을 바로 이용할 수 있습니다.") },
            confirmButton = {
                TextButton(onClick = { confirmApprove = false; vm.approveUser(p.id) }) {
                    Text("승인", color = catColor("work"), fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = { TextButton(onClick = { confirmApprove = false }) { Text("취소") } }
        )
    }
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
            modifier = Modifier.size(38.dp).background(typeColor(p.memberType), RoundedCornerShape(11.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(p.name.take(3), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.width(11.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(p.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk)
                Spacer(Modifier.width(6.dp))
                Text(
                    "대기", color = MoimAdmin, fontSize = 9.5.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(MoimAdmin.copy(alpha = 0.12f)).padding(horizontal = 6.dp, vertical = 2.dp)
                )
            }
            Text("${p.memberType} · ${roleLabel(p.role)}", fontSize = 11.5.sp, color = MoimSub)
        }
        Text(
            "승인", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.clip(RoundedCornerShape(20.dp)).clickable { confirmApprove = true }.background(catColor("work")).padding(horizontal = 16.dp, vertical = 7.dp)
        )
    }
}

// 회원 관리 행 — 관리자 지위 토글 + 계정 비활성화 (전체관리자 전용 화면)
@Composable
private fun MemberManageRow(p: Profile, vm: MoimViewModel) {
    var confirmDeact by remember { mutableStateOf(false) }
    if (confirmDeact) {
        AlertDialog(
            onDismissRequest = { confirmDeact = false },
            title = { Text("계정 비활성화") },
            text = { Text("‘${p.name}’ 님의 계정을 비활성화할까요?\n로그인·활동이 막히고 모든 방에서 제외됩니다.") },
            confirmButton = {
                TextButton(onClick = { confirmDeact = false; vm.adminDeactivate(p.id) }) {
                    Text("계정 비활성화", color = MoimAdmin, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = { TextButton(onClick = { confirmDeact = false }) { Text("취소") } }
        )
    }
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
            modifier = Modifier.size(38.dp).background(typeColor(p.memberType), RoundedCornerShape(11.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(p.name.take(3), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.width(11.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(p.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Text("${p.memberType} · ${roleLabel(p.role)}", fontSize = 11.5.sp, color = MoimSub)
        }
        val isAdmin = p.role == "admin"
        Text(
            if (isAdmin) "관리자 ✓" else "관리자 지정",
            color = if (isAdmin) Color.White else MoimAccent, fontSize = 11.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .clickable { vm.setRole(p.id, if (isAdmin) "user" else "admin") }
                .background(if (isAdmin) MoimAccent else MoimBg)
                .padding(horizontal = 10.dp, vertical = 6.dp)
        )
        Spacer(Modifier.width(6.dp))
        Text(
            "계정 비활성화", color = MoimAdmin, fontSize = 11.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .clickable { confirmDeact = true }
                .background(MoimAdmin.copy(alpha = 0.12f))
                .padding(horizontal = 10.dp, vertical = 6.dp)
        )
    }
}

// 방 관리 행 — 가운데 구분 바 없이 카드형. 누르면 구성원 편집/삭제
@Composable
private fun RoomManageRow(r: Room, count: Int, onManage: (Room) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 9.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MoimWhite, RoundedCornerShape(12.dp))
            .clickable { onManage(r) }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        RoomAvatar(r, 40, 12, 8.5)
        Spacer(Modifier.width(11.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(r.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Text("${catLabel(r.category)} · ${r.postPolicy}" + if (count > 0) " · ${count}명" else "", fontSize = 11.5.sp, color = MoimSub)
        }
        Text("›", fontSize = 18.sp, color = MoimSub)
    }
}

private fun roleLabel(role: String): String = when (role) {
    "superadmin" -> "전체관리자"
    "admin" -> "관리자"
    else -> "회원"
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
    // 주간 학술활동(default_view=week)은 목록에서 빼고 별도 바로 표시. 나머지는 전체방(첫번째)+모임방 평면 목록.
    val weekRoom = vm.rooms.firstOrNull { it.category != "custom" && it.defaultView == "week" }
    // 고정(핀) 우선 + 나머지는 최근 메시지순
    // 홈 목록: 기본 방은 항상, 모임방(custom)은 내가 가입한 것만 (관리자 콘솔은 전체 vm.rooms 사용)
    val flatRooms = vm.rooms.filter { it.id != weekRoom?.id && (it.category != "custom" || vm.myRoomIds.contains(it.id)) }
    val pinnedRooms = vm.roomPins.mapNotNull { id -> flatRooms.find { it.id == id } }
    val pinnedIds = pinnedRooms.map { it.id }.toSet()
    val listRooms = pinnedRooms + flatRooms.filter { it.id !in pinnedIds }
        .sortedWith(compareByDescending<Room> { vm.lastMsgByRoom[it.id]?.createdAt ?: "" }.thenBy { it.sortOrder })
    var showPinSettings by remember { mutableStateOf(false) }
    if (showPinSettings) {
        PinSettingsDialog(
            vm = vm,
            rooms = flatRooms,
            pins = vm.roomPins,
            onSave = { vm.saveRoomPins(it); showPinSettings = false },
            onDismiss = { showPinSettings = false }
        )
    }

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
                    TextButton(onClick = { vm.loadRooms() }) { Text("↻", fontSize = 17.sp) }
                    // 관리자 진입: admin='가입승인' / superadmin='관리자모드'
                    when (profile?.role) {
                        "superadmin" -> TextButton(onClick = onApprovals) { Text("관리자모드", fontSize = 12.sp, color = MoimAdmin, fontWeight = FontWeight.Bold) }
                        "admin" -> TextButton(onClick = onApprovals) { Text("가입승인", fontSize = 12.sp, color = MoimAdmin, fontWeight = FontWeight.Bold) }
                    }
                    // 설정(⚙️): 방 순서 + 회원 탈퇴·로그아웃
                    TextButton(onClick = { showPinSettings = true }) { Text("⚙️", fontSize = 15.sp) }
                }
                HorizontalDivider(color = MoimLine)
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
            weekRoom?.let { wr -> item { WeekRoomBar(wr, vm.unreadByRoom[wr.id] ?: 0, onOpen) } }
            item { CreateRoomButton(onCreateRoom) }
            if (listRooms.isEmpty()) {
                item { EmptyBox("🔒", "아직 방이 없어요", "전체관리자가 방에 배정하면\n여기에 표시됩니다.") }
            } else {
                items(listRooms) { room -> RoomRow(room, vm.unreadByRoom[room.id] ?: 0, vm.lastMsgByRoom[room.id], onOpen) }
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
@Composable
fun ColorSwatchRow(selected: String?, onPick: (String) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        ROOM_COLORS.forEach { hex ->
            val sel = hex.equals(selected, ignoreCase = true)
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(parseHexColor(hex) ?: MoimSub)
                    .border(if (sel) 3.dp else 0.dp, if (sel) MoimInk else Color.Transparent, RoundedCornerShape(8.dp))
                    .clickable { onPick(hex) }
            )
        }
    }
}

// 방표식(색상·사진) 편집기 — 생성/이름변경 공통
@Composable
fun RoomAppearancePicker(
    name: String,
    color: String,
    onColor: (String) -> Unit,
    iconUri: Uri?,
    existingIconUrl: String?,
    onPickPhoto: () -> Unit,
    onClearPhoto: () -> Unit,
) {
    Text("방표식 색상", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
    Spacer(Modifier.height(6.dp))
    ColorSwatchRow(color, onColor)
    Spacer(Modifier.height(10.dp))
    Text("방표식 사진 (선택)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
    Spacer(Modifier.height(6.dp))
    Row(verticalAlignment = Alignment.CenterVertically) {
        val shape = RoundedCornerShape(12.dp)
        val img: Any? = iconUri ?: existingIconUrl
        if (img != null) {
            AsyncImage(model = img, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(44.dp).clip(shape))
        } else {
            Box(modifier = Modifier.size(44.dp).background(parseHexColor(color) ?: MoimSub, shape), contentAlignment = Alignment.Center) {
                Text(name.ifBlank { "방" }.take(3), color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
            }
        }
        Spacer(Modifier.width(10.dp))
        TextButton(onClick = onPickPhoto) { Text("사진 선택") }
        if (img != null) TextButton(onClick = onClearPhoto) { Text("제거", color = MoimAdmin) }
    }
}

@Composable
fun RoomAvatar(room: Room, sizeDp: Int, cornerDp: Int, fontSp: Double) {
    val shape = RoundedCornerShape(cornerDp.dp)
    if (!room.iconUrl.isNullOrBlank()) {
        AsyncImage(
            model = room.iconUrl,
            contentDescription = room.name,
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(sizeDp.dp).clip(shape)
        )
    } else {
        Box(
            modifier = Modifier.size(sizeDp.dp).background(roomColor(room), shape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                room.name, color = Color.White, fontWeight = FontWeight.ExtraBold,
                fontSize = fontSp.sp, lineHeight = (fontSp + 1.5).sp, textAlign = TextAlign.Center,
                maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(horizontal = 3.dp)
            )
        }
    }
}

@Composable
fun RoomRow(room: Room, unread: Int = 0, lastMsg: LastMsg? = null, onOpen: (Room) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onOpen(room) }
            .padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        RoomAvatar(room, 48, 16, 10.5)
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
            val desc = msgPreview(lastMsg).ifBlank {
                if (room.postPolicy == "restricted") "공지 · 관리자/지정작성자" else ""
            }
            Text(desc, fontSize = 12.5.sp, color = MoimSub, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.width(6.dp))
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(5.dp)) {
            val t = fmtListTime(lastMsg?.createdAt)
            if (t.isNotEmpty()) Text(t, fontSize = 11.sp, color = MoimSub)
            if (unread > 0) UnreadBadge(unread)
        }
    }
    HorizontalDivider(color = MoimLine.copy(alpha = 0.4f))
}

@Composable
private fun UnreadBadge(n: Int) {
    Text(
        if (n > 99) "99+" else n.toString(),
        color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold,
        modifier = Modifier
            .background(MoimAdmin, RoundedCornerShape(11.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp)
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomScreen(vm: MoimViewModel, room: Room, onBack: () -> Unit) {
    // 이름 변경이 반영되도록 최신 방 정보를 vm.rooms 에서 조회
    val liveRoom = vm.rooms.firstOrNull { it.id == room.id } ?: room
    // 주간 학술활동 등 default_view='week' 방은 열자마자 캘린더(주간 목록)로 (프로토타입과 동일)
    var tab by remember { mutableStateOf(if (room.category != "custom" && room.defaultView == "week") "cal" else "chat") }
    var input by remember { mutableStateOf("") }
    var showAttach by remember { mutableStateOf(false) }
    val context = LocalContext.current
    // 카톡식 + 첨부: 선택하면 '대기'에 담고, 보내기(➤) 누르면 전송. (name, bytes, kind)
    var pendingAttach by remember { mutableStateOf<Triple<String, ByteArray, String>?>(null) }
    val imgPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) readUri(context, uri)?.let { (n, b) -> pendingAttach = Triple(n, b, "image") }
    }
    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) readUri(context, uri)?.let { (n, b) -> pendingAttach = Triple(n, b, "file") }
    }
    var showRename by remember { mutableStateOf(false) }
    var renameText by remember { mutableStateOf("") }
    // 방표식(색상·사진) 편집 상태
    var editColor by remember { mutableStateOf(ROOM_COLORS[1]) }
    var editIconUri by remember { mutableStateOf<Uri?>(null) }
    var editIconBytes by remember { mutableStateOf<ByteArray?>(null) }
    var editIconName by remember { mutableStateOf<String?>(null) }
    var editIconCleared by remember { mutableStateOf(false) }
    val iconPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) { editIconUri = uri; editIconCleared = false; readUri(context, uri)?.let { (n, b) -> editIconName = n; editIconBytes = b } }
    }
    var showSettings by remember { mutableStateOf(false) }
    var showLeave by remember { mutableStateOf(false) }
    val profile = vm.myProfile
    val canPost = canPostInRoom(profile, room)

    if (showLeave) {
        AlertDialog(
            onDismissRequest = { showLeave = false },
            title = { Text("방 나가기") },
            text = { Text("'${liveRoom.name}' 방에서 나갈까요?") },
            confirmButton = {
                TextButton(onClick = {
                    showLeave = false
                    vm.leaveRoom(liveRoom) { onBack() }
                }) { Text("나가기", color = MoimAdmin) }
            },
            dismissButton = { TextButton(onClick = { showLeave = false }) { Text("취소") } }
        )
    }

    // 채팅 첨부(path) → 서명 URL 해석 (방 구성원만)
    LaunchedEffect(vm.messages) { vm.resolveAttachments() }

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
            title = { Text("방 정보 변경") },
            text = {
                Column {
                    OutlinedTextField(
                        value = renameText,
                        onValueChange = { renameText = it },
                        singleLine = true,
                        label = { Text("방 이름") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(14.dp))
                    RoomAppearancePicker(
                        name = renameText, color = editColor, onColor = { editColor = it },
                        iconUri = editIconUri,
                        existingIconUrl = if (editIconCleared) null else liveRoom.iconUrl,
                        onPickPhoto = { iconPicker.launch("image/*") },
                        onClearPhoto = { editIconUri = null; editIconBytes = null; editIconName = null; editIconCleared = true }
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.updateRoomAppearance(liveRoom, renameText, editColor, editIconBytes, editIconName, editIconCleared)
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
                                editColor = liveRoom.color ?: ROOM_COLORS[1]
                                editIconUri = null; editIconBytes = null; editIconName = null; editIconCleared = false
                                showRename = true
                            }) { Text("이름변경", fontSize = 13.sp, color = MoimAccent, fontWeight = FontWeight.Bold) }
                        }
                        if (canManageRoom(profile, liveRoom)) {
                            TextButton(onClick = {
                                vm.loadRoomMembers(liveRoom.id)
                                showSettings = true
                            }) { Text("⚙️", fontSize = 17.sp) }
                        }
                        // 본인이 만들지 않은 모임방: 나가기
                        if (canLeaveRoom(profile, liveRoom)) {
                            TextButton(onClick = { showLeave = true }) {
                                Text("나가기", fontSize = 13.sp, color = MoimAdmin)
                            }
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = MoimPaper)
                )
                Row(modifier = Modifier.fillMaxWidth()) {
                    // 자료실·캘린더는 기본 방(과전체공지·주간 학술활동)만. 모임방(custom)은 채팅만.
                    // 모임방 채팅 탭은 '채팅' 대신 '개설자: <방개설자 이름>' 표시
                    val chatLabel = liveRoom.createdBy?.let { "개설자: ${vm.nameOf(it)}" } ?: "💬 채팅"
                    val tabs = if (room.category != "custom")
                        listOf("chat" to "💬 채팅", "files" to "📁 자료실", "cal" to "📅 캘린더")
                    else listOf("chat" to chatLabel)
                    tabs.forEach { (id, label) ->
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
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .navigationBarsPadding()
                            .imePadding()
                            .background(MoimPaper)
                    ) {
                        // 첨부 대기 미리보기 (선택 후 ➤ 누르면 전송)
                        pendingAttach?.let { (name, _, kind) ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 12.dp, vertical = 7.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    "${if (kind == "image") "🖼" else "📎"}  $name",
                                    fontSize = 12.5.sp, color = MoimInk,
                                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.weight(1f)
                                )
                                Text(
                                    "✕", fontSize = 15.sp, color = MoimAdmin, fontWeight = FontWeight.Bold,
                                    modifier = Modifier
                                        .clickable { pendingAttach = null }
                                        .padding(horizontal = 6.dp)
                                )
                            }
                        }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 9.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box {
                            Box(
                                modifier = Modifier
                                    .size(33.dp)
                                    .clip(CircleShape)
                                    .background(MoimWhite, CircleShape)
                                    .clickable { showAttach = true },
                                contentAlignment = Alignment.Center
                            ) {
                                Text("＋", fontSize = 19.sp, color = MoimSub)
                            }
                            DropdownMenu(expanded = showAttach, onDismissRequest = { showAttach = false }) {
                                DropdownMenuItem(
                                    text = { Text("📷  사진") },
                                    onClick = { showAttach = false; imgPicker.launch("image/*") }
                                )
                                DropdownMenuItem(
                                    text = { Text("📎  파일") },
                                    onClick = { showAttach = false; filePicker.launch("*/*") }
                                )
                            }
                        }
                        Spacer(Modifier.width(8.dp))
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
                                    pendingAttach?.let { (n, b, k) ->
                                        vm.sendAttachment(n, b, k); pendingAttach = null
                                    }
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
                    }
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .navigationBarsPadding()
                            .imePadding()
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
                nameOf = vm::nameOf,
                attachUrl = { vm.attachmentUrls[it] },
                onDelete = { vm.deleteMessage(it.id) },
                unreadOf = { vm.unreadByMsg[it.id] ?: 0 }
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
    nameOf: (String) -> String,
    attachUrl: (String) -> String?,
    onDelete: (Message) -> Unit,
    unreadOf: (Message) -> Int
) {
    var deleteTarget by remember { mutableStateOf<Message?>(null) }
    deleteTarget?.let { tgt ->
        AlertDialog(
            onDismissRequest = { deleteTarget = null },
            title = { Text("메시지 삭제") },
            text = { Text("이 메시지를 삭제할까요?") },
            confirmButton = {
                TextButton(onClick = { deleteTarget = null; onDelete(tgt) }) {
                    Text("삭제", color = MoimAdmin, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = { TextButton(onClick = { deleteTarget = null }) { Text("취소") } }
        )
    }
    val listState = rememberLazyListState()
    val imeBottom = WindowInsets.ime.getBottom(LocalDensity.current)
    val lastIndex = if (messages.isEmpty()) 1 else messages.size

    LaunchedEffect(messages.size, imeBottom) {
        if (lastIndex >= 0) {
            listState.animateScrollToItem(lastIndex)
        }
    }

    LazyColumn(
        state = listState,
        modifier = modifier
            .fillMaxSize()
            .padding(horizontal = 12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
        contentPadding = PaddingValues(bottom = 8.dp),
    ) {
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
            // 날짜가 바뀌면 가운데 날짜 구분선 삽입
            var lastDay = ""
            messages.forEach { m ->
                val day = dayKey(m.createdAt)
                if (day != lastDay) {
                    item { DateDivider(fmtDateDivider(m.createdAt)) }
                    lastDay = day
                }
                item(key = m.id) {
                    MessageBubble(m, isMine(m), nameOf(m.senderId), attachUrl, onDelete = { deleteTarget = m }, unread = unreadOf(m))
                }
            }
        }
    }
}

// 채팅 가운데 날짜 구분선
@Composable
private fun DateDivider(text: String) {
    Box(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text, fontSize = 11.sp, color = Color.White,
            modifier = Modifier
                .background(Color(0x33000000), RoundedCornerShape(20.dp))
                .padding(horizontal = 12.dp, vertical = 4.dp)
        )
    }
}

@Composable
fun MessageBubble(
    m: Message, mine: Boolean, senderName: String,
    attachUrl: (String) -> String? = { null }, onDelete: () -> Unit = {}, unread: Int = 0
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start
    ) {
        if (mine) {
            // 본인 메시지 삭제
            Text(
                "🗑", fontSize = 13.sp,
                modifier = Modifier
                    .align(Alignment.CenterVertically)
                    .clickable { onDelete() }
                    .padding(horizontal = 6.dp)
            )
        }
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
        if (mine && unread > 0) {
            Text(
                if (unread > 99) "99+" else unread.toString(),
                color = Color(0xFFE0922F), fontSize = 11.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.Bottom).padding(horizontal = 4.dp)
            )
        }
        if (mine) {
            Text(fmtMsgTime(m.createdAt), fontSize = 10.sp, color = MoimSub,
                modifier = Modifier.align(Alignment.Bottom).padding(horizontal = 3.dp))
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
            val uriHandler = LocalUriHandler.current
            val path = m.attachmentUrl
            // 공개 URL(http)은 즉시 표시, 과거 path 는 서명 URL 캐시 사용
            val resolved = path?.let { p ->
                attachUrl(p) ?: if (p.startsWith("http")) p else null
            }
            when {
                m.type == "image" && path != null -> AsyncImage(
                    model = resolved,
                    contentDescription = "사진",
                    modifier = Modifier
                        .widthIn(max = 220.dp)
                        .heightIn(max = 260.dp)
                        .clip(RoundedCornerShape(14.dp))
                        .background(MoimBg, RoundedCornerShape(14.dp))
                        .clickable { resolved?.let { uriHandler.openUri(it) } }
                )
                m.type == "file" && path != null -> Row(
                    modifier = Modifier
                        .widthIn(max = 225.dp)
                        .clip(shape)
                        .background(MoimWhite, shape)
                        .clickable { resolved?.let { uriHandler.openUri(it) } }
                        .padding(horizontal = 12.dp, vertical = 11.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("📎", fontSize = 16.sp)
                    Spacer(Modifier.width(7.dp))
                    Text(
                        m.attachmentName ?: "파일", color = MoimInk, fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis
                    )
                }
                else -> Box(
                    modifier = Modifier
                        .widthIn(max = 225.dp)
                        .background(bg, shape)
                        .padding(horizontal = 12.dp, vertical = 9.dp)
                ) {
                    Text(m.content.orEmpty(), color = MoimInk, fontSize = 14.5.sp, lineHeight = 20.sp)
                }
            }
        }
        if (!mine) {
            Text(fmtMsgTime(m.createdAt), fontSize = 10.sp, color = MoimSub,
                modifier = Modifier.align(Alignment.Bottom).padding(horizontal = 3.dp))
        }
        if (!mine && unread > 0) {
            Text(
                if (unread > 99) "99+" else unread.toString(),
                color = Color(0xFFE0922F), fontSize = 11.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.Bottom).padding(horizontal = 4.dp)
            )
        }
    }
}

// 방 목록 맨 위 고정 배너 — 탭하면 잔여 병실 현황 페이지로
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
            Text("잔여 병실 현황", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
            Text("남 · 여 잔여 병상 보기", color = Color(0xFFFFE9D6), fontSize = 11.5.sp)
        }
        Text("›", color = Color.White, fontSize = 20.sp)
    }
}

// 주간 학술활동 고정 바 (잔여 병실 현황 아래, 파란색)
@Composable
private fun WeekRoomBar(room: Room, unread: Int = 0, onOpen: (Room) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp)
            .padding(bottom = 10.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFF4A6FA5))
            .clickable { onOpen(room) }
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("📅", fontSize = 20.sp)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(room.name, color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
            Text("주간 학술활동 · 일정 보기", color = Color(0xFFDDE6F3), fontSize = 11.5.sp)
        }
        if (unread > 0) {
            UnreadBadge(unread)
            Spacer(Modifier.width(6.dp))
        }
        Text("›", color = Color.White, fontSize = 20.sp)
    }
}

// ＋ 모임방 만들기 버튼 (목록 위)
@Composable
private fun CreateRoomButton(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp)
            .padding(bottom = 4.dp),
        horizontalArrangement = Arrangement.End
    ) {
        Text(
            "＋ 모임방 만들기",
            fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MoimAccent,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(MoimWhite, RoundedCornerShape(10.dp))
                .clickable(onClick = onClick)
                .padding(horizontal = 14.dp, vertical = 8.dp)
        )
    }
}

// 방 순서(핀) 설정 — 최대 5개 고정·드래그 재정렬 + 회원 탈퇴·로그아웃
@Composable
private fun PinSettingsDialog(
    vm: MoimViewModel,
    rooms: List<Room>,
    pins: List<String>,
    onSave: (List<String>) -> Unit,
    onDismiss: () -> Unit
) {
    var draft by remember { mutableStateOf(pins.filter { id -> rooms.any { it.id == id } }) }
    var showDelete by remember { mutableStateOf(false) }
    // 드래그 재정렬 상태
    var dragIndex by remember { mutableStateOf(-1) }
    var dragOffset by remember { mutableStateOf(0f) }
    var rowHeightPx by remember { mutableStateOf(1f) }

    if (showDelete) {
        AlertDialog(
            onDismissRequest = { showDelete = false },
            title = { Text("회원 탈퇴") },
            text = { Text("정말 탈퇴할까요?\n계정이 비활성화되어 다시 로그인할 수 없으며 모든 방에서 나가집니다.") },
            confirmButton = { TextButton(onClick = { showDelete = false; vm.deleteAccount() }) { Text("탈퇴", color = MoimAdmin) } },
            dismissButton = { TextButton(onClick = { showDelete = false }) { Text("취소") } }
        )
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("방 순서 설정") },
        text = {
            Column(modifier = Modifier.heightIn(max = 480.dp).verticalScroll(rememberScrollState())) {
                // 회원 탈퇴 · 로그아웃 (방 순서 위)
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                    Text("로그아웃", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MoimSub,
                        modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable { vm.logout() }.padding(horizontal = 10.dp, vertical = 6.dp))
                    Text("회원 탈퇴", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MoimAdmin,
                        modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable { showDelete = true }.padding(horizontal = 10.dp, vertical = 6.dp))
                }
                HorizontalDivider(color = MoimLine, modifier = Modifier.padding(vertical = 6.dp))
                Text("상단에 고정할 방 최대 5개. ☰ 를 길게 눌러 드래그로 순서 변경. 나머지는 새 메시지 순.", fontSize = 12.sp, color = MoimSub)
                Spacer(Modifier.height(8.dp))
                Text("고정된 방 (${draft.size}/5)", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
                if (draft.isEmpty()) Text("고정된 방 없음", fontSize = 13.sp, color = MoimSub, modifier = Modifier.padding(vertical = 4.dp))
                draft.forEachIndexed { i, id ->
                    val r = rooms.find { it.id == id } ?: return@forEachIndexed
                    val dragging = dragIndex == i
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .onSizeChanged { if (it.height > 0) rowHeightPx = it.height.toFloat() }
                            .zIndex(if (dragging) 1f else 0f)
                            .graphicsLayer { translationY = if (dragging) dragOffset else 0f }
                            .padding(vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "☰", fontSize = 16.sp, color = MoimSub,
                            modifier = Modifier
                                .padding(end = 8.dp)
                                .pointerInput(id) {
                                    detectDragGesturesAfterLongPress(
                                        onDragStart = { dragIndex = i; dragOffset = 0f },
                                        onDragEnd = { dragIndex = -1; dragOffset = 0f },
                                        onDragCancel = { dragIndex = -1; dragOffset = 0f },
                                        onDrag = { change, amount ->
                                            change.consume()
                                            dragOffset += amount.y
                                            val cur = dragIndex
                                            if (cur < 0) return@detectDragGesturesAfterLongPress
                                            if (dragOffset > rowHeightPx / 2 && cur < draft.size - 1) {
                                                val m = draft.toMutableList(); val t = m.removeAt(cur); m.add(cur + 1, t)
                                                draft = m; dragIndex = cur + 1; dragOffset -= rowHeightPx
                                            } else if (dragOffset < -rowHeightPx / 2 && cur > 0) {
                                                val m = draft.toMutableList(); val t = m.removeAt(cur); m.add(cur - 1, t)
                                                draft = m; dragIndex = cur - 1; dragOffset += rowHeightPx
                                            }
                                        }
                                    )
                                }
                        )
                        Text("${i + 1}. ${r.name}", fontSize = 14.sp, color = MoimInk, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        PinIcon("✕", MoimAdmin) { draft = draft.filter { it != id } }
                    }
                }
                Spacer(Modifier.height(10.dp))
                Text("방 목록", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
                rooms.filter { it.id !in draft }.forEach { r ->
                    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(r.name, fontSize = 14.sp, color = MoimInk, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        val enabled = draft.size < 5
                        Text(
                            "📌 고정", fontSize = 12.sp, fontWeight = FontWeight.Bold,
                            color = if (enabled) MoimAccent else MoimSub.copy(alpha = 0.4f),
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .then(if (enabled) Modifier.clickable { draft = draft + r.id } else Modifier)
                                .background(MoimBg, RoundedCornerShape(8.dp))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = { onSave(draft) }) { Text("저장", fontWeight = FontWeight.Bold) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("취소") } }
    )
}

@Composable
private fun PinIcon(t: String, color: Color = MoimAccent, onClick: () -> Unit) {
    Text(
        t, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = color,
        modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onClick).padding(horizontal = 8.dp, vertical = 4.dp)
    )
}

// 잔여 병실 현황 — 메모 형식 자유 텍스트 (편집 → 게시, 모두에게 공유)
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
                title = { Text("잔여 병실 현황", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) }
                },
                actions = {
                    if (!editing && canEditWard(vm.myProfile)) {
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
                    Text("잔여 병실 현황", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, color = MoimInk)
                }
                updatedLabel?.let {
                    Spacer(Modifier.height(4.dp))
                    Text("최종 수정: $it", fontSize = 11.sp, color = MoimSub)
                }
                Spacer(Modifier.height(14.dp))
                if (vm.wardStatus.isBlank()) {
                    EmptyBox("🛏", "작성된 내용이 없습니다", "우측 상단 ‘편집’을 눌러\n잔여 병실 현황을 작성하세요.")
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

// 모임방 설정 — 회원 내보내기 + 모임방 삭제 (생성자/관리자만)
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

    // 회원 내보내기 확인
    kickTarget?.let { uid ->
        AlertDialog(
            onDismissRequest = { kickTarget = null },
            title = { Text("회원 내보내기") },
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
                Text("참여 회원 (${memberIds.size}명)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
                Spacer(Modifier.height(8.dp))
                if (!vm.roomMembersLoaded) {
                    Text("회원 정보를 불러오는 중…", fontSize = 13.sp, color = MoimSub)
                } else if (memberIds.isEmpty()) {
                    Text("참여 구성원이 없습니다. 아래에서 초대하세요.", fontSize = 13.sp, color = MoimSub)
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

                // 구성원 초대 — 아직 참여하지 않은 승인 회원
                val candidates = vm.otherProfiles().filter { it.id !in memberIds }
                Spacer(Modifier.height(14.dp))
                HorizontalDivider(color = MoimLine)
                Spacer(Modifier.height(12.dp))
                Text("구성원 초대", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
                Spacer(Modifier.height(8.dp))
                if (candidates.isEmpty()) {
                    Text("초대할 수 있는 회원가 없습니다.", fontSize = 13.sp, color = MoimSub)
                }
                candidates.forEach { p ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("${p.name} · ${p.memberType}", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MoimInk, modifier = Modifier.weight(1f))
                        TextButton(onClick = { vm.inviteRoomMember(room.id, p.id) }) {
                            Text("초대", fontSize = 13.sp, color = catColor("work"))
                        }
                    }
                }

                if (canDeleteRoom(vm.myProfile, room)) {
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
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("닫기") } }
    )
}

// 모임방 만들기 (카톡처럼 누구나) — 이름 + 참여 회원 선택
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateRoomScreen(vm: MoimViewModel, onBack: () -> Unit) {
    var name by remember { mutableStateOf("") }
    var selected by remember { mutableStateOf(setOf<String>()) }
    var color by remember { mutableStateOf(ROOM_COLORS[1]) }
    var iconUri by remember { mutableStateOf<Uri?>(null) }
    var iconBytes by remember { mutableStateOf<ByteArray?>(null) }
    var iconName by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val iconPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) { iconUri = uri; readUri(context, uri)?.let { (n, b) -> iconName = n; iconBytes = b } }
    }
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
            RoomAppearancePicker(
                name = name, color = color, onColor = { color = it },
                iconUri = iconUri, existingIconUrl = null,
                onPickPhoto = { iconPicker.launch("image/*") },
                onClearPhoto = { iconUri = null; iconBytes = null; iconName = null }
            )
            Spacer(Modifier.height(14.dp))
            Text("참여 회원 선택", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Spacer(Modifier.height(8.dp))
            LazyColumn(modifier = Modifier.weight(1f)) {
                if (people.isEmpty()) {
                    item {
                        Text(
                            "표시할 회원가 없습니다.",
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
                    vm.createRoom(nm, selected.toList(), color, iconBytes, iconName) { onBack() }
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
