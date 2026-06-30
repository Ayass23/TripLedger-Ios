import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var friendsVM: FriendsViewModel

    @State private var searchQuery = ""
    @State private var selectedUsers: Set<String> = [] // UIDs of selected users
    @State private var selectedUserModels: [UserModel] = [] // Full user models for selected users
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tambah Teman")
                            .font(AppFont.title2())
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text("Cari teman yang ingin kamu tambahkan")
                            .font(AppFont.subheadline())
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    // MARK: - Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundColor(.textSecondary)

                        TextField("Cari orang berdasarkan nama atau email...", text: $searchQuery)
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // MARK: - Selected Users
                    if !selectedUsers.isEmpty {
                        selectedUsersSection
                    }

                    // MARK: - Search Results
                    Group {
                        if searchQuery.isEmpty {
                            emptySearchState
                        } else if friendsVM.isLoading {
                            loadingState
                        } else if friendsVM.searchResults.isEmpty {
                            noResultsState
                        } else {
                            searchResultsList
                        }
                    }

                    Spacer()
                }

                // MARK: - Send Button
                if !selectedUsers.isEmpty {
                    VStack {
                        Spacer()
                        sendButton
                    }
                }
            }
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .alert("Berhasil!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .tint(.brandPrimary)
            .onChange(of: searchQuery) { newValue in
                if !newValue.isEmpty {
                    Task {
                        await performSearch(query: newValue)
                    }
                } else {
                    friendsVM.searchResults = []
                }
            }
            .task {
                // Load pending requests when view appears
                guard let currentUser = authVM.currentUser else { return }
                await friendsVM.loadOutgoingRequests(currentUID: currentUser.uid)
                await friendsVM.loadPendingRequests(currentUser: currentUser)
            }
        }
    }

    // MARK: - Selected Users Section
    private var selectedUsersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dipilih (\(selectedUsers.count))")
                .font(AppFont.caption())
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(getSelectedUserModels(), id: \.uid) { user in
                        SelectedUserChip(user: user) {
                            selectedUsers.remove(user.uid)
                            selectedUserModels.removeAll { $0.uid == user.uid }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Search Results List
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredSearchResults) { user in
                    SearchResultRow(
                        user: user,
                        isSelected: selectedUsers.contains(user.uid),
                        currentUserUID: authVM.currentUser?.uid ?? "",
                        currentUserFriends: authVM.currentUser?.friendUIDs ?? [],
                        outgoingRequests: friendsVM.outgoingRequests,
                        incomingRequests: friendsVM.pendingRequests
                    ) {
                        toggleUserSelection(user)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Empty States
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary.opacity(0.3))

            Text("Cari Teman")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            Text("Ketik username untuk mencari teman")
                .font(AppFont.subheadline())
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.brandPrimary)
            Text("Mencari...")
                .font(AppFont.subheadline())
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary.opacity(0.3))

            Text("Tidak Ditemukan")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            Text("Tidak ada pengguna dengan nama atau email tersebut")
                .font(AppFont.subheadline())
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Send Button
    private var sendButton: some View {
        Button {
            sendFriendRequests()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Kirim Permintaan (\(selectedUsers.count))")
                        .fontWeight(.semibold)
                }
            }
            .font(AppFont.subheadline())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isLoading ? Color.textSecondary.opacity(0.3) : Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .disabled(isLoading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Helper Functions
    private var filteredSearchResults: [UserModel] {
        guard let currentUID = authVM.currentUser?.uid else { return friendsVM.searchResults }

        // Filter out current user
        return friendsVM.searchResults.filter { $0.uid != currentUID }
    }

    private func getSelectedUserModels() -> [UserModel] {
        selectedUserModels
    }

    private func toggleUserSelection(_ user: UserModel) {
        if selectedUsers.contains(user.uid) {
            selectedUsers.remove(user.uid)
            selectedUserModels.removeAll { $0.uid == user.uid }
        } else {
            selectedUsers.insert(user.uid)
            selectedUserModels.append(user)
        }
    }

    private func performSearch(query: String) async {
        guard let currentUID = authVM.currentUser?.uid else { return }
        await friendsVM.searchUsers(query: query, currentUID: currentUID)
    }

    private func sendFriendRequests() {
        guard let currentUser = authVM.currentUser else { return }

        isLoading = true

        Task {
            let usersToSend = getSelectedUserModels()
            var successCount = 0

            for user in usersToSend {
                await friendsVM.sendRequest(from: currentUser, to: user)
                if friendsVM.errorMessage == nil {
                    successCount += 1
                }
            }

            isLoading = false

            if successCount > 0 {
                successMessage = successCount == 1 ?
                    "Permintaan pertemanan berhasil dikirim" :
                    "\(successCount) permintaan pertemanan berhasil dikirim"
                showSuccess = true
                selectedUsers.removeAll()
                selectedUserModels.removeAll()
                searchQuery = ""
                friendsVM.searchResults = []
            }
        }
    }
}

