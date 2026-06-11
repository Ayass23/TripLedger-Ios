import Foundation
import FirebaseFirestore

// MARK: - Trip Status
enum TripStatus: String, Codable {
    case active   = "active"
    case finished = "finished"
    case deleted  = "deleted"
}

// MARK: - Trip Invite
struct TripInvite: Identifiable, Codable {
    @DocumentID var id: String?
    var tripID:     String
    var tripName:   String
    var inviterUID: String
    var inviterName:String
    var inviteeUID: String
    var status:     TripInviteStatus
    var createdAt:  Timestamp

    enum TripInviteStatus: String, Codable {
        case pending  = "pending"
        case accepted = "accepted"
        case rejected = "rejected"
    }
}

// MARK: - Trip Member
struct TripMember: Identifiable, Codable, Equatable {
    var id:          String   // same as uid
    var uid:         String
    var displayName: String
    var avatarURL:   String?
    var role:        TripMemberRole
    var joinedAt:    Timestamp

    static func == (lhs: TripMember, rhs: TripMember) -> Bool {
        lhs.id == rhs.id &&
        lhs.uid == rhs.uid &&
        lhs.displayName == rhs.displayName &&
        lhs.avatarURL == rhs.avatarURL &&
        lhs.role == rhs.role &&
        lhs.joinedAt == rhs.joinedAt
    }
}

enum TripMemberRole: String, Codable, Equatable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
    case pending = "pending"
}

// MARK: - Trip Model
struct TripModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var name:       String
    var currency:   String          // e.g. "IDR"
    var ownerUID:   String
    var adminUIDs:  [String]
    var memberUIDs: [String]
    var members:    [TripMember]
    var coverEmoji: String          // e.g. "🏝️"
    var status:     TripStatus
    var startDate:  Timestamp?
    var endDate:    Timestamp?
    var createdAt:  Timestamp
    var finishedAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id, name, currency, ownerUID, adminUIDs, memberUIDs, members, coverEmoji, status, startDate, endDate, createdAt, finishedAt
    }

    var isActive: Bool { status == .active }

    var memberCount: Int { memberUIDs.count }

    static func == (lhs: TripModel, rhs: TripModel) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.currency == rhs.currency &&
        lhs.ownerUID == rhs.ownerUID &&
        lhs.adminUIDs == rhs.adminUIDs &&
        lhs.memberUIDs == rhs.memberUIDs &&
        lhs.members == rhs.members &&
        lhs.coverEmoji == rhs.coverEmoji &&
        lhs.status == rhs.status &&
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate &&
        lhs.createdAt == rhs.createdAt &&
        lhs.finishedAt == rhs.finishedAt
    }
}
