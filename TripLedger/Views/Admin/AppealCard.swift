import SwiftUI
import FirebaseFirestore

// MARK: - Appeal Card Component
struct AppealCard: View {
    let appeal: AccountAppeal
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandPrimary.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.brandPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.brandPrimary)
                            Text("BANDING PEMULIHAN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.brandPrimary)
                        }

                        Text(appeal.userName)
                            .font(AppFont.subheadline())
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text(appeal.userEmail)
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(timeAgo(from: appeal.createdAt.dateValue()))
                                .font(AppFont.caption2())
                        }
                        .foregroundColor(.textSecondary.opacity(0.7))
                    }

                    Spacer()

                    // Status Badge
                    Text(appeal.status.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor)
                        .clipShape(Capsule())
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Alasan Banding:")
                        .font(AppFont.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.textSecondary)

                    Text(appeal.appealReason)
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            AppealDetailSheet(appeal: appeal, adminVM: adminVM, currentAdminUID: currentAdminUID)
        }
    }

    private var statusColor: Color {
        switch appeal.status {
        case .pending: return Color.warningAmber
        case .approved: return Color.successGreen
        case .rejected: return Color.errorRed
        }
    }

    // Sengaja tidak memakai Date.timeAgo(): versi ini tetap menampilkan "N hari lalu"
    // untuk tanggal lama, sedangkan Date.timeAgo() beralih ke format tanggal setelah 7 hari.
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days) hari lalu"
        } else if hours > 0 {
            return "\(hours) jam lalu"
        } else if minutes > 0 {
            return "\(minutes) menit lalu"
        } else {
            return "Baru saja"
        }
    }
}
