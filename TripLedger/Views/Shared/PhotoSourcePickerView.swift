import SwiftUI

struct PhotoSourcePickerView: View {
    @Environment(\.dismiss) var dismiss
    let onSelectCamera: () -> Void
    let onSelectGallery: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.textSecondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandPrimary.opacity(0.15), Color.brandAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.brandPrimary, Color.brandAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Pilih Sumber Foto")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)

                Text("Ambil foto baru atau pilih dari galeri")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // Options
            VStack(spacing: 12) {
                // Camera Option
                Button {
                    dismiss()
                    // Delay untuk smooth transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSelectCamera()
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.brandPrimary.opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.brandPrimary)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Buka Kamera")
                                .font(AppFont.headline())
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)

                            Text("Ambil foto langsung dari kamera")
                                .font(AppFont.caption())
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary.opacity(0.5))
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.brandPrimary.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Gallery Option
                Button {
                    dismiss()
                    // Delay untuk smooth transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSelectGallery()
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#10B981").opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#10B981"))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pilih dari Galeri")
                                .font(AppFont.headline())
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)

                            Text("Pilih foto dari album kamu")
                                .font(AppFont.caption())
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary.opacity(0.5))
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color(hex: "#10B981").opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            Spacer()
        }
        .background(Color.baseFallback.ignoresSafeArea())
        .presentationDetents([.height(380)])
    }
}

#Preview {
    PhotoSourcePickerView(
        onSelectCamera: {},
        onSelectGallery: {}
    )
}
