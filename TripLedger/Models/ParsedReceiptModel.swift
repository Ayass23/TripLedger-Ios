import Foundation

// MARK: - Parsed Receipt Model
struct ParsedReceiptModel: Codable {
    var billName: String              // Nama tagihan / merchant name
    var totalAmount: Double           // Total tagihan
    var currency: String              // Currency (e.g., "Rp", "USD")
    var category: String?             // Kategori (Food, Transport, etc.)
    var items: [ReceiptItem]          // Item-item dalam struk
    var date: String?                 // Tanggal transaksi (optional)
    var taxAmount: Double?            // Pajak (optional)
    var serviceCharge: Double?        // Service charge (optional)

    var description: String {
        var desc = "Tagihan: \(billName)\n"
        desc += "Total: \(currency) \(String(format: "%.0f", totalAmount))\n"
        if let cat = category {
            desc += "Kategori: \(cat)\n"
        }
        if !items.isEmpty {
            desc += "\nItem (\(items.count)):\n"
            for item in items {
                desc += "- \(item.name): \(currency) \(String(format: "%.0f", item.price))\n"
            }
        }
        return desc
    }
}

// MARK: - Receipt Item
struct ReceiptItem: Codable, Identifiable {
    var id: String { name + "\(price)" }
    var name: String
    var price: Double
    var quantity: Int?
}

// MARK: - AI Response Wrapper
struct AIReceiptResponse: Codable {
    var isReceipt: Bool?           // Validation: is this actually a receipt?
    var error: String?             // Error message if not a receipt
    var billName: String?
    var totalAmount: Double?
    var currency: String?
    var category: String?
    var items: [ReceiptItem]?
    var date: String?
    var taxAmount: Double?
    var serviceCharge: Double?
}
