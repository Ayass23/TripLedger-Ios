import SwiftUI
import UIKit
import FirebaseCore
import FirebaseFirestore

struct AddExpenseView: View {
    @Environment(\.dismiss)          var dismiss
    @EnvironmentObject var authVM:    AuthViewModel
    @EnvironmentObject var expenseVM: ExpenseViewModel
    
    let trip: TripModel
    var source: AddExpenseSource = .manual
    var scannedResult: OCRResult? = nil
    @Binding var isAddingExpense: Bool
    
    // UI State
    @State var step = 1
    @State var showBankAccountAlert = false
    @State var showEditBankView = false
    @State var showPostTripAlert = false
    @State var showSuccessAlert = false
    @StateObject var profileVM = ProfileViewModel()

    // Step 1: Info
    @State var title      = ""
    @State var amountStr  = ""
    @State var category   = ExpenseCategory.food
    @State var notes      = ""
    @State var transactionDate = Date()
    @State var showDatePicker = false
    @State var showPhotoSourcePicker = false
    @State var showCameraPicker = false
    @State var showGalleryPicker = false
    @State var selectedImage: UIImage? = nil
    
    var amount: Double {
        // Remove both "." (thousand separator) and "," (decimal separator if any) for parsing
        let cleaned = amountStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }
    var isStep1Valid: Bool  { !title.isBlank && amount > 0 }

    var isTripEnded: Bool {
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
    @State var participants: [ParticipantEntry] = []
    @State var paidByParticipant: ParticipantEntry?

    var isStep2Valid: Bool { participants.contains(where: { $0.isSelected }) && paidByParticipant != nil }

    // Step 3: Item-based Splits
    @State var items: [ItemEntry] = []
    @State var showEditItem: ItemEntry?
    @State var showAddItem = false
    @State var showAturPembagian: ItemEntry?  // Item for custom split
    @State var editingItemName = ""
    @State var editingItemPrice = ""
    @State var editingItemQuantity = 1
    @State var suspendedMemberUIDs: Set<String> = []

    // Split Mode for Step 3
    @State var splitMode: BillSplitMode = .bagiRata
    @State var participantAmounts: [String: String] = [:]  // participantID -> amount string

    var activeParticipants: [ParticipantEntry] { participants.filter { $0.isSelected } }

    // Calculate how much each participant owes based on their item selections
    func calculateParticipantAmount(_ participantID: String) -> Double {
        // No additional charges in this flow: defaults keep the item total unchanged
        BillSplitCalculator.participantAmount(for: participantID, items: items)
    }

    var calculatedTotal: Double {
        items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }

    var isStep3Valid: Bool {
        !items.isEmpty &&
        items.allSatisfy { !$0.selectedParticipantIDs.isEmpty } &&
        abs(calculatedTotal - amount) < 0.01 && // Allow small floating point difference
        allParticipantsHaveItems
    }

    var isTotalMatching: Bool {
        abs(calculatedTotal - amount) < 0.01
    }

    // Participants who don't have any items assigned
    var participantsWithoutItems: [ParticipantEntry] {
        activeParticipants.filter { participant in
            calculateParticipantAmount(participant.id) == 0
        }
    }

    var allParticipantsHaveItems: Bool {
        participantsWithoutItems.isEmpty
    }

    // MARK: - Bagi Rata Mode Helpers
    func parseAmount(_ str: String) -> Double {
        BillSplitCalculator.parseAmount(str)
    }

    var bagiRataTotalInput: Double {
        activeParticipants.reduce(0) { total, participant in
            total + parseAmount(participantAmounts[participant.id] ?? "0")
        }
    }

    var isBagiRataMatching: Bool {
        abs(bagiRataTotalInput - amount) < 1  // Allow Rp 1 tolerance
    }

    var allParticipantsHaveAmount: Bool {
        activeParticipants.allSatisfy { participant in
            parseAmount(participantAmounts[participant.id] ?? "0") > 0
        }
    }

    var isStep3ValidBagiRata: Bool {
        isBagiRataMatching && allParticipantsHaveAmount
    }

    func distributeEvenly() {
        let distributed = BillSplitCalculator.evenDistribution(
            total: amount,
            participantIDs: activeParticipants.map { $0.id }
        )
        for (participantID, value) in distributed {
            participantAmounts[participantID] = value
        }
    }

    func initializeParticipantAmounts() {
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
    
    // MARK: - Navigation & Validation
    func handleNextStep() {
        // Check bank account before going to step 3
        if step == 2 {
            if checkBankAccountBeforeContinue() {
                showBankAccountAlert = true
                return
            }
        }
        withAnimation { step += 1 }
    }

    func checkBankAccountBeforeContinue() -> Bool {
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
    func saveExpense() async {
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

    func formatTransactionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Load Suspended Members
    func loadSuspendedMembers() async {
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
    func initParticipants() {
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
