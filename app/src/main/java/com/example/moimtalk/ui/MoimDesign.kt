package com.example.moimtalk.ui

import android.app.Activity
import android.content.Context
import android.os.Build
import androidx.compose.foundation.text.selection.TextSelectionColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.TextFieldColors
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import com.example.moimtalk.data.CalendarEvent
import com.example.moimtalk.data.LastMsg
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Room

// =====================================================================
//  화면 테마 — 🌙 다크(기본) / ☀️ 라이트 토글. 토큰은 팔레트에서 읽어 동적 전환.
// =====================================================================
data class MoimPalette(
    val bg: Color, val paper: Color, val surface: Color,
    val ink: Color, val sub: Color, val accent: Color, val secondary: Color,
    val yellow: Color, val line: Color, val admin: Color, val success: Color, val hint: Color,
    val hl: Color, val youBubble: Color,
)

private val DarkPalette = MoimPalette(
    bg = Color(0xFF161616), paper = Color(0xFF121212), surface = Color(0xFF1E1E1E),
    ink = Color(0xFFFFFFFF), sub = Color(0xFFBDBDBD), accent = Color(0xFF1E88E5), secondary = Color(0xFF00BCD4),
    yellow = Color(0xFFFFCA28), line = Color(0xFF2C2C2C), admin = Color(0xFFF44336), success = Color(0xFF4CAF50), hint = Color(0xFF6E6E6E),
    hl = Color(0xFF1E1E1E), youBubble = Color(0xFF3A3A3A),   // 다크 hl = surface(노란 톤 제거)
)
private val LightPalette = MoimPalette(
    bg = Color(0xFFECECEC), paper = Color(0xFFFFFFFF), surface = Color(0xFFF5F5F5),
    ink = Color(0xFF212121), sub = Color(0xFF757575), accent = Color(0xFF1976D2), secondary = Color(0xFF0097A7),
    yellow = Color(0xFFFFE45C), line = Color(0xFFE0E0E0), admin = Color(0xFFD32F2F), success = Color(0xFF388E3C), hint = Color(0xFFBDBDBD),
    hl = Color(0xFFFFF8E0), youBubble = Color(0xFFFFFFFF),
)

object MoimTheme {
    private var _dark by mutableStateOf(true)    // 기본=다크
    var dark: Boolean
        get() = _dark
        set(value) {
            _dark = value
            prefs?.edit()?.putBoolean("dark", value)?.apply()
        }
    private var prefs: android.content.SharedPreferences? = null
    val palette: MoimPalette get() = if (dark) DarkPalette else LightPalette
    fun init(ctx: Context) {
        prefs = ctx.getSharedPreferences("moim_theme", Context.MODE_PRIVATE)
        _dark = prefs?.getBoolean("dark", true) ?: true
    }
}

// 기존 토큰 이름 유지(사용처 변경 없음) — 팔레트에서 읽어 테마 전환 시 자동 recompose
val MoimBg: Color get() = MoimTheme.palette.bg
val MoimPaper: Color get() = MoimTheme.palette.paper
val MoimInk: Color get() = MoimTheme.palette.ink
val MoimSub: Color get() = MoimTheme.palette.sub
val MoimAccent: Color get() = MoimTheme.palette.accent
val MoimSecondary: Color get() = MoimTheme.palette.secondary
val MoimYellow: Color get() = MoimTheme.palette.yellow
val MoimLine: Color get() = MoimTheme.palette.line
val MoimAdmin: Color get() = MoimTheme.palette.admin
val MoimSuccess: Color get() = MoimTheme.palette.success
val MoimWhite: Color get() = MoimTheme.palette.surface   // 카드/표면(다크에선 어두운 surface)
val MoimHint: Color get() = MoimTheme.palette.hint
val MoimHl: Color get() = MoimTheme.palette.hl
val MoimYouBubble: Color get() = MoimTheme.palette.youBubble

