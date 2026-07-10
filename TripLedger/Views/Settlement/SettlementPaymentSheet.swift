import SwiftUI

struct SettlementPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool
    @ObservedObject var settlementVM: SettlementViewModel

    let balance: UserBalance
    let currency: String
    let tripID: String
    let tripName: String
    let currentUser: (uid: String, name: String)

    @State private var selectedDebts: Set<String> = []
    @State private var proofImage: UIImage?
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showImageSourceSheet = false
    @State private var bankAccount: String?
    @State private var isLoadingBank = true

    private var selectedAmount: Double {
        balance.owedDetails
            .filter { selectedDebts.contains($0.id) }
            .reduce(0) { $0 + $1.amount }
    }

    private var canSubmit: Bool {
        !selectedDebts.isEmpty && proofImage != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Receiver Info
                        receiverCard

                        // Bank Account Info
                        if isLoadingBank {
                            bankAccountLoadingCard
                        } else if let bank = bankAccount {
                            bankAccountCard(bank)
                        } else {
                            noBankAccountCard
                        }

                        // Debt Selection
                        debtSelectionSection

                        // Payment Summary
                        paymentSummaryCard

                        // Proof Upload
                        proofUploadSection

                        // Submit Button
                        submitButton
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Konfirmasi Pembayaran")
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
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $proofImage, sourceType: imageSourceType)
            }
            .sheet(isPresented: $showImageSourceSheet) {
                ImageSourceSheet(
                    onCameraSelected: {
                        showImageSourceSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            imageSourceType = .camera
                            showImagePicker = true
                        }
                    },
                    onGallerySelected: {
                        showImageSourceSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            imageSourceType = .photoLibrary
                            showImagePicker = true
                        }
                    },
                    onDismiss: {
                        showImageSourceSheet = false
                    }
                )
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(24)
            }
            .task {
                await loadBankAccount()
            }
        }
    }

    // MARK: - Receiver Card
    private var receiverCard: some View {
        HStack(spacing: 14) {
            AvatarView(
                url: balance.avatarURL,
                initials: String(balance.userName.prefix(2)).uppercased(),
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Bayar ke")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.5))

                Text(balance.userName)
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Total Hutang")
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.5))

                Text(balance.totalOwed.toCurrency(symbol: currency))
                    .font(AppFont.subheadline())
                    .fontWeight(.bold)
                    .foregroundColor(.errorRed)
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Bank Account Cards
    private var bankAccountLoadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.brandPrimary)

            Text("Memuat info rekening...")
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.6))

            Spacer()
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    private func bankAccountCard(_ bankInfo: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.brandPrimary)

                Text("Rekening Tujuan")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.6))

                Spacer()

                Button {
                    UIPasteboard.general.string = bankInfo
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                        Text("Salin")
                            .font(AppFont.caption2())
                    }
                    .foregroundColor(.brandPrimary)
                }
            }

            Text(bankInfo)
                .font(AppFont.subheadline())
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(Color.brandPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1)
        )
    }

    private var noBankAccountCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.warningAmber)

            Text("Pengguna ini belum mengatur info rekening bank")
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.7))

            Spacer()
        }
        .padding(14)
        .background(Color.warningAmber.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Debt Selection Section
    private var debtSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pilih Hutang yang Dibayar")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    if selectedDebts.count == balance.owedDetails.count {
                        selectedDebts.removeAll()
                    } else {
                        selectedDebts = Set(balance.owedDetails.map { $0.id })
                    }
                } label: {
                    Text(selectedDebts.count == balance.owedDetails.count ? "Hapus Semua" : "Pilih Semua")
                        .font(AppFont.caption())
                        .foregroundColor(.brandPrimary)
                }
            }

            VStack(spacing: 8) {
                ForEach(balance.owedDetails) { debt in
                    debtRow(debt)
                }
            }
        }
    }

    private func debtRow(_ debt: ExpenseDebtDetail) -> some View {
        let isSelected = selectedDebts.contains(debt.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedDebts.remove(debt.id)
                } else {
                    selectedDebts.insert(debt.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .brandPrimary : .textPrimary.opacity(0.25))

                // Expense Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(debt.title)
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(debt.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.4))
                }

                Spacer()

                // Amount
                Text(debt.amount.toCurrency(symbol: currency))
                    .font(AppFont.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .brandPrimary : .textPrimary.opacity(0.6))
            }
            .padding(14)
            .background(isSelected ? Color.brandPrimary.opacity(0.06) : Color.cardFallback)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? Color.brandPrimary.opacity(0.3) : Color.borderSoft, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Payment Summary Card
    private var paymentSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Jumlah yang Dibayar")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.7))

                Spacer()

                Text("\(selectedDebts.count) item dipilih")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.5))
            }

            Text(selectedAmount.toCurrency(symbol: currency))
                .font(AppFont.largeTitle())
                .fontWeight(.bold)
                .foregroundColor(.brandPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
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

    // MARK: - Proof Upload Section
    private var proofUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Bukti Transfer")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)

                Text("*")
                    .foregroundColor(.errorRed)

                Spacer()
            }

            if let image = proofImage {
                // Show uploaded image
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

                    // Remove button
                    Button {
                        withAnimation {
                            proofImage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white, Color.errorRed)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            } else {
                // Upload button
                Button {
                    showImageSourceSheet = true
                } label: {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.brandPrimary.opacity(0.1))
                                .frame(width: 56, height: 56)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.brandPrimary)
                        }

                        Text("Upload Bukti Transfer")
                            .font(AppFont.subheadline())
                            .fontWeight(.medium)
                            .foregroundColor(.brandPrimary)

                        Text("Ketuk untuk menambahkan foto")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(Color.brandPrimary.opacity(0.3))
                    )
                    .background(Color.brandPrimary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            Task {
                await submitSettlement()
            }
        } label: {
            HStack(spacing: 8) {
                if settlementVM.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                    Text("Kirim Konfirmasi")
                        .fontWeight(.semibold)
                }
            }
            .font(AppFont.headline())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canSubmit
                    ? LinearGradient.brandGradient
                    : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .shadow(color: canSubmit ? Color.brandPrimary.opacity(0.3) : .clear, radius: 8, y: 4)
        }
        .disabled(!canSubmit || settlementVM.isLoading)
    }

    // MARK: - Functions
    private func loadBankAccount() async {
        isLoadingBank = true
        bankAccount = await settlementVM.fetchUserBankAccount(userUID: balance.userUID)
        isLoadingBank = false
    }

    private func submitSettlement() async {
        // Build expense split refs
        let expenseSplitRefs = balance.owedDetails
            .filter { selectedDebts.contains($0.id) }
            .map { ExpenseSplitRef(
                expenseID: $0.expenseID,
                splitID: $0.splitID,
                amount: $0.amount,
                title: $0.title
            )}

        let success = await settlementVM.createSettlement(
            tripID: tripID,
            tripName: tripName,
            fromUser: currentUser,
            toUser: (balance.userUID, balance.userName, bankAccount),
            amount: selectedAmount,
            currency: currency,
            proofImage: proofImage,
            expenseSplitRefs: expenseSplitRefs
        )

        if success {
            isPresented = false
        }
    }
}

