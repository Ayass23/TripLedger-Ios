import Foundation
import PDFKit
import UIKit
import FirebaseFirestore

class TripReportGenerator {

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

    // MARK: - Settlement Calculation Helpers

    /// Calculate member balances (who owes/receives money)
    private static func calculateMemberBalances(expenses: [ExpenseModel], members: [TripMember]) -> [String: Double] {
        var balances: [String: Double] = [:]

        // Initialize all members with 0
        for member in members {
            balances[member.uid] = 0
        }

        // Process each expense
        for expense in expenses {
            // Calculate total unpaid splits for this expense
            let unpaidSplits = expense.splits.filter { $0.isPaid != true }
            let totalUnpaidAmount = unpaidSplits.reduce(0) { $0 + $1.amount }

            // Only add to payer's balance if there are unpaid splits
            if totalUnpaidAmount > 0 {
                balances[expense.paidByUID, default: 0] += totalUnpaidAmount
            }

            // Subtract each person's share from their balance (ONLY if not paid)
            for split in expense.splits {
                // Skip splits that are already paid
                if split.isPaid == true { continue }

                balances[split.uid, default: 0] -= split.amount
            }
        }

        return balances
    }

    /// Calculate simplified settlements (who should pay whom)
    private static func calculateSettlements(balances: [String: Double], members: [TripMember]) -> [(from: String, to: String, amount: Double)] {
        var settlements: [(from: String, to: String, amount: Double)] = []
        var tempBalances = balances

        // Get debtors (negative balance) and creditors (positive balance)
        let debtors = tempBalances.filter { $0.value < -0.01 }.sorted { $0.value < $1.value }
        let creditors = tempBalances.filter { $0.value > 0.01 }.sorted { $0.value > $1.value }

        var debtorQueue = debtors.map { (uid: $0.key, amount: -$0.value) }
        var creditorQueue = creditors.map { (uid: $0.key, amount: $0.value) }

        while !debtorQueue.isEmpty && !creditorQueue.isEmpty {
            var debtor = debtorQueue.removeFirst()
            var creditor = creditorQueue.removeFirst()

            let settlementAmount = min(debtor.amount, creditor.amount)

            // Get names
            let debtorName = members.first(where: { $0.uid == debtor.uid })?.displayName ?? debtor.uid
            let creditorName = members.first(where: { $0.uid == creditor.uid })?.displayName ?? creditor.uid

            settlements.append((from: debtorName, to: creditorName, amount: settlementAmount))

            // Update remaining balances
            debtor.amount -= settlementAmount
            creditor.amount -= settlementAmount

            if debtor.amount > 0.01 {
                debtorQueue.insert(debtor, at: 0)
            }
            if creditor.amount > 0.01 {
                creditorQueue.insert(creditor, at: 0)
            }
        }

        return settlements
    }

    // MARK: - Generate Trip Summary Report

