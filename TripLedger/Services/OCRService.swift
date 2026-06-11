import Foundation
import Vision
import UIKit

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

    // MARK: - Recognize text in image (async)
    func recognizeText(in image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw AppError.unknown("Invalid image.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let fullText = lines.joined(separator: "\n")
                continuation.resume(returning: OCRResult(fullText: fullText, lines: lines, parsedReceipt: nil))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

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
