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




#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(NotificationsViewModel())
            .environmentObject(AuthViewModel())
            .environmentObject(TripViewModel())
            .environmentObject(FriendsViewModel())
    }
}
