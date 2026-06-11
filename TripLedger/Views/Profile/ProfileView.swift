import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authVM:   AuthViewModel
    @StateObject private var profileVM = ProfileViewModel()

    @State private var showEditName  = false
    @State private var showEditBank  = false
    @State private var showPhotoSourcePicker = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var showImageCropper = false
    @State private var selectedImage: UIImage?
    @State private var croppedImage: UIImage?

    var body: some View {
        ZStack {
            // Background gradient
            Color.baseFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header / Avatar
                    headerSection
                        .padding(.top, 20)

                    // Info cards
                    VStack(spacing: 12) {
                        infoCard
                        bankCard
                        dangerZone
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .fullScreenCover(isPresented: $showEditName) {
            NavigationStack {
                EditNameView(profileVM: profileVM)
                    .environmentObject(authVM)
            }
        }
        .fullScreenCover(isPresented: $showEditBank) {
            NavigationStack {
                EditBankView(profileVM: profileVM)
                    .environmentObject(authVM)
            }
        }
        // Photo Source Picker Sheet
        .sheet(isPresented: $showPhotoSourcePicker) {
            PhotoSourcePickerView(
                onSelectCamera: {
                    showCamera = true
                },
                onSelectGallery: {
                    showGallery = true
                }
            )
        }
        // Camera Full Page
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
                .ignoresSafeArea()
                .onDisappear {
                    if selectedImage != nil {
                        showImageCropper = true
                    }
                }
        }
        // Gallery Sheet
        .sheet(isPresented: $showGallery) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
                .onDisappear {
                    if selectedImage != nil {
                        showImageCropper = true
                    }
                }
        }
        // Image Cropper Full Page
        .fullScreenCover(isPresented: $showImageCropper) {
            if let image = selectedImage {
                CircleImageCropperView(image: image) { croppedImg in
                    croppedImage = croppedImg
                    Task {
                        if let uid = authVM.currentUser?.uid {
                            await profileVM.uploadAvatar(croppedImg, uid: uid)

                            // Refresh current user data
                            await authVM.refreshUser()

                            // Clear URL cache untuk force reload gambar baru
                            URLCache.shared.removeAllCachedResponses()

                            print("🔄 [ProfileView] User refreshed - New avatar URL: \(authVM.currentUser?.avatarURL ?? "nil")")
                        }
                    }
                }
            } else {
                // Fallback jika image nil (shouldn't happen)
                Color.red
                    .ignoresSafeArea()
                    .overlay(
                        VStack {
                            Text("Error: No Image")
                                .foregroundColor(.white)
                            Button("Close") {
                                showImageCropper = false
                            }
                            .foregroundColor(.white)
                            .padding()
                        }
                    )
            }
        }
        // Debug: onChange untuk track selectedImage
        .onChange(of: selectedImage) { newValue in
            print("📸 [ProfileView] selectedImage changed: \(newValue != nil)")
            if newValue != nil {
                print("   Image size: \(newValue!.size)")
            }
        }
        .onChange(of: showImageCropper) { newValue in
            print("✂️ [ProfileView] showImageCropper: \(newValue)")
        }
        // Alert for errors
        .alert("Error", isPresented: .constant(profileVM.errorMessage != nil)) {
            Button("OK") {
                profileVM.errorMessage = nil
            }
        } message: {
            if let error = profileVM.errorMessage {
                Text(error)
            }
        }
        // Alert for success
        .alert("Berhasil!", isPresented: .constant(profileVM.successMessage != nil)) {
            Button("OK") {
                profileVM.successMessage = nil
            }
        } message: {
            if let success = profileVM.successMessage {
                Text(success)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Avatar Button
            Button { showPhotoSourcePicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar with border
                    ZStack {
                        AvatarView(
                            url: authVM.currentUser?.avatarURL,
                            initials: authVM.currentUser?.initials ?? "?",
                            size: 80
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.brandPrimary.opacity(0.3), Color.brandAccent.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.5
                                )
                        )
                    }

                    // Camera icon with gradient
                    ZStack {
                        Circle()
                            .fill(Color.baseFallback)
                            .frame(width: 30, height: 30)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brandPrimary, Color.brandAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 28, height: 28)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Color.brandPrimary.opacity(0.3), radius: 4, y: 2)
                    .offset(x: 2, y: 2)
                }
            }
            .padding(.top, 40)

            // Name & Email
            VStack(spacing: 6) {
                Text(authVM.currentUser?.displayName ?? "—")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)

                    Text(authVM.currentUser?.email ?? "")
                        .font(AppFont.caption())
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Info Card
    private var infoCard: some View {
        VStack(spacing: 0) {
            // Header with Edit Button
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Informasi Pribadi")
                    .font(AppFont.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Edit Button
                Button {
                    showEditName = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Edit")
                            .font(AppFont.caption())
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.brandPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.brandPrimary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.brandPrimary.opacity(0.03))

            Divider().background(Color.textPrimary.opacity(0.06))

            // Content (non-clickable)
            staticProfileRow(
                icon: "person.fill",
                iconColor: Color.brandPrimary,
                label: "Nama Lengkap",
                value: authVM.currentUser?.displayName ?? "—"
            )
        }
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Bank Card
    private var bankCard: some View {
        VStack(spacing: 0) {
            // Header with Edit Button
            HStack(spacing: 8) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Informasi Rekening")
                    .font(AppFont.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Edit Button
                Button {
                    showEditBank = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Edit")
                            .font(AppFont.caption())
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color(hex: "#10B981"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#10B981").opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#10B981").opacity(0.05))

            Divider().background(Color.textPrimary.opacity(0.06))

            // Content (non-clickable)
            let bank = authVM.currentUser?.bankInfo
            staticProfileRow(
                icon: "building.columns.fill",
                iconColor: Color(hex: "#10B981"),
                label: "Nama Bank",
                value: bank?.bankName ?? "Belum diisi"
            )

            Divider().background(Color.textPrimary.opacity(0.06))
                .padding(.leading, 56)

            staticProfileRow(
                icon: "creditcard.fill",
                iconColor: Color(hex: "#10B981"),
                label: "Nomor Rekening",
                value: bank?.accountNumber ?? "—"
            )

            Divider().background(Color.textPrimary.opacity(0.06))
                .padding(.leading, 56)

            staticProfileRow(
                icon: "person.text.rectangle.fill",
                iconColor: Color(hex: "#10B981"),
                label: "Nama Pemilik",
                value: bank?.accountName ?? "—"
            )
        }
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - Danger Zone
    private var dangerZone: some View {
        Button {
            authVM.logout()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.errorRed.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.errorRed)
                }

                Text("Keluar dari Akun")
                    .font(AppFont.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(.errorRed)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.errorRed.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardFallback)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.errorRed.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: Color.errorRed.opacity(0.1), radius: 8, y: 2)
        }
        .padding(.top, 12)
    }

    // MARK: - Static Profile Row (non-clickable)
    private func staticProfileRow(
        icon: String,
        iconColor: Color,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 14) {
            // Icon container
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }

            // Label & Value
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AppFont.caption())
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)

                Text(value)
                    .font(AppFont.subheadline())
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

}

#Preview {
    ProfileView().environmentObject(AuthViewModel())
}
