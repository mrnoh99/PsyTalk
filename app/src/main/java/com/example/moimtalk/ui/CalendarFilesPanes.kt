package com.example.moimtalk.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.example.moimtalk.MoimViewModel
import com.example.moimtalk.data.CalendarEvent
import com.example.moimtalk.data.Room
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.OffsetDateTime
import java.time.YearMonth
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

// =====================================================================
//  날짜·시간 유틸 (timestamptz <-> 한국시간 표시)
// =====================================================================
private val KST: ZoneId = ZoneId.of("Asia/Seoul")
private val FMT_DISPLAY = DateTimeFormatter.ofPattern("M/d a h:mm", Locale.KOREAN)
private val FMT_DAY = DateTimeFormatter.ofPattern("M/d", Locale.KOREAN)
private val DOW_KO = arrayOf("월", "화", "수", "목", "금", "토", "일")
private val GRID_HEAD = arrayOf("일", "월", "화", "수", "목", "금", "토")

private fun parseZdt(iso: String?): ZonedDateTime? {
    if (iso.isNullOrBlank()) return null
    return try {
        OffsetDateTime.parse(iso).atZoneSameInstant(KST)
    } catch (_: Exception) {
        try {
            LocalDateTime.parse(iso).atZone(KST)
        } catch (_: Exception) {
            null
        }
    }
}

private fun eventDate(iso: String?): LocalDate? = parseZdt(iso)?.toLocalDate()
private fun timeLabel(iso: String): String = parseZdt(iso)?.format(FMT_DISPLAY) ?: iso
private fun dayLabel(iso: String?): String = parseZdt(iso)?.format(FMT_DAY) ?: ""

private fun buildStartAt(date: LocalDate, time: LocalTime): String =
    date.atTime(time).atZone(KST).toOffsetDateTime().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)

private fun parseKeywords(raw: String): List<String> =
    raw.split(",").map { it.trim() }.filter { it.isNotBlank() }

private fun openUrl(context: Context, url: String) {
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }
}

/** content:// URI 에서 표시 이름과 바이트를 읽는다 (작은 문서 파일 기준). */
private fun readUri(context: Context, uri: Uri): Pair<String, ByteArray>? {
    var name = "file"
    runCatching {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) c.getString(idx)?.let { name = it }
            }
        }
    }
    val bytes = runCatching {
        context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
    }.getOrNull() ?: return null
    return name to bytes
}

// =====================================================================
//  자료실 (Files)
// =====================================================================
private data class FileEntry(
    val name: String,
    val url: String?,
    val description: String,
    val keywords: List<String>,
    val by: String,
    val day: String,
    val fromCalendar: Boolean,
    val sortKey: String,
)

