import Foundation
import FirebaseFirestore

// MARK: - Report Model
struct ReportModel: Identifiable, Codable {
    @DocumentID var id: String?
    var reporterUID: String      // User yang melaporkan
    var reporterName: String     // Nama pelapor
    var reportedUID: String      // User yang dilaporkan
    var reportedName: String     // Nama yang dilaporkan
    var reportedEmail: String    // Email yang dilaporkan
    var reason: String           // Alasan report
    var category: ReportCategory // Kategori report
    var status: ReportStatus     // Status penanganan
    var createdAt: Timestamp
    var resolvedAt: Timestamp?   // Kapan diresolve
    var resolvedBy: String?      // Admin yang resolve
    var adminNotes: String?      // Catatan dari admin
}

// MARK: - Report Category
enum ReportCategory: String, Codable, CaseIterable {
    case spam = "spam"
    case harassment = "harassment"
    case fraud = "fraud"
    case inappropriate = "inappropriate"
    case other = "other"

    var displayName: String {
        switch self {
        case .spam: return "Spam"
        case .harassment: return "Pelecehan/Harassment"
        case .fraud: return "Penipuan/Fraud"
        case .inappropriate: return "Konten Tidak Pantas"
        case .other: return "Lainnya"
        }
    }

    var icon: String {
        switch self {
        case .spam: return "exclamationmark.bubble"
        case .harassment: return "person.fill.xmark"
        case .fraud: return "dollarsign.circle"
        case .inappropriate: return "eye.slash"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Report Status
enum ReportStatus: String, Codable {
    case pending = "pending"
    case reviewed = "reviewed"
    case resolved = "resolved"
    case dismissed = "dismissed"

    var displayName: String {
        switch self {
        case .pending: return "Menunggu"
        case .reviewed: return "Sedang Ditinjau"
        case .resolved: return "Diselesaikan"
        case .dismissed: return "Ditolak"
        }
    }

    var color: String {
        switch self {
        case .pending: return "FFA500" // Orange
        case .reviewed: return "0066CC" // Blue
        case .resolved: return "00C853" // Green
        case .dismissed: return "9E9E9E" // Gray
        }
    }
}
