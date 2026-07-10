import SwiftUI
import FirebaseFirestore

struct InviteMemberSheetView: View {
    let trip: TripModel
    @Binding var showInvite: Bool

    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var tripVM: TripViewModel
    @StateObject private var friendsVM = FriendsViewModel()

    @State private var searchQuery = ""
    @State private var selectedMembers: Set<String> = []
    @State private var isInviting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with subtitle
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Search bar
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Selected members chips
                if !selectedMembers.isEmpty {
                    selectedMembersChips
                }

                // Friends list
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        friendsList
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
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

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daftar Teman")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            Text("Kamu hanya bisa mengundang orang yang sudah menjadi temanmu")
                .font(AppFont.caption())
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.textPrimary.opacity(0.35))
            TextField("Cari nama teman...", text: $searchQuery)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary)
                .autocapitalization(.none)
                .autocorrectionDisabled()
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

    // MARK: - Selected Members Chips
    private var selectedMembersChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedMembers), id: \.self) { uid in
                    if let user = friendsVM.friends.first(where: { $0.uid == uid }) {
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
            if friendsVM.friends.isEmpty {
                emptyFriendsState
            } else if filteredFriends.isEmpty && !searchQuery.isEmpty {
                noResultsState
            } else {
                ForEach(filteredFriends) { friend in
                    userRow(friend)
                }
            }
        }
    }

    // MARK: - User Row
    private func userRow(_ user: UserModel) -> some View {
        let isSelected = selectedMembers.contains(user.uid)
        let isCurrentUser = user.uid == authVM.currentUser?.uid
        let isMember = trip.members.contains(where: { $0.uid == user.uid })
        let isPending = trip.members.contains(where: { $0.uid == user.uid && $0.role == .pending })
        let isSuspended = user.isSuspended

        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(url: user.avatarURL, initials: user.initials, size: 40)
                    .opacity(isSuspended ? 0.5 : 1.0)

                if isSuspended {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.errorRed)
                        .background(Circle().fill(Color.baseFallback).frame(width: 16, height: 16))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(AppFont.subheadline())
                        .foregroundColor(isSuspended ? .textPrimary.opacity(0.5) : .textPrimary)

                    if isSuspended {
                        Text("Ditangguhkan")
                            .font(AppFont.caption2())
                            .foregroundColor(.errorRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.errorRed.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(user.email)
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.4))
            }

            Spacer()

            if isCurrentUser {
                Text("Kamu")
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.4))
            } else if isSuspended {
                Image(systemName: "nosign")
                    .font(.system(size: 20))
                    .foregroundColor(.errorRed.opacity(0.5))
            } else if isMember && !isPending {
                Text("Sudah Anggota")
                    .font(AppFont.caption2())
                    .foregroundColor(.successGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.successGreen.opacity(0.15))
                    .clipShape(Capsule())
            } else if isPending {
                Text("Menunggu")
                    .font(AppFont.caption2())
                    .foregroundColor(.warningAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.warningAmber.opacity(0.15))
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

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Text("🔍")
                .font(.system(size: 40))
            Text("Tidak Ditemukan")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary.opacity(0.6))
            Text("Tidak ada teman dengan nama tersebut")
                .font(AppFont.footnote())
                .foregroundColor(.textPrimary.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helper Functions
    private var filteredFriends: [UserModel] {
        let allFriends = friendsVM.friends

        // Filter out current user and admin users, but KEEP existing members (to show "Sudah Anggota")
        let filtered = allFriends.filter { friend in
            friend.uid != authVM.currentUser?.uid && friend.role != .admin
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

    private func inviteSelectedMembers() async {
        guard let owner = authVM.currentUser else { return }
        isInviting = true
        defer { isInviting = false }

        // Get all selected users from friends list
        let users = friendsVM.friends.filter { selectedMembers.contains($0.uid) }

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
