import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var adminVM: AdminViewModel

    @State private var selectedTab = 0
    @State private var kelolaSegment = 0 // 0: Pengguna, 1: Laporan
    @State private var userFilterTab = 0 // 0: Semua, 1: Aktif, 2: Tersuspend
    @State private var searchQuery = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Home
            homeTab
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            // Tab 2: Kelola
            Group {
                if pendingReportsCount > 0 {
                    kelolaTab
                        .badge(pendingReportsCount)
                } else {
                    kelolaTab
                }
            }
            .tabItem {
                Label("Kelola", systemImage: "gearshape.fill")
            }
            .tag(1)
        }
        .tint(Color(hex: "#7C3AED"))
        .onAppear {
            Task {
                await adminVM.loadAllUsers()
            }
            adminVM.listenToReports()
        }
    }

    // MARK: - Home Tab
    private var homeTab: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        Color(hex: "#7C3AED").opacity(0.15),
                        Color(hex: "#7C3AED").opacity(0.08),
                        Color.baseFallback
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Stats Cards
                        statsCards
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        // Recent Reports Section
                        if !adminVM.allReports.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("📋 Laporan Terbaru")
                                        .font(AppFont.headline())
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Button {
                                        selectedTab = 1
                                        kelolaSegment = 1
                                    } label: {
                                        Text("Lihat Semua")
                                            .font(AppFont.caption())
                                            .foregroundColor(Color(hex: "#7C3AED"))
                                    }
                                }
                                .padding(.horizontal, 20)

                                LazyVStack(spacing: 12) {
                                    ForEach(recentReports) { report in
                                        ReportCard(report: report, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Recent Users Section
                        if !adminVM.allUsers.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("👥 Pengguna Terbaru")
                                        .font(AppFont.headline())
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    Button {
                                        selectedTab = 1
                                        kelolaSegment = 0
                                    } label: {
                                        Text("Lihat Semua")
                                            .font(AppFont.caption())
                                            .foregroundColor(Color(hex: "#7C3AED"))
                                    }
                                }
                                .padding(.horizontal, 20)

                                LazyVStack(spacing: 12) {
                                    ForEach(recentUsers) { user in
                                        UserManagementCard(user: user, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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

                        .clipShape(Capsule())
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithTransparentBackground()
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#7C3AED"))]
                appearance.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#7C3AED"))]
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
            }
        }
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

    private var recentReports: [ReportModel] {
        Array(adminVM.allReports.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }.prefix(3))
    }

    private var recentUsers: [UserModel] {
        Array(adminVM.allUsers.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }.prefix(3))
    }

    private var pendingReportsCount: Int {
        adminVM.allReports.filter { $0.status == .pending }.count
    }

    private var suspendedUsersCount: Int {
        adminVM.allUsers.filter { $0.isSuspended }.count
    }

    // MARK: - Kelola Tab
    private var kelolaTab: some View {
        NavigationStack {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        Color(hex: "#7C3AED").opacity(0.15),
                        Color(hex: "#7C3AED").opacity(0.08),
                        Color.baseFallback
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Segmented Control
                        segmentedControl
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        // Content based on segment
                        if kelolaSegment == 0 {
                            kelolaUserContent
                        } else {
                            kelolaReportContent
                        }
                    }
                }
            }
            .navigationTitle("Kelola")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Segmented Control
    private var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Kelola Pengguna", icon: "person.2.fill", index: 0)
            segmentButton(title: "Kelola Laporan", icon: "exclamationmark.triangle.fill", index: 1)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }

    private func segmentButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                kelolaSegment = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(AppFont.caption())
                    .fontWeight(.semibold)
            }
            .foregroundColor(kelolaSegment == index ? .white : .textPrimary.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                kelolaSegment == index ?
                LinearGradient(
                    colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
                    startPoint: .leading,
                    endPoint: .trailing
                ) : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Kelola User Content
    private var kelolaUserContent: some View {
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
            .padding(.top, 16)

            // Filter Tabs
            userFilterTabs
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Users List
            if adminVM.isLoading {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(Color(hex: "#7C3AED"))
                    .padding(.top, 40)
            } else if filteredUsersByTab.isEmpty {
                emptyUsersState
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredUsersByTab) { user in
                        UserManagementCard(user: user, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - User Filter Tabs
    private var userFilterTabs: some View {
        HStack(spacing: 8) {
            filterTab(title: "Semua", count: filteredUsers.count, index: 0)
            filterTab(title: "Aktif", count: activeUsers.count, index: 1)
            filterTab(title: "Tersuspend", count: suspendedUsers.count, index: 2)
        }
    }

    private func filterTab(title: String, count: Int, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                userFilterTab = index
            }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(AppFont.caption())
                        .fontWeight(userFilterTab == index ? .bold : .semibold)

                    Text("\(count)")
                        .font(AppFont.caption2())
                        .foregroundColor(userFilterTab == index ? .white : .textPrimary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(userFilterTab == index ? Color(hex: "#7C3AED") : Color.textPrimary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .foregroundColor(userFilterTab == index ? Color(hex: "#7C3AED") : .textPrimary.opacity(0.5))
                .padding(.vertical, 8)

                Rectangle()
                    .fill(userFilterTab == index ? Color(hex: "#7C3AED") : Color.clear)
                    .frame(height: 2.5)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var filteredUsers: [UserModel] {
        adminVM.searchUsers(query: searchQuery)
    }

    private var activeUsers: [UserModel] {
        filteredUsers.filter { !$0.isSuspended }
    }

    private var suspendedUsers: [UserModel] {
        filteredUsers.filter { $0.isSuspended }
    }

    private var filteredUsersByTab: [UserModel] {
        switch userFilterTab {
        case 0: return filteredUsers
        case 1: return activeUsers
        case 2: return suspendedUsers
        default: return filteredUsers
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

    // MARK: - Kelola Report Content
    private var kelolaReportContent: some View {
        VStack(spacing: 14) {
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
        .padding(.top, 20)
        .padding(.bottom, 40)
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
        .tint(.brandPrimary)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }
}

// MARK: - Report Card Component
struct ReportCard: View {
    let report: ReportModel
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    // Category Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: report.category.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(statusColor)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(report.reportedName)
                            .font(AppFont.subheadline())
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text(report.category.displayName)
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(timeAgo(from: report.createdAt.dateValue()))
                                .font(AppFont.caption2())
                        }
                        .foregroundColor(.textSecondary.opacity(0.7))
                    }

                    Spacer()

                    // Status Badge
                    Text(report.status.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor)
                        .clipShape(Capsule())
                }

                Divider()

                Text(report.reason)
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.8))
                    .lineLimit(2)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(statusColor.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            ReportDetailSheet(report: report, adminVM: adminVM, currentAdminUID: currentAdminUID)
        }
    }

    private var statusColor: Color {
        switch report.status {
        case .pending: return Color.errorRed
        case .reviewed: return Color.warningAmber
        case .resolved: return Color.successGreen
        case .dismissed: return Color.textSecondary
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

    @Environment(\.dismiss) private var dismiss

    @State private var adminNotes = ""
    @State private var suspendUserOnResolve = false
    @State private var showResolveAlert = false
    @State private var showDismissAlert = false

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

                    // Admin Notes
                    if report.status == .pending {
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

                            Toggle(isOn: $suspendUserOnResolve) {
                                Text("Suspend pengguna yang dilaporkan")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary)
                            }
                            .tint(.errorRed)
                        }

                        // Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                showDismissAlert = true
                            } label: {
                                Text("Tolak Laporan")
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.textSecondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }

                            Button {
                                showResolveAlert = true
                            } label: {
                                Text("Selesaikan")
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(LinearGradient.brandGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            }
                        }
                    } else if let notes = report.adminNotes {
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
            }
            .background(Color.baseFallback)
            .navigationTitle("Detail Laporan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
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
            .tint(.brandPrimary)
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
            .tint(.brandPrimary)
        }
    }
}
