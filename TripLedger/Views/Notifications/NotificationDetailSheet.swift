import SwiftUI
import FirebaseCore

// MARK: - Notification Detail Sheet
struct NotificationDetailSheet: View {
    let notification: NotificationModel
    let notificationID: String?
    let onDismiss: () -> Void

    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var friendsVM: FriendsViewModel
    @EnvironmentObject private var tripVM: TripViewModel
    @EnvironmentObject private var notifVM: NotificationsViewModel

    @State private var isProcessing = false
    @State private var showSuccessAlert = false
    @State private var alertMessage = ""

    private var accentColor: Color {
        switch notification.type {
        case .tripInvite:      return .brandPrimary
        case .tripEnded:       return .warningAmber
        case .friendRequest:   return .brandAccent
        case .expenseAdded:    return .warningAmber
        case .settlementProof: return .successGreen
        case .paymentVerified: return .successGreen
        case .paymentRejected: return .errorRed
        case .general:         return .brandAccent
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Image(systemName: notification.icon)
                                    .font(.system(size: 36))
                                    .foregroundColor(accentColor)
                            }
                            .padding(.top, 20)

                            // Content
                            VStack(spacing: 12) {
                                Text(notification.title)
                                    .font(AppFont.title2())
                                    .fontWeight(.bold)
                                    .foregroundColor(.textPrimary)
                                    .multilineTextAlignment(.center)

                                Text(notification.body)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)

                                if let senderName = notification.senderName {
                                    Text("Dari: \(senderName)")
                                        .font(AppFont.caption())
                                        .foregroundColor(.textSecondary.opacity(0.7))
                                        .padding(.top, 4)
                                }

                                Text(notification.createdAt.dateValue().timeAgo())
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textSecondary.opacity(0.5))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    // Action buttons ONLY for PENDING friend requests (not "Permintaan Diterima")
                    if notification.type == .friendRequest && notification.title == "Permintaan Pertemanan" {
                        actionButtons
                    }
                }
            }
            .navigationTitle("Detail Notifikasi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        onDismiss()
                    }
                    .foregroundColor(.textSecondary)
                }

                // Show delete button only for read notifications (except pending friend requests)
                if notification.isRead && !(notification.type == .friendRequest && notification.title == "Permintaan Pertemanan") {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                if let id = notificationID ?? notification.id {
                                    await notifVM.deleteNotification(notificationID: id)
                                    onDismiss()
                                }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.errorRed)
                        }
                    }
                }
            }
            .onAppear {
                // Debug: Print notification info
                AppLog.debug("📋 [NotificationDetail] Notification ID (passed): \(notificationID ?? "nil")")
                AppLog.debug("📋 [NotificationDetail] Notification ID (model): \(notification.id ?? "nil")")
                AppLog.debug("📋 [NotificationDetail] Reference ID: \(notification.referenceID ?? "nil")")
                AppLog.debug("📋 [NotificationDetail] Type: \(notification.type.rawValue)")

                // Mark as read when sheet appears - EXCEPT for actionable invitations
                // Skip auto mark-as-read for:
                // 1. Pending friend requests (title = "Permintaan Pertemanan")
                // 2. Trip invites (type = tripInvite BUT NOT "Anggota Baru Bergabung")
                let isPendingFriendRequest = notification.type == .friendRequest && notification.title == "Permintaan Pertemanan"
                let isActionableTripInvite = notification.type == .tripInvite && notification.title != "Anggota Baru Bergabung"

                if !isPendingFriendRequest && !isActionableTripInvite {
                    Task {
                        if let id = notificationID ?? notification.id {
                            await notifVM.markAsRead(notificationID: id)
                        } else {
                            AppLog.debug("⚠️ [NotificationDetail] Cannot mark as read - notification ID is nil")
                        }
                    }
                } else {
                    AppLog.debug("📋 [NotificationDetail] Skipping auto mark-as-read for actionable invitation: \(notification.title)")
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Reject button
            Button {
                Task {
                    guard let requestID = notification.referenceID, !requestID.isEmpty else {
                        AppLog.debug("❌ No referenceID found in notification")
                        return
                    }

                    // Use passed notificationID or fallback to notification.id
                    let notifID = notificationID ?? notification.id
                    guard let finalNotifID = notifID, !finalNotifID.isEmpty else {
                        AppLog.debug("❌ No notification ID found (passed: \(notificationID ?? "nil"), model: \(notification.id ?? "nil"))")
                        return
                    }

                    isProcessing = true
                    AppLog.debug("🔄 Rejecting friend request: \(requestID), notifID: \(finalNotifID)")

                    // Decline the friend request
                    await friendsVM.declineFriendRequestByID(requestID: requestID, notificationID: nil)

                    // Delete notification from UI immediately
                    await notifVM.deleteNotification(notificationID: finalNotifID)

                    isProcessing = false

                    // Show success alert
                    if friendsVM.errorMessage == nil {
                        alertMessage = "Permintaan pertemanan telah ditolak."
                        showSuccessAlert = true
                    } else {
                        onDismiss()
                    }
                }
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.errorRed.opacity(0.1))
                            .frame(height: 60)

                        if isProcessing {
                            ProgressView()
                                .tint(.errorRed)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.errorRed)
                        }
                    }
                    Text("Tolak")
                        .font(AppFont.caption())
                        .foregroundColor(.errorRed)
                }
            }
            .disabled(isProcessing)

            // Accept button
            Button {
                Task {
                    guard let requestID = notification.referenceID, !requestID.isEmpty else {
                        AppLog.debug("❌ No referenceID found in notification")
                        return
                    }
                    guard let user = authVM.currentUser else {
                        AppLog.debug("❌ No current user found")
                        return
                    }

                    // Use passed notificationID or fallback to notification.id
                    let notifID = notificationID ?? notification.id
                    guard let finalNotifID = notifID, !finalNotifID.isEmpty else {
                        AppLog.debug("❌ No notification ID found (passed: \(notificationID ?? "nil"), model: \(notification.id ?? "nil"))")
                        return
                    }

                    isProcessing = true
                    AppLog.debug("🔄 Accepting friend request: \(requestID), notifID: \(finalNotifID)")

                    // Accept the friend request
                    await friendsVM.acceptFriendRequestByID(requestID: requestID, currentUser: user, notificationID: nil)

                    if friendsVM.errorMessage == nil {
                        AppLog.debug("✅ Request accepted, refreshing user data")
                        await authVM.refreshUser()
                        if let updatedUser = authVM.currentUser {
                            await friendsVM.loadFriends(currentUser: updatedUser)
                        }

                        // Delete notification from UI immediately
                        await notifVM.deleteNotification(notificationID: finalNotifID)

                        // Show success alert
                        let senderName = notification.senderName ?? "pengguna ini"
                        alertMessage = "Sekarang kamu dan \(senderName) sudah berteman! 🎉"
                        showSuccessAlert = true
                    } else {
                        AppLog.debug("❌ Error accepting request: \(friendsVM.errorMessage ?? "unknown")")
                        onDismiss()
                    }

                    isProcessing = false
                }
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.successGreen.opacity(0.1))
                            .frame(height: 60)

                        if isProcessing {
                            ProgressView()
                                .tint(.successGreen)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.successGreen)
                        }
                    }
                    Text("Terima")
                        .font(AppFont.caption())
                        .foregroundColor(.successGreen)
                }
            }
            .disabled(isProcessing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.baseFallback)
        .alert("Permintaan Pertemanan", isPresented: $showSuccessAlert) {
            Button("OK") {
                onDismiss()
            }
        } message: {
            Text(alertMessage)
        }
        .tint(.brandPrimary)
    }
}
