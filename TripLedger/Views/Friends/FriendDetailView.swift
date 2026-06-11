import SwiftUI
import FirebaseFirestore

struct FriendDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var tripVM: TripViewModel
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var friendsVM: FriendsViewModel

    let friend: UserModel

    @State private var showDeleteAlert = false

    // Computed property untuk trip bersama
    private var sharedTrips: [TripModel] {
        guard let currentUID = authVM.currentUser?.uid else { return [] }

        // Gabungkan active dan history trips
        let allTrips = tripVM.activeTrips + tripVM.historyTrips

        // Filter trips yang ada current user DAN friend ini sebagai member
        return allTrips.filter { trip in
            let hasCurrentUser = trip.memberUIDs.contains(currentUID)
            let hasFriend = trip.memberUIDs.contains(friend.uid)
            return hasCurrentUser && hasFriend
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Avatar & Name
                        VStack(spacing: 16) {
                            AvatarView(url: friend.avatarURL, initials: friend.initials, size: 100)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.brandPrimary.opacity(0.3), Color.brandAccent.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 3
                                        )
                                )
                                .shadow(color: Color.brandPrimary.opacity(0.2), radius: 10, y: 5)

                            VStack(spacing: 6) {
                                Text(friend.displayName)
                                    .font(AppFont.title2())
                                    .fontWeight(.bold)
                                    .foregroundColor(.textPrimary)

                                Text(friend.email)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(.top, 20)

                        // MARK: - Trip Bersama
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Trip Bersama")
                                    .font(AppFont.headline())
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                Text("\(sharedTrips.count)")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.textSecondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }

                            if sharedTrips.isEmpty {
                                // Empty State
                                VStack(spacing: 12) {
                                    Image(systemName: "airplane.departure")
                                        .font(.system(size: 32))
                                        .foregroundColor(.textSecondary.opacity(0.3))

                                    Text("Belum ada trip bersama")
                                        .font(AppFont.subheadline())
                                        .foregroundColor(.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                // Trip List
                                VStack(spacing: 8) {
                                    ForEach(sharedTrips) { trip in
                                        TripRowCard(trip: trip)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationTitle("Detail Teman")
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

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.errorRed)
                    }
                }
            }
            .alert("Hapus Teman", isPresented: $showDeleteAlert) {
                Button("Batal", role: .cancel) { }
                Button("Hapus", role: .destructive) {
                    Task {
                        guard let currentUID = authVM.currentUser?.uid else { return }
                        await friendsVM.removeFriend(friendID: friend.uid, currentUID: currentUID)
                        if friendsVM.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Apakah kamu yakin ingin menghapus \(friend.displayName) dari daftar teman? Kalian tidak akan bisa melihat trip bersama lagi.")
            }
        }
    }
}

// MARK: - Trip Row Card
struct TripRowCard: View {
    let trip: TripModel

    var body: some View {
        HStack(spacing: 12) {
            // Emoji
            Text(trip.coverEmoji)
                .font(.system(size: 32))
                .frame(width: 50, height: 50)
                .background(Color.brandPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(AppFont.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)

                    Text("\(trip.memberUIDs.count) anggota")
                        .font(AppFont.caption2())
                        .foregroundColor(.textSecondary)

                    Text("•")
                        .foregroundColor(.textSecondary)

                    Text(trip.status.rawValue.capitalized)
                        .font(AppFont.caption2())
                        .foregroundColor(trip.status == .active ? .successGreen : .textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary.opacity(0.5))
        }
        .padding(12)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

// MARK: - Info Card Component
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.brandPrimary)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.caption())
                    .foregroundColor(.textSecondary)

                Text(value)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

#Preview {
    FriendDetailView(
        friend: UserModel(
            uid: "123",
            displayName: "John Doe",
            email: "john@example.com",
            avatarURL: nil,
            avatarPublicID: nil,
            bankInfo: nil,
            role: .user,
            isSuspended: false,
            fcmToken: nil,
            createdAt: Timestamp(date: Date()),
            friendUIDs: []
        )
    )
    .environmentObject(TripViewModel())
    .environmentObject(AuthViewModel())
}
