import Foundation
import FirebaseFirestore

// MARK: - Settlement Status
enum SettlementStatus: String, Codable {
    case pending  = "pending"
    case verified = "verified"
    case rejected = "rejected"
}

// MARK: - Debt Record (computed, not stored — stored as settlement records)
struct DebtRecord: Identifiable {
    var id:        String { "\(fromUID)_\(toUID)" }
    var fromUID:   String
    var fromName:  String
    var toUID:     String
    var toName:    String
    var amount:    Double
    var currency:  String
}

// MARK: - Settlement Model (stored in Firestore)
struct SettlementModel: Identifiable, Codable {
    @DocumentID var id: String?

    var tripID:       String
    var fromUID:      String
    var fromName:     String
    var toUID:        String
    var toName:       String
    var amount:       Double
    var currency:     String
    var status:       SettlementStatus
    var proofURL:     String?       // uploaded payment proof image
    var notes:        String?
    var createdAt:    Timestamp
    var verifiedAt:   Timestamp?
    var verifiedByUID:String?

    enum CodingKeys: String, CodingKey {
        case tripID, fromUID, fromName, toUID, toName, amount, currency,
             status, proofURL, notes, createdAt, verifiedAt, verifiedByUID
    }
}
