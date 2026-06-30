import SwiftUI

// MARK: - Model for storing custom split per participant
struct ParticipantSplitDetail: Identifiable, Hashable {
    let id: String
    let name: String
    var portion: Int  // Number of portions (for portion mode)
    var customAmount: Double  // Custom amount (for price mode)
}

// MARK: - Atur Pembagian View
struct AturPembagianView: View {
    @Environment(\.dismiss) var dismiss

    let itemName: String
    let itemPrice: Double  // Total price (price * quantity)
    let itemQuantity: Int
    let currency: String
    let participants: [(id: String, name: String)]

    // Callback to return the split details
    let onSave: ([String: ParticipantSplitDetail]) -> Void

    // Split mode
    enum SplitMode: String, CaseIterable {
        case portion = "Porsi"
        case price = "Harga"
    }

    @State private var splitMode: SplitMode = .portion
    @State private var splitDetails: [ParticipantSplitDetail] = []

    // Alert states
    @State private var showZeroPortionAlert = false
    @State private var zeroPortionParticipants: [String] = []

    // Computed properties
    private var totalPortions: Int {
        splitDetails.reduce(0) { $0 + $1.portion }
    }

    private var pricePerPortion: Double {
        guard totalPortions > 0 else { return 0 }
        return itemPrice / Double(totalPortions)
    }

    private var totalCustomAmount: Double {
        splitDetails.reduce(0) { $0 + $1.customAmount }
    }

    private var isAmountMatching: Bool {
        abs(totalCustomAmount - itemPrice) < 1  // Allow Rp 1 tolerance
    }

    private var canSave: Bool {
        if splitMode == .portion {
            return totalPortions > 0
        } else {
            return isAmountMatching
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Item Info Header
                        itemInfoHeader

                        // Bagi Rata Button
                        bagiRataButton

                        // Split Mode Selector
                        splitModeSelector

                        // Helper Text
                        helperText

                        // Participants List
                        participantsList

                        // Total Summary (for price mode)
                        if splitMode == .price {
                            totalSummary
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .dismissKeyboardOnTap()

                // Bottom Save Button
                VStack {
                    Spacer()
                    saveButton
                }
            }
            .navigationTitle("Atur Pembagian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
        }
        .onAppear {
            initializeSplitDetails()
        }
        .alert("Peserta Tidak Ikut Pembagian", isPresented: $showZeroPortionAlert) {
            Button("Benahi Dulu", role: .cancel) { }
            Button("Lanjutkan") {
                saveAndDismiss()
            }
        } message: {
            let names = zeroPortionParticipants.joined(separator: ", ")
            Text("\(names) akan tidak diikutkan dalam pembagian karena porsinya 0. Lanjutkan?")
        }
    }

    // MARK: - Item Info Header
    private var itemInfoHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(itemQuantity > 1 ? "\(itemQuantity)x \(itemName)" : itemName)
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            Text(itemPrice.toCurrency(symbol: currency))
                .font(AppFont.title2())
                .foregroundColor(.brandPrimary)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Bagi Rata Button
    private var bagiRataButton: some View {
        Button {
            distributeEvenly()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "equal.circle.fill")
                    .font(.system(size: 18))
                Text("Bagi Rata")
                    .font(AppFont.subheadline())
                    .fontWeight(.semibold)
            }
            .foregroundColor(.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.brandPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Split Mode Selector
    private var splitModeSelector: some View {
        HStack(spacing: 8) {
            ForEach(SplitMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        splitMode = mode
                        // Recalculate when switching modes
                        if mode == .price {
                            recalculateCustomAmounts()
                        }
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(splitMode == mode ? .white : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(splitMode == mode ? Color.brandPrimary : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.cardFallback)
        .clipShape(Capsule())
    }

    // MARK: - Helper Text
    private var helperText: some View {
        Text(splitMode == .portion ?
             "Tentukan jumlah porsi untuk masing-masing orang. Harga akan dihitung otomatis berdasarkan porsi." :
             "Masukkan nominal pembagian untuk masing-masing orang. Total harus sama dengan harga item.")
            .font(AppFont.caption())
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 4)
    }

    // MARK: - Participants List
    private var participantsList: some View {
        VStack(spacing: 12) {
            ForEach($splitDetails) { $detail in
                participantRow(detail: $detail)
            }
        }
    }

    // MARK: - Participant Row
    private func participantRow(detail: Binding<ParticipantSplitDetail>) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(String(detail.wrappedValue.name.prefix(1)).uppercased())
                    .font(AppFont.subheadline())
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.bold)
            }

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.wrappedValue.name)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)

