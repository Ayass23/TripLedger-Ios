import SwiftUI
import FirebaseCore
import FirebaseFirestore

// MARK: - Data Loading & Listeners
extension TripDetailView {
    // MARK: - Helper Functions
    func recalculateBalances() {
        guard let uid = authVM.currentUser?.uid else { return }
        userBalances = settlementVM.calculateBalances(
            expenses: expenseVM.expenses,
            members: currentTrip.members,
            currentUID: uid
        )
    }

    func loadSuspendedMembers() async {
        let memberUIDs = currentTrip.memberUIDs
        guard !memberUIDs.isEmpty else { return }

        do {
            suspendedMemberUIDs = try await FirestoreService.shared.fetchSuspendedMemberUIDs(memberUIDs: memberUIDs)
        } catch {
            AppLog.debug("Error loading suspended members: \(error)")
        }
    }

    func listenToTripUpdates() {
        guard let tripID = trip.id else { return }
        let db = FirestoreService.shared.db

        tripListener = db.collection(Collection.trips)
            .document(tripID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    AppLog.debug("Error listening to trip updates: \(error)")
                    return
                }

                guard let snapshot = snapshot,
                      let updatedTrip = try? snapshot.data(as: TripModel.self) else {
                    return
                }

                currentTrip = updatedTrip
            }
    }
}
