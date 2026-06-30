import Foundation
import FirebaseFirestore

// MARK: - User Role
enum UserRole: String, Codable {
    case user  = "user"
    case admin = "admin"
}

// MARK: - Bank Account Info
struct BankInfo: Codable {
    var bankName:      String
    var accountNumber: String
    var accountName:   String
}

// MARK: - User Model
struct UserModel: Identifiable, Codable {
    @DocumentID var id: String?

    var uid:            String
    var displayName:    String
    var email:          String
    var avatarURL:      String?
    var avatarPublicID: String?  // Firebase Storage full path untuk delete (e.g., "profile_pictures/user_123_456.jpg")
    var bankInfo:       BankInfo?
    var role:           UserRole
    var isSuspended:    Bool
    var suspendReason:  String?
    var fcmToken:       String?
    var createdAt:      Timestamp
    var friendUIDs:     [String]

    enum CodingKeys: String, CodingKey {
        case id, uid, displayName, email, avatarURL, avatarPublicID, bankInfo, role, isSuspended, suspendReason, fcmToken, createdAt, friendUIDs
    }

    // Computed
    var initials: String {
        displayName.split(separator: " ")
            .compactMap { $0.first.map(String.init) }
            .prefix(2)
            .joined()
            .uppercased()
    }
}

// MARK: - Friend Request Model
struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUID:      String
    var fromName:     String
    var fromAvatar:   String?
    var toUID:        String
    var status:       FriendRequestStatus
    var createdAt:    Timestamp

    enum FriendRequestStatus: String, Codable {
        case pending  = "pending"
        case accepted = "accepted"
        case rejected = "rejected"
    }
}
