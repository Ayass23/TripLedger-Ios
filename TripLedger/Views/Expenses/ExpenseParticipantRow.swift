import SwiftUI
import Kingfisher

// MARK: - Expense Participant Row
struct ExpenseParticipantRow: View {
    let split: ExpenseSplit
    let currency: String

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.brandAccent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    let initial = String(split.displayName.prefix(1)).uppercased()
                    Text(initial)
                        .font(AppFont.headline())
                        .foregroundColor(.brandAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(split.displayName)
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary)
                    Text(split.amount.toCurrency(symbol: currency))
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.6))
                }

                Spacer()

                // Expand/Collapse button
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.textPrimary.opacity(0.3))
                        .font(.system(size: 20))
                }

                // Payment status indicator (read-only)
                if split.isPaid == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.successGreen)
                        .font(.system(size: 24))
                } else {
                    Text("Belum Lunas")
                        .font(AppFont.caption())
                        .foregroundColor(.warningAmber)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.warningAmber.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(12)

            // Expandable content - Item details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rincian Item")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.6))
                            .padding(.horizontal, 12)

                        if !split.items.isEmpty {
                            ForEach(split.items, id: \.self) { item in
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 4))
                                        .foregroundColor(.textPrimary.opacity(0.4))
                                    Text(item)
                                        .font(AppFont.caption())
                                        .foregroundColor(.textPrimary.opacity(0.7))
                                        .lineLimit(2)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                            }
                        } else {
                            Text("Tidak ada rincian item")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.5))
                                .italic()
                                .padding(.horizontal, 12)
                        }

                        Divider()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)

                        HStack {
                            Text("Total Bayar:")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.8))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(split.amount.toCurrency(symbol: currency))
                                .font(AppFont.caption())
                                .foregroundColor(.brandPrimary)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}
