import SwiftUI

struct PhotoSourcePickerPage: View {
    let onSelectCamera: () -> Void
    let onSelectGallery: () -> Void

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandPrimary.opacity(0.15), Color.brandAccent.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.brandPrimary, Color.brandAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text("Pilih Sumber Foto")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)

                    Text("Ambil foto struk untuk di-scan otomatis")
                        .font(AppFont.subheadline())
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                // Options
                VStack(spacing: 16) {
                    // Camera option
                    Button {
                        onSelectCamera()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandPrimary.opacity(0.15))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.brandPrimary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kamera")
                                    .font(AppFont.headline())
                                    .foregroundColor(.textPrimary)

                                Text("Foto struk menggunakan kamera")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textSecondary.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)

                    // Gallery option
                    Button {
                        onSelectGallery()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandAccent.opacity(0.15))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.brandAccent)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Galeri")
                                    .font(AppFont.headline())
                                    .foregroundColor(.textPrimary)

                                Text("Pilih foto struk dari galeri")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textSecondary.opacity(0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .navigationTitle("Scan Struk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    NavigationStack {
        PhotoSourcePickerPage(
            onSelectCamera: {},
            onSelectGallery: {}
        )
    }
}
