import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class SplitBillViewModel: ObservableObject {

    @Published var splitBills:   [SplitBillModel] = []
    @Published var isLoading     = false
    @Published var errorMessage: String?

    private let db = FirestoreService.shared
    private var ownerListener: ListenerRegistration?
    private var participantListener: ListenerRegistration?

    // Temporary storage for combining results from both listeners
    private var ownerBills: [SplitBillModel] = []
    private var participantBills: [SplitBillModel] = []

    deinit {
        ownerListener?.remove()
        participantListener?.remove()
    }

    // MARK: - Computed
    var activeBills: [SplitBillModel] {
        splitBills.filter { $0.status == .active }
    }

    var settledBills: [SplitBillModel] {
        splitBills.filter { $0.status == .settled }
    }

    // MARK: - Listen to user's split bills (real-time)
    // Listens to bills where user is owner OR participant
    func listenSplitBills(uid: String) {
        print("🔊 [SplitBillVM] Starting listeners for user (uid: \(uid))")
        print("   🔑 User UID for participant query: '\(uid)'")

        // Listener 1: Bills where user is owner (for backward compatibility)
        ownerListener = db.listen(collection: Collection.splitBills, queryBuilder: { ref in
            ref.whereField("ownerUID", isEqualTo: uid)
               .order(by: "createdAt", descending: true)
        }) { [weak self] (bills: [SplitBillModel]) in
            print("📥 [SplitBillVM] Owner listener received \(bills.count) bills")
            for bill in bills {
                print("   📄 Bill '\(bill.title)': participantUIDs = \(bill.participantUIDs)")
            }

            // Auto-migrate old bills: update participantUIDs if missing
            Task { [weak self] in
                await self?.migrateOldBills(bills)
            }

            self?.ownerBills = bills
            self?.combineAndPublishBills()
        }

        // Listener 2: Bills where user is participant (but not owner to avoid duplicates)
        // Note: We don't use orderBy here to avoid needing a composite index
        // Sorting is done in combineAndPublishBills() instead
        print("🔍 [SplitBillVM] Setting up participant listener with arrayContains: '\(uid)'")
        participantListener = db.listen(collection: Collection.splitBills, queryBuilder: { ref in
            ref.whereField("participantUIDs", arrayContains: uid)
        }) { [weak self] (bills: [SplitBillModel]) in
            print("📥 [SplitBillVM] Participant listener received \(bills.count) bills (before filtering)")
            for bill in bills {
                print("   📄 Bill '\(bill.title)': ownerUID=\(bill.ownerUID), participantUIDs=\(bill.participantUIDs)")
            }

            // Filter out bills where user is owner (already handled by ownerListener)
            let nonOwnerBills = bills.filter { $0.ownerUID != uid }
            print("📥 [SplitBillVM] After filtering (excluding owner): \(nonOwnerBills.count) bills")

            self?.participantBills = nonOwnerBills
            self?.combineAndPublishBills()
        }
    }

    // MARK: - Combine Bills from Both Listeners
    private func combineAndPublishBills() {
        // Combine owner bills and participant bills, remove duplicates by ID
        var allBills = ownerBills
        for bill in participantBills {
            if !allBills.contains(where: { $0.id == bill.id }) {
                allBills.append(bill)
            }
        }

        // Sort by createdAt descending
        allBills.sort { ($0.createdAt.dateValue() ?? Date.distantPast) > ($1.createdAt.dateValue() ?? Date.distantPast) }

        print("📊 [SplitBillVM] Combined bills: \(allBills.count) (owner: \(ownerBills.count), participant: \(participantBills.count))")

        self.splitBills = allBills
    }

    // MARK: - Migrate Old Bills
    private func migrateOldBills(_ bills: [SplitBillModel]) async {
        for bill in bills {
            // Check if bill needs migration (has empty or missing participantUIDs)
            guard let billID = bill.id else { continue }

            // If participantUIDs is empty or only has owner, migrate it
            if bill.participantUIDs.isEmpty || (bill.participantUIDs.count == 1 && bill.participantUIDs.contains(bill.ownerUID)) {
                print("🔄 [SplitBillVM] Migrating old bill: \(bill.title)")

                var updatedBill = bill
                var uids = bill.participants.compactMap { $0.uid }
                if !uids.contains(bill.ownerUID) {
                    uids.append(bill.ownerUID)
                }
                updatedBill.participantUIDs = uids

                do {
                    try db.db.collection(Collection.splitBills).document(billID).setData(from: updatedBill)
                    print("✅ [SplitBillVM] Migrated: \(bill.title) - added \(uids.count) UIDs")
                } catch {
                    print("❌ [SplitBillVM] Migration failed for \(bill.title): \(error)")
                }
            }
        }
    }

    // MARK: - Create split bill
    func createSplitBill(
        ownerUID:        String,
        ownerName:       String,
        ownerBankAccount: String? = nil,
        paidByUID:       String,
        paidByName:      String,
        title:           String,
        totalAmount:     Double,
        currency:        String,
        participants:    [SplitBillParticipant],
        source:          SplitBillSource,
        category:        ExpenseCategory? = nil,
        notes:           String? = nil,
        receiptURL:      String? = nil
    ) async -> SplitBillModel? {
        isLoading = true
        defer { isLoading = false }

        let docRef = db.newDocRef(collection: Collection.splitBills)

        // Extract participant UIDs (including owner)
        var participantUIDs = participants.compactMap { $0.uid }
        if !participantUIDs.contains(ownerUID) {
            participantUIDs.append(ownerUID)
        }

        // Debug logging
        print("🔍 [SplitBillVM] Creating split bill with participantUIDs:")
        print("   📝 Title: \(title)")
        print("   👤 Owner UID: \(ownerUID)")
        print("   👥 All participants:")
        for participant in participants {
            print("      - \(participant.displayName): uid=\(participant.uid ?? "nil")")
        }
        print("   📋 Final participantUIDs array: \(participantUIDs)")

        let bill = SplitBillModel(
            ownerUID: ownerUID, ownerName: ownerName,
            ownerBankAccount: ownerBankAccount,
            paidByUID: paidByUID, paidByName: paidByName,
            title: title, totalAmount: totalAmount, currency: currency,
            participants: participants, participantUIDs: participantUIDs,
            source: source,
            receiptURL: receiptURL, status: .active,
            category: category, notes: notes,
            createdAt: Timestamp(date: Date())
        )
        do {
            try db.db.collection(Collection.splitBills).document(docRef.documentID).setData(from: bill)
            print("✅ [SplitBillVM] Split bill saved successfully!")
            print("   📄 Document ID: \(docRef.documentID)")
            print("   📋 Saved participantUIDs: \(participantUIDs)")
            var created = bill
            created.id = docRef.documentID
            return created
        } catch {
            print("❌ [SplitBillVM] Failed to save split bill: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Toggle participant paid status
    func toggleParticipantPaidStatus(billID: String, participantID: String, isPaid: Bool) async {
        print("▶️ [SplitBillVM] toggleParticipantPaidStatus dipanggil untuk billID: \(billID), participantID: \(participantID), isPaid: \(isPaid)")
        
        guard let idx = splitBills.firstIndex(where: { $0.id == billID }),
              let pIdx = splitBills[idx].participants.firstIndex(where: { $0.id == participantID })
        else {
            print("❌ [SplitBillVM] Gagal: Tagihan atau partisipan tidak ditemukan di memori lokal.")
            return
        }

        var updatedBill = splitBills[idx]
        updatedBill.participants[pIdx].isPaid = isPaid
        print("⏳ [SplitBillVM] Menyiapkan data update... Partisipan \(updatedBill.participants[pIdx].displayName) diset menjadi isPaid = \(isPaid).")
        
        // Check if all paid → mark as settled, otherwise active
        if updatedBill.participants.allSatisfy({ $0.isPaid }) {
            updatedBill.status = .settled
            print("🎉 [SplitBillVM] Semua partisipan sudah lunas! Status tagihan diset menjadi .settled")
        } else {
            updatedBill.status = .active
            print("🔄 [SplitBillVM] Status tagihan diset kembali menjadi .active")
        }
        
        do {
            // Write entire updated object to Firestore
            print("📡 [SplitBillVM] Mengirim update ke Firestore (Collection: \(Collection.splitBills))...")
            try db.db.collection(Collection.splitBills).document(billID).setData(from: updatedBill)
            
            print("✅ [SplitBillVM] BERHASIL! Data berhasil disimpan di Firestore.")
            
            // Update local state immediately to ensure UI responsiveness
            splitBills[idx] = updatedBill
            print("🔄 [SplitBillVM] State lokal berhasil diperbarui.")
        } catch {
            errorMessage = error.localizedDescription
            print("🚨 [SplitBillVM] ERROR GAGAL UPDATE: \(error.localizedDescription)")
            print("🚨 [SplitBillVM] Detail Error: \(error)")
        }
    }

    // MARK: - Delete split bill
    func deleteSplitBill(billID: String) async {
        print("🗑️ [SplitBillVM] Deleting split bill: \(billID)")

        // First, check if bill has receipt photo and delete it from storage
        if let bill = splitBills.first(where: { $0.id == billID }),
           let receiptURL = bill.receiptURL,
           !receiptURL.isEmpty {
            print("📸 [SplitBillVM] Deleting receipt photo from storage...")
            do {
                try await FirebaseStorageService.shared.deleteImageByURL(receiptURL)
                print("✅ [SplitBillVM] Receipt photo deleted from storage")
            } catch {
                print("⚠️ [SplitBillVM] Failed to delete receipt photo (continuing...): \(error.localizedDescription)")
                // Continue with bill deletion even if photo deletion fails
            }
        }

        // Delete the bill document from Firestore
        do {
            try await db.delete(collection: Collection.splitBills, documentID: billID)
            print("✅ [SplitBillVM] Split bill deleted successfully from Firestore")
            print("   Listener should automatically update splitBills array")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [SplitBillVM] Failed to delete: \(error.localizedDescription)")
        }
    }
}
