import SwiftUI
import FirebaseFirestore

// MARK: - User Management Card
struct UserManagementCard: View {
    let user: UserModel
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @State private var showSuspendAlert = false
    @State private var showUnsuspendAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarView(url: user.avatarURL, initials: user.initials, size: 56)
                    .overlay(
                        Circle()
                            .stroke(
                                user.isSuspended ? Color.errorRed.opacity(0.3) : Color.successGreen.opacity(0.2),
                                lineWidth: 2.5
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.displayName)
                            .font(AppFont.subheadline())
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        if user.role == .admin {
                            Text("ADMIN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [Color.adminPurple, Color.adminPurpleDark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }

                        if user.isSuspended {
                            Text("SUSPENDED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.errorRed)
                                .clipShape(Capsule())
                        }
                    }

                    Text(user.email)
                        .font(AppFont.caption())
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text("Bergabung \(formatDate(user.createdAt.dateValue()))")
                            .font(AppFont.caption2())
                    }
                    .foregroundColor(.textSecondary.opacity(0.8))
                }

                Spacer()
            }

            // Actions
            if user.role != .admin && user.uid != currentAdminUID {
                Divider()
                    .background(Color.borderSoft)

                HStack(spacing: 10) {
                    if user.isSuspended {
                        Button {
                            showUnsuspendAlert = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Aktifkan Kembali")
                                    .font(AppFont.caption())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.successGreen, Color.successGreen.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            showSuspendAlert = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.shield.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Suspend Akun")
                                    .font(AppFont.caption())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.errorRed, Color.errorRed.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        .alert("Suspend Akun", isPresented: $showSuspendAlert) {
            Button("Batal", role: .cancel) { }
            Button("Suspend", role: .destructive) {
                Task {
                    await adminVM.suspendUser(uid: user.uid)
                }
            }
        } message: {
            Text("Apakah kamu yakin ingin suspend akun \(user.displayName)? Pengguna tidak akan bisa login ke aplikasi.")
        }
        .alert("Aktifkan Kembali", isPresented: $showUnsuspendAlert) {
            Button("Batal", role: .cancel) { }
            Button("Aktifkan") {
                Task {
                    await adminVM.unsuspendUser(uid: user.uid)
                }
            }
        } message: {
            Text("Aktifkan kembali akun \(user.displayName)? Pengguna akan bisa login ke aplikasi lagi.")
        }
        .tint(.brandPrimary)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }
}
