import SwiftUI
import FirebaseFirestore

struct CreateSplitBillView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM:      AuthViewModel
    @EnvironmentObject private var splitBillVM: SplitBillViewModel
    @EnvironmentObject private var friendsVM:   FriendsViewModel
    @StateObject private var profileVM = ProfileViewModel()

    let source:        SplitBillSource
    let scannedResult: OCRResult?
    let receiptImage:  UIImage?

    // UI State
    @State private var step = 1
    
    // Step 1: Info Dasar
    @State private var title       = ""
    @State private var amountStr   = ""
    @State private var currency    = "Rp"
    @State private var category    = ExpenseCategory.food
    @State private var notes       = ""
    @State private var transactionDate = Date()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil

    // Additional charges (editable)
    @State private var taxAmountStr = ""
    @State private var serviceChargeStr = ""
    @State private var discountStr = ""

    private var totalAmount: Double {
        let cleaned = amountStr
            .replacingOccurrences(of: ".", with: "")  // Remove thousand separator
            .replacingOccurrences(of: ",", with: "")  // Remove any commas
            .trimmingCharacters(in: .whitespaces)
        let amount = Double(cleaned) ?? 0
        print("💰 [CreateSplitBillView] totalAmount computed: '\(amountStr)' → \(amount)")
        return amount
    }

    private var taxAmount: Double {
        let cleaned = taxAmountStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    private var serviceCharge: Double {
        let cleaned = serviceChargeStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    private var discount: Double {
        let cleaned = discountStr
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    private var isStep1Valid: Bool { !title.isBlank && totalAmount > 0 }

    // Step 2: Participants
    @State private var participants: [ParticipantEntry] = []
    @State private var showAddGuest = false
    @State private var paidByParticipant: ParticipantEntry?  // Who paid first (default: current user)

    // Bank Account Check
    @State private var showBankAccountAlert = false
    @State private var showEditBankView = false

    private var isStep2Valid: Bool { participants.contains(where: { $0.isSelected }) }

    // Loading overlay
    @State private var showLoadingOverlay = false
    @State private var loadingMessage = ""

    // Step 3: Item-based Splits
    struct ItemEntry: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var price: Double
        var quantity: Int = 1
        var selectedParticipantIDs: Set<String> = []  // IDs of participants who bought this item
    }
    @State private var items: [ItemEntry] = []
    @State private var showEditItem: ItemEntry?  // Item being edited
    @State private var showAddItem = false  // Show add item sheet
    @State private var editingItemName = ""
    @State private var editingItemPrice = ""
    @State private var editingItemQuantity = 1

    private var activeParticipants: [ParticipantEntry] { participants.filter { $0.isSelected } }

    // Calculate how much each participant owes based on their item selections
    private func calculateParticipantAmount(_ participantID: String) -> Double {
        var itemTotal: Double = 0

        // Calculate items
        for item in items {
            if item.selectedParticipantIDs.contains(participantID) {
                let shareCount = item.selectedParticipantIDs.count
                if shareCount > 0 {
                    itemTotal += (item.price * Double(item.quantity)) / Double(shareCount)
                }
            }
        }

        // Add proportional tax, service charge, and subtract proportional discount
        let itemsTotal = items.reduce(0.0) { $0 + ($1.price * Double($1.quantity)) }
        if itemsTotal > 0 {
            let proportion = itemTotal / itemsTotal
            itemTotal += (taxAmount + serviceCharge) * proportion
            itemTotal -= discount * proportion
        }

        return itemTotal
    }

    private var calculatedTotal: Double {
        // Sum of all item prices with quantities plus tax and service minus discount
        let itemsTotal = items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
        return itemsTotal + taxAmount + serviceCharge - discount
    }

    private var isStep3Valid: Bool {
        // Valid if all items have at least one participant selected AND total matches
        !items.isEmpty &&
        items.allSatisfy { !$0.selectedParticipantIDs.isEmpty } &&
        abs(calculatedTotal - totalAmount) < 0.01
    }

    private var isTotalMatching: Bool {
        abs(calculatedTotal - totalAmount) < 0.01
    }

    // MARK: - Main Content View
    private var mainContentView: some View {
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
        .sheet(isPresented: $showEditBankView) {
            NavigationStack {
                EditBankView(profileVM: profileVM)
                    .environmentObject(authVM)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
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
        .tint(.brandPrimary)
    }

    // MARK: - Setup & Handlers
    private func setupForm() {
            print("\n📋 [CreateSplitBillView] Initializing form...")
            print("   📸 Received receiptImage: \(receiptImage != nil)")
            print("   🔍 Received scannedResult: \(scannedResult != nil)")

            // Auto-fill from AI-parsed receipt data
            if let result = scannedResult, let parsed = result.parsedReceipt {
                print("✨ [CreateSplitBillView] Auto-filling from AI-parsed data:")

                // Fill bill name
                title = parsed.billName
                print("   📝 Title: \(parsed.billName)")

                // Fill total amount
                amountStr = String(Int(parsed.totalAmount))
                print("   💰 Amount: \(parsed.currency) \(parsed.totalAmount)")

                // Fill currency
                currency = parsed.currency

                // Fill category if available
                if let cat = parsed.category {
                    if let expenseCategory = ExpenseCategory.fromString(cat) {
                        category = expenseCategory
                        print("   🏷️  Category: \(cat) → \(expenseCategory.displayName)")
                    } else {
                        print("   ⚠️ Category '\(cat)' not mapped, using default")
                    }
                }

                // Fill items for Step 3 with quantities (filter out items without price)
                if !parsed.items.isEmpty {
                    items = parsed.items.compactMap { receiptItem in
                        // Skip items without price (like plastic bags)
                        guard let price = receiptItem.price, price > 0 else {
                            print("   ⚠️ Skipping item '\(receiptItem.name)' - no price")
                            return nil
                        }
                        return ItemEntry(
                            name: receiptItem.name,
                            price: price,
                            quantity: receiptItem.quantity ?? 1
                        )
                    }
                    print("   📦 Items: \(items.count) items loaded for splitting (filtered from \(parsed.items.count))")

                    // If all items were filtered out (no valid prices), use total
                    if items.isEmpty {
                        items = [ItemEntry(name: "Total Tagihan", price: parsed.totalAmount, quantity: 1)]
                        print("   ⚠️ All items had no price, using total as single item")
                    }
                } else {
                    // If no items, create a single "Total" item
                    items = [ItemEntry(name: "Total Tagihan", price: parsed.totalAmount, quantity: 1)]
                    print("   ⚠️ No items found, using total as single item")
                }

                // Fill tax, service charge, and discount
                if let tax = parsed.taxAmount, tax > 0 {
                    taxAmountStr = String(Int(tax))
                    print("   💳 Tax: \(currency) \(tax)")
                }
                if let service = parsed.serviceCharge, service > 0 {
                    serviceChargeStr = String(Int(service))
                    print("   🍽️  Service: \(currency) \(service)")
                }
                if let disc = parsed.discount, disc > 0 {
                    discountStr = String(Int(disc))
                    print("   🎟️  Discount: \(currency) \(disc)")
                }

                // Fill date if available
                if let dateStr = parsed.date, let date = parseDate(dateStr) {
                    transactionDate = date
                    print("   📅 Date: \(dateStr)")
                }

                print("✅ [CreateSplitBillView] Auto-fill completed from AI data")
            } else if let result = scannedResult, let parsed = result.parsedAmount {
                // Fallback to basic OCR parsing
                amountStr = String(Int(parsed))
                print("⚠️ [CreateSplitBillView] Using basic OCR parsing (amount only): \(parsed)")

                // Create single item for manual split
                if totalAmount > 0 {
                    items = [ItemEntry(name: "Total Tagihan", price: totalAmount, quantity: 1)]
                }
            } else {
                print("ℹ️ [CreateSplitBillView] No scanned data, manual input mode")
            }

            // Ensure items exist for manual entry
            if items.isEmpty && totalAmount > 0 {
                items = [ItemEntry(name: "Total Tagihan", price: totalAmount)]
                print("   📦 Created default item for manual split")
            }

            if participants.isEmpty, let user = authVM.currentUser {
                let currentUserParticipant = ParticipantEntry(id: user.uid, uid: user.uid, name: user.displayName, isSelected: true)
                participants.append(currentUserParticipant)
                paidByParticipant = currentUserParticipant  // Default: current user is the payer
                print("👤 [CreateSplitBillView] Added current user as participant: \(user.displayName)")
                print("💳 [CreateSplitBillView] Default payer: \(user.displayName)")
            }

            print("📋 [CreateSplitBillView] Form initialized\n")
    }

    private func handleTotalAmountChange(_ newAmount: Double) {
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

    private func handleAmountStrChange(_ newValue: String) {
        let formatted = newValue.formattedAsCurrency()
        if amountStr != formatted { amountStr = formatted }
    }

    private func handleTaxAmountChange(_ newValue: String) {
        let formatted = newValue.formattedAsCurrency()
        if taxAmountStr != formatted { taxAmountStr = formatted }
    }

    private func handleServiceChargeChange(_ newValue: String) {
        let formatted = newValue.formattedAsCurrency()
        if serviceChargeStr != formatted { serviceChargeStr = formatted }
    }

    private func handleDiscountChange(_ newValue: String) {
        let formatted = newValue.formattedAsCurrency()
        if discountStr != formatted { discountStr = formatted }
    }

    private func handleBankViewDismiss(_ isShowing: Bool) {
        if !isShowing && step == 2 {
            if !checkBankAccountBeforeContinue() {
                withAnimation { step += 1 }
                print("✅ [CreateSplitBillView] Bank account filled - proceeding to step 3")
            }
        }
    }

    // MARK: - Step 1: Info Dasar
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 24) {
            if source == .scan, let result = scannedResult {
                scanResultBanner(result)
            }

            // Foto Struk (only for manual input)
            if source == .manual {
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
                                .onTapGesture { showImagePicker = true }

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
                        Button { showImagePicker = true } label: {
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
            }

            // Nama Tagihan
            VStack(alignment: .leading, spacing: 10) {
                Text("Nama Tagihan")
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

            // Total Tagihan
            VStack(alignment: .leading, spacing: 10) {
                Text("Total Tagihan (\(currency))")
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

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.warningAmber.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundColor(.warningAmber)
                    }

                    DatePicker("", selection: $transactionDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.warningAmber.opacity(0.3), lineWidth: 1)
                )
            }

            // Kategori
            VStack(alignment: .leading, spacing: 10) {
                Text("Kategori")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                category = cat
                            }
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: cat.color).opacity(category == cat ? 0.2 : 0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: cat.color))
                                }
                                Text(cat.displayName)
                                    .font(AppFont.caption2())
                                    .foregroundColor(category == cat ? .textPrimary : .textPrimary.opacity(0.6))
                                    .fontWeight(category == cat ? .semibold : .regular)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(category == cat ? Color.cardFallback : Color.cardFallback.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(category == cat ? Color(hex: cat.color).opacity(0.5) : Color.borderSoft, lineWidth: category == cat ? 2 : 1)
                            )
                            .shadow(color: category == cat ? Color(hex: cat.color).opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
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
                            .fill(Color.brandAccent.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "note.text")
                            .font(.system(size: 18))
                            .foregroundColor(.brandAccent)
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
                        .stroke(notes.isEmpty ? Color.borderSoft : Color.brandAccent.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Step 2: Pilih Peserta
    private var step2View: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Siapa yang ikut patungan?")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
                Spacer()
                Button {
                    showAddGuest = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                        Text("Tambah")
                    }
                    .font(AppFont.caption())
                    .foregroundColor(.brandAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.brandAccent.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            
            VStack(spacing: 12) {
                ForEach($participants) { $participant in
                    Button {
                        participant.isSelected.toggle()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: participant.isSelected ? "checkmark.square.fill" : "square")
                                .foregroundColor(participant.isSelected ? .brandPrimary : .textPrimary.opacity(0.3))
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
                                    Text("Kamu (Pembuat)")
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
                                .stroke(participant.isSelected ? Color.brandPrimary : Color.borderSoft, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
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
                    ForEach(participants.filter { $0.isSelected }) { participant in
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
                            .background(paidByParticipant?.id == participant.id ? Color.brandPrimary.opacity(0.08) : Color.cardFallback)
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
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Siapa aja yang beli apa?")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
                Text("Centang item yang dibeli oleh masing-masing orang")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.6))
            }

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
                                // Show price breakdown clearly
                                if item.quantity > 1 {
                                    // Format: @ Rp 5,000 = Rp 15,000
                                    HStack(spacing: 4) {
                                        Text("@")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.textPrimary.opacity(0.5))
                                        Text(item.price.toCurrency(symbol: currency))
                                            .font(AppFont.caption())
                                            .foregroundColor(.brandPrimary)
                                        Text("=")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.textPrimary.opacity(0.5))
                                        Text((item.price * Double(item.quantity)).toCurrency(symbol: currency))
                                            .font(AppFont.caption())
                                            .foregroundColor(.brandPrimary)
                                            .fontWeight(.semibold)
                                    }
                                } else {
                                    // Single item: just show price
                                    Text(item.price.toCurrency(symbol: currency))
                                        .font(AppFont.caption())
                                        .foregroundColor(.brandPrimary)
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
                                            print("🔴 [Step3] Removed \(participant.name) from \(item.name)")
                                        } else {
                                            item.selectedParticipantIDs.insert(participant.id)
                                            print("✅ [Step3] Added \(participant.name) to \(item.name)")
                                        }
                                        print("   Current selections for \(item.name): \(item.selectedParticipantIDs.count) people")
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

            // Additional charges section (editable)
            VStack(alignment: .leading, spacing: 12) {
                Text("Biaya Tambahan (Opsional)")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                VStack(spacing: 10) {
                    // Tax
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.warningAmber.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "percent")
                                .font(.system(size: 16))
                                .foregroundColor(.warningAmber)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pajak / PPN")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            TextField("0", text: $taxAmountStr)
                                .keyboardType(.decimalPad)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                        }

                        Spacer()

                        if !taxAmountStr.isEmpty {
                            Button {
                                taxAmountStr = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(taxAmountStr.isEmpty ? Color.borderSoft : Color.warningAmber.opacity(0.3), lineWidth: 1)
                    )

                    // Service Charge
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.brandAccent.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.brandAccent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Service Charge")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            TextField("0", text: $serviceChargeStr)
                                .keyboardType(.decimalPad)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                        }

                        Spacer()

                        if !serviceChargeStr.isEmpty {
                            Button {
                                serviceChargeStr = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(serviceChargeStr.isEmpty ? Color.borderSoft : Color.brandAccent.opacity(0.3), lineWidth: 1)
                    )

                    // Discount
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.successGreen.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "tag.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.successGreen)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Diskon")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            TextField("0", text: $discountStr)
                                .keyboardType(.decimalPad)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                        }

                        Spacer()

                        if !discountStr.isEmpty {
                            Button {
                                discountStr = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(discountStr.isEmpty ? Color.borderSoft : Color.successGreen.opacity(0.3), lineWidth: 1)
                    )
                }

                // Info text
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 Otomatis terdeteksi dari struk. Kamu bisa edit atau hapus jika salah.")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.5))
                    Text("*Dibagi proporsional sesuai item yang dibeli")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.5))
                        .italic()
                }
            }

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Ringkasan Pembagian")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                VStack(spacing: 8) {
                    ForEach(activeParticipants) { participant in
                        let amount = calculateParticipantAmount(participant.id)
                        if amount > 0 {
                            HStack {
                                Text(participant.name)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Text(amount.toCurrency(symbol: currency))
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.brandPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Divider()

                    // Breakdown of calculation
                    let itemsOnlyTotal = items.reduce(0.0) { $0 + ($1.price * Double($1.quantity)) }

                    // Items subtotal
                    HStack {
                        Text("Total Items")
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                        Spacer()
                        Text(itemsOnlyTotal.toCurrency(symbol: currency))
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                    }
                    .padding(.vertical, 4)

                    // Tax (if any)
                    if taxAmount > 0 {
                        HStack {
                            Text("Pajak")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Spacer()
                            Text("+ " + taxAmount.toCurrency(symbol: currency))
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }
                        .padding(.vertical, 2)
                    }

                    // Service Charge (if any)
                    if serviceCharge > 0 {
                        HStack {
                            Text("Service Charge")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Spacer()
                            Text("+ " + serviceCharge.toCurrency(symbol: currency))
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }
                        .padding(.vertical, 2)
                    }

                    // Discount (if any)
                    if discount > 0 {
                        HStack {
                            Text("Diskon")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Spacer()
                            Text("- " + discount.toCurrency(symbol: currency))
                                .font(AppFont.caption())
                                .foregroundColor(.successGreen)
                        }
                        .padding(.vertical, 2)
                    }

                    // Show proportional distribution note if there are additional charges
                    if taxAmount > 0 || serviceCharge > 0 || discount > 0 {
                        Text("*Dibagi proporsional sesuai item yang dibeli")
                            .font(AppFont.caption2())
                            .foregroundColor(.textPrimary.opacity(0.5))
                            .italic()
                            .padding(.top, 4)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Total Tagihan (from step 1)
                    HStack {
                        Text("Total Tagihan")
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                        Spacer()
                        Text(totalAmount.toCurrency(symbol: currency))
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                    }
                    .padding(.vertical, 4)

                    // Total Calculated (items + tax + service - discount)
                    HStack {
                        Text("Total Terhitung")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(calculatedTotal.toCurrency(symbol: currency))
                            .font(AppFont.headline())
                            .foregroundColor(isTotalMatching ? .brandPrimary : .errorRed)
                    }

                    // Warning if not matching
                    if !isTotalMatching {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("Total terhitung harus sama dengan total tagihan")
                                .font(AppFont.caption2())
                        }
                        .foregroundColor(.errorRed)
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
                    Button {
                        Task { await saveBill() }
                    } label: {
                        Text(splitBillVM.isLoading ? "Menyimpan..." : "Simpan Split Bill")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isStep3Valid ? LinearGradient.brandGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                    .disabled(!isStep3Valid || splitBillVM.isLoading)
                }
            }
            .padding(20)
            .background(Color.baseFallback)
        }
    }

    // MARK: - Scan Result Banner
    private func scanResultBanner(_ result: OCRResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.successGreen)
            VStack(alignment: .leading, spacing: 4) {
                Text("Struk berhasil di-scan")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)

                if let parsed = result.parsedReceipt {
                    // Show AI-parsed summary
                    HStack(spacing: 4) {
                        Text("\(parsed.billName) •")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.7))
                        Text("\(parsed.currency) \(Int(parsed.totalAmount).description)")
                            .font(AppFont.caption())
                            .foregroundColor(.successGreen)
                        if let cat = parsed.category {
                            Text("• \(cat)")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.7))
                        }
                    }

                    if !parsed.items.isEmpty {
                        Text("\(parsed.items.count) item terdeteksi")
                            .font(AppFont.caption2())
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }
                } else if let amt = result.parsedAmount {
                    // Fallback to basic OCR parsing
                    Text("Total terdeteksi: \(Int(amt).description)")
                        .font(AppFont.caption())
                        .foregroundColor(.successGreen)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.successGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.successGreen.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Field Section
    private func fieldSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary.opacity(0.6))
            content()
        }
    }

    // MARK: - Loading Overlay
    private var loadingOverlayView: some View {
        ZStack {
            // Dark overlay background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                VStack(spacing: 8) {
                    Text(loadingMessage)
                        .font(AppFont.headline())
                        .foregroundColor(.white)

                    if let image = receiptImage {
                        let imageSizeInMB = Double(image.jpegData(compressionQuality: 0.8)?.count ?? 0) / 1_048_576
                        if imageSizeInMB > 0.1 {
                            Text(String(format: "%.1f MB", imageSizeInMB))
                                .font(AppFont.caption())
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding(40)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: showLoadingOverlay)
    }

    // MARK: - Save
    private func saveBill() async {
        guard let user = authVM.currentUser else { return }

        print("💾 [CreateSplitBillView] Saving split bill...")
        print("   📝 Title: \(title)")
        print("   💰 amountStr: '\(amountStr)'")
        print("   💰 totalAmount: \(totalAmount)")
        print("   💰 calculatedTotal: \(calculatedTotal)")
        print("   📸 receiptImage (from scan): \(receiptImage != nil)")
        print("   📸 selectedImage (manual): \(selectedImage != nil)")

        // Upload receipt image if available (from scan or manual)
        var receiptURL: String? = nil
        let imageToUpload = receiptImage ?? selectedImage
        if let image = imageToUpload {
            print("📸 [CreateSplitBillView] Uploading receipt image...")

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
                print("✅ [CreateSplitBillView] Receipt uploaded: \(receiptURL ?? "")")
            } catch {
                print("❌ [CreateSplitBillView] Failed to upload receipt: \(error.localizedDescription)")
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

        // Calculate amount for each participant based on their item selections
        // Filter out participants with 0 amount
        let billParticipants: [SplitBillParticipant] = activeParticipants.compactMap { entry -> SplitBillParticipant? in
            let calculatedAmount = calculateParticipantAmount(entry.id)
            print("   👤 \(entry.name): \(currency) \(calculatedAmount)")

            // Skip participants with 0 amount
            guard calculatedAmount > 0 else {
                print("   ⚠️ Skipping \(entry.name) - amount is 0")
                return nil
            }

            return SplitBillParticipant(
                id: entry.id,
                uid: entry.uid,
                displayName: entry.name,
                amount: calculatedAmount,
                isPaid: false
            )
        }

        // Build notes with item breakdown (only include participants with amount > 0)
        var notesText = notes.isBlank ? "" : notes + "\n\n"
        notesText += "Tanggal: \(formatDate(transactionDate))\n\n"

        // Only show participants who owe money
        notesText += "Peserta Patungan:\n"
        let participantsWithAmount = activeParticipants.filter { calculateParticipantAmount($0.id) > 0 }
        for participant in participantsWithAmount {
            let amount = calculateParticipantAmount(participant.id)
            notesText += "• \(participant.name): \(currency) \(Int(amount))\n"
        }

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

        if taxAmount > 0 || serviceCharge > 0 || discount > 0 {
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

        print("✅ [CreateSplitBillView] Split bill saved successfully!")

        // Hide loading overlay
        await MainActor.run {
            showLoadingOverlay = false
        }

        dismiss()
    }

    // MARK: - Helper: Parse Date
    private func parseDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateStr)
    }

    // MARK: - Helper: Format Date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }

    // MARK: - Helper: Handle Next Step
    private func handleNextStep() {
        // Check bank account before moving from step 2 to step 3
        if step == 2 {
            if checkBankAccountBeforeContinue() {
                // Show alert - user must fill bank account
                showBankAccountAlert = true
                print("⚠️ [CreateSplitBillView] Payer doesn't have bank account - showing alert")
                return
            }
        }

        // Proceed to next step
        withAnimation { step += 1 }
    }

    // MARK: - Helper: Check Bank Account Before Continue
    private func checkBankAccountBeforeContinue() -> Bool {
        guard let payer = paidByParticipant else { return false }

        // Only check for current user (we don't have bank info for friends)
        if payer.uid == authVM.currentUser?.uid {
            // Check if current user has bank account info
            if authVM.currentUser?.bankInfo == nil ||
               authVM.currentUser?.bankInfo?.accountNumber.isEmpty == true {
                // Return true = needs to fill bank account
                return true
            } else {
                print("✅ [CreateSplitBillView] Payer has bank account: \(authVM.currentUser?.bankInfo?.accountNumber ?? "")")
                return false
            }
        }

        // For friends, we don't check (return false = can continue)
        return false
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
                            items[index].price = Double(editingItemPrice.replacingOccurrences(of: ",", with: "")) ?? 0
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
                            price: Double(editingItemPrice.replacingOccurrences(of: ",", with: "")) ?? 0,
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
}

// FlowLayout moved to TripLedger/Views/Shared/FlowLayout.swift
