import SwiftUI
import Kingfisher

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
                        AppLog.debug("👉 [ParticipantRow] Tombol 'Batal Lunas' diklik untuk: \(participant.displayName)")
                        
                        // Optimistic UI Update
                        if let idx = bill.participants.firstIndex(where: { $0.id == participant.id }) {
                            bill.participants[idx].isPaid = false
                            bill.status = .active
                            AppLog.debug("⚡️ [ParticipantRow] Optimistic Update: \(participant.displayName) dikembalikan ke Belum Lunas.")
                        }
                        
                        Task {
                            if let id = bill.id {
                                AppLog.debug("🚀 [ParticipantRow] Memanggil splitBillVM.toggleParticipantPaidStatus (isPaid: false)...")
                                await splitBillVM.toggleParticipantPaidStatus(billID: id, participantID: participant.id, isPaid: false)
                            } else {
                                AppLog.debug("🚨 [ParticipantRow] ERROR: bill.id KOSONG!")
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
                        AppLog.debug("👉 [ParticipantRow] Tombol 'Tandai Lunas' diklik untuk: \(participant.displayName)")
                        
                        // Optimistic UI Update
                        if let idx = bill.participants.firstIndex(where: { $0.id == participant.id }) {
                            bill.participants[idx].isPaid = true
                            AppLog.debug("⚡️ [ParticipantRow] Optimistic Update: \(participant.displayName) isPaid diset jadi TRUE di state View lokal.")
                            
                            if bill.participants.allSatisfy({ $0.isPaid }) {
                                bill.status = .settled
                                AppLog.debug("⚡️ [ParticipantRow] Optimistic Update: Semua sudah lunas, status Tagihan lokal diset jadi SETTLED.")
                            } else {
                                AppLog.debug("⚡️ [ParticipantRow] Optimistic Update: Belum semua lunas. Status Tagihan lokal masih ACTIVE.")
                            }
                        }
                        
                        Task {
                            if let id = bill.id {
                                AppLog.debug("🚀 [ParticipantRow] Memanggil splitBillVM.toggleParticipantPaidStatus (isPaid: true)...")
                                await splitBillVM.toggleParticipantPaidStatus(billID: id, participantID: participant.id, isPaid: true)
                            } else {
                                AppLog.debug("🚨 [ParticipantRow] ERROR: bill.id KOSONG!")
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
