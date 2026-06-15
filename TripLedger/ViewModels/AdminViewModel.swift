import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var allUsers: [UserModel] = []
    @Published var allReports: [ReportModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = FirestoreService.shared
    private var usersListener: ListenerRegistration?
    private var reportsListener: ListenerRegistration?

    deinit {
        usersListener?.remove()
        reportsListener?.remove()
    }

    // MARK: - Load All Users
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

    // MARK: - Suspend User
    func suspendUser(uid: String) async {
        do {
            try await db.update(
                collection: Collection.users,
                documentID: uid,
                fields: ["isSuspended": true]
            )
            print("✅ [AdminVM] User \(uid) suspended")

            // Refresh users list
            await loadAllUsers()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [AdminVM] Error suspending user: \(error)")
        }
    }

    // MARK: - Unsuspend User
    func unsuspendUser(uid: String) async {
        do {
            try await db.update(
                collection: Collection.users,
                documentID: uid,
                fields: ["isSuspended": false]
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
            await self.suspendUser(uid: report.reportedUID)
        }
    }

    // MARK: - Dismiss Report
    func dismissReport(reportID: String, adminUID: String, adminNotes: String?) async {
        await updateReportStatus(
            reportID: reportID,
            status: .dismissed,
            adminUID: adminUID,
            adminNotes: adminNotes
        )
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
}
