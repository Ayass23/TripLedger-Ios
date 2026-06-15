import Foundation
import PDFKit
import UIKit

class PDFGenerator {

    // MARK: - Colors (Matching App Theme)
    private static let primaryColor = UIColor(hexString: "#433075")   // Deep Purple
    private static let accentColor = UIColor(hexString: "#A58CF4")    // Lavender
    private static let textPrimary = UIColor(hexString: "#0D0D0D")    // Jet Black
    private static let textSecondary = UIColor(hexString: "#0D0D0D").withAlphaComponent(0.65)
    private static let backgroundColor = UIColor.white
    private static let successGreen = UIColor(hexString: "#22C55E")
    private static let warningAmber = UIColor(hexString: "#F59E0B")
    private static let errorRed = UIColor(hexString: "#E5484D")
    private static let surfaceElevated = UIColor(hexString: "#F4F1FF")

    // MARK: - Generate Expense PDF
    static func generateExpensePDF(
        expense: ExpenseModel,
        currency: String,
        paidAmount: Double,
        isFullySettled: Bool
    ) -> URL? {

        let pdfMetaData = [
            kCGPDFContextCreator: "TripLedger",
            kCGPDFContextAuthor: expense.paidByName,
            kCGPDFContextTitle: "Detail Pengeluaran - \(expense.title)"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { (context) in
            context.beginPage()

            var currentY: CGFloat = 40

            // MARK: - Header with Logo
            currentY = drawHeader(in: pageRect, startY: currentY)
            currentY += 20

            // MARK: - Title Section
            currentY = drawExpenseTitle(expense: expense, currency: currency, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Payment Information
            currentY = drawSectionTitle("Informasi Pembayaran", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawInfoRow(label: "Dibayar oleh", value: expense.paidByName, in: pageRect, startY: currentY)

            // Add bank account if available
            if let paidByBankAccount = expense.paidByBankAccount, !paidByBankAccount.isEmpty {
                currentY += 8
                currentY = drawInfoRow(label: "Rekening", value: paidByBankAccount, in: pageRect, startY: currentY)
            }

            currentY += 8
            currentY = drawInfoRow(label: "Kategori", value: expense.category.rawValue, in: pageRect, startY: currentY)
            currentY += 8
            currentY = drawInfoRow(label: "Total Pengeluaran", value: formatCurrency(expense.amount, symbol: currency), in: pageRect, startY: currentY, valueColor: primaryColor, valueBold: true)
            currentY += 25

            // MARK: - Progress Section
            currentY = drawSectionTitle("Status Pembayaran", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawProgressBar(paidAmount: paidAmount, totalAmount: expense.amount, isFullySettled: isFullySettled, currency: currency, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Participants List
            currentY = drawSectionTitle("Daftar Patungan", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawExpenseParticipants(splits: expense.splits, currency: currency, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Footer
            drawFooter(in: pageRect)

            // MARK: - Receipt Image (New Page)
            if let receiptURL = expense.receiptURL, !receiptURL.isEmpty {
                context.beginPage()
                drawReceiptPage(receiptURL: receiptURL, in: pageRect, title: "Foto Struk/Nota")
            }
        }

        // Save to temp directory
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TripLedger_Expense_\(expense.id ?? UUID().uuidString).pdf")

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("❌ Error saving PDF: \(error)")
            return nil
        }
    }

    // MARK: - Generate Split Bill PDF
    static func generateSplitBillPDF(
        bill: SplitBillModel
    ) -> URL? {

        let pdfMetaData = [
            kCGPDFContextCreator: "TripLedger",
            kCGPDFContextAuthor: bill.ownerName,
            kCGPDFContextTitle: "Detail Tagihan - \(bill.title)"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { (context) in
            context.beginPage()

            var currentY: CGFloat = 40

            // MARK: - Header with Logo
            currentY = drawHeader(in: pageRect, startY: currentY)
            currentY += 20

            // MARK: - Title Section
            currentY = drawBillTitle(bill: bill, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Bill Information
            currentY = drawSectionTitle("Informasi Tagihan", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawInfoRow(label: "Dibuat oleh", value: bill.ownerName, in: pageRect, startY: currentY)

            // Add bank account if available
            if let ownerBankAccount = bill.ownerBankAccount, !ownerBankAccount.isEmpty {
                currentY += 8
                currentY = drawInfoRow(label: "Rekening Penerima", value: ownerBankAccount, in: pageRect, startY: currentY)
            }

            currentY += 8
            currentY = drawInfoRow(label: "Jumlah Peserta", value: "\(bill.participants.count) orang", in: pageRect, startY: currentY)
            currentY += 8
            currentY = drawInfoRow(label: "Total Tagihan", value: formatCurrency(bill.totalAmount, symbol: bill.currency), in: pageRect, startY: currentY, valueColor: primaryColor, valueBold: true)
            currentY += 25

            // MARK: - Progress Section
            currentY = drawSectionTitle("Status Pembayaran", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawProgressBar(paidAmount: bill.paidAmount, totalAmount: bill.totalAmount, isFullySettled: bill.isFullySettled, currency: bill.currency, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Participants List with Details
            currentY = drawSectionTitle("Rincian Per Peserta", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawBillParticipantsWithDetails(participants: bill.participants, notes: bill.notes, currency: bill.currency, totalAmount: bill.totalAmount, in: pageRect, startY: currentY, context: context)
            currentY += 30

            // MARK: - Footer
            drawFooter(in: pageRect)

            // MARK: - Receipt Image (New Page)
            if let receiptURL = bill.receiptURL, !receiptURL.isEmpty {
                context.beginPage()
                drawReceiptPage(receiptURL: receiptURL, in: pageRect, title: "Foto Struk/Nota")
            }
        }

        // Save to temp directory
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TripLedger_Bill_\(bill.id ?? UUID().uuidString).pdf")

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("❌ Error saving PDF: \(error)")
            return nil
        }
    }

    // MARK: - Drawing Helper Functions

    private static func drawHeader(in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        // Draw App Icon logo
        if let logo = getAppIcon() {
            let logoSize: CGFloat = 50
            let logoRect = CGRect(x: 40, y: currentY, width: logoSize, height: logoSize)

            // Draw rounded corner background for logo
            let cornerRadius: CGFloat = 12
            let backgroundPath = UIBezierPath(roundedRect: logoRect, cornerRadius: cornerRadius)
            UIColor.white.setFill()
            backgroundPath.fill()

            // Clip to rounded rect and draw logo
            UIGraphicsGetCurrentContext()?.saveGState()
            backgroundPath.addClip()
            logo.draw(in: logoRect)
            UIGraphicsGetCurrentContext()?.restoreGState()

            // Optional: Add border around logo
            primaryColor.withAlphaComponent(0.2).setStroke()
            backgroundPath.lineWidth = 1
            backgroundPath.stroke()
        }

        // App name
        let appNameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: primaryColor
        ]
        let appName = "TripLedger"
        appName.draw(at: CGPoint(x: 100, y: currentY + 10), withAttributes: appNameAttrs)

        // Tagline
        let taglineAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: textSecondary
        ]
        let tagline = "Kelola Pengeluaran Perjalanan Bersama"
        tagline.draw(at: CGPoint(x: 100, y: currentY + 35), withAttributes: taglineAttrs)

        currentY += 65

        // Divider line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: 40, y: currentY))
        linePath.addLine(to: CGPoint(x: pageRect.width - 40, y: currentY))
        primaryColor.setStroke()
        linePath.lineWidth = 2
        linePath.stroke()

        return currentY + 5
    }

    // MARK: - Get App Icon
    private static func getAppIcon() -> UIImage? {
        // Try to load from asset catalog first
        if let appIcon = UIImage(named: "logo tripledger") {
            return appIcon
        }

        // Fallback: Try to get app icon from bundle
        if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last,
           let appIcon = UIImage(named: lastIcon) {
            return appIcon
        }

        return nil
    }

    private static func drawExpenseTitle(expense: ExpenseModel, currency: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        // Icon circle background
        let iconSize: CGFloat = 60
        let iconX = (pageRect.width - iconSize) / 2
        let iconRect = CGRect(x: iconX, y: currentY, width: iconSize, height: iconSize)

        // Draw colored circle
        let circlePath = UIBezierPath(ovalIn: iconRect)
        UIColor(hexString: expense.category.color).withAlphaComponent(0.15).setFill()
        circlePath.fill()

        currentY += iconSize + 15

        // Expense title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: textPrimary
        ]
        let titleSize = expense.title.size(withAttributes: titleAttrs)
        let titleX = (pageRect.width - titleSize.width) / 2
        expense.title.draw(at: CGPoint(x: titleX, y: currentY), withAttributes: titleAttrs)

        currentY += titleSize.height + 10

        // Amount
        let amountText = formatCurrency(expense.amount, symbol: currency)
        let amountAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: primaryColor
        ]
        let amountSize = amountText.size(withAttributes: amountAttrs)
        let amountX = (pageRect.width - amountSize.width) / 2
        amountText.draw(at: CGPoint(x: amountX, y: currentY), withAttributes: amountAttrs)

        return currentY + amountSize.height
    }

    private static func drawBillTitle(bill: SplitBillModel, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        // Icon circle background
        let iconSize: CGFloat = 60
        let iconX = (pageRect.width - iconSize) / 2
        let iconRect = CGRect(x: iconX, y: currentY, width: iconSize, height: iconSize)

        // Draw colored circle
        let circlePath = UIBezierPath(ovalIn: iconRect)
        primaryColor.withAlphaComponent(0.15).setFill()
        circlePath.fill()

        currentY += iconSize + 15

        // Bill title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: textPrimary
        ]
        let titleSize = bill.title.size(withAttributes: titleAttrs)
        let titleX = (pageRect.width - titleSize.width) / 2
        bill.title.draw(at: CGPoint(x: titleX, y: currentY), withAttributes: titleAttrs)

        currentY += titleSize.height + 10

        // Amount
        let amountText = formatCurrency(bill.totalAmount, symbol: bill.currency)
        let amountAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: primaryColor
        ]
        let amountSize = amountText.size(withAttributes: amountAttrs)
        let amountX = (pageRect.width - amountSize.width) / 2
        amountText.draw(at: CGPoint(x: amountX, y: currentY), withAttributes: amountAttrs)

        return currentY + amountSize.height
    }

    private static func drawSectionTitle(_ title: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: textPrimary
        ]
        title.draw(at: CGPoint(x: 40, y: startY), withAttributes: attrs)
        return startY + title.size(withAttributes: attrs).height
    }

    private static func drawInfoRow(label: String, value: String, in pageRect: CGRect, startY: CGFloat, valueColor: UIColor = textPrimary, valueBold: Bool = false) -> CGFloat {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: textSecondary
        ]
        label.draw(at: CGPoint(x: 60, y: startY), withAttributes: labelAttrs)

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: valueBold ? UIFont.boldSystemFont(ofSize: 14) : UIFont.systemFont(ofSize: 14),
            .foregroundColor: valueColor
        ]
        let valueX = pageRect.width - 60 - value.size(withAttributes: valueAttrs).width
        value.draw(at: CGPoint(x: valueX, y: startY - 1), withAttributes: valueAttrs)

        return startY + max(label.size(withAttributes: labelAttrs).height, value.size(withAttributes: valueAttrs).height)
    }

    private static func drawProgressBar(paidAmount: Double, totalAmount: Double, isFullySettled: Bool, currency: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        // Progress text
        let progressText = "\(formatCurrency(paidAmount, symbol: currency)) / \(formatCurrency(totalAmount, symbol: currency))"
        let progressAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: textSecondary
        ]
        progressText.draw(at: CGPoint(x: 60, y: currentY), withAttributes: progressAttrs)

        currentY += progressText.size(withAttributes: progressAttrs).height + 8

        // Progress bar background
        let barWidth = pageRect.width - 120
        let barHeight: CGFloat = 12
        let barRect = CGRect(x: 60, y: currentY, width: barWidth, height: barHeight)

        let backgroundPath = UIBezierPath(roundedRect: barRect, cornerRadius: 6)
        UIColor.lightGray.withAlphaComponent(0.2).setFill()
        backgroundPath.fill()

        // Progress bar fill
        let ratio = totalAmount > 0 ? (paidAmount / totalAmount) : 0
        let fillWidth = barWidth * CGFloat(ratio)
        let fillRect = CGRect(x: 60, y: currentY, width: fillWidth, height: barHeight)

        let fillPath = UIBezierPath(roundedRect: fillRect, cornerRadius: 6)
        (isFullySettled ? successGreen : primaryColor).setFill()
        fillPath.fill()

        return currentY + barHeight
    }

    private static func drawExpenseParticipants(splits: [ExpenseSplit], currency: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        for split in splits {
            // Background card
            let cardRect = CGRect(x: 60, y: currentY, width: pageRect.width - 120, height: 50)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
            UIColor.systemGray6.setFill()
            cardPath.fill()

            // Initial circle
            let circleRect = CGRect(x: 70, y: currentY + 10, width: 30, height: 30)
            let circlePath = UIBezierPath(ovalIn: circleRect)
            accentColor.withAlphaComponent(0.15).setFill()
            circlePath.fill()

            // Initial letter
            let initial = String(split.displayName.prefix(1)).uppercased()
            let initialAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: accentColor
            ]
            let initialSize = initial.size(withAttributes: initialAttrs)
            initial.draw(at: CGPoint(x: 70 + (30 - initialSize.width) / 2, y: currentY + 10 + (30 - initialSize.height) / 2), withAttributes: initialAttrs)

            // Name
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: textPrimary
            ]
            split.displayName.draw(at: CGPoint(x: 110, y: currentY + 13), withAttributes: nameAttrs)

            // Amount
            let amountAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: textSecondary
            ]
            let amountText = formatCurrency(split.amount, symbol: currency)
            amountText.draw(at: CGPoint(x: 110, y: currentY + 28), withAttributes: amountAttrs)

