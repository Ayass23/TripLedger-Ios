import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var allUsers: [UserModel] = []
    @Published var allReports: [ReportModel] = []
    @Published var allAppeals: [AccountAppeal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = FirestoreService.shared
    private var usersListener: ListenerRegistration?
    private var reportsListener: ListenerRegistration?
    private var appealsListener: ListenerRegistration?

    deinit {
        usersListener?.remove()
        reportsListener?.remove()
        appealsListener?.remove()
    }

    // MARK: - Listen to Users (real-time)
    func listenToUsers() {
        usersListener?.remove()

        usersListener = db.db.collection(Collection.users)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [AdminVM] Error listening to users: \(error)")
                    self?.errorMessage = error.localizedDescription
                    return
                }

                self?.allUsers = snapshot?.documents.compactMap { try? $0.data(as: UserModel.self) } ?? []
                print("✅ [AdminVM] Loaded \(self?.allUsers.count ?? 0) users (real-time)")
            }
    }

    // MARK: - Load All Users (one-time fetch - kept for compatibility)
    func loadAllUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db.db.collection(Collection.users)
                .order(by: "createdAt", descending: true)
                .getDocuments()

            allUsers = snapshot.documents.compactMap { try? $0.data(as: UserModel.self) }
            print("✅ [AdminVM] Loaded \(allUsers.count) users")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [AdminVM] Error loading users: \(error)")
        }
    }

    // MARK: - Listen to Reports
    func listenToReports() {
        reportsListener?.remove()

        reportsListener = db.db.collection(Collection.reports)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [AdminVM] Error listening to reports: \(error)")
                    self?.errorMessage = error.localizedDescription
                    return
                }

                self?.allReports = snapshot?.documents.compactMap { try? $0.data(as: ReportModel.self) } ?? []
                print("✅ [AdminVM] Loaded \(self?.allReports.count ?? 0) reports")
            }
    }

    // MARK: - Listen to Appeals
    func listenToAppeals() {
        appealsListener?.remove()

        appealsListener = db.db.collection(Collection.appeals)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [AdminVM] Error listening to appeals: \(error)")
                    self?.errorMessage = error.localizedDescription
                    return
                }

                self?.allAppeals = snapshot?.documents.compactMap { try? $0.data(as: AccountAppeal.self) } ?? []
                print("✅ [AdminVM] Loaded \(self?.allAppeals.count ?? 0) appeals")
            }
    }

    // MARK: - Suspend User
    func suspendUser(uid: String, reason: String? = nil) async {
        do {
            var fields: [String: Any] = ["isSuspended": true]
            if let reason = reason {
                fields["suspendReason"] = reason
            }

            try await db.update(
                collection: Collection.users,
                documentID: uid,
                fields: fields
            )
            print("✅ [AdminVM] User \(uid) suspended with reason: \(reason ?? "N/A")")

            // Transfer ownership of trips where this user is owner
            await transferOwnershipFromSuspendedUser(uid: uid)

            // Refresh users list
            await loadAllUsers()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [AdminVM] Error suspending user: \(error)")
        }
    }

    // MARK: - Transfer Ownership From Suspended User
    private func transferOwnershipFromSuspendedUser(uid: String) async {
        do {
            // Find all trips where this user is owner
            let snapshot = try await db.db.collection(Collection.trips)
                .whereField("ownerUID", isEqualTo: uid)
                .getDocuments()

            for doc in snapshot.documents {
                guard var trip = try? doc.data(as: TripModel.self),
                      let tripID = trip.id else { continue }

                // Find new owner: first admin (other than suspended user), or oldest member
                let activeAdmins = trip.adminUIDs.filter { $0 != uid }
                let activeMembers = trip.members.filter { $0.uid != uid && $0.role != .pending }
                    .sorted { $0.joinedAt.dateValue() < $1.joinedAt.dateValue() }

                var newOwnerUID: String?

                if let firstAdmin = activeAdmins.first {
                    newOwnerUID = firstAdmin
                } else if let firstMember = activeMembers.first {
                    newOwnerUID = firstMember.uid
                }

                guard let newOwner = newOwnerUID else {
                    // No eligible member to become owner, delete the trip
                    print("⚠️ [AdminVM] No eligible new owner for trip \(trip.name) - deleting trip")

                    // Delete all expenses for this trip
                    let expensesSnapshot = try await db.db.collection(Collection.expenses)
                        .whereField("tripID", isEqualTo: tripID)
                        .getDocuments()
                    for expenseDoc in expensesSnapshot.documents {
                        try await expenseDoc.reference.delete()
                    }

                    // Delete all settlements for this trip
                    let settlementsSnapshot = try await db.db.collection(Collection.settlements)
                        .whereField("tripID", isEqualTo: tripID)
                        .getDocuments()
                    for settlementDoc in settlementsSnapshot.documents {
                        try await settlementDoc.reference.delete()
                    }

                    // Delete the trip document
                    try await db.db.collection(Collection.trips).document(tripID).delete()

                    print("✅ [AdminVM] Deleted orphan trip '\(trip.name)' (no eligible owner after suspension)")
                    continue
                }

                // Update owner in trip
                var newAdminUIDs = trip.adminUIDs
                if !newAdminUIDs.contains(newOwner) {
                    newAdminUIDs.append(newOwner)
                }

                // Update member role to owner
                var updatedMembers = trip.members
                if let memberIndex = updatedMembers.firstIndex(where: { $0.uid == newOwner }) {
                    updatedMembers[memberIndex] = TripMember(
                        id: updatedMembers[memberIndex].id,
                        uid: updatedMembers[memberIndex].uid,
                        displayName: updatedMembers[memberIndex].displayName,
                        avatarURL: updatedMembers[memberIndex].avatarURL,
                        role: .owner,
                        joinedAt: updatedMembers[memberIndex].joinedAt
                    )
                }

                // Demote old owner to member in members array
                if let oldOwnerIndex = updatedMembers.firstIndex(where: { $0.uid == uid }) {
                    updatedMembers[oldOwnerIndex] = TripMember(
                        id: updatedMembers[oldOwnerIndex].id,
                        uid: updatedMembers[oldOwnerIndex].uid,
                        displayName: updatedMembers[oldOwnerIndex].displayName,
                        avatarURL: updatedMembers[oldOwnerIndex].avatarURL,
                        role: .member,
                        joinedAt: updatedMembers[oldOwnerIndex].joinedAt
                    )
                }

                let memberDicts = updatedMembers.map { [
                    "id": $0.id,
                    "uid": $0.uid,
                    "displayName": $0.displayName,
                    "avatarURL": $0.avatarURL ?? "",
                    "role": $0.role.rawValue,
                    "joinedAt": $0.joinedAt
                ]}

                try await db.update(collection: Collection.trips, documentID: tripID, fields: [
                    "ownerUID": newOwner,
                    "adminUIDs": newAdminUIDs,
                    "members": memberDicts
                ])

                print("✅ [AdminVM] Transferred ownership of trip '\(trip.name)' from \(uid) to \(newOwner)")

                // Send notification to new owner
                let notification = NotificationModel(
                    recipientUID: newOwner,
                    type: .general,
                    title: "Kamu Sekarang Owner Trip",
                    body: "Kamu telah menjadi owner trip \"\(trip.name)\" karena owner sebelumnya tidak lagi aktif.",
                    isRead: false,
                    referenceID: tripID,
                    senderUID: "system",
                    senderName: "Sistem",
                    createdAt: Timestamp(date: Date())
                )
                try await db.db.collection(Collection.notifications).addDocument(from: notification)
            }
        } catch {
            print("❌ [AdminVM] Error transferring ownership: \(error)")
        }
    }

    // MARK: - Unsuspend User
    func unsuspendUser(uid: String) async {
        do {
            try await db.update(
                collection: Collection.users,
                documentID: uid,
                fields: [
                    "isSuspended": false,
                    "suspendReason": FieldValue.delete() // Clear suspend reason
                ]
            )
            print("✅ [AdminVM] User \(uid) unsuspended")

            // Refresh users list
            await loadAllUsers()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [AdminVM] Error unsuspending user: \(error)")
        }
    }

    // MARK: - Update Report Status
    func updateReportStatus(reportID: String, status: ReportStatus, adminUID: String, adminNotes: String? = nil) async {
        var fields: [String: Any] = [
            "status": status.rawValue,
            "resolvedBy": adminUID,
            "resolvedAt": Timestamp(date: Date())
        ]

        if let notes = adminNotes, !notes.isEmpty {
            fields["adminNotes"] = notes
        }

        do {
            try await db.update(
                collection: Collection.reports,
                documentID: reportID,
                fields: fields
            )
            print("✅ [AdminVM] Report \(reportID) updated to \(status.rawValue)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [AdminVM] Error updating report: \(error)")
        }
    }

    // MARK: - Resolve Report (and optionally suspend user)
    func resolveReport(reportID: String, suspendUser: Bool, adminUID: String, adminNotes: String?) async {
        guard let report = allReports.first(where: { $0.id == reportID }) else { return }

        // Update report status
        await updateReportStatus(
            reportID: reportID,
            status: .resolved,
            adminUID: adminUID,
            adminNotes: adminNotes
        )

        // Suspend user if requested
        if suspendUser {
            await self.suspendUser(uid: report.reportedUID, reason: adminNotes)
        }

        // Send notification to reporter
        do {
            let notification = NotificationModel(
                recipientUID: report.reporterUID,
                type: .general,
                title: "Laporan Diproses",
                body: suspendUser
                    ? "Laporan kamu terhadap \(report.reportedName) telah ditindaklanjuti. Pengguna telah disuspend."
                    : "Laporan kamu terhadap \(report.reportedName) telah ditinjau dan diselesaikan oleh admin.",
                isRead: false,
                referenceID: reportID,
                senderUID: adminUID,
                senderName: "Admin",
                createdAt: Timestamp(date: Date())
            )
            try await db.db.collection(Collection.notifications).addDocument(from: notification)
            print("✅ [AdminVM] Notification sent to reporter \(report.reporterUID)")
        } catch {
            print("⚠️ [AdminVM] Failed to send notification to reporter: \(error)")
        }
    }

    // MARK: - Dismiss Report
    func dismissReport(reportID: String, adminUID: String, adminNotes: String?) async {
        guard let report = allReports.first(where: { $0.id == reportID }) else { return }

        await updateReportStatus(
            reportID: reportID,
            status: .dismissed,
            adminUID: adminUID,
            adminNotes: adminNotes
        )

        // Send notification to reporter
        do {
            let notificationBody = adminNotes?.isEmpty == false
                ? "Laporan kamu terhadap \(report.reportedName) ditolak. Alasan: \(adminNotes!)"
                : "Laporan kamu terhadap \(report.reportedName) telah ditinjau dan ditolak oleh admin."

            let notification = NotificationModel(
                recipientUID: report.reporterUID,
                type: .general,
                title: "Laporan Ditolak",
                body: notificationBody,
                isRead: false,
                referenceID: reportID,
                senderUID: adminUID,
                senderName: "Admin",
                createdAt: Timestamp(date: Date())
            )
            try await db.db.collection(Collection.notifications).addDocument(from: notification)
            print("✅ [AdminVM] Notification sent to reporter \(report.reporterUID)")
        } catch {
            print("⚠️ [AdminVM] Failed to send notification to reporter: \(error)")
        }
    }

    // MARK: - Search Users
    func searchUsers(query: String) -> [UserModel] {
        guard !query.isEmpty else { return allUsers }

        let lowercased = query.lowercased()
        return allUsers.filter { user in
            user.displayName.lowercased().contains(lowercased) ||
            user.email.lowercased().contains(lowercased)
        }
    }

    // MARK: - Filter Reports
    func filteredReports(by status: ReportStatus?) -> [ReportModel] {
        guard let status = status else { return allReports }
        return allReports.filter { $0.status == status }
    }

    // MARK: - Filter Appeals
    func filteredAppeals(by status: AppealStatus?) -> [AccountAppeal] {
        guard let status = status else { return allAppeals }
        return allAppeals.filter { $0.status == status }
    }

    // MARK: - Approve Appeal (Unsuspend User)
    func approveAppeal(appealID: String, adminUID: String, adminNotes: String?) async {
        guard let appeal = allAppeals.first(where: { $0.id == appealID }) else { return }

        do {
            // 1. Update appeal status
            var fields: [String: Any] = [
                "status": AppealStatus.approved.rawValue,
                "resolvedBy": adminUID,
                "resolvedAt": Timestamp(date: Date())
            ]

            if let notes = adminNotes, !notes.isEmpty {
                fields["adminNotes"] = notes
            }

            try await db.update(
                collection: Collection.appeals,
                documentID: appealID,
                fields: fields
            )

            // 2. Unsuspend the user
            await unsuspendUser(uid: appeal.userUID)

            // 3. Send notification to user
            let notification = NotificationModel(
                recipientUID: appeal.userUID,
                type: .general,
                title: "Banding Disetujui",
                body: "Banding kamu telah disetujui. Akun kamu sudah dipulihkan dan kamu bisa login kembali.",
                isRead: false,
                referenceID: appealID,
                senderUID: adminUID,
                senderName: "Admin",
                createdAt: Timestamp(date: Date())
            )

            try await db.db.collection(Collection.notifications).addDocument(from: notification)

            print("✅ [AdminVM] Appeal approved and user unsuspended")
            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
            print("❌ [AdminVM] Error approving appeal: \(error)")
        }
    }

    // MARK: - Reject Appeal
    func rejectAppeal(appealID: String, adminUID: String, adminNotes: String?) async {
        guard let appeal = allAppeals.first(where: { $0.id == appealID }) else { return }

        do {
            // 1. Update appeal status
            var fields: [String: Any] = [
                "status": AppealStatus.rejected.rawValue,
                "resolvedBy": adminUID,
                "resolvedAt": Timestamp(date: Date())
            ]

            if let notes = adminNotes, !notes.isEmpty {
                fields["adminNotes"] = notes
            }

            try await db.update(
                collection: Collection.appeals,
                documentID: appealID,
                fields: fields
            )

            // 2. Update user's suspendReason with new admin notes if provided
            if let notes = adminNotes, !notes.isEmpty {
                try await db.update(
                    collection: Collection.users,
                    documentID: appeal.userUID,
                    fields: ["suspendReason": notes]
                )
                print("✅ [AdminVM] Updated user suspend reason with rejection notes")
            }

            // 3. Send notification to user
            let notification = NotificationModel(
                recipientUID: appeal.userUID,
                type: .general,
                title: "Banding Ditolak",
                body: "Banding kamu telah ditinjau dan ditolak. \(adminNotes ?? "")",
                isRead: false,
                referenceID: appealID,
                senderUID: adminUID,
                senderName: "Admin",
                createdAt: Timestamp(date: Date())
            )

            try await db.db.collection(Collection.notifications).addDocument(from: notification)

            print("✅ [AdminVM] Appeal rejected")
            errorMessage = nil

        } catch {
            errorMessage = error.localizedDescription
            print("❌ [AdminVM] Error rejecting appeal: \(error)")
        }
    }
}
