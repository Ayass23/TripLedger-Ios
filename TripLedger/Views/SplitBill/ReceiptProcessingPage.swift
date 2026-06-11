import SwiftUI

struct ReceiptProcessingPage: View {
    let selectedImage: UIImage
    let onSuccess: (OCRResult) -> Void
    let onError: () -> Void

    @State private var isProcessing = true
    @State private var errorMessage: String?
    @State private var processingProgress: CGFloat = 0.0

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                if isProcessing {
                    // Loading State
                    VStack(spacing: 24) {
                        // Animated Circle with Image
                        ZStack {
                            // Outer rotating circle
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.brandPrimary, Color.brandAccent, Color.brandPrimary.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(processingProgress * 360))

                            // Inner circle background
                            Circle()
                                .fill(Color.cardFallback)
                                .frame(width: 100, height: 100)

                            // AI Icon
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.brandPrimary, Color.brandAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        VStack(spacing: 12) {
                            Text("AI Sedang Memproses")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)

                            Text("Menganalisis struk belanja Anda...")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // Progress dots
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.brandPrimary)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(dotScale(for: index))
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.2),
                                        value: processingProgress
                                    )
                            }
                        }
                        .padding(.top, 8)
                    }
                } else if let error = errorMessage {
                    // Error State
                    VStack(spacing: 24) {
                        // Error Icon
                        ZStack {
                            Circle()
                                .fill(Color.errorRed.opacity(0.15))
                                .frame(width: 120, height: 120)

                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50, weight: .semibold))
                                .foregroundColor(.errorRed)
                        }

                        VStack(spacing: 12) {
                            Text("Gagal Memproses Struk")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)

                            Text(error)
                                .font(AppFont.body())
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        // Retry Button
                        Button {
                            onError()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Coba Lagi")
                            }
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.brandPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }
                }

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            startProcessing()
        }
    }

    private func dotScale(for index: Int) -> CGFloat {
        let phase = processingProgress * 3
        let distance = abs(phase - CGFloat(index))
        return distance < 0.5 ? 1.4 : 1.0
    }

    private func startProcessing() {
        // Start animation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            processingProgress = 1.0
        }

        // Process receipt
        Task {
            do {
                print("🔄 [ReceiptProcessingPage] Processing receipt image...")

                // Perform OCR and AI parsing
                let result = try await OCRService.shared.recognizeAndParseReceipt(in: selectedImage)

                // Validate if it's a receipt
                guard let parsedReceipt = result.parsedReceipt else {
                    throw AppError.unknown("Tidak dapat mendeteksi struk. Pastikan foto jelas dan berisi informasi struk.")
                }

                // Additional validation: check if total amount exists and is reasonable
                guard parsedReceipt.totalAmount > 0 else {
                    throw AppError.unknown("Total tagihan tidak ditemukan. Pastikan foto struk menampilkan total pembayaran dengan jelas.")
                }

                print("✅ [ReceiptProcessingPage] Receipt validated successfully")

                // Success - callback with result
                await MainActor.run {
                    onSuccess(result)
                }

            } catch {
                print("❌ [ReceiptProcessingPage] Receipt processing failed: \(error.localizedDescription)")

                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
