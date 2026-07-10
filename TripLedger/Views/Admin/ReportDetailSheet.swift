import SwiftUI
import FirebaseFirestore

// MARK: - Report Detail Sheet
struct ReportDetailSheet: View {
    let report: ReportModel
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @Environment(\.dismiss) private var dismiss

    @State private var adminNotes = ""
    @State private var showSuspendAlert = false
    @State private var showDismissAlert = false
    @State private var showSuccessAlert = false
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Reporter Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pelapor")
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
                                Text(report.reporterName)
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    // Reported User Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Yang Dilaporkan")
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.errorRed.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: "person.fill.xmark")
                                    .font(.system(size: 18))
                                    .foregroundColor(.errorRed)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(report.reportedName)
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)

                                Text(report.reportedEmail)
                                    .font(AppFont.caption())
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    // Category & Reason
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Kategori")
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        Text(report.category.displayName)
                            .font(AppFont.subheadline())
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alasan Laporan")
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        Text(report.reason)
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Status & Resolution Info (for resolved/dismissed reports)
                    if report.status != .pending {
                        VStack(alignment: .leading, spacing: 16) {
                            // Status Badge
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(statusColor(for: report.status).opacity(0.15))
                                        .frame(width: 40, height: 40)

                                    Image(systemName: statusIcon(for: report.status))
                                        .font(.system(size: 18))
                                        .foregroundColor(statusColor(for: report.status))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Status Laporan")
                                        .font(AppFont.caption())
                                        .foregroundColor(.textSecondary)

                                    Text(report.status.displayName)
                                        .font(AppFont.subheadline())
                                        .fontWeight(.bold)
                                        .foregroundColor(statusColor(for: report.status))
                                }
                            }
                            .padding(14)
                            .background(statusColor(for: report.status).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                            // Resolved Info
                            if let resolvedAt = report.resolvedAt {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Ditangani Pada")
                                        .font(AppFont.caption())
                                        .foregroundColor(.textSecondary)

                                    Text(formatDate(resolvedAt.dateValue()))
                                        .font(AppFont.subheadline())
                                        .foregroundColor(.textPrimary)
                                }
                            }

                            // Admin Notes
                            if let notes = report.adminNotes {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Catatan dari Admin")
                                        .font(AppFont.caption())
                                        .foregroundColor(.textSecondary)

                                    Text(notes)
                                        .font(AppFont.subheadline())
                                        .foregroundColor(.textPrimary)
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.cardFallback)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: AppRadius.md)
                                                .stroke(Color.borderSoft, lineWidth: 1)
                                        )
                                }
                            }

                            // Action Taken Info
                            if report.status == .resolved {
                                HStack(spacing: 12) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.successGreen)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Tindakan Diambil")
                                            .font(AppFont.caption())
                                            .fontWeight(.semibold)
                                            .foregroundColor(.textPrimary)
                                        Text("Pengguna yang dilaporkan telah disuspend dari aplikasi.")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                .padding(14)
                                .background(Color.successGreen.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }
                        }
                    } else {
                        // Pending Status - Show Form
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 4) {
                                Text("Catatan Admin")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textSecondary)
                                Text("*")
                                    .font(AppFont.caption())
                                    .foregroundColor(.errorRed)
                            }

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
                                        .stroke(adminNotes.isEmpty ? Color.errorRed.opacity(0.3) : Color.borderSoft, lineWidth: 1)
                                )

                            if adminNotes.isEmpty {
                                Text("Catatan wajib diisi untuk memberikan alasan kepada pengguna")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.errorRed)
                            }
                        }

                        // Action Buttons
                        VStack(spacing: 12) {
                            Button {
                                guard !adminNotes.isEmpty else { return }
                                showSuspendAlert = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.shield.fill")
                                        .font(.system(size: 16))
                                    Text("Suspend Pengguna")
                                        .font(AppFont.subheadline())
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(adminNotes.isEmpty ? Color.gray.opacity(0.4) : Color.errorRed)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }
                            .disabled(adminNotes.isEmpty)

                            Button {
                                guard !adminNotes.isEmpty else { return }
                                showDismissAlert = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Tolak Laporan")
                                        .font(AppFont.subheadline())
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(adminNotes.isEmpty ? .textSecondary : .textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.textSecondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }
                            .disabled(adminNotes.isEmpty)
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
            .navigationTitle("Detail Laporan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            .alert("Suspend Pengguna", isPresented: $showSuspendAlert) {
                Button("Batal", role: .cancel) { }
                Button("Suspend", role: .destructive) {
                    Task {
                        await adminVM.resolveReport(
                            reportID: report.id ?? "",
                            suspendUser: true,
                            adminUID: currentAdminUID,
                            adminNotes: adminNotes
                        )
                        successMessage = "Pengguna \(report.reportedName) berhasil disuspend.\n\nAlasan: \(adminNotes)"
                        showSuccessAlert = true
                    }
                }
            } message: {
                Text("Akun \(report.reportedName) akan disuspend dengan alasan:\n\n\"\(adminNotes)\"\n\nPengguna akan otomatis logout dan tidak bisa login lagi.")
            }
            .alert("Tolak Laporan", isPresented: $showDismissAlert) {
                Button("Batal", role: .cancel) { }
                Button("Tolak") {
                    Task {
                        await adminVM.dismissReport(
                            reportID: report.id ?? "",
                            adminUID: currentAdminUID,
                            adminNotes: adminNotes
                        )
                        successMessage = "Laporan berhasil ditolak.\n\nAlasan: \(adminNotes)"
                        showSuccessAlert = true
                    }
                }
            } message: {
                Text("Laporan akan ditolak dengan alasan:\n\n\"\(adminNotes)\"\n\nTidak ada tindakan yang diambil terhadap pengguna yang dilaporkan.")
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

    // Helper functions
    private func statusColor(for status: ReportStatus) -> Color {
        switch status {
        case .pending: return .errorRed
        case .reviewed: return .warningAmber
        case .resolved: return .successGreen
        case .dismissed: return .textSecondary
        }
    }

    private func statusIcon(for status: ReportStatus) -> String {
        switch status {
        case .pending: return "clock.fill"
        case .reviewed: return "eye.fill"
        case .resolved: return "checkmark.shield.fill"
        case .dismissed: return "xmark.circle.fill"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }
}
