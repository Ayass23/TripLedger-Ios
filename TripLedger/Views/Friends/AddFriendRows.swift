import SwiftUI
import Kingfisher

// MARK: - Selected User Chip
struct SelectedUserChip: View {
    let user: UserModel
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 24, height: 24)

                Text(user.displayName.prefix(1).uppercased())
                    .font(AppFont.caption2())
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.bold)
            }

            Text(user.displayName)
                .font(AppFont.caption())
                .foregroundColor(.textPrimary)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.brandPrimary.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let user: UserModel
    let isSelected: Bool
    let currentUserUID: String
    let currentUserFriends: [String]
    let outgoingRequests: [FriendRequest]
    let incomingRequests: [FriendRequest]
    let onTap: () -> Void

    private var isSuspended: Bool {
        user.isSuspended
    }

    private var relationshipStatus: RelationshipStatus {
        // Check if suspended first
        if isSuspended {
            return .suspended
        }

        // Check if already friends
        if currentUserFriends.contains(user.uid) {
            return .friend
        }

        // Check if there's an outgoing pending request to this user
        if outgoingRequests.contains(where: { $0.toUID == user.uid }) {
            return .pendingOutgoing
        }

        // Check if there's an incoming pending request from this user
        if incomingRequests.contains(where: { $0.fromUID == user.uid }) {
            return .pendingIncoming
        }

        return .none
    }

    enum RelationshipStatus {
        case friend
        case pendingOutgoing    // We sent request to them
        case pendingIncoming    // They sent request to us
        case suspended          // User is suspended
        case none
    }

    private var isDisabled: Bool {
        relationshipStatus != .none
    }

    var body: some View {
        Button {
            // Only allow selection if no relationship exists and not suspended
            if relationshipStatus == .none {
                onTap()
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox or nosign for suspended
                if isSuspended {
                    Image(systemName: "nosign")
                        .font(.system(size: 20))
                        .foregroundColor(.errorRed.opacity(0.5))
                        .frame(width: 24, height: 24)
                } else {
                    ZStack {
                        Circle()
                            .stroke(
                                relationshipStatus == .none ?
                                    (isSelected ? Color.brandPrimary : Color.textSecondary.opacity(0.3)) :
                                    Color.textSecondary.opacity(0.2),
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)

                        if isSelected && relationshipStatus == .none {
                            Circle()
                                .fill(Color.brandPrimary)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }

                // Avatar
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(isSuspended ? Color.errorRed.opacity(0.15) : Color.brandPrimary.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Text(user.displayName.prefix(1).uppercased())
                            .font(AppFont.headline())
                            .foregroundColor(isSuspended ? .errorRed : .brandPrimary)
                            .fontWeight(.bold)
                    }
                    .opacity(isSuspended ? 0.5 : 1.0)

                    if isSuspended {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.errorRed)
                            .background(Circle().fill(Color.baseFallback).frame(width: 16, height: 16))
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName)
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(isSuspended ? .textPrimary.opacity(0.5) : .textPrimary)

                    Text(user.email)
                        .font(AppFont.caption2())
                        .foregroundColor(.textSecondary)

                    if isSuspended {
                        Text("Ditangguhkan")
                            .font(AppFont.caption2())
                            .foregroundColor(.errorRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.errorRed.opacity(0.15))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                }

                Spacer()

                // Status Badge
                if relationshipStatus == .friend {
                    Text("Sudah Teman")
                        .font(AppFont.caption2())
                        .foregroundColor(.successGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.successGreen.opacity(0.15))
                        .clipShape(Capsule())
                } else if relationshipStatus == .pendingOutgoing {
                    Text("Menunggu")
                        .font(AppFont.caption2())
                        .foregroundColor(.warningAmber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.warningAmber.opacity(0.15))
                        .clipShape(Capsule())
                } else if relationshipStatus == .pendingIncoming {
                    Text("Sudah Mengirim")
                        .font(AppFont.caption2())
                        .foregroundColor(.brandPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandPrimary.opacity(0.15))
                        .clipShape(Capsule())
                }
                // Note: suspended badge is shown inline with name, not here
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isSuspended ? Color.cardFallback.opacity(0.5) :
                (relationshipStatus == .none ?
                    (isSelected ? Color.brandPrimary.opacity(0.05) : Color.cardFallback) :
                    Color.cardFallback.opacity(0.5))
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(
                        isSuspended ? Color.errorRed.opacity(0.3) :
                        (isSelected && relationshipStatus == .none ?
                            Color.brandPrimary.opacity(0.3) :
                            Color.clear),
                        lineWidth: 1
                    )
            )
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled)
    }
}
