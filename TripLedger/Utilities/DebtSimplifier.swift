import Foundation

// MARK: - Models
struct NetBalance {
    let uid: String
    let displayName: String
    var amount: Double   // positive = owed money, negative = owes money
}

struct Transaction: Identifiable {
    let id: String = UUID().uuidString
    let fromUID: String
    let fromName: String
    let toUID: String
    let toName: String
    let amount: Double
}

// MARK: - Min Cash Flow Algorithm
/// Greedy algorithm to minimize the number of transactions needed to settle debts.
enum DebtSimplifier {

    /// Given a list of net balances, returns the minimal set of transactions.
    static func simplify(balances: [NetBalance]) -> [Transaction] {
        guard !balances.isEmpty else { return [] }

        // Separate into creditors (owed money) and debtors (owe money)
        var creditors = balances.filter { $0.amount > 0.001 }
                                .sorted { $0.amount > $1.amount }
        var debtors   = balances.filter { $0.amount < -0.001 }
                                .sorted { $0.amount < $1.amount }

        var transactions: [Transaction] = []

        while !creditors.isEmpty && !debtors.isEmpty {
            var creditor = creditors.removeFirst()
            var debtor   = debtors.removeFirst()

            let amount = min(creditor.amount, -debtor.amount)
            transactions.append(Transaction(
                fromUID:  debtor.uid,
                fromName: debtor.displayName,
                toUID:    creditor.uid,
                toName:   creditor.displayName,
                amount:   amount
            ))

            creditor.amount -= amount
            debtor.amount   += amount

            if creditor.amount > 0.001 {
                creditors.insert(creditor, at: 0)
                creditors.sort { $0.amount > $1.amount }
            }
            if debtor.amount < -0.001 {
                debtors.insert(debtor, at: 0)
                debtors.sort { $0.amount < $1.amount }
            }
        }

        return transactions
    }

    /// Compute per-member net balances from a list of split details.
    /// - Parameters:
    ///   - payments: [(payerUID, amount)] — who paid what
    ///   - obligations: [(memberUID, amount)] — who owes what
    ///   - memberNames: uid → displayName mapping
    static func computeBalances(
        payments:    [(uid: String, amount: Double)],
        obligations: [(uid: String, amount: Double)],
        memberNames: [String: String]
    ) -> [NetBalance] {
        var net: [String: Double] = [:]

        for p in payments    { net[p.uid, default: 0] += p.amount }
        for o in obligations { net[o.uid, default: 0] -= o.amount }

        return net.map { uid, amount in
            NetBalance(uid: uid, displayName: memberNames[uid] ?? uid, amount: amount)
        }
    }
}
