package com.example.moimtalk.ui

import android.content.Context
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.text.ClickableText
import androidx.compose.foundation.text.selection.SelectionContainer
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
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.RowScope
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
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.rememberSwipeToDismissBoxState
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.moimtalk.MoimViewModel
import com.example.moimtalk.R
import com.example.moimtalk.data.LastMsg
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Reaction
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
    var deviceType by remember { mutableStateOf("") }   // iphone | android (가입 필수)
    var deviceEmail by remember { mutableStateOf("") }  // 앱 설치용 연결 이메일
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
            colors = moimOutlinedTextFieldColors(),
            value = email,
            onValueChange = { email = it },
            label = { Text(if (signup) "이메일" else "이메일 또는 핸드폰번호") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
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
            colors = moimOutlinedTextFieldColors(),
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
            colors = moimOutlinedTextFieldColors(),
                value = name,
                onValueChange = { name = it },
                label = { Text("이름") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
                value = phone,
                onValueChange = { phone = it },
                label = { Text("핸드폰번호 (예: 010-1234-5678)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
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
            Spacer(Modifier.height(12.dp))
            Text("사용 핸드폰 종류 (필수)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Spacer(Modifier.height(6.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("iphone" to "🍎 아이폰", "android" to "🤖 안드로이드").forEach { (k, label) ->
                    val on = deviceType == k
                    Text(
                        label, fontSize = 13.sp, fontWeight = FontWeight.Bold,
                        color = if (on) Color.White else MoimInk,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .clickable { deviceType = k }
                            .background(if (on) MoimAccent else MoimWhite)
                            .padding(vertical = 10.dp)
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            Text("앱 설치용 연결 이메일 (애플ID/구글계정)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Spacer(Modifier.height(6.dp))
            OutlinedTextField(
                value = deviceEmail, onValueChange = { deviceEmail = it }, singleLine = true,
                placeholder = { Text("앱 설치용 이메일") },
                modifier = Modifier.fillMaxWidth()
            )
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
                if (signup) {
                    if (deviceType.isBlank()) { vm.error = "사용 핸드폰 종류(아이폰/안드로이드)를 선택하세요"; return@Button }
                    vm.signUp(email.trim(), pw, name.trim(), memberType, phone.trim(), intro.trim(), deviceType, deviceEmail.trim())
                } else vm.login(email.trim(), pw)
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
                if (pending > 0) "가입 승인 대기 ${pending}명" else "가입 승인 · 회원 관리",
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

// 관리자 콘솔 — 가입승인 / 회원관리. 관리자는 '가입 승인'만, 전체관리자는 둘 다.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminConsoleScreen(vm: MoimViewModel, onBack: () -> Unit) {
    val isSuper = vm.myProfile?.role == "superadmin"
    val tabs = if (isSuper) listOf("가입 승인", "회원 관리") else listOf("가입 승인")
    var tab by remember { mutableStateOf(0) }
    val collator = remember { java.text.Collator.getInstance(java.util.Locale.KOREAN) }

    LaunchedEffect(Unit) { vm.reloadProfiles() }

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
                else -> MemberManageTab(vm, collator)
            }
        }
    }
}

@Composable
private fun ApprovalTab(vm: MoimViewModel, collator: java.text.Collator) {
    var byType by remember { mutableStateOf(false) }
    // 신규 가입자(미승인 + 미탈퇴, 전체관리자 제외)
    val base = vm.profilesById.values.filter(::isSignupPending)
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
    val base = vm.profilesById.values.filter(::isApprovedMember)
    val cmp: Comparator<Profile> = if (byType) Comparator { a, b ->
        val t = collator.compare(a.memberType, b.memberType); if (t != 0) t else collator.compare(a.name, b.name)
    } else Comparator { a, b ->
        // 이름순: 관리자(admin)를 맨 위로, 그 안에서 가나다순
        val ad = (if (a.role == "admin") 0 else 1) - (if (b.role == "admin") 0 else 1)
        if (ad != 0) ad else collator.compare(a.name, b.name)
    }
    val members = base.sortedWith(cmp)
    // 비활성(탈퇴) 회원 — 복구 대상
    val withdrawn = vm.profilesById.values.filter(::isWithdrawnMember)
        .sortedWith(Comparator { a, b -> collator.compare(a.name, b.name) })
    val context = LocalContext.current
    LazyColumn(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        item {
            Text("관리자 지위 지정 / 계정 비활성화. (전체관리자 제외)", fontSize = 12.sp, color = MoimSub)
            Spacer(Modifier.height(10.dp))
            Text(
                "📥 회원 명단 엑셀 다운로드 (앱 배포용)",
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = MoimAccent,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(11.dp))
                    .border(1.dp, MoimLine, RoundedCornerShape(11.dp))
                    .background(MoimWhite)
                    .clickable { MemberCsvExport.share(context, vm.profilesById.values) }
                    .padding(11.dp),
            )
            Spacer(Modifier.height(12.dp))
            Row(modifier = Modifier.padding(bottom = 10.dp)) {
                SortChip("가나다순", !byType) { byType = false }
                Spacer(Modifier.width(8.dp))
                SortChip("직군별", byType) { byType = true }
            }
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
        if (withdrawn.isNotEmpty()) {
            item {
                Spacer(Modifier.height(16.dp))
                Text("🚫 비활성 회원 · ${withdrawn.size}명 · 복구하면 이전 대화에 다시 연결됩니다", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub, modifier = Modifier.padding(bottom = 8.dp))
            }
            items(withdrawn, key = { "w_" + it.id }) { p -> MemberWithdrawnRow(p, vm) }
        }
    }
}

@Composable
private fun SortChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold,
        color = moimToggleText(selected, Color.White),
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .background(moimToggleBg(selected, MoimAccent, MoimBg))
            .then(if (MoimTheme.dark) Modifier.border(1.dp, moimToggleBorder(selected), RoundedCornerShape(20.dp)) else Modifier)
            .padding(horizontal = 14.dp, vertical = 7.dp)
    )
}

private fun roleLabel(role: String): String = when (role) {
    "superadmin" -> "전체관리자"
    "admin" -> "관리자"
    else -> "회원"
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
            MemberContactLines(p)
        }
        Text(
            "승인", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.clip(RoundedCornerShape(20.dp)).clickable { confirmApprove = true }.background(catColor("work")).padding(horizontal = 16.dp, vertical = 7.dp)
        )
    }
}

// 회원 정보(이름·직군) 변경 다이얼로그 — 전체관리자 전용
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MemberEditDialog(p: Profile, vm: MoimViewModel, onDismiss: () -> Unit) {
    var name by remember { mutableStateOf(p.name) }
    var mtype by remember { mutableStateOf(p.memberType.ifBlank { MTYPE_ORDER.first() }) }
    var expanded by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("회원 정보 변경") },
        text = {
            Column {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("이름") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(12.dp))
                ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                    OutlinedTextField(
                        value = mtype,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("직군") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth()
                    )
                    ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                        MTYPE_ORDER.forEach { t ->
                            DropdownMenuItem(text = { Text(t) }, onClick = { mtype = t; expanded = false })
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val nm = name.trim()
                if (nm.isNotEmpty()) { vm.updateMemberInfo(p.id, nm, mtype); onDismiss() }
            }) { Text("저장", fontWeight = FontWeight.Bold) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("취소") } }
    )
}

