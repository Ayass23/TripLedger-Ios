import SwiftUI
import FirebaseCore

struct NotificationsView: View {
    @EnvironmentObject private var notifVM: NotificationsViewModel
    @EnvironmentObject private var authVM:  AuthViewModel
    @EnvironmentObject private var tripVM:  TripViewModel
    @EnvironmentObject private var friendsVM: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedNotification: NotificationModel?
    @State private var selectedNotificationID: String?
    @State private var selectedInvite: TripInvite?
    @State private var showNotificationDetail = false

    // All items combined (invites + notifications)
    private var allUnreadItems: [UnreadItem] {
        var items: [UnreadItem] = []

        // Add unread notifications
        for notif in notifVM.notifications.filter({ !$0.isRead }) {
            items.append(.notification(notif))
        }

        // Add trip invites
        for invite in tripVM.pendingInvites {
            items.append(.invite(invite))
        }

        // Sort by created date
        return items.sorted { item1, item2 in
            item1.createdAt > item2.createdAt
        }
    }

    private var allReadNotifs: [NotificationModel] {
        notifVM.notifications.filter { $0.isRead }
    }

    enum UnreadItem: Identifiable {
        case notification(NotificationModel)
        case invite(TripInvite)

        var id: String {
            switch self {
            case .notification(let notif):
                return "notif_\(notif.id ?? "")"
            case .invite(let invite):
                return "invite_\(invite.id ?? "")"
            }
        }

        var createdAt: Date {
            switch self {
            case .notification(let notif):
                return notif.createdAt.dateValue()
            case .invite(let invite):
                return invite.createdAt.dateValue()
            }
        }
    }

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            if allUnreadItems.isEmpty && allReadNotifs.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Belum Dibaca
                        if !allUnreadItems.isEmpty {
                            sectionHeader(title: "Belum Dibaca", count: allUnreadItems.count, color: .brandAccent)

                            LazyVStack(spacing: 10) {
                                ForEach(allUnreadItems) { item in
                                    switch item {
                                    case .notification(let notif):
                                        NotifRow(notif: notif)
                                            .onTapGesture {
                                                selectedNotification = notif
                                                selectedNotificationID = notif.id
                                                print("📱 [NotifView] Tapped notification - ID: \(notif.id ?? "nil")")
                                                showNotificationDetail = true
                                            }
                                    case .invite(let invite):
                                        InviteNotifRow(invite: invite)
                                            .onTapGesture {
                                                selectedInvite = invite
                                                showNotificationDetail = true
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }

                        // MARK: - Sudah Dibaca
                        if !allReadNotifs.isEmpty {
                            if !allUnreadItems.isEmpty {
                                sectionDivider
                            }

                            sectionHeader(title: "Sudah Dibaca", count: allReadNotifs.count, color: .textPrimary.opacity(0.4))

                            LazyVStack(spacing: 10) {
                                ForEach(allReadNotifs) { notif in
                                    NotifRow(notif: notif)
                                        .onTapGesture {
                                            selectedNotification = notif
                                            selectedNotificationID = notif.id
                                            print("📱 [NotifView] Tapped read notification - ID: \(notif.id ?? "nil")")
                                            showNotificationDetail = true
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Notifikasi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showNotificationDetail) {
            if let notif = selectedNotification {
                NotificationDetailSheet(
                    notification: notif,
                    notificationID: selectedNotificationID,
                    onDismiss: {
                        showNotificationDetail = false
                        selectedNotification = nil
                        selectedNotificationID = nil
                    }
                )
                .environmentObject(authVM)
                .environmentObject(friendsVM)
                .environmentObject(tripVM)
                .environmentObject(notifVM)
            } else if let invite = selectedInvite {
                InviteDetailSheet(
                    invite: invite,
                    onDismiss: {
                        showNotificationDetail = false
                        selectedInvite = nil
                    }
                )
                .environmentObject(authVM)
                .environmentObject(tripVM)
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary.opacity(0.7))

            // Count badge
            Text("\(count)")
                .font(AppFont.caption2())
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(color)
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Section Divider
    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.textPrimary.opacity(0.06))
            .frame(height: 6)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.textPrimary.opacity(0.04))
                    .frame(width: 100, height: 100)
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.textPrimary.opacity(0.15))
            }
            Text("Tidak ada notifikasi")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary.opacity(0.5))
            Text("Notifikasi baru akan muncul di sini.")
                .font(AppFont.footnote())
                .foregroundColor(.textPrimary.opacity(0.35))
        }
    }
}

// MARK: - Invite Notification Row (without buttons)
struct InviteNotifRow: View {
    let invite: TripInvite

    var body: some View {
        HStack(spacing: 14) {
            // Unread indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.brandAccent)
                .frame(width: 3, height: 40)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(invite.tripName)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text("Undangan dari \(invite.inviterName)")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.5))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(invite.createdAt.dateValue().timeAgo())
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.3))

                Circle()
                    .fill(Color.brandAccent)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Notification Row
struct NotifRow: View {
    let notif: NotificationModel

