import SwiftUI
import FirebaseCore

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
    
    // Step 1: Info
    @State private var title      = ""
    @State private var amountStr  = ""
    @State private var category   = ExpenseCategory.food
    @State private var notes      = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    
    private var amount: Double { Double(amountStr.replacingOccurrences(of: ",", with: "")) ?? 0 }
    private var isStep1Valid: Bool  { !title.isBlank && amount > 0 }
    
    // Step 2: Participants
    struct ParticipantEntry: Identifiable, Equatable {
        let id: String
        var uid: String
        var name: String
        var isSelected: Bool = true
    }
    @State private var participants: [ParticipantEntry] = []

    private var isStep2Valid: Bool { participants.contains(where: { $0.isSelected }) }

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
        items.reduce(0) { $0 + ($1.price * Double($1.quantity)) }
    }

    private var isStep3Valid: Bool {
        !items.isEmpty &&
        items.allSatisfy { !$0.selectedParticipantIDs.isEmpty } &&
        abs(calculatedTotal - amount) < 0.01 // Allow small floating point difference
    }

    private var isTotalMatching: Bool {
        abs(calculatedTotal - amount) < 0.01
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
            // Init Participants
            if participants.isEmpty {
                participants = trip.members.map { member in
                    ParticipantEntry(id: member.uid, uid: member.uid, name: member.displayName, isSelected: true)
                }
            }
            // Init Items with single default item
            if items.isEmpty && amount > 0 {
                items = [ItemEntry(name: "Total Pengeluaran", price: amount, quantity: 1)]
            }
        }
        .onChange(of: amountStr) { newValue in
            let formatted = newValue.formattedAsCurrency()
            if amountStr != formatted { amountStr = formatted }

            // Update default item if only one item exists
            if items.count == 1 && items.first?.name == "Total Pengeluaran" {
                items = [ItemEntry(name: "Total Pengeluaran", price: amount, quantity: 1)]
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
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
            // Receipt Image
            fieldSection("Foto Struk (Opsional)") {
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
            
            fieldSection("Nama Pengeluaran") {
                TLTextField(icon: "tag.fill", placeholder: "Cth: Makan Siang Bersama", text: $title)
            }
            
            fieldSection("Jumlah (\(trip.currency))") {
                TLTextField(icon: "banknote.fill", placeholder: "0", text: $amountStr, keyboardType: .decimalPad)
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
    
    // MARK: - Step 2: Pilih Anggota
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
    
    // MARK: - Save Logic
    private func saveExpense() async {
        guard let user = authVM.currentUser else { return }

        // Build splits based on item selections
        let finalSplits: [ExpenseSplit] = activeParticipants.compactMap { p in
            let splitAmount = calculateParticipantAmount(p.id)
            guard splitAmount > 0 else { return nil }

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

        // Get bank account info for current user (who is paying)
        var paidByBankAccount: String? = nil
        if let bankInfo = user.bankInfo {
            paidByBankAccount = "\(bankInfo.bankName) - \(bankInfo.accountNumber) a.n. \(bankInfo.accountName)"
        }

        await expenseVM.addExpense(
            tripID: trip.id ?? "",
            title: title,
            amount: calculatedTotal,
            currency: trip.currency,
            category: category,
            paidByUID: user.uid,
            paidByName: user.displayName,
            paidByBankAccount: paidByBankAccount,
            splitType: .custom,  // Always use custom for item-based
            members: trip.members,
            customSplits: finalSplits,
            notes: finalNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptImage: selectedImage
        )
        isAddingExpense = false
    }
    
    // MARK: - Helpers
    private func fieldSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary.opacity(0.6))
            content()
        }
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

// MARK: - Progress Header
struct ProgressHeader: View {
    let step: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= step ? Color.brandPrimary : Color.textPrimary.opacity(0.1))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
    }
}
