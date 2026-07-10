import SwiftUI

// MARK: - Report Type
enum ReportType {
    case tripSummary
    case personalExpense
}

// MARK: - Report Generation
extension TripDetailView {

    // MARK: - Generate Report
    func generateReport() {
        guard let reportType = selectedReportType,
              let currentUserUID = authVM.currentUser?.uid,
              let currentUserName = authVM.currentUser?.displayName else {
            AppLog.debug("❌ Missing data for report generation")
            return
        }

        // Generate PDF based on report type
        let pdfURL: URL?
        let title: String

        switch reportType {
        case .tripSummary:
            pdfURL = TripReportGenerator.generateTripSummaryReport(
                trip: currentTrip,
                expenses: expenseVM.expenses
            )
            title = "Laporan Ringkasan Trip"

        case .personalExpense:
            pdfURL = TripReportGenerator.generatePersonalExpenseReport(
                trip: currentTrip,
                expenses: expenseVM.expenses,
                currentUserUID: currentUserUID,
                currentUserName: currentUserName
            )
            title = "Laporan Pengeluaran Pribadi"
        }

        if let url = pdfURL {
            reportPDFURL = url
            reportTitle = title
            showReportPreview = true
            AppLog.debug("✅ Report PDF generated: \(url.lastPathComponent)")
        } else {
            AppLog.debug("❌ Failed to generate report PDF")
        }
    }
}
