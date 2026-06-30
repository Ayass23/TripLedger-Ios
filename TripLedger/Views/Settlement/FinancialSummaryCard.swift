import SwiftUI

struct FinancialSummaryCard: View {
    let balances: [UserBalance]
    let pendingSettlements: [Settlement]
    let myPendingSettlements: [Settlement]
    let currency: String
    let onShowDetail: () -> Void
    let onVerifySettlement: (Settlement) -> Void

    private var summary: (totalOwed: Double, totalReceivable: Double, netAmount: Double) {
        let totalOwed = balances.reduce(0) { $0 + $1.totalOwed }
        let totalReceivable = balances.reduce(0) { $0 + $1.totalReceivable }
        return (totalOwed, totalReceivable, totalOwed - totalReceivable)
    }

    private var hasPendingVerification: Bool {
        !pendingSettlements.isEmpty
    }

    private var hasMyPendingSettlement: Bool {
        !myPendingSettlements.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pending Verification Card (for receiver)
            if hasPendingVerification {
                pendingVerificationCard
            }
            // My Pending Settlement (waiting for approval)
            else if hasMyPendingSettlement {
                myPendingCard
            }
            // Balance Summary Card
            else if abs(summary.netAmount) > 0.01 {
                balanceSummaryCard
            }
            // All Settled Card
            else if !balances.isEmpty {
                allSettledCard
            }
            // Empty State - No expenses yet
            else {
                emptyFinancialCard
            }
        }
    }

    // MARK: - Pending Verification Card
    private var pendingVerificationCard: some View {
        VStack(spacing: 12) {
            ForEach(pendingSettlements) { settlement in
                Button {
                    onVerifySettlement(settlement)
                } label: {
                    HStack(spacing: 14) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.warningAmber.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.warningAmber)
                        }

                        // Content
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pembayaran Masuk")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary)

                            Text("\(settlement.fromName) mengkonfirmasi")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }

                        Spacer()

                        // Amount & Action
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(settlement.totalAmount.toCurrency(symbol: currency))
                                .font(AppFont.headline())
                                .foregroundColor(.brandPrimary)

                            Text("Verifikasi")
                                .font(AppFont.caption2())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.warningAmber)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(Color.warningAmber.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: Color.warningAmber.opacity(0.1), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - My Pending Settlement Card
    private var myPendingCard: some View {
        VStack(spacing: 12) {
            ForEach(myPendingSettlements) { settlement in
                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.brandAccent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.brandAccent)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Menunggu Verifikasi")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)

                        Text("Dari \(settlement.toName)")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.6))
                    }

                    Spacer()

                    // Amount
                    Text(settlement.totalAmount.toCurrency(symbol: currency))
                        .font(AppFont.headline())
                        .foregroundColor(.brandPrimary)
                }
                .padding(16)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(Color.brandAccent.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: AppShadow.soft, radius: 8, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Balance Summary Card
    private var balanceSummaryCard: some View {
        Button {
            onShowDetail()
        } label: {
            VStack(spacing: 14) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(summary.netAmount > 0 ? Color.errorRed.opacity(0.15) : Color.successGreen.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: summary.netAmount > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(summary.netAmount > 0 ? .errorRed : .successGreen)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Posisi Keuangan")
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.6))

                        if summary.totalOwed > 0 && summary.totalReceivable > 0 {
                            // Has both
                            Text("Hutang & Piutang")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary)
                        } else if summary.netAmount > 0 {
                            Text("Kamu punya hutang")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary)
                        } else {
                            Text("Kamu punya piutang")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary.opacity(0.3))
                }

                // Divider
                Rectangle()
                    .fill(Color.borderSoft)
                    .frame(height: 1)

                // Summary Row
                HStack(spacing: 16) {
                    // Hutang
                    if summary.totalOwed > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hutang")
                                .font(AppFont.caption2())
                                .foregroundColor(.textPrimary.opacity(0.5))
                            Text(summary.totalOwed.toCurrency(symbol: currency))
                                .font(AppFont.subheadline())
                                .foregroundColor(.errorRed)
                        }
                    }

                    // Piutang
                    if summary.totalReceivable > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Piutang")
                                .font(AppFont.caption2())
                                .foregroundColor(.textPrimary.opacity(0.5))
                            Text(summary.totalReceivable.toCurrency(symbol: currency))
                                .font(AppFont.subheadline())
                                .foregroundColor(.successGreen)
                        }
                    }

                    Spacer()

                    // Net Amount
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Net")
                            .font(AppFont.caption2())
                            .foregroundColor(.textPrimary.opacity(0.5))
                        Text(abs(summary.netAmount).toCurrency(symbol: currency))
                            .font(AppFont.headline())
                            .foregroundColor(summary.netAmount > 0 ? .errorRed : .successGreen)
                    }
                }

                // Action Button
                HStack {
                    Spacer()
                    Text(summary.netAmount > 0 ? "Lunasi Sekarang" : "Lihat Rincian")
                        .font(AppFont.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(LinearGradient.brandGradient)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(Color.cardFallback)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(Color.borderSoft, lineWidth: 1)
            )
            .shadow(color: AppShadow.soft, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - All Settled Card
    private var allSettledCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.successGreen.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.successGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Semua Lunas!")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
                Text("Tidak ada hutang atau piutang")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.successGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.successGreen.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Empty Financial Card
    private var emptyFinancialCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandAccent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "wallet.pass")
                    .font(.system(size: 20))
                    .foregroundColor(.brandAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Posisi Keuangan")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
                Text("Belum ada pengeluaran")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderSoft, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
