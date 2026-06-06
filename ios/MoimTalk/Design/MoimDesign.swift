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

/// 주간 학술활동(default_view=week) — 입장 시 캘린더·주간 보기가 기본
func opensWeekCalendar(_ room: Room) -> Bool {
    room.category != "custom" && room.category != "direct" && room.defaultView == "week"
}

/// 과 전체공지 방 = 항상 방 목록 맨 위 고정(핀·정렬 변경 불가). 모임·DM·주간(week)이 아닌 기본 방.
func noticeTopRoom(_ rooms: [Room]) -> Room? {
    rooms.filter { $0.category != "custom" && $0.category != "direct" && $0.defaultView != "week" }
        .min { $0.sortOrder < $1.sortOrder }
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
    static var hl: Color { moimDark ? Color(hex: 0x33301F) : Color(hex: 0xFFF8E0) }      // 선택·오늘 하이라이트
    static let orange = Color(hex: 0xEA7317)
}

func catColor(_ category: String) -> Color {
    switch category {
    case "notice": return Color(hex: 0xB5651D)
    case "group": return Color(hex: 0x4A6FA5)
    case "work": return Color(hex: 0x3D8361)
    case "research": return Color(hex: 0x6D597A)
    default: return Moim.sub
    }
}

func catLabel(_ category: String) -> String {
    switch category {
    case "notice": return "공지"
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

// ward 편집 권한: 관리자 또는 직군 교실·의국·간호사("병동")
func canEditWard(_ profile: Profile?) -> Bool {
    guard let p = profile else { return false }
    return isAdminRole(p.role) || ["교실", "의국", "간호사"].contains(p.memberType)
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
func isNoticeTopRoom(_ room: Room, rooms: [Room]) -> Bool {
    noticeTopRoom(rooms)?.id == room.id
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
    if isAdminRole(p.role) { return true }
    return room.createdBy != nil && room.createdBy == MoimRepository.currentUserId()
}

func viewBadgeText(_ profile: Profile?) -> String {
    guard let p = profile else { return "정신건강의학과" }
    if isSuperAdmin(p.role) { return "전체관리자 · 전체 방" }
    if isAdminRole(p.role) { return "관리자 · 전체 방" }
    return "\(p.name)(\(p.memberType))"
}
