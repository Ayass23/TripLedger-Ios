import SwiftUI

struct SplitBillDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var splitBillVM: SplitBillViewModel
    
    @State var bill: SplitBillModel
    
    @State private var showDeleteAlert = false
    @State private var isEditing = false
    @State private var showShareSheet = false
    @State private var showFullScreenReceipt = false
    @State private var pdfURL: URL?
    
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
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Generate and Share PDF
    private func generateAndSharePDF() {
        // Generate PDF using PDFGenerator
        if let url = PDFGenerator.generateSplitBillPDF(bill: bill) {
            pdfURL = url
            showShareSheet = true
        } else {
            print("❌ Failed to generate PDF")
        }
    }
}

// MARK: - Participant Row
struct ParticipantRow: View {
    let participant: SplitBillParticipant
    @Binding var bill: SplitBillModel
    let isOwner: Bool
    let isEditing: Bool
    let splitBillVM: SplitBillViewModel

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.brandAccent.opacity(0.12))
                    .frame(width: 40, height: 40)
                let initial = String(participant.displayName.prefix(1)).uppercased()
                Text(initial)
                    .font(AppFont.headline())
                    .foregroundColor(.brandAccent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.displayName)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                Text(participant.amount.toCurrency(symbol: bill.currency))
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.6))
            }
            
            Spacer()
            
            if participant.isPaid {
                if isOwner && isEditing {
                    Button {
                        print("👉 [ParticipantRow] Tombol 'Batal Lunas' diklik untuk: \(participant.displayName)")
                        
                        // Optimistic UI Update
                        if let idx = bill.participants.firstIndex(where: { $0.id == participant.id }) {
                            bill.participants[idx].isPaid = false
                            bill.status = .active
                            print("⚡️ [ParticipantRow] Optimistic Update: \(participant.displayName) dikembalikan ke Belum Lunas.")
                        }
                        
                        Task {
                            if let id = bill.id {
                                print("🚀 [ParticipantRow] Memanggil splitBillVM.toggleParticipantPaidStatus (isPaid: false)...")
                                await splitBillVM.toggleParticipantPaidStatus(billID: id, participantID: participant.id, isPaid: false)
                            } else {
                                print("🚨 [ParticipantRow] ERROR: bill.id KOSONG!")
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
                        print("👉 [ParticipantRow] Tombol 'Tandai Lunas' diklik untuk: \(participant.displayName)")
                        
                        // Optimistic UI Update
                        if let idx = bill.participants.firstIndex(where: { $0.id == participant.id }) {
                            bill.participants[idx].isPaid = true
                            print("⚡️ [ParticipantRow] Optimistic Update: \(participant.displayName) isPaid diset jadi TRUE di state View lokal.")
                            
                            if bill.participants.allSatisfy({ $0.isPaid }) {
                                bill.status = .settled
                                print("⚡️ [ParticipantRow] Optimistic Update: Semua sudah lunas, status Tagihan lokal diset jadi SETTLED.")
                            } else {
                                print("⚡️ [ParticipantRow] Optimistic Update: Belum semua lunas. Status Tagihan lokal masih ACTIVE.")
                            }
                        }
                        
                        Task {
                            if let id = bill.id {
                                print("🚀 [ParticipantRow] Memanggil splitBillVM.toggleParticipantPaidStatus (isPaid: true)...")
                                await splitBillVM.toggleParticipantPaidStatus(billID: id, participantID: participant.id, isPaid: true)
                            } else {
                                print("🚨 [ParticipantRow] ERROR: bill.id KOSONG!")
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

            // Expand/Collapse Button
            if !isEditing {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.textPrimary.opacity(0.3))
                        .font(.system(size: 20))
                }
            }
        }
        .padding(12)

        // Expandable Content - Item Breakdown
        if isExpanded && !isEditing {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Rincian Pembayaran")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.6))
                        .padding(.horizontal, 12)

                    if let notes = bill.notes {
                        let participantItems = extractParticipantItems(from: notes, participantName: participant.displayName)

                        if !participantItems.isEmpty {
                            // Items
                            ForEach(participantItems, id: \.self) { item in
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))
                                        .foregroundColor(.textPrimary.opacity(0.4))
                                    Text(item)
                                        .font(AppFont.caption())
                                        .foregroundColor(.textPrimary.opacity(0.7))
                                        .lineLimit(2)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                            }

                            // Tax and Service Charge
                            let charges = extractTaxAndServiceCharges(from: notes)
                            if charges.tax > 0 || charges.service > 0 {
                                let share = calculateTaxShare(participant: participant, totalTax: charges.tax, totalService: charges.service)

                                Divider()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)

                                Text("Biaya Tambahan:")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textPrimary.opacity(0.5))
                                    .padding(.horizontal, 12)

                                if share.tax > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 4))
                                            .foregroundColor(.warningAmber.opacity(0.6))
                                        Text("Pajak/PPN - \(bill.currency) \(formatAmount(share.tax))")
                                            .font(AppFont.caption())
                                            .foregroundColor(.textPrimary.opacity(0.7))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                }

                                if share.service > 0 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 4))
                                            .foregroundColor(.warningAmber.opacity(0.6))
                                        Text("Service Charge - \(bill.currency) \(formatAmount(share.service))")
                                            .font(AppFont.caption())
                                            .foregroundColor(.textPrimary.opacity(0.7))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                }

                                Divider()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)

                                HStack {
                                    Text("Total Bayar:")
                                        .font(AppFont.caption())
                                        .foregroundColor(.textPrimary.opacity(0.8))
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(participant.amount.toCurrency(symbol: bill.currency))
                                        .font(AppFont.caption())
                                        .foregroundColor(.brandPrimary)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 12)
                            }
                        } else {
                            Text("Tidak ada rincian item")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.5))
                                .italic()
                                .padding(.horizontal, 12)
                        }
                    } else {
                        Text("Tidak ada rincian item")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.5))
                            .italic()
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        }
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Helper: Extract Items for Participant with Details
    struct ItemDetail {
        let name: String
        let totalPrice: Double
        let sharePrice: Double
        let participantCount: Int
    }

    private func extractParticipantItems(from notes: String, participantName: String) -> [String] {
        let details = extractParticipantItemDetails(from: notes, participantName: participantName)
        return details.map { detail in
            let shareText = detail.participantCount > 1 ? " (bayar \(bill.currency) \(formatAmount(detail.sharePrice)))" : ""
            return "\(detail.name) - \(bill.currency) \(formatAmount(detail.totalPrice))\(shareText)"
        }
    }

    private func extractParticipantItemDetails(from notes: String, participantName: String) -> [ItemDetail] {
        var items: [ItemDetail] = []
        let lines = notes.components(separatedBy: .newlines)

        for line in lines {
            // Look for lines like: "• 2x Nasi Goreng (Rp 25000 @ Rp 50000): Andi, Budi"
            if line.contains("•") && line.contains(":") && !line.contains("Pajak") && !line.contains("Service") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let itemPart = parts[0].replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespaces)
                    let participantsPart = parts[1].trimmingCharacters(in: .whitespaces)

                    // Check if this participant is in the list
                    let participantNames = participantsPart.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

                    if participantNames.contains(participantName) {
                        // Parse item details
                        // Format: "2x Cheese Cake (Rp 30000 @ Rp 60000)"
                        let itemName = extractItemName(from: itemPart)
                        let totalPrice = extractTotalPrice(from: itemPart, currency: bill.currency)
                        let sharePrice = totalPrice / Double(participantNames.count)

                        items.append(ItemDetail(
                            name: itemName,
                            totalPrice: totalPrice,
                            sharePrice: sharePrice,
                            participantCount: participantNames.count
                        ))
                    }
                }
            }
        }

        return items
    }

    private func extractItemName(from itemPart: String) -> String {
        // Extract name before "("
        if let parenIndex = itemPart.firstIndex(of: "(") {
            let name = String(itemPart[..<parenIndex]).trimmingCharacters(in: .whitespaces)
            return name
        }
        return itemPart
    }

    private func extractTotalPrice(from itemPart: String, currency: String) -> Double {
        // Extract price from format: "... (Rp 25000 @ Rp 50000)" or "... (Rp 25000)"
        // We want the total price (after @) or the single price
        if let atIndex = itemPart.range(of: "@") {
            // Has "@", take the price after it
            let afterAt = String(itemPart[atIndex.upperBound...])
            return extractNumber(from: afterAt)
        } else {
            // No "@", take the price in parentheses
            if let openParen = itemPart.firstIndex(of: "("),
               let closeParen = itemPart.firstIndex(of: ")") {
                let priceStr = String(itemPart[openParen...closeParen])
                return extractNumber(from: priceStr)
            }
        }
        return 0
    }

    private func extractNumber(from text: String) -> Double {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(numbers) ?? 0
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }

    private func extractTaxAndServiceCharges(from notes: String) -> (tax: Double, service: Double) {
        var tax: Double = 0
        var service: Double = 0

        let lines = notes.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Pajak") || line.contains("PPN") {
                tax = extractNumber(from: line)
            } else if line.contains("Service") {
                service = extractNumber(from: line)
            }
        }

        return (tax, service)
    }

    private func calculateTaxShare(participant: SplitBillParticipant, totalTax: Double, totalService: Double) -> (tax: Double, service: Double) {
        // Calculate proportion based on participant's item amount (before tax)
        let participantItemAmount = participant.amount - (totalTax + totalService) * (participant.amount / bill.totalAmount)
        let totalItemsAmount = bill.totalAmount - totalTax - totalService

        if totalItemsAmount > 0 {
            let proportion = participantItemAmount / totalItemsAmount
            return (
                tax: totalTax * proportion,
                service: totalService * proportion
            )
        }

        return (0, 0)
    }
}

// MARK: - Full Screen Receipt View
struct FullScreenReceiptView: View {
    let imageURL: URL
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    .padding()
                }

                // Image with Zoom
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        // Limit scale
                                        if scale < 1.0 {
                                            withAnimation {
                                                scale = 1.0
                                                lastScale = 1.0
                                            }
                                        } else if scale > 5.0 {
                                            withAnimation {
                                                scale = 5.0
                                                lastScale = 5.0
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                // Double tap to reset zoom
                                withAnimation {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                    } else if phase.error != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.7))
                            Text("Gagal memuat foto struk")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }

                // Hint Text
                if scale == 1.0 {
                    Text("Pinch untuk zoom • Ketuk 2x untuk reset")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 16)
                }

                Spacer()
            }
        }
        .statusBar(hidden: true)
    }
}
