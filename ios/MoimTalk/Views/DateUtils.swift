import Foundation

// =====================================================================
//  날짜·시간 유틸 (timestamptz <-> 한국시간) — Android CalendarFilesPanes.kt 와 동일 논리
// =====================================================================
enum CalDate {
    static let kst = TimeZone(identifier: "Asia/Seoul")!

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = kst
        return c
    }

    static func parse(_ iso: String?) -> Date? {
        guard let iso = iso, !iso.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }

    private static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = kst
        f.dateFormat = pattern
        return f
    }

    /// "6/5 오후 2:00"
    static func timeLabel(_ iso: String) -> String {
        guard let d = parse(iso) else { return iso }
        return fmt("M/d a h:mm").string(from: d)
    }

    /// "6/5"
    static func dayLabel(_ iso: String?) -> String {
        guard let iso = iso, let d = parse(iso) else { return "" }
        return fmt("M/d").string(from: d)
    }

    static func dayLabel(_ date: Date) -> String { fmt("M/d").string(from: date) }

    static func startOfDay(_ date: Date) -> Date { cal.startOfDay(for: date) }

    static func eventDay(_ iso: String?) -> Date? {
        guard let d = parse(iso) else { return nil }
        return cal.startOfDay(for: d)
    }

    static func sameDay(_ a: Date, _ b: Date) -> Bool { cal.isDate(a, inSameDayAs: b) }

    static func today() -> Date { cal.startOfDay(for: Date()) }

    /// 해당 주 월요일
    static func mondayOf(_ date: Date) -> Date {
        let weekday = cal.component(.weekday, from: date)  // 일=1 ... 토=7
        let backToMon = (weekday + 5) % 7                  // 월=0
        return cal.date(byAdding: .day, value: -backToMon, to: startOfDay(date))!
    }

    /// 날짜(연·월·일) + 시간(시·분) → ISO8601 timestamptz 문자열
    static func buildStartAt(date: Date, time: Date) -> String {
        let dc = cal.dateComponents([.year, .month, .day], from: date)
        let tc = cal.dateComponents([.hour, .minute], from: time)
        var merged = DateComponents()
        merged.year = dc.year; merged.month = dc.month; merged.day = dc.day
        merged.hour = tc.hour; merged.minute = tc.minute
        let d = cal.date(from: merged) ?? Date()
        let f = ISO8601DateFormatter()
        f.timeZone = kst
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
    }
}

func parseKeywords(_ raw: String) -> [String] {
    raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}
