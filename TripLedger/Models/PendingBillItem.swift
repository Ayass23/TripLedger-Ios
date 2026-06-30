import Foundation
import FirebaseFirestore

enum PendingBillItem: Identifiable {
    case splitBill(SplitBillModel)
    case expense(ExpenseModel, tripName: String) // Need tripName for context
    case tripAccumulated(tripID: String, tripName: String, tripEmoji: String, totalDebt: Double, currency: String, expenseCount: Int, expenses: [ExpenseModel])

    var id: String {
        switch self {
        case .splitBill(let bill):
            return "split_\(bill.id ?? UUID().uuidString)"
        case .expense(let exp, _):
            return "exp_\(exp.id ?? UUID().uuidString)"
        case .tripAccumulated(let tripID, _, _, _, _, _, _):
            return "trip_\(tripID)"
        }
    }

    var title: String {
        switch self {
        case .splitBill(let bill):
            return bill.title
        case .expense(let exp, _):
            return exp.title
        case .tripAccumulated(_, let tripName, _, _, _, _, _):
            return tripName
        }
    }

    var amount: Double {
        switch self {
        case .splitBill(let bill):
            return bill.totalAmount
        case .expense(let exp, _):
            return exp.amount
        case .tripAccumulated(_, _, _, let totalDebt, _, _, _):
            return totalDebt
        }
    }

    var currency: String {
        switch self {
        case .splitBill(let bill):
            return bill.currency
        case .expense(let exp, _):
            return exp.currency
        case .tripAccumulated(_, _, _, _, let currency, _, _):
            return currency
        }
    }

    var ownerName: String {
        switch self {
        case .splitBill(let bill):
            return bill.ownerName
        case .expense(let exp, _):
            return exp.paidByName
        case .tripAccumulated:
            return ""
        }
    }

    var typeLabel: String {
        switch self {
        case .splitBill:
            return "Split Bill"
        case .expense(_, let tripName):
            return "Trip: \(tripName)"
        case .tripAccumulated:
            return "Trip"
        }
    }

    var participantCount: Int {
        switch self {
        case .splitBill(let bill):
            return bill.participants.count
        case .expense(let exp, _):
            return exp.splits.count
        case .tripAccumulated(_, _, _, _, _, let expenseCount, _):
            return expenseCount
        }
    }

    var unpaidCount: Int {
        switch self {
        case .splitBill(let bill):
            return bill.unpaidCount
        case .expense(let exp, _):
            return exp.splits.filter { $0.isPaid != true }.count
        case .tripAccumulated(_, _, _, _, _, let expenseCount, _):
            return expenseCount
        }
    }

    var progressRatio: CGFloat {
        guard participantCount > 0 else { return 0 }
        let paidCount: Int
        switch self {
        case .splitBill(let bill):
            paidCount = bill.participants.filter { $0.isPaid }.count
        case .expense(let exp, _):
            paidCount = exp.splits.filter { $0.isPaid == true }.count
        case .tripAccumulated:
            // For accumulated trip debts, progress is 0 since user hasn't paid
            return 0
        }
        return CGFloat(paidCount) / CGFloat(participantCount)
    }

    var createdAt: Timestamp {
        switch self {
        case .splitBill(let bill):
            return bill.createdAt
        case .expense(let exp, _):
            return exp.createdAt
        case .tripAccumulated(_, _, _, _, _, _, let expenses):
            // Return most recent expense date
            return expenses.max(by: { $0.createdAt.dateValue() < $1.createdAt.dateValue() })?.createdAt ?? Timestamp(date: Date())
        }
    }

    // So we can easily extract the underlying models for navigation
    var underlyingSplitBill: SplitBillModel? {
        if case .splitBill(let bill) = self { return bill }
        return nil
    }

    var underlyingExpense: ExpenseModel? {
        if case .expense(let exp, _) = self { return exp }
        return nil
    }

    var underlyingTripAccumulated: (tripID: String, tripName: String, tripEmoji: String, totalDebt: Double, currency: String, expenses: [ExpenseModel])? {
        if case .tripAccumulated(let tripID, let tripName, let tripEmoji, let totalDebt, let currency, _, let expenses) = self {
            return (tripID, tripName, tripEmoji, totalDebt, currency, expenses)
        }
        return nil
    }
}
