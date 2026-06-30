import Foundation
import FirebaseFirestore

// MARK: - Settlement Model
struct Settlement: Identifiable, Codable {
    @DocumentID var id: String?
    var tripID: String
    var tripName: String
    var fromUID: String           // Yang bayar hutang
    var fromName: String
    var toUID: String             // Yang menerima pembayaran
    var toName: String
    var toBankAccount: String?    // Info rekening penerima
    var totalAmount: Double       // Nilai net yang dibayar
    var currency: String
    var proofImageURL: String?    // Bukti transfer
    var status: SettlementStatus
    var rejectionReason: String?
    var expenseSplitRefs: [ExpenseSplitRef]  // Reference ke expense splits
    var createdAt: Timestamp
    var verifiedAt: Timestamp?
}

// MARK: - Expense Split Reference
struct ExpenseSplitRef: Codable, Identifiable {
    var id: String { "\(expenseID)_\(splitID)" }
    var expenseID: String
    var splitID: String
    var amount: Double
    var title: String

    enum CodingKeys: String, CodingKey {
        case expenseID, splitID, amount, title
    }
}

// MARK: - User Balance (for UI calculation)
struct UserBalance: Identifiable {
    var id: String { userUID }
    var userUID: String
    var userName: String
    var avatarURL: String?
    var totalOwed: Double        // Total hutang ke orang ini
    var totalReceivable: Double  // Total piutang dari orang ini
    var bankAccount: String?     // Info rekening orang ini

    var netAmount: Double {
        totalOwed - totalReceivable  // + = hutang, - = piutang
    }

    var isNetOwed: Bool {
        netAmount > 0.01
    }

    var isNetReceivable: Bool {
        netAmount < -0.01
    }

    var isSettled: Bool {
        abs(netAmount) < 0.01
    }

    var owedDetails: [ExpenseDebtDetail]      // Detail hutang
    var receivableDetails: [ExpenseDebtDetail] // Detail piutang
}

// MARK: - Expense Debt Detail
struct ExpenseDebtDetail: Identifiable {
    var id: String { "\(expenseID)_\(splitID)" }
    var expenseID: String
    var splitID: String
    var title: String
    var amount: Double
    var paidByName: String
    var createdAt: Date
}
