import SwiftUI

struct ExpenseDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var expenseVM: ExpenseViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    
    @State var expense: ExpenseModel
    let currency: String
    
    @State private var showDeleteAlert = false
    @State private var isEditing = false
    @State private var showFullScreenReceipt = false
    @State private var showPDFPreview = false
    @State private var pdfURL: URL?

    private var isOwner: Bool {
        expense.paidByUID == authVM.currentUser?.uid
    }

    private var paidAmount: Double {
        expense.splits.filter { $0.isPaid == true }.reduce(0) { $0 + $1.amount }
    }

    private var isFullySettled: Bool {
        expense.splits.allSatisfy { $0.isPaid == true }
    }
    
    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Header (Category & Amount)
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppRadius.xl)
                                .fill(Color(hex: expense.category.color).opacity(0.12))
                                .frame(width: 64, height: 64)
                            Image(systemName: expense.category.icon)
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: expense.category.color))
                        }

                        VStack(spacing: 4) {
                            Text(expense.title)
                                .font(AppFont.title3())
                                .foregroundColor(.textPrimary)
                                .multilineTextAlignment(.center)
                            Text("dibayar oleh \(expense.paidByName)")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }

                        Text(expense.amount.toCurrency(symbol: currency))
                            .font(AppFont.title1())
                            .foregroundColor(.brandPrimary)
                    }
                    .padding(.top, 24)
                    
                    // MARK: - Receipt Photo Thumbnail
                    if let receiptURL = expense.receiptURL, let url = URL(string: receiptURL) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text.image")
                                    .font(.system(size: 16))
                                    .foregroundColor(.brandPrimary)
                                Text("Foto Struk")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary.opacity(0.7))
                                Spacer()
                            }
                            .padding(.horizontal, 20)

                            Button {
                                showFullScreenReceipt = true
                            } label: {
                                ZStack(alignment: .bottom) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 180)
                                                .frame(maxWidth: .infinity)
                                                .clipped()
                                        } else if phase.error != nil {
                                            HStack {
                                                Image(systemName: "exclamationmark.triangle")
                                                    .foregroundColor(.errorRed)
                                                Text("Gagal memuat foto struk")
                                                    .font(AppFont.caption())
                                                    .foregroundColor(.textPrimary.opacity(0.5))
                                            }
                                            .frame(height: 180)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.textPrimary.opacity(0.05))
                                        } else {
                                            ZStack {
                                                Color.textPrimary.opacity(0.05)
                                                    .frame(height: 180)
                                                ProgressView()
                                                    .tint(.brandPrimary)
                                            }
                                        }
                                    }

                                    // Overlay text - Centered
                                    HStack(spacing: 6) {
                                        Image(systemName: "hand.tap.fill")
                                            .font(.system(size: 14))
                                        Text("Klik untuk melihat struk")
                                            .font(AppFont.caption())
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            colors: [Color.black.opacity(0.7), Color.black.opacity(0.5)],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                }
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.md)
                                        .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Progress Bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Terkumpul")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.8))
                            Spacer()
                            Text("\(paidAmount.toCurrency(symbol: currency)) / \(expense.amount.toCurrency(symbol: currency))")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.textPrimary.opacity(0.1))
                                    .frame(height: 8)

                                let ratio = expense.amount > 0 ? (paidAmount / expense.amount) : 0
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isFullySettled ? Color.successGreen : Color.brandPrimary)
                                    .frame(width: max(0, proxy.size.width * CGFloat(ratio)), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 20)

                    // MARK: - Participants List
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Daftar Patungan")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary)
                            Spacer()
                            if isOwner {
                                Button {
                                    withAnimation {
                                        isEditing.toggle()
                                    }
                                } label: {
                                    Text(isEditing ? "Selesai" : "Edit")
                                        .font(AppFont.caption())
                                        .foregroundColor(isEditing ? .white : .brandPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isEditing ? Color.brandPrimary : Color.brandPrimary.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        VStack(spacing: 8) {
                            ForEach(expense.splits) { split in
                                ExpenseParticipantRow(
                                    split: split,
                                    expense: $expense,
                                    currency: currency,
                                    isOwner: isOwner,
                                    isEditing: isEditing,
                                    expenseVM: expenseVM
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // MARK: - Share Button
                    Button {
                        generateAndSharePDF()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20))
                            Text("Bagikan Tagihan")
                                .font(AppFont.subheadline())
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 40)
                    Spacer().frame(height: 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showPDFPreview) {
            if let url = pdfURL {
                PDFPreviewView(pdfURL: url, title: "Pengeluaran - \(expense.title)")
            }
        }
        .fullScreenCover(isPresented: $showFullScreenReceipt) {
            if let receiptURL = expense.receiptURL, let url = URL(string: receiptURL) {
                FullScreenReceiptView(imageURL: url, isPresented: $showFullScreenReceipt)
            }
        }
        .onChange(of: expenseVM.expenses) { expenses in
            if let updated = expenses.first(where: { $0.id == expense.id }) {
                self.expense = updated
            }
        }
        .navigationTitle("Detail Pengeluaran")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if expense.paidByUID == authVM.currentUser?.uid {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Hapus Pengeluaran", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(8)
                    }
                }
            }
        }
        .alert("Hapus Pengeluaran?", isPresented: $showDeleteAlert) {
            Button("Batal", role: .cancel) { }
            Button("Hapus", role: .destructive) {
                if let id = expense.id {
                    Task {
                        await expenseVM.deleteExpense(expenseID: id)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Pengeluaran ini akan dihapus secara permanen.")
        }
    }

    private func generateAndSharePDF() {
        // Generate PDF using PDFGenerator
        if let url = PDFGenerator.generateExpensePDF(
            expense: expense,
            currency: currency,
            paidAmount: paidAmount,
            isFullySettled: isFullySettled
        ) {
            pdfURL = url
            showPDFPreview = true
        } else {
            print("❌ Failed to generate PDF")
        }
    }
}

// MARK: - Expense Participant Row
struct ExpenseParticipantRow: View {
    let split: ExpenseSplit
    @Binding var expense: ExpenseModel
    let currency: String
    let isOwner: Bool
    let isEditing: Bool
    let expenseVM: ExpenseViewModel
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.brandAccent.opacity(0.12))
                    .frame(width: 40, height: 40)
                let initial = String(split.displayName.prefix(1)).uppercased()
                Text(initial)
                    .font(AppFont.headline())
                    .foregroundColor(.brandAccent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(split.displayName)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                Text(split.amount.toCurrency(symbol: currency))
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.6))
            }
            
            Spacer()
            
            if split.isPaid == true {
                if isOwner && isEditing {
                    Button {
                        // Optimistic UI Update
                        if let idx = expense.splits.firstIndex(where: { $0.id == split.id }) {
                            expense.splits[idx].isPaid = false
                        }
                        
                        Task {
                            if let id = expense.id {
                                await expenseVM.toggleExpenseSplitPaidStatus(expenseID: id, splitID: split.id, isPaid: false)
                            }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.errorRed)
                            .font(.system(size: 24))
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.successGreen)
                        .font(.system(size: 24))
                }
            } else {
                if isOwner {
                    Button {
                        // Optimistic UI Update
                        if let idx = expense.splits.firstIndex(where: { $0.id == split.id }) {
                            expense.splits[idx].isPaid = true
                        }
                        
                        Task {
                            if let id = expense.id {
                                await expenseVM.toggleExpenseSplitPaidStatus(expenseID: id, splitID: split.id, isPaid: true)
                            }
                        }
                    } label: {
                        Text("Tandai Lunas")
                            .font(AppFont.caption())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.brandPrimary)
                            .clipShape(Capsule())
                    }
                } else {
                    Text("Belum")
                        .font(AppFont.caption())
                        .foregroundColor(.warningAmber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.warningAmber.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}
