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

            // Sync display name across trips and expenses
            await syncDisplayNameAcrossTrips(uid: uid, newName: name)
            await syncDisplayNameAcrossExpenses(uid: uid, newName: name)

            successMessage    = "Nama berhasil diperbarui."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sync Display Name Across Trips
    private func syncDisplayNameAcrossTrips(uid: String, newName: String) async {
        do {
            // Find all trips where this user is a member
            let snapshot = try await db.db.collection(Collection.trips)
                .whereField("memberUIDs", arrayContains: uid)
                .getDocuments()

            for doc in snapshot.documents {
                guard var trip = try? doc.data(as: TripModel.self),
                      let tripID = trip.id else { continue }

                // Update member's displayName in members array
                var updated = false
                for i in trip.members.indices {
                    if trip.members[i].uid == uid {
                        trip.members[i] = TripMember(
                            id: trip.members[i].id,
                            uid: trip.members[i].uid,
                            displayName: newName,
                            avatarURL: trip.members[i].avatarURL,
                            role: trip.members[i].role,
                            joinedAt: trip.members[i].joinedAt
                        )
                        updated = true
                    }
                }

                if updated {
                    let memberDicts = trip.members.map { [
                        "id": $0.id,
                        "uid": $0.uid,
                        "displayName": $0.displayName,
                        "avatarURL": $0.avatarURL ?? "",
                        "role": $0.role.rawValue,
                        "joinedAt": $0.joinedAt
                    ]}

                    try await db.update(collection: Collection.trips, documentID: tripID, fields: [
                        "members": memberDicts
                    ])
                }
            }
            AppLog.debug("✅ [ProfileVM] Synced display name across \(snapshot.documents.count) trips")
        } catch {
            AppLog.debug("⚠️ [ProfileVM] Error syncing display name across trips: \(error)")
        }
    }

    // MARK: - Sync Avatar URL Across Trips
    private func syncAvatarURLAcrossTrips(uid: String, newAvatarURL: String) async {
        do {
            let snapshot = try await db.db.collection(Collection.trips)
                .whereField("memberUIDs", arrayContains: uid)
                .getDocuments()

            for doc in snapshot.documents {
                guard var trip = try? doc.data(as: TripModel.self),
                      let tripID = trip.id else { continue }

                var updated = false
                for i in trip.members.indices {
                    if trip.members[i].uid == uid {
                        trip.members[i] = TripMember(
                            id: trip.members[i].id,
                            uid: trip.members[i].uid,
                            displayName: trip.members[i].displayName,
                            avatarURL: newAvatarURL,
                            role: trip.members[i].role,
                            joinedAt: trip.members[i].joinedAt
                        )
                        updated = true
                    }
                }

                if updated {
                    let memberDicts = trip.members.map { [
                        "id": $0.id,
                        "uid": $0.uid,
                        "displayName": $0.displayName,
                        "avatarURL": $0.avatarURL ?? "",
                        "role": $0.role.rawValue,
                        "joinedAt": $0.joinedAt
                    ]}

                    try await db.update(collection: Collection.trips, documentID: tripID, fields: [
                        "members": memberDicts
                    ])
                }
            }
            AppLog.debug("✅ [ProfileVM] Synced avatar URL across \(snapshot.documents.count) trips")
        } catch {
            AppLog.debug("⚠️ [ProfileVM] Error syncing avatar URL across trips: \(error)")
        }
    }

    // MARK: - Sync Display Name Across Expenses
    private func syncDisplayNameAcrossExpenses(uid: String, newName: String) async {
        do {
            // Find all expenses where this user is payer or in splits
            // We'll search by paidByUID first
            let payerSnapshot = try await db.db.collection(Collection.expenses)
                .whereField("paidByUID", isEqualTo: uid)
                .getDocuments()

            for doc in payerSnapshot.documents {
                try await db.update(collection: Collection.expenses, documentID: doc.documentID, fields: [
                    "paidByName": newName
                ])
            }

            // For splits, we need to fetch all expenses and check splits array
            // This is less efficient but necessary since Firestore can't query array elements
            let allExpenses = try await db.db.collection(Collection.expenses).getDocuments()

            for doc in allExpenses.documents {
                guard var expense = try? doc.data(as: ExpenseModel.self),
                      let expenseID = expense.id else { continue }

                var updated = false
                for i in expense.splits.indices {
                    if expense.splits[i].uid == uid {
                        expense.splits[i] = ExpenseSplit(
                            id: expense.splits[i].id,
                            uid: expense.splits[i].uid,
                            displayName: newName,
                            amount: expense.splits[i].amount,
                            items: expense.splits[i].items,
                            isPaid: expense.splits[i].isPaid
                        )
                        updated = true
                    }
                }

                if updated {
                    let splitDicts = expense.splits.map { split -> [String: Any] in
                        var dict: [String: Any] = [
                            "id": split.id,
                            "uid": split.uid,
                            "displayName": split.displayName,
                            "amount": split.amount,
                            "items": split.items
                        ]
                        if let isPaid = split.isPaid {
                            dict["isPaid"] = isPaid
                        }
                        return dict
                    }

                    try await db.update(collection: Collection.expenses, documentID: expenseID, fields: [
                        "splits": splitDicts
                    ])
                }
            }
            AppLog.debug("✅ [ProfileVM] Synced display name across expenses")
        } catch {
            AppLog.debug("⚠️ [ProfileVM] Error syncing display name across expenses: \(error)")
        }
    }

    // MARK: - Upload avatar
    func uploadAvatar(_ image: UIImage, uid: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Step 1: Fetch current user data from Firestore untuk get avatarPublicID yang latest
            AppLog.debug("🔍 [ProfileVM] Fetching current user data to get old avatar path...")
            let currentUser: UserModel = try await db.fetch(collection: Collection.users, documentID: uid)
            let oldPath = currentUser.avatarPublicID

            AppLog.debug("📊 [ProfileVM] Current avatarPublicID from Firestore: \(oldPath ?? "nil")")

            // Step 2: Delete old avatar if exists
            if let oldPath = oldPath, !oldPath.isEmpty {
                AppLog.debug("🗑️  [ProfileVM] Deleting old avatar: \(oldPath)")
                do {
                    try await storage.deleteImage(fullPath: oldPath)
                    AppLog.debug("✅ [ProfileVM] Old avatar deleted successfully")
                } catch {
                    // Log error but continue with upload
                    AppLog.debug("⚠️ [ProfileVM] Failed to delete old avatar: \(error.localizedDescription)")
                }
            } else {
                AppLog.debug("ℹ️ [ProfileVM] No old avatar to delete (first upload)")
            }

            // Step 3: Upload new avatar to Firebase Storage
            AppLog.debug("📤 [ProfileVM] Uploading new avatar to Firebase Storage")
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

            // Step 6: Sync avatar URL across trips
            await syncAvatarURLAcrossTrips(uid: uid, newAvatarURL: response.downloadURL)

            AppLog.debug("✅ [ProfileVM] Avatar uploaded successfully")
            AppLog.debug("   URL: \(response.downloadURL)")
            AppLog.debug("   Storage Path: \(response.fullPath)")

            successMessage = "Foto profil berhasil diperbarui."

        } catch let error as StorageError {
            AppLog.debug("❌ [ProfileVM] Storage error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        } catch {
            AppLog.debug("❌ [ProfileVM] Upload error: \(error.localizedDescription)")
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
