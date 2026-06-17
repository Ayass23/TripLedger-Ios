import Foundation
import FirebaseFirestore

// MARK: - Transaction (computed debt for settlement)
struct Transaction: Identifiable {
    let id: String = UUID().uuidString
    let fromUID: String
    let fromName: String
    let toUID: String
    let toName: String
    let amount: Double
}

// MARK: - Settlement Status
enum SettlementStatus: String, Codable {
    case pending  = "pending"
    case verified = "verified"
    case rejected = "rejected"
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
