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
        var uid: String?
        var name: String
        var isSelected: Bool = true
        var customAmountStr: String = ""
        
        var customAmount: Double { Double(customAmountStr.replacingOccurrences(of: ",", with: "")) ?? 0 }
    }
    @State private var participants: [ParticipantEntry] = []
    @State private var showAddGuest = false
    @State private var newGuestName = ""
    
    private var isStep2Valid: Bool { participants.contains(where: { $0.isSelected }) }
    
    // Step 3: Splits
    @State private var splitType = SplitType.equally
    
    private var activeParticipants: [ParticipantEntry] { participants.filter { $0.isSelected } }
    private var perPersonAmount: Double {
        guard !activeParticipants.isEmpty else { return 0 }
        return (amount / Double(activeParticipants.count) * 100).rounded() / 100
    }
    
    private var customTotal: Double {
        activeParticipants.reduce(0) { $0 + $1.customAmount }
    }
    
    private var isStep3Valid: Bool {
        if splitType == .equally { return true }
        // For custom, sum must equal total
        return abs(customTotal - amount) < 0.01
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
        }
        .onChange(of: amountStr) { newValue in
            let formatted = newValue.formattedAsCurrency()
            if amountStr != formatted { amountStr = formatted }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .alert("Tambah Tamu", isPresented: $showAddGuest) {
            TextField("Nama Tamu", text: $newGuestName)
            Button("Batal", role: .cancel) { newGuestName = "" }
            Button("Tambah") {
                if !newGuestName.isBlank {
                    participants.append(ParticipantEntry(id: UUID().uuidString, uid: nil, name: newGuestName.trimmed, isSelected: true))
                    newGuestName = ""
                }
            }
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
                        Text("Tamu")
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
                            // Checkbox
                            Image(systemName: participant.isSelected ? "checkmark.square.fill" : "square")
                                .foregroundColor(participant.isSelected ? .brandPrimary : .textPrimary.opacity(0.3))
                                .font(.system(size: 22))
                            
                            // Avatar placeholder
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
                                } else if participant.uid == nil {
                                    Text("Tamu (Non-App)")
                                        .font(AppFont.caption2())
                                        .foregroundColor(.warningAmber)
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
    
    // MARK: - Step 3: Splits
    private var step3View: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Total Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Pengeluaran")
                        .font(AppFont.footnote())
                        .foregroundColor(.textPrimary.opacity(0.6))
                    Text(amount.toCurrency(symbol: trip.currency))
                        .font(AppFont.title3())
                        .foregroundColor(.brandPrimary)
                }
                Spacer()
                Button {
                    step = 1
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.brandAccent)
                        .padding(8)
                        .background(Color.brandAccent.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(16)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            
            // Split Type Toggle
            Picker("Cara Bagi", selection: $splitType) {
                Text("Bagi Rata").tag(SplitType.equally)
                Text("Tentuin Nominal").tag(SplitType.custom)
            }
            .pickerStyle(.segmented)
            .onAppear {
                let primaryColor = UIColor(Color.brandPrimary)
                UISegmentedControl.appearance().selectedSegmentTintColor = primaryColor
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(Color.textPrimary.opacity(0.6))], for: .normal)
            }
            
            // Splits List
            VStack(spacing: 12) {
                ForEach($participants) { $participant in
                    if participant.isSelected {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandAccent.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Text(String(participant.name.prefix(1)).uppercased())
                                    .font(AppFont.caption())
                                    .foregroundColor(.brandAccent)
                            }
                            
                            Text(participant.name)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            if splitType == .equally {
                                Text(perPersonAmount.toCurrency(symbol: trip.currency))
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                            } else {
                                // Custom Input
                                TextField("0", text: $participant.customAmountStr)
                                    .keyboardType(.decimalPad)
                                    .font(AppFont.subheadline())
                                    .multilineTextAlignment(.trailing)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.textPrimary.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                                    .frame(width: 120)
                                    .onChange(of: participant.customAmountStr) { newValue in
                                        let formatted = newValue.formattedAsCurrency()
                                        if participant.customAmountStr != formatted {
                                            participant.customAmountStr = formatted
                                        }
                                    }
                            }
                        }
                        .padding(14)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                }
            }
            
            if splitType == .custom {
                let diff = amount - customTotal
                HStack {
                    Text(diff == 0 ? "Pas! ✅" : (diff > 0 ? "Kurang: \(diff.toCurrency(symbol: trip.currency))" : "Lebih: \(abs(diff).toCurrency(symbol: trip.currency))"))
                        .font(AppFont.subheadline())
                        .foregroundColor(diff == 0 ? .successGreen : .warningAmber)
                    Spacer()
                    Text("Total: \(customTotal.toCurrency(symbol: trip.currency))")
                        .font(AppFont.footnote())
                        .foregroundColor(.textPrimary.opacity(0.5))
                }
                .padding(.top, 8)
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
        
        let finalSplits: [ExpenseSplit] = activeParticipants.map { p in
            let splitAmount = splitType == .equally ? perPersonAmount : p.customAmount
            return ExpenseSplit(
                id: p.id,
                uid: p.uid ?? "guest_\(p.id)", // provide dummy uid for guests
                displayName: p.name,
                amount: splitAmount,
                items: []
            )
        }
        
        await expenseVM.addExpense(
            tripID: trip.id ?? "",
            title: title,
            amount: amount,
            currency: trip.currency,
            category: category,
            paidByUID: user.uid,
            paidByName: user.displayName,
            splitType: splitType,
            members: trip.members, // kept for backward compatibility if needed
            customSplits: finalSplits,
            notes: notes.isBlank ? nil : notes,
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
