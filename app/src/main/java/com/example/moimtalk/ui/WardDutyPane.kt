package com.example.moimtalk.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.example.moimtalk.MoimViewModel
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.WardDuty
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId

private val KST = ZoneId.of("Asia/Seoul")
private val DOW_KO = arrayOf("월", "화", "수", "목", "금", "토", "일")
private val TONE_LABEL = mapOf(
    WardDutyTone.PUBLIC_HOLIDAY to "공휴일",
    WardDutyTone.WEEKEND to "주말",
)

private fun hasAnyDuty(duty: WardDuty?): Boolean = duty != null && (
    duty.profDay.isNotBlank() || duty.residentDay.isNotBlank() || duty.residentNight.isNotBlank()
        || duty.residentOutpatient1.isNotBlank() || duty.residentOutpatient2.isNotBlank()
    )

@Composable
fun WardSegmentRow(tab: String, onTab: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        WardSegButton("잔여병실", tab == "beds", Modifier.weight(1f)) { onTab("beds") }
        WardSegButton("당직표", tab == "duty", Modifier.weight(1f)) { onTab("duty") }
    }
}

@Composable
private fun WardSegButton(label: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (on) MoimYellow else MoimWhite, RoundedCornerShape(10.dp))
            .border(1.dp, if (on) MoimYellow else MoimLine, RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(label, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = if (on) MoimInk else MoimSub)
    }
}

@Composable
fun WardDutyPane(vm: MoimViewModel, modifier: Modifier = Modifier) {
    val today = remember { LocalDate.now(KST) }
    var ym by remember { mutableStateOf(YearMonth.from(today)) }
    var editDate by remember { mutableStateOf<LocalDate?>(null) }
    var pendingScrollToday by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    LaunchedEffect(Unit) { vm.loadWardTodayDuty() }
    LaunchedEffect(ym) { vm.loadWardDuties(ym) }

    val days = remember(ym) { (1..ym.lengthOfMonth()).map { ym.atDay(it) } }

    LaunchedEffect(ym, pendingScrollToday) {
        if (pendingScrollToday) {
            val idx = days.indexOfFirst { it == today }
            if (idx >= 0) listState.animateScrollToItem(idx)
            pendingScrollToday = false
        }
    }
    val faculty = remember(vm.profilesById) { dutyMembersByType(vm.profilesById, "교실") }
    val residents = remember(vm.profilesById) { dutyMembersByType(vm.profilesById, "의국") }
    val canEdit = canEditWardDuty(vm.myProfile)

    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("‹", fontSize = 20.sp, color = MoimSub, modifier = Modifier
                .clickable { ym = ym.minusMonths(1) }
                .padding(horizontal = 8.dp))
            Text("${ym.year}년 ${ym.monthValue}월", fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
            Text("›", fontSize = 20.sp, color = MoimSub, modifier = Modifier
                .clickable { ym = ym.plusMonths(1) }
                .padding(horizontal = 8.dp))
        }
        TodayDutyQuickButton(
            today = today,
            duty = vm.wardTodayDuty,
            offDay = isWardDutyOffDay(today),
            onClick = {
                vm.loadWardTodayDuty()
                ym = YearMonth.from(today)
                pendingScrollToday = true
            },
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
        )
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            items(days, key = { it.toString() }) { date ->
                val key = date.toString()
                val duty = vm.wardDuties[key]
                WardDutyDayRow(
                    date = date,
                    duty = duty,
                    tone = wardDutyTone(date),
                    offDay = isWardDutyOffDay(date),
                    isToday = date == today,
                    editLabel = if (canEdit) (if (hasAnyDuty(duty)) "수정" else "입력") else null,
                    onEdit = { editDate = date },
                )
            }
        }
    }

    editDate?.let { date ->
        val key = date.toString()
        val existing = vm.wardDuties[key]
        val offDay = isWardDutyOffDay(date)
        WardDutyEditDialog(
            date = date,
            offDay = offDay,
            faculty = faculty,
            residents = residents,
            initialProf = existing?.profDay ?: "",
            initialResidentDay = existing?.residentDay ?: "",
            initialResidentNight = existing?.residentNight ?: "",
            initialOutpatient1 = existing?.residentOutpatient1 ?: "",
            initialOutpatient2 = existing?.residentOutpatient2 ?: "",
            onDismiss = { editDate = null },
            onSave = { prof, resDay, resNight, out1, out2 ->
                val day = if (offDay) "" else resDay
                val o1 = if (offDay) "" else out1
                val o2 = if (offDay) "" else out2
                vm.saveWardDuty(key, prof, day, resNight, o1, o2) { editDate = null }
            },
        )
    }
}

