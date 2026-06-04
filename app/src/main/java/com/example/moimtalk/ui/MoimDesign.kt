package com.example.moimtalk.ui

import androidx.compose.ui.graphics.Color
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

fun viewBadgeText(profile: Profile?): String {
    if (profile == null) return "정신건강의학과"
    return when {
        isSuperAdmin(profile.role) -> "전체관리자 · 전체 방"
        isAdminRole(profile.role) -> "관리자 · 전체 방"
        else -> "${profile.name}(${profile.memberType})"
    }
}
