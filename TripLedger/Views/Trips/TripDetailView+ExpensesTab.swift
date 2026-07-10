import SwiftUI
import FirebaseCore
import FirebaseFirestore

// MARK: - Expenses Tab (search, filter, day grouping)
extension TripDetailView {
    // MARK: - Expenses Tab
    var expensesTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Financial Summary Card
                financialSummaryCardView

                if expenseVM.expenses.isEmpty {
                    emptyState(icon: "receipt.fill", text: "Belum ada pengeluaran", sub: "Tap + untuk tambah expense pertamamu!")
                } else {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.textPrimary.opacity(0.4))

                        TextField("Cari pengeluaran...", text: $expenseSearchText)
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)

                        if !expenseSearchText.isEmpty {
                            Button {
                                expenseSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textPrimary.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.borderSoft, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Category Filter Pills
                    if !availableCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // "Semua" pill
                                Button {
                                    selectedCategory = nil
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.grid.2x2")
                                            .font(.system(size: 12))
                                        Text("Semua")
                                            .font(AppFont.caption())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == nil ? Color.brandPrimary : Color.cardFallback)
                                    .foregroundColor(selectedCategory == nil ? .white : .textPrimary.opacity(0.7))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedCategory == nil ? Color.clear : Color.borderSoft, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                // Category pills
                                ForEach(availableCategories, id: \.self) { category in
                                    let isSelected = selectedCategory == category
                                    let categoryColor = Color(hex: category.color)

                                    Button {
                                        if selectedCategory == category {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = category
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: category.icon)
                                                .font(.system(size: 12))
                                            Text(category.displayName)
                                                .font(AppFont.caption())
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? categoryColor : Color.cardFallback)
                                        .foregroundColor(isSelected ? .white : .textPrimary.opacity(0.7))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.clear : Color.borderSoft, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 8)
                        .padding(.top, 8)
                    }

                    if filteredExpenses.isEmpty {
                        // No search results
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(.textPrimary.opacity(0.2))
                            Text("Tidak ada hasil")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Text("Coba kata kunci lain")
                                .font(AppFont.footnote())
                                .foregroundColor(.textPrimary.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(groupedExpensesByDay.keys.sorted(by: >), id: \.self) { date in
                            VStack(alignment: .leading, spacing: 12) {
                                // Date Header
                                Text(formatDateHeader(date))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.textPrimary.opacity(0.8))
                                    .padding(.horizontal, 16)

                                // Expenses for this day
                                VStack(spacing: 12) {
                                    ForEach(groupedExpensesByDay[date] ?? []) { expense in
                                        NavigationLink(destination: ExpenseDetailView(expense: expense, currency: trip.currency)
                                            .environmentObject(expenseVM)
                                            .environmentObject(authVM)) {
                                            ExpenseRow(expense: expense, currency: trip.currency)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Filtered Expenses
    var filteredExpenses: [ExpenseModel] {
        var results = expenseVM.expenses

        // Filter by search text
        if !expenseSearchText.isEmpty {
            results = results.filter { expense in
                expense.title.localizedCaseInsensitiveContains(expenseSearchText)
            }
        }

        // Filter by category
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        return results
    }

    // MARK: - Available Categories (only show categories that have expenses)
    var availableCategories: [ExpenseCategory] {
        let usedCategories = Set(expenseVM.expenses.map { $0.category })
        return ExpenseCategory.allCases.filter { usedCategories.contains($0) }
    }

    // MARK: - Group Expenses by Day
    var groupedExpensesByDay: [Date: [ExpenseModel]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { expense in
            calendar.startOfDay(for: expense.createdAt.dateValue())
        }
        return grouped
    }

    // MARK: - Format Date Header
    func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "EEEE, d MMMM yyyy" // "Rabu, 25 Juli 2026"
        return formatter.string(from: date)
    }

    func emptyState(icon: String, text: String, sub: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundColor(.textPrimary.opacity(0.2))
            Text(text).font(AppFont.headline()).foregroundColor(.textPrimary.opacity(0.6))
            Text(sub).font(AppFont.footnote()).foregroundColor(.textPrimary.opacity(0.35)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
