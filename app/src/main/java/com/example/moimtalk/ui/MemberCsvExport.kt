package com.example.moimtalk.ui

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import com.example.moimtalk.data.Profile
import java.io.File
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

/** 회원 명단 CSV(UTF-8 BOM) — 웹 `downloadMembersExcel()` 과 동일 */
object MemberCsvExport {
    private fun csvCell(v: String?): String {
        val s = v ?: ""
        return if (s.any { it == '"' || it == ',' || it == '\n' || it == '\r' }) {
            "\"${s.replace("\"", "\"\"")}\""
        } else s
    }

    private fun deviceLabel(t: String?) = when (t) {
        "iphone" -> "아이폰"
        "android" -> "안드로이드"
        else -> ""
    }

    private fun roleLbl(role: String) = when (role) {
        "superadmin" -> "전체관리자"
        "admin" -> "관리자"
        else -> "회원"
    }

    private fun fmtDate(s: String?): String {
        if (s.isNullOrBlank()) return ""
        return runCatching {
            OffsetDateTime.parse(s).format(DateTimeFormatter.ofPattern("yyyy-MM-dd"))
        }.getOrElse { s.take(10) }
    }

    fun buildCsv(profiles: Collection<Profile>): String {
        val header = listOf(
            "이름", "직군", "역할", "로그인 이메일", "핸드폰번호", "핸드폰 종류",
            "연결 이메일(앱설치)", "자기소개", "승인", "가입일", "핸드폰 최종변경일",
        )
        val rows = profiles.filter { it.withdrawn != true }.sortedBy { it.name }
        val lines = mutableListOf(header.joinToString(","))
        for (p in rows) {
            lines.add(
                listOf(
                    p.name, p.memberType, roleLbl(p.role), p.email, p.phone,
                    deviceLabel(p.deviceType), p.deviceEmail, p.intro,
                    if (p.approved == true) "승인" else "대기",
                    fmtDate(p.createdAt), fmtDate(p.phoneUpdatedAt),
                ).map { csvCell(it) }.joinToString(","),
            )
        }
        return "\uFEFF" + lines.joinToString("\r\n")
    }

    fun share(context: Context, profiles: Collection<Profile>) {
        val ymd = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"))
        val file = File(context.cacheDir, "아주정신_회원명단_$ymd.csv")
        file.writeText(buildCsv(profiles), Charsets.UTF_8)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/csv"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "회원 명단 저장"))
    }
}
