import UIKit

// 회원 명단 CSV(UTF-8 BOM) — 웹 `downloadMembersExcel()` 과 동일
enum MemberCsvExport {
    private static func csvCell(_ v: String?) -> String {
        let s = v ?? ""
        if s.contains(where: { $0 == "\"" || $0 == "," || $0 == "\n" || $0 == "\r" }) {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }

    private static func deviceLabel(_ t: String?) -> String {
        switch t {
        case "iphone": return "아이폰"
        case "android": return "안드로이드"
        default: return ""
        }
    }

    private static func parseISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    private static func fmtDate(_ s: String?) -> String {
        guard let s, !s.isEmpty else { return "" }
        if let d = parseISO(s) {
            let f = DateFormatter()
            f.timeZone = TimeZone(identifier: "Asia/Seoul")
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d)
        }
        return String(s.prefix(10))
    }

    static func buildCsv(profiles: [Profile]) -> String {
        let header = [
            "이름", "직군", "역할", "로그인 이메일", "핸드폰번호", "핸드폰 종류",
            "연결 이메일(앱설치)", "자기소개", "승인", "가입일", "핸드폰 최종변경일",
        ]
        let rows = profiles.filter { $0.withdrawn != true }.sorted { $0.name < $1.name }
        var lines = [header.joined(separator: ",")]
        for p in rows {
            let approved = (p.approved == true) ? "승인" : "대기"
            lines.append([
                p.name, p.memberType, roleLabel(p.role), p.email, p.phone,
                deviceLabel(p.deviceType), p.deviceEmail, p.intro, approved,
                fmtDate(p.createdAt), fmtDate(p.phoneUpdatedAt),
            ].map { csvCell($0) }.joined(separator: ","))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n")
    }

    static func share(profiles: [Profile]) {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyyMMdd"
        let ymd = f.string(from: Date())
        let fileName = "아주정신_회원명단_\(ymd).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try buildCsv(profiles: profiles).write(to: url, atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                      let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
                let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let pop = vc.popoverPresentationController {
                    pop.sourceView = root.view
                    pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
                }
                root.present(vc, animated: true)
            }
        } catch {}
    }
}