// MARK: - Selected User Chip
struct SelectedUserChip: View {
    let user: UserModel
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 24, height: 24)

                Text(user.displayName.prefix(1).uppercased())
                    .font(AppFont.caption2())
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.bold)
            }

            Text(user.displayName)
                .font(AppFont.caption())
                .foregroundColor(.textPrimary)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.brandPrimary.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let user: UserModel
    let isSelected: Bool
    let currentUserUID: String
    let currentUserFriends: [String]
    let outgoingRequests: [FriendRequest]
    let incomingRequests: [FriendRequest]
    let onTap: () -> Void

    private var isSuspended: Bool {
        user.isSuspended
    }

    private var relationshipStatus: RelationshipStatus {
        // Check if suspended first
        if isSuspended {
            return .suspended
        }

        // Check if already friends
        if currentUserFriends.contains(user.uid) {
            return .friend
        }

        // Check if there's an outgoing pending request to this user
        if outgoingRequests.contains(where: { $0.toUID == user.uid }) {
            return .pendingOutgoing
        }

        // Check if there's an incoming pending request from this user
        if incomingRequests.contains(where: { $0.fromUID == user.uid }) {
            return .pendingIncoming
        }

        return .none
    }

    enum RelationshipStatus {
        case friend
        case pendingOutgoing    // We sent request to them
        case pendingIncoming    // They sent request to us
        case suspended          // User is suspended
        case none
    }

    private var isDisabled: Bool {
        relationshipStatus != .none
    }

    var body: some View {
        Button {
            // Only allow selection if no relationship exists and not suspended
            if relationshipStatus == .none {
                onTap()
            }
        } label: {
            HStack(spacing: 12) {
                // Checkbox or nosign for suspended
                if isSuspended {
                    Image(systemName: "nosign")
                        .font(.system(size: 20))
                        .foregroundColor(.errorRed.opacity(0.5))
                        .frame(width: 24, height: 24)
                } else {
                    ZStack {
                        Circle()
                            .stroke(
                                relationshipStatus == .none ?
                                    (isSelected ? Color.brandPrimary : Color.textSecondary.opacity(0.3)) :
                                    Color.textSecondary.opacity(0.2),
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)

                        if isSelected && relationshipStatus == .none {
                            Circle()
                                .fill(Color.brandPrimary)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }

                // Avatar
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(isSuspended ? Color.errorRed.opacity(0.15) : Color.brandPrimary.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Text(user.displayName.prefix(1).uppercased())
                            .font(AppFont.headline())
                            .foregroundColor(isSuspended ? .errorRed : .brandPrimary)
                            .fontWeight(.bold)
                    }
                    .opacity(isSuspended ? 0.5 : 1.0)

                    if isSuspended {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.errorRed)
                            .background(Circle().fill(Color.baseFallback).frame(width: 16, height: 16))
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(user.displayName)
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(isSuspended ? .textPrimary.opacity(0.5) : .textPrimary)

                    Text(user.email)
                        .font(AppFont.caption2())
                        .foregroundColor(.textSecondary)

                    if isSuspended {
                        Text("Ditangguhkan")
                            .font(AppFont.caption2())
                            .foregroundColor(.errorRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.errorRed.opacity(0.15))
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                }

                Spacer()

                // Status Badge
                if relationshipStatus == .friend {
                    Text("Sudah Teman")
                        .font(AppFont.caption2())
                        .foregroundColor(.successGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.successGreen.opacity(0.15))
                        .clipShape(Capsule())
                } else if relationshipStatus == .pendingOutgoing {
                    Text("Menunggu")
                        .font(AppFont.caption2())
                        .foregroundColor(.warningAmber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.warningAmber.opacity(0.15))
                        .clipShape(Capsule())
                } else if relationshipStatus == .pendingIncoming {
                    Text("Sudah Mengirim")
                        .font(AppFont.caption2())
                        .foregroundColor(.brandPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandPrimary.opacity(0.15))
                        .clipShape(Capsule())
                }
                // Note: suspended badge is shown inline with name, not here
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isSuspended ? Color.cardFallback.opacity(0.5) :
                (relationshipStatus == .none ?
                    (isSelected ? Color.brandPrimary.opacity(0.05) : Color.cardFallback) :
                    Color.cardFallback.opacity(0.5))
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(
                        isSuspended ? Color.errorRed.opacity(0.3) :
                        (isSelected && relationshipStatus == .none ?
                            Color.brandPrimary.opacity(0.3) :
                            Color.clear),
                        lineWidth: 1
                    )
            )
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled)
    }
}

#Preview {
    AddFriendView()
        .environmentObject(AuthViewModel())
        .environmentObject(FriendsViewModel())
}
