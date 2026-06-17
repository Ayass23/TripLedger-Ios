import Foundation
import Combine
import FirebaseFirestore
import UIKit

@MainActor
final class DebtViewModel: ObservableObject {

    @Published var transactions:  [Transaction]      = []
    @Published var settlements:   [SettlementModel]  = []
    @Published var isLoading      = false
    @Published var errorMessage:  String?

    private let db      = FirestoreService.shared
    private let storage = StorageService.shared
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    // MARK: - Compute debts from expenses (Direct debt without simplification)
    func computeDebts(expenses: [ExpenseModel], members: [TripMember], currency: String) {
        let nameMap = Dictionary(uniqueKeysWithValues: members.map { ($0.uid, $0.displayName) })
        var directDebts: [String: Double] = [:] // key: "fromUID_toUID", value: amount

        // For each expense, calculate direct debts
        for expense in expenses {
            let payerUID = expense.paidByUID
            let payerName = nameMap[payerUID] ?? payerUID

            // Each person who owes money (except the payer) creates a direct debt
            for split in expense.splits {
                // Skip if this person is the payer
                if split.uid == payerUID { continue }

                let debtKey = "\(split.uid)_\(payerUID)"
                directDebts[debtKey, default: 0] += split.amount
            }
        }

        // Convert to Transaction objects
        var txList: [Transaction] = []
        for (key, amount) in directDebts {
            guard amount > 0.01 else { continue } // Skip negligible amounts

            let parts = key.split(separator: "_").map(String.init)
            guard parts.count == 2 else { continue }

            let fromUID = parts[0]
            let toUID = parts[1]
            let fromName = nameMap[fromUID] ?? fromUID
            let toName = nameMap[toUID] ?? toUID

            txList.append(Transaction(
                fromUID: fromUID,
                fromName: fromName,
                toUID: toUID,
                toName: toName,
                amount: amount
            ))
        }

        // Sort by amount (largest first) for better UX
        transactions = txList.sorted { $0.amount > $1.amount }
    }

    // MARK: - Listen to settlements
    func listenSettlements(tripID: String) {
        listener = db.listen(collection: Collection.settlements, queryBuilder: { ref in
            ref.whereField("tripID", isEqualTo: tripID)
               .order(by: "createdAt", descending: true)
        }) { [weak self] (settlements: [SettlementModel]) in
            self?.settlements = settlements
        }
    }

    // MARK: - Submit payment proof
    func submitPayment(
        tripID:   String,
        fromUID:  String,
        fromName: String,
        toUID:    String,
        toName:   String,
        amount:   Double,
        currency: String,
        notes:    String?,
        proof:    UIImage
    ) async {
        isLoading = true
        defer { isLoading = false }
        let docRef = db.newDocRef(collection: Collection.settlements)
        do {
            let proofURL = try await storage.uploadImage(proof, path: StorageService.proofPath(settlementID: docRef.documentID))
            let settlement = SettlementModel(
                id: docRef.documentID, tripID: tripID, fromUID: fromUID, fromName: fromName,
                toUID: toUID, toName: toName, amount: amount, currency: currency,
                status: .pending, proofURL: proofURL, notes: notes,
                createdAt: Timestamp(date: Date()), verifiedAt: nil, verifiedByUID: nil
            )
            try db.db.collection(Collection.settlements).document(docRef.documentID).setData(from: settlement)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Verify payment
    func verifyPayment(settlementID: String, verifierUID: String) async {
        do {
            try await db.update(collection: Collection.settlements, documentID: settlementID, fields: [
                "status":       SettlementStatus.verified.rawValue,
                "verifiedAt":   Timestamp(date: Date()),
                "verifiedByUID":verifierUID
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reject payment
    func rejectPayment(settlementID: String, verifierUID: String) async {
        do {
            try await db.update(collection: Collection.settlements, documentID: settlementID, fields: [
                "status":       SettlementStatus.rejected.rawValue,
                "verifiedByUID":verifierUID
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
