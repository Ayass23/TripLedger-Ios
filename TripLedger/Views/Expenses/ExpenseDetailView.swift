import SwiftUI
import Kingfisher

struct ExpenseDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var expenseVM: ExpenseViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    
    @State var expense: ExpenseModel
    let currency: String

    @State private var showDeleteAlert = false
    @State private var showFullScreenReceipt = false
    @State private var showPDFPreview = false
    @State private var pdfURL: URL?
    @State private var isGeneratingPDF = false

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
                                    KFImage(url)
                                        .placeholder {
                                            ZStack {
                                                Color.textPrimary.opacity(0.05)
                                                    .frame(height: 180)
                                                ProgressView()
                                                    .tint(.brandPrimary)
                                            }
                                        }
                                        .onFailure { _ in }
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 180)
                                        .frame(maxWidth: .infinity)
                                        .clipped()

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
                        Text("Daftar Patungan")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)

                        VStack(spacing: 8) {
                            ForEach(expense.splits) { split in
                                ExpenseParticipantRow(
                                    split: split,
                                    currency: currency
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
                            if isGeneratingPDF {
                                ProgressView()
                                    .tint(.white)
                                Text("Membuat PDF...")
                                    .font(AppFont.subheadline())
                                    .fontWeight(.medium)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                                Text("Bagikan Tagihan")
                                    .font(AppFont.subheadline())
                                    .fontWeight(.medium)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isGeneratingPDF ? Color.brandPrimary.opacity(0.7) : Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    .disabled(isGeneratingPDF)
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
        isGeneratingPDF = true

        Task {
            // Download receipt image if exists
            var receiptImage: UIImage? = nil
            if let receiptURL = expense.receiptURL, !receiptURL.isEmpty {
                receiptImage = await downloadImage(from: receiptURL)
            }

            // Generate PDF using PDFGenerator with pre-downloaded image
            if let url = PDFGenerator.generateExpensePDF(
                expense: expense,
                currency: currency,
                paidAmount: paidAmount,
                isFullySettled: isFullySettled,
                receiptImage: receiptImage
            ) {
                await MainActor.run {
                    pdfURL = url
                    showPDFPreview = true
                    isGeneratingPDF = false
                }
            } else {
                await MainActor.run {
                    AppLog.debug("❌ Failed to generate PDF")
                    isGeneratingPDF = false
                }
            }
        }
    }

    // MARK: - Download Image Async
    private func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else {
            AppLog.debug("❌ Invalid URL: \(urlString)")
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            AppLog.debug("❌ Failed to download image: \(error.localizedDescription)")
            return nil
        }
    }
}

