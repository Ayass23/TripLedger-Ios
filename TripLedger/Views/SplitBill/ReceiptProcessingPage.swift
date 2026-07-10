import SwiftUI

struct ReceiptProcessingPage: View {
    let selectedImage: UIImage
    let onSuccess: (OCRResult) -> Void
    let onError: () -> Void

    // MARK: - Processing Steps
    private enum Step: Int, CaseIterable {
        case ocr
        case ai
        case finish

        var title: String {
            switch self {
            case .ocr:    return "Membaca teks struk"
            case .ai:     return "AI menganalisis item & harga"
            case .finish: return "Menyusun hasil"
            }
        }

        var icon: String {
            switch self {
            case .ocr:    return "doc.text.viewfinder"
            case .ai:     return "sparkles"
            case .finish: return "checklist"
            }
        }
    }

    @State private var isProcessing = true
    @State private var errorMessage: String?
    @State private var currentStep = 0          // steps below this index are done
    @State private var scanOffset: CGFloat = 0.05  // 0...1 vertical position of the scan beam
    @State private var glowPulse = false
    @State private var statusIndex = 0

    private let statusMessages = [
        "Menganalisis struk belanja Anda...",
        "Membaca nama item dan harga...",
        "Memeriksa pajak, diskon & pembulatan...",
        "Merapikan hasil scan...",
        "Sebentar lagi selesai..."
    ]

    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color.brandPrimary, Color.brandAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                if isProcessing {
                    loadingState
                } else if let error = errorMessage {
                    errorState(error)
                }

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            startProcessing()
        }
        .task {
            await cycleStatusMessages()
        }
    }

    // MARK: - Loading State
    private var loadingState: some View {
        VStack(spacing: 28) {
            receiptPreview

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(brandGradient)
                        .scaleEffect(glowPulse ? 1.2 : 0.85)

                    Text("AI Sedang Memproses")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                }

                // Crossfade only — no movement, so the text doesn't bounce
                Text(statusMessages[statusIndex])
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 20)  // fixed height: no layout shift between messages
                    .id(statusIndex)
                    .transition(.opacity)
            }

            stepsCard
        }
        .padding(.horizontal, 32)
    }

    /// Receipt thumbnail with a glowing scan beam sweeping over it
    private var receiptPreview: some View {
        Image(uiImage: selectedImage)
            .resizable()
            .scaledToFill()
            .frame(width: 200, height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(scanBeam)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(brandGradient, lineWidth: 2.5)
            )
            .shadow(
                color: Color.brandPrimary.opacity(glowPulse ? 0.4 : 0.15),
                radius: glowPulse ? 24 : 12
            )
    }

    private var scanBeam: some View {
        GeometryReader { geo in
            let beamY = geo.size.height * scanOffset

            ZStack {
                // Soft glow trailing the beam
                LinearGradient(
                    colors: [Color.brandAccent.opacity(0), Color.brandAccent.opacity(0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: 64)
                .position(x: geo.size.width / 2, y: beamY - 32)

                // The beam itself
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.brandAccent, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width, height: 3)
                    .position(x: geo.size.width / 2, y: beamY)
                    .shadow(color: Color.brandAccent.opacity(0.9), radius: 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .allowsHitTesting(false)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Step.allCases, id: \.rawValue) { step in
                stepRow(step)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardFallback)
        )
    }

    @ViewBuilder
    private func stepRow(_ step: Step) -> some View {
        let isDone = step.rawValue < currentStep
        let isActive = step.rawValue == currentStep && isProcessing

        HStack(spacing: 14) {
            ZStack {
                if isDone {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else if isActive {
                    Circle()
                        .fill(brandGradient)
                    Image(systemName: step.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .scaleEffect(glowPulse ? 1.12 : 0.95)
                } else {
                    Circle()
                        .fill(Color.textSecondary.opacity(0.12))
                    Image(systemName: step.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.textSecondary.opacity(0.6))
                }
            }
            .frame(width: 36, height: 36)

            Text(step.title)
                .font(AppFont.subheadline())
                .foregroundColor(isDone || isActive ? .textPrimary : Color.textSecondary.opacity(0.7))

            Spacer()

            if isActive {
                ProgressView()
                    .tint(Color.brandPrimary)
                    .scaleEffect(0.8)
            }
        }
    }

    // MARK: - Error State
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 24) {
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

    // MARK: - Status Message Cycling
    private func cycleStatusMessages() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard isProcessing else { continue }
            withAnimation(.easeInOut(duration: 0.35)) {
                statusIndex = (statusIndex + 1) % statusMessages.count
            }
        }
    }

    // MARK: - Processing
    private func startProcessing() {
        // Scan beam sweeps up & down; glow breathes
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            scanOffset = 0.95
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            glowPulse = true
        }

        Task {
            do {
                AppLog.debug("🔄 [ReceiptProcessingPage] Processing receipt image...")

                // Perform OCR and AI parsing; phases drive the step checklist
                let result = try await OCRService.shared.recognizeAndParseReceipt(in: selectedImage) { phase in
                    Task { @MainActor in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            switch phase {
                            case .ocr: currentStep = Step.ocr.rawValue
                            case .ai:  currentStep = Step.ai.rawValue
                            }
                        }
                    }
                }

                // Validate if it's a receipt
                guard let parsedReceipt = result.parsedReceipt else {
                    throw AppError.unknown("Tidak dapat mendeteksi struk. Pastikan foto jelas dan berisi informasi struk.")
                }

                // Additional validation: check if total amount exists and is reasonable
                guard parsedReceipt.totalAmount > 0 else {
                    throw AppError.unknown("Total tagihan tidak ditemukan. Pastikan foto struk menampilkan total pembayaran dengan jelas.")
                }

                AppLog.debug("✅ [ReceiptProcessingPage] Receipt validated successfully")

                // Briefly show the last step, then all steps completed,
                // so the checklist reads as finished before navigating away
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        currentStep = Step.finish.rawValue
                    }
                }
                try? await Task.sleep(nanoseconds: 450_000_000)

                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        currentStep = Step.allCases.count
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                try? await Task.sleep(nanoseconds: 500_000_000)

                // Success - callback with result
                await MainActor.run {
                    onSuccess(result)
                }

            } catch {
                AppLog.debug("❌ [ReceiptProcessingPage] Receipt processing failed: \(error.localizedDescription)")

                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
