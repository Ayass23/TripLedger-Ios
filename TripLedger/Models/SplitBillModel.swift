import Foundation
import FirebaseFirestore

// MARK: - Split Bill Source
enum SplitBillSource: String, Codable {
    case manual = "manual"
    case scan   = "scan"
}

// MARK: - Split Bill Status
enum SplitBillStatus: String, Codable {
    case active  = "active"
    case settled = "settled"
}

// MARK: - Split Bill Participant
struct SplitBillParticipant: Identifiable, Codable, Equatable {
    var id:          String   // uid or UUID for manual entries
    var uid:         String?  // nil for non-app users
    var displayName: String
    var amount:      Double
    var isPaid:      Bool

    enum CodingKeys: String, CodingKey {
        case id, uid, displayName, amount, isPaid
    }
}

// MARK: - Split Bill Model
struct SplitBillModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var ownerUID:        String
    var ownerName:       String
    var title:           String
    var totalAmount:     Double
    var currency:        String
    var participants:    [SplitBillParticipant]
    var participantUIDs: [String]  // Array of participant UIDs for easy querying
    var source:          SplitBillSource
    var receiptURL:      String?
    var status:          SplitBillStatus
    var category:        ExpenseCategory?
    var notes:           String?
    var createdAt:       Timestamp

    enum CodingKeys: String, CodingKey {
        case id, ownerUID, ownerName, title, totalAmount, currency,
             participants, participantUIDs, source, receiptURL, status, category, notes, createdAt
    }

    // Regular initializer
    init(
        id: String? = nil,
        ownerUID: String,
        ownerName: String,
        title: String,
        totalAmount: Double,
        currency: String,
        participants: [SplitBillParticipant],
        participantUIDs: [String],
        source: SplitBillSource,
        receiptURL: String? = nil,
        status: SplitBillStatus,
        category: ExpenseCategory? = nil,
        notes: String? = nil,
        createdAt: Timestamp
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.ownerName = ownerName
        self.title = title
        self.totalAmount = totalAmount
        self.currency = currency
        self.participants = participants
        self.participantUIDs = participantUIDs
        self.source = source
        self.receiptURL = receiptURL
        self.status = status
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
    }

    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        ownerUID = try container.decode(String.self, forKey: .ownerUID)
        ownerName = try container.decode(String.self, forKey: .ownerName)
        title = try container.decode(String.self, forKey: .title)
        totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        currency = try container.decode(String.self, forKey: .currency)
        participants = try container.decode([SplitBillParticipant].self, forKey: .participants)
        source = try container.decode(SplitBillSource.self, forKey: .source)
        receiptURL = try container.decodeIfPresent(String.self, forKey: .receiptURL)
        status = try container.decode(SplitBillStatus.self, forKey: .status)
        category = try container.decodeIfPresent(ExpenseCategory.self, forKey: .category)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decode(Timestamp.self, forKey: .createdAt)

        // Backward compatibility: Auto-populate participantUIDs if missing
        if let uids = try? container.decode([String].self, forKey: .participantUIDs) {
            participantUIDs = uids
            print("✅ [SplitBillModel] Decoded '\(title)' with \(uids.count) participantUIDs from Firestore")
        } else {
            // Generate from participants
            var uids = participants.compactMap { $0.uid }
            if !uids.contains(ownerUID) {
                uids.append(ownerUID)
            }
            participantUIDs = uids
            print("⚠️ [SplitBillModel] Backward compatibility: Auto-populated \(uids.count) participantUIDs for bill '\(title)'")
            print("   Generated UIDs: \(uids)")
        }
    }

    /// Check if all participants have paid
    var isFullySettled: Bool {
        participants.allSatisfy { $0.isPaid }
    }

    /// Total amount that has been paid
    var paidAmount: Double {
        participants.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    /// Number of participants who haven't paid
    var unpaidCount: Int {
        participants.filter { !$0.isPaid }.count
    }
}
