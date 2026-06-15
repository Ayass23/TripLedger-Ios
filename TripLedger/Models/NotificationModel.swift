import Foundation
import FirebaseFirestore

// MARK: - Notification Type
enum AppNotificationType: String, Codable {
    case tripInvite      = "tripInvite"
    case tripEnded       = "tripEnded"
    case friendRequest   = "friendRequest"
    case expenseAdded    = "expenseAdded"
    case settlementProof = "settlementProof"
    case paymentVerified = "paymentVerified"
    case paymentRejected = "paymentRejected"
    case general         = "general"
}

// MARK: - Notification Model
struct NotificationModel: Identifiable, Codable {
    @DocumentID var id: String?

    var recipientUID: String
    var type:         AppNotificationType
    var title:        String
    var body:         String
    var isRead:       Bool
    var referenceID:  String?   // tripID, requestID, expenseID, etc.
    var senderUID:    String?
    var senderName:   String?
    var createdAt:    Timestamp

    var icon: String {
        switch type {
        case .tripInvite:      return "airplane.circle.fill"
        case .tripEnded:       return "flag.pattern.checkered"
        case .friendRequest:   return "person.badge.plus.fill"
        case .expenseAdded:    return "dollarsign.circle.fill"
        case .settlementProof: return "banknote.fill"
        case .paymentVerified: return "checkmark.seal.fill"
        case .paymentRejected: return "xmark.seal.fill"
        case .general:         return "bell.fill"
        }
    }
}