// 회원 관리 행 — 이름·직군 수정 + 관리자 지위 토글 + 계정 비활성화 (전체관리자 전용 화면)
@Composable
private fun MemberManageRow(p: Profile, vm: MoimViewModel) {
    var confirmDeact by remember { mutableStateOf(false) }
    var showEdit by remember { mutableStateOf(false) }
    if (showEdit) MemberEditDialog(p, vm) { showEdit = false }
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
        PersonAvatar(p, 38, 11, 11.0)
        Spacer(Modifier.width(11.dp))
        Column(modifier = Modifier.weight(1f).clickable { showEdit = true }) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(p.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk)
                Spacer(Modifier.width(4.dp))
                Text("✏️", fontSize = 10.sp, color = MoimSub)
            }
            Text("${p.memberType} · ${roleLabel(p.role)}", fontSize = 11.5.sp, color = MoimSub)
            MemberContactLines(p)
            if (!p.intro.isNullOrBlank()) {
                Text(p.intro, fontSize = 11.sp, color = MoimSub, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        val isAdmin = p.role == "admin"
        Text(
            if (isAdmin) "관리자 ✓" else "관리자 지정",
            color = moimToggleText(isAdmin, Color.White, MoimAccent), fontSize = 11.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(RoundedCornerShape(20.dp))
                .clickable { vm.setRole(p.id, if (isAdmin) "user" else "admin") }
                .background(moimToggleBg(isAdmin, MoimAccent, MoimBg))
                .then(if (MoimTheme.dark) Modifier.border(1.dp, moimToggleBorder(isAdmin), RoundedCornerShape(20.dp)) else Modifier)
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

// 비활성(탈퇴) 회원 행 — 복구 버튼
@Composable
private fun MemberWithdrawnRow(p: Profile, vm: MoimViewModel) {
    var confirm by remember { mutableStateOf(false) }
    if (confirm) {
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text("계정 복구") },
            text = { Text("‘${p.name}’ 님의 계정을 복구할까요?\n로그인·활동이 다시 가능해지고 승인 상태가 됩니다.\n(이전 메시지·자료가 그대로 연결됩니다.)") },
            confirmButton = {
                TextButton(onClick = { confirm = false; vm.reactivateUser(p.id) }) {
                    Text("복구", color = catColor("work"), fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("취소") } }
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
            modifier = Modifier.size(38.dp).background(MoimSub, RoundedCornerShape(11.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(p.name.take(3), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.width(11.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(p.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Text("${p.memberType} · 비활성", fontSize = 11.5.sp, color = MoimSub)
            MemberContactLines(p)
        }
        Text(
            "복구", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.clip(RoundedCornerShape(20.dp)).clickable { confirm = true }.background(catColor("work")).padding(horizontal = 14.dp, vertical = 7.dp)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomListScreen(
    vm: MoimViewModel,
    onOpen: (Room) -> Unit,
    onWard: () -> Unit,
    onCreateRoom: () -> Unit,
    onApprovals: () -> Unit,
    onSettings: () -> Unit
) {
    val profile = vm.myProfile
    // 주간 학술활동(default_view=week)은 목록에서 빼고 별도 바로 표시. 나머지는 전체방(첫번째)+모임방 평면 목록.
    val weekRoom = vm.rooms.firstOrNull { it.category != "custom" && it.defaultView == "week" }
    // 과 전체공지 방은 항상 맨 위 고정(핀·정렬 대상에서 제외).
    val noticeRoom = noticeTopRoom(vm.rooms)
    val bugReport = bugReportRoom(vm.rooms)
    // 고정(핀) 우선 + 나머지는 최근 메시지순
    // 홈 목록: 기본 방은 항상, 모임방(custom)·1:1(direct)은 내가 가입한 것만 (관리자 콘솔은 전체 vm.rooms 사용)
    val flatRooms = vm.rooms.filter {
        it.id != weekRoom?.id && it.id != noticeRoom?.id && it.id != bugReport?.id &&
            (if (it.category == "custom" || it.category == "direct") vm.myRoomIds.contains(it.id) else true)
    }
    val pinnedRooms = vm.roomPins.mapNotNull { id -> flatRooms.find { it.id == id } }
    val pinnedIds = pinnedRooms.map { it.id }.toSet()
    // 과 전체공지는 맨 위 고정 바로 별도 표시(목록 행에서 제외). 사용자 고정(핀) → 나머지(최근 메시지순)
    val listRooms = pinnedRooms + flatRooms.filter { it.id !in pinnedIds }
        .sortedWith(compareByDescending<Room> { vm.lastMsgByRoom[it.id]?.createdAt ?: "" }.thenBy { it.sortOrder })

    // 1:1 대화(DM) 스와이프 삭제 — 확인 후 본인 참여만 제거(상대·이력 유지, 재오픈 시 복구)
    var dmToDelete by remember { mutableStateOf<Room?>(null) }
    dmToDelete?.let { dm ->
        AlertDialog(
            onDismissRequest = { dmToDelete = null },
            title = { Text("대화 삭제") },
            text = { Text("이 대화를 목록에서 삭제할까요?\n상대는 그대로이며, 다시 메시지하면 이전 대화가 복구됩니다.") },
            confirmButton = { TextButton(onClick = { val r = dm; dmToDelete = null; vm.leaveRoom(r) }) { Text("삭제", color = MoimAdmin, fontWeight = FontWeight.Bold) } },
            dismissButton = { TextButton(onClick = { dmToDelete = null }) { Text("취소") } }
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
                        color = if (MoimTheme.dark) MoimSub else MoimAccent,
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(if (MoimTheme.dark) MoimWhite else MoimYellow, RoundedCornerShape(20.dp))
                            .then(if (MoimTheme.dark) Modifier.border(1.dp, MoimLine, RoundedCornerShape(20.dp)) else Modifier)
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    )
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = { vm.loadRooms() }) { Text("↻", fontSize = 17.sp) }
                    // 관리자 진입: admin·비서='가입승인' / superadmin='관리자모드'
                    when {
                        profile?.role == "superadmin" -> TextButton(onClick = onApprovals) { Text("관리자모드", fontSize = 12.sp, color = MoimAdmin, fontWeight = FontWeight.Bold) }
                        profile?.role == "admin" || profile?.memberType == "비서" -> TextButton(onClick = onApprovals) { Text("가입승인", fontSize = 12.sp, color = MoimAdmin, fontWeight = FontWeight.Bold) }
                    }
                    // 설정(⚙️): 내 정보 / 방 순서 / 회원 검색
                    TextButton(onClick = onSettings) { Text("⚙️", fontSize = 15.sp) }
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
            item {
                RoomListTopTriBar(
                    noticeRoom = noticeRoom,
                    noticeUnread = noticeRoom?.let { vm.unreadByRoom[it.id] ?: 0 } ?: 0,
                    weekRoom = weekRoom,
                    weekUnread = weekRoom?.let { vm.unreadByRoom[it.id] ?: 0 } ?: 0,
                    onNotice = { noticeRoom?.let(onOpen) },
                    onWard = onWard,
                    onWeek = { weekRoom?.let(onOpen) },
                )
            }
            item {
                val brUnread = bugReport?.let { r ->
                    effectiveRoomUnread(r.id, vm.unreadByRoom[r.id] ?: 0, vm.myProfile?.role)
                } ?: 0
                RoomListActionRow(bugReport, brUnread, { bugReport?.let(onOpen) }, onCreateRoom)
            }
            if (listRooms.isEmpty()) {
                item { EmptyBox("🔒", "아직 방이 없어요", "전체관리자가 방에 배정하면\n여기에 표시됩니다.") }
            } else {
                items(listRooms, key = { it.id }) { room ->
                    if (room.category == "direct") {
                        val dismissState = rememberSwipeToDismissBoxState(
                            confirmValueChange = { v ->
                                if (v == SwipeToDismissBoxValue.EndToStart) dmToDelete = room
                                false  // 실제 제거는 확인 후 leaveRoom 으로 → 항상 스냅백
                            }
                        )
                        SwipeToDismissBox(
                            state = dismissState,
                            enableDismissFromStartToEnd = false,
                            backgroundContent = {
                                Box(
                                    modifier = Modifier.fillMaxSize().background(MoimAdmin).padding(end = 24.dp),
                                    contentAlignment = Alignment.CenterEnd
                                ) { Text("🗑 삭제", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp) }
                            }
                        ) {
                            Box(modifier = Modifier.fillMaxWidth().background(MoimPaper)) {
                                RoomRow(room, vm.unreadByRoom[room.id] ?: 0, vm.lastMsgByRoom[room.id], vm.profilesById, onOpen)
                            }
                        }
                    } else {
                        RoomRow(room, vm.unreadByRoom[room.id] ?: 0, vm.lastMsgByRoom[room.id], vm.profilesById, onOpen)
                    }
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
    val bg = moimToggleBg(selected, MoimAccent)
    val fg = moimToggleText(selected, Color.White, MoimInk)
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(bg)
            .then(if (MoimTheme.dark && selected) Modifier.border(1.dp, moimToggleBorder(true), RoundedCornerShape(20.dp)) else Modifier)
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
    iconBytes: ByteArray? = null,
    iconUri: Uri? = null,
    existingIconUrl: String? = null,
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
        val img: Any? = iconBytes ?: iconUri ?: existingIconUrl
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

/** 사람(프로필) 아바타: 사진 > 색상 > 직군색 (사진 없으면 이름 앞 3글자) */
@Composable
fun PersonAvatar(profile: Profile?, sizeDp: Int, cornerDp: Int, fontSp: Double) {
    val shape = RoundedCornerShape(cornerDp.dp)
    val avatarUrl = profile?.avatarUrl
    if (profile != null && !avatarUrl.isNullOrBlank()) {
        AsyncImage(
            model = avatarUrl,
            contentDescription = profile.name,
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(sizeDp.dp).clip(shape)
        )
    } else {
        Box(
            modifier = Modifier.size(sizeDp.dp).background(personColor(profile), shape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                (profile?.name ?: "?").take(3), color = Color.White, fontWeight = FontWeight.Bold,
                fontSize = fontSp.sp, textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
fun RoomRow(
    room: Room,
    unread: Int = 0,
    lastMsg: LastMsg? = null,
    profiles: Map<String, Profile> = emptyMap(),
    onOpen: (Room) -> Unit,
) {
    val isDM = room.category == "direct"
    val other = if (isDM) dmOther(room, profiles) else null
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onOpen(room) }
            .padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (isDM) PersonAvatar(other, 48, 16, 13.0) else RoomAvatar(room, 48, 16, 10.5)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    catLabel(room.category),
                    fontSize = 9.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = Color.White,
                    modifier = Modifier
                        .background(if (isDM) Color(0xFF7A8A99) else catColor(room.category), RoundedCornerShape(5.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                )
                Text(roomDisplayName(room, profiles), fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MoimInk)
            }
            val desc = msgPreview(lastMsg).ifBlank {
                when {
                    isDM -> other?.memberType.orEmpty()
                    room.postPolicy == "restricted" -> "공지 · 관리자"
                    else -> ""
                }
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
    // 주간 학술활동(default_view=week) 방은 열자마자 캘린더(주간) 탭으로
    var tab by remember(liveRoom.id) {
        mutableStateOf(
            when {
                isNoticeTopRoom(liveRoom, vm.rooms) -> "chat"
                opensWeekCalendar(liveRoom) -> "cal"
                else -> "chat"
            },
        )
    }
    var input by remember(liveRoom.id) { mutableStateOf("") }
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
    var pendingIconAdjustUri by remember { mutableStateOf<Uri?>(null) }
    val iconPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) pendingIconAdjustUri = uri
    }
    var showSettings by remember { mutableStateOf(false) }
    var showLeave by remember { mutableStateOf(false) }
    var showDeleteRoom by remember { mutableStateOf(false) }
    val profile = vm.myProfile
    val canPost = canPostInRoom(profile, room)
    // 1:1 DM 은 채팅 전용 (캘린더·자료실 탭, 이름변경·설정 숨김). 제목=상대 이름. 방삭제=목록에서 제거.
    val dm = isDirect(liveRoom)
    val titleName = roomDisplayName(liveRoom, vm.profilesById)
    val noticeCompose = isNoticeTopRoom(liveRoom, vm.rooms)
    val bugReportCompose = isBugReportRoom(liveRoom)
    val multilineCompose = noticeCompose || bugReportCompose

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

    if (showDeleteRoom) {
        AlertDialog(
            onDismissRequest = { showDeleteRoom = false },
            title = { Text("대화 삭제") },
            text = { Text("이 대화를 목록에서 삭제할까요?\n상대는 그대로이며, 다시 메시지하면 이전 대화가 복구됩니다.") },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteRoom = false
                    vm.leaveRoom(liveRoom) { onBack() }
                }) { Text("삭제", color = MoimAdmin, fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { showDeleteRoom = false }) { Text("취소") } }
        )
    }

    // 채팅 첨부(path) → 서명 URL 해석 (방 구성원만)
    LaunchedEffect(vm.messages) { vm.resolveAttachments() }

    // 상단 바에 개설자·참여자 이름을 나열하기 위해 방 구성원 로드 (DM 제외)
    LaunchedEffect(liveRoom.id) {
        if (!dm && showRoomHeaderMembers(liveRoom, vm.rooms)) vm.loadRoomMembers(liveRoom.id)
        tab = when {
            isNoticeTopRoom(liveRoom, vm.rooms) -> "chat"
            opensWeekCalendar(liveRoom) -> "cal"
            else -> "chat"
        }
        input = if (bugReportCompose) {
            if (vm.replyTarget != null) "" else bugReportDraftFor(profile?.role)
        } else ""
    }

    // BugReport 답장 작성 중에는 환경 템플릿 숨김, 답장 취소 시 복원
    LaunchedEffect(vm.replyTarget, bugReportCompose, profile?.role) {
        if (bugReportCompose) {
            input = if (vm.replyTarget != null) "" else bugReportDraftFor(profile?.role)
        }
    }

    if (showSettings) {
        RoomSettingsDialog(
            vm = vm,
            room = liveRoom,
            onDismiss = { showSettings = false },
            onDeleted = { showSettings = false; onBack() }
        )
    }

    pendingIconAdjustUri?.let { uri ->
        AvatarAdjustDialog(
            sourceUri = uri,
            onDismiss = { pendingIconAdjustUri = null },
            onConfirm = { bytes, name ->
                editIconBytes = bytes
                editIconName = name
                editIconUri = null
                editIconCleared = false
                pendingIconAdjustUri = null
            },
        )
    }

    if (showRename) {
        AlertDialog(
            onDismissRequest = { showRename = false },
            title = { Text("방 정보 변경") },
            text = {
                Column {
                    OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
                        value = renameText,
                        onValueChange = { renameText = it },
                        singleLine = true,
                        label = { Text("방 이름") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(14.dp))
                    RoomAppearancePicker(
                        name = renameText, color = editColor, onColor = { editColor = it },
                        iconBytes = editIconBytes,
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
                // 웹 .hdr 와 동일: 뒤로 · 방이름+구성원(ellipsis) · 액션 버튼
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 4.dp, end = 8.dp, top = 10.dp, bottom = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    TextButton(onClick = onBack, contentPadding = PaddingValues(horizontal = 8.dp)) {
                        Text("‹", fontSize = 25.sp)
                    }
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxWidth(),
                    ) {
                        Text(
                            titleName,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        // 개설자·참여자 이름 나열 (모임방 등 — DM·과 전체공지 제외)
                        if (!dm && showRoomHeaderMembers(liveRoom, vm.rooms) && vm.memberListRoomId == liveRoom.id) {
                            val memberLine = roomMemberNames(liveRoom, vm.roomMemberIds, vm.profilesById).joinToString(", ")
                            if (memberLine.isNotBlank()) {
                                Text(
                                    memberLine,
                                    fontSize = 11.sp,
                                    color = MoimSub,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                        }
                    }
                    if (!dm && canRenameRoom(profile, liveRoom)) {
                        TextButton(
                            onClick = {
                                renameText = liveRoom.name
                                editColor = liveRoom.color ?: ROOM_COLORS[1]
                                editIconUri = null; editIconBytes = null; editIconName = null; editIconCleared = false
                                showRename = true
                            },
                            contentPadding = PaddingValues(horizontal = 6.dp),
                        ) { Text("이름변경", fontSize = 13.sp, color = MoimAccent, fontWeight = FontWeight.Bold) }
                    }
                    if (!dm && canManageRoom(profile, liveRoom)) {
                        TextButton(
                            onClick = {
                                vm.loadRoomMembers(liveRoom.id)
                                showSettings = true
                            },
                            contentPadding = PaddingValues(horizontal = 6.dp),
                        ) { Text("⚙️", fontSize = 17.sp) }
                    }
                    if (!dm && canLeaveRoom(profile, liveRoom)) {
                        TextButton(onClick = { showLeave = true }, contentPadding = PaddingValues(horizontal = 6.dp)) {
                            Text("나가기", fontSize = 13.sp, color = MoimAdmin)
                        }
                    }
                    if (dm) {
                        TextButton(onClick = { showDeleteRoom = true }, contentPadding = PaddingValues(horizontal = 6.dp)) {
                            Text("방삭제", fontSize = 13.sp, color = MoimAdmin, fontWeight = FontWeight.Bold)
                        }
                    }
                }
                val showSubTabs = room.category != "custom" && !dm && !isNoticeTopRoom(liveRoom, vm.rooms) && !isBugReportRoom(liveRoom)
                if (showSubTabs) {
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
                                        .background(
                                            if (on) (if (MoimTheme.dark) MoimSub else MoimYellow)
                                            else Color.Transparent,
                                        )
                                )
                            }
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
                        // 답장 대상 미리보기 (✕로 취소)
                        vm.replyTarget?.let { rt ->
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 7.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text("↩ ${vm.nameOf(rt.senderId)} 에게 답장", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = MoimAccent)
                                    Text(
                                        rt.content?.takeIf { it.isNotBlank() } ?: when (rt.type) { "image" -> "사진" "file" -> "파일" else -> "" },
                                        fontSize = 12.sp, color = MoimSub, maxLines = 1, overflow = TextOverflow.Ellipsis
                                    )
                                }
                                Text(
                                    "✕", fontSize = 15.sp, color = MoimAdmin, fontWeight = FontWeight.Bold,
                                    modifier = Modifier.clickable { vm.setReply(null) }.padding(horizontal = 6.dp)
                                )
                            }
                        }
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
                        verticalAlignment = Alignment.Bottom,
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
            colors = moimOutlinedTextFieldColors(),
                            value = input,
                            onValueChange = { input = it },
                            modifier = Modifier
                                .weight(1f)
                                .then(
                                    if (multilineCompose) Modifier.heightIn(min = 88.dp, max = 160.dp)
                                    else Modifier,
                                ),
                            placeholder = {
                                Text(
                                    when {
                                        noticeCompose -> "공지 내용 입력 (줄바꿈 가능)"
                                        bugReportCompose -> if (isSuperAdmin(profile?.role.orEmpty())) {
                                            "메시지 입력"
                                        } else {
                                            "버그·제안 내용 입력 (아래 템플릿 참고)"
                                        }
                                        else -> "메시지 입력"
                                    },
                                )
                            },
                            singleLine = false,   // web 처럼 Enter=줄바꿈, 전송은 ↑ 버튼
                            minLines = if (multilineCompose) 3 else 1,
                            maxLines = 8,
                            shape = if (multilineCompose) RoundedCornerShape(14.dp) else RoundedCornerShape(20.dp),
                        )
                        Spacer(Modifier.width(8.dp))
                        Box(
                            modifier = Modifier
                                .size(33.dp)
                                .background(MoimYellow, CircleShape)
                                .clickable {
                                    val text = input.trim()
                                    pendingAttach?.let { (n, b, k) ->
                                        vm.sendAttachment(n, b, k, caption = text.ifBlank { null })
                                        pendingAttach = null
                                        input = ""
                                    } ?: run {
                                        if (text.isNotBlank()) {
                                            vm.send(text)
                                            input = ""
                                        }
                                    }
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            Text("↑", fontSize = 19.sp, fontWeight = FontWeight.Bold)
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
                            "🔒 공지 전용 방 · 관리자만 글을 쓸 수 있어요",
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
                unreadOf = { m ->
                    effectiveMsgUnread(liveRoom.id, vm.unreadByMsg[m.id] ?: 0, vm.myProfile?.role)
                },
                profileOf = { vm.profilesById[it] },
                noticeLayout = isNoticeTopRoom(liveRoom, vm.rooms),
                reactions = vm.reactions,
                myUserId = vm.myProfile?.id ?: "",
                onReact = { m, e -> vm.toggleReaction(m.id, e) },
                onReply = { vm.setReply(it) },
                messageById = { id -> vm.messages.firstOrNull { it.id == id } },
            )
            "files" -> FilesPane(
                vm = vm,
                canUpload = canPost,
                modifier = Modifier.padding(pad)
            )
            else -> CalendarPane(
                vm = vm,
                room = liveRoom,
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
    unreadOf: (Message) -> Int,
    profileOf: (String) -> Profile? = { null },
    noticeLayout: Boolean = false,
    reactions: List<Reaction> = emptyList(),
    myUserId: String = "",
    onReact: (Message, String) -> Unit = { _, _ -> },
    onReply: (Message) -> Unit = {},
    messageById: (String) -> Message? = { null },
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
        } else if (noticeLayout) {
            mergeNoticeMessages(messages).forEach { m ->
                item(key = m.id) {
                    NoticePostCard(
                        m = m,
                        senderName = nameOf(m.senderId),
                        sender = profileOf(m.senderId),
                        mine = isMine(m),
                        attachUrl = attachUrl,
                        onDelete = { deleteTarget = m },
                        reactions = reactions.filter { it.messageId == m.id },
                        myUserId = myUserId,
                        onReact = { e -> onReact(m, e) },
                    )
                }
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
                    MessageBubble(
                        m, isMine(m), nameOf(m.senderId), attachUrl,
                        onDelete = { deleteTarget = m }, unread = unreadOf(m), sender = profileOf(m.senderId),
                        reactions = reactions.filter { it.messageId == m.id },
                        myUserId = myUserId,
                        onReact = { e -> onReact(m, e) },
                        onReply = { onReply(m) },
                        repliedMessage = m.replyTo?.let { messageById(it) },
                        repliedName = m.replyTo?.let { messageById(it) }?.let { nameOf(it.senderId) },
                    )
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

private val NOTICE_ACCENT = Color(0xFFB5651D)

private fun noticeCopyText(m: Message): String? =
    m.content?.trim()?.takeIf { it.isNotEmpty() }

@Composable
private fun NoticeBodyText(text: String) {
    val uriHandler = LocalUriHandler.current
    val annotated = remember(text) { linkifyAnnotatedString(text) }
    SelectionContainer {
        ClickableText(
            text = annotated,
            style = TextStyle(color = MoimInk, fontSize = 15.sp, lineHeight = 24.sp),
            onClick = { offset ->
                annotated.getLinkAnnotations(offset, offset)
                    .firstOrNull()?.item
                    ?.let { link -> (link as? LinkAnnotation.Url)?.url?.let { uriHandler.openUri(it) } }
            },
        )
    }
}

@Composable
private fun ReactionChipsRow(
    reactions: List<Reaction>,
    myUserId: String,
    onReact: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (reactions.isEmpty()) return
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        reactions.groupBy { it.emoji }.forEach { (emoji, list) ->
            val mineReacted = list.any { it.userId == myUserId }
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (mineReacted) MoimAccent.copy(alpha = 0.20f) else MoimBg)
                    .clickable { onReact(emoji) }
                    .padding(horizontal = 7.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(emoji, fontSize = 12.sp)
                if (list.size > 1) {
                    Spacer(Modifier.width(3.dp))
                    Text("${list.size}", fontSize = 11.sp, color = MoimSub)
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun NoticePostCard(
    m: Message,
    senderName: String,
    sender: Profile?,
    mine: Boolean,
    attachUrl: (String) -> String?,
    onDelete: () -> Unit,
    reactions: List<Reaction> = emptyList(),
    myUserId: String = "",
    onReact: (String) -> Unit = {},
) {
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current
    val clipboard = LocalClipboardManager.current
    val path = m.attachmentUrl
    val resolved = path?.let { p -> attachUrl(p) ?: if (p.startsWith("http")) p else null }
    val caption = noticeCopyText(m)
    var actionMenuOpen by remember(m.id) { mutableStateOf(false) }
    val authorLine = buildString {
        append(senderName)
        sender?.memberType?.takeIf { it.isNotBlank() }?.let { append(" · $it") }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.94f)
                .shadow(3.dp, RoundedCornerShape(16.dp), ambientColor = Color.Black.copy(alpha = 0.08f))
                .clip(RoundedCornerShape(16.dp))
                .background(MoimWhite)
                .border(1.dp, MoimLine, RoundedCornerShape(16.dp))
                .combinedClickable(onClick = {}, onLongClick = { actionMenuOpen = true })
                .padding(horizontal = 20.dp, vertical = 18.dp),
        ) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(3.dp)
                    .background(NOTICE_ACCENT, RoundedCornerShape(2.dp)),
            )
            Spacer(Modifier.height(14.dp))
            Text(
                fmtPublishTime(m.createdAt),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = MoimInk,
                lineHeight = 28.sp,
            )
            Text(authorLine, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MoimSub, modifier = Modifier.padding(top = 6.dp))
            Spacer(Modifier.height(14.dp))
            HorizontalDivider(color = MoimLine)
            Spacer(Modifier.height(14.dp))
            if (caption != null) {
                NoticeBodyText(caption)
            }
            when {
                m.type == "image" && path != null -> {
                    if (caption != null) Spacer(Modifier.height(12.dp))
                    AsyncImage(
                        model = resolved,
                        contentDescription = "사진",
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 320.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(MoimBg, RoundedCornerShape(12.dp))
                            .clickable { resolved?.let { uriHandler.openUri(it) } },
                        contentScale = ContentScale.Fit,
                    )
                }
                m.type == "file" && path != null -> {
                    if (caption != null) Spacer(Modifier.height(12.dp))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(10.dp))
                            .background(MoimPaper)
                            .border(1.dp, MoimLine, RoundedCornerShape(10.dp))
                            .clickable { resolved?.let { uriHandler.openUri(it) } }
                            .padding(horizontal = 12.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text("📎", fontSize = 16.sp)
                        Text(
                            m.attachmentName ?: "파일",
                            color = MoimInk,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
                caption == null -> NoticeBodyText(m.content.orEmpty())
            }
            ReactionChipsRow(
                reactions = reactions,
                myUserId = myUserId,
                onReact = onReact,
                modifier = Modifier.padding(top = 6.dp),
            )
            Row(
                modifier = Modifier.align(Alignment.End).padding(top = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                caption?.let { txt ->
                    Text(
                        "📋 복사", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimAccent,
                        modifier = Modifier.clickable {
                            clipboard.setText(AnnotatedString(txt))
                            Toast.makeText(context, "복사되었습니다", Toast.LENGTH_SHORT).show()
                        },
                    )
                }
                if (mine) {
                    Text(
                        "🗑 삭제", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimAdmin,
                        modifier = Modifier.clickable { onDelete() },
                    )
                }
            }
        }
            DropdownMenu(expanded = actionMenuOpen, onDismissRequest = { actionMenuOpen = false }) {
                Row(modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)) {
                    REACTION_EMOJIS.forEach { e ->
                        Text(
                            e, fontSize = 20.sp,
                            modifier = Modifier
                                .clip(CircleShape)
                                .clickable { onReact(e); actionMenuOpen = false }
                                .padding(6.dp),
                        )
                    }
                }
                if (caption != null) {
                    HorizontalDivider()
                    DropdownMenuItem(
                        text = { Text("복사") },
                        onClick = {
                            clipboard.setText(AnnotatedString(caption))
                            Toast.makeText(context, "복사되었습니다", Toast.LENGTH_SHORT).show()
                            actionMenuOpen = false
                        },
                    )
                }
            }
        }
    }
}

// 카톡식 빠른 리액션 이모지
val REACTION_EMOJIS = listOf("👍", "❤️", "😂", "😮", "😢", "👏")

private fun replyQuotePreview(msg: Message): String =
    msg.content?.takeIf { it.isNotBlank() }
        ?: when (msg.type) { "image" -> "사진" "file" -> "파일" else -> "" }

@Composable
private fun ReplyQuoteInBubble(
    repliedMessage: Message,
    repliedName: String?,
    mine: Boolean,
) {
    val nameColor = if (mine) Color.White.copy(alpha = 0.92f) else MoimSub
    val bodyColor = if (mine) Color.White.copy(alpha = 0.78f) else MoimSub
    val dividerColor = if (mine) Color.White.copy(alpha = 0.32f) else MoimLine
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            "${repliedName ?: "상대"}에게",
            fontSize = 10.5.sp,
            fontWeight = FontWeight.SemiBold,
            color = nameColor,
        )
        Text(
            replyQuotePreview(repliedMessage),
            fontSize = 11.sp,
            color = bodyColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(6.dp))
        HorizontalDivider(color = dividerColor, thickness = 1.dp)
    }
}

// 긴 메시지: 이 길이 초과 시 말풍선에서 잘라 보여주고 '전체보기'로 전문 표시 (web 과 동일)
private const val MSG_TRUNC = 400

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageBubble(
    m: Message, mine: Boolean, senderName: String,
    attachUrl: (String) -> String? = { null }, onDelete: () -> Unit = {}, unread: Int = 0,
    sender: Profile? = null,
    reactions: List<Reaction> = emptyList(),
    myUserId: String = "",
    onReact: (String) -> Unit = {},
    onReply: () -> Unit = {},
    repliedMessage: Message? = null,
    repliedName: String? = null,
) {
    // 텍스트 메시지 길게 누르기 → 카톡식 메뉴(복사·답장 + 이모지 리액션)
    var copyMenuOpen by remember(m.id) { mutableStateOf(false) }
    var showFullMsg by remember(m.id) { mutableStateOf(false) }   // 긴 메시지 전체보기
    val clipboard = LocalClipboardManager.current
    if (showFullMsg) {
        AlertDialog(
            onDismissRequest = { showFullMsg = false },
            confirmButton = {
                TextButton(onClick = {
                    clipboard.setText(AnnotatedString(m.content.orEmpty())); showFullMsg = false
                }) { Text("복사") }
            },
            dismissButton = { TextButton(onClick = { showFullMsg = false }) { Text("닫기") } },
            title = { Text("전체 내용") },
            text = {
                Box(modifier = Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState())) {
                    Text(m.content.orEmpty(), fontSize = 15.sp, lineHeight = 22.sp)
                }
            },
        )
    }
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
            // 보낸이 썸네일: 사진 있으면 사진, 없으면 색/이니셜
            PersonAvatar(sender ?: Profile(id = m.senderId, name = senderName, memberType = "", role = "user"), 36, 13, 13.0)
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
        val bg = if (mine) MoimAccent else MoimYouBubble // 내=파랑, 상대=채팅배경과 구분되는 밝은 톤
        val bubbleTextColor = if (mine) Color.White else MoimInk
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
                m.type == "image" && path != null -> Column(
                    modifier = Modifier.widthIn(max = 220.dp),
                    horizontalAlignment = if (mine) Alignment.End else Alignment.Start,
                ) {
                    if (repliedMessage != null) {
                        Box(
                            modifier = Modifier
                                .widthIn(max = 225.dp)
                                .background(bg, shape)
                                .padding(horizontal = 12.dp, vertical = 9.dp),
                        ) {
                            ReplyQuoteInBubble(repliedMessage, repliedName, mine)
                        }
                        Spacer(Modifier.height(4.dp))
                    }
                    AsyncImage(
                        model = resolved,
                        contentDescription = "사진",
                        modifier = Modifier
                            .widthIn(max = 220.dp)
                            .heightIn(max = 260.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(MoimBg, RoundedCornerShape(14.dp))
                            .clickable { resolved?.let { uriHandler.openUri(it) } },
                        contentScale = ContentScale.Fit,
                    )
                }
                m.type == "file" && path != null -> Column(
                    modifier = Modifier.widthIn(max = 225.dp),
                    horizontalAlignment = if (mine) Alignment.End else Alignment.Start,
                ) {
                    if (repliedMessage != null) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(shape)
                                .background(bg, shape)
                                .padding(horizontal = 12.dp, vertical = 9.dp),
                        ) {
                            ReplyQuoteInBubble(repliedMessage, repliedName, mine)
                        }
                        Spacer(Modifier.height(4.dp))
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(shape)
                            .background(if (mine) MoimAccent else MoimYouBubble, shape)
                            .clickable { resolved?.let { uriHandler.openUri(it) } }
                            .padding(horizontal = 12.dp, vertical = 11.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("📎", fontSize = 16.sp)
                        Spacer(Modifier.width(7.dp))
                        Text(
                            m.attachmentName ?: "파일", color = bubbleTextColor, fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                else -> Box {
                    Box(
                        modifier = Modifier
                            .widthIn(max = 225.dp)
                            .background(bg, shape)
                            .combinedClickable(onClick = {}, onLongClick = { copyMenuOpen = true })
                            .padding(horizontal = 12.dp, vertical = 9.dp),
                    ) {
                        Column {
                            if (repliedMessage != null) {
                                ReplyQuoteInBubble(repliedMessage, repliedName, mine)
                                Spacer(Modifier.height(6.dp))
                            }
                            val fullText = m.content.orEmpty()
                            val isLong = fullText.length > MSG_TRUNC
                            Text(
                                if (isLong) fullText.take(MSG_TRUNC) + "…" else fullText,
                                color = bubbleTextColor, fontSize = 14.5.sp, lineHeight = 20.sp,
                            )
                            if (isLong) {
                                Text(
                                    "전체보기", color = if (mine) Color.White else MoimAccent,
                                    fontSize = 12.sp, fontWeight = FontWeight.Bold,
                                    textDecoration = TextDecoration.Underline,
                                    modifier = Modifier
                                        .padding(top = 4.dp)
                                        .clickable { showFullMsg = true },
                                )
                            }
                        }
                    }
                    DropdownMenu(expanded = copyMenuOpen, onDismissRequest = { copyMenuOpen = false }) {
                        Row(modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)) {
                            REACTION_EMOJIS.forEach { e ->
                                Text(
                                    e, fontSize = 20.sp,
                                    modifier = Modifier
                                        .clip(CircleShape)
                                        .clickable { onReact(e); copyMenuOpen = false }
                                        .padding(6.dp),
                                )
                            }
                        }
                        HorizontalDivider()
                        DropdownMenuItem(
                            text = { Text("복사") },
                            onClick = {
                                clipboard.setText(AnnotatedString(m.content.orEmpty()))
                                copyMenuOpen = false
                            },
                        )
                        DropdownMenuItem(
                            text = { Text("답장") },
                            onClick = { onReply(); copyMenuOpen = false },
                        )
                    }
                }
            }
            ReactionChipsRow(
                reactions = reactions,
                myUserId = myUserId,
                onReact = onReact,
                modifier = Modifier.padding(top = 3.dp),
            )
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

/** 방목록 상단 — 전체공지 · 병실현황 · 학술활동 한 줄 3분할 */
@Composable
private fun RoomListTopTriBar(
    noticeRoom: Room?,
    noticeUnread: Int,
    weekRoom: Room?,
    weekUnread: Int,
    onNotice: () -> Unit,
    onWard: () -> Unit,
    onWeek: () -> Unit,
) {
    if (MoimTheme.dark) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .padding(bottom = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            RoomListTriSegPill("전체공지", noticeUnread, noticeRoom != null, onNotice)
            RoomListTriSegPill("병실현황", 0, true, onWard)
            RoomListTriSegPill("학술활동", weekUnread, weekRoom != null, onWeek)
        }
    } else {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp)
                .padding(bottom = 10.dp)
                .height(IntrinsicSize.Min)
                .clip(RoundedCornerShape(14.dp)),
        ) {
            RoomListTriSegment("전체공지", Color(0xFFB5651D), noticeUnread, noticeRoom != null, onNotice, start = true)
            Box(Modifier.fillMaxHeight().width(1.dp).background(Color.White.copy(alpha = 0.28f)))
            RoomListTriSegment("병실현황", Color(0xFFEA7317), 0, true, onWard)
            Box(Modifier.fillMaxHeight().width(1.dp).background(Color.White.copy(alpha = 0.28f)))
            RoomListTriSegment("학술활동", Color(0xFF4A6FA5), weekUnread, weekRoom != null, onWeek, end = true)
        }
    }
}

/** 다크 모드 — 병실현황 잔여병실·당직표 세그먼트와 동일 스타일 */
@Composable
private fun RowScope.RoomListTriSegPill(
    label: String, unread: Int, enabled: Boolean, onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .weight(1f)
            .clip(RoundedCornerShape(10.dp))
            .background(MoimWhite.copy(alpha = if (enabled) 1f else 0.45f), RoundedCornerShape(10.dp))
            .border(1.dp, MoimLine, RoundedCornerShape(10.dp))
            .then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 10.dp, horizontal = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            color = if (enabled) MoimInk else MoimInk.copy(alpha = 0.45f),
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            textAlign = TextAlign.Center,
        )
        if (unread > 0) {
            Box(modifier = Modifier.align(Alignment.TopEnd).padding(end = 4.dp, top = 2.dp)) {
                UnreadBadge(unread)
            }
        }
    }
}

@Composable
private fun RowScope.RoomListTriSegment(
    label: String, bg: Color, unread: Int, enabled: Boolean, onClick: () -> Unit,
    start: Boolean = false, end: Boolean = false,
) {
    val shape = when {
        start -> RoundedCornerShape(topStart = 14.dp, bottomStart = 14.dp)
        end -> RoundedCornerShape(topEnd = 14.dp, bottomEnd = 14.dp)
        else -> RoundedCornerShape(0.dp)
    }
    Box(
        modifier = Modifier
            .weight(1f)
            .fillMaxHeight()
            .background(bg.copy(alpha = if (enabled) 1f else 0.45f), shape)
            .then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 12.dp, horizontal = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            color = if (enabled) MoimInk else MoimInk.copy(alpha = 0.45f),
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            textAlign = TextAlign.Center,
        )
        if (unread > 0) {
            Box(modifier = Modifier.align(Alignment.TopEnd).padding(end = 4.dp, top = 2.dp)) {
                UnreadBadge(unread)
            }
        }
    }
}

// BugReport(왼쪽) + 모임방 만들기(오른쪽) — 동일 크기 버튼
@Composable
private fun RoomListActionRow(
    bugReport: Room?, bugReportUnread: Int, onBugReport: () -> Unit, onCreateRoom: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp)
            .padding(bottom = 4.dp),
        horizontalArrangement = if (bugReport != null) Arrangement.spacedBy(10.dp) else Arrangement.End,
    ) {
        if (bugReport != null) {
            Box(Modifier.weight(1f)) {
                RoomListActionChip("BugReport", onBugReport, Modifier.fillMaxWidth(), accent = MoimAdmin)
                if (bugReportUnread > 0) {
                    Box(Modifier.align(Alignment.TopEnd).padding(top = 2.dp, end = 6.dp)) {
                        UnreadBadge(bugReportUnread)
                    }
                }
            }
            RoomListActionChip("＋ 모임방 만들기", onCreateRoom, Modifier.weight(1f))
        } else {
            RoomListActionChip("＋ 모임방 만들기", onCreateRoom)
        }
    }
}

@Composable
private fun RoomListActionChip(
    label: String, onClick: () -> Unit, modifier: Modifier = Modifier,
    accent: Color = MoimAccent, fill: Color? = null,
) {
    val bg = fill ?: MoimWhite
    val fg = if (fill != null) Color.White else accent
    Text(
        label,
        fontSize = 13.sp, fontWeight = FontWeight.Bold, color = fg,
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(bg, RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        textAlign = TextAlign.Center,
    )
}

// =====================================================================
//  설정 화면 — 내 정보 / 방 순서 / 회원 검색 (방목록 ⚙️로 진입)
// =====================================================================
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: MoimViewModel, onBack: () -> Unit, onOpenRoom: (Room) -> Unit) {
    val tabs = listOf("내 정보", "방 순서", "회원 검색")
    var tab by remember { mutableStateOf(0) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("설정", fontWeight = FontWeight.Bold) },
                navigationIcon = { TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MoimPaper)
            )
        },
        containerColor = MoimPaper
    ) { pad ->
        Column(modifier = Modifier.padding(pad).fillMaxSize()) {
            Row(modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 4.dp)) {
                tabs.forEachIndexed { i, t ->
                    SortChip(t, tab == i) { tab = i }
                    if (i < tabs.lastIndex) Spacer(Modifier.width(8.dp))
                }
            }
            when (tab) {
                0 -> MyInfoTab(vm)
                1 -> OrderTab(vm)
                else -> MemberSearchTab(vm, onOpenRoom)
            }
        }
    }
}

// ── 내 정보 변경 (이름·이메일·전화번호 읽기전용 / 직군·자기소개·아바타 변경 + 회원 탈퇴) ──
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MyInfoTab(vm: MoimViewModel) {
    val me = vm.myProfile
    val context = LocalContext.current
    var intro by remember(me?.id) { mutableStateOf(me?.intro ?: "") }
    var memberType by remember(me?.id) { mutableStateOf(me?.memberType ?: "의국") }
    var color by remember(me?.id) { mutableStateOf(me?.color ?: "") }
    var deviceType by remember(me?.id) { mutableStateOf(me?.deviceType ?: "") }       // iphone | android
    var deviceEmail by remember(me?.id) { mutableStateOf(me?.deviceEmail ?: "") }     // 앱 설치용 이메일
    var memberTypeExpanded by remember { mutableStateOf(false) }
    var avatarBytes by remember(me?.id) { mutableStateOf<ByteArray?>(null) }
    var avatarName by remember(me?.id) { mutableStateOf<String?>(null) }
    var clearAvatar by remember(me?.id) { mutableStateOf(false) }
    var pendingAdjustUri by remember { mutableStateOf<Uri?>(null) }
    var pw by remember { mutableStateOf("") }
    var pw2 by remember { mutableStateOf("") }
    var pwMsg by remember { mutableStateOf<Pair<Boolean, String>?>(null) }   // (성공 여부, 메시지)
    var savedMsg by remember { mutableStateOf(false) }
    var showDelete by remember { mutableStateOf(false) }
    val avatarPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) pendingAdjustUri = uri
    }
    val isSuper = (MoimRepository.currentUserEmail() ?: "").equals("jsnoh@ajou.ac.kr", ignoreCase = true)

    pendingAdjustUri?.let { uri ->
        AvatarAdjustDialog(
            sourceUri = uri,
            onDismiss = { pendingAdjustUri = null },
            onConfirm = { bytes, name ->
                avatarBytes = bytes
                avatarName = name
                clearAvatar = false
                pendingAdjustUri = null
            },
        )
    }

    if (showDelete) {
        AlertDialog(
            onDismissRequest = { showDelete = false },
            title = { Text("회원 탈퇴") },
            text = { Text("정말 탈퇴할까요?\n계정이 비활성화되어 다시 로그인할 수 없으며 모든 방에서 나가집니다.") },
            confirmButton = { TextButton(onClick = { showDelete = false; vm.deleteAccount() }) { Text("탈퇴", color = MoimAdmin) } },
            dismissButton = { TextButton(onClick = { showDelete = false }) { Text("취소") } }
        )
    }

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)
    ) {
        // 화면 테마 (🌙 다크 / ☀️ 라이트) 전환
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(MoimWhite, RoundedCornerShape(12.dp))
                .padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(if (MoimTheme.dark) "🌙 화면 테마" else "☀️ 화면 테마", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk, modifier = Modifier.weight(1f))
            Text(
                if (MoimTheme.dark) "다크 모드 · 전환" else "라이트 모드 · 전환",
                fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimAccent,
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .clickable { MoimTheme.dark = !MoimTheme.dark }
                    .background(MoimBg, RoundedCornerShape(20.dp))
                    .padding(horizontal = 14.dp, vertical = 7.dp)
            )
        }
        Spacer(Modifier.height(14.dp))
        // 아바타 미리보기 + 사진 선택/제거 + 색상 팔레트
        Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            val shape = RoundedCornerShape(26.dp)
            val img: Any? = avatarBytes ?: (if (clearAvatar) null else me?.avatarUrl)
            if (img != null) {
                AsyncImage(model = img, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(84.dp).clip(shape))
            } else {
                Box(modifier = Modifier.size(84.dp).background(parseHexColor(color) ?: personColor(me), shape), contentAlignment = Alignment.Center) {
                    Text((me?.name ?: "?").take(3), color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
                }
            }
            Spacer(Modifier.height(9.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TextButton(onClick = { avatarPicker.launch("image/*") }) { Text("사진 선택") }
                if (img != null) TextButton(onClick = { avatarBytes = null; avatarName = null; clearAvatar = true }) {
                    Text("사진 제거", color = MoimAdmin)
                }
            }
            Spacer(Modifier.height(6.dp))
            ColorSwatchRow(color) { color = it }
        }
        Spacer(Modifier.height(16.dp))
        Text("이름 (변경 불가)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        OutlinedTextField(
            value = me?.name ?: "", onValueChange = {}, enabled = false, singleLine = true, modifier = Modifier.fillMaxWidth(), colors = moimOutlinedTextFieldColors())
        Spacer(Modifier.height(10.dp))
        Text("이메일 (변경 불가)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
            value = MoimRepository.currentUserEmail() ?: "",
            onValueChange = {},
            enabled = false,
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(10.dp))
        Text("전화번호 (변경 불가)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        OutlinedTextField(
            value = me?.phone ?: "", onValueChange = {}, enabled = false, singleLine = true, modifier = Modifier.fillMaxWidth(), colors = moimOutlinedTextFieldColors())
        Spacer(Modifier.height(10.dp))
        Text("사용 핸드폰 종류", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        Spacer(Modifier.height(6.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("iphone" to "🍎 아이폰", "android" to "🤖 안드로이드").forEach { (k, label) ->
                val on = deviceType == k
                Text(
                    label, fontSize = 13.sp, fontWeight = FontWeight.Bold,
                    color = moimToggleText(on, Color.White, MoimInk),
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .clickable { deviceType = k }
                        .background(moimToggleBg(on, MoimAccent), RoundedCornerShape(20.dp))
                        .then(if (MoimTheme.dark) Modifier.border(1.dp, moimToggleBorder(on), RoundedCornerShape(20.dp)) else Modifier)
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        Text("앱 설치용 연결 이메일 (애플ID/구글계정)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        OutlinedTextField(
            value = deviceEmail, onValueChange = { deviceEmail = it }, singleLine = true,
            placeholder = { Text("앱 설치용 이메일") },
            modifier = Modifier.fillMaxWidth(), colors = moimOutlinedTextFieldColors())
        Spacer(Modifier.height(10.dp))
        Text("직군", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        ExposedDropdownMenuBox(
            expanded = memberTypeExpanded,
            onExpandedChange = { memberTypeExpanded = it },
            modifier = Modifier.fillMaxWidth(),
        ) {
            OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
                value = memberType,
                onValueChange = {},
                readOnly = true,
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = memberTypeExpanded) },
                modifier = Modifier
                    .menuAnchor(type = MenuAnchorType.PrimaryNotEditable, enabled = true)
                    .fillMaxWidth(),
            )
            ExposedDropdownMenu(
                expanded = memberTypeExpanded,
                onDismissRequest = { memberTypeExpanded = false },
            ) {
                MTYPE_ORDER.forEach { t ->
                    DropdownMenuItem(
                        text = { Text(t) },
                        onClick = {
                            memberType = t
                            memberTypeExpanded = false
                            savedMsg = false
                        },
                    )
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Text("자기소개", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
            value = intro, onValueChange = { intro = it; savedMsg = false },
            placeholder = { Text("자기소개를 입력하세요") }, modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(14.dp))
        Button(
            onClick = {
                vm.saveMyInfo(intro, memberType, color.ifBlank { null }, avatarBytes, avatarName, clearAvatar,
                    deviceType.ifBlank { null }, deviceEmail) {
                    avatarBytes = null; avatarName = null; clearAvatar = false; savedMsg = true
                }
            },
            modifier = Modifier.fillMaxWidth().height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
            shape = RoundedCornerShape(12.dp)
        ) { Text("내 정보 저장", fontSize = 15.sp, fontWeight = FontWeight.Bold) }
        if (savedMsg) {
            Spacer(Modifier.height(8.dp))
            Text("내 정보가 저장되었습니다.", color = catColor("work"), fontSize = 12.5.sp)
        }

        HorizontalDivider(color = MoimLine, modifier = Modifier.padding(vertical = 20.dp))
        Text("비밀번호 변경", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        Spacer(Modifier.height(8.dp))
        if (isSuper) {
            Text("전체관리자 계정의 비밀번호는 변경할 수 없습니다.", color = MoimSub, fontSize = 12.5.sp)
        } else {
            OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
                value = pw, onValueChange = { pw = it; pwMsg = null },
                placeholder = { Text("새 비밀번호 (6자 이상)") }, singleLine = true,
                visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
                value = pw2, onValueChange = { pw2 = it; pwMsg = null },
                placeholder = { Text("새 비밀번호 확인") }, singleLine = true,
                visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth()
            )
            pwMsg?.let { (ok, m) ->
                Spacer(Modifier.height(8.dp))
                Text(m, color = if (ok) catColor("work") else MoimAdmin, fontSize = 12.5.sp)
            }
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = {
                    when {
                        pw.length < 6 -> pwMsg = false to "비밀번호는 6자 이상이어야 합니다."
                        pw != pw2 -> pwMsg = false to "비밀번호가 일치하지 않습니다."
                        else -> vm.changeMyPassword(pw) { ok, m ->
                            pwMsg = ok to m
                            if (ok) { pw = ""; pw2 = "" }
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth().height(46.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MoimLine, contentColor = MoimInk),
                shape = RoundedCornerShape(12.dp)
            ) { Text("비밀번호 변경", fontSize = 14.sp, fontWeight = FontWeight.Bold) }
        }

        Spacer(Modifier.height(8.dp))
        val uriHandler = LocalUriHandler.current
        val privacyUrl = context.getString(R.string.privacy_policy_url)
        Text(
            "개인정보처리방침",
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = MoimAccent,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .clickable { uriHandler.openUri(privacyUrl) }
                .padding(vertical = 8.dp),
        )
        HorizontalDivider(color = MoimLine, modifier = Modifier.padding(vertical = 20.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            Text("로그아웃", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MoimSub,
                modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable { vm.logout() }.padding(horizontal = 12.dp, vertical = 6.dp))
            Spacer(Modifier.width(10.dp))
            Text("회원 탈퇴", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MoimAdmin,
                modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable { showDelete = true }.padding(horizontal = 12.dp, vertical = 6.dp))
        }
        Spacer(Modifier.height(20.dp))
    }
}

// ── 방 순서(핀) 설정 — 최대 5개 고정·드래그 재정렬 (방목록 ⚙️ → 방 순서 탭) ──
@Composable
private fun OrderTab(vm: MoimViewModel) {
    // 고정 가능한 방 = 방목록에 보이는 방(주간 학술활동·전체공지 제외, 가입한 모임방·DM 포함)
    val weekRoom = vm.rooms.firstOrNull { it.category != "custom" && it.defaultView == "week" }
    val noticeRoom = noticeTopRoom(vm.rooms)   // 항상 맨 위 고정 · 변경 불가
    val bugReport = bugReportRoom(vm.rooms)
    val rooms = vm.rooms.filter {
        it.id != weekRoom?.id && it.id != noticeRoom?.id && it.id != bugReport?.id &&
            (if (it.category == "custom" || it.category == "direct") vm.myRoomIds.contains(it.id) else true)
    }
    var draft by remember(vm.roomPins) { mutableStateOf(vm.roomPins.filter { id -> rooms.any { it.id == id } }) }
    var savedMsg by remember { mutableStateOf(false) }
    var dragIndex by remember { mutableStateOf(-1) }
    var dragOffset by remember { mutableStateOf(0f) }
    var rowHeightPx by remember { mutableStateOf(1f) }
    fun labelOf(r: Room) = roomDisplayName(r, vm.profilesById)

    Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text("전체공지 방은 항상 맨 위에 고정되며 변경할 수 없습니다. 그 아래로 최대 5개를 고정할 수 있어요. ☰ 를 길게 눌러 드래그로 순서 변경, 나머지는 새 메시지 순.", fontSize = 12.sp, color = MoimSub)
        Spacer(Modifier.height(10.dp))
        noticeRoom?.let { nr ->
            Text("항상 맨 위 (변경 불가)", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Row(modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("📌", fontSize = 14.sp, modifier = Modifier.padding(end = 8.dp))
                Text(labelOf(nr), fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("고정됨", fontSize = 11.sp, color = MoimSub)
            }
            Spacer(Modifier.height(10.dp))
        }
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
                Text("${i + 1}. ${labelOf(r)}", fontSize = 14.sp, color = MoimInk, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                PinIcon("✕", MoimAdmin) { draft = draft.filter { it != id }; savedMsg = false }
            }
        }
        Spacer(Modifier.height(10.dp))
        Text("방 목록", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        rooms.filter { it.id !in draft }.forEach { r ->
            Row(modifier = Modifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(labelOf(r), fontSize = 14.sp, color = MoimInk, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                val enabled = draft.size < 5
                Text(
                    "📌 고정", fontSize = 12.sp, fontWeight = FontWeight.Bold,
                    color = if (enabled) MoimAccent else MoimSub.copy(alpha = 0.4f),
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .then(if (enabled) Modifier.clickable { draft = draft + r.id; savedMsg = false } else Modifier)
                        .background(MoimBg, RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        Button(
            onClick = { vm.saveRoomPins(draft); savedMsg = true },
            modifier = Modifier.fillMaxWidth().height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
            shape = RoundedCornerShape(12.dp)
        ) { Text("순서 저장", fontSize = 15.sp, fontWeight = FontWeight.Bold) }
        if (savedMsg) {
            Spacer(Modifier.height(8.dp))
            Text("순서를 저장했습니다.", color = catColor("work"), fontSize = 12.5.sp, modifier = Modifier.align(Alignment.CenterHorizontally))
        }
    }
}

// ── 회원 검색 — 전체 명단·이름/직종 정렬·검색·메시지(1:1 DM 열기) ──
@Composable
private fun MemberSearchTab(vm: MoimViewModel, onOpenRoom: (Room) -> Unit) {
    val collator = remember { java.text.Collator.getInstance(java.util.Locale.KOREAN) }
    val byName = Comparator<Profile> { a, b -> collator.compare(a.name, b.name) }
    val list = vm.searchableMembers()
    val byType = vm.memberSearchByType

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        OutlinedTextField(
            colors = moimOutlinedTextFieldColors(),
            value = vm.memberSearchQuery,
            onValueChange = { vm.memberSearchQuery = it },
            placeholder = { Text("🔍 이름으로 검색") },
            singleLine = true, modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(10.dp))
        Row {
            SortChip("이름순", !byType) { vm.memberSearchByType = false }
            Spacer(Modifier.width(8.dp))
            SortChip("직종별", byType) { vm.memberSearchByType = true }
        }
        Spacer(Modifier.height(12.dp))
        LazyColumn(modifier = Modifier.fillMaxSize()) {
            if (list.isEmpty()) {
                item {
                    Text(
                        if (vm.memberSearchQuery.isBlank()) "표시할 회원이 없습니다." else "검색 결과가 없습니다.",
                        fontSize = 13.sp, color = MoimSub
                    )
                }
            } else if (byType) {
                val groups = list.groupBy { it.memberType }
                val order = MTYPE_ORDER.filter { groups.containsKey(it) } + groups.keys.filter { it !in MTYPE_ORDER }
                order.forEach { t ->
                    val g = groups[t] ?: return@forEach
                    item { Text("$t · ${g.size}명", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = typeColor(t), modifier = Modifier.padding(top = 4.dp, bottom = 6.dp)) }
                    items(g.sortedWith(byName), key = { it.id }) { p -> MemberSearchRow(p) { vm.startDirect(p.id, onOpenRoom) } }
                }
            } else {
                items(list.sortedWith(byName), key = { it.id }) { p -> MemberSearchRow(p) { vm.startDirect(p.id, onOpenRoom) } }
            }
        }
    }
}

// 직군·자기소개 — 모임방 설정·만들기 등에서 작은 글씨로 (iOS MemberTypeIntroLines)
@Composable
private fun MemberTypeIntroLines(p: Profile) {
    Text(p.memberType, fontSize = 11.sp, color = MoimSub)
    if (!p.intro.isNullOrBlank()) {
        Text(p.intro, fontSize = 11.sp, color = MoimSub, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun RoomMemberInfo(p: Profile, nameSuffix: String = "", modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(p.name + nameSuffix, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MoimInk)
        MemberTypeIntroLines(p)
    }
}

// 회원 검색·관리 행의 연락처 줄 — 이메일·전화번호를 작은 글씨로 (있는 것만)
@Composable
private fun MemberContactLines(p: Profile) {
    if (!p.email.isNullOrBlank()) {
        Text("✉ ${p.email}", fontSize = 11.sp, color = MoimSub, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
    if (!p.phone.isNullOrBlank()) {
        Text("☎ ${p.phone}", fontSize = 11.sp, color = MoimSub, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun MemberSearchRow(p: Profile, onMessage: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MoimWhite, RoundedCornerShape(12.dp))
            .padding(11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        PersonAvatar(p, 42, 13, 12.0)
        Spacer(Modifier.width(11.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(p.name, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Text(p.memberType, fontSize = 11.5.sp, color = MoimSub)
            MemberContactLines(p)
            if (!p.intro.isNullOrBlank()) {
                Text(p.intro, fontSize = 11.5.sp, color = MoimSub, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Spacer(Modifier.width(8.dp))
        Text(
            "메시지", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold,
            modifier = Modifier.clip(RoundedCornerShape(14.dp)).clickable(onClick = onMessage).background(MoimAccent).padding(horizontal = 14.dp, vertical = 8.dp)
        )
    }
}

@Composable
private fun PinIcon(t: String, color: Color = MoimAccent, onClick: () -> Unit) {
    Text(
        t, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = color,
        modifier = Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onClick).padding(horizontal = 8.dp, vertical = 4.dp)
    )
}

// 잔여 병실 현황 — 메모 형식 자유 텍스트 (편집 → 게시, 모두에게 공유)
private val WARD_ACCENT = Color(0xFFEA7317)
private val WARD_KST = ZoneId.of("Asia/Seoul")
private val WARD_DOW = arrayOf("월", "화", "수", "목", "금", "토", "일")

private fun wardPublishLabel(iso: String?): String? {
    if (iso.isNullOrBlank()) return null
    return runCatching {
        val z = OffsetDateTime.parse(iso).atZoneSameInstant(WARD_KST)
        val dow = WARD_DOW[z.dayOfWeek.value - 1]
        val d = z.format(DateTimeFormatter.ofPattern("M/d", Locale.KOREAN))
        val t = z.format(DateTimeFormatter.ofPattern("a h:mm", Locale.KOREAN))
        "$d ($dow) $t"
    }.getOrNull()
}

@Composable
private fun WardStatusDocument(content: String, publishLabel: String?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(3.dp, RoundedCornerShape(16.dp), ambientColor = Color.Black.copy(alpha = 0.08f))
            .clip(RoundedCornerShape(16.dp))
            .background(MoimWhite)
            .border(1.dp, MoimLine, RoundedCornerShape(16.dp))
            .padding(horizontal = 20.dp, vertical = 20.dp),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(3.dp)
                .background(WARD_ACCENT, RoundedCornerShape(2.dp)),
        )
        Spacer(Modifier.height(16.dp))
        if (publishLabel != null) {
            Text("게시", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Spacer(Modifier.height(4.dp))
            Text(publishLabel, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = MoimInk, lineHeight = 28.sp)
            Spacer(Modifier.height(14.dp))
            HorizontalDivider(color = MoimLine)
            Spacer(Modifier.height(14.dp))
        }
        if (content.isBlank()) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text("🛏", fontSize = 36.sp)
                Spacer(Modifier.height(8.dp))
                Text("작성된 내용이 없습니다", fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MoimInk)
                Spacer(Modifier.height(4.dp))
                Text(
                    "우측 상단 ‘편집’을 눌러\n잔여 병실 현황을 작성하세요.",
                    fontSize = 13.sp,
                    color = MoimSub,
                    textAlign = TextAlign.Center,
                    lineHeight = 20.sp,
                )
            }
        } else {
            Text(content, fontSize = 15.sp, color = MoimInk, lineHeight = 24.sp)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WardStatusScreen(vm: MoimViewModel, onBack: () -> Unit) {
    var tab by remember { mutableStateOf("beds") }
    var editing by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }
    LaunchedEffect(Unit) { vm.loadWardStatus() }

    val publishLabel = wardPublishLabel(vm.wardStatusUpdatedAt)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("병실현황", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    TextButton(onClick = onBack) { Text("‹", fontSize = 25.sp) }
                },
                actions = {
                    if (tab == "beds" && !editing && canEditWard(vm.myProfile)) {
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
        Column(modifier = Modifier.padding(pad).fillMaxSize()) {
            WardSegmentRow(tab = tab, onTab = { tab = it; editing = false })
            when (tab) {
                "duty" -> WardDutyPane(vm = vm, modifier = Modifier.weight(1f).background(MoimBg))
                "beds" -> if (editing) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp),
                    ) {
                        OutlinedTextField(
                            colors = moimOutlinedTextFieldColors(),
                            value = draft,
                            onValueChange = { draft = it },
                            modifier = Modifier
                                .fillMaxWidth()
                                .weight(1f),
                            placeholder = {
                                Text("예:\n- 남자\n다인실: 0자리 (1자리 EICU 전과예정)\n3인실(APICU): 0자리")
                            },
                        )
                        Spacer(Modifier.height(12.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Button(
                                onClick = { editing = false },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.buttonColors(containerColor = MoimLine, contentColor = MoimInk),
                            ) { Text("취소") }
                            Button(
                                onClick = { vm.saveWardStatus(draft) { editing = false } },
                                modifier = Modifier.weight(1f),
                                colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
                            ) { Text("게시") }
                        }
                    }
                } else {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(MoimBg)
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                    ) {
                        WardStatusDocument(content = vm.wardStatus, publishLabel = publishLabel)
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

    // 구성원 제거 확인
    kickTarget?.let { uid ->
        AlertDialog(
            onDismissRequest = { kickTarget = null },
            title = { Text("구성원 제거") },
            text = { Text("‘${vm.nameOf(uid)}’ 님을 이 모임방에서 제거할까요?") },
            confirmButton = {
                TextButton(onClick = {
                    vm.removeRoomMember(room.id, uid)
                    kickTarget = null
                }) { Text("구성원 제거", color = MoimAdmin, fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { kickTarget = null }) { Text("취소") } }
        )
    }

    LaunchedEffect(room.id) {
        vm.loadRoomMembers(room.id)
        vm.reloadProfiles()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("모임방 설정", fontWeight = FontWeight.Bold) },
        text = {
            Column(modifier = Modifier
                .heightIn(max = 380.dp)
                .verticalScroll(rememberScrollState())) {
                Text("참여 회원 (제거)", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
                Spacer(Modifier.height(8.dp))
                if (!vm.roomMembersLoaded) {
                    Text("회원 정보를 불러오는 중…", fontSize = 13.sp, color = MoimSub)
                } else if (memberIds.isEmpty()) {
                    Text("참여 구성원이 없습니다. 아래에서 초대하세요.", fontSize = 13.sp, color = MoimSub)
                }
                orderedRoomMemberIds(room, memberIds, vm.profilesById).forEach { uid ->
                    val isCreator = uid == room.createdBy
                    val isMe = uid == MoimRepository.currentUserId()
                    val tag = when {
                        isCreator -> " (개설자)"
                        isMe -> " (나)"
                        else -> ""
                    }
                    val p = vm.profilesById[uid]
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (p != null) {
                            RoomMemberInfo(p, nameSuffix = tag, modifier = Modifier.weight(1f))
                        } else {
                            Text(
                                vm.nameOf(uid) + tag,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = MoimInk,
                                modifier = Modifier.weight(1f),
                            )
                        }
                        if (!isCreator) {
                            TextButton(onClick = { kickTarget = uid }) {
                                Text("제거", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MoimAdmin)
                            }
                        }
                    }
                }

                val candidates = vm.profilesById.values
                    .filter {
                        it.id != MoimRepository.currentUserId()
                            && it.approved != false
                            && it.withdrawn != true
                            && it.id !in memberIds
                    }
                    .sortedBy { it.name }
                Spacer(Modifier.height(14.dp))
                HorizontalDivider(color = MoimLine)
                Spacer(Modifier.height(12.dp))
                Text("구성원 초대", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MoimSub)
                Spacer(Modifier.height(8.dp))
                if (!vm.roomMembersLoaded) {
                    Text("회원 정보를 불러오는 중…", fontSize = 13.sp, color = MoimSub)
                } else if (candidates.isEmpty()) {
                    Text("초대할 수 있는 회원가 없습니다.", fontSize = 13.sp, color = MoimSub)
                }
                candidates.forEach { p ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RoomMemberInfo(p, modifier = Modifier.weight(1f))
                        TextButton(onClick = { vm.inviteRoomMember(room.id, p.id) }) {
                            Text("초대", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = catColor("work"))
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
    var pendingIconAdjustUri by remember { mutableStateOf<Uri?>(null) }
    val iconPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) pendingIconAdjustUri = uri
    }
    val people = vm.otherProfiles()

    pendingIconAdjustUri?.let { uri ->
        AvatarAdjustDialog(
            sourceUri = uri,
            onDismiss = { pendingIconAdjustUri = null },
            onConfirm = { bytes, name ->
                iconBytes = bytes
                iconName = name
                iconUri = null
                pendingIconAdjustUri = null
            },
        )
    }

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
            colors = moimOutlinedTextFieldColors(),
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
                iconBytes = iconBytes, iconUri = iconUri, existingIconUrl = null,
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
                            .background(moimToggleBg(on, MoimHl))
                            .then(if (MoimTheme.dark && on) Modifier.border(1.dp, moimToggleBorder(true), RoundedCornerShape(11.dp)) else Modifier)
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
                        RoomMemberInfo(p, modifier = Modifier.weight(1f))
                        Spacer(Modifier.width(8.dp))
                        Text(if (on) "✓" else "○", color = moimToggleText(on, MoimAccent, MoimLine), fontWeight = FontWeight.Bold)
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
