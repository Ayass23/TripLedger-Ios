import SwiftUI
import FirebaseFirestore

struct AppealFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authVM: AuthViewModel

    let suspendReason: String
    let userUID: String
    let userName: String
    let userEmail: String

    @State private var appealReason = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        let trimmed = appealReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count >= 50
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
                                        .fill(Color.errorRed.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "exclamationmark.shield.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.errorRed)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Akun Disuspend")
                                        .font(AppFont.headline())
                                        .foregroundColor(.textPrimary)
                                    Text("Ajukan banding untuk pemulihan")
                                        .font(AppFont.caption())
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                        // Suspend Reason
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Alasan Suspend")
                                .font(AppFont.subheadline())
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)

                            Text(suspendReason)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.8))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.errorRed.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.md)
                                        .stroke(Color.errorRed.opacity(0.2), lineWidth: 1)
                                )
                        }

                        // Appeal Reason
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 4) {
                                Text("Alasan Banding")
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                                Text("*")
                                    .foregroundColor(.errorRed)
                            }

                            Text("Jelaskan apa yang sudah kamu perbaiki dan mengapa akunmu harus dipulihkan (minimal 50 karakter)")
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
                                Text("\(trimmedCount) / 50")
                                    .font(AppFont.caption2())
                                    .foregroundColor(trimmedCount >= 50 ? .successGreen : .textSecondary)

                                Spacer()
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
                                Text("Admin akan meninjau banding kamu. Proses review mungkin memakan waktu. Kamu akan mendapat notifikasi hasil review.")
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
                                    Text("Kirim Banding")
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

                        if let error = errorMessage {
                            Text(error)
                                .font(AppFont.caption())
                                .foregroundColor(.errorRed)
                                .padding(.horizontal)
                        }
                    }
                    .padding(20)
                }
                .dismissKeyboardOnTap()
            }
            .navigationTitle("Ajukan Banding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        dismiss()
                    }
                }
            }
            .alert("Banding Terkirim", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Banding kamu telah dikirim ke admin. Kamu akan mendapat notifikasi hasil review. Terima kasih atas kesabaranmu.")
            }
            .tint(.brandPrimary)
        }
    }

    private func submitAppeal() async {
        guard isValid else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let db = FirestoreService.shared.db

            // Create appeal document
            let appeal = AccountAppeal(
                userUID: userUID,
                userName: userName,
                userEmail: userEmail,
                suspendReason: suspendReason,
                appealReason: appealReason.trimmingCharacters(in: .whitespacesAndNewlines),
                status: .pending,
                createdAt: Timestamp(date: Date())
            )

            try await db.collection(Collection.appeals).addDocument(from: appeal)

            AppLog.debug("✅ [AppealForm] Appeal submitted successfully")
            showSuccessAlert = true

        } catch {
            AppLog.debug("❌ [AppealForm] Error submitting appeal: \(error)")
            errorMessage = "Gagal mengirim banding. Silakan coba lagi."
        }
    }
}
