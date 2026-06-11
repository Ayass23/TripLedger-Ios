import Foundation
import Combine
import FirebaseStorage
import UIKit

// MARK: - Storage Service
final class StorageService {

    static let shared = StorageService()
    private let storage = Storage.storage()
    private init() {}

    // MARK: - Upload image
    /// Returns the public download URL string
    func uploadImage(_ image: UIImage, path: String, compressionQuality: CGFloat = 0.75) async throws -> String {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw AppError.unknown("Image compression failed.")
        }
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Delete file
    func deleteFile(path: String) async throws {
        let ref = storage.reference().child(path)
        try await ref.delete()
    }

    // MARK: - Path helpers
    static func avatarPath(uid: String) -> String { "avatars/\(uid).jpg" }
    static func receiptPath(expenseID: String) -> String { "receipts/\(expenseID).jpg" }
    static func proofPath(settlementID: String) -> String { "proofs/\(settlementID).jpg" }
}
