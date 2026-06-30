import Foundation

// MARK: - Parsed Receipt Model
struct ParsedReceiptModel: Codable {
    var billName: String              // Nama tagihan / merchant name
    var totalAmount: Double           // Total tagihan
    var currency: String              // Currency (e.g., "Rp", "USD")
    var category: String?             // Kategori (Food, Transport, etc.)
    var items: [ReceiptItem]          // Item-item dalam struk
    var date: String?                 // Tanggal transaksi (optional)
    var taxAmount: Double?            // Pajak/PPN/PB1 (optional)
    var serviceCharge: Double?        // Service charge (optional)
    var discount: Double?             // Diskon (optional)
    var rounding: Double?             // Pembulatan (optional) - bisa positif atau negatif

    var description: String {
        var desc = "Tagihan: \(billName)\n"
        desc += "Total: \(currency) \(String(format: "%.0f", totalAmount))\n"
        if let cat = category {
            desc += "Kategori: \(cat)\n"
        }
        if !items.isEmpty {
            desc += "\nItem (\(items.count)):\n"
            for item in items {
                if let price = item.price {
                    desc += "- \(item.name): \(currency) \(String(format: "%.0f", price))\n"
                } else {
                    desc += "- \(item.name): (tidak ada harga)\n"
                }
            }
        }
        return desc
    }
}

// MARK: - Receipt Item
struct ReceiptItem: Codable, Identifiable {
    var id: String { name + "\(price ?? 0)" }
    var name: String
    var price: Double?  // Optional to handle items without price (like plastic bags)
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
    var discount: Double?          // Diskon
    var rounding: Double?          // Pembulatan (bisa positif atau negatif)
}
