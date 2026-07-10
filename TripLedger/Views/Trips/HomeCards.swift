import SwiftUI
import FirebaseFirestore
import Kingfisher

//  HomeCards.swift
//  Kartu-kartu beranda: tagihan split bill pending, ringkasan utang trip, dan kartu trip.
// MARK: - Pending Bill Card (horizontal scroll - for Split Bills)
struct PendingBillCard: View {
    let item: PendingBillItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Icon + Title
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.brandAccent.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "rectangle.split.3x1.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.brandAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Text("\(item.unpaidCount) orang belum bayar")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.45))
                }
                Spacer()
            }

            // Amount Section
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Tagihan")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.5))
                    Text(item.amount.toCurrency(symbol: item.currency))
                        .font(AppFont.title3())
                        .fontWeight(.semibold)
                        .foregroundColor(.errorRed)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary.opacity(0.25))
            }

            // Type Badge
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                Text("Split Bill")
                    .font(AppFont.caption2())
            }
            .foregroundColor(.brandAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brandAccent.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(16)
        .frame(width: 220, height: 150)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// MARK: - Trip Debt Card (for accumulated trip debts)
struct TripDebtCard: View {
    let item: PendingBillItem

    private var tripEmoji: String {
        if case .tripAccumulated(_, _, let emoji, _, _, _, _) = item {
            return emoji
        }
        return "✈️"
    }

    private var expenseCount: Int {
        if case .tripAccumulated(_, _, _, _, _, let count, _) = item {
            return count
        }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Emoji + Title
            HStack(spacing: 10) {
                Text(tripEmoji)
                    .font(.system(size: 22))
                    .frame(width: 42, height: 42)
                    .background(Color.brandPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Text("\(expenseCount) pengeluaran")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.45))
                }
                Spacer()
            }

            // Amount Section
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Hutang")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.5))
                    Text(item.amount.toCurrency(symbol: item.currency))
                        .font(AppFont.title3())
                        .fontWeight(.semibold)
                        .foregroundColor(.errorRed)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary.opacity(0.25))
            }

            // Type Badge
            HStack(spacing: 4) {
                Image(systemName: "airplane")
                    .font(.system(size: 10))
                Text("Trip")
                    .font(AppFont.caption2())
            }
            .foregroundColor(.brandPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brandPrimary.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(16)
        .frame(width: 220, height: 150)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// MARK: - Trip Card
struct TripCard: View {
    let trip:  TripModel
    var dimmed: Bool = false

    private var formattedDate: String {
        let date = trip.startDate?.dateValue() ?? trip.createdAt.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }

    private var statusColor: Color {
        switch trip.status {
        case .planned:  return .brandAccent
        case .active:   return .successGreen
        case .finished: return .textPrimary.opacity(0.4)
        case .deleted:  return .errorRed
        }
    }

    private var statusLabel: String {
        switch trip.status {
        case .planned:  return "Direncanakan"
        case .active:   return "Aktif"
        case .finished: return "Selesai"
        case .deleted:  return "Dihapus"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Emoji avatar
            Text(trip.coverEmoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Color.textPrimary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // Trip info
            VStack(alignment: .leading, spacing: 5) {
                Text(trip.name)
                    .font(AppFont.headline())
                    .foregroundColor(dimmed ? .textPrimary.opacity(0.5) : .textPrimary)
                    .lineLimit(1)

                // Date row
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(formattedDate)
                }
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.45))

                // Members + Status row
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(trip.memberCount) anggota")
                    }
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.4))

                    // Status badge
                    Text(statusLabel)
                        .font(AppFont.caption2())
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textPrimary.opacity(0.25))
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}
