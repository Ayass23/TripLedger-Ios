import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PublicAppealFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var appealReason = ""
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private var isValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReason = appealReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedEmail.isEmpty &&
               trimmedEmail.contains("@") &&
               !trimmedReason.isEmpty &&
               trimmedReason.count >= 10
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Info
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.brandPrimary.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "arrow.uturn.left.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.brandPrimary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Ajukan Pemulihan Akun")
                                        .font(AppFont.headline())
                                        .foregroundColor(.textPrimary)
                                    Text("Kirim pengajuan untuk memulihkan akun yang tersuspend")
                                        .font(AppFont.caption())
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                        // Email Field
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 4) {
                                Text("Email Akun yang Disuspend")
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                                Text("*")
                                    .foregroundColor(.errorRed)
                            }

                            TextField("contoh@email.com", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                                .padding(14)
                                .background(Color.cardFallback)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.md)
                                        .stroke(
                                            email.isEmpty ? Color.errorRed.opacity(0.3) : Color.borderSoft,
                                            lineWidth: 1
                                        )
                                )
                        }

                        // Appeal Reason
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 4) {
                                Text("Alasan Pengajuan")
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                                Text("*")
                                    .foregroundColor(.errorRed)
                            }

                            Text("Jelaskan mengapa akun kamu berhak untuk dipulihkan (minimal 10 karakter)")
                                .font(AppFont.caption())
                                .foregroundColor(.textSecondary)

                            TextEditor(text: $appealReason)
                                .frame(height: 150)
                                .scrollContentBackground(.hidden)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                                .padding(12)
                                .background(Color.cardFallback)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.md)
                                        .stroke(
                                            appealReason.isEmpty ? Color.errorRed.opacity(0.3) : Color.borderSoft,
                                            lineWidth: 1
                                        )
                                )

                            HStack {
                                let trimmedCount = appealReason.trimmingCharacters(in: .whitespacesAndNewlines).count
                                Text("\(trimmedCount) / 10 karakter")
                                    .font(AppFont.caption2())
                                    .foregroundColor(trimmedCount >= 10 ? .successGreen : .errorRed)

                                Spacer()

                                if trimmedCount < 10 && trimmedCount > 0 {
                                    Text("Kurang \(10 - trimmedCount) karakter lagi")
                                        .font(AppFont.caption2())
                                        .foregroundColor(.errorRed)
                                }
                            }
                        }

                        // Info
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.brandPrimary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Catatan Penting")
                                    .font(AppFont.caption())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                                Text("Admin akan meninjau pengajuan kamu. Proses review mungkin memakan waktu. Pastikan email yang dimasukkan benar dan akun tersebut memang tersuspend.")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(Color.brandPrimary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                        // Submit Button
                        Button {
                            Task { await submitAppeal() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 16))
                                    Text("Kirim Pengajuan")
                                        .font(AppFont.headline())
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid && !isSubmitting ? LinearGradient.brandGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                        }
                        .disabled(!isValid || isSubmitting)

                        // Validation hint when button is disabled
                        if !isValid && !isSubmitting {
                            VStack(alignment: .leading, spacing: 4) {
                                let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                                let trimmedReason = appealReason.trimmingCharacters(in: .whitespacesAndNewlines)

                                if trimmedEmail.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text("Email akun yang disuspend harus diisi")
                                            .font(AppFont.caption2())
                                    }
                                    .foregroundColor(.errorRed)
                                } else if !trimmedEmail.contains("@") {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text("Format email tidak valid")
                                            .font(AppFont.caption2())
                                    }
                                    .foregroundColor(.errorRed)
                                }

                                if trimmedReason.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text("Alasan pengajuan harus diisi")
                                            .font(AppFont.caption2())
                                    }
                                    .foregroundColor(.errorRed)
                                } else if trimmedReason.count < 10 {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text("Alasan pengajuan minimal 10 karakter")
                                            .font(AppFont.caption2())
                                    }
                                    .foregroundColor(.errorRed)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                }
                .dismissKeyboardOnTap()
            }
            .navigationTitle("Pemulihan Akun")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if alertTitle == "Berhasil Terkirim" {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .tint(.brandPrimary)
        }
    }

    private func submitAppeal() async {
        guard isValid else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        // Sign in anonymously to access Firestore (for suspended/unauthenticated users)
        var signedInAnonymously = false
        do {
            if Auth.auth().currentUser == nil {
                try await Auth.auth().signInAnonymously()
                signedInAnonymously = true
                AppLog.debug("✅ [PublicAppeal] Signed in anonymously for Firestore access")
            }
        } catch {
            AppLog.debug("❌ [PublicAppeal] Anonymous sign-in failed: \(error)")
            alertTitle = "Gagal Mengirim"
            alertMessage = "Tidak dapat terhubung ke server. Periksa koneksi internet dan coba lagi."
            showAlert = true
            return
        }

        // Ensure we sign out anonymous user when done
        defer {
            if signedInAnonymously {
                try? Auth.auth().signOut()
                AppLog.debug("✅ [PublicAppeal] Signed out anonymous user")
            }
        }

        do {
            let db = FirestoreService.shared.db
            let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // 1. Check if email exists
            let users: [UserModel] = try await FirestoreService.shared.fetchList(collection: Collection.users) { ref in
                ref.whereField("email", isEqualTo: trimmedEmail)
                    .limit(to: 1)
            }

            guard let user = users.first else {
                alertTitle = "Akun Tidak Terdaftar"
                alertMessage = "Email yang kamu masukkan tidak terdaftar di sistem. Pastikan email sudah benar."
                showAlert = true
                return
            }

            // 2. Check if user is suspended
            guard user.isSuspended else {
                alertTitle = "Akun Tidak Tersuspend"
                alertMessage = "Akun dengan email tersebut tidak dalam status suspend. Pengajuan pemulihan hanya untuk akun yang tersuspend."
                showAlert = true
                return
            }

            // 3. Check if there's already a pending appeal for this user
            let existingAppeals: [AccountAppeal] = try await FirestoreService.shared.fetchList(collection: Collection.appeals) { ref in
                ref.whereField("userUID", isEqualTo: user.uid)
                    .whereField("status", isEqualTo: AppealStatus.pending.rawValue)
                    .limit(to: 1)
            }

            if !existingAppeals.isEmpty {
                alertTitle = "Pengajuan Sudah Ada"
                alertMessage = "Kamu sudah memiliki pengajuan pemulihan yang sedang menunggu review admin. Mohon tunggu hasil review."
                showAlert = true
                return
            }

            // 4. Create appeal document
            let appeal = AccountAppeal(
                userUID: user.uid,
                userName: user.displayName,
                userEmail: user.email,
                suspendReason: user.suspendReason ?? "Tidak ada alasan yang tercatat",
                appealReason: appealReason.trimmingCharacters(in: .whitespacesAndNewlines),
                status: .pending,
                createdAt: Timestamp(date: Date())
            )

            try await db.collection(Collection.appeals).addDocument(from: appeal)

            AppLog.debug("✅ [PublicAppeal] Appeal submitted successfully")

            alertTitle = "Berhasil Terkirim"
            alertMessage = "Pengajuan pemulihan akun telah dikirim ke admin. Silakan tunggu hasil review dari admin. Kamu akan mendapat pemberitahuan melalui email."
            showAlert = true

        } catch {
            AppLog.debug("❌ [PublicAppeal] Error submitting appeal: \(error)")
            let errorDesc = error.localizedDescription.lowercased()

            // Handle permission errors - likely means email not found or rules issue
            if errorDesc.contains("permission") || errorDesc.contains("denied") {
                alertTitle = "Akun Tidak Ditemukan"
                alertMessage = "Email yang kamu masukkan tidak terdaftar di sistem atau sedang ada gangguan. Pastikan email sudah benar dan coba lagi."
            } else if errorDesc.contains("network") || errorDesc.contains("internet") {
                alertTitle = "Koneksi Bermasalah"
                alertMessage = "Tidak dapat terhubung ke server. Periksa koneksi internet kamu dan coba lagi."
            } else {
                alertTitle = "Gagal Mengirim"
                alertMessage = "Terjadi kesalahan saat mengirim pengajuan. Silakan coba lagi nanti."
            }
            showAlert = true
        }
    }
}
