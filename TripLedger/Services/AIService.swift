//  AIService.swift
//  Parsing teks OCR struk (format Indonesia) menjadi ParsedReceiptModel via OpenAI.
//  Foto struk ikut dikirim ke model multimodal sebagai sumber kebenaran urutan item.
//  API key dibaca dari Secrets.xcconfig melalui Info.plist - jangan hardcode di sini.
//
import Foundation
import UIKit

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
            AppLog.debug("⚠️ [AIService] OpenAI API key not configured in Secrets.xcconfig")
            return ""
        }
        return key
    }()

    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"

    // MARK: - Parse Receipt from OCR Text (+ optional photo)
    /// When the receipt photo is provided it is sent to the multimodal model
    /// alongside the OCR text: the photo is the source of truth for item order
    /// and name↔price pairing (immune to OCR row-reconstruction errors), while
    /// the OCR text helps with exact digits.
    func parseReceipt(from ocrText: String, image: UIImage? = nil) async throws -> ParsedReceiptModel {
        AppLog.debug("📄 [AIService] Starting receipt parsing...")
        AppLog.debug("📝 [AIService] OCR Text (\(ocrText.count) chars):")
        AppLog.debug("─────────────────────────────────────")
        AppLog.debug(ocrText)
        AppLog.debug("─────────────────────────────────────")

        // Buat prompt untuk AI (spesifik untuk struk Indonesia) - IMPROVED VERSION v2
        var prompt = """
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
        - Ekstrak SEMUA item tanpa kecuali — struk bisa berisi 20+ item, jangan meringkas!
        - Semua angka harus INTEGER (25000 bukan 25.0)
        - Item murah (plastik, sedotan) bisa < 1000, jangan diubah
        - QUANTITY: price = harga_baris ÷ quantity (SANGAT PENTING!)
        - WAJIB ekstrak taxAmount jika ada PPN/PB1/VAT di struk!
        - WAJIB ekstrak rounding jika ada pembulatan di struk!
        - Return HANYA JSON, tanpa markdown atau penjelasan
        """

        // Attach the photo when available — layout comes from the photo,
        // not from the (possibly scrambled) OCR text
        let imageBase64 = encodeImageForVision(image)
        if imageBase64 != nil {
            prompt += """


            ═══════════════════════════════════════════════════════════════
            FOTO STRUK TERLAMPIR — SUMBER UTAMA:
            ═══════════════════════════════════════════════════════════════
            Foto struk asli dilampirkan bersama pesan ini. Teks OCR di atas bisa
            SALAH URUTAN dan SALAH PASANGAN nama-harga. Karena itu:
            1. Gunakan FOTO sebagai sumber utama untuk: urutan item, pasangan
               nama ↔ quantity ↔ harga, dan angka yang terpecah/aneh di OCR
            2. Gunakan teks OCR hanya sebagai alat bantu ejaan/angka
            3. Jika foto dan teks OCR bertentangan, IKUTI FOTO
            """
        }

        // Check if API key is configured
        guard !apiKey.isEmpty else {
            AppLog.debug("⚠️ [AIService] API key not configured, using mock parser")
            return createMockParsedReceipt(from: ocrText)
        }

        // Prepare request
        AppLog.debug("🤖 [AIService] Calling OpenAI API...")
        let systemPrompt = """
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
            11. Ekstrak SEMUA item tanpa kecuali — struk bisa berisi 20+ item, JANGAN meringkas atau melewatkan item apa pun
            12. KOREKSI kesalahan OCR yang jelas:
                - Huruf tunggal T/I/l di awal baris item kemungkinan besar angka 1 (quantity), bukan bagian nama
                - Rapikan salah eja OCR pada nama item (contoh: "Avam" → "Ayam", "Tkan" → "Ikan", "Asın" → "Asin")
            13. Baris yang hanya berisi HARGA tanpa nama biasanya milik item di baris atasnya
                yang tergabung dengan item lain — pisahkan kembali jika masuk akal
            14. Return HANYA valid JSON, tanpa markdown atau penjelasan
            """

        // User message: multimodal (text + photo) when the photo is available
        let userMessageContent: Any
        if let imageBase64 = imageBase64 {
            AppLog.debug("🖼️ [AIService] Attaching receipt photo to AI request")
            userMessageContent = [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": [
                    "url": "data:image/jpeg;base64,\(imageBase64)",
                    "detail": "high"  // receipts have small text
                ]]
            ]
        } else {
            userMessageContent = prompt
        }

        // Reasoning models spend completion tokens on reasoning too; 2000 was
        // truncating long receipts. Start at 8000 and retry once at 16000 if
        // the response still comes back truncated (finish_reason=length).
        var maxCompletionTokens = 8000
        var content = ""

        while true {
            let requestBody: [String: Any] = [
                "model": "gpt-5.4-mini-2026-03-17",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userMessageContent]
                ],
                "temperature": 0,  // Zero temperature for maximum consistency
                "max_completion_tokens": maxCompletionTokens,
                "response_format": ["type": "json_object"]  // Force JSON output
            ]

            let aiResponse = try await performChatRequest(body: requestBody)
            let choice = aiResponse.choices.first

            // Detect truncated response BEFORE parsing — a cut-off JSON would
            // otherwise fail decoding with a generic, misleading error
            if choice?.finishReason == "length" {
                if maxCompletionTokens < 16000 {
                    AppLog.debug("⚠️ [AIService] Response truncated (finish_reason=length), retrying with 16000 tokens...")
                    maxCompletionTokens = 16000
                    continue
                }
                AppLog.debug("❌ [AIService] Response truncated even at \(maxCompletionTokens) tokens")
                throw AppError.unknown("Respons AI terpotong karena struk terlalu panjang. Coba scan ulang dengan foto yang lebih jelas.")
            }

            guard let responseContent = choice?.message.content, !responseContent.isEmpty else {
                AppLog.debug("❌ [AIService] No content in AI response")
                throw AppError.unknown("No content in AI response")
            }

            content = responseContent
            break
        }

        AppLog.debug("🤖 [AIService] Raw AI Response:")
        AppLog.debug("─────────────────────────────────────")
        AppLog.debug(content)
        AppLog.debug("─────────────────────────────────────")

        // Clean content (remove markdown code blocks if present)
        let cleanContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        AppLog.debug("🧹 [AIService] Cleaned JSON:")
        AppLog.debug(cleanContent)

        // Parse JSON response
        guard let jsonData = cleanContent.data(using: .utf8) else {
            AppLog.debug("❌ [AIService] Failed to convert response to data")
            throw AppError.unknown("Failed to convert response to data")
        }

        let parsedResponse = try JSONDecoder().decode(AIReceiptResponse.self, from: jsonData)

        // Check if it's a valid receipt
        if parsedResponse.isReceipt == false {
            let errorMsg = parsedResponse.error ?? "Ini bukan struk pembayaran yang valid"
            AppLog.debug("❌ [AIService] Not a receipt: \(errorMsg)")
            throw AppError.unknown(errorMsg)
        }

        // Validate required fields exist
        guard let billName = parsedResponse.billName,
              let totalAmount = parsedResponse.totalAmount,
              let currency = parsedResponse.currency,
              let items = parsedResponse.items else {
            AppLog.debug("❌ [AIService] Missing required receipt fields")
            throw AppError.unknown("Data struk tidak lengkap. Pastikan foto menampilkan informasi struk dengan jelas.")
        }

        AppLog.debug("✅ [AIService] Successfully parsed receipt:")
        AppLog.debug("   📝 Bill Name: \(billName)")
        AppLog.debug("   💰 Total: \(currency) \(totalAmount) (raw: \(totalAmount))")
        AppLog.debug("   🏷️  Category: \(parsedResponse.category ?? "nil")")
        AppLog.debug("   📦 Items from AI: \(items.count)")
        for (idx, item) in items.enumerated() {
            if let price = item.price {
                let qty = item.quantity ?? 1
                let lineTotal = price * Double(qty)
                AppLog.debug("      \(idx+1). '\(item.name)' - qty:\(qty) × \(currency) \(price) = \(lineTotal)")
            } else {
                AppLog.debug("      \(idx+1). '\(item.name)' - (no price)")
            }
        }
        AppLog.debug("   ⚠️ Note: If qty=1 but name contains '2 xxx', post-processing will fix it")

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
                    AppLog.debug("🏷️ [AIService] Extracted discount from item: \(item.name) = \(discValue)")
                } else {
                    regularItems.append(item)
                }
            }

            // Add extracted discount to existing discount
            if extractedDiscount > 0 {
                let existingDiscount = fixedDiscount ?? 0
                fixedDiscount = existingDiscount + extractedDiscount
                AppLog.debug("🏷️ [AIService] Total discount: \(existingDiscount) + \(extractedDiscount) = \(fixedDiscount ?? 0)")
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
                            AppLog.debug("🔧 [AIService] Fixed quantity for '\(item.name)':")
                            AppLog.debug("   Original: qty=1, lineTotal=\(lineTotal)")
                            AppLog.debug("   Fixed: qty=\(detectedQty), unitPrice=\(unitPrice), name='\(cleanedName)'")
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
                    AppLog.debug("⚠️ [AIService] Rounding value seems too large: \(rounding)")
                    // Check if it should be divided by 1000
                    if abs(rounding) >= 1000 && abs(rounding) < 10000 {
                        // Might be correct, keep it
                    }
                }
                AppLog.debug("ℹ️ [AIService] Rounding: \(rounding)")
            }

            // Cross-validation: Check if items sum is close to total
            let itemsSum = fixedItems.reduce(0.0) { $0 + (($1.price ?? 0) * Double($1.quantity ?? 1)) }
            let extras = (fixedTaxAmount ?? 0) + (fixedServiceCharge ?? 0) + (fixedRounding ?? 0) - (fixedDiscount ?? 0)
            let expectedTotalWithExtras = itemsSum + extras
            let expectedTotalWithoutExtras = itemsSum + (fixedRounding ?? 0) - (fixedDiscount ?? 0)

            AppLog.debug("📊 [AIService] Cross-validation:")
            AppLog.debug("   Items sum: \(itemsSum)")
            AppLog.debug("   Tax: \(fixedTaxAmount ?? 0), Service: \(fixedServiceCharge ?? 0)")
            AppLog.debug("   Discount: \(fixedDiscount ?? 0), Rounding: \(fixedRounding ?? 0)")
            AppLog.debug("   Expected (with tax+service): \(expectedTotalWithExtras)")
            AppLog.debug("   Expected (without tax+service): \(expectedTotalWithoutExtras)")
            AppLog.debug("   Actual total: \(fixedTotalAmount)")

            if fixedTotalAmount > 0 {
                // Check if tax is informational (already included in item prices)
                let diffWithTax = abs(fixedTotalAmount - expectedTotalWithExtras)
                let diffWithoutTax = abs(fixedTotalAmount - expectedTotalWithoutExtras)

                // If total matches items WITHOUT tax better than WITH tax,
                // then tax is probably informational (set to null)
                if diffWithoutTax < diffWithTax && diffWithoutTax < fixedTotalAmount * 0.05 {
                    if fixedTaxAmount != nil && fixedTaxAmount! > 0 {
                        AppLog.debug("ℹ️ [AIService] Tax appears to be INFORMATIONAL (already in prices)")
                        AppLog.debug("   Setting taxAmount to null")
                        fixedTaxAmount = nil
                    }
                    if fixedServiceCharge != nil && fixedServiceCharge! > 0 {
                        // Also check service charge
                        let diffWithoutService = abs(fixedTotalAmount - itemsSum + (fixedRounding ?? 0) - (fixedDiscount ?? 0))
                        if diffWithoutService < fixedTotalAmount * 0.05 {
                            AppLog.debug("ℹ️ [AIService] Service charge appears to be INFORMATIONAL")
                            AppLog.debug("   Setting serviceCharge to null")
                            fixedServiceCharge = nil
                        }
                    }
                }

                // Final validation
                let finalExpected = itemsSum + (fixedTaxAmount ?? 0) + (fixedServiceCharge ?? 0) + (fixedRounding ?? 0) - (fixedDiscount ?? 0)
                let finalDiff = abs(fixedTotalAmount - finalExpected)
                let tolerance = fixedTotalAmount * 0.1  // 10% tolerance

                if finalDiff > tolerance {
                    AppLog.debug("⚠️ [AIService] WARNING: Total (\(fixedTotalAmount)) doesn't match calculated (\(finalExpected))")
                    AppLog.debug("   Difference: \(finalDiff) (tolerance: \(tolerance))")
                } else {
                    AppLog.debug("✅ [AIService] Validation passed: Total matches calculated amount")
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

        AppLog.debug("🎉 [AIService] Parsing completed successfully!")
        return result
    }

    // MARK: - Encode Image for Vision Input
    /// Downscales and JPEG-encodes the receipt photo for the multimodal API.
    /// Drawing through UIGraphicsImageRenderer also bakes the camera
    /// orientation into the pixels. 2048px is plenty: the API's high-detail
    /// pipeline rescales larger images anyway.
    private func encodeImageForVision(_ image: UIImage?, maxDimension: CGFloat = 2048) -> String? {
        guard let image = image else { return nil }

        let largest = max(image.size.width, image.size.height)
        let ratio = largest > maxDimension ? maxDimension / largest : 1.0
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: newSize, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }

        guard let jpegData = resized.jpegData(compressionQuality: 0.6) else {
            AppLog.debug("⚠️ [AIService] Could not JPEG-encode receipt photo, sending text only")
            return nil
        }
        AppLog.debug("🖼️ [AIService] Receipt photo encoded: \(Int(newSize.width))x\(Int(newSize.height)), \(jpegData.count / 1024) KB")
        return jpegData.base64EncodedString()
    }

    // MARK: - Perform Chat Request
    /// Sends one chat-completion request with a generous timeout and a single
    /// automatic retry for transient failures (rate limit, server error,
    /// timeout, dropped connection) — common on mobile networks.
    private func performChatRequest(body: [String: Any]) async throws -> OpenAIResponse {
        guard let url = URL(string: apiEndpoint) else {
            AppLog.debug("❌ [AIService] Invalid API endpoint")
            throw AppError.unknown("Invalid API endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120  // reasoning + long receipts can exceed the default 60s
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let maxAttempts = 2
        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    AppLog.debug("❌ [AIService] Invalid HTTP response")
                    throw AppError.unknown("Invalid response")
                }

                AppLog.debug("📡 [AIService] Response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    return try JSONDecoder().decode(OpenAIResponse.self, from: data)
                }

                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                let isTransient = httpResponse.statusCode == 429 || httpResponse.statusCode >= 500
                if isTransient && attempt < maxAttempts {
                    AppLog.debug("⚠️ [AIService] Transient API error (\(httpResponse.statusCode)), retrying...")
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    continue
                }
                AppLog.debug("❌ [AIService] API Error (\(httpResponse.statusCode)): \(errorMessage)")
                throw AppError.unknown("API Error (\(httpResponse.statusCode)): \(errorMessage)")
            } catch let error as URLError {
                let isTransient = error.code == .timedOut || error.code == .networkConnectionLost
                if isTransient && attempt < maxAttempts {
                    AppLog.debug("⚠️ [AIService] Network error (\(error.code.rawValue)), retrying...")
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    continue
                }
                throw error
            }
        }

        // Unreachable: the loop always returns or throws on the last attempt
        throw AppError.unknown("Request failed")
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
                AppLog.debug("   🔍 [extractQty] Pattern 1 matched: '\(trimmedName)' -> qty=\(qty), name='\(cleanedName)'")
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
                AppLog.debug("   🔍 [extractQty] Pattern 2 matched: '\(trimmedName)' -> qty=\(qty), name='\(cleanedName)'")
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
                AppLog.debug("   🔍 [extractQty] Pattern 3 matched: '\(trimmedName)' -> qty=\(qty), name='\(cleanedName)'")
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
            AppLog.debug("ℹ️ [AIService] SKIP FIX: \(context) = \(amount) (legitimate cheap item)")
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
                AppLog.debug("⚠️ [AIService] AUTO-FIX: \(context) \(amount) → \(fixed) (×1000)")
            }
        }

        // Case 2: Check for suspicious decimal patterns in larger numbers
        // e.g., 131.5 likely means 131500
        let decimalPart = amount.truncatingRemainder(dividingBy: 1)
        if decimalPart > 0 && decimalPart < 1 && amount < 10000 && !isCheapItem {
            // Small number with decimal - likely wrong
            fixed = amount * 1000
            AppLog.debug("⚠️ [AIService] AUTO-FIX (decimal): \(context) \(amount) → \(fixed) (×1000)")
        }

        return fixed
    }

    // MARK: - Create Mock Parsed Receipt (Fallback untuk struk Indonesia)
    private func createMockParsedReceipt(from ocrText: String) -> ParsedReceiptModel {
        AppLog.debug("🔄 [AIService] Using fallback mock parser for Indonesian receipt")

        // Extract merchant name (first non-empty line)
        let lines = ocrText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let merchantName = lines.first ?? "Merchant Tidak Diketahui"
        AppLog.debug("   📝 Merchant: \(merchantName)")

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
            AppLog.debug("   💰 Total found: \(totalAmount)")
        } else {
            AppLog.debug("   ⚠️ Total not found in receipt")
        }

        // Detect currency (Indonesia)
        let currency = ocrText.lowercased().contains("rp") || ocrText.lowercased().contains("idr") ? "Rp" : "USD"

        // Try to extract items dengan format Indonesia
        var items: [ReceiptItem] = []
        // Pattern: Nama item diikuti harga (dengan atau tanpa quantity)
        let itemPattern = #"([A-Za-z][A-Za-z\s]{2,30})\s+(?:x?\d+\s+)?([0-9]{1,3}(?:\.[0-9]{3})+)"#

        if let itemRegex = try? NSRegularExpression(pattern: itemPattern) {
            let matches = itemRegex.matches(in: ocrText, range: NSRange(ocrText.startIndex..., in: ocrText))
            AppLog.debug("   📦 Found \(matches.count) potential items")

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
                        AppLog.debug("      ✓ \(name) - Rp \(price)")
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

        AppLog.debug("   🏷️  Category: \(category ?? "nil")")

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

        AppLog.debug("✅ [AIService] Mock parsing completed")
        return result
    }
}

// MARK: - OpenAI Response Models
private struct OpenAIResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Codable {
        // Optional: some responses (e.g. refusals) come back without content;
        // a non-optional field would fail decoding with a misleading error
        let content: String?
    }
}
