import SwiftUI
import FirebaseFirestore

struct CreateSplitBillView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM:      AuthViewModel
    @EnvironmentObject private var splitBillVM: SplitBillViewModel
    @EnvironmentObject private var friendsVM:   FriendsViewModel

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
    @State private var taxAmount: Double = 0  // PPN/Pajak
    @State private var serviceCharge: Double = 0  // Service charge

    private var totalAmount: Double {
        let cleaned = amountStr
            .replacingOccurrences(of: ".", with: "")  // Remove thousand separator
            .replacingOccurrences(of: ",", with: "")  // Remove any commas
            .trimmingCharacters(in: .whitespaces)
        let amount = Double(cleaned) ?? 0
        print("💰 [CreateSplitBillView] totalAmount computed: '\(amountStr)' → \(amount)")
        return amount
    }
    private var isStep1Valid: Bool { !title.isBlank && totalAmount > 0 }

    // Step 2: Participants
    @State private var participants: [ParticipantEntry] = []
    @State private var showAddGuest = false

    private var isStep2Valid: Bool { participants.contains(where: { $0.isSelected }) }

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

        // Add proportional tax and service charge
        let itemsTotal = items.reduce(0.0) { $0 + ($1.price * Double($1.quantity)) }
        if itemsTotal > 0 {
            let proportion = itemTotal / itemsTotal
            itemTotal += (taxAmount + serviceCharge) * proportion
        }

        return itemTotal
    }

    private var calculatedTotal: Double {
        // Sum of all item prices with quantities plus tax and service
        let itemsTotal = items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
        return itemsTotal + taxAmount + serviceCharge
    }

    private var isStep3Valid: Bool {
        // Valid if all items have at least one participant selected
        !items.isEmpty && items.allSatisfy { !$0.selectedParticipantIDs.isEmpty }
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
            .navigationTitle(source == .scan ? "Split dari Struk" : "Split Bill Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        }
        .onAppear {
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

                // Fill items for Step 3 with quantities
                if !parsed.items.isEmpty {
                    items = parsed.items.map { receiptItem in
                        ItemEntry(
                            name: receiptItem.name,
                            price: receiptItem.price,
                            quantity: receiptItem.quantity ?? 1
                        )
                    }
                    print("   📦 Items: \(parsed.items.count) items loaded for splitting")
                } else {
                    // If no items, create a single "Total" item
                    items = [ItemEntry(name: "Total Tagihan", price: parsed.totalAmount, quantity: 1)]
                    print("   ⚠️ No items found, using total as single item")
                }

                // Fill tax and service charge
                if let tax = parsed.taxAmount {
                    taxAmount = tax
                    print("   💳 Tax: \(currency) \(tax)")
                }
                if let service = parsed.serviceCharge {
                    serviceCharge = service
                    print("   🍽️  Service: \(currency) \(service)")
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
                participants.append(ParticipantEntry(id: user.uid, uid: user.uid, name: user.displayName, isSelected: true))
                print("👤 [CreateSplitBillView] Added current user as participant: \(user.displayName)")
            }

            print("📋 [CreateSplitBillView] Form initialized\n")
        }
        .onChange(of: totalAmount) { _ in
            // Update items if total changes and we only have the default item
            if items.count == 1 && items.first?.name == "Total Tagihan" {
                items = [ItemEntry(name: "Total Tagihan", price: totalAmount, quantity: 1)]
            }
        }
        .onChange(of: amountStr) { newValue in
            let formatted = newValue.formattedAsCurrency()
            if amountStr != formatted { amountStr = formatted }
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
    }

    // MARK: - Step 1: Info Dasar
    private var step1View: some View {
        VStack(alignment: .leading, spacing: 24) {
            if source == .scan, let result = scannedResult {
                scanResultBanner(result)
            }

            fieldSection("Nama Tagihan") {
                TLTextField(icon: "tag.fill", placeholder: "Cth: Makan Siang Bersama", text: $title)
            }

            fieldSection("Total Tagihan (\(currency))") {
                TLTextField(icon: "banknote.fill", placeholder: "0", text: $amountStr, keyboardType: .decimalPad)
            }

            fieldSection("Tanggal Transaksi") {
                DatePicker("", selection: $transactionDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.textPrimary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }

            fieldSection("Kategori") {
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
            
            fieldSection("Catatan (opsional)") {
                TLTextField(icon: "note.text", placeholder: "Tambahkan catatan...", text: $notes)
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
                                HStack(spacing: 4) {
                                    // Quantity badge
                                    if item.quantity > 1 {
                                        Text("\(item.quantity)x")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.brandAccent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.brandAccent.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    Text(item.name)
                                        .font(AppFont.subheadline())
                                        .foregroundColor(.textPrimary)
                                }
                                HStack(spacing: 4) {
                                    Text(item.price.toCurrency(symbol: currency))
                                        .font(AppFont.caption())
                                        .foregroundColor(.brandPrimary)
                                    if item.quantity > 1 {
                                        Text("(@\((item.price * Double(item.quantity)).toCurrency(symbol: currency)))")
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

            // Tax and Service Charge
            if taxAmount > 0 || serviceCharge > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Biaya Tambahan")
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary.opacity(0.6))

                    VStack(spacing: 8) {
                        if taxAmount > 0 {
                            HStack {
                                Text("Pajak / PPN")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary.opacity(0.7))
                                Spacer()
                                Text(taxAmount.toCurrency(symbol: currency))
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        if serviceCharge > 0 {
                            HStack {
                                Text("Service Charge")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary.opacity(0.7))
                                Spacer()
                                Text(serviceCharge.toCurrency(symbol: currency))
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.warningAmber.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

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

                    HStack {
                        Text("Total")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(calculatedTotal.toCurrency(symbol: currency))
                            .font(AppFont.headline())
                            .foregroundColor(.brandPrimary)
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
                        withAnimation { step += 1 }
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

    // MARK: - Save
    private func saveBill() async {
        guard let user = authVM.currentUser else { return }

        print("💾 [CreateSplitBillView] Saving split bill...")
        print("   📝 Title: \(title)")
        print("   💰 amountStr: '\(amountStr)'")
        print("   💰 totalAmount: \(totalAmount)")
        print("   💰 calculatedTotal: \(calculatedTotal)")
        print("   📸 receiptImage available: \(receiptImage != nil)")

        // Upload receipt image if available
        var receiptURL: String? = nil
        if let image = receiptImage {
            print("📸 [CreateSplitBillView] Uploading receipt image...")
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

        if taxAmount > 0 || serviceCharge > 0 {
            notesText += "\nBiaya Tambahan:\n"
            if taxAmount > 0 {
                notesText += "• Pajak/PPN: \(currency) \(Int(taxAmount))\n"
            }
            if serviceCharge > 0 {
                notesText += "• Service Charge: \(currency) \(Int(serviceCharge))\n"
            }
        }

        _ = await splitBillVM.createSplitBill(
            ownerUID: user.uid,
            ownerName: user.displayName,
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

// MARK: - FlowLayout Helper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