/** 다크 모드 surface pill — 방목록 상단 3버튼(전체공지·병실현황·학술활동)과 동일 톤 */
fun moimDarkSegBg(): Color = MoimWhite
fun moimDarkSegText(selected: Boolean): Color = if (selected) MoimInk else MoimSub
fun moimDarkSegBorder(selected: Boolean = false): Color =
    if (MoimTheme.dark && selected) MoimSub else MoimLine

/** 다크 surface pill — 선택 시 테두리 밝게 */
fun moimToggleBorder(selected: Boolean): Color = moimDarkSegBorder(selected)

fun moimToggleBg(selected: Boolean, lightOn: Color, lightOff: Color = MoimWhite): Color =
    if (MoimTheme.dark) MoimWhite else if (selected) lightOn else lightOff

fun moimToggleText(selected: Boolean, lightOn: Color, lightOff: Color = MoimSub): Color =
    if (MoimTheme.dark) moimDarkSegText(selected) else if (selected) lightOn else lightOff

/** surface 위 강조 링크·라벨 — 다크에서는 ink(파란 accent 대신) */
fun moimSurfaceAccentText(): Color = if (MoimTheme.dark) MoimInk else MoimAccent

/** 상태바·네비게이션 바 — MoimTheme 다크/라이트와 동기화 */
@Composable
fun MoimSystemBars(darkTheme: Boolean = MoimTheme.dark) {
    val view = LocalView.current
    val paper = MoimTheme.palette.paper
    SideEffect {
        val window = (view.context as? Activity)?.window ?: return@SideEffect
        WindowCompat.setDecorFitsSystemWindows(window, true)
        @Suppress("DEPRECATION")
        window.statusBarColor = paper.toArgb()
        @Suppress("DEPRECATION")
        window.navigationBarColor = paper.toArgb()
        WindowCompat.getInsetsController(window, view).apply {
            isAppearanceLightStatusBars = !darkTheme
            isAppearanceLightNavigationBars = !darkTheme
        }
    }
}

/** OutlinedTextField — Moim 팔레트와 동기화(다크에서 검은 글자·보라 커서 방지) */
@Composable
fun moimOutlinedTextFieldColors(): TextFieldColors = OutlinedTextFieldDefaults.colors(
    focusedTextColor = MoimInk,
    unfocusedTextColor = MoimInk,
    disabledTextColor = MoimSub,
    errorTextColor = MoimAdmin,
    cursorColor = MoimAccent,
    focusedBorderColor = MoimAccent,
    unfocusedBorderColor = MoimLine,
    disabledBorderColor = MoimLine,
    errorBorderColor = MoimAdmin,
    focusedPlaceholderColor = MoimHint,
    unfocusedPlaceholderColor = MoimHint,
    focusedLabelColor = MoimSub,
    unfocusedLabelColor = MoimSub,
    disabledLabelColor = MoimHint,
    focusedContainerColor = MoimWhite,
    unfocusedContainerColor = MoimWhite,
    disabledContainerColor = MoimWhite,
    selectionColors = TextSelectionColors(
        handleColor = MoimAccent,
        backgroundColor = MoimAccent.copy(alpha = 0.28f),
    ),
)

fun catColor(category: String): Color = when (category) {
    "notice" -> Color(0xFFB5651D)
    "bugreport" -> Color(0xFF5C4D7A)
    "group" -> Color(0xFF4A6FA5)
    "work" -> Color(0xFF3D8361)
    "research" -> Color(0xFF6D597A)
    else -> MoimSub
}

// 방표식(아바타) 색상 팔레트 + 헬퍼
val ROOM_COLORS = listOf("#c7a008", "#4a6fa5", "#3d8361", "#b5651d", "#6d597a", "#c0452f", "#3a7ca5", "#d98b3a", "#5b8c5a", "#586b7d")
fun parseHexColor(hex: String?): Color? = hex?.let {
    try { Color(android.graphics.Color.parseColor(it)) } catch (_: Exception) { null }
}
/** 방표식 배경색: 커스텀 색상 우선, 없으면 카테고리 기본색 */
fun roomColor(room: Room): Color = parseHexColor(room.color) ?: catColor(room.category)

