package com.example.moimtalk.ui

import androidx.compose.ui.graphics.Color
import com.example.moimtalk.data.CalendarEvent
import com.example.moimtalk.data.LastMsg
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Room

val MoimBg = Color(0xFFE9E4DD)
val MoimPaper = Color(0xFFF5F1EA)
val MoimInk = Color(0xFF231F1C)
val MoimSub = Color(0xFF8A817A)
val MoimAccent = Color(0xFF2B2825)
val MoimYellow = Color(0xFFFFE45C)
val MoimLine = Color(0xFFDCD5CC)
val MoimAdmin = Color(0xFFC0452F)
val MoimWhite = Color(0xFFFFFFFF)
val MoimHint = Color(0xFFC4BCB2)   // placeholder(예시) — 입력값과 헷갈리지 않게 연하게

fun catColor(category: String): Color = when (category) {
    "notice" -> Color(0xFFB5651D)
    "group" -> Color(0xFF4A6FA5)
    "work" -> Color(0xFF3D8361)
    "research" -> Color(0xFF6D597A)
    else -> MoimSub
}

fun catLabel(category: String): String = when (category) {
    "notice" -> "공지"
    "group" -> "그룹"
    "work" -> "업무"
    "research" -> "연구"
    "custom" -> "모임"
    else -> category
}

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

fun canPostInRoom(profile: Profile?, room: Room): Boolean {
    if (profile == null) return false
    if (isAdminRole(profile.role)) return true
    return room.postPolicy != "restricted"
}

/** 방 이름 변경 권한: 관리자(모든 방) 또는 방 생성자(본인이 만든 방) */
fun canRenameRoom(profile: Profile?, room: Room): Boolean {
    if (profile == null) return false
    if (isAdminRole(profile.role)) return true
    return room.createdBy != null && room.createdBy == MoimRepository.currentUserId()
}

/** 모임방 관리(구성원 초대·제거) 권한: 관리자는 모든 방, 그 외는 custom 방 생성자 */
fun canManageRoom(profile: Profile?, room: Room): Boolean {
    if (profile == null) return false
    if (isAdminRole(profile.role)) return true
    if (room.category != "custom") return false
    return room.createdBy != null && room.createdBy == MoimRepository.currentUserId()
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
        isSuperAdmin(profile.role) -> "전체관리자 · 전체 방"
        isAdminRole(profile.role) -> "관리자 · 전체 방"
        else -> "${profile.name}(${profile.memberType})"
    }
}
