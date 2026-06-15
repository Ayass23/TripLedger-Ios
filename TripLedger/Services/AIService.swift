import Foundation

// MARK: - AI Service
final class AIService {

    static let shared = AIService()
    private init() {}

    // ✅ SECURE: Load API key from Secrets.xcconfig (via Info.plist)
    // Flow: Secrets.xcconfig → Xcode Build → Info.plist → Bundle
    private let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
              key != "YOUR_OPENAI_API_KEY_HERE",
              !key.isEmpty else {
            print("⚠️ [AIService] OpenAI API key not configured in Secrets.xcconfig")
            return ""
        }
        return key
    }()

    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"

    // MARK: - Parse Receipt from OCR Text
    func parseReceipt(from ocrText: String) async throws -> ParsedReceiptModel {
        print("📄 [AIService] Starting receipt parsing...")
        print("📝 [AIService] OCR Text (\(ocrText.count) chars):")
        print("─────────────────────────────────────")
        print(ocrText)
        print("─────────────────────────────────────")

        // Buat prompt untuk AI (spesifik untuk struk Indonesia)
        let prompt = """
        Kamu adalah asisten untuk menganalisis struk/receipt dari Indonesia. Analisis teks berikut dan tentukan apakah ini BENAR-BENAR STRUK atau bukan.

        TEKS YANG DIANALISIS:
        \(ocrText)

        LANGKAH 1 - VALIDASI STRUK:
        Periksa apakah teks ini adalah struk pembayaran yang valid dengan kriteria:
        - Ada nama merchant/toko
        - Ada daftar item/produk yang dibeli (minimal 1)
        - Ada total pembayaran dengan angka yang jelas
        - Ada indikator transaksi (tanggal, nomor transaksi, atau kasir)

        Jika BUKAN struk (misalnya: foto dokumen biasa, text acak, screenshot chat, dll), return JSON berikut:
        {
            "isReceipt": false,
            "error": "Ini bukan struk pembayaran yang valid"
        }

        LANGKAH 2 - EKSTRAK DATA (hanya jika struk valid):
        Jika ini adalah struk yang valid, ekstrak informasi berikut:

        INSTRUKSI:
        1. Ekstrak nama toko/merchant (biasanya di baris pertama atau paling atas)
        2. Cari total akhir (keyword: "TOTAL", "GRAND TOTAL", "Total Pembayaran", "JUMLAH")
        3. Format harga Indonesia menggunakan titik sebagai thousand separator (contoh: 50.000 = lima puluh ribu rupiah)
        4. Ekstrak SEMUA item dengan harganya (sebelum baris pajak/service charge/discount)
        5. Identifikasi kategori berdasarkan nama merchant atau jenis item
        6. Cari pajak (keyword: "PB1", "Pajak", "Tax", "PPn"), service charge, dan DISKON (keyword: "DISKON", "DISCOUNT", "POTONGAN", "DISC")

        KATEGORI yang valid:
        - "Food" untuk restoran, cafe, makanan/minuman
        - "Transport" untuk transportasi (taxi, grab, gojek, dll)
        - "Accommodation" untuk hotel, penginapan
        - "Entertainment" untuk hiburan, bioskop, permainan
        - "Shopping" untuk belanja, supermarket, toko
        - "Health" untuk kesehatan, apotik, klinik
        - "Other" untuk lainnya

        CONTOH FORMAT HARGA INDONESIA:
        - "50.000" = 50000 (lima puluh ribu) - BUKAN 50.0!
        - "131.000" = 131000 (seratus tiga puluh satu ribu) - BUKAN 131.0!
        - "150.500" = 150500 (seratus lima puluh ribu lima ratus)
        - "1.250.000" = 1250000 (satu juta dua ratus lima puluh ribu)

        SANGAT PENTING - TITIK (.) ADALAH THOUSAND SEPARATOR:
        - Di Indonesia: 50.000 = 50 ribu = 50000
        - BUKAN desimal! 50.000 ≠ 50.0
        - Koma (,) adalah desimal: 50,50 = 50.5

        Return HANYA JSON dengan struktur ini (tanpa markdown, tanpa teks tambahan):

        JIKA BUKAN STRUK:
        {
            "isReceipt": false,
            "error": "Penjelasan mengapa bukan struk"
        }

        JIKA STRUK VALID:
        {
            "isReceipt": true,
            "billName": "Nama Toko/Merchant",
            "totalAmount": 50000,
            "currency": "Rp",
            "category": "Food",
            "items": [
                {"name": "Nama Item", "price": 25000, "quantity": 1}
            ],
            "date": "2024-05-14",
            "taxAmount": 5000,
            "serviceCharge": 2500,
            "discount": 10000
        }

        PENTING:
        - totalAmount, price, taxAmount, serviceCharge harus NUMBER tanpa desimal (contoh: 131000 BUKAN 131)
        - Hapus SEMUA titik dari angka (131.000 → 131000)
        - Hapus SEMUA koma dari angka jika ada
        - Jangan interpretasikan titik sebagai desimal!
        - Jika tidak ada data, gunakan null
        - Jika ada item tanpa harga (seperti plastik gratis), set price = null atau jangan include item tersebut
        - Return ONLY JSON, no explanation
        """

        // Check if API key is configured
        guard !apiKey.isEmpty else {
            print("⚠️ [AIService] API key not configured, using mock parser")
            return createMockParsedReceipt(from: ocrText)
        }

        // Prepare request
        print("🤖 [AIService] Calling OpenAI API...")
        let requestBody: [String: Any] = [
            "model": "gpt-5.4-mini-2026-03-17",
            "messages": [
                ["role": "system", "content": "Kamu adalah ahli dalam membaca dan menganalisis struk pembayaran Indonesia. Return hanya valid JSON tanpa teks tambahan."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2,  // Lower for more consistent results
            "max_completion_tokens": 1500  // Changed from max_tokens for new model
        ]

        guard let url = URL(string: apiEndpoint) else {
            print("❌ [AIService] Invalid API endpoint")
            throw AppError.unknown("Invalid API endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Make API call
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [AIService] Invalid HTTP response")
            throw AppError.unknown("Invalid response")
        }

        print("📡 [AIService] Response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [AIService] API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw AppError.unknown("API Error (\(httpResponse.statusCode)): \(errorMessage)")
        }

        // Parse response
        let aiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let content = aiResponse.choices.first?.message.content else {
            print("❌ [AIService] No content in AI response")
            throw AppError.unknown("No content in AI response")
        }

        print("🤖 [AIService] Raw AI Response:")
        print("─────────────────────────────────────")
        print(content)
        print("─────────────────────────────────────")

        // Clean content (remove markdown code blocks if present)
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("🧹 [AIService] Cleaned JSON:")
        print(cleanContent)

        // Parse JSON response
        guard let jsonData = cleanContent.data(using: .utf8) else {
            print("❌ [AIService] Failed to convert response to data")
            throw AppError.unknown("Failed to convert response to data")
        }

        let parsedResponse = try JSONDecoder().decode(AIReceiptResponse.self, from: jsonData)

        // Check if it's a valid receipt
        if parsedResponse.isReceipt == false {
            let errorMsg = parsedResponse.error ?? "Ini bukan struk pembayaran yang valid"
            print("❌ [AIService] Not a receipt: \(errorMsg)")
            throw AppError.unknown(errorMsg)
        }

        // Validate required fields exist
        guard let billName = parsedResponse.billName,
              let totalAmount = parsedResponse.totalAmount,
              let currency = parsedResponse.currency,
              let items = parsedResponse.items else {
            print("❌ [AIService] Missing required receipt fields")
            throw AppError.unknown("Data struk tidak lengkap. Pastikan foto menampilkan informasi struk dengan jelas.")
        }

        print("✅ [AIService] Successfully parsed receipt:")
        print("   📝 Bill Name: \(billName)")
        print("   💰 Total: \(currency) \(totalAmount) (raw: \(totalAmount))")
        print("   🏷️  Category: \(parsedResponse.category ?? "nil")")
        print("   📦 Items: \(items.count)")
        for (idx, item) in items.enumerated() {
            if let price = item.price {
                print("      \(idx+1). \(item.name) - \(currency) \(price) (raw: \(price))")
            } else {
                print("      \(idx+1). \(item.name) - (no price)")
            }
        }

        // Auto-fix amounts that are too small (AI misinterpreted dots as decimals)
        var fixedTotalAmount = totalAmount
        var fixedItems = items
        var fixedTaxAmount = parsedResponse.taxAmount
        var fixedServiceCharge = parsedResponse.serviceCharge
        var fixedDiscount = parsedResponse.discount

        if currency == "Rp" || currency == "IDR" {
            // Auto-fix total amount
            if fixedTotalAmount < 1000 && fixedTotalAmount > 0 {
                print("⚠️ [AIService] AUTO-FIX: Total \(fixedTotalAmount) → \(fixedTotalAmount * 1000)")
                fixedTotalAmount *= 1000
            }

            // Auto-fix item prices
            fixedItems = items.map { item in
                var fixedItem = item
                if let price = item.price, price < 1000 && price > 0 {
                    print("⚠️ [AIService] AUTO-FIX: \(item.name) \(price) → \(price * 1000)")
                    fixedItem.price = price * 1000
                }
                return fixedItem
            }

            // Auto-fix tax
            if let tax = fixedTaxAmount, tax < 1000 && tax > 0 {
                print("⚠️ [AIService] AUTO-FIX: Tax \(tax) → \(tax * 1000)")
                fixedTaxAmount = tax * 1000
            }

            // Auto-fix service charge
            if let service = fixedServiceCharge, service < 1000 && service > 0 {
                print("⚠️ [AIService] AUTO-FIX: Service \(service) → \(service * 1000)")
                fixedServiceCharge = service * 1000
            }

            // Auto-fix discount
            if let disc = fixedDiscount, disc < 1000 && disc > 0 {
                print("⚠️ [AIService] AUTO-FIX: Discount \(disc) → \(disc * 1000)")
                fixedDiscount = disc * 1000
            }
        }

        // Convert to ParsedReceiptModel with fixed amounts
        let result = ParsedReceiptModel(
            billName: billName,
            totalAmount: fixedTotalAmount,
            currency: currency,
            category: parsedResponse.category,
            items: fixedItems,
            date: parsedResponse.date,
            taxAmount: fixedTaxAmount,
            serviceCharge: fixedServiceCharge,
            discount: fixedDiscount
        )

        print("🎉 [AIService] Parsing completed successfully!")
        return result
    }

    // MARK: - Create Mock Parsed Receipt (Fallback untuk struk Indonesia)
    private func createMockParsedReceipt(from ocrText: String) -> ParsedReceiptModel {
        print("🔄 [AIService] Using fallback mock parser for Indonesian receipt")

        // Extract merchant name (first non-empty line)
        let lines = ocrText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let merchantName = lines.first ?? "Merchant Tidak Diketahui"
        print("   📝 Merchant: \(merchantName)")

        // Try to extract total amount using regex (Indonesian format)
        // Pattern mencari: TOTAL, GRAND TOTAL, JUMLAH diikuti angka dengan format Indonesia (50.000)
        let pattern = #"(?i)(?:total|jumlah|grand\s*total|total\s*pembayaran)[^0-9]*([0-9][0-9.,\s]*)"#
        var totalAmount: Double = 0.0

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: ocrText, range: NSRange(ocrText.startIndex..., in: ocrText)),
           let range = Range(match.range(at: 1), in: ocrText) {
            let raw = String(ocrText[range])
                .replacingOccurrences(of: ".", with: "")  // Remove thousand separator
                .replacingOccurrences(of: ",", with: "")  // Remove decimal
                .replacingOccurrences(of: " ", with: "")  // Remove spaces
                .trimmingCharacters(in: .whitespacesAndNewlines)
            totalAmount = Double(raw) ?? 0.0
            print("   💰 Total found: \(totalAmount)")
        } else {
            print("   ⚠️ Total not found in receipt")
        }

        // Detect currency (Indonesia)
        let currency = ocrText.lowercased().contains("rp") || ocrText.lowercased().contains("idr") ? "Rp" : "USD"

        // Try to extract items dengan format Indonesia
        var items: [ReceiptItem] = []
        // Pattern: Nama item diikuti harga (dengan atau tanpa quantity)
        let itemPattern = #"([A-Za-z][A-Za-z\s]{2,30})\s+(?:x?\d+\s+)?([0-9]{1,3}(?:\.[0-9]{3})+)"#

        if let itemRegex = try? NSRegularExpression(pattern: itemPattern) {
            let matches = itemRegex.matches(in: ocrText, range: NSRange(ocrText.startIndex..., in: ocrText))
            print("   📦 Found \(matches.count) potential items")

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: ocrText),
                   let priceRange = Range(match.range(at: 2), in: ocrText) {
                    let name = String(ocrText[nameRange])
                        .trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "  ", with: " ")

                    let priceStr = String(ocrText[priceRange])
                        .replacingOccurrences(of: ".", with: "")  // Remove thousand separator
                        .replacingOccurrences(of: " ", with: "")

                    if let price = Double(priceStr),
                       price > 1000,  // Minimum 1000 rupiah
                       price < totalAmount * 1.5,  // Not more than 1.5x total
                       !name.lowercased().contains("total"),
                       !name.lowercased().contains("pajak"),
                       !name.lowercased().contains("service") {
                        items.append(ReceiptItem(name: name, price: price, quantity: 1))
                        print("      ✓ \(name) - Rp \(price)")
                    }
                }
            }
        }

        // Guess category based on Indonesian keywords
        var category: String? = nil
        let lowerText = ocrText.lowercased()
        if lowerText.contains("restaurant") || lowerText.contains("resto") || lowerText.contains("cafe") ||
           lowerText.contains("warung") || lowerText.contains("rumah makan") || lowerText.contains("food") ||
           lowerText.contains("makan") || lowerText.contains("kopi") {
            category = "Food"
        } else if lowerText.contains("taxi") || lowerText.contains("uber") || lowerText.contains("grab") ||
                  lowerText.contains("gojek") || lowerText.contains("ojek") || lowerText.contains("transport") {
            category = "Transport"
        } else if lowerText.contains("hotel") || lowerText.contains("hostel") || lowerText.contains("penginapan") ||
                  lowerText.contains("homestay") {
            category = "Accommodation"
        } else if lowerText.contains("indomaret") || lowerText.contains("alfamart") || lowerText.contains("supermarket") ||
                  lowerText.contains("toko") || lowerText.contains("mall") {
            category = "Shopping"
        }

        print("   🏷️  Category: \(category ?? "nil")")

        let result = ParsedReceiptModel(
            billName: merchantName,
            totalAmount: totalAmount,
            currency: currency,
            category: category,
            items: items,
            date: nil,
            taxAmount: nil,
            serviceCharge: nil,
            discount: nil
        )

        print("✅ [AIService] Mock parsing completed")
        return result
    }
}

// MARK: - OpenAI Response Models
private struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}