fun catLabel(category: String): String = when (category) {
    "notice" -> "공지"
    "bugreport" -> "BugReport"
    "group" -> "그룹"
    "work" -> "업무"
    "research" -> "연구"
    "custom" -> "모임"
    "direct" -> "1:1"
    else -> category
}

// 직군 정렬 순서 (직종별 보기 그룹 헤더 순서)
val MTYPE_ORDER = listOf("교실", "의국", "심리실", "연구실", "PA", "간호사", "SW", "보조원", "생명사랑", "비서", "의국동문", "심리실 동문", "기타")

/** 사람(프로필) 아바타 배경색: 커스텀 색상 우선, 없으면 직군색 (사진은 별도 처리) */
fun personColor(profile: Profile?): Color =
    parseHexColor(profile?.color) ?: typeColor(profile?.memberType ?: "")

// ── 1:1 DM 헬퍼 (dm_key 'a_b' 에서 상대 user id·프로필·표시이름 계산) ──
fun dmOtherId(room: Room): String? {
    val key = room.dmKey ?: return null
    val ids = key.split("_")
    if (ids.size < 2) return null
    val me = MoimRepository.currentUserId()
    return if (ids[0] == me) ids[1] else ids[0]
}

fun dmOther(room: Room, profiles: Map<String, Profile>): Profile? =
    dmOtherId(room)?.let { profiles[it] }

/** 방 표시 이름: DM 이면 상대 이름, 그 외에는 방 이름 */
fun roomDisplayName(room: Room, profiles: Map<String, Profile>): String =
    if (room.category == "direct") dmOther(room, profiles)?.name ?: "(알 수 없음)" else room.name

/** DM = 채팅 전용 (캘린더·자료실 탭, 이름변경·설정·나가기 모두 숨김) */
fun isDirect(room: Room): Boolean = room.category == "direct"

/** BugReport 고정 방 id (승인·미탈퇴 전원 구성원) */
const val BUG_REPORT_ROOM_ID = "11111111-1111-1111-1111-111111110013"

fun bugReportRoom(rooms: List<Room>): Room? =
    rooms.find { it.id == BUG_REPORT_ROOM_ID }

fun isBugReportRoom(room: Room): Boolean =
    room.id == BUG_REPORT_ROOM_ID

/** BugReport 작성 시 OS·기기 정보가 채워진 기본 템플릿 */
fun bugReportDraft(): String {
    val platform = "Android"
    val device = listOf(Build.MANUFACTURER, Build.MODEL)
        .filter { it.isNotBlank() }
        .joinToString(" ")
        .trim()
        .ifBlank { "알 수 없음" }
    val os = "Android ${Build.VERSION.RELEASE}"
    return """[환경]
플랫폼: $platform
기기: $device
OS: $os

[증상]


[재현 방법]
1. 

[기대 동작]


[실제 동작]

"""
}

/** BugReport 템플릿 — 전체관리자(superadmin)는 빈 입력창 */
fun bugReportDraftFor(role: String?): String =
    if (isSuperAdmin(role.orEmpty())) "" else bugReportDraft()

/** BugReport 방 새글 표시 — 전체관리자만 */
fun bugReportUnreadVisible(role: String?): Boolean = role == "superadmin"

fun effectiveRoomUnread(roomId: String, count: Int, role: String?): Int =
    if (roomId == BUG_REPORT_ROOM_ID && !bugReportUnreadVisible(role)) 0 else count

fun effectiveMsgUnread(roomId: String, count: Int, role: String?): Int =
    if (roomId == BUG_REPORT_ROOM_ID && !bugReportUnreadVisible(role)) 0 else count

