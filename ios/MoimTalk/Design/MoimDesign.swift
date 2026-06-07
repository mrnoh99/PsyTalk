import SwiftUI

// =====================================================================
//  색상·라벨·권한 헬퍼 — Android MoimDesign.kt 와 동일
// =====================================================================
extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
    /// "#4a6fa5" 형태의 hex 문자열에서 색상 생성
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(hex: v)
    }
}

// 방표식(아바타) 색상 팔레트 + 헬퍼
let ROOM_COLORS = ["#c7a008", "#4a6fa5", "#3d8361", "#b5651d", "#6d597a", "#c0452f", "#3a7ca5", "#d98b3a", "#5b8c5a", "#586b7d"]
func roomColor(_ room: Room) -> Color { (room.color.flatMap { Color(hexString: $0) }) ?? catColor(room.category) }

// 직종별 정렬 순서 (회원 검색·회원 관리 그룹 순서) — web MTYPE_ORDER 와 동일
let MTYPE_ORDER = ["교실", "의국", "심리실", "연구실", "PA", "간호사", "SW", "보조원", "생명사랑", "비서", "의국동문", "심리실 동문", "기타"]

/// 사람(프로필) 아바타 색상: 사진이 없을 때 → 본인 지정 색상 > 직군색
func personColor(_ p: Profile?) -> Color {
    guard let p = p else { return Moim.sub }
    return (p.color.flatMap { Color(hexString: $0) }) ?? typeColor(p.memberType)
}

/// 이름 머리글자 (아바타용) — 앞 3글자
func initials(_ name: String?) -> String { String((name ?? "?").prefix(3)) }

/// 이름 한국어 로케일 정렬 비교
func byName(_ a: Profile, _ b: Profile) -> Bool {
    a.name.localizedCompare(b.name) == .orderedAscending
}

/// BugReport 고정 방 id (승인·미탈퇴 전원 구성원)
let BUG_REPORT_ROOM_ID = "11111111-1111-1111-1111-111111110013"

func bugReportRoom(_ rooms: [Room]) -> Room? {
    rooms.first { $0.id == BUG_REPORT_ROOM_ID }
}

func isBugReportRoom(_ room: Room) -> Bool {
    room.id == BUG_REPORT_ROOM_ID
}

private func bugReportMachineId() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(cString: $0)
        }
    }
}

/// BugReport 작성 시 OS·기기 정보가 채워진 기본 템플릿
func bugReportDraft() -> String {
    let platform = "iOS"
    let device = UIDevice.current
    let kind = device.model
    let machine = bugReportMachineId()
    let deviceLine = machine.isEmpty ? kind : "\(kind) (\(machine))"
    let os = "iOS \(device.systemVersion)"
    return """
[환경]
플랫폼: \(platform)
기기: \(deviceLine)
OS: \(os)

[증상]


[재현 방법]
1. 

[기대 동작]


[실제 동작]

"""
}

/// BugReport 템플릿 — 전체관리자(superadmin)는 빈 입력창
func bugReportDraftFor(role: String?) -> String {
    isSuperAdmin(role ?? "") ? "" : bugReportDraft()
}

/// BugReport 방 새글 표시 — 전체관리자만
func bugReportUnreadVisible(role: String?) -> Bool {
    role == "superadmin"
}

func effectiveRoomUnread(roomId: String, count: Int, role: String?) -> Int {
    if roomId == BUG_REPORT_ROOM_ID && !bugReportUnreadVisible(role: role) { return 0 }
    return count
}

func effectiveMsgUnread(roomId: String, count: Int, role: String?) -> Int {
    if roomId == BUG_REPORT_ROOM_ID && !bugReportUnreadVisible(role: role) { return 0 }
    return count
}

/// 주간 학술활동(default_view=week) — 입장 시 캘린더·주간 보기가 기본
func opensWeekCalendar(_ room: Room) -> Bool {
    room.category != "custom" && room.category != "direct" && !isBugReportRoom(room) && room.defaultView == "week"
}

