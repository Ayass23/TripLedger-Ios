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
            let fetchedFriends: [UserModel] = try await db.fetchList(collection: Collection.users) { ref in
                ref.whereField("uid", in: currentUser.friendUIDs)
            }
            // Filter out admin users from friends list (they should never be shown)
            friends = fetchedFriends.filter { $0.role != .admin }
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

            // Fetch all users (or a larger set) for client-side filtering
            // This supports partial/contains matching
            let allUsers: [UserModel] = try await db.fetchList(collection: Collection.users) { ref in
                ref.limit(to: 100) // Fetch up to 100 users for client-side filtering
            }

            // Filter users that contain the search query in their name or email (case-insensitive)
            let filteredUsers = allUsers.filter { user in
                let nameContains = user.displayName.lowercased().contains(lowerQuery)
                let emailContains = user.email.lowercased().contains(lowerQuery)
                return nameContains || emailContains
            }

            // Filter out current user AND admin users, sort by relevance (suspended users shown but marked)
            // IMPORTANT: Admin users should NEVER appear in search results
            searchResults = filteredUsers
                .filter { $0.uid != currentUID && $0.role != .admin }
                .sorted { user1, user2 in
                    let name1Lower = user1.displayName.lowercased()
                    let name2Lower = user2.displayName.lowercased()
                    let email1Lower = user1.email.lowercased()
                    let email2Lower = user2.email.lowercased()

                    // Prioritize exact matches (case-insensitive)
                    if name1Lower == lowerQuery && name2Lower != lowerQuery { return true }
                    if name2Lower == lowerQuery && name1Lower != lowerQuery { return false }
                    if email1Lower == lowerQuery && email2Lower != lowerQuery { return true }
                    if email2Lower == lowerQuery && email1Lower != lowerQuery { return false }

                    // Then prioritize starts with in name
                    let nameStarts1 = name1Lower.hasPrefix(lowerQuery)
                    let nameStarts2 = name2Lower.hasPrefix(lowerQuery)
                    if nameStarts1 && !nameStarts2 { return true }
                    if nameStarts2 && !nameStarts1 { return false }

                    // Then prioritize starts with in email
                    let emailStarts1 = email1Lower.hasPrefix(lowerQuery)
                    let emailStarts2 = email2Lower.hasPrefix(lowerQuery)
                    if emailStarts1 && !emailStarts2 { return true }
                    if emailStarts2 && !emailStarts1 { return false }

                    // Otherwise alphabetical by name
                    return name1Lower < name2Lower
                }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Send friend request
    func sendRequest(from current: UserModel, to target: UserModel) async {
        AppLog.debug("📤 [FriendsVM] Sending friend request from \(current.displayName) to \(target.displayName)")

        // Check if target is admin (admin cannot be added as friend)
        if target.role == .admin {
            AppLog.debug("⚠️ [FriendsVM] Cannot send friend request to admin user")
            errorMessage = "Tidak dapat menambahkan pengguna ini sebagai teman"
            return
        }

        // Check if already friends
        if current.friendUIDs.contains(target.uid) {
            AppLog.debug("⚠️ [FriendsVM] Already friends with \(target.displayName)")
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
                AppLog.debug("⚠️ [FriendsVM] Request already exists for \(target.displayName)")
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
            AppLog.debug("✅ [FriendsVM] Friend request sent successfully to \(target.displayName)")

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
            AppLog.debug("✅ [FriendsVM] Notification created for \(target.displayName)")

            errorMessage = nil

        } catch {
            AppLog.debug("❌ [FriendsVM] Error sending friend request: \(error.localizedDescription)")
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
            AppLog.debug("❌ [FriendsVM] Cannot accept request: request ID is nil")
            return
        }

        AppLog.debug("✅ [FriendsVM] Accepting friend request from \(request.fromName)")

        do {
            // 1. Update request status to accepted
            AppLog.debug("📝 [FriendsVM] Updating request status to accepted...")
            try await db.db.collection(Collection.friendRequests)
                .document(reqID)
                .updateData(["status": "accepted"])

            // 2. Add fromUID to current user's friendUIDs
            AppLog.debug("👥 [FriendsVM] Adding \(request.fromUID) to current user's friends...")
            try await db.db.collection(Collection.users)
                .document(currentUID)
                .updateData(["friendUIDs": FieldValue.arrayUnion([request.fromUID])])

            // 3. Add currentUID to fromUser's friendUIDs
            AppLog.debug("👥 [FriendsVM] Adding \(currentUID) to \(request.fromName)'s friends...")
            try await db.db.collection(Collection.users)
                .document(request.fromUID)
                .updateData(["friendUIDs": FieldValue.arrayUnion([currentUID])])

            // 4. Remove from pending requests
            AppLog.debug("🗑️ [FriendsVM] Removing request from pending list...")
            pendingRequests.removeAll { $0.id == reqID }

            AppLog.debug("✅ [FriendsVM] Friend request accepted successfully!")
            errorMessage = nil

        } catch {
            AppLog.debug("❌ [FriendsVM] Error accepting friend request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reject request
    func rejectRequest(_ request: FriendRequest) async {
        guard let reqID = request.id else {
            AppLog.debug("❌ [FriendsVM] Cannot reject request: request ID is nil")
            return
        }

        AppLog.debug("🚫 [FriendsVM] Rejecting friend request from \(request.fromName)")

        do {
            // Update request status to rejected
            try await db.db.collection(Collection.friendRequests)
                .document(reqID)
                .updateData(["status": "rejected"])

            // Remove from pending requests
            pendingRequests.removeAll { $0.id == reqID }

            AppLog.debug("✅ [FriendsVM] Friend request rejected successfully!")
            errorMessage = nil

        } catch {
            AppLog.debug("❌ [FriendsVM] Error rejecting friend request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Remove friend
    func removeFriend(friendID: String, currentUID: String) async {
        AppLog.debug("🗑️ [FriendsVM] Removing friend \(friendID)")

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

            AppLog.debug("✅ [FriendsVM] Friend removed successfully!")
            errorMessage = nil

        } catch {
            AppLog.debug("❌ [FriendsVM] Error removing friend: \(error.localizedDescription)")
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
            AppLog.debug("❌ [FriendsVM] Cannot find request with ID: \(requestID)")
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
                AppLog.debug("✅ [FriendsVM] Notification sent to \(request.fromName)")
            } catch {
                AppLog.debug("⚠️ [FriendsVM] Failed to send notification: \(error.localizedDescription)")
                // Don't set errorMessage since the main action succeeded
            }
        }

        // Reload friends list to show the newly added friend
        if errorMessage == nil {
            AppLog.debug("🔄 [FriendsVM] Reloading friends list after accepting request...")

            // Fetch updated current user to get updated friendUIDs
            do {
                let updatedUsers: [UserModel] = try await db.fetchList(collection: Collection.users) { ref in
                    ref.whereField("uid", isEqualTo: currentUser.uid).limit(to: 1)
                }

                if let updatedUser = updatedUsers.first {
                    await loadFriends(currentUser: updatedUser)
                }
            } catch {
                AppLog.debug("❌ [FriendsVM] Error reloading friends: \(error.localizedDescription)")
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
        AppLog.debug("✅ [FriendsVM] Accepting friend request by ID: \(requestID)")

        do {
            // 1. Fetch the friend request document
            let docSnapshot = try await db.db.collection(Collection.friendRequests)
                .document(requestID)
                .getDocument()

            guard docSnapshot.exists else {
                AppLog.debug("❌ [FriendsVM] Request document does not exist: \(requestID)")
                errorMessage = "Permintaan tidak ditemukan"
                return
            }

            let request = try docSnapshot.data(as: FriendRequest.self)
            AppLog.debug("📋 [FriendsVM] Found request from \(request.fromName) to \(request.toUID)")

            // 2. Update request status to accepted
            AppLog.debug("📝 [FriendsVM] Updating request status to accepted...")
            try await db.db.collection(Collection.friendRequests)
                .document(requestID)
                .updateData(["status": "accepted"])

            // 3. Add fromUID to current user's friendUIDs
            AppLog.debug("👥 [FriendsVM] Adding \(request.fromUID) to current user's friends...")
            try await db.db.collection(Collection.users)
                .document(currentUser.uid)
                .updateData(["friendUIDs": FieldValue.arrayUnion([request.fromUID])])

            // 4. Add currentUID to fromUser's friendUIDs
            AppLog.debug("👥 [FriendsVM] Adding \(currentUser.uid) to \(request.fromName)'s friends...")
            try await db.db.collection(Collection.users)
                .document(request.fromUID)
                .updateData(["friendUIDs": FieldValue.arrayUnion([currentUser.uid])])

            // 5. Delete the notification
            if let notifID = notificationID {
                AppLog.debug("🗑️ [FriendsVM] Deleting notification \(notifID)...")
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

            AppLog.debug("✅ [FriendsVM] Friend request accepted successfully!")
            errorMessage = nil

        } catch {
            AppLog.debug("❌ [FriendsVM] Error accepting friend request: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Decline friend request by ID (from notification)
    func declineFriendRequestByID(requestID: String, notificationID: String?) async {
        AppLog.debug("🚫 [FriendsVM] Declining friend request by ID: \(requestID)")

        do {
            // 1. Update request status to rejected
            try await db.db.collection(Collection.friendRequests)
                .document(requestID)
                .updateData(["status": "rejected"])

            // 2. Delete the notification
            if let notifID = notificationID {
                AppLog.debug("🗑️ [FriendsVM] Deleting notification \(notifID)...")
                try await db.db.collection(Collection.notifications)
                    .document(notifID)
                    .delete()
            }

            AppLog.debug("✅ [FriendsVM] Friend request declined successfully!")
            errorMessage = nil

        } catch {
            AppLog.debug("❌ [FriendsVM] Error declining friend request: \(error.localizedDescription)")
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

            // Check if target is admin (admin cannot be added as friend)
            if targetUser.role == .admin {
                errorMessage = "Tidak dapat menambahkan pengguna ini sebagai teman"
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
