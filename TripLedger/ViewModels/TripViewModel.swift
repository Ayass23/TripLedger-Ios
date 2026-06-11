import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class TripViewModel: ObservableObject {

    @Published var activeTrips:  [TripModel] = []
    @Published var historyTrips: [TripModel] = []
    @Published var pendingInvites:[TripInvite] = []
    @Published var selectedTrip: TripModel?
    @Published var isLoading     = false
    @Published var errorMessage: String?

    private let db = FirestoreService.shared
    private var tripsListener:   ListenerRegistration?
    private var invitesListener: ListenerRegistration?

    deinit {
        tripsListener?.remove()
        invitesListener?.remove()
    }

    // MARK: - Listen to user's trips (real-time)
    func listenTrips(uid: String) {
        tripsListener?.remove()
        tripsListener = db.db.collection(Collection.trips)
            .whereField("memberUIDs", arrayContains: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("⚠️ TripVM listenTrips error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    return
                }
                let trips = snapshot?.documents.compactMap { try? $0.data(as: TripModel.self) } ?? []
                self?.activeTrips  = trips.filter { $0.status == .active }
                self?.historyTrips = trips.filter { $0.status == .finished }
            }
    }

    // MARK: - Listen to pending invites
    func listenInvites(uid: String) {
        invitesListener = db.listen(collection: Collection.invites, queryBuilder: { ref in
            ref.whereField("inviteeUID", isEqualTo: uid)
               .whereField("status", isEqualTo: TripInvite.TripInviteStatus.pending.rawValue)
        }) { [weak self] (invites: [TripInvite]) in
            self?.pendingInvites = invites
        }
    }

    // MARK: - Create trip
    func createTrip(name: String, currency: String, emoji: String, startDate: Date?, endDate: Date?, owner: UserModel, additionalMembers: [UserModel] = []) async -> TripModel? {
        isLoading = true
        defer { isLoading = false }
        let docRef = db.newDocRef(collection: Collection.trips)
        let now = Timestamp(date: Date())

        // Owner member
        let ownerMember = TripMember(id: owner.uid, uid: owner.uid, displayName: owner.displayName, avatarURL: owner.avatarURL, role: .owner, joinedAt: now)

        // Additional members
        var allMembers = [ownerMember]
        var allMemberUIDs = [owner.uid]
        for user in additionalMembers {
            guard user.uid != owner.uid else { continue }
            let member = TripMember(id: user.uid, uid: user.uid, displayName: user.displayName, avatarURL: user.avatarURL, role: .member, joinedAt: now)
            allMembers.append(member)
            allMemberUIDs.append(user.uid)
        }

        let trip = TripModel(
            name: name, currency: currency,
            ownerUID: owner.uid, adminUIDs: [owner.uid], memberUIDs: allMemberUIDs,
            members: allMembers, coverEmoji: emoji, status: .active,
            startDate: startDate.map { Timestamp(date: $0) },
            endDate: endDate.map { Timestamp(date: $0) },
            createdAt: now, finishedAt: nil
        )
        do {
            try db.db.collection(Collection.trips).document(docRef.documentID).setData(from: trip)
            var created = trip
            created.id = docRef.documentID
            return created
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Invite member
    func inviteMember(trip: TripModel, invitee: UserModel, inviter: UserModel) async {
        let docRef = db.newDocRef(collection: Collection.invites)
        let invite = TripInvite(
            id: nil, tripID: trip.id ?? "", tripName: trip.name,
            inviterUID: inviter.uid, inviterName: inviter.displayName,
            inviteeUID: invitee.uid, status: .pending, createdAt: Timestamp(date: Date())
        )
        do {
            try db.db.collection(Collection.invites).document(docRef.documentID).setData(from: invite)
            
            // Add pending member to trip
            if let tripID = trip.id {
                let pendingMemberDict: [String: Any] = [
                    "id": invitee.uid,
                    "uid": invitee.uid,
                    "displayName": invitee.displayName,
                    "avatarURL": invitee.avatarURL ?? "",
                    "role": "pending",
                    "joinedAt": Timestamp(date: Date())
                ]
                try await db.update(collection: Collection.trips, documentID: tripID, fields: [
                    "members": FieldValue.arrayUnion([pendingMemberDict])
                ])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Accept invite
    func acceptInvite(_ invite: TripInvite, user: UserModel) async {
        guard let inviteID = invite.id else { return }
        do {
            try await db.update(collection: Collection.invites, documentID: inviteID, fields: ["status": "accepted"])
            
            let tripDoc = try await db.db.collection(Collection.trips).document(invite.tripID).getDocument()
            if var trip = try? tripDoc.data(as: TripModel.self) {
                trip.members.removeAll(where: { $0.uid == user.uid })
                
                let newMember = TripMember(id: user.uid, uid: user.uid, displayName: user.displayName, avatarURL: user.avatarURL, role: .member, joinedAt: Timestamp(date: Date()))
                trip.members.append(newMember)
                
                if !trip.memberUIDs.contains(user.uid) {
                    trip.memberUIDs.append(user.uid)
                }
                
                let memberDicts = trip.members.map { [
                    "id": $0.id,
                    "uid": $0.uid,
                    "displayName": $0.displayName,
                    "avatarURL": $0.avatarURL ?? "",
                    "role": $0.role.rawValue,
                    "joinedAt": $0.joinedAt
                ]}
                
                try await db.update(collection: Collection.trips, documentID: invite.tripID, fields: [
                    "memberUIDs": trip.memberUIDs,
                    "members": memberDicts
                ])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reject invite
    func rejectInvite(_ invite: TripInvite) async {
        guard let inviteID = invite.id else { return }
        do {
            try await db.update(collection: Collection.invites, documentID: inviteID, fields: ["status": "rejected"])
            
            let tripDoc = try await db.db.collection(Collection.trips).document(invite.tripID).getDocument()
            if var trip = try? tripDoc.data(as: TripModel.self) {
                trip.members.removeAll(where: { $0.uid == invite.inviteeUID })
                
                let memberDicts = trip.members.map { [
                    "id": $0.id,
                    "uid": $0.uid,
                    "displayName": $0.displayName,
                    "avatarURL": $0.avatarURL ?? "",
                    "role": $0.role.rawValue,
                    "joinedAt": $0.joinedAt
                ]}
                
                try await db.update(collection: Collection.trips, documentID: invite.tripID, fields: [
                    "members": memberDicts
                ])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Finish trip
    func finishTrip(tripID: String) async {
        do {
            try await db.update(collection: Collection.trips, documentID: tripID, fields: [
                "status":     TripStatus.finished.rawValue,
                "finishedAt": Timestamp(date: Date())
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete trip
    func deleteTrip(tripID: String) async {
        guard !tripID.isEmpty else {
            errorMessage = "Trip ID tidak valid"
            return
        }
        do {
            try await db.db.collection(Collection.trips).document(tripID).delete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Kick member
    func kickMember(tripID: String, memberUID: String) async {
        do {
            let tripDoc = try await db.db.collection(Collection.trips).document(tripID).getDocument()
            if var trip = try? tripDoc.data(as: TripModel.self) {
                trip.memberUIDs.removeAll(where: { $0 == memberUID })
                trip.members.removeAll(where: { $0.uid == memberUID })
                
                let memberDicts = trip.members.map { [
                    "id": $0.id,
                    "uid": $0.uid,
                    "displayName": $0.displayName,
                    "avatarURL": $0.avatarURL ?? "",
                    "role": $0.role.rawValue,
                    "joinedAt": $0.joinedAt
                ]}
                
                try await db.update(collection: Collection.trips, documentID: tripID, fields: [
                    "memberUIDs": trip.memberUIDs,
                    "members": memberDicts
                ])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Leave trip
    func leaveTrip(tripID: String, uid: String) async {
        await kickMember(tripID: tripID, memberUID: uid)
    }

    // MARK: - Transfer ownership
    func transferOwnership(tripID: String, newOwnerUID: String, currentOwnerUID: String) async {
        do {
            try await db.update(collection: Collection.trips, documentID: tripID, fields: [
                "ownerUID":  newOwnerUID,
                "adminUIDs": FieldValue.arrayUnion([newOwnerUID])
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
