import SwiftUI
import Charts
import FirebaseCore

struct ReportView: View {
    @Environment(\.dismiss)          var dismiss
    @EnvironmentObject private var expenseVM: ExpenseViewModel

    let trip: TripModel

    @StateObject private var reportVM = ReportViewModel()
    @State private var pdfData:   Data?
    @State private var showShare  = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Total summary
                        totalCard

                        // Category chart
                        if !expenseVM.categoryTotals.isEmpty {
                            chartSection
                        }

                        // Expense list by category
                        ForEach(expenseVM.categoryTotals, id: \.category) { item in
                            categoryRow(item.category, total: item.total)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Laporan Trip")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundColor(.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        pdfData = reportVM.generatePDF(trip: trip, expenses: expenseVM.expenses)
                        if pdfData != nil { showShare = true }
                    } label: {
                        Label("Export PDF", systemImage: "square.and.arrow.up")
                            .foregroundColor(Color.accentFallback)
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let data = pdfData { ShareSheet(items: [data]) }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Total Card
    private var totalCard: some View {
        VStack(spacing: 6) {
            Text("Total Pengeluaran")
                .font(AppFont.subheadline()).foregroundColor(.textPrimary.opacity(0.5))
            Text(expenseVM.totalAmount.toCurrency(symbol: trip.currency))
                .font(AppFont.largeTitle()).foregroundColor(.textPrimary)
            Text("\(expenseVM.expenses.count) transaksi · \(trip.name)")
                .font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(LinearGradient.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
    }

    // MARK: - Chart
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pengeluaran per Kategori")
                .font(AppFont.subheadline()).foregroundColor(.textPrimary.opacity(0.6))

            Chart(expenseVM.categoryTotals, id: \.category) { item in
                SectorMark(
                    angle: .value("Total", item.total),
                    innerRadius: .ratio(0.55),
                    angularInset: 2
                )
                .foregroundStyle(Color(hex: item.category.color))
                .cornerRadius(4)
            }
            .frame(height: 220)
            .chartBackground { _ in Color.clear }
        }
        .padding(20)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    // MARK: - Category Row
    private func categoryRow(_ cat: ExpenseCategory, total: Double) -> some View {
        let pct = expenseVM.totalAmount > 0 ? total / expenseVM.totalAmount : 0
        return HStack(spacing: 14) {
            Image(systemName: cat.icon)
                .foregroundColor(Color(hex: cat.color))
                .frame(width: 36, height: 36)
                .background(Color(hex: cat.color).opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(cat.displayName).font(AppFont.subheadline()).foregroundColor(.textPrimary)
                    Spacer()
                    Text(total.toCurrency(symbol: trip.currency)).font(AppFont.subheadline()).foregroundColor(.textPrimary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.textPrimary.opacity(0.08))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: cat.color))
                            .frame(width: geo.size.width * pct, height: 5)
                    }
                }
                .frame(height: 5)
                Text("\(Int(pct * 100))%")
                    .font(AppFont.caption2()).foregroundColor(.textPrimary.opacity(0.4))
            }
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ReportView(trip: TripModel(name: "Bali", currency: "IDR", ownerUID: "1", adminUIDs: [], memberUIDs: [], members: [], coverEmoji: "🏝️", status: .active, startDate: nil, endDate: nil, createdAt: .init()))
        .environmentObject(ExpenseViewModel())
}
