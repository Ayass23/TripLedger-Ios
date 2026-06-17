import SwiftUI

struct AddParticipantView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var friendsVM: FriendsViewModel

    @Binding var participants: [ParticipantEntry]

    enum ParticipantSource: String, CaseIterable {
        case manual = "Manual"
        case fromFriends = "Dari Daftar Teman"
    }

    @State private var selectedSource: ParticipantSource = .manual
    @State private var manualNames: [String] = [""] // Start with one empty field
    @State private var searchQuery = ""
    @State private var selectedFriends: Set<String> = [] // UIDs
    @FocusState private var focusedField: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Description
                    Text("Pilih cara menambahkan peserta patungan")
                        .font(AppFont.subheadline())
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 16)

                    // MARK: - Segmented Control
                    segmentedControl
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // MARK: - Content
                    if selectedSource == .manual {
                        manualView
                    } else {
                        fromFriendsView
                    }
                }
            }
            .navigationTitle("Tambah Peserta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Batal")
                            .foregroundColor(.textSecondary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        confirmSelection()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(canConfirm ? .brandPrimary : .textSecondary)
                            .fontWeight(.semibold)
                    }
                    .disabled(!canConfirm)
                }
            }
            .onAppear {
                // Load friends jika belum ada
                if friendsVM.friends.isEmpty, let currentUser = authVM.currentUser {
                    Task {
                        await friendsVM.loadFriends(currentUser: currentUser)
                    }
                }

                // Auto focus to first field in manual mode
                if selectedSource == .manual {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        focusedField = 0
                    }
                }
            }
        }
    }

    // MARK: - Segmented Control
    private var segmentedControl: some View {
        HStack(spacing: 8) {
            ForEach(ParticipantSource.allCases, id: \.self) { source in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedSource = source
                    }

                    // Auto focus when switching to manual
                    if source == .manual {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            focusedField = 0
                        }
                    }
                } label: {
                    Text(source.rawValue)
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(selectedSource == source ? .white : .textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedSource == source ? Color.brandPrimary : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.cardFallback)
        .clipShape(Capsule())
    }

    // MARK: - Manual View
    private var manualView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Masukkan Nama Peserta")
                    .font(AppFont.caption())
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(manualNames.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            TextField("Nama peserta", text: $manualNames[index])
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.cardFallback)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                .focused($focusedField, equals: index)

                            if manualNames.count > 1 {
                                Button {
                                    manualNames.remove(at: index)
                                    // Adjust focus if needed
                                    if focusedField == index {
                                        focusedField = nil
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.errorRed)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Add More Button
                Button {
                    manualNames.append("")
                    // Auto focus to the new field
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedField = manualNames.count - 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Tambah Peserta Lain")
                            .fontWeight(.semibold)
                    }
                    .font(AppFont.subheadline())
                    .foregroundColor(canAddMore ? .brandPrimary : .textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canAddMore ? Color.brandPrimary.opacity(0.1) : Color.textSecondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .disabled(!canAddMore)
                .padding(.horizontal, 20)

                Spacer().frame(height: 40)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - From Friends View
    private var fromFriendsView: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)

                TextField("Cari nama teman", text: $searchQuery)
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

            // Friends List
            ScrollView {
                if filteredFriends.isEmpty {
                    emptyFriendsState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredFriends) { friend in
                            FriendSelectRow(
                                friend: friend,
                                isSelected: selectedFriends.contains(friend.uid)
                            ) {
                                toggleFriendSelection(friend)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Empty Friends State
    private var emptyFriendsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(.textSecondary.opacity(0.3))

            Text(friendsVM.friends.isEmpty ? "Belum Ada Teman" : "Tidak Ditemukan")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            Text(friendsVM.friends.isEmpty ?
                 "Tambahkan teman untuk memilih peserta" :
                 "Tidak ada teman dengan nama tersebut"
            )
                .font(AppFont.subheadline())
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Helper Properties
    private var filteredFriends: [UserModel] {
        // Filter out current user from the list
        let friendsExcludingSelf = friendsVM.friends.filter { friend in
            friend.uid != authVM.currentUser?.uid
        }

        if searchQuery.isEmpty {
            return friendsExcludingSelf
        }
        return friendsExcludingSelf.filter { friend in
            friend.displayName.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var canAddMore: Bool {
        // Can only add more if all current fields are filled
        return !manualNames.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    private var canConfirm: Bool {
        if selectedSource == .manual {
            return manualNames.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        } else {
            return !selectedFriends.isEmpty
        }
    }

    // MARK: - Actions
    private func toggleFriendSelection(_ friend: UserModel) {
        if selectedFriends.contains(friend.uid) {
            selectedFriends.remove(friend.uid)
        } else {
            selectedFriends.insert(friend.uid)
        }
    }

    private func confirmSelection() {
        if selectedSource == .manual {
            // Add manual names
            let validNames = manualNames
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for name in validNames {
                let entry = ParticipantEntry(
                    id: UUID().uuidString,
                    uid: nil,
                    name: name,
                    isSelected: true
                )
                participants.append(entry)
            }
        } else {
            // Add selected friends (skip duplicates)
            let selectedFriendModels = friendsVM.friends.filter { selectedFriends.contains($0.uid) }
            let existingUIDs = Set(participants.compactMap { $0.uid })

            for friend in selectedFriendModels {
                // Skip if already exists
                guard !existingUIDs.contains(friend.uid) else { continue }

                let entry = ParticipantEntry(
                    id: UUID().uuidString,
                    uid: friend.uid,
                    name: friend.displayName,
                    isSelected: true
                )
                participants.append(entry)
            }
        }

        dismiss()
    }
}

// MARK: - Friend Select Row
struct FriendSelectRow: View {
    let friend: UserModel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.brandPrimary : Color.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.brandPrimary)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Text(friend.displayName.prefix(1).uppercased())
                        .font(AppFont.subheadline())
                        .foregroundColor(.brandPrimary)
                        .fontWeight(.bold)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(friend.displayName)
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    Text(friend.email)
                        .font(AppFont.caption2())
                        .foregroundColor(.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? Color.brandPrimary.opacity(0.05) : Color.cardFallback)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? Color.brandPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AddParticipantView(participants: .constant([]))
        .environmentObject(AuthViewModel())
        .environmentObject(FriendsViewModel())
}
