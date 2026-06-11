import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var user:         UserModel?
    @Published var isLoading     = false
    @Published var errorMessage: String?
    @Published var successMessage:String?

    private let db      = FirestoreService.shared
    private let storage = FirebaseStorageService.shared

    func loadUser(uid: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await db.fetch(collection: Collection.users, documentID: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Update display name
    func updateName(_ name: String, uid: String) async {
        guard !name.isBlank else { errorMessage = "Nama tidak boleh kosong."; return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await db.update(collection: Collection.users, documentID: uid, fields: ["displayName": name])
            user?.displayName = name
            successMessage    = "Nama berhasil diperbarui."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Upload avatar
    func uploadAvatar(_ image: UIImage, uid: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Step 1: Fetch current user data from Firestore untuk get avatarPublicID yang latest
            print("🔍 [ProfileVM] Fetching current user data to get old avatar path...")
            let currentUser: UserModel = try await db.fetch(collection: Collection.users, documentID: uid)
            let oldPath = currentUser.avatarPublicID

            print("📊 [ProfileVM] Current avatarPublicID from Firestore: \(oldPath ?? "nil")")

            // Step 2: Delete old avatar if exists
            if let oldPath = oldPath, !oldPath.isEmpty {
                print("🗑️  [ProfileVM] Deleting old avatar: \(oldPath)")
                do {
                    try await storage.deleteImage(fullPath: oldPath)
                    print("✅ [ProfileVM] Old avatar deleted successfully")
                } catch {
                    // Log error but continue with upload
                    print("⚠️ [ProfileVM] Failed to delete old avatar: \(error.localizedDescription)")
                }
            } else {
                print("ℹ️ [ProfileVM] No old avatar to delete (first upload)")
            }

            // Step 3: Upload new avatar to Firebase Storage
            print("📤 [ProfileVM] Uploading new avatar to Firebase Storage")
            let response = try await storage.uploadImage(
                image,
                folder: "profile_pictures",
                fileName: nil // Auto-generate with user_uid_timestamp
            )

            // Step 4: Update Firestore with new URL and storage path
            let fields: [String: Any] = [
                "avatarURL": response.downloadURL,
                "avatarPublicID": response.fullPath  // Store full path for deletion
            ]

            try await db.update(collection: Collection.users, documentID: uid, fields: fields)

            // Step 5: Update local user object
            user?.avatarURL = response.downloadURL
            user?.avatarPublicID = response.fullPath

            print("✅ [ProfileVM] Avatar uploaded successfully")
            print("   URL: \(response.downloadURL)")
            print("   Storage Path: \(response.fullPath)")

            successMessage = "Foto profil berhasil diperbarui."

        } catch let error as StorageError {
            print("❌ [ProfileVM] Storage error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            print("❌ [ProfileVM] Upload error: \(error.localizedDescription)")
            errorMessage = "Upload gagal: \(error.localizedDescription)"
        }
    }

    // MARK: - Update bank info
    func updateBankInfo(bankName: String, accountNumber: String, accountName: String, uid: String) async {
        isLoading = true
        defer { isLoading = false }
        let info: [String: Any] = [
            "bankInfo.bankName":      bankName,
            "bankInfo.accountNumber": accountNumber,
            "bankInfo.accountName":   accountName
        ]
        do {
            try await db.update(collection: Collection.users, documentID: uid, fields: info)
            user?.bankInfo = BankInfo(bankName: bankName, accountNumber: accountNumber, accountName: accountName)
            successMessage = "Info rekening berhasil disimpan."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
