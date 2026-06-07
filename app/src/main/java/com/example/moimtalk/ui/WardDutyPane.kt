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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.ExposedDropdownMenu
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
    var showTodaySummary by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { vm.loadWardTodayDuty() }
    LaunchedEffect(ym) { vm.loadWardDuties(ym) }

    val days = remember(ym) { (1..ym.lengthOfMonth()).map { ym.atDay(it) } }
    val faculty = remember(vm.profilesById) { dutyMembersByType(vm.profilesById, "교실") }
    val residents = remember(vm.profilesById) { dutyMembersByType(vm.profilesById, "의국") }
    val canEdit = canEditWard(vm.myProfile)

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
            onClick = {
                vm.loadWardTodayDuty()
                showTodaySummary = true
            },
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
        )
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(days, key = { it.toString() }) { date ->
                val key = date.toString()
                val duty = vm.wardDuties[key]
                val tone = wardDutyTone(date)
                val isToday = date == today
                val hasDuty = duty != null && (
                    duty.profDay.isNotBlank() || duty.residentDay.isNotBlank() || duty.residentNight.isNotBlank()
                    )
                WardDutyDayRow(
                    date = date,
                    duty = duty,
                    tone = tone,
                    isToday = isToday,
                    editLabel = if (isToday && canEdit) (if (hasDuty) "수정" else "입력") else null,
                    onEdit = { if (canEdit) editDate = date },
                )
            }
        }
    }

    if (showTodaySummary) {
        TodayDutySummaryDialog(
            today = today,
            duty = vm.wardTodayDuty,
            onDismiss = { showTodaySummary = false },
        )
    }

    editDate?.let { date ->
        val key = date.toString()
        val existing = vm.wardDuties[key]
        WardDutyEditDialog(
            date = date,
            faculty = faculty,
            residents = residents,
            initialProf = existing?.profDay ?: "",
            initialResidentDay = existing?.residentDay ?: "",
            initialResidentNight = existing?.residentNight ?: "",
            onDismiss = { editDate = null },
            onSave = { prof, resDay, resNight ->
                vm.saveWardDuty(key, prof, resDay, resNight) { editDate = null }
            },
        )
    }
}

@Composable
private fun TodayDutyQuickButton(
    today: LocalDate,
    duty: WardDuty?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dow = DOW_KO[today.dayOfWeek.value - 1]
    val prof = duty?.profDay?.takeIf { it.isNotBlank() } ?: "—"
    val resDay = duty?.residentDay?.takeIf { it.isNotBlank() } ?: "—"
    val resNight = duty?.residentNight?.takeIf { it.isNotBlank() } ?: "—"

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MoimAccent.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
            .border(1.dp, MoimAccent.copy(alpha = 0.35f), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("오늘 당직", fontSize = 14.sp, fontWeight = FontWeight.ExtraBold, color = MoimAccent)
                Spacer(Modifier.weight(1f))
                Text("${today.monthValue}/${today.dayOfMonth} ($dow)", fontSize = 11.sp, color = MoimSub)
            }
            Spacer(Modifier.height(6.dp))
            Text(
                "교원 $prof  ·  낮 $resDay  ·  방 $resNight",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = MoimInk,
                maxLines = 2,
            )
            Text("탭하여 자세히 보기", fontSize = 10.sp, color = MoimSub, modifier = Modifier.padding(top = 4.dp))
        }
    }
}

@Composable
private fun TodayDutySummaryDialog(
    today: LocalDate,
    duty: WardDuty?,
    onDismiss: () -> Unit,
) {
    val dow = DOW_KO[today.dayOfWeek.value - 1]
    val tone = wardDutyTone(today)
    val toneLabel = TONE_LABEL[tone]
    fun name(v: String?) = v?.takeIf { it.isNotBlank() } ?: "미지정"

    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(MoimPaper)
                .padding(20.dp),
        ) {
            Text("오늘 당직", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Text(
                "${today.monthValue}월 ${today.dayOfMonth}일 ($dow)${toneLabel?.let { " · $it" } ?: ""}",
                fontSize = 12.sp,
                color = MoimSub,
                modifier = Modifier.padding(top = 4.dp, bottom = 16.dp),
            )
            Text("교원", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Text(name(duty?.profDay), fontSize = 22.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Spacer(Modifier.height(14.dp))
            Text("전공의", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f)) {
                    Text("낮당직", fontSize = 10.sp, color = MoimSub)
                    Text(name(duty?.residentDay), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = MoimInk)
                }
                Column(Modifier.weight(1f)) {
                    Text("방당직", fontSize = 10.sp, color = MoimSub)
                    Text(name(duty?.residentNight), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = MoimInk)
                }
            }
            Spacer(Modifier.height(18.dp))
            Button(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
            ) { Text("확인") }
        }
    }
}