/** 주간 학술활동(default_view=week) — 입장 시 캘린더·주간 보기가 기본 */
fun opensWeekCalendar(room: Room): Boolean =
    room.category != "custom" && room.category != "direct" && !isBugReportRoom(room) && room.defaultView == "week"

/** 일정 발표자 표시 — 미입력 시 작성자로 대체하지 않음 */
fun eventPresenterLabel(presenter: String?): String =
    presenter?.trim()?.takeIf { it.isNotBlank() } ?: "미정"

/** 과 전체공지 방 = 항상 방 목록 맨 위 고정(핀·정렬 변경 불가). 모임·DM·주간(week)·BugReport 제외. */
fun noticeTopRoom(rooms: List<Room>): Room? =
    rooms.filter { it.category != "custom" && it.category != "direct" && !isBugReportRoom(it) && it.defaultView != "week" }
        .minByOrNull { it.sortOrder }

/** 방 구성원 id 정렬 — 개설자(created_by) 맨 앞, 나머지 가나다순 */
fun orderedRoomMemberIds(room: Room, memberIds: List<String>, profiles: Map<String, Profile>): List<String> {
    val collator = java.text.Collator.getInstance(java.util.Locale.KOREAN)
    val creator = room.createdBy
    return buildList {
        if (creator != null && memberIds.contains(creator)) add(creator)
        addAll(memberIds.filter { it != creator }.sortedWith { a, b ->
            collator.compare(profiles[a]?.name ?: "", profiles[b]?.name ?: "")
        })
    }
}

/** 방 구성원 이름 나열 — 개설자(created_by)를 맨 앞에, 나머지는 이름순. 표시는 ... 잘림은 UI 가 처리. */
fun roomMemberNames(room: Room, memberIds: List<String>, profiles: Map<String, Profile>): List<String> =
    orderedRoomMemberIds(room, memberIds, profiles).mapNotNull { id -> profiles[id]?.name }

fun typeColor(memberType: String): Color = when (memberType) {
    "교실" -> Color(0xFFB5651D)
    "의국" -> Color(0xFF4A6FA5)
    "심리실" -> Color(0xFF6D597A)
    "연구실" -> Color(0xFF3D8361)
    "PA" -> Color(0xFF0D8A8A)
    "간호사" -> Color(0xFFC0452F)
    "SW" -> Color(0xFF9A6A00)
    "보조원" -> Color(0xFF777777)
    "생명사랑" -> Color(0xFF1F9B8E)
    "비서" -> Color(0xFFA0526D)
    "의국동문" -> Color(0xFF5B7C99)
    "심리실 동문" -> Color(0xFF8A7AA0)
    "기타" -> Color(0xFF8A817A)
    else -> MoimSub
}

fun isAdminRole(role: String): Boolean = role == "superadmin" || role == "admin"

fun isSuperAdmin(role: String): Boolean = role == "superadmin"

/** 가입 승인 대기(미승인·미탈퇴, superadmin 제외) — approved 가 true 가 아니면 대기 */
fun isSignupPending(p: Profile): Boolean =
    p.role != "superadmin" && p.withdrawn != true && p.approved != true

/** 승인된 활성 회원(superadmin 제외) */
fun isApprovedMember(p: Profile): Boolean =
    p.role != "superadmin" && p.withdrawn != true && p.approved == true

/** 비활성(탈퇴) 회원 — 복구 대상 */
fun isWithdrawnMember(p: Profile): Boolean =
    p.role != "superadmin" && p.withdrawn == true

/** 비서 직군: 가입 승인 + 전체공지 작성 가능(관리자에 준함) */
fun canApprove(profile: Profile?): Boolean {
    if (profile == null) return false
    return isAdminRole(profile.role) || profile.memberType == "비서"
}

fun canPostInRoom(profile: Profile?, room: Room): Boolean {
    if (profile == null) return false
    if (isAdminRole(profile.role) || profile.memberType == "비서") return true
    return room.postPolicy != "restricted"
}