@Composable
private fun TodayDutyQuickButton(
    today: LocalDate,
    duty: WardDuty?,
    offDay: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dow = DOW_KO[today.dayOfWeek.value - 1]
    val preview = dutyTodayPreview(
        duty?.profDay, duty?.residentDay, duty?.residentNight,
        duty?.residentOutpatient1, duty?.residentOutpatient2, offDay,
    )
    val (bg, border) = wardDutyTodayCardColors()

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg, RoundedCornerShape(12.dp))
            .border(1.dp, border, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("오늘 당직", fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = MoimAccent)
                Spacer(Modifier.weight(1f))
                Text("${today.monthValue}/${today.dayOfMonth} ($dow)", fontSize = 12.sp, color = MoimSub)
            }
            Spacer(Modifier.height(8.dp))
            Text(preview, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MoimInk, lineHeight = 21.sp, maxLines = 4)
        }
    }
}

@Composable
private fun WardDutyDayRow(
    date: LocalDate,
    duty: WardDuty?,
    tone: WardDutyTone,
    offDay: Boolean,
    isToday: Boolean,
    editLabel: String?,
    onEdit: () -> Unit,
) {
    val dow = DOW_KO[date.dayOfWeek.value - 1]
    val label = "${date.monthValue}/${date.dayOfMonth} ($dow)"
    val (bg, border) = wardDutyRowColors(tone, isToday)
    val toneLabel = TONE_LABEL[tone]

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg, RoundedCornerShape(12.dp))
            .border(1.dp, border, RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                label,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = if (tone != WardDutyTone.WEEKDAY) wardDutyOffDayInk() else MoimInk,
            )
            if (isToday) {
                Text(" 오늘", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimAccent)
            }
            Spacer(Modifier.weight(1f))
            if (toneLabel != null) {
                Text(toneLabel, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = wardDutyToneBadge())
            }
            if (editLabel != null) {
                TextButton(onClick = onEdit, modifier = Modifier.padding(0.dp)) {
                    Text(editLabel, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MoimAccent)
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(dutyProfDisplay(duty?.profDay), fontSize = 18.sp, fontWeight = FontWeight.Bold, color = MoimInk, lineHeight = 24.sp)
        Spacer(Modifier.height(6.dp))
        if (offDay) {
            Text("당직", fontSize = 10.sp, color = MoimSub)
            Text(dutyResidentDisplay(duty?.residentNight), fontSize = 17.sp, fontWeight = FontWeight.Bold, color = MoimInk, lineHeight = 22.sp)
        } else {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Column(Modifier.weight(1f)) {
                    Text("낮", fontSize = 10.sp, color = MoimSub)
                    Text(dutyResidentDisplay(duty?.residentDay), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = MoimInk)
                }
                Column(Modifier.weight(1f)) {
                    Text("당직", fontSize = 10.sp, color = MoimSub)
                    Text(dutyResidentDisplay(duty?.residentNight), fontSize = 16.sp, fontWeight = FontWeight.Bold, color = MoimInk)
                }
                Column(Modifier.weight(1f)) {
                    Text("외래", fontSize = 10.sp, color = MoimSub)
                    Text(
                        dutyOutpatientDisplay(duty?.residentOutpatient1, duty?.residentOutpatient2),
                        fontSize = 14.sp, fontWeight = FontWeight.Bold, color = MoimInk, lineHeight = 18.sp,
                    )
                }
            }
        }
    }
}

