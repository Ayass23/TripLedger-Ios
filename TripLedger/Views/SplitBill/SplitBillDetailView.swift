//  SplitBillDetailView.swift
//  Detail split bill: rincian item per peserta, status pembayaran, dan ekspor PDF.
//
import SwiftUI
import Kingfisher

struct SplitBillDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var splitBillVM: SplitBillViewModel
    
    @State var bill: SplitBillModel
    
    @State private var showDeleteAlert = false
    @State private var isEditing = false
    @State private var showPDFPreview = false
    @State private var showFullScreenReceipt = false
    @State private var pdfURL: URL?
    @State private var isGeneratingPDF = false
    
    private var isOwner: Bool {
        bill.ownerUID == authVM.currentUser?.uid
    }
    
    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()
            
            ScrollView {
                    VStack(spacing: 24) {
                        
                        // MARK: - Header
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppRadius.xl)
                                    .fill(Color.brandPrimary.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "scissors")
                                    .foregroundColor(.brandPrimary)
                                    .font(.system(size: 28))
                            }
                            
                            VStack(spacing: 4) {
                                Text(bill.title)
                                    .font(AppFont.title3())
                                    .foregroundColor(.textPrimary)
                                Text("dibuat oleh \(bill.ownerName)")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary.opacity(0.6))
                            }
                            
                            Text(bill.totalAmount.toCurrency(symbol: bill.currency))
                                .font(AppFont.title1())
                                .foregroundColor(.brandPrimary)
                        }
                        .padding(.top, 24)

                        // MARK: - Receipt Photo Thumbnail
                        if let receiptURL = bill.receiptURL, let url = URL(string: receiptURL) {
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

                        // MARK: - Status Banner
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Terkumpul")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary.opacity(0.8))
                                Spacer()
                                Text("\(bill.paidAmount.toCurrency(symbol: bill.currency)) / \(bill.totalAmount.toCurrency(symbol: bill.currency))")
                                    .font(AppFont.headline())
                                    .foregroundColor(.textPrimary)
                            }
                            
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.textPrimary.opacity(0.1))
                                        .frame(height: 8)
                                    
                                    let ratio = bill.totalAmount > 0 ? (bill.paidAmount / bill.totalAmount) : 0
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(bill.isFullySettled ? Color.successGreen : Color.brandPrimary)
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
                                ForEach(bill.participants) { participant in
                                    ParticipantRow(participant: participant, bill: $bill, isOwner: isOwner, isEditing: isEditing, splitBillVM: splitBillVM)
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
        .fullScreenCover(isPresented: $showFullScreenReceipt) {
            if let receiptURL = bill.receiptURL, let url = URL(string: receiptURL) {
                FullScreenReceiptView(imageURL: url, isPresented: $showFullScreenReceipt)
            }
        }
        .navigationTitle("Detail Tagihan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isOwner {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Hapus Tagihan", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(8)
                    }
                }
            }
        }
        .alert("Hapus Tagihan?", isPresented: $showDeleteAlert) {
            Button("Batal", role: .cancel) { }
            Button("Hapus", role: .destructive) {
                if let id = bill.id {
                    Task {
                        await splitBillVM.deleteSplitBill(billID: id)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Tagihan ini akan dihapus secara permanen.")
        }
        .onChange(of: splitBillVM.splitBills) { bills in
            if let updated = bills.first(where: { $0.id == bill.id }) {
                self.bill = updated
            }
        }
        .fullScreenCover(isPresented: $showPDFPreview) {
            if let url = pdfURL {
                PDFPreviewView(pdfURL: url, title: "Tagihan - \(bill.title)")
            }
        }
    }

    // MARK: - Generate and Share PDF
    private func generateAndSharePDF() {
        isGeneratingPDF = true

        Task {
            // Download receipt image if exists
            var receiptImage: UIImage? = nil
            if let receiptURL = bill.receiptURL, !receiptURL.isEmpty {
                receiptImage = await downloadImage(from: receiptURL)
            }

            // Generate PDF using PDFGenerator with pre-downloaded image
            if let url = PDFGenerator.generateSplitBillPDF(bill: bill, receiptImage: receiptImage) {
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