                // Amount display
                if splitMode == .portion {
                    let amount = Double(detail.wrappedValue.portion) * pricePerPortion
                    Text(amount.toCurrency(symbol: currency))
                        .font(AppFont.caption())
                        .foregroundColor(detail.wrappedValue.portion > 0 ? .brandPrimary : .textSecondary)
                }
            }

            Spacer()

            // Controls
            if splitMode == .portion {
                portionStepper(detail: detail)
            } else {
                priceTextField(detail: detail)
            }
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(
                    splitMode == .portion && detail.wrappedValue.portion == 0 ?
                    Color.warningAmber.opacity(0.5) : Color.borderSoft,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Portion Stepper
    private func portionStepper(detail: Binding<ParticipantSplitDetail>) -> some View {
        HStack(spacing: 0) {
            Button {
                if detail.wrappedValue.portion > 0 {
                    detail.wrappedValue.portion -= 1
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(detail.wrappedValue.portion > 0 ? .brandPrimary : .textSecondary.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .background(Color.brandPrimary.opacity(detail.wrappedValue.portion > 0 ? 0.1 : 0.05))
                    .clipShape(Circle())
            }
            .disabled(detail.wrappedValue.portion == 0)

            Text("\(detail.wrappedValue.portion)")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)
                .frame(width: 40)

            Button {
                detail.wrappedValue.portion += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brandPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.brandPrimary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Price TextField
    private func priceTextField(detail: Binding<ParticipantSplitDetail>) -> some View {
        HStack(spacing: 4) {
            Text(currency)
                .font(AppFont.caption())
                .foregroundColor(.textSecondary)
                .fixedSize()

            TextField("0", value: detail.customAmount, format: .number)
                .keyboardType(.numberPad)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Total Summary (Price Mode)
    private var totalSummary: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Total Input")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(totalCustomAmount.toCurrency(symbol: currency))
                    .font(AppFont.headline())
                    .foregroundColor(isAmountMatching ? .successGreen : .errorRed)
            }

            HStack {
                Text("Harga Item")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(itemPrice.toCurrency(symbol: currency))
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
            }

            if !isAmountMatching {
                let difference = itemPrice - totalCustomAmount
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(difference > 0 ?
                         "Kurang \(difference.toCurrency(symbol: currency))" :
                         "Lebih \(abs(difference).toCurrency(symbol: currency))")
                        .font(AppFont.caption())
                }
                .foregroundColor(.errorRed)
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Save Button
    private var saveButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                handleSave()
            } label: {
                Text("Simpan Pembagian")
                    .font(AppFont.headline())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canSave ? LinearGradient.brandGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
            }
            .disabled(!canSave)
            .padding(20)
            .background(Color.baseFallback)
        }
    }

    // MARK: - Helper Functions
    private func initializeSplitDetails() {
        // Initialize with 1 portion each
        splitDetails = participants.map { participant in
            ParticipantSplitDetail(
                id: participant.id,
                name: participant.name,
                portion: 1,
                customAmount: itemPrice / Double(participants.count)
            )
        }
    }

    private func distributeEvenly() {
        if splitMode == .portion {
            // Set all portions to 1
            for i in splitDetails.indices {
                splitDetails[i].portion = 1
            }
        } else {
            // Distribute amount evenly
            let evenAmount = itemPrice / Double(splitDetails.count)
            for i in splitDetails.indices {
                splitDetails[i].customAmount = evenAmount
            }
        }
    }

    private func recalculateCustomAmounts() {
        // When switching to price mode, calculate based on current portions
        guard totalPortions > 0 else { return }
        for i in splitDetails.indices {
            splitDetails[i].customAmount = Double(splitDetails[i].portion) * pricePerPortion
        }
    }

    private func handleSave() {
        if splitMode == .portion {
            // Check for zero portions
            let zeroParticipants = splitDetails.filter { $0.portion == 0 }.map { $0.name }
            if !zeroParticipants.isEmpty {
                zeroPortionParticipants = zeroParticipants
                showZeroPortionAlert = true
                return
            }
        }

        saveAndDismiss()
    }

    private func saveAndDismiss() {
        // Convert to dictionary and pass back
        var result: [String: ParticipantSplitDetail] = [:]

        for detail in splitDetails {
            var updatedDetail = detail
            if splitMode == .portion {
                // Calculate final amount based on portion
                updatedDetail.customAmount = Double(detail.portion) * pricePerPortion
            }
            result[detail.id] = updatedDetail
        }

        onSave(result)
        dismiss()
    }
}

#Preview {
    AturPembagianView(
        itemName: "Bakso",
        itemPrice: 24000,
        itemQuantity: 4,
        currency: "Rp",
        participants: [
            (id: "1", name: "Andi"),
            (id: "2", name: "Budi"),
            (id: "3", name: "Citra")
        ],
        onSave: { splits in
            print("Splits: \(splits)")
        }
    )
}
