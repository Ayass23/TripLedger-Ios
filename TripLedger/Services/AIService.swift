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

        // Buat prompt untuk AI (spesifik untuk struk Indonesia) - IMPROVED VERSION v2
        let prompt = """
        Analisis teks struk pembayaran Indonesia berikut.

        === TEKS STRUK ===
        \(ocrText)
        === AKHIR TEKS ===

        TUGAS: Ekstrak data dari struk di atas ke format JSON.

        ═══════════════════════════════════════════════════════════════
        ATURAN KRITIS #1 - FORMAT ANGKA INDONESIA:
        ═══════════════════════════════════════════════════════════════
        Di Indonesia, TITIK (.) adalah PEMISAH RIBUAN, BUKAN DESIMAL!

        CONTOH KONVERSI:
          "15.000"     → 15000    (lima belas ribu)
          "150.000"    → 150000   (seratus lima puluh ribu)
          "1.500.000"  → 1500000  (satu juta lima ratus ribu)
          "25.500"     → 25500    (dua puluh lima ribu lima ratus)

        SALAH: "15.000" → 15.0 ❌
        BENAR: "15.000" → 15000 ✓

        ═══════════════════════════════════════════════════════════════
        ATURAN KRITIS #2 - QUANTITY DAN HARGA SATUAN:
        ═══════════════════════════════════════════════════════════════
        Di struk Indonesia, format item dengan quantity biasanya:

        FORMAT UMUM:
        ```
        [Nama Item]  [Qty]  [Harga Total Baris]
        Es Teh        2      10.000
        ```

        PENTING: Angka di akhir adalah HARGA TOTAL BARIS, bukan harga satuan!

        CARA PARSING:
        1. Jika ada angka SEBELUM harga (biasanya 1-9), itu adalah QUANTITY
        2. Harga yang tertera = Qty × Harga Satuan
        3. Hitung: Harga Satuan = Harga Total Baris ÷ Quantity

        CONTOH:
        ```
        Es Teh    2   10.000   → qty=2, price=5000 (10000÷2)
        Bakso     3   45.000   → qty=3, price=15000 (45000÷3)
        Nasi      1   15.000   → qty=1, price=15000
        Ayam Goreng   25.000   → qty=1, price=25000 (tidak ada qty = 1)
        ```

        VARIASI FORMAT:
        ```
        2x Es Teh     10.000   → qty=2, price=5000
        Es Teh x2     10.000   → qty=2, price=5000
        Es Teh (2)    10.000   → qty=2, price=5000
        Es Teh @5000 x2 10.000 → qty=2, price=5000 (@ menunjukkan harga satuan)
        ```

        JIKA ADA SIMBOL @ (at):
        ```
        Es Teh 2 @5.000 10.000  → qty=2, price=5000 (@5000 adalah harga satuan)
        ```

        OUTPUT yang BENAR:
        {"name": "Es Teh", "price": 5000, "quantity": 2}

        OUTPUT yang SALAH:
        {"name": "Es Teh", "price": 10000, "quantity": 1} ❌

        ═══════════════════════════════════════════════════════════════
        ATURAN KRITIS #3 - ITEM MURAH:
        ═══════════════════════════════════════════════════════════════
        Beberapa item memang berharga MURAH (di bawah Rp 1.000):
        - Plastik/kantong: Rp 200 - 500
        - Sedotan: Rp 200 - 500
        - Es batu: Rp 500 - 1.000

        JANGAN ubah harga item murah ini! Rp 400 tetap 400, BUKAN 400000.

        ═══════════════════════════════════════════════════════════════
        ATURAN KRITIS #4 - DISKON/VOUCHER SEBAGAI ITEM:
        ═══════════════════════════════════════════════════════════════
        Diskon di struk Indonesia sering muncul sebagai ITEM dengan:
        - Harga NEGATIF (ada tanda minus)
        - Keyword: VC, VOUCHER, PROMO, DISC, POTONGAN, CASHBACK, REWARD

        CONTOH:
        ```
        Nasi Goreng      25.000
        Es Teh            8.000
        VC GOPAY         -5.000  ← Ini DISKON, bukan item!
        PROMO WEEKEND    -3.000  ← Ini juga DISKON!
        TOTAL            25.000
        ```

        CARA HANDLE:
        1. JANGAN masukkan item dengan harga negatif ke array "items"
        2. JUMLAHKAN semua item negatif/voucher → masukkan ke "discount"
        3. Discount: 5000 + 3000 = 8000

        KEYWORD DISKON: VC, VOUCHER, PROMO, DISC, DISKON, POTONGAN,
                        CASHBACK, REWARD, KUPON, COUPON, MEMBER

        ═══════════════════════════════════════════════════════════════
        ATURAN KRITIS #5 - PAJAK (PPN/PB1/VAT):
        ═══════════════════════════════════════════════════════════════
        WAJIB ekstrak pajak jika ada! Cari keyword berikut:
        - PPN (Pajak Pertambahan Nilai)
        - PB1 / PB 1 (Pajak Bangunan 1 / Pajak Restoran)
        - VAT (Value Added Tax)
        - TAX / PAJAK
        - PPn / Ppn (variasi kapitalisasi)
        - SERVICE TAX
        - GOV TAX

        CONTOH PAJAK DI STRUK:
        ```
        Subtotal       100.000
        PB1 10%         10.000  ← Ini PAJAK! taxAmount = 10000
        Service 5%       5.000
        TOTAL          115.000
        ```

        ```
        Subtotal       100.000
        PPN 11%         11.000  ← Ini PAJAK! taxAmount = 11000
        TOTAL          111.000
        ```

        PAJAK INFORMATIF vs AKTUAL:
        - Jika SUM(items) + pajak + service - discount ≈ total → pajak AKTUAL
        - Jika SUM(items) ≈ total (tanpa pajak) → pajak INFORMATIF (null)

        ═══════════════════════════════════════════════════════════════
        ATURAN KRITIS #6 - PEMBULATAN (ROUNDING):
        ═══════════════════════════════════════════════════════════════
        Di Indonesia, struk sering ada PEMBULATAN untuk membulatkan total.
        Pembulatan bisa POSITIF (menambah) atau NEGATIF (mengurangi).

        KEYWORD PEMBULATAN:
        - PEMBULATAN / BULATKAN / BULAT
        - ROUNDING / ROUND
        - SELISIH
        - ADJ / ADJUSTMENT

        CONTOH PEMBULATAN:
        ```
        Subtotal       99.800
        Pembulatan        200  ← POSITIF (menambah ke 100.000)
        TOTAL         100.000
        ```
        → rounding = 200

        ```
        Subtotal      100.300
        Pembulatan       -300  ← NEGATIF (mengurangi ke 100.000)
        TOTAL         100.000
        ```
        → rounding = -300

        PENTING: Pembulatan biasanya angka KECIL (< Rp 1.000)

        ═══════════════════════════════════════════════════════════════
        LANGKAH PARSING:
        ═══════════════════════════════════════════════════════════════
        1. Cari nama toko/merchant di bagian ATAS struk
        2. Ekstrak SEMUA item dengan harga (sebelum subtotal/pajak/total)
        3. Cari PAJAK (PPN/PB1/VAT/TAX) - WAJIB ekstrak jika ada!
        4. Cari SERVICE CHARGE jika ada
        5. Cari PEMBULATAN/ROUNDING jika ada
        6. Cari DISKON (termasuk dari item negatif)
        7. Cari TOTAL/GRAND TOTAL (angka akhir yang dibayar)
        8. Validasi: items + tax + service + rounding - discount ≈ total
        9. Tentukan kategori

        KATEGORI: Food, Transport, Accommodation, Entertainment, Shopping, Health, Other

        OUTPUT FORMAT:
        {
            "isReceipt": true/false,
            "error": "alasan jika bukan struk",
            "billName": "Nama Toko",
            "totalAmount": 115000,
            "currency": "Rp",
            "category": "Food",
            "items": [
                {"name": "Bakso", "price": 25000, "quantity": 1},
                {"name": "Es Teh", "price": 8000, "quantity": 1}
            ],
            "date": "2024-05-14",
            "taxAmount": 10000,
            "serviceCharge": 5000,
            "discount": null,
            "rounding": 200
        }

        CONTOH LENGKAP (dengan quantity):
        Struk:
        ```
        RESTORAN SEDERHANA
        Nasi Goreng    25.000
        Es Teh    2    10.000    ← 2x Es Teh, total 10.000
        Subtotal       35.000
        PB1 10%         3.500
        Service 5%      1.750
        Pembulatan        -250
        TOTAL          40.000
        ```
        Output:
        {
            "isReceipt": true,
            "billName": "RESTORAN SEDERHANA",
            "totalAmount": 40000,
            "currency": "Rp",
            "category": "Food",
            "items": [
                {"name": "Nasi Goreng", "price": 25000, "quantity": 1},
                {"name": "Es Teh", "price": 5000, "quantity": 2}
            ],
            "taxAmount": 3500,
            "serviceCharge": 1750,
            "rounding": -250,
            "discount": null
        }
        Note: Es Teh qty=2, price=5000 (10000÷2), BUKAN price=10000!

        PENTING:
        - Semua angka harus INTEGER (25000 bukan 25.0)
        - Item murah (plastik, sedotan) bisa < 1000, jangan diubah
        - QUANTITY: price = harga_baris ÷ quantity (SANGAT PENTING!)
        - WAJIB ekstrak taxAmount jika ada PPN/PB1/VAT di struk!
        - WAJIB ekstrak rounding jika ada pembulatan di struk!
        - Return HANYA JSON, tanpa markdown atau penjelasan
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
                ["role": "system", "content": """
                    Kamu adalah parser struk Indonesia yang sangat akurat.

                    ATURAN MUTLAK:
                    1. TITIK dalam angka Indonesia = pemisah ribuan (50.000 = 50000)
                    2. JANGAN pernah interpretasikan titik sebagai desimal
                    3. Selalu return angka sebagai INTEGER (25000, bukan 25.0)
                    4. QUANTITY: Jika ada "Es Teh 2 10.000", qty=2 dan price=5000 (10000÷2)
                       - Harga di struk = TOTAL BARIS, bukan harga satuan!
                       - Hitung: price = harga_baris ÷ quantity
                    5. Item MURAH (plastik, sedotan, es) memang < Rp 1.000, jangan diubah!
                    6. Item dengan HARGA NEGATIF atau keyword VC/VOUCHER/PROMO = DISKON, bukan item!
                    7. WAJIB ekstrak PAJAK jika ada (PPN/PB1/VAT/TAX/PAJAK)
                    8. WAJIB ekstrak PEMBULATAN jika ada (PEMBULATAN/ROUNDING/BULAT/SELISIH)
                    9. VALIDASI: SUM(price×qty) + tax + service + rounding - discount ≈ total
                    10. Jika validasi gagal dan pajak membuat total > actual, set pajak = null (informatif)
                    11. Return HANYA valid JSON, tanpa markdown atau penjelasan
                    """],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0,  // Zero temperature for maximum consistency
            "max_completion_tokens": 2000,
            "response_format": ["type": "json_object"]  // Force JSON output
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
        print("   📦 Items from AI: \(items.count)")
        for (idx, item) in items.enumerated() {
            if let price = item.price {
                let qty = item.quantity ?? 1
                let lineTotal = price * Double(qty)
                print("      \(idx+1). '\(item.name)' - qty:\(qty) × \(currency) \(price) = \(lineTotal)")
            } else {
                print("      \(idx+1). '\(item.name)' - (no price)")
            }
        }
        print("   ⚠️ Note: If qty=1 but name contains '2 xxx', post-processing will fix it")

        // Auto-fix amounts that are too small (AI misinterpreted dots as decimals)
        var fixedTotalAmount = totalAmount
        var fixedItems = items
        var fixedTaxAmount = parsedResponse.taxAmount
        var fixedServiceCharge = parsedResponse.serviceCharge
        var fixedDiscount = parsedResponse.discount
        var fixedRounding = parsedResponse.rounding

        if currency == "Rp" || currency == "IDR" {
            // Smart auto-fix for Indonesian Rupiah

            // STEP 0: Extract discount items from items array
            // Some receipts list discounts as items with negative prices or discount keywords
            let discountKeywords = ["vc", "voucher", "promo", "disc", "diskon", "potongan",
                                    "cashback", "reward", "kupon", "coupon", "member", "poin", "point"]

            var extractedDiscount: Double = 0
            var regularItems: [ReceiptItem] = []

            for item in items {
                let nameLower = item.name.lowercased()
                let isDiscountItem = discountKeywords.contains { nameLower.contains($0) }
                let hasNegativePrice = (item.price ?? 0) < 0

                if isDiscountItem || hasNegativePrice {
                    // This is a discount item, extract the value
                    let discValue = abs(item.price ?? 0)
                    extractedDiscount += discValue
                    print("🏷️ [AIService] Extracted discount from item: \(item.name) = \(discValue)")
                } else {
                    regularItems.append(item)
                }
            }

            // Add extracted discount to existing discount
            if extractedDiscount > 0 {
                let existingDiscount = fixedDiscount ?? 0
                fixedDiscount = existingDiscount + extractedDiscount
                print("🏷️ [AIService] Total discount: \(existingDiscount) + \(extractedDiscount) = \(fixedDiscount ?? 0)")
            }

            // Use only regular items (without discount items)
            fixedItems = regularItems

            // STEP 1: Auto-fix total amount
            fixedTotalAmount = autoFixIndonesianAmount(fixedTotalAmount, context: "Total")

            // Auto-fix item prices
            fixedItems = regularItems.map { item in
                var fixedItem = item
                if let price = item.price {
                    fixedItem.price = autoFixIndonesianAmount(price, context: item.name)
                }
                return fixedItem
            }

            // STEP 2: Fix quantity from item names
            // Detect patterns like "2 1pc chicken", "2x Es Teh", "Es Teh (2)" in item names
            fixedItems = fixedItems.map { item in
                var fixedItem = item
                let currentQty = item.quantity ?? 1

                // Only fix if quantity is 1 (might be incorrectly parsed)
                if currentQty == 1 {
                    let (detectedQty, cleanedName) = extractQuantityFromName(item.name)
                    if detectedQty > 1 {
                        // Found quantity in name, fix it
                        fixedItem.quantity = detectedQty
                        // Clean up the name (remove quantity prefix)
                        fixedItem.name = cleanedName

                        // Recalculate unit price: lineTotal / quantity
                        // Use fixedItem.price which has already been auto-fixed
                        if let lineTotal = fixedItem.price {
                            let unitPrice = lineTotal / Double(detectedQty)
                            fixedItem.price = unitPrice
                            print("🔧 [AIService] Fixed quantity for '\(item.name)':")
                            print("   Original: qty=1, lineTotal=\(lineTotal)")
                            print("   Fixed: qty=\(detectedQty), unitPrice=\(unitPrice), name='\(cleanedName)'")
                        }
                    }
                }
                return fixedItem
            }

            // Auto-fix tax
            if let tax = fixedTaxAmount {
                fixedTaxAmount = autoFixIndonesianAmount(tax, context: "Tax")
            }

            // Auto-fix service charge
            if let service = fixedServiceCharge {
                fixedServiceCharge = autoFixIndonesianAmount(service, context: "Service")
            }

            // Auto-fix discount
            if let disc = fixedDiscount {
                fixedDiscount = autoFixIndonesianAmount(disc, context: "Discount")
            }

            // Auto-fix rounding (rounding is usually small, don't multiply)
            // Rounding can be negative, so handle both cases
            if let rounding = fixedRounding {
                // Rounding should be small (usually < 1000)
                // If it's too large, it might have been misread
                if abs(rounding) > 1000 {
                    print("⚠️ [AIService] Rounding value seems too large: \(rounding)")
                    // Check if it should be divided by 1000
                    if abs(rounding) >= 1000 && abs(rounding) < 10000 {
                        // Might be correct, keep it
                    }
                }
                print("ℹ️ [AIService] Rounding: \(rounding)")
            }

            // Cross-validation: Check if items sum is close to total
            let itemsSum = fixedItems.reduce(0.0) { $0 + (($1.price ?? 0) * Double($1.quantity ?? 1)) }
            let extras = (fixedTaxAmount ?? 0) + (fixedServiceCharge ?? 0) + (fixedRounding ?? 0) - (fixedDiscount ?? 0)
            let expectedTotalWithExtras = itemsSum + extras
            let expectedTotalWithoutExtras = itemsSum + (fixedRounding ?? 0) - (fixedDiscount ?? 0)

            print("📊 [AIService] Cross-validation:")
            print("   Items sum: \(itemsSum)")
            print("   Tax: \(fixedTaxAmount ?? 0), Service: \(fixedServiceCharge ?? 0)")
            print("   Discount: \(fixedDiscount ?? 0), Rounding: \(fixedRounding ?? 0)")
            print("   Expected (with tax+service): \(expectedTotalWithExtras)")
            print("   Expected (without tax+service): \(expectedTotalWithoutExtras)")
            print("   Actual total: \(fixedTotalAmount)")

            if fixedTotalAmount > 0 {
                // Check if tax is informational (already included in item prices)
                let diffWithTax = abs(fixedTotalAmount - expectedTotalWithExtras)
                let diffWithoutTax = abs(fixedTotalAmount - expectedTotalWithoutExtras)

                // If total matches items WITHOUT tax better than WITH tax,
                // then tax is probably informational (set to null)
                if diffWithoutTax < diffWithTax && diffWithoutTax < fixedTotalAmount * 0.05 {
                    if fixedTaxAmount != nil && fixedTaxAmount! > 0 {
                        print("ℹ️ [AIService] Tax appears to be INFORMATIONAL (already in prices)")
                        print("   Setting taxAmount to null")
                        fixedTaxAmount = nil
                    }
                    if fixedServiceCharge != nil && fixedServiceCharge! > 0 {
                        // Also check service charge
                        let diffWithoutService = abs(fixedTotalAmount - itemsSum + (fixedRounding ?? 0) - (fixedDiscount ?? 0))
                        if diffWithoutService < fixedTotalAmount * 0.05 {
                            print("ℹ️ [AIService] Service charge appears to be INFORMATIONAL")
                            print("   Setting serviceCharge to null")
                            fixedServiceCharge = nil
                        }
                    }
                }

                // Final validation
                let finalExpected = itemsSum + (fixedTaxAmount ?? 0) + (fixedServiceCharge ?? 0) + (fixedRounding ?? 0) - (fixedDiscount ?? 0)
                let finalDiff = abs(fixedTotalAmount - finalExpected)
                let tolerance = fixedTotalAmount * 0.1  // 10% tolerance

                if finalDiff > tolerance {
                    print("⚠️ [AIService] WARNING: Total (\(fixedTotalAmount)) doesn't match calculated (\(finalExpected))")
                    print("   Difference: \(finalDiff) (tolerance: \(tolerance))")
                } else {
                    print("✅ [AIService] Validation passed: Total matches calculated amount")
                }
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
            discount: fixedDiscount,
            rounding: fixedRounding
        )

        print("🎉 [AIService] Parsing completed successfully!")
        return result
    }

    // MARK: - Extract Quantity from Item Name
    /// Detects quantity patterns in item names and returns (quantity, cleanedName)
    /// Examples:
    ///   "2 1pc chicken" -> (2, "1pc chicken")
    ///   "2x Es Teh" -> (2, "Es Teh")
    ///   "Es Teh x2" -> (2, "Es Teh")
    ///   "Es Teh (2)" -> (2, "Es Teh")
    ///   "3 Nasi Goreng" -> (3, "Nasi Goreng")
    private func extractQuantityFromName(_ name: String) -> (quantity: Int, cleanedName: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Pattern 1: Starts with number followed by space (with or without 'x')
        // "2 1pc chicken", "2x Es Teh", "3 Nasi Goreng", "2x1pc chicken"
        let prefixPattern = #"^(\d+)\s*[xX]?\s*(.+)$"#
        if let regex = try? NSRegularExpression(pattern: prefixPattern),
           let match = regex.firstMatch(in: trimmedName, range: NSRange(trimmedName.startIndex..., in: trimmedName)),
           let qtyRange = Range(match.range(at: 1), in: trimmedName),
           let nameRange = Range(match.range(at: 2), in: trimmedName) {
            let qty = Int(trimmedName[qtyRange]) ?? 1
            var cleanedName = String(trimmedName[nameRange]).trimmingCharacters(in: .whitespaces)
            // Don't extract if qty is 1 or remaining name is just numbers (like "1pc" becoming "pc")
            if qty > 1 && qty <= 99 && !cleanedName.isEmpty && cleanedName.first?.isLetter == true {
                print("   🔍 [extractQty] Pattern 1 matched: '\(trimmedName)' -> qty=\(qty), name='\(cleanedName)'")
                return (qty, cleanedName)
            }
        }

        // Pattern 2: Ends with 'x' followed by number
        // "Es Teh x2", "Nasi Goreng X3"
        let suffixPattern = #"^(.+?)\s*[xX]\s*(\d+)$"#
        if let regex = try? NSRegularExpression(pattern: suffixPattern),
           let match = regex.firstMatch(in: trimmedName, range: NSRange(trimmedName.startIndex..., in: trimmedName)),
           let nameRange = Range(match.range(at: 1), in: trimmedName),
           let qtyRange = Range(match.range(at: 2), in: trimmedName) {
            let qty = Int(trimmedName[qtyRange]) ?? 1
            let cleanedName = String(trimmedName[nameRange]).trimmingCharacters(in: .whitespaces)
            if qty > 1 && qty <= 99 {
                print("   🔍 [extractQty] Pattern 2 matched: '\(trimmedName)' -> qty=\(qty), name='\(cleanedName)'")
                return (qty, cleanedName)
            }
        }

        // Pattern 3: Ends with number in parentheses
        // "Es Teh (2)", "Nasi Goreng (3)"
        let parenPattern = #"^(.+?)\s*\((\d+)\)\s*$"#
        if let regex = try? NSRegularExpression(pattern: parenPattern),
           let match = regex.firstMatch(in: trimmedName, range: NSRange(trimmedName.startIndex..., in: trimmedName)),
           let nameRange = Range(match.range(at: 1), in: trimmedName),
           let qtyRange = Range(match.range(at: 2), in: trimmedName) {
            let qty = Int(trimmedName[qtyRange]) ?? 1
            let cleanedName = String(trimmedName[nameRange]).trimmingCharacters(in: .whitespaces)
            if qty > 1 && qty <= 99 {
                print("   🔍 [extractQty] Pattern 3 matched: '\(trimmedName)' -> qty=\(qty), name='\(cleanedName)'")
                return (qty, cleanedName)
            }
        }

        // No quantity found, return original
        return (1, trimmedName)
    }

    // MARK: - Smart Auto-Fix for Indonesian Amount
    private func autoFixIndonesianAmount(_ amount: Double, context: String) -> Double {
        guard amount > 0 else { return amount }

        // List of items that are legitimately cheap (under Rp 1.000)
        let cheapItemKeywords = [
            "plastik", "kantong", "plastic", "bag",
            "sedotan", "straw",
            "es batu", "ice",
            "tissue", "tisu",
            "sendok", "garpu", "spoon", "fork",
            "sambal", "kecap", "sauce",
            "air mineral", "aqua"  // Sometimes very cheap
        ]

        let contextLower = context.lowercased()

        // Check if this is a legitimately cheap item
        let isCheapItem = cheapItemKeywords.contains { contextLower.contains($0) }

        if isCheapItem && amount < 1000 && amount > 0 {
            // This is likely a legitimate cheap item, don't auto-fix
            print("ℹ️ [AIService] SKIP FIX: \(context) = \(amount) (legitimate cheap item)")
            return amount
        }

        var fixed = amount

        // Case 1: Very small number that's likely divided by 1000
        // But only if it's NOT a cheap item and has decimal pattern
        if amount < 1000 && !isCheapItem {
            // Check if it looks like a decimal was wrongly interpreted
            // e.g., 131.0 (should be 131000), 15.5 (should be 15500)
            let decimalPart = amount.truncatingRemainder(dividingBy: 1)

            // Only fix if:
            // 1. Has suspicious decimal (like .0, .5)
            // 2. Or is unrealistically small for a non-cheap item (< 100)
            if decimalPart > 0 || amount < 100 {
                fixed = amount * 1000
                print("⚠️ [AIService] AUTO-FIX: \(context) \(amount) → \(fixed) (×1000)")
            }
        }

        // Case 2: Check for suspicious decimal patterns in larger numbers
        // e.g., 131.5 likely means 131500
        let decimalPart = amount.truncatingRemainder(dividingBy: 1)
        if decimalPart > 0 && decimalPart < 1 && amount < 10000 && !isCheapItem {
            // Small number with decimal - likely wrong
            fixed = amount * 1000
            print("⚠️ [AIService] AUTO-FIX (decimal): \(context) \(amount) → \(fixed) (×1000)")
        }

        return fixed
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
            discount: nil,
            rounding: nil
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
