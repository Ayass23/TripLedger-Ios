import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var adminVM: AdminViewModel

    @State private var selectedTab = 0
    @State private var searchQuery = ""

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(hex: "#7C3AED").opacity(0.05),
                    Color.baseFallback
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Beautiful Header
                adminHeader

                // Stats Cards
                statsCards
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // Custom Tab Selector
                tabSelector
                    .padding(.top, 20)

                // Tab Content
                if selectedTab == 0 {
                    usersManagementTab
                } else {
                    reportsManagementTab
                }
            }
        }
        .onAppear {
            Task {
                await adminVM.loadAllUsers()
            }
            adminVM.listenToReports()
        }
    }

    // MARK: - Admin Header
    private var adminHeader: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: [
                    Color(hex: "#7C3AED"),
                    Color(hex: "#5B21B6")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    // Admin Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Admin Dashboard")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(authVM.currentUser?.displayName ?? "Administrator")
                            .font(AppFont.subheadline())
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    // Logout Button
                    Button {
                        authVM.logout()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Keluar")
                                .font(AppFont.caption())
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }
        }
        .frame(height: 140)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Stats Cards
    private var statsCards: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "person.2.fill",
                title: "Total Pengguna",
                value: "\(adminVM.allUsers.count)",
                gradient: [Color(hex: "#3B82F6"), Color(hex: "#1E40AF")]
            )

            StatCard(
                icon: "exclamationmark.triangle.fill",
                title: "Laporan Pending",
                value: "\(pendingReportsCount)",
                gradient: [Color(hex: "#EF4444"), Color(hex: "#B91C1C")]
            )

            StatCard(
                icon: "xmark.shield.fill",
                title: "User Suspended",
                value: "\(suspendedUsersCount)",
                gradient: [Color(hex: "#F59E0B"), Color(hex: "#D97706")]
            )
        }
    }

    private var pendingReportsCount: Int {
        adminVM.allReports.filter { $0.status == .pending }.count
    }

    private var suspendedUsersCount: Int {
        adminVM.allUsers.filter { $0.isSuspended }.count
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Kelola Pengguna", icon: "person.2.fill", index: 0)
            tabButton(title: "Kelola Laporan", icon: "exclamationmark.triangle.fill", index: 1, badge: pendingReportsCount)
        }
        .padding(.horizontal, 20)
        .background(Color.clear)
    }

    private func tabButton(title: String, icon: String, index: Int, badge: Int? = nil) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(title)
                        .font(AppFont.subheadline())
                        .fontWeight(selectedTab == index ? .bold : .semibold)

                    if let count = badge, count > 0 {
                        Text("\(count)")
                            .font(AppFont.caption2())
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.errorRed)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(selectedTab == index ? Color(hex: "#7C3AED") : .textPrimary.opacity(0.5))
                .padding(.vertical, 12)

                Rectangle()
                    .fill(selectedTab == index ?
                          LinearGradient(
                            colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
                            startPoint: .leading,
                            endPoint: .trailing
                          ) : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 3)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Users Management Tab
    private var usersManagementTab: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#7C3AED").opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#7C3AED"))
                }

                TextField("Cari nama atau email pengguna...", text: $searchQuery)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)

                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.textPrimary.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            // Users List
            if adminVM.isLoading {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(Color(hex: "#7C3AED"))
                    .padding(.top, 40)
            } else if filteredUsers.isEmpty {
                emptyUsersState
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredUsers) { user in
                            UserManagementCard(user: user, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var emptyUsersState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.textSecondary.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "person.2.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.textSecondary.opacity(0.4))
            }

            Text("Tidak ada pengguna")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary.opacity(0.6))

            Text("Pengguna dengan kriteria pencarian tidak ditemukan")
                .font(AppFont.caption())
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private var filteredUsers: [UserModel] {
        adminVM.searchUsers(query: searchQuery)
    }

    // MARK: - Reports Management Tab
    private var reportsManagementTab: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                // Pending Reports
                if !pendingReports.isEmpty {
                    sectionHeader("🔴 Menunggu Ditinjau", count: pendingReports.count, color: Color.errorRed)
                    ForEach(pendingReports) { report in
                        ReportCard(report: report, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                    }
                }

                // Reviewed Reports
                if !reviewedReports.isEmpty {
                    sectionHeader("👁️ Sedang Ditinjau", count: reviewedReports.count, color: Color.warningAmber)
                    ForEach(reviewedReports) { report in
                        ReportCard(report: report, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                    }
                }

                // Resolved Reports
                if !resolvedReports.isEmpty {
                    sectionHeader("✅ Diselesaikan", count: resolvedReports.count, color: Color.successGreen)
                    ForEach(resolvedReports) { report in
                        ReportCard(report: report, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                    }
                }

                // Dismissed Reports
                if !dismissedReports.isEmpty {
                    sectionHeader("❌ Ditolak", count: dismissedReports.count, color: Color.textSecondary)
                    ForEach(dismissedReports) { report in
                        ReportCard(report: report, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                    }
                }

                if adminVM.allReports.isEmpty {
                    emptyReportsState
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(AppFont.headline())
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            Text("\(count)")
                .font(AppFont.caption())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color)
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var emptyReportsState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.successGreen.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.successGreen.opacity(0.6))
            }

            Text("Tidak Ada Laporan")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary.opacity(0.7))

            Text("Belum ada laporan dari pengguna.\nSemuanya aman!")
                .font(AppFont.caption())
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private var pendingReports: [ReportModel] {
        adminVM.filteredReports(by: .pending)
    }

    private var reviewedReports: [ReportModel] {
        adminVM.filteredReports(by: .reviewed)
    }

    private var resolvedReports: [ReportModel] {
        adminVM.filteredReports(by: .resolved)
    }

    private var dismissedReports: [ReportModel] {
        adminVM.filteredReports(by: .dismissed)
    }
}

