import SwiftUI

// MARK: - Appeal Detail Sheet
struct AppealDetailSheet: View {
    let appeal: AccountAppeal
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @Environment(\.dismiss) private var dismiss

    @State private var adminNotes = ""
    @State private var showApproveAlert = false
    @State private var showRejectAlert = false
    @State private var showSuccessAlert = false
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // User Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pengguna")
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandPrimary.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "person.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.brandPrimary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appeal.userName)
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)

                                Text(appeal.userEmail)
                                    .font(AppFont.caption())
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    // Original Suspend Reason
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alasan Suspend (Original)")
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        Text(appeal.suspendReason)
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Appeal Reason
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alasan Banding dari User")
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        Text(appeal.appealReason)
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Admin Notes
                    if appeal.status == .pending {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Catatan Admin (Opsional)")
                                .font(AppFont.caption())
                                .foregroundColor(.textSecondary)

                            TextEditor(text: $adminNotes)
                                .frame(height: 100)
                                .scrollContentBackground(.hidden)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                                .padding(12)
                                .background(Color.cardFallback)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.md)
                                        .stroke(Color.borderSoft, lineWidth: 1)
                                )
                        }

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button {
                                showApproveAlert = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Setujui & Pulihkan Akun")
                                        .font(AppFont.subheadline())
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.successGreen)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }

                            Button {
                                showRejectAlert = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Tolak Banding")
                                        .font(AppFont.subheadline())
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.textSecondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }
                        }
                    } else if let notes = appeal.adminNotes {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Catatan Admin")
                                .font(AppFont.caption())
                                .foregroundColor(.textSecondary)

                            Text(notes)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                        }
                    }
                }
                .padding(20)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .background(Color.baseFallback)
            .navigationTitle("Detail Banding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            .alert("Setujui Banding", isPresented: $showApproveAlert) {
                Button("Batal", role: .cancel) { }
                Button("Setujui") {
                    Task {
                        await adminVM.approveAppeal(
                            appealID: appeal.id ?? "",
                            adminUID: currentAdminUID,
                            adminNotes: adminNotes.isEmpty ? nil : adminNotes
                        )
                        successMessage = "Banding disetujui. Akun \(appeal.userName) telah dipulihkan."
                        showSuccessAlert = true
                    }
                }
            } message: {
                Text("Akun \(appeal.userName) akan dipulihkan dan bisa login kembali.")
            }
            .alert("Tolak Banding", isPresented: $showRejectAlert) {
                Button("Batal", role: .cancel) { }
                Button("Tolak", role: .destructive) {
                    Task {
                        await adminVM.rejectAppeal(
                            appealID: appeal.id ?? "",
                            adminUID: currentAdminUID,
                            adminNotes: adminNotes.isEmpty ? nil : adminNotes
                        )
                        successMessage = "Banding ditolak. User tetap tersuspend."
                        showSuccessAlert = true
                    }
                }
            } message: {
                Text("Banding akan ditolak dan akun tetap tersuspend.")
            }
            .alert("Berhasil", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .tint(.brandPrimary)
        }
    }
}
