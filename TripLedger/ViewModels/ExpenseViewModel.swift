import Foundation
import Combine
import FirebaseFirestore
import UIKit

@MainActor
final class ExpenseViewModel: ObservableObject {

    @Published var expenses:     [ExpenseModel] = []
    @Published var isLoading     = false
    @Published var errorMessage: String?

    private let db      = FirestoreService.shared
    private let storage = StorageService.shared
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    // MARK: - Listen to trip expenses (real-time)
    func listenExpenses(tripID: String) {
        listener = db.listen(collection: Collection.expenses, queryBuilder: { ref in
            ref.whereField("tripID", isEqualTo: tripID)
               .order(by: "createdAt", descending: true)
        }) { [weak self] (expenses: [ExpenseModel]) in
            self?.expenses = expenses
        }
    }

    // MARK: - Add expense (manual)
    func addExpense(
        tripID:      String,
        title:       String,
        amount:      Double,
        currency:    String,
        category:    ExpenseCategory,
        paidByUID:   String,
        paidByName:  String,
        splitType:   SplitType,
        members:     [TripMember],
        customSplits:[ExpenseSplit] = [],
        notes:       String? = nil,
        receiptImage:UIImage? = nil
    ) async {
        isLoading = true
        defer { isLoading = false }

        let docRef   = db.newDocRef(collection: Collection.expenses)
        let splits   = customSplits.isEmpty ? equalSplits(amount: amount, members: members) : customSplits

        var expense  = ExpenseModel(
            tripID: tripID, title: title, amount: amount, currency: currency,
            category: category, paidByUID: paidByUID, paidByName: paidByName,
            splitType: splitType, splits: splits, notes: notes,
            receiptURL: nil, createdAt: Timestamp(date: Date()), updatedAt: nil
        )

        do {
            // Upload receipt if provided
            if let image = receiptImage {
                let url = try await storage.uploadImage(image, path: StorageService.receiptPath(expenseID: docRef.documentID))
                expense.receiptURL = url
            }
            try db.db.collection(Collection.expenses).document(docRef.documentID).setData(from: expense)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Edit expense
    func updateExpense(expenseID: String, title: String, amount: Double, category: ExpenseCategory, notes: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await db.update(collection: Collection.expenses, documentID: expenseID, fields: [
                "title":     title,
                "amount":    amount,
                "category":  category.rawValue,
                "notes":     notes ?? "",
                "updatedAt": Timestamp(date: Date())
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete expense
    func deleteExpense(expenseID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await db.delete(collection: Collection.expenses, documentID: expenseID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Toggle split paid status
    func toggleExpenseSplitPaidStatus(expenseID: String, splitID: String, isPaid: Bool) async {
        guard let idx = expenses.firstIndex(where: { $0.id == expenseID }),
              let sIdx = expenses[idx].splits.firstIndex(where: { $0.id == splitID })
        else { return }
        
        var updatedExpense = expenses[idx]
        updatedExpense.splits[sIdx].isPaid = isPaid
        updatedExpense.updatedAt = Timestamp(date: Date())
        
        do {
            try db.db.collection(Collection.expenses).document(expenseID).setData(from: updatedExpense)
            expenses[idx] = updatedExpense
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Split equally helper
    private func equalSplits(amount: Double, members: [TripMember]) -> [ExpenseSplit] {
        guard !members.isEmpty else { return [] }
        let share = (amount / Double(members.count) * 100).rounded() / 100
        return members.map {
            ExpenseSplit(id: $0.uid, uid: $0.uid, displayName: $0.displayName, amount: share, items: [])
        }
    }

    // MARK: - Category totals (for reports)
    var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped.map { cat, exps in
            (category: cat, total: exps.reduce(0) { $0 + $1.amount })
        }.sorted { $0.total > $1.total }
    }

    var totalAmount: Double { expenses.reduce(0) { $0 + $1.amount } }
}