/// 과 전체공지 방 = 항상 방 목록 맨 위 고정(핀·정렬 변경 불가). 모임·DM·주간(week)·BugReport 제외.
func noticeTopRoom(_ rooms: [Room]) -> Room? {
    rooms.filter { $0.category != "custom" && $0.category != "direct" && !isBugReportRoom($0) && $0.defaultView != "week" }
        .min { $0.sortOrder < $1.sortOrder }
}

func isNoticeTopRoom(_ room: Room, _ rooms: [Room]) -> Bool {
    noticeTopRoom(rooms)?.id == room.id
}

/// 방 헤더에 구성원 이름 줄 표시 — 모임방 등만(과 전체공지·DM 제외)
func showRoomHeaderMembers(_ room: Room, _ rooms: [Room]) -> Bool {
    room.category != "direct" && !isNoticeTopRoom(room, rooms)
}

/// 방 구성원 id 정렬 — 개설자(createdBy) 맨 앞, 나머지 가나다순
func orderedRoomMemberIds(_ room: Room, memberIds: [String], profiles: [String: Profile]) -> [String] {
    let creator = room.createdBy
    var ordered: [String] = []
    if let c = creator, memberIds.contains(c) { ordered.append(c) }
    ordered.append(contentsOf: memberIds.filter { $0 != creator }
        .sorted { (profiles[$0]?.name ?? "").localizedCompare(profiles[$1]?.name ?? "") == .orderedAscending })
    return ordered
}

/// 방 구성원 이름 나열 — 개설자(createdBy)를 맨 앞에, 나머지는 이름순. 잘림(...)은 UI 가 처리.
func roomMemberNames(_ room: Room, memberIds: [String], profiles: [String: Profile]) -> [String] {
    orderedRoomMemberIds(room, memberIds: memberIds, profiles: profiles).compactMap { profiles[$0]?.name }
}

// 화면 테마 — 🌙 다크(기본) / ☀️ 라이트 전환. UserDefaults 에 저장, 루트 뷰가 관찰해 재렌더.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @Published var dark: Bool = (UserDefaults.standard.object(forKey: "moim_dark") as? Bool) ?? true
    func setDark(_ v: Bool) { dark = v; UserDefaults.standard.set(v, forKey: "moim_dark") }
}
private var moimDark: Bool { ThemeManager.shared.dark }

enum Moim {
    static var bg: Color { moimDark ? Color(hex: 0x161616) : Color(hex: 0xECECEC) }
    static var paper: Color { moimDark ? Color(hex: 0x121212) : Color(hex: 0xFFFFFF) }
    static var ink: Color { moimDark ? Color(hex: 0xFFFFFF) : Color(hex: 0x212121) }
    static var sub: Color { moimDark ? Color(hex: 0xBDBDBD) : Color(hex: 0x757575) }
    static var accent: Color { moimDark ? Color(hex: 0x1E88E5) : Color(hex: 0x1976D2) }
    static var secondary: Color { moimDark ? Color(hex: 0x00BCD4) : Color(hex: 0x0097A7) }
    static var yellow: Color { moimDark ? Color(hex: 0xFFCA28) : Color(hex: 0xFFE45C) }
    static var line: Color { moimDark ? Color(hex: 0x2C2C2C) : Color(hex: 0xE0E0E0) }
    static var admin: Color { moimDark ? Color(hex: 0xF44336) : Color(hex: 0xD32F2F) }
    static var success: Color { moimDark ? Color(hex: 0x4CAF50) : Color(hex: 0x388E3C) }
    static var white: Color { moimDark ? Color(hex: 0x1E1E1E) : Color(hex: 0xFFFFFF) }   // 카드/표면
    static var youBubble: Color { moimDark ? Color(hex: 0x3A3A3A) : Color(hex: 0xFFFFFF) } // 상대 말풍선
    static var hl: Color { moimDark ? Color(hex: 0x1E1E1E) : Color(hex: 0xFFF8E0) }      // 다크 hl = surface
    static let orange = Color(hex: 0xEA7317)
}

