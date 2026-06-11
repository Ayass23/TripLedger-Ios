import Foundation
import Combine
import FirebaseFirestore
import PDFKit
import SwiftUI

// MARK: - Notifications ViewModel
@MainActor
final class NotificationsViewModel: ObservableObject {

    @Published var notifications: [NotificationModel] = []
    @Published var unreadCount    = 0

    private let db = FirestoreService.shared
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func listenNotifications(uid: String) {
        listener = db.listen(collection: Collection.notifications, queryBuilder: { ref in
            ref.whereField("recipientUID", isEqualTo: uid)
               .order(by: "createdAt", descending: true)
               .limit(to: 50)
        }) { [weak self] (notifs: [NotificationModel]) in
            self?.notifications = notifs
            self?.unreadCount   = notifs.filter { !$0.isRead }.count
        }
    }

    func markAsRead(notificationID: String) async {
        guard !notificationID.isEmpty else { return }
        try? await db.update(collection: Collection.notifications, documentID: notificationID, fields: ["isRead": true])
        if let idx = notifications.firstIndex(where: { $0.id == notificationID }) {
            notifications[idx].isRead = true
            unreadCount = notifications.filter { !$0.isRead }.count
        }
    }

    func markAllAsRead(uid: String) async {
        let unread = notifications.filter { !$0.isRead }
        await withTaskGroup(of: Void.self) { group in
            for notif in unread {
                group.addTask { [weak self] in
                    guard let id = notif.id else { return }
                    await self?.markAsRead(notificationID: id)
                }
            }
        }
    }

    func deleteNotification(notificationID: String) async {
        guard !notificationID.isEmpty else { return }
        do {
            try await db.db.collection(Collection.notifications)
                .document(notificationID)
                .delete()

            // Remove from local array immediately for instant UI update
            notifications.removeAll { $0.id == notificationID }
            unreadCount = notifications.filter { !$0.isRead }.count

            print("✅ [NotifVM] Notification deleted: \(notificationID)")
        } catch {
            print("❌ [NotifVM] Error deleting notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - Report ViewModel
@MainActor
final class ReportViewModel: ObservableObject {

    @Published var isGeneratingPDF = false

    // MARK: - Generate PDF report
    func generatePDF(trip: TripModel, expenses: [ExpenseModel]) -> Data? {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)) // A4
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]

            // Title
            "Trip Ledger — Report".draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)
            trip.name.draw(at: CGPoint(x: 40, y: 72), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])

            var y: CGFloat = 110
            // Summary header
            "Expense Summary".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16)])
            y += 28

            // Expense list
            for expense in expenses {
                let line = "\(expense.title)  —  \(expense.amount.toCurrency(symbol: expense.currency))  (\(expense.category.displayName))"
                line.draw(at: CGPoint(x: 40, y: y), withAttributes: bodyAttrs)
                y += 20
                if y > 800 { ctx.beginPage(); y = 40 }
            }

            // Total
            y += 8
            let total = "Total: \(expenses.reduce(0) { $0 + $1.amount }.toCurrency())"
            total.draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
        }
    }
}
