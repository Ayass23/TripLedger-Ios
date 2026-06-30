import Foundation
import Vision
import UIKit
import CoreImage

// MARK: - OCR Result
struct OCRResult {
    var fullText: String
    var lines:    [String]
    var parsedReceipt: ParsedReceiptModel? // AI-parsed structured data

    // Attempt to parse a total amount from recognized text
    var parsedAmount: Double? {
        // Look for patterns like "Total: 150.000" or "TOTAL Rp 75,000"
        let pattern = #"(?i)(?:total|jumlah|grand\s*total)[^0-9]*([0-9][0-9.,\s]*[0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: fullText, range: NSRange(fullText.startIndex..., in: fullText)),
              let range = Range(match.range(at: 1), in: fullText) else { return nil }

        let raw = String(fullText[range])
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        return Double(raw)
    }
}

// MARK: - OCR Service
final class OCRService {

    static let shared = OCRService()
    private init() {}

    // MARK: - Preprocess Image for Better OCR
    private func preprocessImage(_ image: UIImage) -> UIImage {
        print("🔧 [OCRService] Preprocessing image...")

        guard let ciImage = CIImage(image: image) else {
            print("   ⚠️ Could not create CIImage, using original")
            return image
        }

        let context = CIContext(options: nil)
        var processedImage = ciImage

        // 1. Auto-adjust orientation (fix rotation issues)
        processedImage = processedImage.oriented(forExifOrientation: Int32(image.imageOrientation.rawValue))

        // 2. Convert to grayscale for cleaner text recognition
        if let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono") {
            grayscaleFilter.setValue(processedImage, forKey: kCIInputImageKey)
            if let output = grayscaleFilter.outputImage {
                processedImage = output
                print("   ✓ Applied grayscale filter")
            }
        }

        // 3. Increase contrast for sharper text
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.1, forKey: kCIInputContrastKey)  // Slight contrast boost
            contrastFilter.setValue(0.0, forKey: kCIInputSaturationKey)  // Keep grayscale
            contrastFilter.setValue(0.05, forKey: kCIInputBrightnessKey)  // Slight brightness boost
            if let output = contrastFilter.outputImage {
                processedImage = output
                print("   ✓ Applied contrast enhancement")
            }
        }

        // 4. Sharpen edges for better text clarity
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.4, forKey: kCIInputSharpnessKey)  // Moderate sharpening
            if let output = sharpenFilter.outputImage {
                processedImage = output
                print("   ✓ Applied sharpening")
            }
        }

        // Convert back to UIImage
        if let cgImage = context.createCGImage(processedImage, from: processedImage.extent) {
            print("   ✅ Preprocessing completed")
            return UIImage(cgImage: cgImage)
        }

        print("   ⚠️ Could not create final image, using original")
        return image
    }

    // MARK: - Recognize text in image (async)
    func recognizeText(in image: UIImage) async throws -> OCRResult {
        // Preprocess image for better OCR accuracy
        let processedImage = preprocessImage(image)

        guard let cgImage = processedImage.cgImage else {
            throw AppError.unknown("Invalid image.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = req.results as? [VNRecognizedTextObservation] ?? []

                // Get top 3 candidates for each observation and pick the best
                let lines = observations.compactMap { observation -> String? in
                    // Get multiple candidates and pick the one with highest confidence
                    let candidates = observation.topCandidates(3)
                    return candidates.first?.string
                }

                let fullText = lines.joined(separator: "\n")
                continuation.resume(returning: OCRResult(fullText: fullText, lines: lines, parsedReceipt: nil))
            }

            // Configure for maximum accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["id-ID", "en-US"]  // Prioritize Indonesian
            // Common Indonesian receipt words for better OCR accuracy
            request.customWords = [
                // Currency
                "Rp", "IDR",
                // Totals
                "TOTAL", "SUBTOTAL", "GRAND", "JUMLAH", "BAYAR",
                // Tax keywords (critical!)
                "PPN", "PB1", "PB 1", "PAJAK", "TAX", "VAT", "PPn",
                // Service
                "SERVICE", "SERVIS", "SC",
                // Discount
                "DISKON", "DISC", "VOUCHER", "PROMO", "POTONGAN",
                // Rounding
                "PEMBULATAN", "BULAT", "ROUNDING", "SELISIH", "ADJ",
                // Common items
                "PLASTIK", "KANTONG", "SEDOTAN"
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Recognize and Parse Receipt (OCR + AI)
    func recognizeAndParseReceipt(in image: UIImage) async throws -> OCRResult {
        print("\n🚀 ========== STARTING RECEIPT SCAN ==========")
        print("📸 [OCRService] Image size: \(image.size.width) x \(image.size.height)")

        // Step 1: Perform OCR
        print("👁️ [OCRService] Step 1: Running OCR text recognition...")
        var result = try await recognizeText(in: image)

        print("✅ [OCRService] OCR completed - Found \(result.lines.count) lines")

        // Step 2: Parse with AI
        guard !result.fullText.isEmpty else {
            print("❌ [OCRService] Error: No text detected in image")
            throw AppError.unknown("No text detected in image.")
        }

        print("🤖 [OCRService] Step 2: Sending to AI parser...")
        do {
            let parsedReceipt = try await AIService.shared.parseReceipt(from: result.fullText)
            result.parsedReceipt = parsedReceipt
            print("✅ [OCRService] AI parsing successful")
        } catch {
            // If AI parsing fails, continue with OCR result only
            print("⚠️ [OCRService] AI parsing failed: \(error.localizedDescription)")
            print("   Using OCR result only (parsedReceipt will be nil)")
            // parsedReceipt will remain nil
        }

        print("🏁 ========== RECEIPT SCAN COMPLETED ==========\n")
        return result
    }
}
