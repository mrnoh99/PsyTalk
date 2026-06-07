package com.example.moimtalk.data

import java.time.LocalDate
import java.time.MonthDay

/** 대한민국 공휴일 (주말 제외·대체공휴일 포함, 2025~2027) */
object KrHolidays {
    private val fixedAnnual = setOf(
        MonthDay.of(1, 1),
        MonthDay.of(3, 1),
        MonthDay.of(5, 5),
        MonthDay.of(6, 6),
        MonthDay.of(8, 15),
        MonthDay.of(10, 3),
        MonthDay.of(10, 9),
        MonthDay.of(12, 25),
    )

    private val lunarAndSubstitute = setOf(
        // 2025
        "2025-01-28", "2025-01-29", "2025-01-30",
        "2025-05-06",
        "2025-10-06", "2025-10-07", "2025-10-08", "2025-10-09",
        // 2026
        "2026-02-16", "2026-02-17", "2026-02-18",
        "2026-05-24",
        "2026-09-24", "2026-09-25", "2026-09-26",
        "2026-10-05",
        // 2027
        "2027-02-06", "2027-02-07", "2027-02-08", "2027-02-09",
        "2027-05-13",
        "2027-09-14", "2027-09-15", "2027-09-16",
        "2027-10-04", "2027-10-11",
    )

    fun isPublicHoliday(date: LocalDate): Boolean {
        if (date.toString() in lunarAndSubstitute) return true
        if (date.year in 2025..2027 && fixedAnnual.contains(MonthDay.from(date))) return true
        return false
    }
}
