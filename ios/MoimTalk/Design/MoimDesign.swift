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
}

enum Moim {
    static let bg = Color(hex: 0xE9E4DD)
    static let paper = Color(hex: 0xF5F1EA)
    static let ink = Color(hex: 0x231F1C)
    static let sub = Color(hex: 0x8A817A)
    static let accent = Color(hex: 0x2B2825)
    static let yellow = Color(hex: 0xFFE45C)
    static let line = Color(hex: 0xDCD5CC)
    static let admin = Color(hex: 0xC0452F)
    static let white = Color.white
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
    default: return "멤버"
    }
}

func isAdminRole(_ role: String) -> Bool { role == "superadmin" || role == "admin" }
func isSuperAdmin(_ role: String) -> Bool { role == "superadmin" }

func canPostInRoom(_ profile: Profile?, _ room: Room) -> Bool {
    guard let p = profile else { return false }
    if isAdminRole(p.role) { return true }
    return room.postPolicy != "restricted"
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