    static func generateTripSummaryReport(
        trip: TripModel,
        expenses: [ExpenseModel]
    ) -> URL? {

        let pdfMetaData = [
            kCGPDFContextCreator: "TripLedger",
            kCGPDFContextAuthor: trip.name,
            kCGPDFContextTitle: "Laporan Ringkasan Trip - \(trip.name)"
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

            // MARK: - Header
            currentY = drawReportHeader(in: pageRect, startY: currentY, title: "Laporan Ringkasan Trip")
            currentY += 30

            // MARK: - Trip Details
            currentY = drawSectionTitle("Detail Trip", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawTripDetails(trip: trip, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Financial Summary
            currentY = drawSectionTitle("Ringkasan Keuangan", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawFinancialSummary(trip: trip, expenses: expenses, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Member Balance Summary
            currentY = drawSectionTitle("Posisi Keuangan Anggota", in: pageRect, startY: currentY)
            currentY += 15
            let balances = calculateMemberBalances(expenses: expenses, members: trip.members)
            currentY = drawMemberBalances(balances: balances, members: trip.members, currency: trip.currency, in: pageRect, startY: currentY)
            currentY += 30

            // Check if we need new page
            if currentY > pageHeight - 200 {
                context.beginPage()
                currentY = 40
            }

            // MARK: - Settlement Recommendation
            currentY = drawSectionTitle("Rekomendasi Pembayaran", in: pageRect, startY: currentY)
            currentY += 15
            let settlements = calculateSettlements(balances: balances, members: trip.members)
            currentY = drawSettlementRecommendations(settlements: settlements, expenses: expenses, members: trip.members, currency: trip.currency, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Expense List
            if currentY > pageHeight - 250 {
                context.beginPage()
                currentY = 40
            }

            currentY = drawSectionTitle("Daftar Pengeluaran", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawExpenseList(expenses: expenses, currency: trip.currency, in: pageRect, startY: currentY, context: context)

            // MARK: - Footer
            drawFooter(in: pageRect)
        }

        // Save to temp directory
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TripLedger_TripSummary_\(trip.id ?? UUID().uuidString).pdf")

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("❌ Error saving Trip Summary PDF: \(error)")
            return nil
        }
    }

    // MARK: - Generate Personal Expense Report

    static func generatePersonalExpenseReport(
        trip: TripModel,
        expenses: [ExpenseModel],
        currentUserUID: String,
        currentUserName: String
    ) -> URL? {

        let pdfMetaData = [
            kCGPDFContextCreator: "TripLedger",
            kCGPDFContextAuthor: currentUserName,
            kCGPDFContextTitle: "Laporan Pengeluaran Pribadi - \(trip.name)"
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

            // MARK: - Header
            currentY = drawReportHeader(in: pageRect, startY: currentY, title: "Laporan Pengeluaran Pribadi")
            currentY += 30

            // MARK: - Trip Details
            currentY = drawSectionTitle("Detail Trip", in: pageRect, startY: currentY)
            currentY += 15
            currentY = drawTripDetailsSimple(trip: trip, in: pageRect, startY: currentY)
            currentY += 30

            // MARK: - Personal Summary
            currentY = drawSectionTitle("Ringkasan Pribadi", in: pageRect, startY: currentY)
            currentY += 15
            let personalData = calculatePersonalSummary(expenses: expenses, currentUserUID: currentUserUID, members: trip.members)
            currentY = drawPersonalSummary(
                userName: currentUserName,
                totalPaid: personalData.totalPaid,
                totalReceivable: personalData.totalReceivable,
                totalPayable: personalData.totalPayable,
                currency: trip.currency,
                in: pageRect,
                startY: currentY
            )
            currentY += 30

            // MARK: - Expense by Category
            currentY = drawSectionTitle("Pengeluaran per Kategori", in: pageRect, startY: currentY)
            currentY += 15
            let categoryData = calculateExpenseByCategory(expenses: expenses, currentUserUID: currentUserUID)
            currentY = drawExpenseByCategory(categoryData: categoryData, currency: trip.currency, in: pageRect, startY: currentY)
            currentY += 30

            // Check if we need new page
            if currentY > pageHeight - 250 {
                context.beginPage()
                currentY = 40
            }

            // MARK: - My Expenses (all expenses involving current user)
            currentY = drawSectionTitle("Pengeluaran Saya", in: pageRect, startY: currentY)
            currentY += 15
            // Show all expenses where user is payer OR is part of the split
            let myExpenses = expenses.filter { expense in
                expense.paidByUID == currentUserUID ||
                expense.splits.contains(where: { $0.uid == currentUserUID })
            }
            currentY = drawMyExpensesList(expenses: myExpenses, currency: trip.currency, in: pageRect, startY: currentY, context: context)
            currentY += 30

            // Check if we need new page
            if currentY > pageHeight - 200 {
                context.beginPage()
                currentY = 40
            }

            // MARK: - Settlement Position
            currentY = drawSectionTitle("Posisi Pembayaran", in: pageRect, startY: currentY)
            currentY += 15
            let balances = calculateMemberBalances(expenses: expenses, members: trip.members)
            let settlements = calculateSettlements(balances: balances, members: trip.members)
            currentY = drawPersonalSettlementPosition(
                settlements: settlements,
                currentUserName: currentUserName,
                currency: trip.currency,
                in: pageRect,
                startY: currentY
            )

            // MARK: - Footer
            drawFooter(in: pageRect)
        }

        // Save to temp directory
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TripLedger_PersonalExpense_\(trip.id ?? UUID().uuidString).pdf")

        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("❌ Error saving Personal Expense PDF: \(error)")
            return nil
        }
    }

    // MARK: - Personal Calculations

    private static func calculatePersonalSummary(expenses: [ExpenseModel], currentUserUID: String, members: [TripMember]) -> (totalPaid: Double, totalReceivable: Double, totalPayable: Double) {
        let balances = calculateMemberBalances(expenses: expenses, members: members)
        let userBalance = balances[currentUserUID] ?? 0

        let totalPaid = expenses.filter { $0.paidByUID == currentUserUID }.reduce(0) { $0 + $1.amount }
        let totalReceivable = max(0, userBalance)
        let totalPayable = max(0, -userBalance)

        return (totalPaid, totalReceivable, totalPayable)
    }

    private static func calculateExpenseByCategory(expenses: [ExpenseModel], currentUserUID: String) -> [ExpenseCategory: Double] {
        var categoryTotals: [ExpenseCategory: Double] = [:]

        for expense in expenses.filter({ $0.paidByUID == currentUserUID }) {
            categoryTotals[expense.category, default: 0] += expense.amount
        }

        return categoryTotals
    }

    // MARK: - Drawing Functions will continue in next part...
    // (This is a placeholder - implementation continues below)

    // MARK: - Report Header
    private static func drawReportHeader(in pageRect: CGRect, startY: CGFloat, title: String) -> CGFloat {
        var currentY = startY

        // Draw App Icon logo
        if let logo = getAppIcon() {
            let logoSize: CGFloat = 40
            let logoRect = CGRect(x: 40, y: currentY, width: logoSize, height: logoSize)

            let cornerRadius: CGFloat = 10
            let backgroundPath = UIBezierPath(roundedRect: logoRect, cornerRadius: cornerRadius)
            UIColor.white.setFill()
            backgroundPath.fill()

            UIGraphicsGetCurrentContext()?.saveGState()
            backgroundPath.addClip()
            logo.draw(in: logoRect)
            UIGraphicsGetCurrentContext()?.restoreGState()

            primaryColor.withAlphaComponent(0.2).setStroke()
            backgroundPath.lineWidth = 1
            backgroundPath.stroke()
        }

        // App name
        let appNameAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: primaryColor
        ]
        let appName = "TripLedger"
        appName.draw(at: CGPoint(x: 90, y: currentY + 5), withAttributes: appNameAttrs)

        // Report title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: textSecondary
        ]
        title.draw(at: CGPoint(x: 90, y: currentY + 23), withAttributes: titleAttrs)

        // Date on right
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "id_ID")
        dateFormatter.dateFormat = "d MMMM yyyy, HH:mm"
        let dateText = "Dibuat: \(dateFormatter.string(from: Date()))"

        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: textSecondary
        ]
        let dateSize = dateText.size(withAttributes: dateAttrs)
        dateText.draw(at: CGPoint(x: pageRect.width - 40 - dateSize.width, y: currentY + 15), withAttributes: dateAttrs)

        currentY += 50

        // Divider line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: 40, y: currentY))
        linePath.addLine(to: CGPoint(x: pageRect.width - 40, y: currentY))
        primaryColor.setStroke()
        linePath.lineWidth = 2
        linePath.stroke()

        return currentY + 5
    }