@Composable
fun FilesPane(vm: MoimViewModel, canUpload: Boolean, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var sort by remember { mutableStateOf("date") } // date | kw
    var pending by remember { mutableStateOf<Pair<String, ByteArray>?>(null) }

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) pending = readUri(context, uri)
    }

    val direct = vm.files.map {
        FileEntry(it.fileName, it.fileUrl, it.description.orEmpty(), it.keywords, vm.nameOf(it.uploadedBy),
            dayLabel(it.createdAt), false, it.createdAt.orEmpty())
    }
    val fromCal = vm.events.filter { !it.attachmentUrl.isNullOrBlank() }.map {
        FileEntry(it.attachmentName ?: "첨부파일", it.attachmentUrl, it.attachmentDesc ?: it.title,
            it.keywords, vm.nameOf(it.ownerId), dayLabel(it.startAt), true, it.startAt)
    }
    val all = direct + fromCal

    LazyColumn(modifier = modifier.fillMaxSize().padding(13.dp)) {
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SortButton("📅 날짜순", sort == "date", Modifier.weight(1f)) { sort = "date" }
                SortButton("🏷 키워드별", sort == "kw", Modifier.weight(1f)) { sort = "kw" }
            }
            Spacer(Modifier.height(12.dp))
            if (canUpload) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(13.dp))
                        .clickable { launcher.launch("*/*") }
                        .background(MoimWhite, RoundedCornerShape(13.dp))
                        .padding(14.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("⬆️ 파일 올리기", color = MoimSub, fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold)
                }
                Spacer(Modifier.height(13.dp))
            }
        }

        if (all.isEmpty()) {
            item {
                EmptyBoxInline("📁", "자료가 없습니다", "채팅·캘린더에 올린 자료가\n여기 모입니다.")
            }
        } else if (sort == "date") {
            val sorted = all.sortedByDescending { it.sortKey }
            items(sorted.size) { i -> FileCard(sorted[i], context) }
        } else {
            val groups = LinkedHashMap<String, MutableList<FileEntry>>()
            all.forEach { f ->
                val keys = if (f.keywords.isEmpty()) listOf("기타") else f.keywords
                keys.forEach { k -> groups.getOrPut(k) { mutableListOf() }.add(f) }
            }
            groups.forEach { (k, list) ->
                item {
                    Text(
                        "🏷 $k",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = catColor("research"),
                        modifier = Modifier.padding(top = 6.dp, bottom = 8.dp)
                    )
                }
                items(list.size) { i -> FileCard(list[i], context) }
            }
        }
    }

    pending?.let { (name, bytes) ->
        FileUploadDialog(
            fileName = name,
            onDismiss = { pending = null },
            onConfirm = { desc, kw ->
                vm.uploadFile(name, bytes, desc, kw) { pending = null }
            }
        )
    }
}

@Composable
private fun SortButton(label: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .background(if (on) MoimAccent else MoimWhite, RoundedCornerShape(10.dp))
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(label, fontSize = 12.5.sp, fontWeight = FontWeight.Bold, color = if (on) Color.White else MoimSub)
    }
}