// MARK: - Stat Card Component
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let gradient: [Color]

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)

                Text(title)
                    .font(AppFont.caption2())
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
    }
}

// MARK: - User Management Card
struct UserManagementCard: View {
    let user: UserModel
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @State private var showSuspendAlert = false
    @State private var showUnsuspendAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarView(url: user.avatarURL, initials: user.initials, size: 56)
                    .overlay(
                        Circle()
                            .stroke(
                                user.isSuspended ? Color.errorRed.opacity(0.3) : Color.successGreen.opacity(0.2),
                                lineWidth: 2.5
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.displayName)
                            .font(AppFont.subheadline())
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        if user.role == .admin {
                            Text("ADMIN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                        }

                        if user.isSuspended {
                            Text("SUSPENDED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.errorRed)
                                .clipShape(Capsule())
                        }
                    }

                    Text(user.email)
                        .font(AppFont.caption())
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text("Bergabung \(formatDate(user.createdAt.dateValue()))")
                            .font(AppFont.caption2())
                    }
                    .foregroundColor(.textSecondary.opacity(0.8))
                }

                Spacer()
            }

            // Actions
            if user.role != .admin && user.uid != currentAdminUID {
                Divider()
                    .background(Color.borderSoft)

                HStack(spacing: 10) {
                    if user.isSuspended {
                        Button {
                            showUnsuspendAlert = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Aktifkan Kembali")
                                    .font(AppFont.caption())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.successGreen, Color.successGreen.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            showSuspendAlert = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.shield.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Suspend Akun")
                                    .font(AppFont.caption())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color.errorRed, Color.errorRed.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        .alert("Suspend Akun", isPresented: $showSuspendAlert) {
            Button("Batal", role: .cancel) { }
            Button("Suspend", role: .destructive) {
                Task {
                    await adminVM.suspendUser(uid: user.uid)
                }
            }
        } message: {
            Text("Apakah kamu yakin ingin suspend akun \(user.displayName)? Pengguna tidak akan bisa login ke aplikasi.")
        }
        .alert("Aktifkan Kembali", isPresented: $showUnsuspendAlert) {
            Button("Batal", role: .cancel) { }
            Button("Aktifkan") {
                Task {
                    await adminVM.unsuspendUser(uid: user.uid)
                }
            }
        } message: {
            Text("Aktifkan kembali akun \(user.displayName)? Pengguna akan bisa login ke aplikasi lagi.")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }
}

// MARK: - Report Card
struct ReportCard: View {
    let report: ReportModel
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @State private var showDetailSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Category & Status
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.errorRed.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: report.category.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.errorRed)
                    }

                    Text(report.category.displayName)
                        .font(AppFont.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                Text(report.status.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: report.status.color))
                    .clipShape(Capsule())
            }

            // Reported User
            VStack(alignment: .leading, spacing: 6) {
                Text("Pengguna Dilaporkan:")
                    .font(AppFont.caption2())
                    .foregroundColor(.textSecondary)

                HStack(spacing: 8) {
                    Text(report.reportedName)
                        .font(AppFont.subheadline())
                        .fontWeight(.bold)
                        .foregroundColor(.errorRed)

                    Text("•")
                        .foregroundColor(.textSecondary.opacity(0.5))

                    Text(report.reportedEmail)
                        .font(AppFont.caption())
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.errorRed.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Reporter
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary.opacity(0.6))
                Text("Dilaporkan oleh:")
                    .font(AppFont.caption2())
                    .foregroundColor(.textSecondary)
                Text(report.reporterName)
                    .font(AppFont.caption2())
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
            }

            // Reason Preview
            Text(report.reason)
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.8))
                .lineLimit(3)
                .padding(.top, 4)

            // Footer: Date & Action
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary.opacity(0.6))
                    Text(timeAgo(from: report.createdAt.dateValue()))
                        .font(AppFont.caption2())
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Action Button
                if report.status == .pending || report.status == .reviewed {
                    Button {
                        showDetailSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Tinjau")
                                .font(AppFont.caption())
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    report.status == .pending ? Color.errorRed.opacity(0.3) : Color.borderSoft.opacity(0.5),
                    lineWidth: report.status == .pending ? 2 : 1
                )
        )
        .shadow(color: Color.black.opacity(report.status == .pending ? 0.08 : 0.04), radius: 8, y: 3)
        .sheet(isPresented: $showDetailSheet) {
            ReportDetailSheet(report: report, adminVM: adminVM, currentAdminUID: currentAdminUID)
        }
    }

    private func timeAgo(from date: Date) -> String {
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

// MARK: - Report Detail Sheet
struct ReportDetailSheet: View {
    let report: ReportModel
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @Environment(\.dismiss) var dismiss
    @State private var adminNotes = ""
    @State private var showResolveAlert = false
    @State private var showDismissAlert = false
    @State private var suspendUserOnResolve = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Status Badge
                        HStack {
                            Spacer()
                            Text(report.status.displayName)
                                .font(AppFont.subheadline())
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Color(hex: report.status.color))
                                .clipShape(Capsule())
                            Spacer()
                        }

                        // Reported User
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pengguna Dilaporkan")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))

                            VStack(alignment: .leading, spacing: 8) {
                                Text(report.reportedName)
                                    .font(AppFont.title3())
                                    .fontWeight(.bold)
                                    .foregroundColor(.errorRed)

                                Text(report.reportedEmail)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textSecondary)

                                Text("UID: \(report.reportedUID)")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textSecondary.opacity(0.7))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.errorRed.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        }

                        // Reporter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dilaporkan Oleh")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))

                            HStack {
                                Text(report.reporterName)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                                Text("(\(report.reporterUID))")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textSecondary)
                            }
                        }

                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kategori")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))

                            HStack(spacing: 8) {
                                Image(systemName: report.category.icon)
                                Text(report.category.displayName)
                            }
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.textPrimary.opacity(0.06))
                            .clipShape(Capsule())
                        }

                        // Reason
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alasan")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))

                            Text(report.reason)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.cardFallback)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        }

                        // Date
                        HStack {
                            Text("Tanggal Laporan:")
                                .font(AppFont.caption())
                                .foregroundColor(.textSecondary)
                            Text(formatDate(report.createdAt.dateValue()))
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary)
                        }

                        // Admin Notes (if resolved)
                        if let notes = report.adminNotes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Catatan Admin")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary.opacity(0.6))

                                Text(notes)
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(hex: "#7C3AED").opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }
                        }

                        // Actions (only if pending or reviewed)
                        if report.status == .pending || report.status == .reviewed {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Catatan Admin (Opsional)")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary.opacity(0.6))

                                TextEditor(text: $adminNotes)
                                    .frame(height: 80)
                                    .scrollContentBackground(.hidden)
                                    .font(AppFont.subheadline())
                                    .padding(12)
                                    .background(Color.cardFallback)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.md)
                                            .stroke(Color.borderSoft, lineWidth: 1)
                                    )

                                Toggle("Suspend pengguna yang dilaporkan", isOn: $suspendUserOnResolve)
                                    .font(AppFont.subheadline())
                                    .tint(.errorRed)

                                HStack(spacing: 12) {
                                    Button {
                                        showDismissAlert = true
                                    } label: {
                                        Text("Tolak")
                                            .font(AppFont.subheadline())
                                            .fontWeight(.semibold)
                                            .foregroundColor(.textPrimary.opacity(0.7))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.textPrimary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                    }

                                    Button {
                                        showResolveAlert = true
                                    } label: {
                                        Text("Selesaikan")
                                            .font(AppFont.subheadline())
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
                .dismissKeyboardOnTap()
            }
            .navigationTitle("Detail Laporan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") {
                        dismiss()
                    }
                }
            }
            .alert("Selesaikan Laporan", isPresented: $showResolveAlert) {
                Button("Batal", role: .cancel) { }
                Button("Selesaikan") {
                    Task {
                        await adminVM.resolveReport(
                            reportID: report.id ?? "",
                            suspendUser: suspendUserOnResolve,
                            adminUID: currentAdminUID,
                            adminNotes: adminNotes.isEmpty ? nil : adminNotes
                        )
                        dismiss()
                    }
                }
            } message: {
                if suspendUserOnResolve {
                    Text("Laporan akan diselesaikan dan akun \(report.reportedName) akan disuspend.")
                } else {
                    Text("Laporan akan diselesaikan tanpa suspend akun pengguna.")
                }
            }
            .alert("Tolak Laporan", isPresented: $showDismissAlert) {
                Button("Batal", role: .cancel) { }
                Button("Tolak") {
                    Task {
                        await adminVM.dismissReport(
                            reportID: report.id ?? "",
                            adminUID: currentAdminUID,
                            adminNotes: adminNotes.isEmpty ? nil : adminNotes
                        )
                        dismiss()
                    }
                }
            } message: {
                Text("Laporan akan ditolak dan tidak ada tindakan yang diambil terhadap pengguna yang dilaporkan.")
            }
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
