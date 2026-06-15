import SwiftUI
import FirebaseFirestore

struct InviteMemberSheetView: View {
    let trip: TripModel
    @Binding var showInvite: Bool

    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var tripVM: TripViewModel
    @StateObject private var friendsVM = FriendsViewModel()

    @State private var searchQuery = ""
    @State private var selectedTab: SearchTab = .friends
    @State private var selectedMembers: Set<String> = []
    @State private var isInviting = false

    enum SearchTab: String, CaseIterable {
        case friends = "Teman"
        case search = "Pencarian"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Segmented Control
                segmentedControl
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Selected members chips
                if !selectedMembers.isEmpty {
                    selectedMembersChips
                }

                // Results list
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if selectedTab == .friends {
                            friendsList
                        } else {
                            searchResults
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        // Dismiss keyboard when tapping anywhere
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                )
                .padding(.top, 12)

                // Bottom buttons
                bottomButtons
            }
            .background(Color.baseFallback)
            .navigationTitle("Tambah Anggota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showInvite = false }
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
            }
        }
        .onAppear {
            if let user = authVM.currentUser {
                Task { await friendsVM.loadFriends(currentUser: user) }
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.textPrimary.opacity(0.35))
            TextField("Cari berdasarkan email atau nama...", text: $searchQuery)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onChange(of: searchQuery) { newValue in
                    if !newValue.isEmpty && selectedTab == .search {
                        guard let uid = authVM.currentUser?.uid else { return }
                        Task { await friendsVM.searchUsers(query: newValue, currentUID: uid) }
                    }
                }
            if !searchQuery.isEmpty {
                Button { searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textPrimary.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.textPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Segmented Control
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                        // Clear search when switching tabs
                        if tab == .friends {
                            searchQuery = ""
                        }
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(AppFont.subheadline())
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .white : .textPrimary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab ?
                                AnyShapeStyle(LinearGradient.brandGradient) :
                                AnyShapeStyle(Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
            }
        }
        .padding(4)
        .background(Color.textPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Selected Members Chips
    private var selectedMembersChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedMembers), id: \.self) { uid in
                    if let user = getUser(by: uid) {
                        HStack(spacing: 6) {
                            Text(user.initials)
                                .font(AppFont.caption2())
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(LinearGradient.brandGradient)
                                .clipShape(Circle())
                            Text(user.displayName.components(separatedBy: " ").first ?? user.displayName)
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary)
                            Button {
                                selectedMembers.remove(uid)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textPrimary.opacity(0.3))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.textPrimary.opacity(0.06))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }

    // MARK: - Friends List
    private var friendsList: some View {
        Group {
            if filteredFriends.isEmpty {
                emptyFriendsState
            } else {
                ForEach(filteredFriends) { friend in
                    userRow(friend)
                }
            }
        }
    }

    // MARK: - Search Results
    private var searchResults: some View {
        Group {
            if searchQuery.isBlank {
                emptySearchState
            } else if friendsVM.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if friendsVM.searchResults.isEmpty {
                noResultsState
            } else {
                ForEach(friendsVM.searchResults) { user in
                    userRow(user)
                }
            }
        }
    }

    // MARK: - User Row
    private func userRow(_ user: UserModel) -> some View {
        let isSelected = selectedMembers.contains(user.uid)
        let isCurrentUser = user.uid == authVM.currentUser?.uid
        let isMember = trip.members.contains(where: { $0.uid == user.uid })

        return HStack(spacing: 12) {
            AvatarView(url: user.avatarURL, initials: user.initials, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                Text(user.email)
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.4))
            }

            Spacer()

            if isCurrentUser {
                Text("Kamu")
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.4))
            } else if isMember {
                Text("Sudah Anggota")
                    .font(AppFont.caption2())
                    .foregroundColor(.successGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.successGreen.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Button {
                    if isSelected {
                        selectedMembers.remove(user.uid)
                    } else {
                        selectedMembers.insert(user.uid)
                    }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .successGreen : .brandAccent)
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        VStack(spacing: 10) {
            // Invite button
            Button {
                Task { await inviteSelectedMembers() }
            } label: {
                Text(isInviting ? "Mengundang..." : "Undang (\(selectedMembers.count) orang)")
                    .font(AppFont.headline())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedMembers.isEmpty ? AnyShapeStyle(Color.textPrimary.opacity(0.1)) : AnyShapeStyle(LinearGradient.brandGradient))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
            }
            .disabled(selectedMembers.isEmpty || isInviting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.baseFallback)
    }

    // MARK: - Empty States
    private var emptyFriendsState: some View {
        VStack(spacing: 12) {
            Text("👥")
                .font(.system(size: 40))
            Text("Belum ada teman")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary.opacity(0.6))
            Text("Tambahkan teman terlebih dahulu\nuntuk mengundang ke trip")
                .font(AppFont.footnote())
                .foregroundColor(.textPrimary.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary.opacity(0.3))
            Text("Cari Pengguna")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)
            Text("Ketik username untuk mencari pengguna")
                .font(AppFont.subheadline())
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
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

    // MARK: - Helper Functions
    private var filteredFriends: [UserModel] {
        let allFriends = friendsVM.friends

        // Filter out current user and existing members
        let filtered = allFriends.filter { friend in
            friend.uid != authVM.currentUser?.uid &&
            !trip.members.contains(where: { $0.uid == friend.uid })
        }

        // Apply search filter if query exists
        if searchQuery.isEmpty {
            return filtered
        }

        return filtered.filter { friend in
            friend.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            friend.email.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private func getUser(by uid: String) -> UserModel? {
        if selectedTab == .friends {
            return friendsVM.friends.first(where: { $0.uid == uid })
        } else {
            return friendsVM.searchResults.first(where: { $0.uid == uid })
        }
    }

    private func inviteSelectedMembers() async {
        guard let owner = authVM.currentUser else { return }
        isInviting = true
        defer { isInviting = false }

        // Get all selected users
        var users: [UserModel] = []
        for uid in selectedMembers {
            if let user = getUser(by: uid) {
                users.append(user)
            }
        }

        // Invite each user
        for user in users {
            await tripVM.inviteMember(trip: trip, invitee: user, inviter: owner)
        }

        // Close sheet
        showInvite = false
    }
}

#Preview {
    InviteMemberSheetView(
        trip: TripModel(
            id: "preview",
            name: "Preview Trip",
            currency: "IDR",
            ownerUID: "owner123",
            adminUIDs: [],
            memberUIDs: ["owner123"],
            members: [],
            coverEmoji: "🏝️",
            status: .active,
            startDate: nil,
            endDate: nil,
            createdAt: .init(date: Date()),
            finishedAt: nil
        ),
        showInvite: .constant(true)
    )
    .environmentObject(AuthViewModel())
    .environmentObject(TripViewModel())
}
