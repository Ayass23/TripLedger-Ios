import SwiftUI

struct FinancialDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isPresented: Bool

    let balances: [UserBalance]
    let currency: String
    let tripID: String
    let tripName: String
    let currentUser: (uid: String, name: String)
    let onPayDebt: (UserBalance) -> Void

    @State private var expandedUserUID: String?

    private var totalOwed: Double {
        balances.reduce(0) { $0 + $1.totalOwed }
    }

    private var totalReceivable: Double {
        balances.reduce(0) { $0 + $1.totalReceivable }
    }

    private var netAmount: Double {
        totalOwed - totalReceivable
    }

    // Separate debts and receivables
    private var debtBalances: [UserBalance] {
        balances.filter { $0.isNetOwed }
    }

    private var receivableBalances: [UserBalance] {
        balances.filter { $0.isNetReceivable }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Card
                        summaryCard

                        // Debts Section
                        if !debtBalances.isEmpty {
                            sectionView(
                                title: "Hutang Kamu",
                                icon: "arrow.up.circle.fill",
                                iconColor: .errorRed,
                                balances: debtBalances,
                                isDebt: true
                            )
                        }

                        // Receivables Section
                        if !receivableBalances.isEmpty {
                            sectionView(
                                title: "Piutang Kamu",
                                icon: "arrow.down.circle.fill",
                                iconColor: .successGreen,
                                balances: receivableBalances,
                                isDebt: false
                            )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Detail Keuangan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.textPrimary.opacity(0.3))
                    }
                }
            }
        }
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        VStack(spacing: 16) {
            // Net Position
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Posisi Bersih")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.6))

                    Text(abs(netAmount).toCurrency(symbol: currency))
                        .font(AppFont.title2())
                        .fontWeight(.bold)
                        .foregroundColor(netAmount > 0 ? .errorRed : .successGreen)
                }

                Spacer()

                // Status Badge
                HStack(spacing: 6) {
                    Image(systemName: netAmount > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 14))
                    Text(netAmount > 0 ? "Kamu Berhutang" : "Kamu Berpiutang")
                        .font(AppFont.caption())
                        .fontWeight(.semibold)
                }
                .foregroundColor(netAmount > 0 ? .errorRed : .successGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (netAmount > 0 ? Color.errorRed : Color.successGreen).opacity(0.12)
                )
                .clipShape(Capsule())
            }

            Divider()
                .background(Color.borderSoft)

            // Breakdown
            HStack(spacing: 24) {
                // Total Hutang
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.errorRed)
                            .frame(width: 8, height: 8)
                        Text("Total Hutang")
                            .font(AppFont.caption2())
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }
                    Text(totalOwed.toCurrency(symbol: currency))
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Total Piutang
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Total Piutang")
                            .font(AppFont.caption2())
                            .foregroundColor(.textPrimary.opacity(0.5))
                        Circle()
                            .fill(Color.successGreen)
                            .frame(width: 8, height: 8)
                    }
                    Text(totalReceivable.toCurrency(symbol: currency))
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                }
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Section View
    private func sectionView(
        title: String,
        icon: String,
        iconColor: Color,
        balances: [UserBalance],
        isDebt: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("\(balances.count) orang")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.5))
            }

            // Balance Cards
            VStack(spacing: 10) {
                ForEach(balances) { balance in
                    balanceCard(balance: balance, isDebt: isDebt)
                }
            }
        }
    }

    // MARK: - Balance Card
    private func balanceCard(balance: UserBalance, isDebt: Bool) -> some View {
        let isExpanded = expandedUserUID == balance.userUID
        let details = isDebt ? balance.owedDetails : balance.receivableDetails
        let amount = isDebt ? balance.totalOwed : balance.totalReceivable

        return VStack(spacing: 0) {
            // Main Row
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedUserUID = isExpanded ? nil : balance.userUID
                }
            } label: {
                HStack(spacing: 12) {
                    // Avatar
                    AvatarView(
                        url: balance.avatarURL,
                        initials: String(balance.userName.prefix(2)).uppercased(),
                        size: 44
                    )

                    // Name & Detail Count
                    VStack(alignment: .leading, spacing: 2) {
                        Text(balance.userName)
                            .font(AppFont.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)

                        Text("\(details.count) transaksi")
                            .font(AppFont.caption2())
                            .foregroundColor(.textPrimary.opacity(0.5))
                    }

                    Spacer()

                    // Amount
                    Text(amount.toCurrency(symbol: currency))
                        .font(AppFont.subheadline())
                        .fontWeight(.bold)
                        .foregroundColor(isDebt ? .errorRed : .successGreen)

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textPrimary.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded Content
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.borderSoft)

                    VStack(spacing: 8) {
                        // Expense Details
                        ForEach(details) { detail in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(detail.title)
                                        .font(AppFont.caption())
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(1)

                                    Text(detail.createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(AppFont.caption2())
                                        .foregroundColor(.textPrimary.opacity(0.4))
                                }

                                Spacer()

                                Text(detail.amount.toCurrency(symbol: currency))
                                    .font(AppFont.caption())
                                    .fontWeight(.medium)
                                    .foregroundColor(isDebt ? .errorRed : .successGreen)
                            }
                        }

                        // Pay Button (only for debts)
                        if isDebt {
                            Button {
                                onPayDebt(balance)
                            } label: {
                                HStack {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 14))
                                    Text("Bayar Sekarang")
                                        .font(AppFont.caption())
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(LinearGradient.brandGradient)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(14)
                    .background(Color.baseFallback)
                }
            }
        }
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderSoft, lineWidth: 1)
        )
    }
}
