import SwiftUI
import UIKit
import FirebaseCore
import FirebaseFirestore

struct AddExpenseView: View {
    @Environment(\.dismiss)          var dismiss
    @EnvironmentObject private var authVM:    AuthViewModel
    @EnvironmentObject private var expenseVM: ExpenseViewModel
    
    let trip: TripModel
    var source: AddExpenseSource = .manual
    var scannedResult: OCRResult? = nil
    @Binding var isAddingExpense: Bool
    
    // UI State
    @State private var step = 1
    @State private var showBankAccountAlert = false
    @State private var showEditBankView = false
    @State private var showPostTripAlert = false
    @State private var showSuccessAlert = false
    @StateObject private var profileVM = ProfileViewModel()

    // Step 1: Info
    @State private var title      = ""
    @State private var amountStr  = ""
    @State private var category   = ExpenseCategory.food
    @State private var notes      = ""
    @State private var transactionDate = Date()
    @State private var showDatePicker = false
    @State private var showPhotoSourcePicker = false
    @State private var showCameraPicker = false
    @State private var showGalleryPicker = false
    @State private var selectedImage: UIImage? = nil
    
    private var amount: Double {
        // Remove both "." (thousand separator) and "," (decimal separator if any) for parsing
        let cleaned = amountStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }
    private var isStep1Valid: Bool  { !title.isBlank && amount > 0 }

    private var isTripEnded: Bool {
        guard let endDate = trip.endDate?.dateValue() else { return false }
        return Date() > Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
    }

    // Step 2: Participants
    struct ParticipantEntry: Identifiable, Equatable {
        let id: String
        var uid: String
        var name: String
        var isSelected: Bool = true
    }
    @State private var participants: [ParticipantEntry] = []
    @State private var paidByParticipant: ParticipantEntry?

    private var isStep2Valid: Bool { participants.contains(where: { $0.isSelected }) && paidByParticipant != nil }

    // Step 3: Item-based Splits
    @State private var items: [ItemEntry] = []
    @State private var showEditItem: ItemEntry?
    @State private var showAddItem = false
    @State private var showAturPembagian: ItemEntry?  // Item for custom split
    @State private var editingItemName = ""
    @State private var editingItemPrice = ""
    @State private var editingItemQuantity = 1
    @State private var suspendedMemberUIDs: Set<String> = []

    // Split Mode for Step 3
    @State private var splitMode: BillSplitMode = .bagiRata
    @State private var participantAmounts: [String: String] = [:]  // participantID -> amount string

    private var activeParticipants: [ParticipantEntry] { participants.filter { $0.isSelected } }

    // Calculate how much each participant owes based on their item selections
    private func calculateParticipantAmount(_ participantID: String) -> Double {
        // No additional charges in this flow: defaults keep the item total unchanged
        BillSplitCalculator.participantAmount(for: participantID, items: items)
    }

    private var calculatedTotal: Double {
        items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }

    private var isStep3Valid: Bool {
        !items.isEmpty &&
        items.allSatisfy { !$0.selectedParticipantIDs.isEmpty } &&
        abs(calculatedTotal - amount) < 0.01 && // Allow small floating point difference
        allParticipantsHaveItems
    }

    private var isTotalMatching: Bool {
        abs(calculatedTotal - amount) < 0.01
    }

    // Participants who don't have any items assigned
    private var participantsWithoutItems: [ParticipantEntry] {
        activeParticipants.filter { participant in
            calculateParticipantAmount(participant.id) == 0
        }
    }

    private var allParticipantsHaveItems: Bool {
        participantsWithoutItems.isEmpty
    }

    // MARK: - Bagi Rata Mode Helpers
    private func parseAmount(_ str: String) -> Double {
        BillSplitCalculator.parseAmount(str)
    }

    private var bagiRataTotalInput: Double {
        activeParticipants.reduce(0) { total, participant in
            total + parseAmount(participantAmounts[participant.id] ?? "0")
        }
    }

    private var isBagiRataMatching: Bool {
        abs(bagiRataTotalInput - amount) < 1  // Allow Rp 1 tolerance
    }

    private var allParticipantsHaveAmount: Bool {
        activeParticipants.allSatisfy { participant in
            parseAmount(participantAmounts[participant.id] ?? "0") > 0
        }
    }