@Composable
private fun WardDutyDayRow(
    date: LocalDate,
    duty: WardDuty?,
    tone: WardDutyTone,
    isToday: Boolean,
    editLabel: String?,
    onEdit: () -> Unit,
) {
    val dow = DOW_KO[date.dayOfWeek.value - 1]
    val label = "${date.monthValue}/${date.dayOfMonth} ($dow)"
    val (bg, border) = wardDutyRowColors(tone, isToday)
    val toneLabel = TONE_LABEL[tone]
    val prof = duty?.profDay?.takeIf { it.isNotBlank() } ?: "—"
    val resDay = duty?.residentDay?.takeIf { it.isNotBlank() } ?: "—"
    val resNight = duty?.residentNight?.takeIf { it.isNotBlank() } ?: "—"

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg, RoundedCornerShape(12.dp))
            .border(1.dp, border, RoundedCornerShape(12.dp))
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                label,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = if (tone != WardDutyTone.WEEKDAY) Color(0xFF6D5E58) else MoimInk,
            )
            if (isToday) {
                Text(" 오늘", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimAccent)
            }
            if (toneLabel != null) {
                Spacer(Modifier.weight(1f))
                Text(toneLabel, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color(0xFF8A7E96))
            } else {
                Spacer(Modifier.weight(1f))
            }
            if (editLabel != null) {
                TextButton(onClick = onEdit, modifier = Modifier.padding(0.dp)) {
                    Text(editLabel, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = MoimAccent)
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Text("교원", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        Text(prof, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = MoimInk, lineHeight = 24.sp)
        Spacer(Modifier.height(8.dp))
        Text("전공의", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f)) {
                Text("낮당직", fontSize = 10.sp, color = MoimSub)
                Text(resDay, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = MoimInk, lineHeight = 22.sp)
            }
            Column(Modifier.weight(1f)) {
                Text("방당직", fontSize = 10.sp, color = MoimSub)
                Text(resNight, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = MoimInk, lineHeight = 22.sp)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WardDutyEditDialog(
    date: LocalDate,
    faculty: List<Profile>,
    residents: List<Profile>,
    initialProf: String,
    initialResidentDay: String,
    initialResidentNight: String,
    onDismiss: () -> Unit,
    onSave: (String, String, String) -> Unit,
) {
    var prof by remember { mutableStateOf(initialProf) }
    var resDay by remember { mutableStateOf(initialResidentDay) }
    var resNight by remember { mutableStateOf(initialResidentNight) }
    val dow = DOW_KO[date.dayOfWeek.value - 1]
    val title = "${date.monthValue}/${date.dayOfMonth} ($dow) 당직"

    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(MoimPaper)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
        ) {
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Spacer(Modifier.height(14.dp))
            Text("교원 (교실)", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            DutyMemberPicker(members = faculty, selected = prof, onSelect = { prof = it })
            Spacer(Modifier.height(10.dp))
            Text("전공의 낮당직 (의국)", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            DutyMemberPicker(members = residents, selected = resDay, onSelect = { resDay = it })
            Spacer(Modifier.height(10.dp))
            Text("전공의 방당직 (의국)", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            DutyMemberPicker(members = residents, selected = resNight, onSelect = { resNight = it })
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = MoimLine, contentColor = MoimInk),
                ) { Text("취소") }
                Button(
                    onClick = { onSave(prof, resDay, resNight) },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
                ) { Text("저장") }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DutyMemberPicker(members: List<Profile>, selected: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val options = remember(members) { listOf("") + members.map { it.name } }
    val label = selected.ifBlank { "선택" }

    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = label,
            onValueChange = {},
            readOnly = true,
            modifier = Modifier.menuAnchor().fillMaxWidth(),
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            shape = RoundedCornerShape(11.dp),
            colors = moimOutlinedTextFieldColors(),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
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
