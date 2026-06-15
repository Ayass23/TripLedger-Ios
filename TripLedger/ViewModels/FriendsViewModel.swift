import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class FriendsViewModel: ObservableObject {

    @Published var friends:        [UserModel]      = []
    @Published var searchResults:  [UserModel]      = []
    @Published var pendingRequests:[FriendRequest]  = []  // Incoming requests
    @Published var outgoingRequests:[FriendRequest] = []  // Outgoing requests
    @Published var isLoading       = false
    @Published var errorMessage:   String?

    private let db  = FirestoreService.shared
    private var requestsListener: ListenerRegistration?

    deinit { requestsListener?.remove() }

    // MARK: - Load friend list
    func loadFriends(currentUser: UserModel) async {
        guard !currentUser.friendUIDs.isEmpty else { friends = []; return }
        isLoading = true
        defer { isLoading = false }
        do {
            friends = try await db.fetchList(collection: Collection.users) { ref in
                ref.whereField("uid", in: currentUser.friendUIDs)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Search users
    func searchUsers(query: String, currentUID: String) async {
        guard !query.isBlank else {
            searchResults = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let lowerQuery = query.lowercased()

            // Search by email prefix (case-insensitive)
            let byEmail: [UserModel] = try await db.fetchList(collection: Collection.users) { ref in
                ref.whereField("email", isGreaterThanOrEqualTo: lowerQuery)
                   .whereField("email", isLessThan: lowerQuery + "\u{f8ff}")
                   .limit(to: 10)
            }

            // Search by name - try both lowercase and capitalized first letter
            let capitalizedQuery = query.prefix(1).uppercased() + query.dropFirst().lowercased()

            async let byNameLower: [UserModel] = db.fetchList(collection: Collection.users) { ref in
                ref.whereField("displayName", isGreaterThanOrEqualTo: lowerQuery)
                    .whereField("displayName", isLessThan: lowerQuery + "\u{f8ff}")
                    .limit(to: 10)
            }

            async let byNameCapital: [UserModel] = db.fetchList(collection: Collection.users) { ref in
                ref.whereField("displayName", isGreaterThanOrEqualTo: capitalizedQuery)
                    .whereField("displayName", isLessThan: capitalizedQuery + "\u{f8ff}")
                    .limit(to: 10)
            }

            async let byNameOriginal: [UserModel] = db.fetchList(collection: Collection.users) { ref in
                ref.whereField("displayName", isGreaterThanOrEqualTo: query)
                    .whereField("displayName", isLessThan: query + "\u{f8ff}")
                    .limit(to: 10)
            }

            // Run all queries in parallel
            let (emailResults, nameLowerResults, nameCapitalResults, nameOriginalResults) =
                try await (byEmail, byNameLower, byNameCapital, byNameOriginal)

            // Merge all results and remove duplicates
            let combined = emailResults + nameLowerResults + nameCapitalResults + nameOriginalResults
            let uniqueUsers = Dictionary(grouping: combined, by: { $0.uid })
                .compactMap { $0.value.first }

            // Filter out current user and sort by relevance
            searchResults = uniqueUsers
                .filter { $0.uid != currentUID }
                .sorted { user1, user2 in
                    // Prioritize exact matches (case-insensitive)
                    let name1Lower = user1.displayName.lowercased()
                    let name2Lower = user2.displayName.lowercased()

                    if name1Lower == lowerQuery && name2Lower != lowerQuery { return true }
                    if name2Lower == lowerQuery && name1Lower != lowerQuery { return false }

                    // Then prioritize starts with
                    let starts1 = name1Lower.hasPrefix(lowerQuery)
                    let starts2 = name2Lower.hasPrefix(lowerQuery)

                    if starts1 && !starts2 { return true }
                    if starts2 && !starts1 { return false }

                    // Otherwise alphabetical
                    return name1Lower < name2Lower
                }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send friend request
    func sendRequest(from current: UserModel, to target: UserModel) async {
        print("📤 [FriendsVM] Sending friend request from \(current.displayName) to \(target.displayName)")

        // Check if already friends
        if current.friendUIDs.contains(target.uid) {
            print("⚠️ [FriendsVM] Already friends with \(target.displayName)")
            errorMessage = "Sudah berteman dengan \(target.displayName)"
            return
        }

        // Check if request already exists
        do {
            let existingRequests: [FriendRequest] = try await db.fetchList(collection: Collection.friendRequests) { ref in
                ref.whereField("fromUID", isEqualTo: current.uid)
                   .whereField("toUID", isEqualTo: target.uid)
                   .whereField("status", isEqualTo: FriendRequest.FriendRequestStatus.pending.rawValue)
                   .limit(to: 1)
            }

            if !existingRequests.isEmpty {
                print("⚠️ [FriendsVM] Request already exists for \(target.displayName)")
                errorMessage = "Permintaan sudah dikirim ke \(target.displayName)"
                return
            }

            // Create and send request
            let docRef = db.newDocRef(collection: Collection.friendRequests)
            let req = FriendRequest(
                id:        nil,
                fromUID:   current.uid,
                fromName:  current.displayName,
                fromAvatar:current.avatarURL,
                toUID:     target.uid,
                status:    .pending,
                createdAt: Timestamp(date: Date())
            )

            try await db.db.collection(Collection.friendRequests).document(docRef.documentID).setData(from: req)
            print("✅ [FriendsVM] Friend request sent successfully to \(target.displayName)")

            // Create notification for the recipient
            let notification = NotificationModel(
                recipientUID: target.uid,
                type: .friendRequest,
                title: "Permintaan Pertemanan",
                body: "\(current.displayName) ingin berteman dengan kamu",
                isRead: false,
                referenceID: docRef.documentID,
                senderUID: current.uid,
                senderName: current.displayName,
                createdAt: Timestamp(date: Date())
            )

            try await db.db.collection(Collection.notifications).addDocument(from: notification)
            print("✅ [FriendsVM] Notification created for \(target.displayName)")

            errorMessage = nil

        } catch {
            print("❌ [FriendsVM] Error sending friend request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Listen to incoming requests
    func listenPendingRequests(uid: String) {
        requestsListener = db.listen(collection: Collection.friendRequests, queryBuilder: { ref in
            ref.whereField("toUID", isEqualTo: uid)
               .whereField("status", isEqualTo: FriendRequest.FriendRequestStatus.pending.rawValue)
        }) { [weak self] (requests: [FriendRequest]) in
            self?.pendingRequests = requests
        }
    }

    // MARK: - Accept request
    func acceptRequest(_ request: FriendRequest, currentUID: String) async {
        guard let reqID = request.id else {
            print("❌ [FriendsVM] Cannot accept request: request ID is nil")
            return
        }

        print("✅ [FriendsVM] Accepting friend request from \(request.fromName)")

        do {
            // 1. Update request status to accepted
            print("📝 [FriendsVM] Updating request status to accepted...")
            try await db.db.collection(Collection.friendRequests)
                .document(reqID)
                .updateData(["status": "accepted"])

            // 2. Add fromUID to current user's friendUIDs
            print("👥 [FriendsVM] Adding \(request.fromUID) to current user's friends...")
            try await db.db.collection(Collection.users)
                .document(currentUID)
                .updateData(["friendUIDs": FieldValue.arrayUnion([request.fromUID])])

            // 3. Add currentUID to fromUser's friendUIDs
            print("👥 [FriendsVM] Adding \(currentUID) to \(request.fromName)'s friends...")
            try await db.db.collection(Collection.users)
                .document(request.fromUID)
                .updateData(["friendUIDs": FieldValue.arrayUnion([currentUID])])

            // 4. Remove from pending requests
            print("🗑️ [FriendsVM] Removing request from pending list...")
            pendingRequests.removeAll { $0.id == reqID }

            print("✅ [FriendsVM] Friend request accepted successfully!")
            errorMessage = nil

        } catch {
            print("❌ [FriendsVM] Error accepting friend request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reject request
    func rejectRequest(_ request: FriendRequest) async {
        guard let reqID = request.id else {
            print("❌ [FriendsVM] Cannot reject request: request ID is nil")
            return
        }

        print("🚫 [FriendsVM] Rejecting friend request from \(request.fromName)")

        do {
            // Update request status to rejected
            try await db.db.collection(Collection.friendRequests)
                .document(reqID)
                .updateData(["status": "rejected"])

            // Remove from pending requests
            pendingRequests.removeAll { $0.id == reqID }

            print("✅ [FriendsVM] Friend request rejected successfully!")
            errorMessage = nil

        } catch {
            print("❌ [FriendsVM] Error rejecting friend request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Remove friend
    func removeFriend(friendID: String, currentUID: String) async {
        print("🗑️ [FriendsVM] Removing friend \(friendID)")

        do {
            // Remove friend from current user's friendUIDs
            try await db.db.collection(Collection.users)
                .document(currentUID)
                .updateData(["friendUIDs": FieldValue.arrayRemove([friendID])])

            // Remove current user from friend's friendUIDs
            try await db.db.collection(Collection.users)
                .document(friendID)
                .updateData(["friendUIDs": FieldValue.arrayRemove([currentUID])])

            // Remove from local list
            friends.removeAll { $0.uid == friendID }

            print("✅ [FriendsVM] Friend removed successfully!")
            errorMessage = nil

        } catch {
            print("❌ [FriendsVM] Error removing friend: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load pending requests
    func loadPendingRequests(currentUser: UserModel) async {
        do {
            pendingRequests = try await db.fetchList(collection: Collection.friendRequests) { ref in
                ref.whereField("toUID", isEqualTo: currentUser.uid)
                   .whereField("status", isEqualTo: FriendRequest.FriendRequestStatus.pending.rawValue)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load outgoing requests
    func loadOutgoingRequests(currentUID: String) async {
        do {
            outgoingRequests = try await db.fetchList(collection: Collection.friendRequests) { ref in
                ref.whereField("fromUID", isEqualTo: currentUID)
                   .whereField("status", isEqualTo: FriendRequest.FriendRequestStatus.pending.rawValue)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Accept friend request (with currentUser)
    func acceptFriendRequest(requestID: String, currentUser: UserModel) async {
        guard let request = pendingRequests.first(where: { $0.id == requestID }) else {
            print("❌ [FriendsVM] Cannot find request with ID: \(requestID)")
            return
        }

        // Accept the request
        await acceptRequest(request, currentUID: currentUser.uid)

        // Send notification to the requester (User A) that their request was accepted
        if errorMessage == nil {
            do {
                let notification = NotificationModel(
                    recipientUID: request.fromUID,
                    type: .friendRequest,
                    title: "Permintaan Diterima",
                    body: "\(currentUser.displayName) menerima permintaan pertemananmu",
                    isRead: false,
                    referenceID: request.id,
                    senderUID: currentUser.uid,
                    senderName: currentUser.displayName,
                    createdAt: Timestamp(date: Date())
                )

                try await db.db.collection(Collection.notifications).addDocument(from: notification)
                print("✅ [FriendsVM] Notification sent to \(request.fromName)")
            } catch {
                print("⚠️ [FriendsVM] Failed to send notification: \(error.localizedDescription)")
                // Don't set errorMessage since the main action succeeded
            }
        }

        // Reload friends list to show the newly added friend
        if errorMessage == nil {
            print("🔄 [FriendsVM] Reloading friends list after accepting request...")

            // Fetch updated current user to get updated friendUIDs
            do {
                let updatedUsers: [UserModel] = try await db.fetchList(collection: Collection.users) { ref in
                    ref.whereField("uid", isEqualTo: currentUser.uid).limit(to: 1)
                }

                if let updatedUser = updatedUsers.first {
                    await loadFriends(currentUser: updatedUser)
                }
            } catch {
                print("❌ [FriendsVM] Error reloading friends: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Decline friend request (with currentUser)
    func declineFriendRequest(requestID: String, currentUser: UserModel) async {
        guard let request = pendingRequests.first(where: { $0.id == requestID }) else { return }
        await rejectRequest(request)
    }

    // MARK: - Accept friend request by ID (from notification)
    func acceptFriendRequestByID(requestID: String, currentUser: UserModel, notificationID: String?) async {
        print("✅ [FriendsVM] Accepting friend request by ID: \(requestID)")

        do {
            // 1. Fetch the friend request document
            let docSnapshot = try await db.db.collection(Collection.friendRequests)
                .document(requestID)
                .getDocument()

            guard docSnapshot.exists else {
                print("❌ [FriendsVM] Request document does not exist: \(requestID)")
                errorMessage = "Permintaan tidak ditemukan"
                return
            }

            let request = try docSnapshot.data(as: FriendRequest.self)
            print("📋 [FriendsVM] Found request from \(request.fromName) to \(request.toUID)")

            // 2. Update request status to accepted
            print("📝 [FriendsVM] Updating request status to accepted...")
            try await db.db.collection(Collection.friendRequests)
                .document(requestID)
                .updateData(["status": "accepted"])

            // 3. Add fromUID to current user's friendUIDs
            print("👥 [FriendsVM] Adding \(request.fromUID) to current user's friends...")
            try await db.db.collection(Collection.users)
                .document(currentUser.uid)
                .updateData(["friendUIDs": FieldValue.arrayUnion([request.fromUID])])

            // 4. Add currentUID to fromUser's friendUIDs
            print("👥 [FriendsVM] Adding \(currentUser.uid) to \(request.fromName)'s friends...")
            try await db.db.collection(Collection.users)
                .document(request.fromUID)
                .updateData(["friendUIDs": FieldValue.arrayUnion([currentUser.uid])])

            // 5. Delete the notification
            if let notifID = notificationID {
                print("🗑️ [FriendsVM] Deleting notification \(notifID)...")
                try await db.db.collection(Collection.notifications)
                    .document(notifID)
                    .delete()
            }

            // 6. Send notification to the requester
            let notification = NotificationModel(
                recipientUID: request.fromUID,
                type: .friendRequest,
                title: "Permintaan Diterima",
                body: "\(currentUser.displayName) menerima permintaan pertemananmu",
                isRead: false,
                referenceID: requestID,
                senderUID: currentUser.uid,
                senderName: currentUser.displayName,
                createdAt: Timestamp(date: Date())
            )
            try await db.db.collection(Collection.notifications).addDocument(from: notification)

            print("✅ [FriendsVM] Friend request accepted successfully!")
            errorMessage = nil

        } catch {
            print("❌ [FriendsVM] Error accepting friend request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Decline friend request by ID (from notification)
    func declineFriendRequestByID(requestID: String, notificationID: String?) async {
        print("🚫 [FriendsVM] Declining friend request by ID: \(requestID)")

        do {
            // 1. Update request status to rejected
            try await db.db.collection(Collection.friendRequests)
                .document(requestID)
                .updateData(["status": "rejected"])

            // 2. Delete the notification
            if let notifID = notificationID {
                print("🗑️ [FriendsVM] Deleting notification \(notifID)...")
                try await db.db.collection(Collection.notifications)
                    .document(notifID)
                    .delete()
            }

            print("✅ [FriendsVM] Friend request declined successfully!")
            errorMessage = nil

        } catch {
            print("❌ [FriendsVM] Error declining friend request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send friend request by email
    func sendFriendRequest(from current: UserModel, toEmail: String) async {
        errorMessage = nil

        // Validate email
        guard !toEmail.isEmpty else {
            errorMessage = "Email tidak boleh kosong"
            return
        }

        guard toEmail.contains("@") else {
            errorMessage = "Format email tidak valid"
            return
        }

        // Don't send to yourself
        guard toEmail.lowercased() != current.email.lowercased() else {
            errorMessage = "Tidak bisa menambahkan diri sendiri"
            return
        }

        do {
            // Find user by email
            let users: [UserModel] = try await db.fetchList(collection: Collection.users) { ref in
                ref.whereField("email", isEqualTo: toEmail.lowercased())
                   .limit(to: 1)
            }

            guard let targetUser = users.first else {
                errorMessage = "Pengguna dengan email tersebut tidak ditemukan"
                return
            }

            // Check if already friends
            if current.friendUIDs.contains(targetUser.uid) {
                errorMessage = "Sudah berteman dengan pengguna ini"
                return
            }

            // Check if request already exists
            let existingRequests: [FriendRequest] = try await db.fetchList(collection: Collection.friendRequests) { ref in
                ref.whereField("fromUID", isEqualTo: current.uid)
                   .whereField("toUID", isEqualTo: targetUser.uid)
                   .whereField("status", isEqualTo: FriendRequest.FriendRequestStatus.pending.rawValue)
                   .limit(to: 1)
            }

            if !existingRequests.isEmpty {
                errorMessage = "Permintaan sudah dikirim sebelumnya"
                return
            }

            // Send request
            await sendRequest(from: current, to: targetUser)

        } catch {
            errorMessage = "Terjadi kesalahan: \(error.localizedDescription)"
        }
    }
}
