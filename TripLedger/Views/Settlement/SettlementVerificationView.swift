import SwiftUI
import Kingfisher
import FirebaseFirestore

struct SettlementVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject var settlementVM: SettlementViewModel
    @StateObject private var expenseVM = ExpenseViewModel()

    let settlement: Settlement

    @State private var showApproveAlert = false
    @State private var showRejectSheet = false
    @State private var rejectReason = ""
    @State private var showSuccessAlert = false
    @State private var successMessage = ""

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    statusBadge

                    // Show rejection reason if rejected
                    if settlement.status == .rejected, let reason = settlement.rejectionReason {
                        rejectionReasonCard(reason)
                    }

                    senderCard
                    proofImageSection
                    paymentDetailsCard
                    expenseListSection

                    if settlement.status == .pending {
                        actionButtons
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Verifikasi Pembayaran")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Terima Pembayaran?", isPresented: $showApproveAlert) {
            Button("Batal", role: .cancel) {}
            Button("Terima") {
                Task { await approveSettlement() }
            }
        } message: {
            Text("Dengan menerima pembayaran ini, hutang akan ditandai sebagai lunas.")
        }
        .sheet(isPresented: $showRejectSheet) {
            rejectReasonSheet
        }
        .alert("Berhasil!", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(successMessage)
        }
        .onAppear {
            expenseVM.listenExpenses(tripID: settlement.tripID)
        }
    }

    // MARK: - Rejection Reason Card
    private func rejectionReasonCard(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.errorRed)
                Text("Alasan Penolakan")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
                Spacer()
            }

            Text(reason)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.errorRed.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.errorRed.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Status Badge
    private var statusBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: settlement.status.icon)
                .font(.system(size: 14))
            Text(settlement.status.displayName)
                .font(AppFont.subheadline())
                .fontWeight(.semibold)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch settlement.status {
        case .pending: return .warningAmber
        case .verified, .approved: return .successGreen
        case .rejected: return .errorRed
        }
    }

    // MARK: - Sender Card
    private var senderCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient.brandGradient)
                    .frame(width: 50, height: 50)
                Text(String(settlement.fromName.prefix(2)).uppercased())
                    .font(AppFont.headline())
                    .foregroundColor(.white)
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

            VStack(alignment: .trailing, spacing: 2) {
                Text(settlement.createdAt.dateValue().formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.4))
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderSoft, lineWidth: 1))
    }

    // MARK: - Proof Image Section
    private var proofImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.brandPrimary)
                Text("Bukti Transfer")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
                Spacer()
            }

            if let urlString = settlement.proofImageURL, let url = URL(string: urlString) {
                KFImage(url)
                    .placeholder {
                        ZStack {
                            Color.textPrimary.opacity(0.05)
                            ProgressView()
                        }
                    }
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderSoft, lineWidth: 1))
            } else {
                HStack {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 24))
                    Text("Bukti transfer tidak tersedia")
                        .font(AppFont.subheadline())
                }
                .foregroundColor(.textPrimary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.textPrimary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderSoft, lineWidth: 1))
    }

    // MARK: - Payment Details Card
    private var paymentDetailsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Total Pembayaran")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.7))
                Spacer()
            }

            Text(settlement.totalAmount.toCurrency(symbol: settlement.currency))
                .font(AppFont.largeTitle())
                .fontWeight(.bold)
                .foregroundColor(.brandPrimary)

            if let bankAccount = settlement.toBankAccount {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rekening Tujuan")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.5))
                        Text(bankAccount)
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                    }
                    Spacer()
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.5))
                    Text(settlement.tripName)
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.brandPrimary.opacity(0.08), Color.brandAccent.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Expense List Section
    private var expenseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 14))
                    .foregroundColor(.brandAccent)
                Text("Pengeluaran yang Dibayar")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("\(settlement.expenseSplitRefs.count) item")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.5))
            }

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
                            .foregroundColor(.brandPrimary)
                    }
                    .padding(12)
                    .background(Color.baseFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderSoft, lineWidth: 1))
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Reject Button
            Button {
                showRejectSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                    Text("Tolak")
                        .fontWeight(.semibold)
                }
                .font(AppFont.headline())
                .foregroundColor(.errorRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.errorRed.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.errorRed.opacity(0.3), lineWidth: 1))
            }

            // Approve Button
            Button {
                showApproveAlert = true
            } label: {
                HStack(spacing: 8) {
                    if settlementVM.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                        Text("Terima")
                            .fontWeight(.semibold)
                    }
                }
                .font(AppFont.headline())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .shadow(color: Color.brandPrimary.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(settlementVM.isLoading)
        }
    }

    // MARK: - Reject Reason Sheet
    private var rejectReasonSheet: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Alasan Penolakan")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)

                        TextEditor(text: $rejectReason)
                            .font(AppFont.body())
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color.cardFallback)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderSoft, lineWidth: 1))

                        Text("Jelaskan mengapa kamu menolak pembayaran ini")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }

                    Button {
                        Task { await rejectSettlement() }
                    } label: {
                        HStack(spacing: 8) {
                            if settlementVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Tolak Pembayaran")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(AppFont.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(rejectReason.isBlank ? Color.gray.opacity(0.4) : Color.errorRed)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    }
                    .disabled(rejectReason.isBlank || settlementVM.isLoading)

                    Spacer()
                }
                .padding(20)
                .dismissKeyboardOnTap()
            }
            .navigationTitle("Tolak Pembayaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        showRejectSheet = false
                    }
                    .foregroundColor(.textPrimary.opacity(0.7))
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions
    private func approveSettlement() async {
        let success = await settlementVM.approveSettlement(settlement: settlement, expenseVM: expenseVM)
        if success {
            successMessage = "Pembayaran telah diterima. Hutang sudah ditandai sebagai lunas."
            showSuccessAlert = true
        }
    }

    private func rejectSettlement() async {
        let success = await settlementVM.rejectSettlement(settlement: settlement, reason: rejectReason)
        if success {
            showRejectSheet = false
            successMessage = "Pembayaran telah ditolak. Pengirim akan menerima notifikasi."
            showSuccessAlert = true
        }
    }
}
