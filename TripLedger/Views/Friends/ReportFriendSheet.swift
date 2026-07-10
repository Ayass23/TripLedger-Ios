import SwiftUI
import FirebaseFirestore

struct ReportFriendSheet: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Binding var isPresented: Bool
    let friend: UserModel
    let onSuccess: () -> Void

    @State private var selectedCategory: ReportCategory = .spam
    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false

    private var isValid: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Melaporkan Pengguna")
                                .font(AppFont.title3())
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)

                            HStack(spacing: 12) {
                                AvatarView(url: friend.avatarURL, initials: friend.initials, size: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(AppFont.subheadline())
                                        .fontWeight(.semibold)
                                        .foregroundColor(.textPrimary)

                                    Text(friend.email)
                                        .font(AppFont.caption())
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .padding(12)
                            .background(Color.cardFallback)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        }

                        // Kategori Laporan
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Kategori Laporan")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))

                            VStack(spacing: 10) {
                                ForEach(ReportCategory.allCases, id: \.self) { category in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedCategory = category
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedCategory == category ? Color.errorRed.opacity(0.15) : Color.textPrimary.opacity(0.08))
                                                    .frame(width: 36, height: 36)

                                                Image(systemName: category.icon)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(selectedCategory == category ? .errorRed : .textPrimary.opacity(0.5))
                                            }

                                            Text(category.displayName)
                                                .font(AppFont.subheadline())
                                                .foregroundColor(.textPrimary)

                                            Spacer()

                                            Image(systemName: selectedCategory == category ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 22))
                                                .foregroundColor(selectedCategory == category ? .errorRed : .textPrimary.opacity(0.2))
                                        }
                                        .padding(14)
                                        .background(Color.cardFallback)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppRadius.md)
                                                .stroke(selectedCategory == category ? Color.errorRed.opacity(0.3) : Color.borderSoft, lineWidth: selectedCategory == category ? 2 : 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Alasan
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Alasan Laporan")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))

                            VStack(alignment: .leading, spacing: 8) {
                                TextEditor(text: $reason)
                                    .frame(height: 120)
                                    .scrollContentBackground(.hidden)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                                    .padding(12)
                                    .background(Color.cardFallback)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.md)
                                            .stroke(reason.isEmpty ? Color.borderSoft : Color.errorRed.opacity(0.3), lineWidth: 1)
                                    )

                                Text("Jelaskan alasan kamu melaporkan pengguna ini. Informasi ini akan membantu tim kami meninjau laporan dengan lebih baik.")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textPrimary.opacity(0.5))
                            }
                        }

                        // Warning
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.warningAmber)

                            Text("Laporan palsu atau penyalahgunaan fitur ini dapat mengakibatkan akun kamu dikenai sanksi.")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }
                        .padding(12)
                        .background(Color.warningAmber.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    }
                    .padding(20)
                }
                .dismissKeyboardOnTap()
            }
            .navigationTitle("Laporkan Pengguna")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        isPresented = false
                    }
                    .foregroundColor(.textPrimary.opacity(0.7))
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await submitReport() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .tint(.errorRed)
                        } else {
                            Text("Kirim")
                                .fontWeight(.semibold)
                                .foregroundColor(isValid ? .errorRed : .textPrimary.opacity(0.3))
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
            .alert("Laporan Terkirim", isPresented: $showSuccessAlert) {
                Button("OK") {
                    isPresented = false
                    onSuccess()
                }
            } message: {
                Text("Laporan kamu telah dikirim ke admin untuk ditinjau. Kamu akan mendapat notifikasi saat laporan selesai ditinjau.")
            }
        }
    }

    // MARK: - Submit Report
    private func submitReport() async {
        guard let currentUser = authVM.currentUser else { return }
        guard isValid else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let db = FirestoreService.shared
        let docRef = db.newDocRef(collection: Collection.reports)

        let report = ReportModel(
            reporterUID: currentUser.uid,
            reporterName: currentUser.displayName,
            reportedUID: friend.uid,
            reportedName: friend.displayName,
            reportedEmail: friend.email,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory,
            status: .pending,
            createdAt: Timestamp(date: Date()),
            resolvedAt: nil,
            resolvedBy: nil,
            adminNotes: nil
        )

        do {
            try db.db.collection(Collection.reports).document(docRef.documentID).setData(from: report)
            AppLog.debug("✅ [ReportFriend] Report submitted for \(friend.displayName)")

            showSuccessAlert = true
        } catch {
            AppLog.debug("❌ [ReportFriend] Error submitting report: \(error)")
        }
    }
}
