import SwiftUI

struct SettlementView: View {
    @Environment(\.dismiss)          var dismiss
    @EnvironmentObject private var authVM:    AuthViewModel
    @EnvironmentObject private var expenseVM: ExpenseViewModel
    @EnvironmentObject private var debtVM:    DebtViewModel

    let trip: TripModel

    @State private var showProofUpload = false
    @State private var selectedTx:     Transaction?
    @State private var proofImage:     UIImage?
    @State private var showPicker      = false
    @State private var notes           = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Summary card
                        summaryCard

                        // Transactions
                        sectionHeader("Yang Harus Dibayar")
                        if debtVM.transactions.isEmpty {
                            emptyLunas
                        } else {
                            ForEach(debtVM.transactions) { tx in
                                transactionCard(tx)
                            }
                        }

                        // Settlement history
                        if !debtVM.settlements.isEmpty {
                            sectionHeader("Riwayat Pembayaran")
                            ForEach(debtVM.settlements) { s in
                                settlementHistoryRow(s)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settlement")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundColor(.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        debtVM.computeDebts(expenses: expenseVM.expenses, members: trip.members, currency: trip.currency)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color.accentFallback)
                    }
                }
            }
        }
        .sheet(isPresented: $showProofUpload) {
            proofUploadSheet
        }
        .preferredColorScheme(.dark)
        .onAppear {
            debtVM.computeDebts(expenses: expenseVM.expenses, members: trip.members, currency: trip.currency)
        }
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Pengeluaran").font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.5))
                    Text(expenseVM.totalAmount.toCurrency(symbol: trip.currency))
                        .font(AppFont.title2()).foregroundColor(.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Transaksi Tersisa").font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.5))
                    Text("\(debtVM.transactions.count)")
                        .font(AppFont.title2())
                        .foregroundColor(debtVM.transactions.isEmpty ? .successGreen : .warningAmber)
                }
            }
        }
        .padding(18)
        .background(LinearGradient.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    // MARK: - Transaction Card
    private func transactionCard(_ tx: Transaction) -> some View {
        let isMyDebt = tx.fromUID == authVM.currentUser?.uid
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMyDebt ? "Kamu harus bayar" : "\(tx.fromName) harus bayar")
                        .font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.5))
                    Text(isMyDebt ? tx.toName : tx.toName)
                        .font(AppFont.headline()).foregroundColor(.textPrimary)
                }
                Spacer()
                Text(tx.amount.toCurrency(symbol: trip.currency))
                    .font(AppFont.title3())
                    .foregroundColor(isMyDebt ? .errorRed : .successGreen)
            }
            if isMyDebt {
                Button {
                    selectedTx = tx
                    showProofUpload = true
                } label: {
                    Label("Upload Bukti Bayar", systemImage: "arrow.up.doc.fill")
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(LinearGradient.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                }
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    // MARK: - Settlement History Row
    private func settlementHistoryRow(_ s: SettlementModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon(s.status))
                .foregroundColor(statusColor(s.status))
                .font(.system(size: 20))
                .frame(width: 36, height: 36)
                .background(statusColor(s.status).opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.fromName) → \(s.toName)")
                    .font(AppFont.subheadline()).foregroundColor(.textPrimary).lineLimit(1)
                Text(s.status.rawValue.capitalized)
                    .font(AppFont.caption()).foregroundColor(statusColor(s.status))
            }
            Spacer()
            Text(s.amount.toCurrency(symbol: trip.currency))
                .font(AppFont.subheadline()).foregroundColor(.textPrimary)

            // Verify/reject buttons for trip admin/owner
            if s.status == .pending && (trip.adminUIDs.contains(authVM.currentUser?.uid ?? "") || trip.ownerUID == authVM.currentUser?.uid) {
                HStack(spacing: 6) {
                    Button {
                        Task { await debtVM.verifyPayment(settlementID: s.id ?? "", verifierUID: authVM.currentUser?.uid ?? "") }
                    } label: {
                        Image(systemName: "checkmark").foregroundColor(.successGreen).font(.system(size: 13, weight: .bold))
                            .frame(width: 28, height: 28).background(Color.successGreen.opacity(0.15)).clipShape(Circle())
                    }
                    Button {
                        Task { await debtVM.rejectPayment(settlementID: s.id ?? "", verifierUID: authVM.currentUser?.uid ?? "") }
                    } label: {
                        Image(systemName: "xmark").foregroundColor(.errorRed).font(.system(size: 13, weight: .bold))
                            .frame(width: 28, height: 28).background(Color.errorRed.opacity(0.15)).clipShape(Circle())
                    }
                }
            }
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Proof Upload Sheet
    private var proofUploadSheet: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()
                VStack(spacing: 20) {
                    if let img = proofImage {
                        Image(uiImage: img).resizable().scaledToFit()
                            .frame(maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button { showPicker = true } label: {
                        Label("Pilih Foto Bukti", systemImage: "photo.fill")
                            .font(AppFont.subheadline()).foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.textPrimary.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    TLTextField(icon: "note.text", placeholder: "Catatan (opsional)", text: $notes)

                    Spacer()

                    Button {
                        Task {
                            guard let tx = selectedTx, let img = proofImage, let uid = authVM.currentUser?.uid else { return }
                            await debtVM.submitPayment(
                                tripID: trip.id ?? "", fromUID: tx.fromUID, fromName: tx.fromName,
                                toUID: tx.toUID, toName: tx.toName, amount: tx.amount,
                                currency: trip.currency, notes: notes.isBlank ? nil : notes, proof: img
                            )
                            showProofUpload = false
                        }
                    } label: {
                        Text(debtVM.isLoading ? "Mengirim..." : "Kirim Bukti")
                            .font(AppFont.headline()).foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(proofImage == nil ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(LinearGradient.brandGradient))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                    .disabled(proofImage == nil || debtVM.isLoading)
                }
                .padding(20)
                .dismissKeyboardOnTap()
            }
            .navigationTitle("Upload Bukti Bayar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showProofUpload = false }.foregroundColor(.textPrimary.opacity(0.7))
                }
            }
        }
        .sheet(isPresented: $showPicker) { ImagePicker(selectedImage: $proofImage) }
        .preferredColorScheme(.dark)
    }

    private var emptyLunas: some View {
        VStack(spacing: 12) {
            Text("🎉").font(.system(size: 48))
            Text("Semua Lunas!").font(AppFont.headline()).foregroundColor(.successGreen)
            Text("Tidak ada hutang yang tersisa.").font(AppFont.footnote()).foregroundColor(.textPrimary.opacity(0.4))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(AppFont.subheadline()).foregroundColor(.textPrimary.opacity(0.5))
    }

    private func statusIcon(_ s: SettlementStatus) -> String {
        switch s {
        case .pending: return "clock.fill"
        case .verified, .approved: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        }
    }
    private func statusColor(_ s: SettlementStatus) -> Color {
        switch s {
        case .pending: return .warningAmber
        case .verified, .approved: return .successGreen
        case .rejected: return .errorRed
        }
    }
}
