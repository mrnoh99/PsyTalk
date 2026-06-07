package com.example.moimtalk.ui

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.example.moimtalk.MoimViewModel
import com.example.moimtalk.data.WardDuty
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId

private val KST = ZoneId.of("Asia/Seoul")
private val DOW_KO = arrayOf("월", "화", "수", "목", "금", "토", "일")
private val HOLIDAY_TINT = Color(0xFFFFE0B2)
private val HOLIDAY_BORDER = Color(0xFFFF9800)

@OptIn(ExperimentalFoundationApi::class)
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

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun WardDutyPane(vm: MoimViewModel, modifier: Modifier = Modifier) {
    val today = remember { LocalDate.now(KST) }
    var ym by remember { mutableStateOf(YearMonth.from(today)) }
    var editDate by remember { mutableStateOf<LocalDate?>(null) }

    LaunchedEffect(ym) { vm.loadWardDuties(ym) }

    val days = remember(ym) {
        (1..ym.lengthOfMonth()).map { ym.atDay(it) }
    }

    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("‹", fontSize = 20.sp, color = MoimSub, modifier = Modifier
                .combinedClickable(onClick = { ym = ym.minusMonths(1) }, onLongClick = null)
                .padding(horizontal = 8.dp))
            Text("${ym.year}년 ${ym.monthValue}월", fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
            Text("›", fontSize = 20.sp, color = MoimSub, modifier = Modifier
                .combinedClickable(onClick = { ym = ym.plusMonths(1) }, onLongClick = null)
                .padding(horizontal = 8.dp))
        }
        Text(
            "날짜를 길게 눌러 당직을 입력·수정합니다.",
            fontSize = 11.5.sp,
            color = MoimSub,
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
                val holiday = isWardDutyHoliday(date, duty?.isHoliday == true)
                val canEdit = canEditWard(vm.myProfile)
                WardDutyDayRow(
                    date = date,
                    duty = duty,
                    holiday = holiday,
                    isToday = date == today,
                    canEdit = canEdit,
                    onLongPress = { if (canEdit) editDate = date },
                )
            }
        }
    }

    editDate?.let { date ->
        val key = date.toString()
        val existing = vm.wardDuties[key]
        WardDutyEditDialog(
            date = date,
            initialProf = existing?.profDay ?: "",
            initialResident = existing?.residentNight ?: "",
            initialHoliday = existing?.isHoliday == true || (existing == null && isWardDutyHoliday(date, false)),
            onDismiss = { editDate = null },
            onSave = { prof, resident, holiday ->
                vm.saveWardDuty(key, prof, resident, holiday) { editDate = null }
            },
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun WardDutyDayRow(
    date: LocalDate,
    duty: WardDuty?,
    holiday: Boolean,
    isToday: Boolean,
    canEdit: Boolean,
    onLongPress: () -> Unit,
) {
    val dow = DOW_KO[date.dayOfWeek.value - 1]
    val label = "${date.monthValue}/${date.dayOfMonth} ($dow)"
    val bg = when {
        holiday -> HOLIDAY_TINT
        isToday -> MoimYellow.copy(alpha = 0.45f)
        else -> MoimWhite
    }
    val borderColor = when {
        holiday -> HOLIDAY_BORDER
        isToday -> MoimAccent
        else -> MoimLine
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg, RoundedCornerShape(12.dp))
            .border(1.dp, borderColor, RoundedCornerShape(12.dp))
            .combinedClickable(
                onClick = {},
                onLongClick = if (canEdit) onLongPress else null,
            )
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = if (holiday) Color(0xFFE65100) else MoimInk)
            if (holiday) {
                Spacer(Modifier.weight(1f))
                Text("휴일", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color(0xFFE65100))
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(
            "교수 낮당직: ${duty?.profDay?.takeIf { it.isNotBlank() } ?: "—"}",
            fontSize = 13.sp,
            color = MoimInk,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.height(3.dp))
        Text(
            "전공의 밤당직: ${duty?.residentNight?.takeIf { it.isNotBlank() } ?: "—"}",
            fontSize = 13.sp,
            color = MoimSub,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun WardDutyEditDialog(
    date: LocalDate,
    initialProf: String,
    initialResident: String,
    initialHoliday: Boolean,
    onDismiss: () -> Unit,
    onSave: (String, String, Boolean) -> Unit,
) {
    var prof by remember { mutableStateOf(initialProf) }
    var resident by remember { mutableStateOf(initialResident) }
    var holiday by remember { mutableStateOf(initialHoliday) }
    val dow = DOW_KO[date.dayOfWeek.value - 1]
    val title = "${date.monthValue}/${date.dayOfMonth} ($dow) 당직"

    Dialog(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(MoimPaper)
                .padding(20.dp),
        ) {
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Spacer(Modifier.height(14.dp))
            Text("교수 낮당직", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            OutlinedTextField(
                prof, { prof = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("교수 이름", color = MoimHint) },
                singleLine = true,
                shape = RoundedCornerShape(11.dp),
                colors = moimOutlinedTextFieldColors(),
            )
            Spacer(Modifier.height(10.dp))
            Text("전공의 밤당직", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MoimSub)
            OutlinedTextField(
                resident, { resident = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("전공의 이름", color = MoimHint) },
                singleLine = true,
                shape = RoundedCornerShape(11.dp),
                colors = moimOutlinedTextFieldColors(),
            )
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(checked = holiday, onCheckedChange = { holiday = it })
                Text("휴일 (강조 표시)", fontSize = 13.sp, color = MoimInk)
            }
            Spacer(Modifier.height(16.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = MoimLine, contentColor = MoimInk),
                ) { Text("취소") }
                Button(
                    onClick = { onSave(prof.trim(), resident.trim(), holiday) },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
                ) { Text("저장") }
            }
        }
    }
}
