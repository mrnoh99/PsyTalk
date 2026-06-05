import Foundation

// =====================================================================
//  데이터 모델 — DB 스키마와 1:1 (snake_case 는 CodingKeys 매핑)
//  Android SupabaseClient.kt 의 모델과 동일
// =====================================================================

struct Profile: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let memberType: String
    let role: String              // superadmin | admin | user
    var approved: Bool?           // 관리자 가입 승인 (nil=마이그레이션 전이면 승인으로 간주)
    var phone: String?            // 전화번호
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, role, approved, phone
        case memberType = "member_type"
        case avatarUrl = "avatar_url"
    }
}

struct Room: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String          // notice | group | work | research | custom
    let postPolicy: String        // restricted | members
    var sortOrder: Int
    var defaultView: String?
    var createdBy: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case postPolicy = "post_policy"
        case sortOrder = "sort_order"
        case defaultView = "default_view"
        case createdBy = "created_by"
    }
}

// 모임방 생성 DTO (카톡처럼 누구나 방 생성)
struct RoomInsert: Encodable {
    let id: String
    let name: String
    var category: String = "custom"
    var postPolicy: String = "members"
    let sortOrder: Int
    let createdBy: String

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case postPolicy = "post_policy"
        case sortOrder = "sort_order"
        case createdBy = "created_by"
    }
}

struct RoomMemberInsert: Encodable {
    let roomId: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
    }
}

// 방 멤버 행 읽기용 (멤버 내보내기 목록)
struct RoomMemberRow: Decodable {
    let roomId: String
    let userId: String
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
    }
}

struct Message: Codable, Identifiable, Hashable {
    let id: String
    let roomId: String
    let senderId: String
    var content: String?
    var type: String = "text"                 // text | image | file
    var attachmentUrl: String?
    var attachmentName: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, content, type
        case roomId = "room_id"
        case senderId = "sender_id"
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
        case createdAt = "created_at"
    }
}

// 방별 마지막 메시지 (방 목록 미리보기)
struct LastMsg: Decodable {
    let roomId: String
    var content: String?
    var type: String = "text"
    var attachmentName: String?
    var createdAt: String?
    enum CodingKeys: String, CodingKey {
        case content, type
        case roomId = "room_id"
        case attachmentName = "attachment_name"
        case createdAt = "created_at"
    }
}

// 개인 고정 방 (순서)
struct RoomPinRow: Decodable {
    let roomId: String
    enum CodingKeys: String, CodingKey { case roomId = "room_id" }
}

// 읽음 추적 RPC 결과
struct UnreadRoomRow: Decodable {
    let roomId: String
    let cnt: Int
    enum CodingKeys: String, CodingKey { case cnt; case roomId = "room_id" }
}
struct UnreadMsgRow: Decodable {
    let messageId: String
    let unread: Int
    enum CodingKeys: String, CodingKey { case unread; case messageId = "message_id" }
}

struct MessageInsert: Encodable {
    let roomId: String
    let senderId: String
    var content: String?
    var type: String = "text"                 // text | image | file
    var attachmentUrl: String?
    var attachmentName: String?

    enum CodingKeys: String, CodingKey {
        case content, type
        case roomId = "room_id"
        case senderId = "sender_id"
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
    }
}

struct CalendarEvent: Codable, Identifiable, Hashable {
    let id: String
    let roomId: String
    let title: String
    let startAt: String
    var place: String?
    var link: String?
    var scope: String?
    var description: String?
    var presenter: String?
    var keywords: [String]?
    let ownerId: String
    var attachmentUrl: String?
    var attachmentName: String?
    var attachmentDesc: String?
    var attachmentUrls: [String]?
    var attachmentNames: [String]?

    var kw: [String] { keywords ?? [] }

    /// 표시용 첨부 목록 — attachment_urls 가 NULL 이 아니면 빈 배열 포함 배열만 사용 (삭제 반영)
    var attachmentList: [(name: String, url: String)] {
        if attachmentUrls != nil {
            let urls = attachmentUrls ?? []
            let names = attachmentNames ?? []
            return urls.enumerated().map { (idx, u) in (idx < names.count ? names[idx] : "첨부파일", u) }
        }
        if let u = attachmentUrl, !u.isEmpty { return [(attachmentName ?? "첨부파일", u)] }
        return []
    }

    enum CodingKeys: String, CodingKey {
        case id, title, place, link, scope, description, presenter, keywords
        case roomId = "room_id"
        case startAt = "start_at"
        case ownerId = "owner_id"
        case attachmentUrl = "attachment_url"
        case attachmentName = "attachment_name"
        case attachmentDesc = "attachment_desc"
        case attachmentUrls = "attachment_urls"
        case attachmentNames = "attachment_names"
    }
}

struct CalendarEventInsert: Encodable {
    let roomId: String
    let title: String
    let startAt: String
    var place: String?
    var link: String?
    var scope: String?
    var description: String?
    var presenter: String?
    var keywords: [String]
    let ownerId: String
    var attachmentUrls: [String] = []
    var attachmentNames: [String] = []

    enum CodingKeys: String, CodingKey {
        case title, place, link, scope, description, presenter, keywords
        case roomId = "room_id"
        case startAt = "start_at"
        case ownerId = "owner_id"
        case attachmentUrls = "attachment_urls"
        case attachmentNames = "attachment_names"
    }
}

struct CalendarEventUpdate: Encodable {
    let title: String
    let startAt: String
    var place: String?
    var link: String?
    var scope: String?
    var description: String?
    var keywords: [String]

    enum CodingKeys: String, CodingKey {
        case title, place, link, scope, description, keywords
        case startAt = "start_at"
    }
}

struct RoomFile: Codable, Identifiable, Hashable {
    let id: String
    let roomId: String
    let fileName: String
    let fileUrl: String
    var description: String?
    var keywords: [String]?
    let uploadedBy: String
    var source: String = "upload"        // upload | calendar
    var createdAt: String?

    var kw: [String] { keywords ?? [] }

    enum CodingKeys: String, CodingKey {
        case id, description, keywords, source
        case roomId = "room_id"
        case fileName = "file_name"
        case fileUrl = "file_url"
        case uploadedBy = "uploaded_by"
        case createdAt = "created_at"
    }
}

struct RoomFileInsert: Encodable {
    let roomId: String
    let fileName: String
    let fileUrl: String
    var description: String?
    var keywords: [String]
    let uploadedBy: String
    var source: String = "upload"

    enum CodingKeys: String, CodingKey {
        case description, keywords, source
        case roomId = "room_id"
        case fileName = "file_name"
        case fileUrl = "file_url"
        case uploadedBy = "uploaded_by"
    }
}

// 잔여 병실 현황 (단일 행, 메모 형식)
struct WardStatus: Codable {
    var id: Int = 1
    var content: String = ""
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, content
        case updatedAt = "updated_at"
    }
}

struct WardStatusUpdate: Encodable {
    let content: String
    var updatedBy: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case content
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
    }
}
