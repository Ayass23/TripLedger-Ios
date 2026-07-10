import SwiftUI
import Kingfisher

// MARK: - Friend Select Row
struct FriendSelectRow: View {
    let friend: UserModel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.brandPrimary : Color.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Text(friend.displayName.prefix(1).uppercased())
                        .font(AppFont.subheadline())
                        .foregroundColor(.brandPrimary)
                        .fontWeight(.bold)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(friend.displayName)
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    Text(friend.email)
                        .font(AppFont.caption2())
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? Color.brandPrimary.opacity(0.05) : Color.cardFallback)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? Color.brandPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