@Composable
private fun WardDutyEditDialog(
    date: LocalDate,
    offDay: Boolean,
    faculty: List<Profile>,
    residents: List<Profile>,
    initialProf: String,
    initialResidentDay: String,
    initialResidentNight: String,
    initialOutpatient1: String,
    initialOutpatient2: String,
    onDismiss: () -> Unit,
    onSave: (String, String, String, String, String) -> Unit,
) {
    var prof by remember { mutableStateOf(initialProf) }
    var resDay by remember { mutableStateOf(initialResidentDay) }
    var resNight by remember { mutableStateOf(initialResidentNight) }
    var out1 by remember { mutableStateOf(initialOutpatient1) }
    var out2 by remember { mutableStateOf(initialOutpatient2) }
    val dow = DOW_KO[date.dayOfWeek.value - 1]
    val toneLabel = TONE_LABEL[wardDutyTone(date)]
    val title = "${date.monthValue}/${date.dayOfMonth} ($dow) 당직${toneLabel?.let { " · $it" } ?: ""}"

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth(0.92f)
                .clip(RoundedCornerShape(16.dp))
                .background(MoimPaper)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
        ) {
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Spacer(Modifier.height(14.dp))
            Text("교원 당직 (교실 · 1인)", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            DutyMemberPicker(members = faculty, selected = prof, onSelect = { prof = it })
            Spacer(Modifier.height(10.dp))
            Text("전공의 (의국)", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            if (offDay) {
                Text("당직 (1인)", fontSize = 10.sp, color = MoimSub)
                DutyMemberPicker(members = residents, selected = resNight, onSelect = { resNight = it })
            } else {
                Text("낮당직 (1인)", fontSize = 10.sp, color = MoimSub)
                DutyMemberPicker(members = residents, selected = resDay, onSelect = { resDay = it })
                Spacer(Modifier.height(8.dp))
                Text("당직 (1인)", fontSize = 10.sp, color = MoimSub)
                DutyMemberPicker(members = residents, selected = resNight, onSelect = { resNight = it })
                Spacer(Modifier.height(8.dp))
                Text("외래 (최대 2인)", fontSize = 10.sp, color = MoimSub)
                DutyMemberPicker(members = residents, selected = out1, onSelect = { out1 = it })
                Spacer(Modifier.height(6.dp))
                DutyMemberPicker(members = residents, selected = out2, onSelect = { out2 = it })
            }
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = MoimLine, contentColor = MoimInk),
                ) { Text("취소") }
                Button(
                    onClick = { onSave(prof, resDay, resNight, out1, out2) },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
                ) { Text("저장") }
            }
        }
    }
}

/** 필드 탭 시 이름 목록 — DropdownMenu(별도 Popup)로 Dialog 에서도 동작 */
@Composable
private fun DutyMemberPicker(members: List<Profile>, selected: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val options = remember(members) { listOf("") + members.map { it.name } }
    val label = selected.ifBlank { "선택" }

    Box(modifier = Modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = label,
            onValueChange = {},
            readOnly = true,
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = true },
            trailingIcon = {
                Box(Modifier.clickable { expanded = !expanded }) {
                    ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded)
                }
            },
            shape = RoundedCornerShape(11.dp),
            colors = moimOutlinedTextFieldColors(),
        )
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier
                .fillMaxWidth(0.88f)
                .heightIn(max = 280.dp),
        ) {
            options.forEach { name ->
                DropdownMenuItem(
                    text = { Text(if (name.isBlank()) "— (없음)" else name) },
                    onClick = {
                        onSelect(name)
                        expanded = false
                    },
                )
            }
        }
    }
}
