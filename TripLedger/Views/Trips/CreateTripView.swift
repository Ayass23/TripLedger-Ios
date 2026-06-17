import SwiftUI
import FirebaseFirestore

struct CreateTripView: View {
    @Environment(\.dismiss)          var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var tripVM: TripViewModel

    // MARK: - Step tracking
    @State private var currentStep = 1

    // MARK: - Step 1: Trip details
    @State private var name        = ""
    @State private var currency    = "IDR"
    @State private var emoji       = "🏝️"
    @State private var startDate   = Date()
    @State private var endDate     = Date().addingTimeInterval(86400 * 3) // default +3 hari

    // MARK: - Step 2: Add members
    @StateObject private var friendsVM = FriendsViewModel()
    @State private var searchQuery  = ""
    @State private var selectedMembers: [UserModel] = []
    @State private var isCreating = false
    @State private var showSuccessAlert = false

    private let emojiOptions = ["🏝️","🏔️","🌆","🚢","🎡","🌴","🗺️","✈️","🏕️","🌊"]
    private let currencies   = ["IDR","USD","EUR","SGD","MYR","JPY","AUD"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                if currentStep == 1 {
                    step1TripDetails
                        .transition(.move(edge: .leading))
                } else {
                    step2AddMembers
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: currentStep)
            .navigationTitle(currentStep == 1 ? "Trip Baru" : "Tambah Anggota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
            }
        }
        .onAppear {
            if let user = authVM.currentUser {
                Task { await friendsVM.loadFriends(currentUser: user) }
            }
        }
        .alert("Trip Berhasil Dibuat! 🎉", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Trip \"\(name)\" berhasil dibuat. Selamat berpetualang!")
        }
        .tint(.brandPrimary)
    }

    // ==========================================
    // MARK: - Step 1: Trip Details
    // ==========================================
    private var step1TripDetails: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                // Step indicator
                stepIndicator

                // Cover emoji picker
                emojiPickerSection

                // Nama Trip
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nama Trip")
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary.opacity(0.6))

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.brandPrimary.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 18))
                                .foregroundColor(.brandPrimary)
                        }

                        TextField("Contoh: Bali Squad 2026", text: $name)
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                    }
                    .padding(14)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(name.isEmpty ? Color.borderSoft : Color.brandPrimary.opacity(0.3), lineWidth: 1)
                    )
                }

                // Tanggal Liburan
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tanggal Liburan")
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary.opacity(0.6))

                    VStack(spacing: 1) {
                        // Start date row
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.successGreen.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "airplane.departure")
                                    .font(.system(size: 16))
                                    .foregroundColor(.successGreen)
                            }

                            Text("Berangkat")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)

                            Spacer()

                            DatePicker("", selection: $startDate, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                                .tint(.brandPrimary)
                                .onChange(of: startDate) { newVal in
                                    if endDate < newVal { endDate = newVal.addingTimeInterval(86400) }
                                }
                        }
                        .padding(14)
                        .background(Color.cardFallback)

                        Divider()
                            .background(Color.borderSoft)

                        // End date row
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.warningAmber.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "airplane.arrival")
                                    .font(.system(size: 16))
                                    .foregroundColor(.warningAmber)
                            }

                            Text("Pulang")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)

                            Spacer()

                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .labelsHidden()
                                .tint(.brandPrimary)
                        }
                        .padding(14)
                        .background(Color.cardFallback)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.borderSoft, lineWidth: 1)
                    )
                }

                // Mata Uang
                currencyPickerSection

                // Next button
                Button {
                    withAnimation { currentStep = 2 }
                } label: {
                    HStack {
                        Text("Lanjut: Tambah Anggota")
                            .font(AppFont.headline())
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(name.isBlank ? AnyShapeStyle(Color.textPrimary.opacity(0.1)) : AnyShapeStyle(LinearGradient.brandGradient))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                }
                .disabled(name.isBlank)
            }
            .padding(20)
        }
        .dismissKeyboardOnTap()
    }

    // ==========================================
    // MARK: - Step 2: Add Members
    // ==========================================
    private var step2AddMembers: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.textPrimary.opacity(0.35))
                TextField("Cari user berdasarkan email...", text: $searchQuery)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: searchQuery) { newValue in
                        guard let uid = authVM.currentUser?.uid else { return }
                        Task { await friendsVM.searchUsers(query: newValue, currentUID: uid) }
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
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Selected members chips
            if !selectedMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedMembers) { user in
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
                                    selectedMembers.removeAll { $0.uid == user.uid }
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
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
            }

            // Results / Friends list
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Search results
                    if !searchQuery.isBlank && !friendsVM.searchResults.isEmpty {
                        sectionLabel("Hasil Pencarian")
                        ForEach(friendsVM.searchResults) { user in
                            userRow(user)
                        }
                    }

                    // Friends list
                    if !friendsVM.friends.isEmpty {
                        sectionLabel("Daftar Teman")
                        ForEach(friendsVM.friends) { friend in
                            userRow(friend)
                        }
                    }

                    // Empty state
                    if friendsVM.friends.isEmpty && friendsVM.searchResults.isEmpty && searchQuery.isBlank {
                        VStack(spacing: 12) {
                            Text("👥")
                                .font(.system(size: 40))
                            Text("Belum ada teman")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Text("Cari user berdasarkan email\nuntuk menambahkan anggota")
                                .font(AppFont.footnote())
                                .foregroundColor(.textPrimary.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    if friendsVM.isLoading {
                        ProgressView()
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.immediately)
            .padding(.top, 12)

            // Bottom buttons
            VStack(spacing: 10) {
                // Create button
                Button {
                    Task { await createTrip() }
                } label: {
                    Text(isCreating ? "Membuat..." : "Buat Trip (\(selectedMembers.count) anggota)")
                        .font(AppFont.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient.brandGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                }
                .disabled(isCreating)

                // Back button
                Button {
                    withAnimation { currentStep = 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Kembali")
                            .font(AppFont.subheadline())
                    }
                    .foregroundColor(.textPrimary.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.baseFallback)
        }
        .onTapGesture {
            // Dismiss keyboard when tapping anywhere
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // ==========================================
    // MARK: - Subviews
    // ==========================================

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...2, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= currentStep ? Color.brandPrimary : Color.textPrimary.opacity(0.1))
                    .frame(height: 4)
            }
        }
        .padding(.vertical, 8)
    }

    private var emojiPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cover Trip")
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(emojiOptions, id: \.self) { e in
                        Text(e)
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .background(emoji == e ? Color.brandPrimary.opacity(0.15) : Color.cardFallback)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(emoji == e ? Color.brandPrimary.opacity(0.5) : Color.borderSoft, lineWidth: emoji == e ? 2 : 1)
                            )
                            .shadow(color: emoji == e ? Color.brandPrimary.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    emoji = e
                                }
                            }
                    }
                }
            }
        }
    }

    private var currencyPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mata Uang")
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(currencies, id: \.self) { c in
                        currencyButton(for: c)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func currencyButton(for c: String) -> some View {
        let isSelected = currency == c

        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            Text(c)
                .font(AppFont.subheadline())
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .foregroundColor(isSelected ? .white : .textPrimary.opacity(0.6))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(isSelected ? AnyShapeStyle(LinearGradient.brandGradient) : AnyShapeStyle(Color.cardFallback))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.full)
                .stroke(isSelected ? Color.clear : Color.borderSoft, lineWidth: 1)
        )
        .shadow(color: isSelected ? Color.brandPrimary.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                currency = c
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.caption())
            .foregroundColor(.textPrimary.opacity(0.4))
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func userRow(_ user: UserModel) -> some View {
        let isSelected = selectedMembers.contains(where: { $0.uid == user.uid })
        let isOwner = user.uid == authVM.currentUser?.uid

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

            if isOwner {
                Text("Kamu")
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.4))
            } else {
                Button {
                    if isSelected {
                        selectedMembers.removeAll { $0.uid == user.uid }
                    } else {
                        selectedMembers.append(user)
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

    // ==========================================
    // MARK: - Create Trip
    // ==========================================
    private func createTrip() async {
        guard let owner = authVM.currentUser else { return }
        isCreating = true
        defer { isCreating = false }

        // Create the trip with only the owner
        guard let trip = await tripVM.createTrip(
            name: name,
            currency: currency,
            emoji: emoji,
            startDate: startDate,
            endDate: endDate,
            owner: owner
        ) else { return }

        // Invite selected members
        for member in selectedMembers {
            await tripVM.inviteMember(trip: trip, invitee: member, inviter: owner)
        }

        showSuccessAlert = true
    }
}

#Preview {
    CreateTripView()
        .environmentObject(AuthViewModel())
        .environmentObject(TripViewModel())
}
