import SwiftUI

// MARK: - Image Source Sheet
struct ImageSourceSheet: View {
    let onCameraSelected: () -> Void
    let onGallerySelected: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color.textPrimary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            // Title
            Text("Pilih Sumber Gambar")
                .font(AppFont.title3())
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
                .padding(.top, 20)
                .padding(.bottom, 24)

            // Options - Horizontal layout with equal spacing
            HStack(spacing: 16) {
                // Camera Option
                Button(action: onCameraSelected) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.brandPrimary.opacity(0.12))
                                .frame(width: 70, height: 70)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.brandPrimary)
                        }

                        Text("Kamera")
                            .font(AppFont.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())

                // Gallery Option
                Button(action: onGallerySelected) {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.successGreen.opacity(0.12))
                                .frame(width: 70, height: 70)

                            Image(systemName: "photo.fill.on.rectangle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.successGreen)
                        }

                        Text("Galeri")
                            .font(AppFont.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(Color.successGreen.opacity(0.2), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.baseFallback)
    }
}

// MARK: - Scale Button Style for better touch feedback
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