/** 방 이름 변경 권한: 기본 방(과 전체공지·주간 학술활동 등 비-모임방)은 전체관리자만,
 *  모임방(custom)은 관리자 또는 생성자(본인이 만든 방) */
fun canRenameRoom(profile: Profile?, room: Room): Boolean {
    if (profile == null) return false
    if (room.category != "custom") return isSuperAdmin(profile.role)
    if (isAdminRole(profile.role)) return true
    return room.createdBy != null && room.createdBy == MoimRepository.currentUserId()
}

/** 모임방 관리(구성원 초대·제거) 권한: 관리자는 모든 방, 그 외는 custom 방 생성자 */
fun canManageRoom(profile: Profile?, room: Room): Boolean {
    if (profile == null) return false
    // 기본 방(과 전체공지·주간 학술활동 등 비-모임방)의 설정(⚙️)은 전체관리자만
    if (room.category != "custom") return isSuperAdmin(profile.role)
    if (isAdminRole(profile.role)) return true
    return room.createdBy != null && room.createdBy == MoimRepository.currentUserId()
}

/** 방 나가기 권한: 본인이 만들지 않은 모임방(custom) — 관리자·생성자가 아닌 경우 */
fun canLeaveRoom(profile: Profile?, room: Room): Boolean {
    if (profile == null || room.category != "custom") return false
    return !canManageRoom(profile, room)
}

/** 방 삭제 권한: 모임방(custom)에 한해 생성자(본인이 만든 방) 또는 전체관리자(superadmin) */
fun canDeleteRoom(profile: Profile?, room: Room): Boolean {
    if (profile == null || room.category != "custom") return false
    if (isSuperAdmin(profile.role)) return true
    return room.createdBy != null && room.createdBy == MoimRepository.currentUserId()
}

/** ward 편집 권한: 관리자 또는 직군 교실·의국·간호사("병동") */
fun canEditWard(profile: Profile?): Boolean {
    if (profile == null) return false
    return isAdminRole(profile.role) || profile.memberType in listOf("교실", "의국", "간호사")
}

/** 당직표 입력·수정 권한: 관리자 또는 직군 교실·의국·비서 */
fun canEditWardDuty(profile: Profile?): Boolean {
    if (profile == null) return false
    return isAdminRole(profile.role) || profile.memberType in listOf("교실", "의국", "비서")
}

/** 휴일(주말·공휴일) — 전공의 당직 1인만 */
fun isWardDutyOffDay(date: java.time.LocalDate): Boolean = wardDutyTone(date) != WardDutyTone.WEEKDAY

enum class WardDutyTone { WEEKDAY, WEEKEND, PUBLIC_HOLIDAY }

/** 당직표 날짜 톤 — 평일 / 주말 / 대한민국 공휴일 */
fun wardDutyTone(date: java.time.LocalDate): WardDutyTone = when {
    com.example.moimtalk.data.KrHolidays.isPublicHoliday(date) -> WardDutyTone.PUBLIC_HOLIDAY
    date.dayOfWeek == java.time.DayOfWeek.SATURDAY || date.dayOfWeek == java.time.DayOfWeek.SUNDAY -> WardDutyTone.WEEKEND
    else -> WardDutyTone.WEEKDAY
}

/** 교원 표시 — 이름 + 교수님 */
fun dutyProfDisplay(name: String?): String =
    name?.takeIf { it.isNotBlank() }?.let { "$it 교수님" } ?: "—"

/** 전공의 표시 — 이름만 */
fun dutyResidentDisplay(name: String?): String =
    name?.takeIf { it.isNotBlank() } ?: "—"

fun dutyOutpatientDisplay(
    out1: String?,
    out2: String?,
): String {
    val names = listOfNotNull(out1?.takeIf { it.isNotBlank() }, out2?.takeIf { it.isNotBlank() })
    return names.joinToString(", ").ifBlank { "—" }
}

