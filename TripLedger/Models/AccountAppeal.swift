import Foundation
import FirebaseFirestore

// MARK: - Account Appeal Model
struct AccountAppeal: Identifiable, Codable {
    @DocumentID var id: String?
    var userUID: String           // User yang mengajukan banding
    var userName: String          // Nama user
    var userEmail: String         // Email user
    var suspendReason: String     // Alasan suspend dari admin (original)
    var appealReason: String      // Alasan banding dari user
    var status: AppealStatus      // Status penanganan
    var createdAt: Timestamp
    var resolvedAt: Timestamp?    // Kapan diresolve
    var resolvedBy: String?       // Admin yang resolve
    var adminNotes: String?       // Catatan dari admin saat review
}

// MARK: - Appeal Status
enum AppealStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"

    var displayName: String {
        switch self {
        case .pending: return "Menunggu"
        case .approved: return "Disetujui"
        case .rejected: return "Ditolak"
        }
    }
}