    private var accentColor: Color {
        switch notif.type {
        case .tripInvite:      return .brandPrimary
        case .friendRequest:   return .brandAccent
        case .expenseAdded:    return .warningAmber
        case .settlementProof: return .successGreen
        case .paymentVerified: return .successGreen
        case .paymentRejected: return .errorRed
        case .general:         return .brandAccent
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Unread indicator bar
            if !notif.isRead {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brandAccent)
                    .frame(width: 3, height: 40)
            }

            // Icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: notif.icon)
                    .font(.system(size: 17))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(notif.title)
                    .font(AppFont.subheadline())
                    .foregroundColor(notif.isRead ? .textPrimary.opacity(0.5) : .textPrimary)
                    .lineLimit(1)
                Text(notif.body)
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(notif.isRead ? 0.3 : 0.5))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(notif.createdAt.dateValue().timeAgo())
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.3))

                if !notif.isRead {
                    Circle()
                        .fill(Color.brandAccent)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(notif.isRead ? Color.cardFallback.opacity(0.6) : Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(notif.isRead ? 0.02 : 0.05), radius: 6, y: 2)
    }
}

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

    private var accentColor: Color {
        switch notification.type {
        case .tripInvite:      return .brandPrimary
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

                    // Action buttons for friend requests
                    if notification.type == .friendRequest {
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
            }
            .onAppear {
                // Debug: Print notification info
                print("📋 [NotificationDetail] Notification ID (passed): \(notificationID ?? "nil")")
                print("📋 [NotificationDetail] Notification ID (model): \(notification.id ?? "nil")")
                print("📋 [NotificationDetail] Reference ID: \(notification.referenceID ?? "nil")")
                print("📋 [NotificationDetail] Type: \(notification.type.rawValue)")

                // Mark as read when sheet appears
                Task {
                    if let id = notificationID ?? notification.id {
                        await notifVM.markAsRead(notificationID: id)
                    } else {
                        print("⚠️ [NotificationDetail] Cannot mark as read - notification ID is nil")
                    }
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
                        print("❌ No referenceID found in notification")
                        return
                    }

                    // Use passed notificationID or fallback to notification.id
                    let notifID = notificationID ?? notification.id
                    guard let finalNotifID = notifID, !finalNotifID.isEmpty else {
                        print("❌ No notification ID found (passed: \(notificationID ?? "nil"), model: \(notification.id ?? "nil"))")
                        return
                    }

                    isProcessing = true
                    print("🔄 Rejecting friend request: \(requestID), notifID: \(finalNotifID)")

                    // Decline the friend request
                    await friendsVM.declineFriendRequestByID(requestID: requestID, notificationID: nil)

                    // Delete notification from UI immediately
                    await notifVM.deleteNotification(notificationID: finalNotifID)

                    isProcessing = false
                    print("✅ Request rejected, dismissing sheet")
                    onDismiss()
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
                        print("❌ No referenceID found in notification")
                        return
                    }
                    guard let user = authVM.currentUser else {
                        print("❌ No current user found")
                        return
                    }

                    // Use passed notificationID or fallback to notification.id
                    let notifID = notificationID ?? notification.id
                    guard let finalNotifID = notifID, !finalNotifID.isEmpty else {
                        print("❌ No notification ID found (passed: \(notificationID ?? "nil"), model: \(notification.id ?? "nil"))")
                        return
                    }

                    isProcessing = true
                    print("🔄 Accepting friend request: \(requestID), notifID: \(finalNotifID)")

                    // Accept the friend request
                    await friendsVM.acceptFriendRequestByID(requestID: requestID, currentUser: user, notificationID: nil)

                    if friendsVM.errorMessage == nil {
                        print("✅ Request accepted, refreshing user data")
                        await authVM.refreshUser()
                        if let updatedUser = authVM.currentUser {
                            await friendsVM.loadFriends(currentUser: updatedUser)
                        }

                        // Delete notification from UI immediately
                        await notifVM.deleteNotification(notificationID: finalNotifID)
                    } else {
                        print("❌ Error accepting request: \(friendsVM.errorMessage ?? "unknown")")
                    }

                    isProcessing = false
                    print("✅ Done, dismissing sheet")
                    onDismiss()
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
    }
}

// MARK: - Invite Detail Sheet
struct InviteDetailSheet: View {
    let invite: TripInvite
    let onDismiss: () -> Void

    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var tripVM: TripViewModel

    @State private var isProcessing = false

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
                                    .fill(Color.brandPrimary.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "airplane.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.brandPrimary)
                            }
                            .padding(.top, 20)

                            // Content
                            VStack(spacing: 12) {
                                Text(invite.tripName)
                                    .font(AppFont.title2())
                                    .fontWeight(.bold)
                                    .foregroundColor(.textPrimary)
                                    .multilineTextAlignment(.center)

                                Text("Undangan Trip")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textSecondary)

                                Text("Dari: \(invite.inviterName)")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textSecondary.opacity(0.7))
                                    .padding(.top, 4)

                                Text(invite.createdAt.dateValue().timeAgo())
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textSecondary.opacity(0.5))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }

                    // Action buttons
                    actionButtons
                }
            }
            .navigationTitle("Detail Undangan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        onDismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Reject button
            Button {
                Task {
                    isProcessing = true
                    await tripVM.rejectInvite(invite)
                    isProcessing = false
                    onDismiss()
                }
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.errorRed.opacity(0.1))
                            .frame(height: 60)
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.errorRed)
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
                    guard let user = authVM.currentUser else { return }
                    isProcessing = true
                    await tripVM.acceptInvite(invite, user: user)
                    isProcessing = false
                    onDismiss()
                }
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.successGreen.opacity(0.1))
                            .frame(height: 60)
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.successGreen)
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
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(NotificationsViewModel())
            .environmentObject(AuthViewModel())
            .environmentObject(TripViewModel())
            .environmentObject(FriendsViewModel())
    }
}