/** 오늘 당직 한 줄 미리보기 */
fun dutyTodayPreview(
    profDay: String?,
    residentDay: String?,
    residentNight: String?,
    out1: String?,
    out2: String?,
    offDay: Boolean,
): String {
    val prof = dutyProfDisplay(profDay)
    return if (offDay) {
        "$prof  ·  당직 ${dutyResidentDisplay(residentNight)}"
    } else {
        "$prof  ·  낮 ${dutyResidentDisplay(residentDay)}  ·  당직 ${dutyResidentDisplay(residentNight)}  ·  외래 ${dutyOutpatientDisplay(out1, out2)}"
    }
}

/** 오늘 당직 카드 — 당직표 행(surface)과 살짝 구분되는 배경 */
fun wardDutyTodayCardColors(): Pair<Color, Color> =
    if (MoimTheme.dark) Color(0xFF262626) to moimDarkSegBorder()
    else MoimAccent.copy(alpha = 0.12f) to MoimAccent.copy(alpha = 0.35f)

/** 주말·공휴일 당직표 행 배경·테두리 — 다크: 평일(surface)에 가깝게, 라이트: 연한 라벤더 */
fun wardDutyOffDayRowColors(): Pair<Color, Color> = if (MoimTheme.dark) {
    Color(0xFF212121) to MoimLine
} else {
    Color(0xFFF3F1F8) to Color(0xFFE4E0EC)
}

/** 주말·공휴일 날짜 라벨 색 */
fun wardDutyOffDayInk(): Color = if (MoimTheme.dark) MoimInk else Color(0xFF6D5E58)

/** 주말·공휴일 뱃지(주말/공휴일) 색 */
fun wardDutyToneBadge(): Color = if (MoimTheme.dark) MoimSub else Color(0xFF8A7E96)

/** 당직표 행 배경·테두리 (주말·공휴일 동일 톤) */
fun wardDutyRowColors(tone: WardDutyTone, isToday: Boolean): Pair<Color, Color> {
    val (bg, border) = when (tone) {
        WardDutyTone.PUBLIC_HOLIDAY, WardDutyTone.WEEKEND -> wardDutyOffDayRowColors()
        WardDutyTone.WEEKDAY -> MoimWhite to MoimLine
    }
    val todayBorder = if (isToday) (if (MoimTheme.dark) MoimSub else MoimAccent) else border
    return bg to todayBorder
}

/** 승인·활성 회원 중 직군 필터 (당직 선택용) */
fun dutyMembersByType(profiles: Map<String, Profile>, memberType: String): List<Profile> =
    profiles.values
        .filter { it.memberType == memberType && (it.approved ?: true) && it.withdrawn != true }
        .sortedBy { it.name }

/** 일정 삭제 권한: 작성자 본인 / 관리자 / 직군 교실·의국·비서·심리실 */
fun canDeleteEvent(profile: Profile?, event: CalendarEvent): Boolean {
    if (profile == null) return false
    if (event.ownerId == MoimRepository.currentUserId()) return true
    return isAdminRole(profile.role) || profile.memberType in listOf("교실", "의국", "비서", "심리실")
}

// ── 시간/날짜/미리보기 표시 헬퍼 ──
private val KST_ZONE = java.time.ZoneId.of("Asia/Seoul")
private fun zdt(createdAt: String?) =
    java.time.OffsetDateTime.parse(createdAt).atZoneSameInstant(KST_ZONE)

/** 메시지 시간 HH:mm */
fun fmtMsgTime(createdAt: String?): String = runCatching {
    zdt(createdAt).format(java.time.format.DateTimeFormatter.ofPattern("HH:mm"))
}.getOrDefault("")

/** 방 목록 시간: 오늘=HH:mm, 이전=M/d */
fun fmtListTime(createdAt: String?): String = runCatching {
    val z = zdt(createdAt)
    if (z.toLocalDate() == java.time.LocalDate.now(KST_ZONE))
        z.format(java.time.format.DateTimeFormatter.ofPattern("HH:mm"))
    else "${z.monthValue}/${z.dayOfMonth}"
}.getOrDefault("")

