import Foundation
import FirebaseFirestore

enum PendingBillItem: Identifiable {
    case splitBill(SplitBillModel)
    case expense(ExpenseModel, tripName: String) // Need tripName for context
    
    var id: String {
        switch self {
        case .splitBill(let bill):
            return "split_\(bill.id ?? UUID().uuidString)"
        case .expense(let exp, _):
            return "exp_\(exp.id ?? UUID().uuidString)"
        }
    }
    
    var title: String {
        switch self {
        case .splitBill(let bill):
            return bill.title
        case .expense(let exp, _):
            return exp.title
        }
    }
    
    var amount: Double {
        switch self {
        case .splitBill(let bill):
            return bill.totalAmount
        case .expense(let exp, _):
            return exp.amount
        }
    }
    
    var currency: String {
        switch self {
        case .splitBill(let bill):
            return bill.currency
        case .expense(let exp, _):
            return exp.currency
        }
    }
    
    var ownerName: String {
        switch self {
        case .splitBill(let bill):
            return bill.ownerName
        case .expense(let exp, _):
            return exp.paidByName
        }
    }
    
    var typeLabel: String {
        switch self {
        case .splitBill:
            return "Split Bill"
        case .expense(_, let tripName):
            return "Trip: \(tripName)"
        }
    }
    
    var participantCount: Int {
        switch self {
        case .splitBill(let bill):
            return bill.participants.count
        case .expense(let exp, _):
            return exp.splits.count
        }
    }
    
    var unpaidCount: Int {
        switch self {
        case .splitBill(let bill):
            return bill.unpaidCount
        case .expense(let exp, _):
            return exp.splits.filter { $0.isPaid != true }.count
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
        }
        return CGFloat(paidCount) / CGFloat(participantCount)
    }
    
    var createdAt: Timestamp {
        switch self {
        case .splitBill(let bill):
            return bill.createdAt
        case .expense(let exp, _):
            return exp.createdAt
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
}
