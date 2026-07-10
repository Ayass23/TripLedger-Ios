import SwiftUI
import FirebaseCore

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
