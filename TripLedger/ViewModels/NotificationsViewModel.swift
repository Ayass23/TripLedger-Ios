import Foundation
import Combine
import FirebaseFirestore

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
            // Count: All unread notifications
            // Pending friend requests stay unread until action, "Permintaan Diterima" marked as read when opened
            self?.unreadCount = notifs.filter { !$0.isRead }.count
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
