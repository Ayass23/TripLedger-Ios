import Foundation

// MARK: - Bill Notes Builder
/// Membangun teks notes yang tersimpan ke database saat menyimpan expense/split bill.
/// Dipakai ketiga wizard (CreateSplitBillView, AddExpenseView, CreateExpenseFromReceiptView).
/// PENTING: format string di sini tersimpan permanen ke Firestore dan dibaca ulang
/// oleh halaman detail & generator PDF — jangan ubah template tanpa memeriksa pembacanya.
enum BillNotesBuilder {

    /// Baris "• 2x Nasi Goreng (Rp 15000 @ Rp 30000): Andi, Budi" per item.
    /// Caller menambahkan sendiri judul "Pembagian Item:\n" di depannya.
    static func itemBreakdownLines(
        items: [ItemEntry],
        participants: [(id: String, name: String)],
        currency: String
    ) -> String {
        var text = ""
        for item in items {
            if !item.selectedParticipantIDs.isEmpty {
                let participantNames = participants
                    .filter { item.selectedParticipantIDs.contains($0.id) }
                    .map { $0.name }
                    .joined(separator: ", ")
                let qtyPrefix = item.quantity > 1 ? "\(item.quantity)x " : ""
                let itemTotal = item.price * Double(item.quantity)
                text += "• \(qtyPrefix)\(item.name) (\(currency) \(Int(item.price))"
                if item.quantity > 1 {
                    text += " @ \(currency) \(Int(itemTotal))"
                }
                text += "): \(participantNames)\n"
            }
        }
        return text
    }

    /// Daftar item milik satu peserta ("2x Es Teh (1/3) - Rp 3.333"),
    /// disimpan ke field `items` pada ExpenseSplit.
    static func participantItemList(
        for participantID: String,
        items: [ItemEntry],
        currency: String
    ) -> [String] {
        var participantItems: [String] = []
        for item in items {
            if item.selectedParticipantIDs.contains(participantID) {
                let shareCount = item.selectedParticipantIDs.count
                let qtyPrefix = item.quantity > 1 ? "\(item.quantity)x " : ""

                // Check if custom split exists
                if let customSplit = item.customSplits[participantID], !item.customSplits.isEmpty {
                    let itemStr = "\(qtyPrefix)\(item.name) - \(customSplit.customAmount.toCurrency(symbol: currency))"
                    participantItems.append(itemStr)
                } else if shareCount > 1 {
                    // Shared item
                    let shareAmount = (item.price * Double(item.quantity)) / Double(shareCount)
                    let itemStr = "\(qtyPrefix)\(item.name) (1/\(shareCount)) - \(shareAmount.toCurrency(symbol: currency))"
                    participantItems.append(itemStr)
                } else {
                    // Solo item
                    let itemTotal = item.price * Double(item.quantity)
                    let itemStr = "\(qtyPrefix)\(item.name) - \(itemTotal.toCurrency(symbol: currency))"
                    participantItems.append(itemStr)
                }
            }
        }
        return participantItems
    }

    /// "BCA - 1234567890 a.n. Andi" — info rekening pembayar.
    static func bankAccountLine(_ bankInfo: BankInfo) -> String {
        "\(bankInfo.bankName) - \(bankInfo.accountNumber) a.n. \(bankInfo.accountName)"
    }
}