            // Status badge
            let statusText = split.isPaid == true ? "✓ Lunas" : "⏳ Belum"
            let statusColor = split.isPaid == true ? successGreen : warningAmber
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: statusColor
            ]
            let statusSize = statusText.size(withAttributes: statusAttrs)
            let statusX = pageRect.width - 80 - statusSize.width
            statusText.draw(at: CGPoint(x: statusX, y: currentY + 20), withAttributes: statusAttrs)

            currentY += 55
        }

        return currentY
    }

    private static func drawBillParticipantsWithDetails(participants: [SplitBillParticipant], notes: String?, currency: String, totalAmount: Double, in pageRect: CGRect, startY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = startY
        let pageHeight = pageRect.height

        for participant in participants {
            // Check if we need a new page
            if currentY > pageHeight - 150 {
                context.beginPage()
                currentY = 40
            }

            // Background card
            let cardHeight = calculateParticipantCardHeight(participant: participant, notes: notes, currency: currency, totalAmount: totalAmount, pageWidth: pageRect.width)
            let cardRect = CGRect(x: 60, y: currentY, width: pageRect.width - 120, height: cardHeight)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
            UIColor.systemGray6.setFill()
            cardPath.fill()

            var cardY = currentY + 10

            // Initial circle
            let circleRect = CGRect(x: 70, y: cardY, width: 30, height: 30)
            let circlePath = UIBezierPath(ovalIn: circleRect)
            accentColor.withAlphaComponent(0.15).setFill()
            circlePath.fill()

            // Initial letter
            let initial = String(participant.displayName.prefix(1)).uppercased()
            let initialAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: accentColor
            ]
            let initialSize = initial.size(withAttributes: initialAttrs)
            initial.draw(at: CGPoint(x: 70 + (30 - initialSize.width) / 2, y: cardY + (30 - initialSize.height) / 2), withAttributes: initialAttrs)

            // Name
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 13),
                .foregroundColor: textPrimary
            ]
            participant.displayName.draw(at: CGPoint(x: 110, y: cardY + 3), withAttributes: nameAttrs)

            // Total amount
            let amountAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: primaryColor
            ]
            let amountText = formatCurrency(participant.amount, symbol: currency)
            amountText.draw(at: CGPoint(x: 110, y: cardY + 18), withAttributes: amountAttrs)

            // Status badge
            let statusText = participant.isPaid ? "✓ Lunas" : "⏳ Belum"
            let statusColor = participant.isPaid ? successGreen : warningAmber
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: statusColor
            ]
            let statusSize = statusText.size(withAttributes: statusAttrs)
            let statusX = pageRect.width - 80 - statusSize.width
            statusText.draw(at: CGPoint(x: statusX, y: cardY + 12), withAttributes: statusAttrs)

            cardY += 45

            // Draw items if available
            if let notes = notes {
                let items = extractParticipantItems(from: notes, participantName: participant.displayName, currency: currency)
                if !items.isEmpty {
                    // Divider
                    let dividerPath = UIBezierPath()
                    dividerPath.move(to: CGPoint(x: 70, y: cardY))
                    dividerPath.addLine(to: CGPoint(x: pageRect.width - 70, y: cardY))
                    UIColor.lightGray.withAlphaComponent(0.3).setStroke()
                    dividerPath.lineWidth = 1
                    dividerPath.stroke()

                    cardY += 10

                    // Items title
                    let itemsTitleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 10),
                        .foregroundColor: textSecondary
                    ]
                    "Rincian Pembayaran:".draw(at: CGPoint(x: 75, y: cardY), withAttributes: itemsTitleAttrs)
                    cardY += 15

                    // Draw items
                    for item in items {
                        let itemAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 10),
                            .foregroundColor: textPrimary
                        ]
                        let bullet = "• "
                        bullet.draw(at: CGPoint(x: 75, y: cardY), withAttributes: itemAttrs)
                        item.draw(at: CGPoint(x: 85, y: cardY), withAttributes: itemAttrs)
                        cardY += 14
                    }

                    // Tax and service
                    let charges = extractTaxAndServiceCharges(from: notes)
                    if charges.tax > 0 || charges.service > 0 {
                        let share = calculateTaxShare(participant: participant, totalTax: charges.tax, totalService: charges.service, totalAmount: totalAmount)

                        cardY += 5

                        if share.tax > 0 {
                            let taxText = "• Pajak/PPN - \(currency) \(formatAmount(share.tax))"
                            let taxAttrs: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 9),
                                .foregroundColor: textSecondary
                            ]
                            taxText.draw(at: CGPoint(x: 75, y: cardY), withAttributes: taxAttrs)
                            cardY += 12
                        }

                        if share.service > 0 {
                            let serviceText = "• Service Charge - \(currency) \(formatAmount(share.service))"
                            let serviceAttrs: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 9),
                                .foregroundColor: textSecondary
                            ]
                            serviceText.draw(at: CGPoint(x: 75, y: cardY), withAttributes: serviceAttrs)
                            cardY += 12
                        }
                    }
                }
            }

            currentY += cardHeight + 10
        }

        return currentY
    }

    private static func calculateParticipantCardHeight(participant: SplitBillParticipant, notes: String?, currency: String, totalAmount: Double, pageWidth: CGFloat) -> CGFloat {
        var height: CGFloat = 55

        if let notes = notes {
            let items = extractParticipantItems(from: notes, participantName: participant.displayName, currency: currency)
            if !items.isEmpty {
                height += 25 // divider + title
                height += CGFloat(items.count) * 14

                let charges = extractTaxAndServiceCharges(from: notes)
                if charges.tax > 0 || charges.service > 0 {
                    height += 5
                    if charges.tax > 0 { height += 12 }
                    if charges.service > 0 { height += 12 }
                }

                height += 10 // bottom padding
            }
        }

        return height
    }

    private static func drawFooter(in pageRect: CGRect) {
        let footerY = pageRect.height - 40

        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: textSecondary
        ]

        let footerText = "Generated by TripLedger - Kelola Pengeluaran Perjalanan Bersama"
        let footerSize = footerText.size(withAttributes: footerAttrs)
        let footerX = (pageRect.width - footerSize.width) / 2
        footerText.draw(at: CGPoint(x: footerX, y: footerY), withAttributes: footerAttrs)

        let dateText = "Generated on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        let dateSize = dateText.size(withAttributes: footerAttrs)
        let dateX = (pageRect.width - dateSize.width) / 2
        dateText.draw(at: CGPoint(x: dateX, y: footerY + 12), withAttributes: footerAttrs)
    }

    // MARK: - Draw Receipt Page
    private static func drawReceiptPage(receiptURL: String, in pageRect: CGRect, title: String) {
        var currentY: CGFloat = 40

        // Page title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: primaryColor
        ]
        let titleSize = title.size(withAttributes: titleAttrs)
        let titleX = (pageRect.width - titleSize.width) / 2
        title.draw(at: CGPoint(x: titleX, y: currentY), withAttributes: titleAttrs)

        currentY += titleSize.height + 30

        // Try to load and draw receipt image
        if let url = URL(string: receiptURL),
           let imageData = try? Data(contentsOf: url),
           let receiptImage = UIImage(data: imageData) {

            // Calculate image size to fit page with padding
            let maxWidth = pageRect.width - 80  // 40px padding on each side
            let maxHeight = pageRect.height - currentY - 60  // Leave space for footer

            let imageSize = receiptImage.size
            let aspectRatio = imageSize.width / imageSize.height

            var drawWidth: CGFloat
            var drawHeight: CGFloat

            if aspectRatio > 1 {
                // Landscape image
                drawWidth = min(maxWidth, imageSize.width)
                drawHeight = drawWidth / aspectRatio
            } else {
                // Portrait image
                drawHeight = min(maxHeight, imageSize.height)
                drawWidth = drawHeight * aspectRatio
            }

            // Ensure it fits within both constraints
            if drawWidth > maxWidth {
                drawWidth = maxWidth
                drawHeight = drawWidth / aspectRatio
            }
            if drawHeight > maxHeight {
                drawHeight = maxHeight
                drawWidth = drawHeight * aspectRatio
            }

            // Center the image
            let imageX = (pageRect.width - drawWidth) / 2
            let imageRect = CGRect(x: imageX, y: currentY, width: drawWidth, height: drawHeight)

            // Draw border/frame
            let borderPath = UIBezierPath(roundedRect: imageRect, cornerRadius: 8)
            surfaceElevated.setFill()
            borderPath.fill()

            // Draw image
            receiptImage.draw(in: imageRect)

            // Draw border stroke
            primaryColor.withAlphaComponent(0.3).setStroke()
            borderPath.lineWidth = 2
            borderPath.stroke()

        } else {
            // If image fails to load, show error message
            let errorAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: errorRed
            ]
            let errorMessage = "Gagal memuat foto struk/nota"
            let errorSize = errorMessage.size(withAttributes: errorAttrs)
            let errorX = (pageRect.width - errorSize.width) / 2
            errorMessage.draw(at: CGPoint(x: errorX, y: currentY + 100), withAttributes: errorAttrs)

            let urlAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: textSecondary
            ]
            let urlText = "URL: \(receiptURL)"
            let urlSize = urlText.size(withAttributes: urlAttrs)
            let urlX = (pageRect.width - urlSize.width) / 2
            urlText.draw(at: CGPoint(x: urlX, y: currentY + 120), withAttributes: urlAttrs)
        }

        // Footer
        drawFooter(in: pageRect)
    }

    // MARK: - Helper Functions

    private static func formatCurrency(_ amount: Double, symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "\(symbol) \(formatted)"
    }

    private static func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }

    // MARK: - Parse Bill Items

    private static func extractParticipantItems(from notes: String, participantName: String, currency: String) -> [String] {
        var items: [String] = []
        let lines = notes.components(separatedBy: .newlines)

        for line in lines {
            if line.contains("•") && line.contains(":") && !line.contains("Pajak") && !line.contains("Service") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    let itemPart = parts[0].replacingOccurrences(of: "•", with: "").trimmingCharacters(in: .whitespaces)
                    let participantsPart = parts[1].trimmingCharacters(in: .whitespaces)

                    let participantNames = participantsPart.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

                    if participantNames.contains(participantName) {
                        let itemName = extractItemName(from: itemPart)
                        let totalPrice = extractTotalPrice(from: itemPart)
                        let sharePrice = totalPrice / Double(participantNames.count)

                        let shareText = participantNames.count > 1 ? " (bayar \(currency) \(formatAmount(sharePrice)))" : ""
                        items.append("\(itemName) - \(currency) \(formatAmount(totalPrice))\(shareText)")
                    }
                }
            }
        }

        return items
    }

    private static func extractItemName(from itemPart: String) -> String {
        if let parenIndex = itemPart.firstIndex(of: "(") {
            let name = String(itemPart[..<parenIndex]).trimmingCharacters(in: .whitespaces)
            return name
        }
        return itemPart
    }

    private static func extractTotalPrice(from itemPart: String) -> Double {
        if let atRange = itemPart.range(of: "@") {
            let afterAt = String(itemPart[atRange.upperBound...])
            return extractNumber(from: afterAt)
        } else {
            if let openParen = itemPart.firstIndex(of: "("),
               let closeParen = itemPart.firstIndex(of: ")") {
                let priceStr = String(itemPart[openParen...closeParen])
                return extractNumber(from: priceStr)
            }
        }
        return 0
    }

    private static func extractNumber(from text: String) -> Double {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(numbers) ?? 0
    }

    private static func extractTaxAndServiceCharges(from notes: String) -> (tax: Double, service: Double) {
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

    private static func calculateTaxShare(participant: SplitBillParticipant, totalTax: Double, totalService: Double, totalAmount: Double) -> (tax: Double, service: Double) {
        let participantItemAmount = participant.amount - (totalTax + totalService) * (participant.amount / totalAmount)
        let totalItemsAmount = totalAmount - totalTax - totalService

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

// MARK: - UIColor Extension
extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
