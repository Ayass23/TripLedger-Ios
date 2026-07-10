//  NotificationsView.swift
//  Daftar notifikasi: undangan trip, permintaan pertemanan, dan info settlement.
//
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

    // Settlement verification
    @State private var selectedSettlement: Settlement?
    @State private var showSettlementVerification = false
    @StateObject private var settlementVM = SettlementViewModel()

    // SECTION 1: Undangan (Invites + Pending Friend Requests)
    private var invitationItems: [UnreadItem] {
        var items: [UnreadItem] = []

        // Add trip invites
        for invite in tripVM.pendingInvites {
            items.append(.invite(invite))
        }

        // Add ONLY pending friend request notifications (filter by title "Permintaan Pertemanan")
        for notif in notifVM.notifications.filter({ $0.type == .friendRequest && $0.title == "Permintaan Pertemanan" }) {
            items.append(.notification(notif))
        }

        // Sort by created date
        return items.sorted { item1, item2 in
            item1.createdAt > item2.createdAt
        }
    }

    // SECTION 2: Notifikasi (All other notifications including accepted/rejected friend requests)
    private var regularNotifications: [NotificationModel] {
        notifVM.notifications.filter {
            // Include if NOT friend request, OR if friend request but NOT "Permintaan Pertemanan"
            $0.type != .friendRequest || $0.title != "Permintaan Pertemanan"
        }
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

            if invitationItems.isEmpty && regularNotifications.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Undangan
                        if !invitationItems.isEmpty {
                            sectionHeader(title: "Undangan", count: invitationItems.count, color: .brandAccent)

                            LazyVStack(spacing: 10) {
                                ForEach(invitationItems) { item in
                                    switch item {
                                    case .notification(let notif):
                                        NotifRow(notif: notif, forceShowIndicator: true)
                                            .onTapGesture {
                                                selectedNotification = notif
                                                selectedNotificationID = notif.id
                                                AppLog.debug("📱 [NotifView] Tapped invitation notification - ID: \(notif.id ?? "nil")")
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

                        // MARK: - Notifikasi
                        if !regularNotifications.isEmpty {
                            if !invitationItems.isEmpty {
                                sectionDivider
                            }

                            sectionHeader(title: "Notifikasi", count: regularNotifications.count, color: .textPrimary.opacity(0.4))

                            LazyVStack(spacing: 10) {
                                ForEach(regularNotifications) { notif in
                                    NotifRow(notif: notif, forceShowIndicator: false)
                                        .onTapGesture {
                                            handleNotificationTap(notif)
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
        .navigationDestination(isPresented: $showSettlementVerification) {
            if let settlement = selectedSettlement {
                SettlementVerificationView(
                    settlementVM: settlementVM,
                    settlement: settlement
                )
                .environmentObject(authVM)
            }
        }
    }

    // MARK: - Handle Notification Tap
    private func handleNotificationTap(_ notif: NotificationModel) {
        // Only navigate to SettlementVerificationView for settlementProof (pending verification)
        if notif.type == .settlementProof {
            Task {
                await fetchAndShowSettlement(notif: notif)
            }
        } else {
            // Regular notification handling (including paymentVerified & paymentRejected)
            // paymentRejected will show rejection reason in body message
            selectedNotification = notif
            selectedNotificationID = notif.id
            AppLog.debug("📱 [NotifView] Tapped regular notification - ID: \(notif.id ?? "nil")")
            showNotificationDetail = true
        }
    }

    private func fetchAndShowSettlement(notif: NotificationModel) async {
        guard let settlementID = notif.referenceID else {
            AppLog.debug("❌ [NotifView] No referenceID for settlement notification")
            return
        }

        do {
            let settlement: Settlement = try await FirestoreService.shared.fetch(
                collection: Collection.settlements,
                documentID: settlementID
            )

            await MainActor.run {
                selectedSettlement = settlement
                showSettlementVerification = true
            }

            // Mark notification as read
            if let notifID = notif.id {
                await notifVM.markAsRead(notificationID: notifID)
            }
        } catch {
            AppLog.debug("❌ [NotifView] Failed to fetch settlement: \(error)")
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
    let forceShowIndicator: Bool // true = selalu tampilkan (untuk undangan), false = based on isRead

    private var accentColor: Color {
        switch notif.type {
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

    private var shouldShowIndicator: Bool {
        forceShowIndicator || !notif.isRead
    }

    var body: some View {
        HStack(spacing: 14) {
            // Unread indicator bar
            if shouldShowIndicator {
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
                    .foregroundColor(forceShowIndicator ? .textPrimary : (notif.isRead ? .textPrimary.opacity(0.5) : .textPrimary))
                    .lineLimit(1)
                Text(notif.body)
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(forceShowIndicator ? 0.5 : (notif.isRead ? 0.3 : 0.5)))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(notif.createdAt.dateValue().timeAgo())
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.3))

                if shouldShowIndicator {
                    Circle()
                        .fill(Color.brandAccent)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(forceShowIndicator ? Color.cardFallback : (notif.isRead ? Color.cardFallback.opacity(0.6) : Color.cardFallback))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(forceShowIndicator ? 0.05 : (notif.isRead ? 0.02 : 0.05)), radius: 6, y: 2)
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
