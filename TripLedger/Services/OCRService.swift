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

    // MARK: - Prepare Image for OCR (orientation + consistent resolution)
    /// Bakes UIImage orientation into the pixels (camera photos come in as .right,
    /// gallery photos as .up) and downscales very large images so both sources
    /// reach Vision in the same, correct orientation and at the same resolution.
    /// maxDimension 4096: long receipts are tall images — downscaling them
    /// shrinks each text line the most, exactly where OCR needs resolution.
    /// 4096 leaves typical iPhone photos (3024x4032) untouched.
    private func prepareImageForOCR(_ image: UIImage, maxDimension: CGFloat = 4096) -> UIImage {
        let size = image.size
        let largest = max(size.width, size.height)
        let ratio = largest > maxDimension ? maxDimension / largest : 1.0
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        // Nothing to fix: already upright and within size limit
        if image.imageOrientation == .up && ratio == 1.0 {
            return image
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let prepared = UIGraphicsImageRenderer(size: newSize, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        print("   ✓ Prepared image: orientation \(image.imageOrientation.rawValue) → up, \(Int(size.width))x\(Int(size.height)) → \(Int(newSize.width))x\(Int(newSize.height))")
        return prepared
    }

    // MARK: - Preprocess Image for Better OCR
    private func preprocessImage(_ image: UIImage) -> UIImage {
        print("🔧 [OCRService] Preprocessing image...")

        // 1. Normalize orientation and resolution (consistent for camera & gallery)
        let preparedImage = prepareImageForOCR(image)

        guard let ciImage = CIImage(image: preparedImage) else {
            print("   ⚠️ Could not create CIImage, using original")
            return preparedImage
        }

        let context = CIContext(options: nil)
        var processedImage = ciImage

        // 2. Flatten perspective: tilted/curved receipt photos are the main
        // source of scrambled row order in OCR output
        processedImage = correctPerspective(processedImage)

        // 3. Convert to grayscale for cleaner text recognition
        if let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono") {
            grayscaleFilter.setValue(processedImage, forKey: kCIInputImageKey)
            if let output = grayscaleFilter.outputImage {
                processedImage = output
                print("   ✓ Applied grayscale filter")
            }
        }

        // 4. Increase contrast for sharper text
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

        // 5. Sharpen edges for better text clarity
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

        print("   ⚠️ Could not create final image, using prepared original")
        return preparedImage
    }

    // MARK: - Perspective Correction
    /// Detects the receipt's outline (document segmentation) and flattens the
    /// perspective so text rows become horizontal. Skipped when no confident
    /// quad is found or the quad is implausibly small (bad detection).
    private func correctPerspective(_ ciImage: CIImage) -> CIImage {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              observation.confidence > 0.8 else {
            print("   ℹ️ No confident document quad, skipping perspective correction")
            return ciImage
        }

        // Sanity check on the normalized quad area (shoelace formula) so a bad
        // detection can't crop away most of the receipt
        let quad = [observation.topLeft, observation.topRight,
                    observation.bottomRight, observation.bottomLeft]
        var area: CGFloat = 0
        for i in 0..<4 {
            let p = quad[i]
            let q = quad[(i + 1) % 4]
            area += p.x * q.y - q.x * p.y
        }
        area = abs(area) / 2
        guard area > 0.1 else {
            print("   ℹ️ Document quad too small (\(area)), skipping perspective correction")
            return ciImage
        }

        // Both Vision quads and CIImage use a lower-left origin
        let extent = ciImage.extent
        func denormalize(_ point: CGPoint) -> CGPoint {
            CGPoint(x: extent.origin.x + point.x * extent.width,
                    y: extent.origin.y + point.y * extent.height)
        }

        let corrected = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: denormalize(observation.topLeft)),
            "inputTopRight": CIVector(cgPoint: denormalize(observation.topRight)),
            "inputBottomLeft": CIVector(cgPoint: denormalize(observation.bottomLeft)),
            "inputBottomRight": CIVector(cgPoint: denormalize(observation.bottomRight))
        ])
        print("   ✓ Applied perspective correction (quad area \(Int(area * 100))% of image)")
        return corrected
    }

    // MARK: - Recognize text in image (async)
    func recognizeText(in image: UIImage) async throws -> OCRResult {
        // Preprocess image for better OCR accuracy
        let processedImage = preprocessImage(image)

        guard let cgImage = processedImage.cgImage else {
            throw AppError.unknown("Invalid image.")
        }

        let request = VNRecognizeTextRequest()

        // Configure for maximum accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true  // required for customWords to take effect

        // Prioritize Indonesian, but only request languages this device/OS
        // actually supports — an unsupported language can make perform() fail
        let preferredLanguages = ["id-ID", "en-US"]
        if let supported = try? request.supportedRecognitionLanguages(), !supported.isEmpty {
            let usable = preferredLanguages.filter { supported.contains($0) }
            request.recognitionLanguages = usable.isEmpty ? ["en-US"] : usable
            if usable.count < preferredLanguages.count {
                print("   ℹ️ OCR languages narrowed to \(request.recognitionLanguages) (device support)")
            }
        } else {
            request.recognitionLanguages = preferredLanguages
        }
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

        return try await withCheckedThrowingContinuation { continuation in
            // OCR blocks for 1-2s on a full receipt; keep it off the Swift
            // concurrency thread pool. Reading request.results after perform()
            // (instead of a completion handler) guarantees a single resume path.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []
                    // Rebuild physical receipt rows from observation positions:
                    // item name (left column) and price (right column) often
                    // come back as separate observations, and on long receipts
                    // their order scrambles — pairing them by Y position keeps
                    // "Nama Item  12.000" on one line for the AI parser
                    let lines = self.reconstructLines(from: observations)
                    continuation.resume(returning: OCRResult(
                        fullText: lines.joined(separator: "\n"),
                        lines: lines,
                        parsedReceipt: nil
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Reconstruct Physical Lines
    /// Groups text observations into physical receipt rows by vertical position,
    /// then orders each row left-to-right. Vision's raw observation order does
    /// not guarantee that fragments of the same printed line stay adjacent.
    /// boundingBox is normalized with Y pointing up, so higher midY = higher row.
    private func reconstructLines(from observations: [VNRecognizedTextObservation]) -> [String] {
        struct Fragment {
            let text: String
            let box: CGRect
        }

        let fragments = observations.compactMap { obs -> Fragment? in
            // Candidates are sorted by confidence; the first is the best
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            return Fragment(text: text, box: obs.boundingBox)
        }

        // Curved/tilted receipts shift the price column vertically by up to
        // half a line height versus the item name, so midY distance cannot
        // separate "same printed line, shifted" from "the next printed line".
        // Vertical overlap can: a shifted price still overlaps its name's box,
        // while the next line's name does not overlap at all.
        func verticalOverlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
            let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
            guard overlap > 0 else { return 0 }
            return overlap / min(a.height, b.height)
        }

        // Assign each fragment (top of receipt first) to the row it overlaps
        // most. A fragment must overlap EVERY fragment already in the row
        // (min, not max): on skewed photos the shifted price of line n also
        // overlaps the name of line n+1 — matching against any single member
        // would chain entire blocks of lines into one giant row.
        var rows: [[Fragment]] = []
        for fragment in fragments.sorted(by: { $0.box.midY > $1.box.midY }) {
            var bestRow = -1
            var bestOverlap: CGFloat = 0.3
            for (index, row) in rows.enumerated() {
                let rowOverlap = row.map { verticalOverlap($0.box, fragment.box) }.min() ?? 0
                if rowOverlap > bestOverlap {
                    bestOverlap = rowOverlap
                    bestRow = index
                }
            }
            if bestRow >= 0 {
                rows[bestRow].append(fragment)
            } else {
                rows.append([fragment])
            }
        }

        // Order rows top-to-bottom, fragments within a row left-to-right
        let orderedRows = rows.sorted { rowA, rowB in
            let midA = rowA.reduce(0) { $0 + $1.box.midY } / CGFloat(rowA.count)
            let midB = rowB.reduce(0) { $0 + $1.box.midY } / CGFloat(rowB.count)
            return midA > midB
        }

        return orderedRows.map { row in
            let text = row.sorted { $0.box.minX < $1.box.minX }
                .map(\.text)
                .joined(separator: "  ")
            return cleanNumberSpacing(in: text)
        }
    }

    // MARK: - Clean Number Spacing
    /// OCR often splits one price into fragments ("84" + ", 000" or "129, 000");
    /// re-join digit groups so the AI sees "84,000" instead of "84 , 000".
    /// Applied repeatedly for numbers split more than once ("1, 931, 200").
    private func cleanNumberSpacing(in line: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\d)\s*([.,])\s*(\d{3})"#) else { return line }
        var result = line
        while true {
            let range = NSRange(result.startIndex..., in: result)
            let joined = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1$2$3")
            if joined == result { break }
            result = joined
        }
        return result
    }

    // MARK: - Scan Phase (drives UI progress)
    enum ScanPhase {
        case ocr  // reading text from the image
        case ai   // AI is parsing the text + photo
    }

    // MARK: - Recognize and Parse Receipt (OCR + AI)
    func recognizeAndParseReceipt(in image: UIImage, onPhase: ((ScanPhase) -> Void)? = nil) async throws -> OCRResult {
        print("\n🚀 ========== STARTING RECEIPT SCAN ==========")
        print("📸 [OCRService] Image size: \(image.size.width) x \(image.size.height)")

        // Step 1: Perform OCR
        print("👁️ [OCRService] Step 1: Running OCR text recognition...")
        onPhase?(.ocr)
        var result = try await recognizeText(in: image)

        print("✅ [OCRService] OCR completed - Found \(result.lines.count) lines")

        // Step 2: Parse with AI
        guard !result.fullText.isEmpty else {
            print("❌ [OCRService] Error: No text detected in image")
            throw AppError.unknown("No text detected in image.")
        }

        print("🤖 [OCRService] Step 2: Sending to AI parser...")
        onPhase?(.ai)
        do {
            let parsedReceipt = try await AIService.shared.parseReceipt(from: result.fullText, image: image)
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
