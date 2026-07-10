//  CreateExpenseFromReceiptView.swift
//  Wizard 3 langkah membuat pengeluaran dari hasil scan struk (tanpa mode bagi rata).
//  Form terisi otomatis dari ParsedReceiptModel. Companion: +Steps, +Sheets.
//
import SwiftUI
import FirebaseFirestore

struct CreateExpenseFromReceiptView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var expenseVM: ExpenseViewModel

    let trip: TripModel
    let scannedResult: OCRResult?
    let receiptImage: UIImage?
    @Binding var isAddingExpense: Bool

    // UI State
    @State var step = 1
    @State var showBankAccountAlert = false
    @State var showEditBankView = false
    @State var showSuccessAlert = false
    @StateObject var profileVM = ProfileViewModel()

    // Step 1: Info Dasar
    @State var title = ""
    @State var amountStr = ""
    @State var currency = "Rp"
    @State var category = ExpenseCategory.food
    @State var notes = ""
    @State var transactionDate = Date()

    // Additional charges (from OCR)
    @State var taxAmountStr = ""
    @State var serviceChargeStr = ""
    @State var discountStr = ""
    @State var roundingStr = ""

    var totalAmount: Double {
        let cleaned = amountStr
            .replacingOccurrences(of: ".", with: "")  // Remove thousand separator
            .replacingOccurrences(of: ",", with: "")  // Remove any commas
            .trimmingCharacters(in: .whitespaces)
        let amount = Double(cleaned) ?? 0
        return amount
    }

    var taxAmount: Double {
        let cleaned = taxAmountStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    var serviceCharge: Double {
        let cleaned = serviceChargeStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    var discount: Double {
        let cleaned = discountStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    var rounding: Double {
        let cleaned = roundingStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        // Rounding can be negative (starts with -)
        return Double(cleaned) ?? 0
    }

    var isStep1Valid: Bool { !title.isBlank && totalAmount > 0 }

    // Step 2: Participants
    struct ParticipantEntry: Identifiable, Equatable {
        let id: String
        var uid: String
        var name: String
        var isSelected: Bool = true
    }
    @State var participants: [ParticipantEntry] = []
    @State var paidByParticipant: ParticipantEntry?
    @State var suspendedMemberUIDs: Set<String> = []

    var isStep2Valid: Bool { participants.contains(where: { $0.isSelected }) && paidByParticipant != nil }

    // Step 3: Item-based Splits
    @State var items: [ItemEntry] = []
    @State var showEditItem: ItemEntry?
    @State var showAddItem = false
    @State var showAturPembagian: ItemEntry?  // Item for custom split
    @State var editingItemName = ""
    @State var editingItemPrice = ""
    @State var editingItemQuantity = 1
    @State var showDatePicker = false

    var activeParticipants: [ParticipantEntry] { participants.filter { $0.isSelected } }

    // Calculate how much each participant owes based on their item selections
    func calculateParticipantAmount(_ participantID: String) -> Double {
        BillSplitCalculator.participantAmount(
            for: participantID,
            items: items,
            taxAmount: taxAmount,
            serviceCharge: serviceCharge,
            rounding: rounding,
            discount: discount
        )
    }

    var calculatedTotal: Double {
        let itemsTotal = items.reduce(0.0) { $0 + ($1.price * Double($1.quantity)) }
        // Add tax, service charge, rounding, subtract discount
        return itemsTotal + taxAmount + serviceCharge + rounding - discount
    }

    var isStep3Valid: Bool {
        !items.isEmpty &&
        items.allSatisfy { !$0.selectedParticipantIDs.isEmpty } &&
        abs(calculatedTotal - totalAmount) < 0.01 &&
        allParticipantsHaveItems
    }

    var isTotalMatching: Bool {
        abs(calculatedTotal - totalAmount) < 0.01
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
            .navigationTitle("Dari Struk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        }
        .onAppear {
            AppLog.debug("\n📋 [CreateExpenseFromReceiptView] Initializing form...")
            AppLog.debug("   📸 Received receiptImage: \(receiptImage != nil)")
            AppLog.debug("   🔍 Received scannedResult: \(scannedResult != nil)")

            // Auto-fill from AI-parsed receipt data
            if let result = scannedResult, let parsed = result.parsedReceipt {
                AppLog.debug("✨ [CreateExpenseFromReceiptView] Auto-filling from AI-parsed data:")

                // Fill expense name
                title = parsed.billName
                AppLog.debug("   📝 Title: \(parsed.billName)")

                // Fill total amount
                amountStr = String(Int(parsed.totalAmount))
                AppLog.debug("   💰 Amount: \(parsed.currency) \(parsed.totalAmount)")

                // Fill currency
                currency = parsed.currency

                // Fill category if available
                if let cat = parsed.category {
                    if let expenseCategory = ExpenseCategory.fromString(cat) {
                        category = expenseCategory
                        AppLog.debug("   🏷️  Category: \(cat) → \(expenseCategory.displayName)")
                    } else {
                        AppLog.debug("   ⚠️ Category '\(cat)' not mapped, using default")
                    }
                }

                // Fill date if available
                if let dateStr = parsed.date, let date = parseDate(dateStr) {
                    transactionDate = date
                    AppLog.debug("   📅 Date: \(dateStr)")
                }

                // Fill additional charges
                if let tax = parsed.taxAmount, tax > 0 {
                    taxAmountStr = String(Int(tax))
                    AppLog.debug("   🧾 Tax: \(tax)")
                }
                if let service = parsed.serviceCharge, service > 0 {
                    serviceChargeStr = String(Int(service))
                    AppLog.debug("   🔔 Service Charge: \(service)")
                }
                if let disc = parsed.discount, disc > 0 {
                    discountStr = String(Int(disc))
                    AppLog.debug("   🎫 Discount: \(disc)")
                }
                if let round = parsed.rounding {
                    // Rounding can be negative
                    roundingStr = String(Int(round))
                    AppLog.debug("   🔄 Rounding: \(round)")
                }

                // Fill items for Step 3 (filter out items without price)
                if !parsed.items.isEmpty {
                    items = parsed.items.compactMap { receiptItem in
                        // Skip items without price
                        guard let price = receiptItem.price, price > 0 else {
                            AppLog.debug("   ⚠️ Skipping item '\(receiptItem.name)' - no price")
                            return nil
                        }
                        return ItemEntry(
                            name: receiptItem.name,
                            price: price,
                            quantity: receiptItem.quantity ?? 1
                        )
                    }
                    AppLog.debug("   📦 Items: \(items.count) items loaded (filtered from \(parsed.items.count))")
                } else {
                    // If no items, create a single "Total" item
                    items = [ItemEntry(name: "Total Pengeluaran", price: parsed.totalAmount, quantity: 1)]
                    AppLog.debug("   ⚠️ No items found, using total as single item")
                }

                AppLog.debug("✅ [CreateExpenseFromReceiptView] Auto-fill completed from AI data")
            } else if let result = scannedResult, let parsed = result.parsedAmount {
                // Fallback to basic OCR parsing
                amountStr = String(Int(parsed))
                AppLog.debug("⚠️ [CreateExpenseFromReceiptView] Using basic OCR parsing (amount only): \(parsed)")

                // Create single item for manual split
                if totalAmount > 0 {
                    items = [ItemEntry(name: "Total Pengeluaran", price: totalAmount, quantity: 1)]
                }
            } else {
                AppLog.debug("ℹ️ [CreateExpenseFromReceiptView] No scanned data")
            }

            // Ensure items exist
            if items.isEmpty && totalAmount > 0 {
                items = [ItemEntry(name: "Total Pengeluaran", price: totalAmount)]
                AppLog.debug("   📦 Created default item for manual split")
            }

            AppLog.debug("📋 [CreateExpenseFromReceiptView] Form initialized\n")
        }
        .task {
            // Load suspended member UIDs first, then init participants
            await loadSuspendedMembers()
            initParticipants()
        }
        .onChange(of: totalAmount) { _ in
            // Update items if total changes and we only have the default item
            if items.count == 1 && items.first?.name == "Total Pengeluaran" {
                items = [ItemEntry(name: "Total Pengeluaran", price: totalAmount, quantity: 1)]
            }
        }
        .onChange(of: amountStr) { newValue in
            let formatted = newValue.formattedAsCurrency()
            if amountStr != formatted { amountStr = formatted }
        }
        .onChange(of: taxAmountStr) { newValue in
            let formatted = newValue.formattedAsCurrency()
            if taxAmountStr != formatted { taxAmountStr = formatted }
        }
        .onChange(of: serviceChargeStr) { newValue in
            let formatted = newValue.formattedAsCurrency()
            if serviceChargeStr != formatted { serviceChargeStr = formatted }
        }
        .onChange(of: discountStr) { newValue in
            let formatted = newValue.formattedAsCurrency()
            if discountStr != formatted { discountStr = formatted }
        }
        .onChange(of: roundingStr) { newValue in
            // Rounding can be negative, so we need special handling
            let isNegative = newValue.hasPrefix("-")
            let cleanedForFormat = newValue.replacingOccurrences(of: "-", with: "")
            let formatted = cleanedForFormat.formattedAsCurrency()
            let finalValue = isNegative ? "-\(formatted)" : formatted
            if roundingStr != finalValue { roundingStr = finalValue }
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
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker("Pilih Tanggal", selection: $transactionDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "id_ID"))
                        .padding()
                    Spacer()
                }
                .navigationTitle("Pilih Tanggal")
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

    // MARK: - Save
    func saveExpense() async {
        guard let user = authVM.currentUser else { return }

        AppLog.debug("💾 [CreateExpenseFromReceiptView] Saving expense...")
        AppLog.debug("   📝 Title: \(title)")
        AppLog.debug("   💰 Amount: \(currency) \(calculatedTotal)")
        AppLog.debug("   📸 receiptImage available: \(receiptImage != nil)")

        // Build splits based on item selections
        let finalSplits: [ExpenseSplit] = activeParticipants.compactMap { p in
            let splitAmount = calculateParticipantAmount(p.id)
            guard splitAmount > 0 else { return nil }

            // Get items for this participant
            let participantItems = BillNotesBuilder.participantItemList(
                for: p.id, items: items, currency: currency
            )

            // Payer's split is automatically marked as paid (they paid for everyone)
            let isPayerSplit = p.uid == paidByParticipant?.uid

            AppLog.debug("   👤 \(p.name): \(currency) \(splitAmount) - \(participantItems.count) items - isPaid: \(isPayerSplit)")
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
        var finalNotes = notes.isBlank ? "" : notes + "\n\n"
        finalNotes += "Tanggal: \(formatDate(transactionDate))\n\n"
        finalNotes += "Pembagian Item:\n"
        finalNotes += BillNotesBuilder.itemBreakdownLines(
            items: items,
            participants: activeParticipants.map { ($0.id, $0.name) },
            currency: currency
        )

        // Get payer info
        guard let payer = paidByParticipant else { return }

        // Get bank account info for payer (only if payer is current user)
        var paidByBankAccount: String? = nil
        if payer.uid == user.uid, let bankInfo = user.bankInfo {
            paidByBankAccount = BillNotesBuilder.bankAccountLine(bankInfo)
        }

        await expenseVM.addExpense(
            tripID: trip.id ?? "",
            tripName: trip.name,
            title: title,
            amount: calculatedTotal,
            currency: currency,
            category: category,
            paidByUID: payer.uid,
            paidByName: payer.name,
            paidByBankAccount: paidByBankAccount,
            splitType: .custom,  // Always use custom for item-based
            members: trip.members,
            customSplits: finalSplits,
            notes: finalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptImage: receiptImage,
            transactionDate: transactionDate
        )

        AppLog.debug("✅ [CreateExpenseFromReceiptView] Expense saved successfully!")
        showSuccessAlert = true
    }

    // MARK: - Helper: Parse Date
    func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }

    // MARK: - Helper: Format Date
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }

    // MARK: - Helper: Format Transaction Date (Full format with day)
    func formatTransactionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }

    // MARK: - Load Suspended Members
    func loadSuspendedMembers() async {
        let memberUIDs = trip.memberUIDs
        guard !memberUIDs.isEmpty else { return }

        do {
            suspendedMemberUIDs = try await FirestoreService.shared.fetchSuspendedMemberUIDs(memberUIDs: memberUIDs)
        } catch {
            AppLog.debug("Error loading suspended members: \(error)")
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

        AppLog.debug("👥 [CreateExpenseFromReceiptView] Loaded \(participants.count) participants from trip")
    }
}
