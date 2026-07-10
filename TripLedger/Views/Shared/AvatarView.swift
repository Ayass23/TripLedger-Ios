import SwiftUI
import Kingfisher

// MARK: - Avatar View (reusable) - Using Kingfisher for disk caching
struct AvatarView: View {
    let url:      String?
    let initials: String
    let size:     CGFloat

    var body: some View {
        Group {
            if let url, let imgURL = URL(string: url) {
                KFImage(imgURL)
                    .placeholder {
                        initialsView
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            )
                    }
                    .onFailure { _ in }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        ZStack {
            LinearGradient.brandGradient
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