/// 다크 모드 surface pill — 방목록 상단 3버튼(전체공지·병실현황·학술활동)과 동일 톤
func moimDarkSegBg() -> Color { Moim.white }
func moimDarkSegText(selected: Bool) -> Color { selected ? Moim.ink : Moim.sub }
func moimDarkSegBorder(selected: Bool = false) -> Color {
    moimDark && selected ? Moim.sub : Moim.line
}
func moimToggleBorder(selected: Bool) -> Color { moimDarkSegBorder(selected: selected) }
func moimToggleBg(selected: Bool, lightOn: Color, lightOff: Color = Moim.white) -> Color {
    moimDark ? Moim.white : (selected ? lightOn : lightOff)
}
func moimToggleText(selected: Bool, lightOn: Color, lightOff: Color = Moim.sub) -> Color {
    moimDark ? moimDarkSegText(selected: selected) : (selected ? lightOn : lightOff)
}

func moimSurfaceAccentText() -> Color { moimDark ? Moim.ink : Moim.accent }

/// 방·일정 상세 등 오버레이 슬라이드 — Android/Web 과 동일(진입 trailing, 복귀 trailing)
enum MoimOverlayAnim {
    static let duration = 0.26
    static let anim = Animation.easeOut(duration: duration)
    static let transition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .trailing)
    )
}

func catColor(_ category: String) -> Color {
    switch category {
    case "notice": return Color(hex: 0xB5651D)
    case "bugreport": return Color(hex: 0x5C4D7A)
    case "group": return Color(hex: 0x4A6FA5)
    case "work": return Color(hex: 0x3D8361)
    case "research": return Color(hex: 0x6D597A)
    default: return Moim.sub
    }
}

/// 공지 본문 — http(s) URL 을 탭 가능한 링크로
func linkifiedNoticeText(_ text: String) -> AttributedString {
    var result = AttributedString()
    let ns = text as NSString
    let pattern = "https?://[^\\s<>\"']+"
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return AttributedString(text)
    }
    let full = NSRange(location: 0, length: ns.length)
    var last = 0
    for match in regex.matches(in: text, options: [], range: full) {
        if match.range.location > last {
            let plain = ns.substring(with: NSRange(location: last, length: match.range.location - last))
            result.append(AttributedString(plain))
        }
        let urlStr = ns.substring(with: match.range)
        var linkPart = AttributedString(urlStr)
        if let url = URL(string: urlStr) {
            linkPart.link = url
        }
        result.append(linkPart)
        last = match.range.location + match.range.length
    }
    if last < ns.length {
        result.append(AttributedString(ns.substring(from: last)))
    }
    if result.characters.isEmpty {
        return AttributedString(text)
    }
    return result
}

func catLabel(_ category: String) -> String {
    switch category {
    case "notice": return "공지"
    case "bugreport": return "BugReport"
    case "group": return "그룹"
    case "work": return "업무"
    case "research": return "연구"
    case "custom": return "모임"
    default: return category
    }
}

func typeColor(_ memberType: String) -> Color {
    switch memberType {
    case "교실": return Color(hex: 0xB5651D)
    case "의국": return Color(hex: 0x4A6FA5)
    case "심리실": return Color(hex: 0x6D597A)
    case "연구실": return Color(hex: 0x3D8361)
    case "PA": return Color(hex: 0x0D8A8A)
    case "간호사": return Color(hex: 0xC0452F)
    case "SW": return Color(hex: 0x9A6A00)
    case "보조원": return Color(hex: 0x777777)
    case "생명사랑": return Color(hex: 0x1F9B8E)
    case "비서": return Color(hex: 0xA0526D)
    case "의국동문": return Color(hex: 0x5B7C99)
    case "심리실 동문": return Color(hex: 0x8A7AA0)
    case "기타": return Color(hex: 0x8A817A)
    default: return Moim.sub
    }
}

func roleLabel(_ role: String) -> String {
    switch role {
    case "superadmin": return "전체관리자"
    case "admin": return "관리자"
    default: return "회원"
    }
}

func isAdminRole(_ role: String) -> Bool { role == "superadmin" || role == "admin" }
func isSuperAdmin(_ role: String) -> Bool { role == "superadmin" }

