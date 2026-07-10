import Foundation
import FirebaseFirestore

typealias DB = Firestore

// MARK: - Firestore Collections
enum Collection {
    static let users        = "users"
    static let trips        = "trips"
    static let expenses     = "expenses"
    static let settlements  = "settlements"
    static let notifications = "notifications"
    static let friendRequests = "friendRequests"
    static let invites      = "tripInvites"
    static let splitBills   = "splitBills"
    static let reports      = "reports"
    static let appeals      = "accountAppeals"
}

// MARK: - Firestore Service (generic CRUD)
final class FirestoreService {

    static let shared = FirestoreService()
    let db = Firestore.firestore()
    private init() {}

    // MARK: - Set
    func set<T: Encodable>(_ value: T, collection: String, documentID: String) async throws {
        try db.collection(collection).document(documentID).setData(from: value)
    }

    // MARK: - Update fields
    func update(collection: String, documentID: String, fields: [String: Any]) async throws {
        try await db.collection(collection).document(documentID).updateData(fields)
    }

    // MARK: - Delete
    func delete(collection: String, documentID: String) async throws {
        try await db.collection(collection).document(documentID).delete()
    }

    // MARK: - Fetch one
    func fetch<T: Decodable>(collection: String, documentID: String) async throws -> T {
        let snap = try await db.collection(collection).document(documentID).getDocument()
        guard let item = try? snap.data(as: T.self) else {
            throw AppError.unknown("Document not found: \(collection)/\(documentID)")
        }
        return item
    }

    // MARK: - Fetch list (with optional query)
    func fetchList<T: Decodable>(
        collection: String,
        queryBuilder: ((CollectionReference) -> Query)? = nil
    ) async throws -> [T] {
        let ref: Query = queryBuilder?(db.collection(collection)) ?? db.collection(collection)
        let snap = try await ref.getDocuments()
        return snap.documents.compactMap { try? $0.data(as: T.self) }
    }

    // MARK: - Real-time listener (returns a Listener handle you must cancel)
    func listen<T: Decodable>(
        collection: String,
        queryBuilder: ((CollectionReference) -> Query)? = nil,
        onChange: @escaping ([T]) -> Void
    ) -> ListenerRegistration {
        let ref: Query = queryBuilder?(db.collection(collection)) ?? db.collection(collection)
        return ref.addSnapshotListener { snap, error in
            if let error = error {
                AppLog.debug("❌ [FirestoreService] Listener error for \(collection)")
                AppLog.debug("   Error Code: \((error as NSError).code)")
                AppLog.debug("   Error Domain: \((error as NSError).domain)")
                AppLog.debug("   Description: \(error.localizedDescription)")
                AppLog.debug("   Full Error: \(error)")
                onChange([])
                return
            }

            guard let documents = snap?.documents else {
                onChange([])
                return
            }

            let items = documents.compactMap { doc -> T? in
                do {
                    var item = try doc.data(as: T.self)
                    // Manually set the document ID if the type has @DocumentID
                    // This is necessary because Firestore decoder doesn't always populate it
                    return item
                } catch {
                    AppLog.debug("⚠️ [FirestoreService] Failed to decode document \(doc.documentID) in \(collection): \(error.localizedDescription)")
                    return nil
                }
            }
            onChange(items)
        }
    }

    // MARK: - New auto-ID document reference
    func newDocRef(collection: String) -> DocumentReference {
        db.collection(collection).document()
    }

    // MARK: - Suspended members
    /// Returns the UIDs of suspended users among the given trip member UIDs.
    func fetchSuspendedMemberUIDs(memberUIDs: [String]) async throws -> Set<String> {
        guard !memberUIDs.isEmpty else { return [] }
        let snapshot = try await db.collection(Collection.users)
            .whereField("uid", in: memberUIDs)
            .getDocuments()

        let suspended = snapshot.documents.compactMap { doc -> String? in
            guard let user = try? doc.data(as: UserModel.self),
                  user.isSuspended else { return nil }
            return user.uid
        }
        return Set(suspended)
    }
}