@Composable
private fun FileCard(f: FileEntry, context: Context) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 9.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MoimWhite, RoundedCornerShape(12.dp))
            .clickable(enabled = f.url != null) { f.url?.let { openUrl(context, it) } }
            .padding(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(if (f.fromCalendar) catColor("research") else catColor("work"), RoundedCornerShape(11.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(if (f.fromCalendar) "📎" else "📄", fontSize = 18.sp)
        }
        Spacer(Modifier.width(11.dp))
        Column(Modifier.weight(1f)) {
            Text(f.name, fontSize = 13.5.sp, fontWeight = FontWeight.Bold, color = MoimInk, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (f.description.isNotBlank()) {
                Text(f.description, fontSize = 12.sp, color = MoimInk.copy(alpha = 0.75f), maxLines = 2, overflow = TextOverflow.Ellipsis)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("${f.by} · ${f.day}", fontSize = 11.sp, color = MoimSub)
                Spacer(Modifier.width(5.dp))
                Text(
                    if (f.fromCalendar) "캘린더" else "직접",
                    fontSize = 9.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = if (f.fromCalendar) catColor("research") else catColor("work"),
                    modifier = Modifier
                        .background(if (f.fromCalendar) Color(0xFFEFE7F5) else Color(0xFFE7F0EB), RoundedCornerShape(5.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                )
            }
            if (f.keywords.isNotEmpty()) {
                Row(modifier = Modifier.padding(top = 5.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    f.keywords.take(4).forEach { k ->
                        Text(
                            "#$k",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = catColor("research"),
                            modifier = Modifier
                                .background(Color(0xFFF0EAF6), RoundedCornerShape(10.dp))
                                .padding(horizontal = 7.dp, vertical = 2.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun FileUploadDialog(fileName: String, onDismiss: () -> Unit, onConfirm: (String, List<String>) -> Unit) {
    var desc by remember { mutableStateOf("") }
    var kw by remember { mutableStateOf("") }
    SheetDialog(title = "자료 올리기", subtitle = fileName, onDismiss = onDismiss) {
        FieldLabel("설명문")
        OutlinedTextField(desc, { desc = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("예: 발표 슬라이드 초안", color = MoimHint) }, shape = RoundedCornerShape(11.dp))
        FieldLabel("키워드 (쉼표로 구분)")
        OutlinedTextField(kw, { kw = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("코호트, 우울증", color = MoimHint) }, shape = RoundedCornerShape(11.dp))
        Spacer(Modifier.height(18.dp))
        PrimaryButton("업로드") { onConfirm(desc.trim(), parseKeywords(kw)) }
    }
}

// =====================================================================
//  캘린더 (Calendar)
// =====================================================================
@Composable
fun CalendarPane(vm: MoimViewModel, room: Room, canPost: Boolean, modifier: Modifier = Modifier) {
    val today = remember { LocalDate.now(KST) }
    var mode by remember { mutableStateOf(if (room.defaultView == "week") "week" else "month") }
    var ym by remember { mutableStateOf(YearMonth.from(today)) }
    var editing by remember { mutableStateOf<CalendarEvent?>(null) }
    var creating by remember { mutableStateOf(false) }

    LazyColumn(modifier = modifier.fillMaxSize().padding(13.dp)) {
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                ModeButton("금일", mode == "day", Modifier.weight(1f)) { mode = "day" }
                ModeButton("주간", mode == "week", Modifier.weight(1f)) { mode = "week" }
                ModeButton("월간", mode == "month", Modifier.weight(1f)) { mode = "month" }
            }
            Spacer(Modifier.height(13.dp))
            if (canPost) {
                Button(
                    onClick = { creating = true },
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
                    shape = RoundedCornerShape(12.dp)
                ) { Text("＋ 일정 추가", fontSize = 14.sp, fontWeight = FontWeight.Bold) }
                Spacer(Modifier.height(14.dp))
            }
        }

        when (mode) {
            "month" -> monthContent(this, vm, ym, today, { ym = it }, { editing = it })
            "week" -> weekContent(this, vm, today, { editing = it })
            else -> dayContent(this, vm, today, { editing = it })
        }
    }

    if (creating) {
        EventDialog(
            title = "일정 추가",
            initial = null,
            allowAttachment = true,
            onDismiss = { creating = false },
            onSubmit = { form ->
                vm.createEvent(
                    form.title, form.startAt, form.place, form.link, form.scope, form.description,
                    form.presenter, form.keywords, form.attachmentName, form.attachmentBytes, form.attachmentDesc,
                ) { creating = false }
            }
        )
    }
    editing?.let { ev ->
        EventDialog(
            title = "일정 수정",
            initial = ev,
            allowAttachment = true,
            onDismiss = { editing = null },
            onSubmit = { form ->
                vm.updateEvent(
                    ev.id, form.title, form.startAt, form.place, form.link, form.scope, form.description,
                    form.presenter, form.keywords, form.attachmentName, form.attachmentBytes, form.attachmentDesc,
                ) { editing = null }
            }
        )
    }
}

private fun monthContent(
    scope: androidx.compose.foundation.lazy.LazyListScope,
    vm: MoimViewModel,
    ym: YearMonth,
    today: LocalDate,
    onMonth: (YearMonth) -> Unit,
    onEdit: (CalendarEvent) -> Unit,
) {
    val monthEvents = vm.events.filter { eventDate(it.startAt)?.let { d -> YearMonth.from(d) == ym } == true }
    val eventDays = monthEvents.mapNotNull { eventDate(it.startAt)?.dayOfMonth }.toSet()

    scope.item {
        Row(
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("‹", fontSize = 20.sp, color = MoimSub, modifier = Modifier.clickable { onMonth(ym.minusMonths(1)) }.padding(horizontal = 8.dp))
            Text("${ym.year}년 ${ym.monthValue}월", fontSize = 16.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
            Text("›", fontSize = 20.sp, color = MoimSub, modifier = Modifier.clickable { onMonth(ym.plusMonths(1)) }.padding(horizontal = 8.dp))
        }
        // 요일 헤더
        Row(Modifier.fillMaxWidth()) {
            GRID_HEAD.forEach { d ->
                Text(d, fontSize = 11.sp, color = MoimSub, fontWeight = FontWeight.Bold,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center, modifier = Modifier.weight(1f).padding(vertical = 5.dp))
            }
        }
        // 날짜 셀 (일요일 시작)
        val lead = ym.atDay(1).dayOfWeek.value % 7
        val len = ym.lengthOfMonth()
        val cells = ArrayList<Int>()
        repeat(lead) { cells.add(0) }
        for (d in 1..len) cells.add(d)
        while (cells.size % 7 != 0) cells.add(0)
        cells.chunked(7).forEach { week ->
            Row(Modifier.fillMaxWidth()) {
                week.forEach { d ->
                    val isToday = d != 0 && ym.atDay(d) == today
                    Box(
                        modifier = Modifier.weight(1f).aspectRatio(1f).padding(2.dp)
                            .clip(RoundedCornerShape(9.dp))
                            .background(if (isToday) MoimYellow else Color.Transparent, RoundedCornerShape(9.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (d != 0) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("$d", fontSize = 13.sp, fontWeight = if (isToday) FontWeight.ExtraBold else FontWeight.Normal, color = MoimInk)
                                if (eventDays.contains(d)) {
                                    Box(Modifier.size(5.dp).background(MoimAdmin, RoundedCornerShape(3.dp)))
                                }
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        Text("이번 달 일정", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = MoimSub, modifier = Modifier.padding(bottom = 10.dp))
    }
    if (monthEvents.isEmpty()) {
        scope.item { NoEvents() }
    } else {
        val sorted = monthEvents.sortedBy { it.startAt }
        scope.items(sorted.size) { i -> EventCard(sorted[i], vm, onEdit) }
    }
}

private fun weekContent(
    scope: androidx.compose.foundation.lazy.LazyListScope,
    vm: MoimViewModel,
    today: LocalDate,
    onEdit: (CalendarEvent) -> Unit,
) {
    val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
    val sunday = monday.plusDays(6)
    scope.item {
        Text(
            "이번 주 · ${monday.format(FMT_DAY)}(월) ~ ${sunday.format(FMT_DAY)}(일)",
            fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = MoimSub, modifier = Modifier.padding(bottom = 10.dp)
        )
    }
    for (offset in 0..6) {
        val date = monday.plusDays(offset.toLong())
        val isToday = date == today
        val dayEvents = vm.events.filter { eventDate(it.startAt) == date }.sortedBy { it.startAt }
        scope.item {
            Row(
                modifier = Modifier.fillMaxWidth()
                    .background(if (isToday) Color(0xFFFFF8E0) else Color.Transparent, RoundedCornerShape(11.dp))
                    .padding(vertical = 9.dp, horizontal = 6.dp)
            ) {
                Column(modifier = Modifier.width(40.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(DOW_KO[offset], fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = if (isToday) MoimAdmin else MoimInk)
                    Text(date.format(FMT_DAY), fontSize = 10.5.sp, color = MoimSub)
                }
                Spacer(Modifier.width(10.dp))
                Column(Modifier.weight(1f)) {
                    if (dayEvents.isEmpty()) {
                        Text("— 일정 없음", fontSize = 12.sp, color = Color(0xFFC4BCB2), modifier = Modifier.padding(vertical = 7.dp))
                    } else {
                        dayEvents.forEach { EventCard(it, vm, onEdit) }
                    }
                }
            }
            HorizontalDivider(color = MoimLine.copy(alpha = 0.5f))
        }
    }
}

private fun dayContent(
    scope: androidx.compose.foundation.lazy.LazyListScope,
    vm: MoimViewModel,
    today: LocalDate,
    onEdit: (CalendarEvent) -> Unit,
) {
    val dayEvents = vm.events.filter { eventDate(it.startAt) == today }.sortedBy { it.startAt }
    scope.item {
        Text("금일 · ${today.format(FMT_DAY)}", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = MoimSub, modifier = Modifier.padding(bottom = 10.dp))
    }
    if (dayEvents.isEmpty()) {
        scope.item { NoEvents() }
    } else {
        scope.items(dayEvents.size) { i -> EventCard(dayEvents[i], vm, onEdit) }
    }
}

@Composable
private fun ModeButton(label: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .background(if (on) MoimYellow else MoimWhite, RoundedCornerShape(10.dp))
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(label, fontSize = 12.5.sp, fontWeight = FontWeight.Bold, color = if (on) MoimInk else MoimSub)
    }
}

@Composable
private fun EventCard(e: CalendarEvent, vm: MoimViewModel, onEdit: (CalendarEvent) -> Unit) {
    val context = LocalContext.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 9.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MoimWhite, RoundedCornerShape(12.dp))
            .padding(12.dp)
    ) {
        Box(Modifier.width(4.dp).height(56.dp).background(catColor("notice"), RoundedCornerShape(4.dp)))
        Spacer(Modifier.width(11.dp))
        Column(Modifier.weight(1f)) {
            Text(e.title, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = MoimInk)
            Text("📅 ${timeLabel(e.startAt)}", fontSize = 12.5.sp, color = MoimInk, modifier = Modifier.padding(top = 4.dp))
            e.place?.takeIf { it.isNotBlank() }?.let {
                Text("📍 $it", fontSize = 12.5.sp, color = MoimSub, modifier = Modifier.padding(top = 1.dp))
            }
            Text(
                "👤 발표자 ${e.presenter?.takeIf { it.isNotBlank() } ?: vm.nameOf(e.ownerId)}",
                fontSize = 12.5.sp, color = MoimSub, modifier = Modifier.padding(top = 1.dp)
            )
            e.scope?.takeIf { it.isNotBlank() }?.let {
                Text("참석 ${it}", fontSize = 11.5.sp, color = MoimSub, modifier = Modifier.padding(top = 1.dp))
            }
            e.description?.takeIf { it.isNotBlank() }?.let {
                Text(it, fontSize = 11.5.sp, color = MoimSub, modifier = Modifier.padding(top = 1.dp))
            }
            Row(modifier = Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                e.link?.takeIf { it.isNotBlank() }?.let { link ->
                    Text("🔗 링크", fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = catColor("group"),
                        modifier = Modifier
                            .background(Color(0xFFEEF2F8), RoundedCornerShape(8.dp))
                            .clickable { openUrl(context, link) }
                            .padding(horizontal = 10.dp, vertical = 4.dp))
                }
                if (!e.attachmentUrl.isNullOrBlank()) {
                    val url = e.attachmentUrl!!
                    Text("📎 첨부파일", fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = catColor("work"),
                        modifier = Modifier
                            .background(Color(0xFFE7F0EB), RoundedCornerShape(8.dp))
                            .clickable { openUrl(context, url) }
                            .padding(horizontal = 10.dp, vertical = 4.dp))
                }
                if (vm.canEditEvent(e)) {
                    Text("✏️ 수정", fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = MoimSub,
                        modifier = Modifier
                            .background(MoimBg, RoundedCornerShape(8.dp))
                            .clickable { onEdit(e) }
                            .padding(horizontal = 10.dp, vertical = 4.dp))
                }
            }
        }
    }
}

@Composable
private fun NoEvents() {
    Text("등록된 일정이 없습니다.", fontSize = 13.sp, color = MoimSub, modifier = Modifier.padding(vertical = 4.dp))
}

// =====================================================================
//  일정 추가/수정 다이얼로그
// =====================================================================
class EventForm(
    val title: String,
    val startAt: String,
    val place: String?,
    val link: String?,
    val scope: String?,
    val description: String?,
    val presenter: String?,
    val keywords: List<String>,
    val attachmentName: String?,
    val attachmentBytes: ByteArray?,
    val attachmentDesc: String?,
)

@Composable
private fun EventDialog(
    title: String,
    initial: CalendarEvent?,
    allowAttachment: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (EventForm) -> Unit,
) {
    val context = LocalContext.current
    val initZdt = initial?.let { parseZdt(it.startAt) }
    val initDate = initZdt?.toLocalDate() ?: LocalDate.now(KST)
    val initTime = initZdt?.toLocalTime() ?: LocalTime.of(9, 0)

    var evTitle by remember { mutableStateOf(initial?.title ?: "") }
    var dateStr by remember { mutableStateOf(initDate.format(DateTimeFormatter.ISO_LOCAL_DATE)) }
    var timeStr by remember { mutableStateOf("%02d:%02d".format(initTime.hour, initTime.minute)) }
    var place by remember { mutableStateOf(initial?.place ?: "") }
    var link by remember { mutableStateOf(initial?.link ?: "") }
    var scope by remember { mutableStateOf(initial?.scope ?: "") }
    var desc by remember { mutableStateOf(initial?.description ?: "") }
    var presenter by remember { mutableStateOf(initial?.presenter ?: "") }
    var attDesc by remember { mutableStateOf(initial?.attachmentDesc ?: "") }
    var att by remember { mutableStateOf<Pair<String, ByteArray>?>(null) }
    var err by remember { mutableStateOf<String?>(null) }

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) att = readUri(context, uri)
    }

    SheetDialog(title = title, subtitle = "참석범위·첨부자료까지 등록할 수 있습니다.", onDismiss = onDismiss) {
        FieldLabel("제목")
        OutlinedTextField(evTitle, { evTitle = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("예: 증례 컨퍼런스", color = MoimHint) }, singleLine = true, shape = RoundedCornerShape(11.dp))
        FieldLabel("날짜 · 시간")
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            OutlinedTextField(dateStr, { dateStr = it }, modifier = Modifier.weight(1f), placeholder = { Text("2026-06-05", color = MoimHint) }, singleLine = true, shape = RoundedCornerShape(11.dp))
            OutlinedTextField(timeStr, { timeStr = it }, modifier = Modifier.weight(1f), placeholder = { Text("14:00", color = MoimHint) }, singleLine = true, shape = RoundedCornerShape(11.dp))
        }
        FieldLabel("장소")
        OutlinedTextField(place, { place = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("의국 회의실", color = MoimHint) }, singleLine = true, shape = RoundedCornerShape(11.dp))
        FieldLabel("링크 (선택)")
        OutlinedTextField(link, { link = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("https://zoom.us/...", color = MoimHint) }, singleLine = true, shape = RoundedCornerShape(11.dp))
        FieldLabel("발표자 (이름·직위, 여러 명은 쉼표로)")
        OutlinedTextField(presenter, { presenter = it }, modifier = Modifier.fillMaxWidth().heightIn(min = 64.dp), placeholder = { Text("예: 김철수 교수, 박영희 전공의 3년차", color = MoimHint) }, shape = RoundedCornerShape(11.dp))
        FieldLabel("참석 범위")
        OutlinedTextField(scope, { scope = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("예: 의국 전공의 전원", color = MoimHint) }, singleLine = true, shape = RoundedCornerShape(11.dp))
        FieldLabel("설명")
        OutlinedTextField(desc, { desc = it }, modifier = Modifier.fillMaxWidth().heightIn(min = 64.dp), placeholder = { Text("안건 / 준비사항", color = MoimHint) }, shape = RoundedCornerShape(11.dp))

        if (allowAttachment) {
            FieldLabel("첨부 자료")
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(11.dp))
                    .clickable { launcher.launch("*/*") }
                    .background(MoimWhite, RoundedCornerShape(11.dp))
                    .padding(12.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    att?.first?.let { "📎 $it" }
                        ?: initial?.attachmentName?.let { "📎 현재: $it (교체하려면 선택)" }
                        ?: "📎 파일 첨부",
                    color = MoimSub, fontSize = 13.sp, fontWeight = FontWeight.SemiBold
                )
            }
            FieldLabel("첨부 자료 설명")
            OutlinedTextField(attDesc, { attDesc = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("예: 발표 슬라이드 초안", color = MoimHint) }, singleLine = true, shape = RoundedCornerShape(11.dp))
        } else {
            Spacer(Modifier.height(6.dp))
            Text("※ 첨부 파일은 일정 수정 시 변경할 수 없습니다.", fontSize = 11.sp, color = MoimSub, modifier = Modifier.padding(top = 8.dp))
        }

        err?.let {
            Text(it, color = MoimAdmin, fontSize = 12.sp, modifier = Modifier.padding(top = 10.dp))
        }

        Spacer(Modifier.height(18.dp))
        PrimaryButton(if (initial == null) "일정 등록" else "수정 저장") {
            if (evTitle.isBlank()) { err = "제목을 입력하세요"; return@PrimaryButton }
            val date = runCatching { LocalDate.parse(dateStr.trim()) }.getOrNull()
            val time = runCatching { LocalTime.parse(timeStr.trim()) }.getOrNull()
            if (date == null || time == null) { err = "날짜는 2026-06-05, 시간은 14:00 형식으로 입력하세요"; return@PrimaryButton }
            onSubmit(
                EventForm(
                    title = evTitle.trim(),
                    startAt = buildStartAt(date, time),
                    place = place.trim().takeIf { it.isNotBlank() },
                    link = link.trim().takeIf { it.isNotBlank() },
                    scope = scope.trim().takeIf { it.isNotBlank() },
                    description = desc.trim().takeIf { it.isNotBlank() },
                    presenter = presenter.trim().takeIf { it.isNotBlank() },
                    keywords = emptyList(),
                    attachmentName = att?.first,
                    attachmentBytes = att?.second,
                    attachmentDesc = attDesc.trim().takeIf { it.isNotBlank() },
                )
            )
        }
    }
}

// =====================================================================
//  공통 다이얼로그 셸 / 위젯
// =====================================================================
@Composable
private fun SheetDialog(title: String, subtitle: String, onDismiss: () -> Unit, content: @Composable () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(color = MoimPaper, shape = RoundedCornerShape(22.dp)) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 620.dp)
                    .verticalScroll(rememberScrollState())
                    .padding(20.dp)
            ) {
                Text(title, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, color = MoimInk)
                Text(subtitle, fontSize = 13.sp, color = MoimSub, modifier = Modifier.padding(top = 4.dp, bottom = 6.dp))
                content()
            }
        }
    }
}

@Composable
private fun FieldLabel(text: String) {
    Text(text, fontSize = 11.5.sp, fontWeight = FontWeight.Bold, color = MoimSub, letterSpacing = 0.4.sp,
        modifier = Modifier.padding(top = 14.dp, bottom = 7.dp))
}

@Composable
private fun PrimaryButton(label: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth().height(52.dp),
        colors = ButtonDefaults.buttonColors(containerColor = MoimAccent),
        shape = RoundedCornerShape(13.dp)
    ) { Text(label, fontSize = 15.sp, fontWeight = FontWeight.Bold) }
}

@Composable
private fun EmptyBoxInline(emoji: String, title: String, subtitle: String) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(emoji, fontSize = 38.sp)
        Spacer(Modifier.height(12.dp))
        Text(title, fontWeight = FontWeight.Bold, fontSize = 15.sp, color = MoimInk)
        Spacer(Modifier.height(6.dp))
        Text(subtitle, fontSize = 13.sp, color = MoimSub)
    }
}
