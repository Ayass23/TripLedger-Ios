import SwiftUI
import FirebaseCore

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
