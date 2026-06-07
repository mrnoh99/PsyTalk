package com.example.moimtalk.data

import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** 반복 일정 시작 시각 목록 (첫 회 포함). rule: none | weekly | biweekly | monthly */
fun expandRepeatStartAts(baseStartAt: String, rule: String, count: Int): List<String> {
    if (rule == "none" || count <= 1) return listOf(baseStartAt)
    val kst = ZoneId.of("Asia/Seoul")
    val fmt = DateTimeFormatter.ISO_OFFSET_DATE_TIME
    val baseZdt = try {
        OffsetDateTime.parse(baseStartAt).atZoneSameInstant(kst)
    } catch (_: Exception) {
        try {
            LocalDateTime.parse(baseStartAt).atZone(kst)
        } catch (_: Exception) {
            return listOf(baseStartAt)
        }
    }
    val total = count.coerceIn(2, 52)
    return (0 until total).map { i ->
        val zdt = when (rule) {
            "weekly" -> baseZdt.plusWeeks(i.toLong())
            "biweekly" -> baseZdt.plusWeeks(i * 2L)
            "monthly" -> baseZdt.plusMonths(i.toLong())
            else -> baseZdt
        }
        zdt.toOffsetDateTime().format(fmt)
    }
}