    private static func getAppIcon() -> UIImage? {
        if let appIcon = UIImage(named: "logo tripledger") {
            return appIcon
        }
        if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last,
           let appIcon = UIImage(named: lastIcon) {
            return appIcon
        }
        return nil
    }

    private static func drawSectionTitle(_ title: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: primaryColor
        ]
        title.draw(at: CGPoint(x: 40, y: startY), withAttributes: attrs)
        return startY + title.size(withAttributes: attrs).height
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
    }

    // MARK: - Trip Details Drawing

    private static func drawTripDetails(trip: TripModel, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        // Trip name
        currentY = drawInfoRow(label: "Nama Trip", value: trip.name, in: pageRect, startY: currentY, valueBold: true)
        currentY += 10

        // Date range
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "id_ID")
        dateFormatter.dateFormat = "d MMM yyyy"

        var dateRange = "-"
        if let startDate = trip.startDate?.dateValue() {
            let startStr = dateFormatter.string(from: startDate)
            if let endDate = trip.endDate?.dateValue() {
                let endStr = dateFormatter.string(from: endDate)
                dateRange = "\(startStr) - \(endStr)"
            } else {
                dateRange = "Mulai \(startStr)"
            }
        }

        currentY = drawInfoRow(label: "Tanggal", value: dateRange, in: pageRect, startY: currentY)
        currentY += 10

        // Members count
        currentY = drawInfoRow(label: "Jumlah Anggota", value: "\(trip.members.count) orang", in: pageRect, startY: currentY)
        currentY += 15

        // Members list with roles
        currentY = drawMembersList(members: trip.members, in: pageRect, startY: currentY)

        return currentY
    }

    private static func drawMembersList(members: [TripMember], in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: textSecondary
        ]
        "Daftar Anggota:".draw(at: CGPoint(x: 60, y: currentY), withAttributes: headerAttrs)
        currentY += 18

        // Sort members by role (owner first, then admin, then member)
        let sortedMembers = members.sorted { m1, m2 in
            let roleOrder: [TripMemberRole: Int] = [.owner: 0, .admin: 1, .member: 2, .pending: 3]
            return (roleOrder[m1.role] ?? 4) < (roleOrder[m2.role] ?? 4)
        }

        for member in sortedMembers {
            let roleText: String
            let roleColor: UIColor

            switch member.role {
            case .owner:
                roleText = "Owner"
                roleColor = primaryColor
            case .admin:
                roleText = "Admin"
                roleColor = accentColor
            case .member:
                roleText = "Anggota"
                roleColor = textSecondary
            case .pending:
                roleText = "Pending"
                roleColor = warningAmber
            }

            // Draw member name
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: textPrimary
            ]
            "• \(member.displayName)".draw(at: CGPoint(x: 70, y: currentY), withAttributes: nameAttrs)

            // Draw role badge
            let roleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: roleColor
            ]
            let roleSize = roleText.size(withAttributes: roleAttrs)
            roleText.draw(at: CGPoint(x: pageRect.width - 60 - roleSize.width, y: currentY + 1), withAttributes: roleAttrs)

            currentY += 16
        }

        return currentY
    }

    private static func drawTripDetailsSimple(trip: TripModel, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        currentY = drawInfoRow(label: "Nama Trip", value: trip.name, in: pageRect, startY: currentY, valueBold: true)
        currentY += 10

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "id_ID")
        dateFormatter.dateFormat = "d MMM yyyy"

        var period = "-"
        if let startDate = trip.startDate?.dateValue(), let endDate = trip.endDate?.dateValue() {
            let startStr = dateFormatter.string(from: startDate)
            let endStr = dateFormatter.string(from: endDate)
            period = "\(startStr) - \(endStr)"
        }

        currentY = drawInfoRow(label: "Periode Trip", value: period, in: pageRect, startY: currentY)

        return currentY
    }

    private static func drawFinancialSummary(trip: TripModel, expenses: [ExpenseModel], in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        let totalExpense = expenses.reduce(0) { $0 + $1.amount }

        currentY = drawInfoRow(label: "Total Pengeluaran", value: formatCurrency(totalExpense, symbol: trip.currency), in: pageRect, startY: currentY, valueColor: primaryColor, valueBold: true)
        currentY += 10

        currentY = drawInfoRow(label: "Jumlah Transaksi", value: "\(expenses.count) expense", in: pageRect, startY: currentY)

        return currentY
    }

    private static func drawMemberBalances(balances: [String: Double], members: [TripMember], currency: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        // Sort by balance (highest first)
        let sortedBalances = balances.sorted { $0.value > $1.value }

        for (uid, balance) in sortedBalances {
            guard let member = members.first(where: { $0.uid == uid }) else { continue }

            let balanceText: String
            let balanceColor: UIColor

            if balance > 0.01 {
                balanceText = "+\(formatCurrency(balance, symbol: currency))"
                balanceColor = successGreen
            } else if balance < -0.01 {
                balanceText = formatCurrency(balance, symbol: currency)
                balanceColor = errorRed
            } else {
                balanceText = formatCurrency(0, symbol: currency)
                balanceColor = textSecondary
            }

            currentY = drawInfoRow(
                label: member.displayName,
                value: balanceText,
                in: pageRect,
                startY: currentY,
                valueColor: balanceColor,
                valueBold: true
            )
            currentY += 8
        }

        return currentY
    }

    private static func drawSettlementRecommendations(settlements: [(from: String, to: String, amount: Double)], expenses: [ExpenseModel], members: [TripMember], currency: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        if settlements.isEmpty {
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: successGreen
            ]
            let emptyText = "✓ Semua sudah lunas!"
            emptyText.draw(at: CGPoint(x: 60, y: currentY), withAttributes: emptyAttrs)
            return currentY + 20
        }

        for settlement in settlements {
            let settlementText = "\(settlement.from) → \(settlement.to)"
            let amountText = formatCurrency(settlement.amount, symbol: currency)

            currentY = drawInfoRow(
                label: settlementText,
                value: amountText,
                in: pageRect,
                startY: currentY,
                valueColor: warningAmber,
                valueBold: true
            )
            currentY += 5

            // Get expense details for this settlement
            let debtorUID = members.first(where: { $0.displayName == settlement.from })?.uid
            let creditorUID = members.first(where: { $0.displayName == settlement.to })?.uid

            if let debtorUID = debtorUID, let creditorUID = creditorUID {
                // Find expenses where creditor paid and debtor owes
                let relatedExpenses = expenses.filter { expense in
                    expense.paidByUID == creditorUID &&
                    expense.splits.contains(where: { $0.uid == debtorUID })
                }

                if !relatedExpenses.isEmpty {
                    let detailAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: textSecondary
                    ]

                    for expense in relatedExpenses.prefix(3) {
                        if let split = expense.splits.first(where: { $0.uid == debtorUID }) {
                            let detailText = "  • \(expense.title): \(formatCurrency(split.amount, symbol: currency))"
                            detailText.draw(at: CGPoint(x: 70, y: currentY), withAttributes: detailAttrs)
                            currentY += 12
                        }
                    }

                    if relatedExpenses.count > 3 {
                        let moreText = "  ...dan \(relatedExpenses.count - 3) expense lainnya"
                        moreText.draw(at: CGPoint(x: 70, y: currentY), withAttributes: detailAttrs)
                        currentY += 12
                    }
                }
            }

            currentY += 8
        }

        return currentY
    }

    private static func drawExpenseList(expenses: [ExpenseModel], currency: String, in pageRect: CGRect, startY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = startY
        let pageHeight = pageRect.height
        let bottomMargin: CGFloat = 60 // Space for footer

        if expenses.isEmpty {
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: textSecondary
            ]
            "Belum ada pengeluaran".draw(at: CGPoint(x: 60, y: currentY), withAttributes: emptyAttrs)
            return currentY + 20
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "id_ID")
        dateFormatter.dateFormat = "dd MMM yyyy"

        for expense in expenses {
            // Calculate card height BEFORE drawing
            let cardHeight = calculateExpenseCardHeight(expense: expense)

            // Check if we need new page based on actual card height
            if currentY + cardHeight + 12 > pageHeight - bottomMargin {
                context.beginPage()
                currentY = 40
            }

            // Draw expense card
            currentY = drawExpenseCard(expense: expense, currency: currency, dateFormatter: dateFormatter, in: pageRect, startY: currentY)
            currentY += 12  // Spacing between cards
        }

        return currentY
    }

    // Helper function to calculate expense card height without drawing
    private static func calculateExpenseCardHeight(expense: ExpenseModel) -> CGFloat {
        let baseHeight: CGFloat = 70
        let participantRowHeight: CGFloat = 12
        let itemRowHeight: CGFloat = 10

        let participantCount = expense.splits.count
        var totalItemsCount = 0
        for split in expense.splits {
            totalItemsCount += split.items.count
        }

        let participantSectionHeight: CGFloat = participantCount > 0
            ? (CGFloat(participantCount) * participantRowHeight) + (CGFloat(totalItemsCount) * itemRowHeight) + 25
            : 0

        return baseHeight + participantSectionHeight
    }

    private static func drawExpenseCard(expense: ExpenseModel, currency: String, dateFormatter: DateFormatter, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY
        let cardPadding: CGFloat = 12
        let leftMargin: CGFloat = 40
        let rightMargin: CGFloat = 40
        let cardWidth = pageRect.width - leftMargin - rightMargin

        // Calculate card height based on content
        let participantCount = expense.splits.count
        let baseHeight: CGFloat = 70
        let participantRowHeight: CGFloat = 12

        // Calculate total items across all splits
        var totalItemsCount = 0
        for split in expense.splits {
            totalItemsCount += split.items.count
        }
        let itemRowHeight: CGFloat = 10

        let participantSectionHeight: CGFloat = participantCount > 0
            ? (CGFloat(participantCount) * participantRowHeight) + (CGFloat(totalItemsCount) * itemRowHeight) + 25
            : 0
        let totalCardHeight = baseHeight + participantSectionHeight

        // Calculate card height first
        let cardStartY = currentY

        // Draw card background
        let cardRect = CGRect(x: leftMargin, y: cardStartY, width: cardWidth, height: totalCardHeight)
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 10)
        surfaceElevated.setFill()
        cardPath.fill()

        // Border
        primaryColor.withAlphaComponent(0.15).setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()

        currentY += cardPadding

        // Top row: Title and Amount
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: textPrimary
        ]
        let titleStr = truncateText(expense.title, maxWidth: cardWidth - 150, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: leftMargin + cardPadding, y: currentY), withAttributes: titleAttrs)

        // Amount on right
        let amountAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: primaryColor
        ]
        let amountStr = formatCurrency(expense.amount, symbol: currency)
        let amountSize = amountStr.size(withAttributes: amountAttrs)
        amountStr.draw(at: CGPoint(x: pageRect.width - rightMargin - cardPadding - amountSize.width, y: currentY - 1), withAttributes: amountAttrs)

        currentY += 18

        // Category and date
        let detailAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: textSecondary
        ]

        let categoryStr = expense.category.displayName
        categoryStr.draw(at: CGPoint(x: leftMargin + cardPadding, y: currentY), withAttributes: detailAttrs)

        // Date on right
        let dateStr = dateFormatter.string(from: expense.createdAt.dateValue())
        let dateSize = dateStr.size(withAttributes: detailAttrs)
        dateStr.draw(at: CGPoint(x: pageRect.width - rightMargin - cardPadding - dateSize.width, y: currentY), withAttributes: detailAttrs)

        currentY += 14

        // Bottom row: Paid by and receipt indicator
        let paidByText = "Dibayar oleh \(expense.paidByName)"
        paidByText.draw(at: CGPoint(x: leftMargin + cardPadding, y: currentY), withAttributes: detailAttrs)

        // Receipt indicator
        if expense.receiptURL != nil {
            let receiptText = "✓ Struk"
            let receiptAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: successGreen
            ]
            let receiptSize = receiptText.size(withAttributes: receiptAttrs)
            receiptText.draw(at: CGPoint(x: pageRect.width - rightMargin - cardPadding - receiptSize.width, y: currentY + 1), withAttributes: receiptAttrs)
        }

        currentY += 18

        // MARK: - Participant Details Section
        if !expense.splits.isEmpty {
            // Divider line
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: leftMargin + cardPadding, y: currentY))
            dividerPath.addLine(to: CGPoint(x: pageRect.width - rightMargin - cardPadding, y: currentY))
            textSecondary.withAlphaComponent(0.3).setStroke()
            dividerPath.lineWidth = 0.5
            dividerPath.stroke()

            currentY += 8

            // Section header
            let sectionHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 9),
                .foregroundColor: textSecondary
            ]
            "Daftar Patungan:".draw(at: CGPoint(x: leftMargin + cardPadding, y: currentY), withAttributes: sectionHeaderAttrs)
            currentY += 14

            // Draw each participant
            let participantNameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: textPrimary
            ]

            let participantAmountAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 9),
                .foregroundColor: accentColor
            ]

            let itemAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: textSecondary
            ]

            for split in expense.splits {
                // Participant name with bullet
                let nameText = "• \(split.displayName)"
                nameText.draw(at: CGPoint(x: leftMargin + cardPadding + 5, y: currentY), withAttributes: participantNameAttrs)

                // Amount on right
                let splitAmountStr = formatCurrency(split.amount, symbol: currency)
                let splitAmountSize = splitAmountStr.size(withAttributes: participantAmountAttrs)
                splitAmountStr.draw(at: CGPoint(x: pageRect.width - rightMargin - cardPadding - splitAmountSize.width, y: currentY), withAttributes: participantAmountAttrs)

                currentY += 12

                // Show ALL items (no truncation)
                if !split.items.isEmpty {
                    for item in split.items {
                        let itemText = "   • \(item)"
                        itemText.draw(at: CGPoint(x: leftMargin + cardPadding + 10, y: currentY), withAttributes: itemAttrs)
                        currentY += 10
                    }
                }
            }
        }

        currentY += 8

        return currentY
    }

    private static func drawPersonalSummary(userName: String, totalPaid: Double, totalReceivable: Double, totalPayable: Double, currency: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        currentY = drawInfoRow(label: "Nama", value: userName, in: pageRect, startY: currentY, valueBold: true)
        currentY += 10

        currentY = drawInfoRow(label: "Total Dibayar", value: formatCurrency(totalPaid, symbol: currency), in: pageRect, startY: currentY, valueColor: primaryColor, valueBold: true)
        currentY += 10

        currentY = drawInfoRow(label: "Total Piutang", value: formatCurrency(totalReceivable, symbol: currency), in: pageRect, startY: currentY, valueColor: successGreen, valueBold: true)
        currentY += 10

        currentY = drawInfoRow(label: "Total Hutang", value: formatCurrency(totalPayable, symbol: currency), in: pageRect, startY: currentY, valueColor: errorRed, valueBold: true)

        return currentY
    }

    private static func drawExpenseByCategory(categoryData: [ExpenseCategory: Double], currency: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        if categoryData.isEmpty {
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: textSecondary
            ]
            "Belum ada pengeluaran".draw(at: CGPoint(x: 60, y: currentY), withAttributes: emptyAttrs)
            return currentY + 20
        }

        // Sort by amount
        let sortedCategories = categoryData.sorted { $0.value > $1.value }

        for (category, amount) in sortedCategories {
            currentY = drawInfoRow(
                label: category.displayName,
                value: formatCurrency(amount, symbol: currency),
                in: pageRect,
                startY: currentY,
                valueColor: UIColor(hexString: category.color),
                valueBold: true
            )
            currentY += 8
        }

        return currentY
    }

    private static func drawMyExpensesList(expenses: [ExpenseModel], currency: String, in pageRect: CGRect, startY: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = startY
        let pageHeight = pageRect.height
        let bottomMargin: CGFloat = 60 // Space for footer

        if expenses.isEmpty {
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: textSecondary
            ]
            "Belum ada pengeluaran yang dibayar".draw(at: CGPoint(x: 60, y: currentY), withAttributes: emptyAttrs)
            return currentY + 20
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "id_ID")
        dateFormatter.dateFormat = "dd MMM yyyy"

        for expense in expenses {
            // Calculate card height BEFORE drawing
            let cardHeight = calculateExpenseCardHeight(expense: expense)

            // Check if we need new page based on actual card height
            if currentY + cardHeight + 12 > pageHeight - bottomMargin {
                context.beginPage()
                currentY = 40
            }

            // Draw expense card
            currentY = drawExpenseCard(expense: expense, currency: currency, dateFormatter: dateFormatter, in: pageRect, startY: currentY)
            currentY += 12  // Spacing between cards
        }

        return currentY
    }

    private static func drawPersonalSettlementPosition(settlements: [(from: String, to: String, amount: Double)], currentUserName: String, currency: String, in pageRect: CGRect, startY: CGFloat) -> CGFloat {
        var currentY = startY

        // Filter settlements involving current user
        let userSettlements = settlements.filter { $0.from == currentUserName || $0.to == currentUserName }

        if userSettlements.isEmpty {
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: successGreen
            ]
            "✓ Tidak ada pembayaran yang perlu dilakukan".draw(at: CGPoint(x: 60, y: currentY), withAttributes: emptyAttrs)
            return currentY + 20
        }

        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: textPrimary
        ]

        for settlement in userSettlements {
            let text: String
            let color: UIColor

            if settlement.from == currentUserName {
                // Current user needs to pay
                text = "\(currentUserName) harus membayar \(settlement.to) \(formatCurrency(settlement.amount, symbol: currency))"
                color = errorRed
            } else {
                // Current user will receive
                text = "\(settlement.from) harus membayar \(currentUserName) \(formatCurrency(settlement.amount, symbol: currency))"
                color = successGreen
            }

            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: color
            ]

            text.draw(at: CGPoint(x: 60, y: currentY), withAttributes: textAttrs)
            currentY += 20
        }

        return currentY
    }

    // MARK: - Helper Drawing Functions

    private static func drawInfoRow(label: String, value: String, in pageRect: CGRect, startY: CGFloat, valueColor: UIColor = textPrimary, valueBold: Bool = false) -> CGFloat {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: textSecondary
        ]
        label.draw(at: CGPoint(x: 60, y: startY), withAttributes: labelAttrs)

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: valueBold ? UIFont.boldSystemFont(ofSize: 12) : UIFont.systemFont(ofSize: 12),
            .foregroundColor: valueColor
        ]
        let valueX = pageRect.width - 60 - value.size(withAttributes: valueAttrs).width
        value.draw(at: CGPoint(x: valueX, y: startY - 1), withAttributes: valueAttrs)

        return startY + max(label.size(withAttributes: labelAttrs).height, value.size(withAttributes: valueAttrs).height)
    }

    // MARK: - Utility Functions

    private static func formatCurrency(_ amount: Double, symbol: String) -> String {
        amount.toCurrency(symbol: symbol)
    }

    private static func truncateText(_ text: String, maxWidth: CGFloat, attributes: [NSAttributedString.Key: Any]) -> String {
        let size = text.size(withAttributes: attributes)
        if size.width <= maxWidth {
            return text
        }

        var truncated = text
        while truncated.count > 0 && truncated.size(withAttributes: attributes).width > maxWidth - 15 {
            truncated = String(truncated.dropLast())
        }
        return truncated + "..."
    }
}