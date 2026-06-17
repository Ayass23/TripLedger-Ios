import SwiftUI
import FirebaseFirestore

struct CreateExpenseFromReceiptView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var expenseVM: ExpenseViewModel

    let trip: TripModel
    let scannedResult: OCRResult?
    let receiptImage: UIImage?
    @Binding var isAddingExpense: Bool

    // UI State
    @State private var step = 1
    @State private var showBankAccountAlert = false
    @State private var showEditBankView = false
    @StateObject private var profileVM = ProfileViewModel()

    // Step 1: Info Dasar
    @State private var title = ""
    @State private var amountStr = ""
    @State private var currency = "Rp"
    @State private var category = ExpenseCategory.food
    @State private var notes = ""
    @State private var transactionDate = Date()

    // Additional charges (from OCR)
    @State private var taxAmountStr = ""
    @State private var serviceChargeStr = ""
    @State private var discountStr = ""

    private var totalAmount: Double {
        let cleaned = amountStr
            .replacingOccurrences(of: ".", with: "")  // Remove thousand separator
            .replacingOccurrences(of: ",", with: "")  // Remove any commas
            .trimmingCharacters(in: .whitespaces)
        let amount = Double(cleaned) ?? 0
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
    struct ItemEntry: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var price: Double
        var quantity: Int = 1
        var selectedParticipantIDs: Set<String> = []
    }
    @State private var items: [ItemEntry] = []
    @State private var showEditItem: ItemEntry?
    @State private var showAddItem = false
    @State private var editingItemName = ""
    @State private var editingItemPrice = ""
    @State private var editingItemQuantity = 1

    private var activeParticipants: [ParticipantEntry] { participants.filter { $0.isSelected } }

    // Calculate how much each participant owes based on their item selections
    private func calculateParticipantAmount(_ participantID: String) -> Double {
        var itemTotal: Double = 0
        for item in items {
            if item.selectedParticipantIDs.contains(participantID) {
                let shareCount = item.selectedParticipantIDs.count
                if shareCount > 0 {
                    itemTotal += (item.price * Double(item.quantity)) / Double(shareCount)
                }
            }
        }
        return itemTotal
    }

    private var calculatedTotal: Double {
        let itemsTotal = items.reduce(0.0) { $0 + ($1.price * Double($1.quantity)) }
        // Add tax and service charge, subtract discount
        return itemsTotal + taxAmount + serviceCharge - discount
    }

    private var isStep3Valid: Bool {
        !items.isEmpty &&
        items.allSatisfy { !$0.selectedParticipantIDs.isEmpty } &&
        abs(calculatedTotal - totalAmount) < 0.01
    }

    private var isTotalMatching: Bool {
        abs(calculatedTotal - totalAmount) < 0.01
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
            print("\n📋 [CreateExpenseFromReceiptView] Initializing form...")
            print("   📸 Received receiptImage: \(receiptImage != nil)")
            print("   🔍 Received scannedResult: \(scannedResult != nil)")

            // Auto-fill from AI-parsed receipt data
            if let result = scannedResult, let parsed = result.parsedReceipt {
                print("✨ [CreateExpenseFromReceiptView] Auto-filling from AI-parsed data:")

                // Fill expense name
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

                // Fill date if available
                if let dateStr = parsed.date, let date = parseDate(dateStr) {
                    transactionDate = date
                    print("   📅 Date: \(dateStr)")
                }

                // Fill additional charges
                if let tax = parsed.taxAmount, tax > 0 {
                    taxAmountStr = String(Int(tax))
                    print("   🧾 Tax: \(tax)")
                }
                if let service = parsed.serviceCharge, service > 0 {
                    serviceChargeStr = String(Int(service))
                    print("   🔔 Service Charge: \(service)")
                }
                if let disc = parsed.discount, disc > 0 {
                    discountStr = String(Int(disc))
                    print("   🎫 Discount: \(disc)")
                }

                // Fill items for Step 3 (filter out items without price)
                if !parsed.items.isEmpty {
                    items = parsed.items.compactMap { receiptItem in
                        // Skip items without price
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
                    print("   📦 Items: \(items.count) items loaded (filtered from \(parsed.items.count))")
                } else {
                    // If no items, create a single "Total" item
                    items = [ItemEntry(name: "Total Pengeluaran", price: parsed.totalAmount, quantity: 1)]
                    print("   ⚠️ No items found, using total as single item")
                }

                print("✅ [CreateExpenseFromReceiptView] Auto-fill completed from AI data")
            } else if let result = scannedResult, let parsed = result.parsedAmount {
                // Fallback to basic OCR parsing
                amountStr = String(Int(parsed))
                print("⚠️ [CreateExpenseFromReceiptView] Using basic OCR parsing (amount only): \(parsed)")

                // Create single item for manual split
                if totalAmount > 0 {
                    items = [ItemEntry(name: "Total Pengeluaran", price: totalAmount, quantity: 1)]
                }
            } else {
                print("ℹ️ [CreateExpenseFromReceiptView] No scanned data")
            }

            // Ensure items exist
            if items.isEmpty && totalAmount > 0 {
                items = [ItemEntry(name: "Total Pengeluaran", price: totalAmount)]
                print("   📦 Created default item for manual split")
            }

            // Init Participants from trip members
            if participants.isEmpty {
                participants = trip.members.map { member in
                    ParticipantEntry(id: member.uid, uid: member.uid, name: member.displayName, isSelected: true)
                }
                // Set default payer to current user, or first participant if current user not found
                if let currentUser = authVM.currentUser {
                    paidByParticipant = participants.first(where: { $0.uid == currentUser.uid })
                }
                // Fallback to first participant if payer still not set
                if paidByParticipant == nil {
                    paidByParticipant = participants.first
                }
                print("👥 [CreateExpenseFromReceiptView] Loaded \(participants.count) participants from trip")
            }

            print("📋 [CreateExpenseFromReceiptView] Form initialized\n")
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
            if let result = scannedResult {
                scanResultBanner(result)
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

            // Total Pengeluaran
            VStack(alignment: .leading, spacing: 10) {
                Text("Total Pengeluaran (\(currency))")
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

                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.brandAccent.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "note.text")
                            .font(.system(size: 18))
                            .foregroundColor(.brandAccent)
                    }

                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
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
            Text("Siapa yang ikut patungan?")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

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
                Text("💡 Otomatis terdeteksi dari struk. Kamu bisa edit atau hapus jika salah.")
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.5))
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
                                Text(participantAmount.toCurrency(symbol: currency))
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
                        Task { await saveExpense() }
                    } label: {
                        Text(expenseVM.isLoading ? "Menyimpan..." : "Simpan Pengeluaran")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isStep3Valid ? LinearGradient.brandGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                    .disabled(!isStep3Valid || expenseVM.isLoading)
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

    // MARK: - Save
    private func saveExpense() async {
        guard let user = authVM.currentUser else { return }

        print("💾 [CreateExpenseFromReceiptView] Saving expense...")
        print("   📝 Title: \(title)")
        print("   💰 Amount: \(currency) \(calculatedTotal)")
        print("   📸 receiptImage available: \(receiptImage != nil)")

        // Build splits based on item selections
        let finalSplits: [ExpenseSplit] = activeParticipants.compactMap { p in
            let splitAmount = calculateParticipantAmount(p.id)
            guard splitAmount > 0 else { return nil }

            print("   👤 \(p.name): \(currency) \(splitAmount)")
            return ExpenseSplit(
                id: p.id,
                uid: p.uid,
                displayName: p.name,
                amount: splitAmount,
                items: []
            )
        }

        // Build notes with item breakdown
        var finalNotes = notes.isBlank ? "" : notes + "\n\n"
        finalNotes += "Tanggal: \(formatDate(transactionDate))\n\n"
        finalNotes += "Pembagian Item:\n"
        for item in items {
            if !item.selectedParticipantIDs.isEmpty {
                let participantNames = activeParticipants
                    .filter { item.selectedParticipantIDs.contains($0.id) }
                    .map { $0.name }
                    .joined(separator: ", ")
                let qtyPrefix = item.quantity > 1 ? "\(item.quantity)x " : ""
                let itemTotal = item.price * Double(item.quantity)
                finalNotes += "• \(qtyPrefix)\(item.name) (\(currency) \(Int(item.price))"
                if item.quantity > 1 {
                    finalNotes += " @ \(currency) \(Int(itemTotal))"
                }
                finalNotes += "): \(participantNames)\n"
            }
        }

        // Get payer info
        guard let payer = paidByParticipant else { return }

        // Get bank account info for payer (only if payer is current user)
        var paidByBankAccount: String? = nil
        if payer.uid == user.uid, let bankInfo = user.bankInfo {
            paidByBankAccount = "\(bankInfo.bankName) - \(bankInfo.accountNumber) a.n. \(bankInfo.accountName)"
        }

        await expenseVM.addExpense(
            tripID: trip.id ?? "",
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
            receiptImage: receiptImage
        )

        print("✅ [CreateExpenseFromReceiptView] Expense saved successfully!")
        isAddingExpense = false
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
