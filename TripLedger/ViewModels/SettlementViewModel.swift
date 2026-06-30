import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import UIKit

@MainActor
final class SettlementViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var pendingSettlements: [Settlement] = []
    @Published var myPendingSettlements: [Settlement] = []  // Settlements I created (waiting for approval)
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = FirestoreService.shared
    private var listener: ListenerRegistration?
    private var mySettlementsListener: ListenerRegistration?

    deinit {
        listener?.remove()
        mySettlementsListener?.remove()
    }

    // MARK: - Calculate User Balances
    /// Calculate all balances for current user in a trip
    func calculateBalances(
        expenses: [ExpenseModel],
        members: [TripMember],
        currentUID: String
    ) -> [UserBalance] {
        var balanceMap: [String: (owed: Double, receivable: Double, owedDetails: [ExpenseDebtDetail], receivableDetails: [ExpenseDebtDetail])] = [:]

        // Initialize all members
        for member in members where member.uid != currentUID {
            balanceMap[member.uid] = (0, 0, [], [])
        }

        // Process each expense
        for expense in expenses {
            let expenseDate = expense.createdAt.dateValue()

            // If current user paid this expense
            if expense.paidByUID == currentUID {
                // Others owe me (piutang)
                for split in expense.splits where split.uid != currentUID {
                    // Skip if already paid
                    if split.isPaid == true { continue }

                    var current = balanceMap[split.uid] ?? (0, 0, [], [])
                    current.receivable += split.amount
                    current.receivableDetails.append(ExpenseDebtDetail(
                        expenseID: expense.id ?? "",
                        splitID: split.id,
                        title: expense.title,
                        amount: split.amount,
                        paidByName: expense.paidByName,
                        createdAt: expenseDate
                    ))
                    balanceMap[split.uid] = current
                }
            } else {
                // If someone else paid, check if I owe them
                if let mySplit = expense.splits.first(where: { $0.uid == currentUID }) {
                    // Skip if already paid
                    if mySplit.isPaid == true { continue }

                    var current = balanceMap[expense.paidByUID] ?? (0, 0, [], [])
                    current.owed += mySplit.amount
                    current.owedDetails.append(ExpenseDebtDetail(
                        expenseID: expense.id ?? "",
                        splitID: mySplit.id,
                        title: expense.title,
                        amount: mySplit.amount,
                        paidByName: expense.paidByName,
                        createdAt: expenseDate
                    ))
                    balanceMap[expense.paidByUID] = current
                }
            }
        }

        // Convert to UserBalance array
        var balances: [UserBalance] = []
        for (uid, data) in balanceMap {
            guard let member = members.first(where: { $0.uid == uid }) else { continue }

            // Skip if no outstanding balance
            if data.owed < 0.01 && data.receivable < 0.01 { continue }

            balances.append(UserBalance(
                userUID: uid,
                userName: member.displayName,
                avatarURL: member.avatarURL,
                totalOwed: data.owed,
                totalReceivable: data.receivable,
                bankAccount: nil, // Will be fetched separately if needed
                owedDetails: data.owedDetails,
                receivableDetails: data.receivableDetails
            ))
        }

        // Sort by net amount (highest debt first)
        return balances.sorted { abs($0.netAmount) > abs($1.netAmount) }
    }

    // MARK: - Get Total Summary
    func getTotalSummary(balances: [UserBalance]) -> (totalOwed: Double, totalReceivable: Double, netAmount: Double) {
        let totalOwed = balances.reduce(0) { $0 + $1.totalOwed }
        let totalReceivable = balances.reduce(0) { $0 + $1.totalReceivable }
        let netAmount = totalOwed - totalReceivable
        return (totalOwed, totalReceivable, netAmount)
    }

    // MARK: - Listen to Pending Settlements (for verification)
    func listenPendingSettlements(tripID: String, userUID: String) {
        listener?.remove()
        mySettlementsListener?.remove()

        // Listen for settlements where I need to verify (toUID = me, status = pending)
        listener = db.listen(collection: Collection.settlements, queryBuilder: { ref in
            ref.whereField("tripID", isEqualTo: tripID)
               .whereField("toUID", isEqualTo: userUID)
               .whereField("status", isEqualTo: SettlementStatus.pending.rawValue)
        }) { [weak self] (settlements: [Settlement]) in
            self?.pendingSettlements = settlements
        }

        // Also listen to my pending settlements (fromUID = me) - real-time for status updates
        mySettlementsListener = db.listen(collection: Collection.settlements, queryBuilder: { ref in
            ref.whereField("tripID", isEqualTo: tripID)
               .whereField("fromUID", isEqualTo: userUID)
               .whereField("status", isEqualTo: SettlementStatus.pending.rawValue)
        }) { [weak self] (settlements: [Settlement]) in
            self?.myPendingSettlements = settlements
        }
    }

    // MARK: - Fetch My Pending Settlements
    func fetchMyPendingSettlements(tripID: String, userUID: String) async {
        do {
            let settlements: [Settlement] = try await db.fetchList(collection: Collection.settlements) { ref in
                ref.whereField("tripID", isEqualTo: tripID)
                   .whereField("fromUID", isEqualTo: userUID)
                   .whereField("status", isEqualTo: SettlementStatus.pending.rawValue)
            }
            myPendingSettlements = settlements
        } catch {
            print("Error fetching my pending settlements: \(error)")
        }
    }

    // MARK: - Create Settlement
    func createSettlement(
        tripID: String,
        tripName: String,
        fromUser: (uid: String, name: String),
        toUser: (uid: String, name: String, bankAccount: String?),
        amount: Double,
        currency: String,
        proofImage: UIImage?,
        expenseSplitRefs: [ExpenseSplitRef]
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            // Upload proof image if exists
            var proofURL: String? = nil
            if let image = proofImage {
                proofURL = try await uploadProofImage(image: image, tripID: tripID)
            }

            // Create settlement document
            let docRef = db.newDocRef(collection: Collection.settlements)
            let settlement = Settlement(
                id: docRef.documentID,
                tripID: tripID,
                tripName: tripName,
                fromUID: fromUser.uid,
                fromName: fromUser.name,
                toUID: toUser.uid,
                toName: toUser.name,
                toBankAccount: toUser.bankAccount,
                totalAmount: amount,
                currency: currency,
                proofImageURL: proofURL,
                status: .pending,
                rejectionReason: nil,
                expenseSplitRefs: expenseSplitRefs,
                createdAt: Timestamp(date: Date()),
                verifiedAt: nil
            )

            try db.db.collection(Collection.settlements).document(docRef.documentID).setData(from: settlement)

            // Send notification to receiver
            await sendSettlementNotification(
                to: toUser.uid,
                type: .settlementProof,
                title: "Konfirmasi Pembayaran",
                body: "\(fromUser.name) mengkonfirmasi pembayaran \(amount.toCurrency(symbol: currency)) untuk trip \(tripName)",
                referenceID: docRef.documentID,
                senderUID: fromUser.uid,
                senderName: fromUser.name
            )

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Approve Settlement
    func approveSettlement(settlement: Settlement, expenseVM: ExpenseViewModel) async -> Bool {
        guard let settlementID = settlement.id else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            // Update settlement status
            try await db.update(collection: Collection.settlements, documentID: settlementID, fields: [
                "status": SettlementStatus.approved.rawValue,
                "verifiedAt": Timestamp(date: Date())
            ])

            // Mark all related expense splits as paid
            for ref in settlement.expenseSplitRefs {
                await expenseVM.toggleExpenseSplitPaidStatus(
                    expenseID: ref.expenseID,
                    splitID: ref.splitID,
                    isPaid: true
                )
            }

            // Send notification to sender
            await sendSettlementNotification(
                to: settlement.fromUID,
                type: .paymentVerified,
                title: "Pembayaran Diterima",
                body: "\(settlement.toName) telah menerima pembayaran \(settlement.totalAmount.toCurrency(symbol: settlement.currency))",
                referenceID: settlementID,
                senderUID: settlement.toUID,
                senderName: settlement.toName
            )

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Reject Settlement
    func rejectSettlement(settlement: Settlement, reason: String) async -> Bool {
        guard let settlementID = settlement.id else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            try await db.update(collection: Collection.settlements, documentID: settlementID, fields: [
                "status": SettlementStatus.rejected.rawValue,
                "rejectionReason": reason,
                "verifiedAt": Timestamp(date: Date())
            ])

            // Send notification to sender
            await sendSettlementNotification(
                to: settlement.fromUID,
                type: .paymentRejected,
                title: "Pembayaran Ditolak",
                body: "\(settlement.toName) menolak pembayaran: \(reason)",
                referenceID: settlementID,
                senderUID: settlement.toUID,
                senderName: settlement.toName
            )

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Upload Proof Image
    private func uploadProofImage(image: UIImage, tripID: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.3) else {
            throw AppError.unknown("Failed to compress image")
        }

        let fileName = "\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference()
            .child("settlements")
            .child(tripID)
            .child(fileName)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // Upload and get metadata with download URL in one operation
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)

        // Get download URL after upload completes
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }

    // MARK: - Send Notification
    private func sendSettlementNotification(
        to recipientUID: String,
        type: AppNotificationType,
        title: String,
        body: String,
        referenceID: String,
        senderUID: String,
        senderName: String
    ) async {
        let notifRef = db.db.collection(Collection.notifications).document()
        let notification: [String: Any] = [
            "recipientUID": recipientUID,
            "type": type.rawValue,
            "title": title,
            "body": body,
            "isRead": false,
            "referenceID": referenceID,
            "senderUID": senderUID,
            "senderName": senderName,
            "createdAt": Timestamp(date: Date())
        ]

        do {
            try await notifRef.setData(notification)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }

    // MARK: - Fetch User Bank Account
    func fetchUserBankAccount(userUID: String) async -> String? {
        do {
            let user: UserModel = try await db.fetch(collection: Collection.users, documentID: userUID)
            if let bankInfo = user.bankInfo {
                return "\(bankInfo.bankName) - \(bankInfo.accountNumber) a.n. \(bankInfo.accountName)"
            }
            return nil
        } catch {
            return nil
        }
    }
}
