import SwiftUI
import FirebaseFirestore

struct FriendsView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var tripVM: TripViewModel
    @StateObject private var friendsVM = FriendsViewModel()

    @State private var searchQuery = ""
    @State private var showAddFriend = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: - Header
                        headerSection

                        // MARK: - Search Bar
                        searchBar

                        // MARK: - Friends List
                        friendsListView
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .refreshable {
                    await refreshData()
                }
                .simultaneousGesture(
                    TapGesture().onEnded { _ in
                        // Dismiss keyboard when tapping anywhere
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                )

                // MARK: - Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingAddButton
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
                    .environmentObject(authVM)
                    .environmentObject(friendsVM)
            }
        }
        .onAppear {
            Task {
                await refreshData()
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("DAFTAR TEMAN")
                    .font(AppFont.title1())
                    .foregroundColor(.brandPrimary)
                Text("Kelola dan tambahkan teman untuk patungan")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 24)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)

            TextField("Cari teman berdasarkan nama atau email..", text: $searchQuery)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary)

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
    }

    // MARK: - Floating Add Button
    private var floatingAddButton: some View {
        Button {
            showAddFriend = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                Text("Tambah")
                    .font(AppFont.headline())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(LinearGradient.brandGradient)
            .clipShape(Capsule())
            .shadow(color: Color.primaryFallback.opacity(0.4), radius: 14)
        }
    }

    // MARK: - Friends List View
    private var friendsListView: some View {
        Group {
            if filteredFriends.isEmpty {
                emptyFriendsView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredFriends) { friend in
                        FriendRow(friend: friend, friendsVM: friendsVM)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - Empty States
    private var emptyFriendsView: some View {
        VStack(spacing: 16) {
            Text("👥")
                .font(.system(size: 64))

            Text("Belum Ada Teman")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            Text("Tambahkan teman untuk mulai berbagi pengeluaran")
                .font(AppFont.subheadline())
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Filtered Friends
    private var filteredFriends: [UserModel] {
        // Filter out current user and admin users (shouldn't see yourself or admins in friend list)
        let friendsExcludingSelf = friendsVM.friends.filter { friend in
            friend.uid != authVM.currentUser?.uid && friend.role != .admin
        }

        if searchQuery.isEmpty {
            return friendsExcludingSelf
        }
        return friendsExcludingSelf.filter { friend in
            friend.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            friend.email.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    // MARK: - Refresh Data
    private func refreshData() async {
        // Refresh current user data first to get updated friendUIDs
        await authVM.refreshUser()

        guard let user = authVM.currentUser else { return }
        await friendsVM.loadFriends(currentUser: user)
        await friendsVM.loadPendingRequests(currentUser: user)
    }
}

// MARK: - Friend Row Component
struct FriendRow: View {
    @EnvironmentObject private var tripVM: TripViewModel
    @EnvironmentObject private var authVM: AuthViewModel

    let friend: UserModel
    @ObservedObject var friendsVM: FriendsViewModel
    @State private var showConfirmRemove = false
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                // Avatar
                AvatarView(url: friend.avatarURL, initials: friend.initials, size: 44)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.displayName)
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    Text(friend.email)
                        .font(AppFont.caption2())
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.cardFallback)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                showConfirmRemove = true
            } label: {
                Label("Hapus Teman", systemImage: "person.fill.xmark")
            }
        }
        .alert("Hapus Teman", isPresented: $showConfirmRemove) {
            Button("Batal", role: .cancel) { }
            Button("Hapus", role: .destructive) {
                Task {
                    guard let currentUID = authVM.currentUser?.uid else { return }
                    await friendsVM.removeFriend(friendID: friend.uid, currentUID: currentUID)
                }
            }
        } message: {
            Text("Apakah kamu yakin ingin menghapus \(friend.displayName) dari daftar teman?")
        }
        .sheet(isPresented: $showDetail) {
            FriendDetailView(friend: friend)
        }
    }
}

// MARK: - Friend Request Row Component
struct FriendRequestRow: View {
    let request: FriendRequest
    @ObservedObject var friendsVM: FriendsViewModel
    @ObservedObject var authVM: AuthViewModel
    @State private var isProcessing = false
    @State private var showSuccessAlert = false
    @State private var alertMessage = ""

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(url: request.fromAvatar, initials: String(request.fromName.prefix(1).uppercased()), size: 44)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(request.fromName)
                    .font(AppFont.subheadline())
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)

                Text("Permintaan pertemanan")
                    .font(AppFont.caption2())
                    .foregroundColor(.textSecondary)

                Text(timeAgo(from: request.createdAt))
                    .font(AppFont.caption2())
                    .foregroundColor(.textSecondary.opacity(0.7))
            }

            Spacer()

            // Action Buttons
            if !isProcessing {
                HStack(spacing: 10) {
                    // Decline
                    Button {
                        isProcessing = true
                        Task {
                            guard let user = authVM.currentUser, let requestID = request.id else {
                                isProcessing = false
                                return
                            }
                            await friendsVM.declineFriendRequest(requestID: requestID, currentUser: user)

                            // Show alert if successful
                            if friendsVM.errorMessage == nil {
                                alertMessage = "Permintaan pertemanan dari \(request.fromName) telah ditolak."
                                showSuccessAlert = true
                            }

                            isProcessing = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.errorRed)
                            .frame(width: 40, height: 40)
                            .background(Color.errorRed.opacity(0.1))
                            .clipShape(Circle())
                    }

                    // Accept
                    Button {
                        isProcessing = true
                        Task {
                            guard let user = authVM.currentUser, let requestID = request.id else {
                                isProcessing = false
                                return
                            }

                            // Accept friend request
                            await friendsVM.acceptFriendRequest(requestID: requestID, currentUser: user)

                            // Refresh current user to update friendUIDs
                            await authVM.refreshUser()

                            // Reload friends if no error
                            if friendsVM.errorMessage == nil, let updatedUser = authVM.currentUser {
                                await friendsVM.loadFriends(currentUser: updatedUser)

                                // Show success alert
                                alertMessage = "Sekarang kamu dan \(request.fromName) sudah berteman! 🎉"
                                showSuccessAlert = true
                            }

                            isProcessing = false
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.successGreen)
                            .frame(width: 40, height: 40)
                            .background(Color.successGreen.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            } else {
                ProgressView()
                    .tint(.brandPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.brandPrimary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
        .alert("Permintaan Pertemanan", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .tint(.brandPrimary)
    }

    private func timeAgo(from timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if days > 0 {
            return "\(days) hari lalu"
        } else if hours > 0 {
            return "\(hours) jam lalu"
        } else if minutes > 0 {
            return "\(minutes) menit lalu"
        } else {
            return "Baru saja"
        }
    }
}

#Preview {
    FriendsView()
        .environmentObject(AuthViewModel())
}
