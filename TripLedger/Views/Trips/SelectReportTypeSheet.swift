import SwiftUI

struct SelectReportTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelectTripSummary: () -> Void
    let onSelectPersonalExpense: () -> Void

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Text("Pilih Jenis Laporan")
                        .font(AppFont.title3())
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)

                    Text("Pilih laporan yang ingin kamu buat")
                        .font(AppFont.subheadline())
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)

                // Trip Summary Report Card
                Button {
                    onSelectTripSummary()
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.brandPrimary.opacity(0.15))
                                .frame(width: 56, height: 56)

                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.brandPrimary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trip Summary Report")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)

                            Text("Ringkasan keuangan trip secara keseluruhan")
                                .font(AppFont.caption())
                                .foregroundColor(.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary.opacity(0.4))
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                // Personal Expense Report Card
                Button {
                    onSelectPersonalExpense()
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.brandAccent.opacity(0.15))
                                .frame(width: 56, height: 56)

                            Image(systemName: "person.text.rectangle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.brandAccent)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Personal Expense Report")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)

                            Text("Laporan pengeluaran pribadi kamu")
                                .font(AppFont.caption())
                                .foregroundColor(.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary.opacity(0.4))
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

#Preview {
    SelectReportTypeSheet(
        onSelectTripSummary: {},
        onSelectPersonalExpense: {}
    )
}