func canPostInRoom(_ profile: Profile?, _ room: Room) -> Bool {
    guard let p = profile else { return false }
    if isAdminRole(p.role) { return true }
    return room.postPolicy != "restricted"
}

enum WardDutyTone { case weekday, weekend, publicHoliday }

func wardDutyTone(_ date: Date) -> WardDutyTone {
    if KrHolidays.isPublicHoliday(date) { return .publicHoliday }
    let wd = CalDate.cal.component(.weekday, from: date)
    if wd == 1 || wd == 7 { return .weekend }
    return .weekday
}

func dutyMembersByType(_ profiles: [String: Profile], memberType: String) -> [Profile] {
    profiles.values
        .filter { $0.memberType == memberType && $0.approved && !$0.withdrawn }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
}

// ward 편집 권한: 관리자 또는 직군 교실·의국·간호사("병동")
func canEditWard(_ profile: Profile?) -> Bool {
    guard let p = profile else { return false }
    return isAdminRole(p.role) || ["교실", "의국", "간호사"].contains(p.memberType)
}

/// 당직표 입력·수정 권한: 관리자 또는 직군 교실·의국·비서
func canEditWardDuty(_ profile: Profile?) -> Bool {
    guard let p = profile else { return false }
    return isAdminRole(p.role) || ["교실", "의국", "비서"].contains(p.memberType)
}

/// 휴일(주말·공휴일) — 전공의 당직 1인만
func isWardDutyOffDay(_ date: Date) -> Bool {
    wardDutyTone(date) != .weekday
}

func dutyProfDisplay(_ name: String?) -> String {
    guard let n = name, !n.isEmpty else { return "—" }
    return "\(n) 교수님"
}

func dutyResidentDisplay(_ name: String?) -> String {
    guard let n = name, !n.isEmpty else { return "—" }
    return n
}

func dutyOutpatientDisplay(_ duty: WardDuty?) -> String {
    let names = [duty?.residentOutpatient1, duty?.residentOutpatient2].compactMap { s -> String? in
        guard let s = s, !s.isEmpty else { return nil }
        return s
    }
    return names.isEmpty ? "—" : names.joined(separator: ", ")
}

func dutyTodayPreview(_ duty: WardDuty?, offDay: Bool) -> String {
    let prof = dutyProfDisplay(duty?.profDay)
    if offDay {
        return "\(prof)  ·  당직 \(dutyResidentDisplay(duty?.residentNight))"
    }
    return "\(prof)  ·  낮 \(dutyResidentDisplay(duty?.residentDay))  ·  당직 \(dutyResidentDisplay(duty?.residentNight))  ·  외래 \(dutyOutpatientDisplay(duty))"
}

func wardDutyTodayCardColors() -> (Color, Color) {
    moimDark
        ? (Color(hex: 0x262626), moimDarkSegBorder())
        : (Moim.accent.opacity(0.12), Moim.accent.opacity(0.35))
}

func wardDutyOffDayRowColors() -> (Color, Color) {
    moimDark
        ? (Color(hex: 0x212121), Moim.line)
        : (Color(hex: 0xF3F1F8), Color(hex: 0xE4E0EC))
}

func wardDutyOffDayInk() -> Color {
    moimDark ? Moim.ink : Color(hex: 0x6D5E58)
}

func wardDutyToneBadge() -> Color {
    moimDark ? Moim.sub : Color(hex: 0x8A7E96)
}

func wardDutyRowColors(_ tone: WardDutyTone, isToday: Bool) -> (Color, Color) {
    let pair: (Color, Color)
    switch tone {
    case .publicHoliday, .weekend: pair = wardDutyOffDayRowColors()
    case .weekday: pair = (Moim.white, Moim.line)
    }
    let todayBorder = isToday ? (moimDark ? Moim.sub : Moim.accent) : pair.1
    return (pair.0, todayBorder)
}

// 일정 삭제 권한: 작성자 본인 / 관리자 / 직군 교실·의국·비서·심리실
func canDeleteEvent(_ profile: Profile?, _ event: CalendarEvent) -> Bool {
    guard let p = profile else { return false }
    if event.ownerId == MoimRepository.currentUserId() { return true }
    return isAdminRole(p.role) || ["교실", "의국", "비서", "심리실"].contains(p.memberType)
}