    private var isStep3ValidBagiRata: Bool {
        isBagiRataMatching && allParticipantsHaveAmount
    }

    private func distributeEvenly() {
        let distributed = BillSplitCalculator.evenDistribution(
            total: amount,
            participantIDs: activeParticipants.map { $0.id }
        )
        for (participantID, value) in distributed {
            participantAmounts[participantID] = value
        }
    }

    private func initializeParticipantAmounts() {
        for participant in activeParticipants {
            if participantAmounts[participant.id] == nil {
                participantAmounts[participant.id] = ""
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Progress
                    ProgressHeader(step: step, totalSteps: 3)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if step == 1 {
                                step1View
                            } else if step == 2 {
                                step2View
                            } else if step == 3 {
                                step3View
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .dismissKeyboardOnTap()
                    
                    // Bottom Navigation
                    bottomNavView
                }
            }
            .navigationTitle(source == .scan ? "Dari Struk" : "Tambah Pengeluaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        }
        .onAppear {
            // Init Amount if scanned
            if let result = scannedResult, let parsed = result.parsedAmount {
                amountStr = String(Int(parsed))
            }
            // Init Items with single default item
            if items.isEmpty && amount > 0 {
                items = [ItemEntry(name: "Total Pengeluaran", price: amount, quantity: 1)]
            }
        }
        .task {
            // Load suspended member UIDs first, then init participants
            await loadSuspendedMembers()
            initParticipants()
        }
        .onChange(of: amountStr) { newValue in
            let formatted = newValue.formattedAsCurrency()
            if amountStr != formatted { amountStr = formatted }

            // Update default item if only one item exists
            if items.count == 1 && items.first?.name == "Total Pengeluaran" {
                items = [ItemEntry(name: "Total Pengeluaran", price: amount, quantity: 1)]
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("Pilih Tanggal", selection: $transactionDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Tanggal Transaksi")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Selesai") {
                                showDatePicker = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPhotoSourcePicker) {
            PhotoSourcePickerView(
                onSelectCamera: {
                    showCameraPicker = true
                },
                onSelectGallery: {
                    showGalleryPicker = true
                }
            )
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showGalleryPicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(item: $showEditItem) { item in
            editItemSheet(item: item)
        }
        .sheet(isPresented: $showAddItem) {
            addItemSheet()
        }
        .sheet(item: $showAturPembagian) { item in
            aturPembagianSheet(item: item)
        }
        .sheet(isPresented: $showEditBankView) {
            NavigationStack {
                EditBankView(profileVM: profileVM)
                    .environmentObject(authVM)
            }
        }
        .alert("Rekening Belum Diisi", isPresented: $showBankAccountAlert) {
            Button("Batal", role: .cancel) {
                // User stays on step 2
            }
            Button("Isi Rekening") {
                showEditBankView = true
            }
        } message: {
            Text("Orang yang bayar dulu belum punya nomor rekening. Silakan isi rekening terlebih dahulu.")
        }
        .alert("Berhasil", isPresented: $showSuccessAlert) {
            Button("OK") {
                isAddingExpense = false
            }
        } message: {
            Text("Pengeluaran berhasil disimpan!")
        }
        .tint(.brandPrimary)
        .onChange(of: showEditBankView) { isShowing in
            if !isShowing && step == 2 {
                if !checkBankAccountBeforeContinue() {
                    withAnimation { step += 1 }
                }
            }
        }
    }
    
    // MARK: - Step 1: Info Dasar
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Receipt Image
            VStack(alignment: .leading, spacing: 10) {
                Text("Foto Struk (Opsional)")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                if let image = selectedImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .contentShape(Rectangle())
                            .onTapGesture { showPhotoSourcePicker = true }

                        Button {
                            selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        .padding(8)
                    }
                } else {
                    Button { showPhotoSourcePicker = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                            Text("Pilih Foto Struk")
                                .font(AppFont.subheadline())
                        }
                        .foregroundColor(Color.accentFallback)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentFallback.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(Color.accentFallback.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                }
            }

            // Nama Pengeluaran
            VStack(alignment: .leading, spacing: 10) {
                Text("Nama Pengeluaran")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "tag.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.brandPrimary)
                    }

                    TextField("Cth: Makan Siang Bersama", text: $title)
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary)
                }
                .padding(14)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(title.isEmpty ? Color.borderSoft : Color.brandPrimary.opacity(0.3), lineWidth: 1)
                )
            }

            // Jumlah
            VStack(alignment: .leading, spacing: 10) {
                Text("Jumlah (\(trip.currency))")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.successGreen.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.successGreen)
                    }

