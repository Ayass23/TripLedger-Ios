import SwiftUI
import UIKit
import FirebaseFirestore

struct CreateSplitBillView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM:      AuthViewModel
    @EnvironmentObject var splitBillVM: SplitBillViewModel
    @EnvironmentObject var friendsVM:   FriendsViewModel
    @StateObject var profileVM = ProfileViewModel()

    let source:        SplitBillSource
    let scannedResult: OCRResult?
    let receiptImage:  UIImage?

    // UI State
    @State var step = 1
    @State var showSuccessAlert = false

    // Step 1: Info Dasar
    @State var title       = ""
    @State var amountStr   = ""
    @State var currency    = "Rp"
    @State var category    = ExpenseCategory.food
    @State var notes       = ""
    @State var transactionDate = Date()
    @State var showPhotoSourcePicker = false
    @State var showCameraPicker = false
    @State var showGalleryPicker = false
    @State var selectedImage: UIImage? = nil
    @State var showDatePicker = false

    // Additional charges (editable)
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
        AppLog.debug("💰 [CreateSplitBillView] totalAmount computed: '\(amountStr)' → \(amount)")
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
    @State var participants: [ParticipantEntry] = []
    @State var showAddGuest = false
    @State var paidByParticipant: ParticipantEntry?  // Who paid first (default: current user)

    // Bank Account Check
    @State var showBankAccountAlert = false
    @State var showEditBankView = false

    var isStep2Valid: Bool { participants.contains(where: { $0.isSelected }) }

    // Loading overlay
    @State var showLoadingOverlay = false
    @State var loadingMessage = ""

    // Step 3: Item-based Splits
    @State var items: [ItemEntry] = []
    @State var showEditItem: ItemEntry?  // Item being edited
    @State var showAddItem = false  // Show add item sheet
    @State var showAturPembagian: ItemEntry?  // Item for custom split
    @State var editingItemName = ""
    @State var editingItemPrice = ""
    @State var editingItemQuantity = 1

    // Split Mode for Step 3
    @State var splitMode: BillSplitMode = .bagiRata
    @State var participantAmounts: [String: String] = [:]  // participantID -> amount string

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
        // Sum of all item prices with quantities plus tax, service, rounding, minus discount
        let itemsTotal = items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
        return itemsTotal + taxAmount + serviceCharge + rounding - discount
    }

    var isStep3Valid: Bool {
        // Valid if all items have at least one participant selected AND total matches AND all participants have items
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
        abs(bagiRataTotalInput - totalAmount) < 1  // Allow Rp 1 tolerance
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
            total: totalAmount,
            participantIDs: activeParticipants.map { $0.id }
        )
        for (participantID, amount) in distributed {
            participantAmounts[participantID] = amount
        }
    }

    func initializeParticipantAmounts() {
        for participant in activeParticipants {
            if participantAmounts[participant.id] == nil {
                participantAmounts[participant.id] = ""
            }
        }
    }

    // MARK: - Main Content View
    var mainContentView: some View {
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

            // Loading Overlay
            if showLoadingOverlay {
                loadingOverlayView
            }
        }
        .navigationTitle(source == .scan ? "Split dari Struk" : "Split Bill Baru")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .disabled(showLoadingOverlay)
        .navigationBarBackButtonHidden(showLoadingOverlay)
    }

    var body: some View {
        NavigationStack {
            mainContentView
                .onAppear(perform: setupForm)
                .onChange(of: totalAmount, perform: handleTotalAmountChange)
                .onChange(of: amountStr, perform: handleAmountStrChange)
                .onChange(of: taxAmountStr, perform: handleTaxAmountChange)
                .onChange(of: serviceChargeStr, perform: handleServiceChargeChange)
                .onChange(of: discountStr, perform: handleDiscountChange)
                .onChange(of: roundingStr, perform: handleRoundingChange)
                .onChange(of: showEditBankView, perform: handleBankViewDismiss)
        }
        .sheet(isPresented: $showAddGuest) {
            AddParticipantView(participants: $participants)
                .environmentObject(authVM)
                .environmentObject(friendsVM)
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
                // User stays on step 2, can change payer or go back
            }
            Button("Isi Rekening") {
                showEditBankView = true
            }
        } message: {
            Text("Orang yang bayar dulu belum punya nomor rekening. Silakan isi rekening terlebih dahulu.")
        }
        .alert("Berhasil", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Split bill berhasil disimpan!")
        }
        .tint(.brandPrimary)
    }

    // MARK: - Setup & Handlers
    func setupForm() {
            AppLog.debug("\n📋 [CreateSplitBillView] Initializing form...")
            AppLog.debug("   📸 Received receiptImage: \(receiptImage != nil)")
            AppLog.debug("   🔍 Received scannedResult: \(scannedResult != nil)")

            // Auto-fill from AI-parsed receipt data
            if let result = scannedResult, let parsed = result.parsedReceipt {
                AppLog.debug("✨ [CreateSplitBillView] Auto-filling from AI-parsed data:")

                // Fill bill name
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

                // Fill items for Step 3 with quantities (filter out items without price)
                if !parsed.items.isEmpty {
                    items = parsed.items.compactMap { receiptItem in
                        // Skip items without price (like plastic bags)
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
                    AppLog.debug("   📦 Items: \(items.count) items loaded for splitting (filtered from \(parsed.items.count))")

                    // If all items were filtered out (no valid prices), use total
                    if items.isEmpty {
                        items = [ItemEntry(name: "Total Tagihan", price: parsed.totalAmount, quantity: 1)]
                        AppLog.debug("   ⚠️ All items had no price, using total as single item")
                    }
                } else {
                    // If no items, create a single "Total" item
                    items = [ItemEntry(name: "Total Tagihan", price: parsed.totalAmount, quantity: 1)]
                    AppLog.debug("   ⚠️ No items found, using total as single item")
                }

                // Fill tax, service charge, and discount
                if let tax = parsed.taxAmount, tax > 0 {
                    taxAmountStr = String(Int(tax))
                    AppLog.debug("   💳 Tax: \(currency) \(tax)")
                }
                if let service = parsed.serviceCharge, service > 0 {
                    serviceChargeStr = String(Int(service))
                    AppLog.debug("   🍽️  Service: \(currency) \(service)")
                }
                if let disc = parsed.discount, disc > 0 {
                    discountStr = String(Int(disc))
                    AppLog.debug("   🎟️  Discount: \(currency) \(disc)")
                }
                if let round = parsed.rounding {
                    // Rounding can be negative
                    roundingStr = String(Int(round))
                    AppLog.debug("   🔄 Rounding: \(currency) \(round)")
                }

                // Fill date if available
                if let dateStr = parsed.date, let date = parseDate(dateStr) {
                    transactionDate = date
                    AppLog.debug("   📅 Date: \(dateStr)")
                }

                AppLog.debug("✅ [CreateSplitBillView] Auto-fill completed from AI data")
            } else if let result = scannedResult, let parsed = result.parsedAmount {
                // Fallback to basic OCR parsing
                amountStr = String(Int(parsed))
                AppLog.debug("⚠️ [CreateSplitBillView] Using basic OCR parsing (amount only): \(parsed)")

                // Create single item for manual split
                if totalAmount > 0 {
                    items = [ItemEntry(name: "Total Tagihan", price: totalAmount, quantity: 1)]
                }
            } else {
                AppLog.debug("ℹ️ [CreateSplitBillView] No scanned data, manual input mode")
            }

            // Ensure items exist for manual entry
            if items.isEmpty && totalAmount > 0 {
                items = [ItemEntry(name: "Total Tagihan", price: totalAmount)]
                AppLog.debug("   📦 Created default item for manual split")
            }

            if participants.isEmpty, let user = authVM.currentUser {
                let currentUserParticipant = ParticipantEntry(id: UUID().uuidString, uid: user.uid, name: user.displayName, isSelected: true)
                participants.append(currentUserParticipant)
                paidByParticipant = currentUserParticipant  // Default: current user is the payer
                AppLog.debug("👤 [CreateSplitBillView] Added current user as participant: \(user.displayName)")
                AppLog.debug("💳 [CreateSplitBillView] Default payer: \(user.displayName)")
            }

            AppLog.debug("📋 [CreateSplitBillView] Form initialized\n")
    }

    func handleTotalAmountChange(_ newAmount: Double) {
        let isSingleItem = items.count == 1
        let isDefaultItem = items.first?.name == "Total Tagihan"
        if isSingleItem && isDefaultItem {
            let newItem = ItemEntry(
                name: "Total Tagihan",
                price: newAmount,
                quantity: 1
            )
            items = [newItem]
        }
    }

    func handleAmountStrChange(_ newValue: String) {
        let formatted = newValue.formattedAsCurrency()
        if amountStr != formatted { amountStr = formatted }
    }

    func handleTaxAmountChange(_ newValue: String) {
        let formatted = newValue.formattedAsCurrency()
        if taxAmountStr != formatted { taxAmountStr = formatted }
    }

    func handleServiceChargeChange(_ newValue: String) {
        let formatted = newValue.formattedAsCurrency()
        if serviceChargeStr != formatted { serviceChargeStr = formatted }
    }

    func handleDiscountChange(_ newValue: String) {
        let formatted = newValue.formattedAsCurrency()
        if discountStr != formatted { discountStr = formatted }
    }

    func handleRoundingChange(_ newValue: String) {
        // Rounding can be negative, so we need special handling
        let isNegative = newValue.hasPrefix("-")
        let cleanedForFormat = newValue.replacingOccurrences(of: "-", with: "")
        let formatted = cleanedForFormat.formattedAsCurrency()
        let finalValue = isNegative ? "-\(formatted)" : formatted
        if roundingStr != finalValue { roundingStr = finalValue }
    }

    func handleBankViewDismiss(_ isShowing: Bool) {
        if !isShowing && step == 2 {
            if !checkBankAccountBeforeContinue() {
                withAnimation { step += 1 }
                AppLog.debug("✅ [CreateSplitBillView] Bank account filled - proceeding to step 3")
            }
        }
    }

    // MARK: - Save
    func saveBill() async {
        guard let user = authVM.currentUser else { return }

        AppLog.debug("💾 [CreateSplitBillView] Saving split bill...")
        AppLog.debug("   📝 Title: \(title)")
        AppLog.debug("   💰 amountStr: '\(amountStr)'")
        AppLog.debug("   💰 totalAmount: \(totalAmount)")
        AppLog.debug("   💰 calculatedTotal: \(calculatedTotal)")
        AppLog.debug("   📸 receiptImage (from scan): \(receiptImage != nil)")
        AppLog.debug("   📸 selectedImage (manual): \(selectedImage != nil)")

        // Upload receipt image if available (from scan or manual)
        var receiptURL: String? = nil
        let imageToUpload = receiptImage ?? selectedImage
        if let image = imageToUpload {
            AppLog.debug("📸 [CreateSplitBillView] Uploading receipt image...")

            // Show loading overlay
            await MainActor.run {
                loadingMessage = "Mengupload struk..."
                showLoadingOverlay = true
            }

            do {
                let response = try await FirebaseStorageService.shared.uploadImage(
                    image,
                    folder: "receipts",
                    fileName: "receipt_\(user.uid)_\(Int(Date().timeIntervalSince1970)).jpg"
                )
                receiptURL = response.downloadURL
                AppLog.debug("✅ [CreateSplitBillView] Receipt uploaded: \(receiptURL ?? "")")
            } catch {
                AppLog.debug("❌ [CreateSplitBillView] Failed to upload receipt: \(error.localizedDescription)")
                // Continue saving even if image upload fails
            }

            // Update loading message to saving data
            await MainActor.run {
                loadingMessage = "Menyimpan data..."
            }
        } else {
            // No receipt image, show overlay for saving only
            await MainActor.run {
                loadingMessage = "Menyimpan data..."
                showLoadingOverlay = true
            }
        }

        // Calculate amount for each participant based on split mode
        // For scan source, always use item-based; for manual, check splitMode
        let useItemBased = source == .scan || splitMode == .inputManual

        // Filter out participants with 0 amount
        let billParticipants: [SplitBillParticipant] = activeParticipants.compactMap { entry -> SplitBillParticipant? in
            let calculatedAmount: Double
            if useItemBased {
                calculatedAmount = calculateParticipantAmount(entry.id)
            } else {
                calculatedAmount = parseAmount(participantAmounts[entry.id] ?? "0")
            }
            AppLog.debug("   👤 \(entry.name): \(currency) \(calculatedAmount) [mode: \(useItemBased ? "Per Item" : "Bagi Rata")]")

            // Skip participants with 0 amount
            guard calculatedAmount > 0 else {
                AppLog.debug("   ⚠️ Skipping \(entry.name) - amount is 0")
                return nil
            }

            // Owner (payer) is automatically marked as paid - they paid for everyone
            let isOwnerParticipant = entry.uid == user.uid

            return SplitBillParticipant(
                id: UUID().uuidString,
                uid: entry.uid,
                displayName: entry.name,
                amount: calculatedAmount,
                isPaid: isOwnerParticipant
            )
        }

        // Build notes with breakdown (only include participants with amount > 0)
        var notesText = notes.isBlank ? "" : notes + "\n\n"
        notesText += "Tanggal: \(formatDate(transactionDate))\n\n"
        notesText += "Metode Pembagian: \(useItemBased ? "Per Item" : "Bagi Rata")\n\n"

        // Only show participants who owe money
        notesText += "Peserta Patungan:\n"
        let participantsWithAmount = activeParticipants.filter { participant in
            if useItemBased {
                return calculateParticipantAmount(participant.id) > 0
            } else {
                return parseAmount(participantAmounts[participant.id] ?? "0") > 0
            }
        }
        for participant in participantsWithAmount {
            let amount: Double
            if useItemBased {
                amount = calculateParticipantAmount(participant.id)
            } else {
                amount = parseAmount(participantAmounts[participant.id] ?? "0")
            }
            notesText += "• \(participant.name): \(currency) \(Int(amount))\n"
        }

        // Only show item breakdown for item-based mode
        if useItemBased {
            notesText += "\nPembagian Item:\n"
            for item in items {
                if !item.selectedParticipantIDs.isEmpty {
                    let participantNames = activeParticipants
                        .filter { item.selectedParticipantIDs.contains($0.id) }
                        .map { $0.name }
                        .joined(separator: ", ")
                    let qtyPrefix = item.quantity > 1 ? "\(item.quantity)x " : ""
                    let itemTotal = item.price * Double(item.quantity)
                    notesText += "• \(qtyPrefix)\(item.name) (\(currency) \(Int(item.price))"
                    if item.quantity > 1 {
                        notesText += " @ \(currency) \(Int(itemTotal))"
                    }
                    notesText += "): \(participantNames)\n"
                }
            }
        }

        // Only show additional charges for item-based mode
        if useItemBased && (taxAmount > 0 || serviceCharge > 0 || discount > 0) {
            notesText += "\nBiaya Tambahan:\n"
            if taxAmount > 0 {
                notesText += "• Pajak/PPN: \(currency) \(Int(taxAmount))\n"
            }
            if serviceCharge > 0 {
                notesText += "• Service Charge: \(currency) \(Int(serviceCharge))\n"
            }
            if discount > 0 {
                notesText += "• Diskon: -\(currency) \(Int(discount))\n"
            }
        }

        // Get payer info (fallback to current user if not set)
        let payerUID = paidByParticipant?.uid ?? user.uid
        let payerName = paidByParticipant?.name ?? user.displayName

        // Get bank account info (only for current user)
        var ownerBankAccount: String? = nil
        if payerUID == user.uid, let bankInfo = user.bankInfo {
            ownerBankAccount = "\(bankInfo.bankName) - \(bankInfo.accountNumber) a.n. \(bankInfo.accountName)"
        }

        _ = await splitBillVM.createSplitBill(
            ownerUID: user.uid,
            ownerName: user.displayName,
            ownerBankAccount: ownerBankAccount,
            paidByUID: payerUID,
            paidByName: payerName,
            title: title,
            totalAmount: totalAmount,
            currency: currency,
            participants: billParticipants,
            source: source,
            category: category,
            notes: notesText.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptURL: receiptURL
        )

        AppLog.debug("✅ [CreateSplitBillView] Split bill saved successfully!")

        // Hide loading overlay and show success alert
        await MainActor.run {
            showLoadingOverlay = false
            showSuccessAlert = true
        }
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

    // MARK: - Helper: Handle Next Step
    func handleNextStep() {
        // Check bank account before moving from step 2 to step 3
        if step == 2 {
            if checkBankAccountBeforeContinue() {
                // Show alert - user must fill bank account
                showBankAccountAlert = true
                AppLog.debug("⚠️ [CreateSplitBillView] Payer doesn't have bank account - showing alert")
                return
            }
        }

        // Proceed to next step
        withAnimation { step += 1 }
    }

    // MARK: - Helper: Check Bank Account Before Continue
    func checkBankAccountBeforeContinue() -> Bool {
        guard let payer = paidByParticipant else { return false }

        // Only check for current user (we don't have bank info for friends)
        if payer.uid == authVM.currentUser?.uid {
            // Check if current user has bank account info
            if authVM.currentUser?.bankInfo == nil ||
               authVM.currentUser?.bankInfo?.accountNumber.isEmpty == true {
                // Return true = needs to fill bank account
                return true
            } else {
                AppLog.debug("✅ [CreateSplitBillView] Payer has bank account: \(authVM.currentUser?.bankInfo?.accountNumber ?? "")")
                return false
            }
        }

        // For friends, we don't check (return false = can continue)
        return false
    }

}

// FlowLayout moved to TripLedger/Views/Shared/FlowLayout.swift
