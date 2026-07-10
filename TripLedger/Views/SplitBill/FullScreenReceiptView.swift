import SwiftUI
import Kingfisher

// MARK: - Full Screen Receipt View
struct FullScreenReceiptView: View {
    let imageURL: URL
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    .padding()
                }

                // Image with Zoom
                KFImage(imageURL)
                    .placeholder {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                    .onFailure { _ in }
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                // Limit scale
                                if scale < 1.0 {
                                    withAnimation {
                                        scale = 1.0
                                        lastScale = 1.0
                                    }
                                } else if scale > 5.0 {
                                    withAnimation {
                                        scale = 5.0
                                        lastScale = 5.0
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        // Double tap to reset zoom
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                        }
                    }

                // Hint Text
                if scale == 1.0 {
                    Text("Pinch untuk zoom • Ketuk 2x untuk reset")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 16)
                }

                Spacer()
            }
        }
        .statusBar(hidden: true)
    }
}
