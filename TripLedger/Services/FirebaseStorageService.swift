import Foundation
import UIKit
import FirebaseStorage
import FirebaseAuth

// MARK: - Firebase Storage Response Model
struct StorageUploadResponse {
    let downloadURL: String
    let fullPath: String
    let fileName: String
}

// MARK: - Firebase Storage Service
final class FirebaseStorageService {

    static let shared = FirebaseStorageService()

    private let storage = Storage.storage()
    private let storageRef: StorageReference

    private init() {
        storageRef = storage.reference()
    }

    // MARK: - Upload Image
    /// Upload image to Firebase Storage
    /// - Parameters:
    ///   - image: UIImage to upload
    ///   - folder: Folder path (e.g., "profile_pictures")
    ///   - fileName: Optional custom file name
    /// - Returns: StorageUploadResponse with download URL and path
    func uploadImage(_ image: UIImage, folder: String, fileName: String? = nil) async throws -> StorageUploadResponse {

        // Resize image to max dimension 1440px for better upload speed
        let resizedImage = resizeImage(image, maxDimension: 1440)

        // Compress image with 60% quality (good balance for receipts)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.3) else {
            throw StorageError.compressionFailed
        }

        print("📊 [Storage] Image size after resize+compress: \(Double(imageData.count) / 1024 / 1024) MB")

        // Validate size (max 5MB)
        let maxSizeInBytes = 5 * 1024 * 1024 // 5MB
        if imageData.count > maxSizeInBytes {
            let sizeInMB = Double(imageData.count) / (1024 * 1024)
            throw StorageError.fileTooLarge(size: sizeInMB)
        }

        // Get current user
        guard let userId = Auth.auth().currentUser?.uid else {
            throw StorageError.notAuthenticated
        }

        // Generate file name
        let timestamp = Int(Date().timeIntervalSince1970)
        let finalFileName = fileName ?? "user_\(userId)_\(timestamp).jpg"

        // Create reference
        let fileRef = storageRef.child("\(folder)/\(finalFileName)")

        print("📤 [Storage] Uploading to: \(fileRef.fullPath)")

        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "userId": userId,
            "uploadedAt": ISO8601DateFormatter().string(from: Date())
        ]

        // Upload
        do {
            let _ = try await fileRef.putDataAsync(imageData, metadata: metadata)

            // Get download URL
            let downloadURL = try await fileRef.downloadURL()

            print("✅ [Storage] Upload success: \(downloadURL.absoluteString)")

            return StorageUploadResponse(
                downloadURL: downloadURL.absoluteString,
                fullPath: fileRef.fullPath,
                fileName: finalFileName
            )

        } catch {
            print("❌ [Storage] Upload error: \(error.localizedDescription)")
            throw StorageError.uploadFailed(message: error.localizedDescription)
        }
    }

    // MARK: - Delete Image
    /// Delete image from Firebase Storage
    /// - Parameter fullPath: Full path of the file (e.g., "profile_pictures/user_123_456.jpg")
    func deleteImage(fullPath: String) async throws {

        guard !fullPath.isEmpty else {
            print("⚠️ [Storage] Empty path, skipping delete")
            return
        }

        let fileRef = storageRef.child(fullPath)

        print("🗑️  [Storage] Deleting: \(fullPath)")

        do {
            try await fileRef.delete()
            print("✅ [Storage] Delete success: \(fullPath)")
        } catch let error as NSError {
            // If file doesn't exist (404), consider it success
            if error.domain == StorageErrorDomain && error.code == StorageErrorCode.objectNotFound.rawValue {
                print("⚠️ [Storage] File not found (already deleted): \(fullPath)")
                return
            }
            print("❌ [Storage] Delete error: \(error.localizedDescription)")
            throw StorageError.deleteFailed(message: error.localizedDescription)
        }
    }

    // MARK: - Delete Image by URL
    /// Delete image by extracting path from download URL
    /// - Parameter downloadURL: Full download URL from Firebase Storage
    func deleteImageByURL(_ downloadURL: String) async throws {

        // Extract path from URL
        // Format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?...
        guard let url = URL(string: downloadURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let pathComponent = components.path.components(separatedBy: "/o/").last?.components(separatedBy: "?").first,
              let decodedPath = pathComponent.removingPercentEncoding else {
            throw StorageError.invalidURL
        }

        try await deleteImage(fullPath: decodedPath)
    }

    // MARK: - List Files in Folder
    /// List all files in a folder (optional, untuk cleanup)
    func listFiles(in folder: String) async throws -> [String] {
        let folderRef = storageRef.child(folder)

        do {
            let result = try await folderRef.listAll()
            return result.items.map { $0.fullPath }
        } catch {
            print("❌ [Storage] List error: \(error.localizedDescription)")
            throw StorageError.listFailed(message: error.localizedDescription)
        }
    }

    // MARK: - Resize Image Helper
    /// Resize image to fit within max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size

        // Calculate new size maintaining aspect ratio
        var newSize = originalSize
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let ratio = originalSize.width / originalSize.height
            if originalSize.width > originalSize.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
            } else {
                newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
            }
        }

        // If no resize needed, return original
        if newSize == originalSize {
            print("📏 [Storage] No resize needed: \(originalSize.width)x\(originalSize.height)")
            return image
        }

        print("📏 [Storage] Resizing from \(originalSize.width)x\(originalSize.height) to \(newSize.width)x\(newSize.height)")

        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }
}

// MARK: - Storage Errors
enum StorageError: LocalizedError {
    case compressionFailed
    case fileTooLarge(size: Double)
    case notAuthenticated
    case invalidURL
    case uploadFailed(message: String)
    case deleteFailed(message: String)
    case listFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Gagal memproses gambar."
        case .fileTooLarge(let size):
            return "Ukuran foto melebihi batas maksimal 5MB. Ukuran foto: \(String(format: "%.2f", size))MB"
        case .notAuthenticated:
            return "User belum login."
        case .invalidURL:
            return "URL gambar tidak valid."
        case .uploadFailed(let message):
            return "Upload gagal: \(message)"
        case .deleteFailed(let message):
            return "Hapus gambar gagal: \(message)"
        case .listFailed(let message):
            return "Gagal mengambil list file: \(message)"
        }
    }
}