                    TextField("0", text: $amountStr)
                        .keyboardType(.decimalPad)
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                }
                .padding(14)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(amountStr.isEmpty ? Color.borderSoft : Color.successGreen.opacity(0.3), lineWidth: 1)
                )
            }

            // Tanggal Transaksi
            VStack(alignment: .leading, spacing: 10) {
                Text("Tanggal Transaksi")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                Button {
                    showDatePicker = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.warningAmber.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "calendar")
                                .font(.system(size: 18))
                                .foregroundColor(.warningAmber)
                        }

                        Text(formatTransactionDate(transactionDate))
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.textPrimary.opacity(0.3))
                    }
                    .padding(14)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.warningAmber.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Kategori
            VStack(alignment: .leading, spacing: 10) {
                Text("Kategori")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        Button {
                            category = cat
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: cat.color))
                                Text(cat.displayName)
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textPrimary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(category == cat ? Color(hex: cat.color).opacity(0.2) : Color.textPrimary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(category == cat ? Color(hex: cat.color) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Catatan
            VStack(alignment: .leading, spacing: 10) {
                Text("Catatan (opsional)")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.warningAmber.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "note.text")
                            .font(.system(size: 18))
                            .foregroundColor(.warningAmber)
                    }

                    TextField("Tambahkan catatan...", text: $notes)
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary)
                }
                .padding(14)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.borderSoft, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Step 2: Pilih Anggota
    private var step2View: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Siapa yang ikut patungan?")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            VStack(spacing: 12) {
                ForEach($participants) { $participant in
                    let isSuspended = suspendedMemberUIDs.contains(participant.uid)

                    Button {
                        if !isSuspended {
                            participant.isSelected.toggle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isSuspended {
                                Image(systemName: "nosign")
                                    .foregroundColor(.errorRed.opacity(0.5))
                                    .font(.system(size: 22))
                            } else {
                                Image(systemName: participant.isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundColor(participant.isSelected ? .brandPrimary : .textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }

                            ZStack {
                                Circle()
                                    .fill(isSuspended ? Color.errorRed.opacity(0.12) : Color.brandAccent.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Text(String(participant.name.prefix(1)).uppercased())
                                    .font(AppFont.caption())
                                    .foregroundColor(isSuspended ? .errorRed : .brandAccent)
                            }
                            .opacity(isSuspended ? 0.5 : 1.0)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(participant.name)
                                        .font(AppFont.subheadline())
                                        .foregroundColor(isSuspended ? .textPrimary.opacity(0.5) : .textPrimary)

                                    if isSuspended {
                                        Text("Ditangguhkan")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.errorRed)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.errorRed.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                if participant.uid == authVM.currentUser?.uid {
                                    Text("Kamu")
                                        .font(AppFont.caption2())
                                        .foregroundColor(.textPrimary.opacity(0.5))
                                }
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(isSuspended ? Color.errorRed.opacity(0.3) : (participant.isSelected ? Color.brandPrimary : Color.borderSoft), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSuspended)
                }
            }

            // Payer Selection Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💳 Siapa yang bayar dulu?")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)
                        Text("Orang ini yang harus dibayar balik")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.6))
                    }
                    Spacer()
                }

                VStack(spacing: 12) {
                    // Only show non-suspended selected participants as potential payers
                    ForEach(participants.filter { $0.isSelected && !suspendedMemberUIDs.contains($0.uid) }) { participant in
                        Button {
                            paidByParticipant = participant
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: paidByParticipant?.id == participant.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(paidByParticipant?.id == participant.id ? .brandPrimary : .textPrimary.opacity(0.3))
                                    .font(.system(size: 22))

                                ZStack {
                                    Circle()
                                        .fill(Color.brandAccent.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Text(String(participant.name.prefix(1)).uppercased())
                                        .font(AppFont.caption())
                                        .foregroundColor(.brandAccent)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participant.name)
                                        .font(AppFont.subheadline())
                                        .foregroundColor(.textPrimary)
                                    if participant.uid == authVM.currentUser?.uid {
                                        Text("Kamu")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.textPrimary.opacity(0.5))
                                    }
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(Color.cardFallback)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(paidByParticipant?.id == participant.id ? Color.brandPrimary : Color.borderSoft, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Step 3: Siapa Beli Apa
    private var step3View: some View {
        VStack(alignment: .leading, spacing: 20) {
            // If source is scan, go directly to input manual (item-based)
            if source == .scan {
                // Header for scan
                VStack(alignment: .leading, spacing: 8) {
                    Text("Siapa aja yang beli apa?")
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                    Text("Centang item yang dibeli oleh masing-masing orang")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.6))
                }

                inputManualView
            } else {
                // Header for manual
                VStack(alignment: .leading, spacing: 8) {
                    Text("Atur Pembagian")
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                    Text("Pilih metode pembagian tagihan")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.6))
                }

                // Split Mode Selector (only for manual source)
                HStack(spacing: 0) {
                    ForEach(BillSplitMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                splitMode = mode
                                if mode == .bagiRata {
                                    initializeParticipantAmounts()
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode == .bagiRata ? "equal.circle.fill" : "list.bullet.clipboard.fill")
                                    .font(.system(size: 14))
                                Text(mode.rawValue)
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(splitMode == mode ? .white : .textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(splitMode == mode ? Color.brandPrimary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        }
                    }
                }
                .padding(4)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(Color.borderSoft, lineWidth: 1)
                )

                // Content based on mode
                if splitMode == .bagiRata {
                    bagiRataView
                } else {
                    inputManualView
                }
            }
        }
        .onAppear {
            if source == .manual {
                initializeParticipantAmounts()
            }
        }
    }

    // MARK: - Bagi Rata View
    private var bagiRataView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick Actions
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    distributeEvenly()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16))
                    Text("Bagi Rata Otomatis")
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                }
                .foregroundColor(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brandPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Info Text
            Text("Masukkan nominal pembagian untuk masing-masing orang. Total harus sama dengan total tagihan.")
                .font(AppFont.caption())
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 4)

            // Participants Amount List
            VStack(spacing: 12) {
                ForEach(activeParticipants) { participant in
                    bagiRataParticipantRow(participant: participant)
                }
            }

            // Total Summary
            bagiRataSummary
        }
    }

    // MARK: - Bagi Rata Participant Row
    private func bagiRataParticipantRow(participant: ParticipantEntry) -> some View {
        let amountBinding = Binding<String>(
            get: { participantAmounts[participant.id] ?? "" },
            set: { participantAmounts[participant.id] = $0 }
        )
        let participantAmount = parseAmount(amountBinding.wrappedValue)
        let hasAmount = participantAmount > 0

        return HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(String(participant.name.prefix(1)).uppercased())
                    .font(AppFont.subheadline())
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.bold)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)

                if hasAmount {
                    Text(participantAmount.toCurrency(symbol: trip.currency))
                        .font(AppFont.caption())
                        .foregroundColor(.brandPrimary)
                }
            }

            Spacer()

            // Amount Input
            HStack(spacing: 4) {
                Text(trip.currency)
                    .font(AppFont.caption())
                    .foregroundColor(.textSecondary)
                    .fixedSize()

                TextField("0", text: amountBinding)
                    .keyboardType(.numberPad)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(!hasAmount ? Color.warningAmber.opacity(0.5) : Color.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Bagi Rata Summary
    private var bagiRataSummary: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Total Input")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(bagiRataTotalInput.toCurrency(symbol: trip.currency))
                    .font(AppFont.headline())
                    .foregroundColor(isBagiRataMatching ? .successGreen : .errorRed)
            }

            HStack {
                Text("Total Tagihan")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(amount.toCurrency(symbol: trip.currency))
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
            }

            if !isBagiRataMatching {
                let difference = amount - bagiRataTotalInput
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(difference > 0 ?
                         "Kurang \(difference.toCurrency(symbol: trip.currency))" :
                         "Lebih \(abs(difference).toCurrency(symbol: trip.currency))")
                        .font(AppFont.caption())
                }
                .foregroundColor(.errorRed)
            } else if allParticipantsHaveAmount {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Pembagian sudah sesuai!")
                        .font(AppFont.caption())
                }
                .foregroundColor(.successGreen)
            }

            if !allParticipantsHaveAmount {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill.xmark")
                        .font(.system(size: 12))
                    Text("Semua peserta harus memiliki nominal")
                        .font(AppFont.caption())
                }
                .foregroundColor(.warningAmber)
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Input Manual View
    private var inputManualView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Helper Text
            Text("Centang item yang dibeli oleh masing-masing orang")
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.6))
                .padding(.horizontal, 4)

            // Items List
            VStack(spacing: 16) {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 12) {
                        // Item Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                // Item name with quantity prefix (always show)
                                Text("\(item.quantity)x \(item.name)")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                                HStack(spacing: 4) {
                                    Text(item.price.toCurrency(symbol: trip.currency))
                                        .font(AppFont.caption())
                                        .foregroundColor(.brandPrimary)
                                    if item.quantity > 1 {
                                        Text("(@\((item.price * Double(item.quantity)).toCurrency(symbol: trip.currency)))")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.textPrimary.opacity(0.5))
                                    }
                                }
                            }
                            Spacer()
                            // Edit button
                            Button {
                                showEditItem = item
                                editingItemName = item.name
                                editingItemPrice = String(Int(item.price))
                                editingItemQuantity = item.quantity
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.textPrimary.opacity(0.5))
                            }
                            // Count badge
                            if !item.selectedParticipantIDs.isEmpty {
                                Text("\(item.selectedParticipantIDs.count)")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.brandPrimary)
                                    .clipShape(Capsule())
                            }
                        }

                        // Participants Chips
                        FlowLayout(spacing: 8) {
                            ForEach(activeParticipants) { participant in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if item.selectedParticipantIDs.contains(participant.id) {
                                            item.selectedParticipantIDs.remove(participant.id)
                                            // Also remove from custom splits
                                            item.customSplits.removeValue(forKey: participant.id)
                                        } else {
                                            item.selectedParticipantIDs.insert(participant.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: item.selectedParticipantIDs.contains(participant.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 14))
                                        Text(participant.name)
                                            .font(AppFont.caption())
                                    }
                                    .foregroundColor(item.selectedParticipantIDs.contains(participant.id) ? .white : .textPrimary.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(item.selectedParticipantIDs.contains(participant.id) ? Color.brandPrimary : Color.textPrimary.opacity(0.08))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Atur Pembagian Button (only show if more than 1 participant)
                        if item.selectedParticipantIDs.count > 1 {
                            Button {
                                showAturPembagian = item
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 14))
                                    Text("Atur Pembagian")
                                        .font(AppFont.caption())
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.brandAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.brandAccent.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.brandAccent.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(item.selectedParticipantIDs.isEmpty ? Color.errorRed.opacity(0.3) : Color.borderSoft, lineWidth: 1)
                    )
                }

                // Add Item Button
                Button {
                    showAddItem = true
                    editingItemName = ""
                    editingItemPrice = ""
                    editingItemQuantity = 1
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("Tambah Item Manual")
                            .font(AppFont.subheadline())
                    }
                    .foregroundColor(.brandAccent)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.brandAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(.brandAccent)
                    )
                }
                .buttonStyle(.plain)
            }

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Ringkasan Pembagian")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                VStack(spacing: 8) {
                    ForEach(activeParticipants) { participant in
                        let participantAmount = calculateParticipantAmount(participant.id)
                        if participantAmount > 0 {
                            HStack {
                                Text(participant.name)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Text(participantAmount.toCurrency(symbol: trip.currency))
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.brandPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Divider()

                    // Total Tagihan (from step 1)
                    HStack {
                        Text("Total Tagihan")
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                        Spacer()
                        Text(amount.toCurrency(symbol: trip.currency))
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                    }
                    .padding(.vertical, 4)

                    // Total Items (calculated)
                    HStack {
                        Text("Total Items")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(calculatedTotal.toCurrency(symbol: trip.currency))
                            .font(AppFont.headline())
                            .foregroundColor(isTotalMatching ? .brandPrimary : .errorRed)
                    }

                    // Warning if not matching
                    if !isTotalMatching {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("Total items harus sama dengan total tagihan")
                                .font(AppFont.caption2())
                        }
                        .foregroundColor(.errorRed)
                        .padding(.top, 4)
                    }

                    // Warning if some participants don't have items
                    if !participantsWithoutItems.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill.xmark")
                                    .font(.system(size: 12))
                                Text("Peserta berikut belum punya item:")
                                    .font(AppFont.caption2())
                            }
                            .foregroundColor(.errorRed)

                            Text(participantsWithoutItems.map { $0.name }.joined(separator: ", "))
                                .font(AppFont.caption2())
                                .fontWeight(.medium)
                                .foregroundColor(.errorRed)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(12)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
        }
    }
    
    // MARK: - Bottom Nav View
    private var bottomNavView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if step > 1 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Text("Kembali")
                            .font(AppFont.headline())
                            .foregroundColor(.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.brandPrimary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                }
                
                if step < 3 {
                    Button {
                        handleNextStep()
                    } label: {
                        Text("Selanjutnya")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background((step == 1 ? isStep1Valid : isStep2Valid) ? LinearGradient.brandGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                    .disabled(step == 1 ? !isStep1Valid : !isStep2Valid)
                } else {
                    // For scan source, always use item-based validation
                    // For manual source, check split mode
                    let isValid = source == .scan ? isStep3Valid : (splitMode == .bagiRata ? isStep3ValidBagiRata : isStep3Valid)
                    Button {
                        if isTripEnded {
                            showPostTripAlert = true
                        } else {
                            Task { await saveExpense() }
                        }
                    } label: {
                        Text(expenseVM.isLoading ? "Menyimpan..." : "Simpan Pengeluaran")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? LinearGradient.brandGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                    .disabled(!isValid || expenseVM.isLoading)
                    .alert("Pengeluaran Setelah Trip", isPresented: $showPostTripAlert) {
                        Button("Batal", role: .cancel) {}
                        Button("Tetap Simpan") {
                            Task { await saveExpense() }
                        }
                    } message: {
                        Text("Pengeluaran ini dibuat setelah tanggal akhir trip. Apakah kamu yakin ingin menyimpannya?")
                    }
                }
            }
            .padding(20)
            .background(Color.baseFallback)
        }
    }

    // MARK: - Navigation & Validation
    private func handleNextStep() {
        // Check bank account before going to step 3
        if step == 2 {
            if checkBankAccountBeforeContinue() {
                showBankAccountAlert = true
                return
            }
        }
        withAnimation { step += 1 }
    }

    private func checkBankAccountBeforeContinue() -> Bool {
        // Only check if payer is current user
        guard let payer = paidByParticipant,
              let currentUser = authVM.currentUser else {
            return false
        }

        // Only check bank account if payer is current user
        if payer.uid == currentUser.uid {
            // Check if current user has bank account
            if currentUser.bankInfo == nil {
                return true  // Show alert
            }
        }

        return false  // No alert needed
    }

    // MARK: - Save Logic
    private func saveExpense() async {
        guard let user = authVM.currentUser else { return }

        // Build splits based on split mode
        // For scan source, always use item-based; for manual, check splitMode
        let useItemBased = source == .scan || splitMode == .inputManual
        let finalSplits: [ExpenseSplit]
        var finalNotes = notes.isBlank ? "" : notes + "\n\n"
        finalNotes += "Metode Pembagian: \(useItemBased ? "Per Item" : "Bagi Rata")\n\n"

        if !useItemBased {
            // Bagi Rata Mode
            finalSplits = activeParticipants.compactMap { p in
                let splitAmount = parseAmount(participantAmounts[p.id] ?? "0")
                guard splitAmount > 0 else { return nil }

                // Payer's split is automatically marked as paid
                let isPayerSplit = p.uid == paidByParticipant?.uid

                return ExpenseSplit(
                    id: p.id,
                    uid: p.uid,
                    displayName: p.name,
                    amount: splitAmount,
                    items: ["Pembagian rata: \(splitAmount.toCurrency(symbol: trip.currency))"],
                    isPaid: isPayerSplit ? true : nil
                )
            }

            // Build notes for bagi rata
            finalNotes += "Peserta Patungan:\n"
            for p in activeParticipants {
                let splitAmount = parseAmount(participantAmounts[p.id] ?? "0")
                if splitAmount > 0 {
                    finalNotes += "• \(p.name): \(splitAmount.toCurrency(symbol: trip.currency))\n"
                }
            }
        } else {
            // Input Manual Mode (item-based)
            finalSplits = activeParticipants.compactMap { p in
                let splitAmount = calculateParticipantAmount(p.id)
                guard splitAmount > 0 else { return nil }

                // Get items for this participant
                var participantItems: [String] = []
                for item in items {
                    if item.selectedParticipantIDs.contains(p.id) {
                        let shareCount = item.selectedParticipantIDs.count
                        let qtyPrefix = item.quantity > 1 ? "\(item.quantity)x " : ""

                        // Check if custom split exists
                        if let customSplit = item.customSplits[p.id], !item.customSplits.isEmpty {
                            let itemStr = "\(qtyPrefix)\(item.name) - \(customSplit.customAmount.toCurrency(symbol: trip.currency))"
                            participantItems.append(itemStr)
                        } else if shareCount > 1 {
                            // Shared item
                            let shareAmount = (item.price * Double(item.quantity)) / Double(shareCount)
                            let itemStr = "\(qtyPrefix)\(item.name) (1/\(shareCount)) - \(shareAmount.toCurrency(symbol: trip.currency))"
                            participantItems.append(itemStr)
                        } else {
                            // Solo item
                            let itemTotal = item.price * Double(item.quantity)
                            let itemStr = "\(qtyPrefix)\(item.name) - \(itemTotal.toCurrency(symbol: trip.currency))"
                            participantItems.append(itemStr)
                        }
                    }
                }

                // Payer's split is automatically marked as paid (they paid for everyone)
                let isPayerSplit = p.uid == paidByParticipant?.uid

                return ExpenseSplit(
                    id: p.id,
                    uid: p.uid,
                    displayName: p.name,
                    amount: splitAmount,
                    items: participantItems,
                    isPaid: isPayerSplit ? true : nil
                )
            }

            // Build notes with item breakdown
            finalNotes += "Pembagian Item:\n"
            for item in items {
                if !item.selectedParticipantIDs.isEmpty {
                    let participantNames = activeParticipants
                        .filter { item.selectedParticipantIDs.contains($0.id) }
                        .map { $0.name }
                        .joined(separator: ", ")
                    let qtyPrefix = item.quantity > 1 ? "\(item.quantity)x " : ""
                    let itemTotal = item.price * Double(item.quantity)
                    finalNotes += "• \(qtyPrefix)\(item.name) (\(trip.currency) \(Int(item.price))"
                    if item.quantity > 1 {
                        finalNotes += " @ \(trip.currency) \(Int(itemTotal))"
                    }
                    finalNotes += "): \(participantNames)\n"
                }
            }
        }

        // Get payer info
        guard let payer = paidByParticipant else { return }

        // Get bank account info for payer (only if payer is current user)
        var paidByBankAccount: String? = nil
        if payer.uid == user.uid, let bankInfo = user.bankInfo {
            paidByBankAccount = "\(bankInfo.bankName) - \(bankInfo.accountNumber) a.n. \(bankInfo.accountName)"
        }

        // Use calculatedTotal for item-based, amount for bagi rata
        let finalAmount = useItemBased ? calculatedTotal : amount

        await expenseVM.addExpense(
            tripID: trip.id ?? "",
            tripName: trip.name,
            title: title,
            amount: finalAmount,
            currency: trip.currency,
            category: category,
            paidByUID: payer.uid,
            paidByName: payer.name,
            paidByBankAccount: paidByBankAccount,
            splitType: .custom,  // Always use custom for item-based
            members: trip.members,
            customSplits: finalSplits,
            notes: finalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptImage: selectedImage,
            transactionDate: transactionDate
        )
        showSuccessAlert = true
    }
    
    // MARK: - Helpers

    private func formatTransactionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Edit Item Sheet
    @ViewBuilder
    private func editItemSheet(item: ItemEntry) -> some View {
        NavigationStack {
            Form {
                Section("Informasi Item") {
                    TextField("Nama Item", text: $editingItemName)
                    TextField("Harga", text: $editingItemPrice)
                        .keyboardType(.numberPad)
                    Stepper("Jumlah: \(editingItemQuantity)", value: $editingItemQuantity, in: 1...99)
                }

                Section {
                    Button("Hapus Item", role: .destructive) {
                        items.removeAll { $0.id == item.id }
                        showEditItem = nil
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showEditItem = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                            items[index].name = editingItemName.trimmed
                            items[index].price = Double(editingItemPrice.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
                            items[index].quantity = editingItemQuantity
                        }
                        showEditItem = nil
                    }
                    .disabled(editingItemName.isBlank || editingItemPrice.isBlank)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Add Item Sheet
    @ViewBuilder
    private func addItemSheet() -> some View {
        NavigationStack {
            Form {
                Section("Informasi Item Baru") {
                    TextField("Nama Item", text: $editingItemName)
                    TextField("Harga", text: $editingItemPrice)
                        .keyboardType(.numberPad)
                    Stepper("Jumlah: \(editingItemQuantity)", value: $editingItemQuantity, in: 1...99)
                }
            }
            .navigationTitle("Tambah Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        showAddItem = false
                        editingItemName = ""
                        editingItemPrice = ""
                        editingItemQuantity = 1
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tambah") {
                        let newItem = ItemEntry(
                            name: editingItemName.trimmed,
                            price: Double(editingItemPrice.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")) ?? 0,
                            quantity: editingItemQuantity
                        )
                        items.append(newItem)
                        showAddItem = false
                        editingItemName = ""
                        editingItemPrice = ""
                        editingItemQuantity = 1
                    }
                    .disabled(editingItemName.isBlank || editingItemPrice.isBlank)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Atur Pembagian Sheet
    @ViewBuilder
    private func aturPembagianSheet(item: ItemEntry) -> some View {
        let selectedParticipants = activeParticipants.filter { item.selectedParticipantIDs.contains($0.id) }
        let participantTuples = selectedParticipants.map { (id: $0.id, name: $0.name) }

        AturPembagianView(
            itemName: item.name,
            itemPrice: item.price * Double(item.quantity),
            itemQuantity: item.quantity,
            currency: trip.currency,
            participants: participantTuples,
            onSave: { splits in
                // Update the item's custom splits
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].customSplits = splits

                    // Remove participants with 0 portion from selectedParticipantIDs
                    for (participantId, split) in splits {
                        if split.portion == 0 {
                            items[index].selectedParticipantIDs.remove(participantId)
                            items[index].customSplits.removeValue(forKey: participantId)
                            print("🔴 [AddExpenseView] Removed \(split.name) from \(item.name) (0 porsi)")
                        } else {
                            print("   👤 \(split.name): \(split.portion) porsi = \(trip.currency) \(Int(split.customAmount))")
                        }
                    }
                    print("✅ [AddExpenseView] Custom splits saved for \(item.name)")
                }
            }
        )
    }

    // MARK: - Load Suspended Members
    private func loadSuspendedMembers() async {
        let memberUIDs = trip.memberUIDs
        guard !memberUIDs.isEmpty else { return }

        do {
            let db = FirestoreService.shared.db
            let snapshot = try await db.collection(Collection.users)
                .whereField("uid", in: memberUIDs)
                .getDocuments()

            let suspended = snapshot.documents.compactMap { doc -> String? in
                guard let user = try? doc.data(as: UserModel.self),
                      user.isSuspended else { return nil }
                return user.uid
            }

            suspendedMemberUIDs = Set(suspended)
        } catch {
            print("Error loading suspended members: \(error)")
        }
    }

    // MARK: - Init Participants
    private func initParticipants() {
        guard participants.isEmpty else { return }

        // Include all members, but suspended users are not selected by default
        participants = trip.members.map { member in
            let isSuspended = suspendedMemberUIDs.contains(member.uid)
            return ParticipantEntry(
                id: UUID().uuidString,
                uid: member.uid,
                name: member.displayName,
                isSelected: !isSuspended  // Suspended users not selected by default
            )
        }

        // Set default payer to current user (if not suspended), or first non-suspended participant
        if let currentUser = authVM.currentUser,
           !suspendedMemberUIDs.contains(currentUser.uid) {
            paidByParticipant = participants.first(where: { $0.uid == currentUser.uid })
        }
        // Fallback to first non-suspended participant if payer still not set
        if paidByParticipant == nil {
            paidByParticipant = participants.first(where: { !suspendedMemberUIDs.contains($0.uid) })
        }
    }
}