// ── 시간/날짜/미리보기 표시 헬퍼 ──
private let kstTZ = TimeZone(identifier: "Asia/Seoul")!
private func parseISO(_ s: String?) -> Date? {
    guard let s = s else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}
private func kstFormatter(_ pattern: String) -> DateFormatter {
    let f = DateFormatter(); f.timeZone = kstTZ; f.locale = Locale(identifier: "ko_KR"); f.dateFormat = pattern; return f
}
/// 메시지 시간 HH:mm
func fmtMsgTime(_ createdAt: String?) -> String {
    guard let d = parseISO(createdAt) else { return "" }
    return kstFormatter("HH:mm").string(from: d)
}
/// 방 목록 시간: 오늘=HH:mm, 이전=M/d
func fmtListTime(_ createdAt: String?) -> String {
    guard let d = parseISO(createdAt) else { return "" }
    var cal = Calendar(identifier: .gregorian); cal.timeZone = kstTZ
    return kstFormatter(cal.isDateInToday(d) ? "HH:mm" : "M/d").string(from: d)
}
/// 날짜 구분선 라벨
func fmtDateDivider(_ createdAt: String?) -> String {
    guard let d = parseISO(createdAt) else { return "" }
    return kstFormatter("yyyy년 M월 d일 EEEE").string(from: d)
}
/// 같은 날 판별용 키
func dayKey(_ createdAt: String?) -> String {
    guard let d = parseISO(createdAt) else { return "" }
    return kstFormatter("yyyy-MM-dd").string(from: d)
}
/// 공지·게시 카드용 — "6/7 (토) 오후 2:30"
func fmtPublishTime(_ createdAt: String?) -> String {
    guard let iso = createdAt else { return "" }
    return CalDate.detailTimeLabel(iso)
}
/// 과 전체공지 — 텍스트+첨부가 연속으로 온 경우 한 카드로 합침 (기존 분리 전송 호환)
func mergeNoticeMessages(_ messages: [Message]) -> [Message] {
    guard !messages.isEmpty else { return messages }
    var out: [Message] = []
    var i = 0
    while i < messages.count {
        let m = messages[i]
        if i + 1 < messages.count {
            let n = messages[i + 1]
            if m.senderId == n.senderId {
                if m.type == "text", (n.type == "image" || n.type == "file"), (n.content ?? "").isEmpty {
                    var merged = n
                    merged.content = m.content
                    out.append(merged)
                    i += 2
                    continue
                }
                if (m.type == "image" || m.type == "file"), (m.content ?? "").isEmpty, n.type == "text", n.attachmentUrl == nil {
                    var merged = m
                    merged.content = n.content
                    out.append(merged)
                    i += 2
                    continue
                }
            }
        }
        out.append(m)
        i += 1
    }
    return out
}
/// 마지막 메시지 미리보기
func msgPreview(_ lm: LastMsg?) -> String {
    guard let lm = lm else { return "" }
    switch lm.type {
    case "image": return "사진"
    case "file": return "📎 \(lm.attachmentName ?? "파일")"
    default: return lm.content ?? ""
    }
}

/// 방 이름 변경 권한: 관리자(모든 방) 또는 방 생성자(본인이 만든 방)
func canRenameRoom(_ profile: Profile?, _ room: Room) -> Bool {
    guard let p = profile else { return false }
    // 기본 방(과 전체공지·주간 학술활동 등 비-모임방)은 전체관리자만
    if room.category != "custom" { return isSuperAdmin(p.role) }
    if isAdminRole(p.role) { return true }
    return room.createdBy != nil && room.createdBy == MoimRepository.currentUserId()
}

func viewBadgeText(_ profile: Profile?) -> String {
    guard let p = profile else { return "정신건강의학과" }
    if isSuperAdmin(p.role) { return "전체관리자 · 전체 방" }
    if isAdminRole(p.role) { return "관리자 · 전체 방" }
    return "\(p.name)(\(p.memberType))"
}
