import SwiftUI

// MARK: - Expense Row
struct ExpenseRow: View {
    let expense:  ExpenseModel
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: expense.category.color).opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: expense.category.icon)
                        .foregroundColor(Color(hex: expense.category.color))
                        .font(.system(size: 18))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.title)
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        if expense.receiptURL != nil {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.brandPrimary)
                        }
                        Text("Dibayar \(expense.paidByName)")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.45))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(expense.amount.toCurrency(symbol: currency))
                        .font(AppFont.headline())
                        .foregroundColor(.brandPrimary)

                    let unpaidCount = expense.splits.filter { $0.isPaid != true }.count
                    if unpaidCount == 0 && !expense.splits.isEmpty {
                        Text("Lunas")
                            .font(AppFont.caption2())
                            .foregroundColor(.successGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.successGreen.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Text("\(unpaidCount) belum bayar")
                            .font(AppFont.caption2())
                            .foregroundColor(.warningAmber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.warningAmber.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            // Progress Bar
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.textPrimary.opacity(0.08))

                        let paidCount = expense.splits.filter { $0.isPaid == true }.count
                        let ratio = expense.splits.isEmpty ? 0 : CGFloat(paidCount) / CGFloat(expense.splits.count)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient.brandGradient)
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(height: 6)

                let paidCount = expense.splits.filter { $0.isPaid == true }.count
                Text("\(paidCount)/\(expense.splits.count)")
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.4))
                    .frame(width: 30)
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(Color.borderSoft, lineWidth: 1)
        )
    }
}

// MARK: - My Debt Row (highlighted)
struct MyDebtRow: View {
    let transaction: Transaction
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.warningAmber.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.warningAmber)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Bayar ke \(transaction.toName)")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                Text("Belum dibayar")
                    .font(AppFont.caption())
                    .foregroundColor(.warningAmber)
            }
            Spacer()
            Text(transaction.amount.toCurrency(symbol: currency))
                .font(AppFont.headline())
                .foregroundColor(.warningAmber)
        }
        .padding(14)
        .background(Color.warningAmber.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.warningAmber.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Debt Row
struct DebtRow: View {
    let transaction: Transaction
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.fromName)
                    .font(AppFont.subheadline())
                    .foregroundColor(.errorRed)
                Text("bayar ke \(transaction.toName)")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.45))
            }
            Spacer()
            Text(transaction.amount.toCurrency(symbol: currency))
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Settlement Row
struct SettlementRow: View {
    let settlement: SettlementModel

    private var statusColor: Color {
        switch settlement.status {
        case .pending:  return .warningAmber
        case .verified, .approved: return .successGreen
        case .rejected: return .errorRed
        }
    }

    private var statusLabel: String {
        switch settlement.status {
        case .pending:  return "Menunggu"
        case .verified, .approved: return "Terverifikasi"
        case .rejected: return "Ditolak"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: settlement.status == .verified ? "checkmark" : settlement.status == .rejected ? "xmark" : "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(settlement.fromName) → \(settlement.toName)")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(settlement.amount.toCurrency(symbol: settlement.currency))
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.7))
            }

            Spacer()

            Text(statusLabel)
                .font(AppFont.caption2())
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
