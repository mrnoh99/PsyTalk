import Foundation

/// 대한민국 공휴일 (주말 제외·대체공휴일 포함, 2025~2027)
enum KrHolidays {
    private static let fixedMonthDay: Set<String> = [
        "01-01", "03-01", "05-05", "06-06", "08-15", "10-03", "10-09", "12-25",
    ]
    private static let extra: Set<String> = [
        "2025-01-28", "2025-01-29", "2025-01-30", "2025-05-06",
        "2025-10-06", "2025-10-07", "2025-10-08", "2025-10-09",
        "2026-02-16", "2026-02-17", "2026-02-18", "2026-05-24",
        "2026-09-24", "2026-09-25", "2026-09-26", "2026-10-05",
        "2027-02-06", "2027-02-07", "2027-02-08", "2027-02-09",
        "2027-05-13", "2027-09-14", "2027-09-15", "2027-09-16",
        "2027-10-04", "2027-10-11",
    ]

    static func isPublicHoliday(_ date: Date) -> Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = CalDate.kst
        let key = f.string(from: date)
        if extra.contains(key) { return true }
        let y = CalDate.cal.component(.year, from: date)
        guard (2025...2027).contains(y) else { return false }
        f.dateFormat = "MM-dd"
        return fixedMonthDay.contains(f.string(from: date))
    }
}