/** 날짜 구분선 라벨 */
fun fmtDateDivider(createdAt: String?): String = runCatching {
    val z = zdt(createdAt)
    val w = listOf("일", "월", "화", "수", "목", "금", "토")[z.dayOfWeek.value % 7]
    "${z.year}년 ${z.monthValue}월 ${z.dayOfMonth}일 ${w}요일"
}.getOrDefault("")

/** 같은 날 판별용 키 */
fun dayKey(createdAt: String?): String = runCatching {
    zdt(createdAt).toLocalDate().toString()
}.getOrDefault("")

private val PUBLISH_DOW = listOf("월", "화", "수", "목", "금", "토", "일")

/** 공지·게시 카드용 — "6/7 (토) 오후 2:30" */
fun fmtPublishTime(createdAt: String?): String = runCatching {
    val z = zdt(createdAt)
    val dow = PUBLISH_DOW[z.dayOfWeek.value - 1]
    val d = "${z.monthValue}/${z.dayOfMonth}"
    val t = z.format(java.time.format.DateTimeFormatter.ofPattern("a h:mm", java.util.Locale.KOREAN))
    "$d ($dow) $t"
}.getOrDefault("")

fun isNoticeTopRoom(room: Room, rooms: List<Room>): Boolean =
    noticeTopRoom(rooms)?.id == room.id

/** 방 헤더에 구성원 이름 줄 표시 — 모임방 등만(과 전체공지·DM 제외) */
fun showRoomHeaderMembers(room: Room, rooms: List<Room>): Boolean =
    room.category != "direct" && !isNoticeTopRoom(room, rooms)

/** 과 전체공지 — 텍스트+첨부가 연속으로 온 경우 한 카드로 합침 (기존 분리 전송 호환) */
fun mergeNoticeMessages(messages: List<Message>): List<Message> {
    if (messages.isEmpty()) return messages
    val out = mutableListOf<Message>()
    var i = 0
    while (i < messages.size) {
        val m = messages[i]
        val n = messages.getOrNull(i + 1)
        if (n != null && m.senderId == n.senderId) {
            if (m.type == "text" && (n.type == "image" || n.type == "file") && n.content.isNullOrBlank()) {
                out.add(n.copy(content = m.content))
                i += 2
                continue
            }
            if ((m.type == "image" || m.type == "file") && m.content.isNullOrBlank() && n.type == "text" && n.attachmentUrl == null) {
                out.add(m.copy(content = n.content))
                i += 2
                continue
            }
        }
        out.add(m)
        i++
    }
    return out
}

/** 마지막 메시지 미리보기 */
fun msgPreview(lm: LastMsg?): String {
    if (lm == null) return ""
    return when (lm.type) {
        "image" -> "사진"
        "file" -> "📎 ${lm.attachmentName ?: "파일"}"
        else -> lm.content.orEmpty()
    }
}

fun viewBadgeText(profile: Profile?): String {
    if (profile == null) return "정신건강의학과"
    return when {
        isSuperAdmin(profile.role) -> "전체관리자"
        isAdminRole(profile.role) -> "관리자 · 전체 방"
        else -> "${profile.name}(${profile.memberType})"
    }
}

private val URL_IN_TEXT = Regex("""https?://[^\s<>"']+""")

/** 공지 본문 — http(s) URL 을 탭 가능한 링크로 */
fun linkifyAnnotatedString(text: String): AnnotatedString = buildAnnotatedString {
    var last = 0
    for (match in URL_IN_TEXT.findAll(text)) {
        append(text.substring(last, match.range.first))
        val url = match.value
        val start = length
        withLink(LinkAnnotation.Url(url)) { append(url) }
        addStyle(SpanStyle(color = MoimAccent, textDecoration = TextDecoration.Underline), start, length)
        last = match.range.last + 1
    }
    append(text.substring(last))
}
