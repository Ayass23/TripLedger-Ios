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

    // MARK: - Compute debts from expenses
    func computeDebts(expenses: [ExpenseModel], members: [TripMember], currency: String) {
        var payments:    [(uid: String, amount: Double)] = []
        var obligations: [(uid: String, amount: Double)] = []

        for expense in expenses {
            payments.append((uid: expense.paidByUID, amount: expense.amount))
            for split in expense.splits {
                obligations.append((uid: split.uid, amount: split.amount))
            }
        }

        let nameMap = Dictionary(uniqueKeysWithValues: members.map { ($0.uid, $0.displayName) })
        let balances = DebtSimplifier.computeBalances(payments: payments, obligations: obligations, memberNames: nameMap)
        transactions = DebtSimplifier.simplify(balances: balances)
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
