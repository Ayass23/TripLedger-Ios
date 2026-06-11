import Foundation
import FirebaseFirestore

// MARK: - Expense Category
enum ExpenseCategory: String, Codable, CaseIterable {
    case food        = "food"
    case transport   = "transport"
    case accommodation = "accommodation"
    case activity    = "activity"
    case shopping    = "shopping"
    case health      = "health"
    case other       = "other"

    var displayName: String {
        switch self {
        case .food:          return "Makanan"
        case .transport:     return "Transportasi"
        case .accommodation: return "Akomodasi"
        case .activity:      return "Aktivitas"
        case .shopping:      return "Belanja"
        case .health:        return "Kesehatan"
        case .other:         return "Lainnya"
        }
    }

    var icon: String {
        switch self {
        case .food:          return "fork.knife"
        case .transport:     return "car.fill"
        case .accommodation: return "house.fill"
        case .activity:      return "figure.hiking"
        case .shopping:      return "bag.fill"
        case .health:        return "cross.case.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }

    var color: String {  // hex string for UI
        switch self {
        case .food:          return "#FF6B6B"
        case .transport:     return "#4ECDC4"
        case .accommodation: return "#45B7D1"
        case .activity:      return "#96CEB4"
        case .shopping:      return "#FFEAA7"
        case .health:        return "#DDA0DD"
        case .other:         return "#95A5A6"
        }
    }

    // Map from string to category (for AI parsing)
    static func fromString(_ string: String) -> ExpenseCategory? {
        let normalized = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized {
        case "food", "makanan":
            return .food
        case "transport", "transportasi", "transportation":
            return .transport
        case "accommodation", "akomodasi", "hotel", "lodging":
            return .accommodation
        case "activity", "aktivitas", "entertainment", "hiburan":
            return .activity
        case "shopping", "belanja":
            return .shopping
        case "health", "kesehatan":
            return .health
        case "other", "lainnya":
            return .other
        default:
            return nil
        }
    }
}

// MARK: - Split Type
enum SplitType: String, Codable {
    case equally  = "equally"
    case byItem   = "byItem"
    case custom   = "custom"
}

// MARK: - Expense Split Detail
struct ExpenseSplit: Identifiable, Codable, Equatable {
    var id:          String  // uid of member
    var uid:         String
    var displayName: String
    var amount:      Double   // amount this member owes
    var items:       [String] // for byItem split
    var isPaid:      Bool?    // tracks if the debt is settled directly
}

// MARK: - Expense Model
struct ExpenseModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var tripID:      String
    var title:       String
    var amount:      Double
    var currency:    String
    var category:    ExpenseCategory
    var paidByUID:   String
    var paidByName:  String
    var splitType:   SplitType
    var splits:      [ExpenseSplit]
    var notes:       String?
    var receiptURL:  String?
    var createdAt:   Timestamp
    var updatedAt:   Timestamp?

    enum CodingKeys: String, CodingKey {
        case id, tripID, title, amount, currency, category, paidByUID,
             paidByName, splitType, splits, notes, receiptURL, createdAt, updatedAt
    }
}
