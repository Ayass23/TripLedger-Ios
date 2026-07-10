import SwiftUI

// MARK: - Scan Result Banner
// Success banner shown after a receipt has been scanned (OCR + AI parsing),
// shared by CreateSplitBillView and CreateExpenseFromReceiptView.
struct ScanResultBanner: View {
    let result: OCRResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.successGreen)
            VStack(alignment: .leading, spacing: 4) {
                Text("Struk berhasil di-scan")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)

                if let parsed = result.parsedReceipt {
                    // Show AI-parsed summary
                    HStack(spacing: 4) {
                        Text("\(parsed.billName) •")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.7))
                        Text("\(parsed.currency) \(Int(parsed.totalAmount).description)")
                            .font(AppFont.caption())
                            .foregroundColor(.successGreen)
                        if let cat = parsed.category {
                            Text("• \(cat)")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.7))
                        }
                    }

                    if !parsed.items.isEmpty {
                        Text("\(parsed.items.count) item terdeteksi")
                            .font(AppFont.caption2())
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }
                } else if let amt = result.parsedAmount {
                    // Fallback to basic OCR parsing
                    Text("Total terdeteksi: \(Int(amt).description)")
                        .font(AppFont.caption())
                        .foregroundColor(.successGreen)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Color.successGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.successGreen.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Field Section
/// Labeled form section used across the wizard step views.
/// Top-level function so existing `fieldSection("…") { … }` call sites keep working.
func fieldSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(AppFont.subheadline())
            .foregroundColor(.textPrimary.opacity(0.6))
        content()
    }
}
