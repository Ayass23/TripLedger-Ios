import SwiftUI
import Kingfisher

struct SettlementVerifySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @ObservedObject var settlementVM: SettlementViewModel
    @ObservedObject var expenseVM: ExpenseViewModel

    let settlement: Settlement

    @State private var showRejectDialog = false
    @State private var rejectionReason = ""
    @State private var showFullImage = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Sender Info
                        senderCard

                        // Proof Image
                        proofImageSection

                        // Payment Details
                        paymentDetailsSection

                        // Amount Card
                        amountCard

                        // Action Buttons
                        actionButtons
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Verifikasi Pembayaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.textPrimary.opacity(0.3))
                    }
                }
            }
            .alert("Tolak Pembayaran", isPresented: $showRejectDialog) {
                TextField("Alasan penolakan...", text: $rejectionReason)
                Button("Batal", role: .cancel) {
                    rejectionReason = ""
                }
                Button("Tolak", role: .destructive) {
                    Task {
                        await rejectSettlement()
                    }
                }
            } message: {
                Text("Berikan alasan mengapa pembayaran ini ditolak.")
            }
            .fullScreenCover(isPresented: $showFullImage) {
                fullImageView
            }
        }
    }

    // MARK: - Sender Card
    private var senderCard: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.warningAmber.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: "person.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.warningAmber)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Pembayaran dari")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.5))

                Text(settlement.fromName)
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            // Status Badge
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12))
                Text("Menunggu")
                    .font(AppFont.caption2())
                    .fontWeight(.semibold)
            }
            .foregroundColor(.warningAmber)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.warningAmber.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.warningAmber.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Proof Image Section
    private var proofImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bukti Transfer")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)

                Spacer()

                if settlement.proofImageURL != nil {
                    Button {
                        showFullImage = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12))
                            Text("Perbesar")
                                .font(AppFont.caption())
                        }
                        .foregroundColor(.brandPrimary)
                    }
                }
            }

            if let urlString = settlement.proofImageURL, let url = URL(string: urlString) {
                KFImage(url)
                    .placeholder {
                        ZStack {
                            Color.cardFallback
                            ProgressView()
                                .tint(.brandPrimary)
                        }
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .onTapGesture {
                        showFullImage = true
                    }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.textPrimary.opacity(0.2))
                        Text("Tidak ada bukti transfer")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }
                    Spacer()
                }
                .frame(height: 160)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            }
        }
    }

    // MARK: - Payment Details Section
    private var paymentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rincian Pembayaran")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            VStack(spacing: 8) {
                ForEach(settlement.expenseSplitRefs) { ref in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ref.title)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(ref.amount.toCurrency(symbol: settlement.currency))
                            .font(AppFont.subheadline())
                            .fontWeight(.medium)
                            .foregroundColor(.textPrimary.opacity(0.8))
                    }
                    .padding(12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
            }
        }
    }

    // MARK: - Amount Card
    private var amountCard: some View {
        VStack(spacing: 8) {
            Text("Total Pembayaran")
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.6))

            Text(settlement.totalAmount.toCurrency(symbol: settlement.currency))
                .font(AppFont.largeTitle())
                .fontWeight(.bold)
                .foregroundColor(.brandPrimary)

            Text("dari trip \"\(settlement.tripName)\"")
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.brandPrimary.opacity(0.08), Color.brandAccent.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Approve Button
            Button {
                Task {
                    await approveSettlement()
                }
            } label: {
                HStack(spacing: 8) {
                    if settlementVM.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Terima Pembayaran")
                            .fontWeight(.semibold)
                    }
                }
                .font(AppFont.headline())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(
                    colors: [Color.successGreen, Color.successGreen.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .shadow(color: Color.successGreen.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(settlementVM.isLoading)

            // Reject Button
            Button {
                showRejectDialog = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                    Text("Tolak Pembayaran")
                        .fontWeight(.semibold)
                }
                .font(AppFont.headline())
                .foregroundColor(.errorRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.errorRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(Color.errorRed.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(settlementVM.isLoading)
        }
    }

    // MARK: - Full Image View
    private var fullImageView: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let urlString = settlement.proofImageURL, let url = URL(string: urlString) {
                KFImage(url)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button {
                showFullImage = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.9), .black.opacity(0.5))
            }
            .padding(20)
        }
    }

    // MARK: - Functions
    private func approveSettlement() async {
        let success = await settlementVM.approveSettlement(settlement: settlement, expenseVM: expenseVM)
        if success {
            isPresented = false
        }
    }

    private func rejectSettlement() async {
        let reason = rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { return }

        let success = await settlementVM.rejectSettlement(settlement: settlement, reason: reason)
        if success {
            isPresented = false
        }
    }
}
