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
        .tint(Color.adminPurple)
        .onAppear {
            adminVM.listenToUsers()
            adminVM.listenToReports()
            adminVM.listenToAppeals()
        }
    }

    // MARK: - Home Tab
    private var homeTab: some View {
        NavigationStack {
            ZStack {
                // Base background
                Color.baseFallback.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    adminHeroHeader

                    // Scrollable content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Stats Cards
                            statsCards
                                .padding(.horizontal, 20)
                                .padding(.top, 24)

                            // Recent Reports Section
                            if !adminVM.allReports.isEmpty {
                                recentReportsSection
                                    .padding(.top, 24)
                            }

                            // Recent Users Section
                            if !adminVM.allUsers.isEmpty {
                                recentUsersSection
                                    .padding(.top, 24)
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Admin Hero Header
    private var adminHeroHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top bar with badge and logout
            HStack {
                // Admin badge
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 12, weight: .semibold))
                    Text("ADMIN")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1)
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())

                Spacer()

                Button {
                    authVM.logout()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Keluar")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }
            }

            // Welcome text
            VStack(alignment: .leading, spacing: 2) {
                Text("Selamat Datang,")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text(authVM.currentUser?.displayName ?? "Admin")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.adminPurple, Color.adminPurpleDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Recent Reports Section
    private var recentReportsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.dangerRed.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dangerRed)
                    }

                    Text("Laporan Terbaru")
                        .font(AppFont.headline())
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                Button {
                    selectedTab = 1
                    kelolaSegment = 1
                } label: {
                    HStack(spacing: 4) {
                        Text("Lihat Semua")
                            .font(AppFont.caption())
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color.adminPurple)
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

    // MARK: - Recent Users Section
    private var recentUsersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.infoBlue.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.infoBlue)
                    }

                    Text("Pengguna Terbaru")
                        .font(AppFont.headline())
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                Button {
                    selectedTab = 1
                    kelolaSegment = 0
                } label: {
                    HStack(spacing: 4) {
                        Text("Lihat Semua")
                            .font(AppFont.caption())
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color.adminPurple)
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

    // MARK: - Stats Cards
    private var statsCards: some View {
        VStack(spacing: 12) {
            // Main stat - Total Users (larger)
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.adminPurple, Color.adminPurpleDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Pengguna Terdaftar")
                        .font(AppFont.caption())
                        .foregroundColor(.textSecondary)

                    Text("\(adminVM.allUsers.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Trend indicator
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.successGreen)

                    Text("Aktif")
                        .font(AppFont.caption2())
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(20)
            .background(Color.cardFallback)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.adminPurple.opacity(0.15), radius: 12, y: 4)

            // Secondary stats row
            HStack(spacing: 12) {
                // Pending Reports
                StatCardCompact(
                    icon: "exclamationmark.triangle.fill",
                    title: "Laporan Pending",
                    value: "\(pendingReportsCount)",
                    color: Color.dangerRed,
                    isUrgent: pendingReportsCount > 0
                )

                // Suspended Users
                StatCardCompact(
                    icon: "person.fill.xmark",
                    title: "User Suspend",
                    value: "\(suspendedUsersCount)",
                    color: Color.warningAmber,
                    isUrgent: false
                )

                // Active Users
                StatCardCompact(
                    icon: "checkmark.circle.fill",
                    title: "User Aktif",
                    value: "\(adminVM.allUsers.count - suspendedUsersCount)",
                    color: Color.successEmerald,
                    isUrgent: false
                )
            }
        }
    }

    private var recentReports: [ReportModel] {
        Array(adminVM.allReports.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }.prefix(3))
    }

    private var recentUsers: [UserModel] {
        Array(adminVM.allUsers.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }.prefix(3))
    }

    private var pendingReportsCount: Int {
        let pendingReports = adminVM.allReports.filter { $0.status == .pending }.count
        let pendingAppeals = adminVM.allAppeals.filter { $0.status == .pending }.count
        return pendingReports + pendingAppeals
    }

    private var suspendedUsersCount: Int {
        adminVM.allUsers.filter { $0.isSuspended }.count
    }

    // MARK: - Kelola Tab
    private var kelolaTab: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                kelolaHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Content based on segment
                        if kelolaSegment == 0 {
                            kelolaUserContent
                        } else {
                            kelolaReportContent
                        }
                    }
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .background(Color.baseFallback.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: - Kelola Header
    private var kelolaHeader: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KELOLA")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(Color.adminPurple.opacity(0.7))

                    Text(kelolaSegment == 0 ? "Pengguna" : "Laporan")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Notification badge for pending items
                if pendingReportsCount > 0 && kelolaSegment == 1 {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.dangerRed)
                            .frame(width: 8, height: 8)
                        Text("\(pendingReportsCount) pending")
                            .font(AppFont.caption2())
                            .fontWeight(.semibold)
                            .foregroundColor(Color.dangerRed)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.dangerRed.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Segmented Control
            segmentedControl
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(Color.baseFallback)
    }

    // MARK: - Segmented Control
    private var segmentedControl: some View {
        HStack(spacing: 4) {
            segmentButton(title: "Pengguna", icon: "person.2.fill", index: 0, count: adminVM.allUsers.count)
            segmentButton(title: "Laporan", icon: "exclamationmark.triangle.fill", index: 1, count: adminVM.allReports.count)
        }
        .padding(4)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }

    private func segmentButton(title: String, icon: String, index: Int, count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                kelolaSegment = index
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))

                Text(title)
                    .font(AppFont.subheadline())
                    .fontWeight(.semibold)

                if kelolaSegment == index {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.adminPurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(kelolaSegment == index ? .white : .textPrimary.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Group {
                    if kelolaSegment == index {
                        LinearGradient(
                            colors: [Color.adminPurple, Color.adminPurpleDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.clear
                    }
                }
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
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.adminPurple)

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
            .background(Color.cardFallback)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.adminPurple.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Filter Tabs
            userFilterTabs
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Users List
            if adminVM.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(Color.adminPurple)
                    Text("Memuat data...")
                        .font(AppFont.caption())
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 60)
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
                .padding(.bottom, 100)
            }
        }
    }

    // MARK: - User Filter Tabs
    private var userFilterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterPill(title: "Semua", count: filteredUsers.count, index: 0, icon: "person.2.fill", color: Color.adminPurple)
                filterPill(title: "Aktif", count: activeUsers.count, index: 1, icon: "checkmark.circle.fill", color: Color.successEmerald)
                filterPill(title: "Tersuspend", count: suspendedUsers.count, index: 2, icon: "xmark.circle.fill", color: Color.dangerRed)
            }
        }
    }

    private func filterPill(title: String, count: Int, index: Int, icon: String, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                userFilterTab = index
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))

                Text(title)
                    .font(AppFont.caption())
                    .fontWeight(.semibold)

                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(userFilterTab == index ? color : .textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(userFilterTab == index ? Color.white : Color.textPrimary.opacity(0.08))
                    .clipShape(Capsule())
            }
            .foregroundColor(userFilterTab == index ? .white : .textPrimary.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if userFilterTab == index {
                        color
                    } else {
                        Color.cardFallback
                    }
                }
            )
            .clipShape(Capsule())
            .shadow(color: userFilterTab == index ? color.opacity(0.3) : Color.black.opacity(0.05), radius: 6, y: 2)
        }
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.adminPurple.opacity(0.1), Color.adminPurple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(Color.adminPurple.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: "person.2.slash")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color.adminPurple.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("Tidak Ada Pengguna")
                    .font(AppFont.headline())
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)

                Text("Pengguna dengan kriteria\npencarian tidak ditemukan")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                        Text("Hapus Pencarian")
                            .font(AppFont.caption())
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color.adminPurple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.adminPurple.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Kelola Report Content
    private var kelolaReportContent: some View {
        VStack(spacing: 14) {
            // Pending Items (Reports + Appeals)
            if !pendingReports.isEmpty || !pendingAppeals.isEmpty {
                sectionHeader("🔴 Menunggu Ditinjau", count: pendingReports.count + pendingAppeals.count, color: Color.errorRed)

                // Show Pending Appeals first
                ForEach(pendingAppeals) { appeal in
                    AppealCard(appeal: appeal, adminVM: adminVM, currentAdminUID: authVM.currentUser?.uid ?? "")
                }

                // Then Pending Reports
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
        HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: iconForSection(title))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(title.replacingOccurrences(of: "🔴 ", with: "")
                      .replacingOccurrences(of: "👁️ ", with: "")
                      .replacingOccurrences(of: "✅ ", with: "")
                      .replacingOccurrences(of: "❌ ", with: ""))
                .font(AppFont.headline())
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color)
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func iconForSection(_ title: String) -> String {
        if title.contains("Menunggu") { return "clock.fill" }
        if title.contains("Sedang") { return "eye.fill" }
        if title.contains("Diselesaikan") { return "checkmark.circle.fill" }
        if title.contains("Ditolak") { return "xmark.circle.fill" }
        return "doc.fill"
    }

    private var emptyReportsState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.successEmerald.opacity(0.15), Color.successEmerald.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(Color.successEmerald.opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color.successEmerald)
            }

            VStack(spacing: 8) {
                Text("Semua Aman! 🎉")
                    .font(AppFont.headline())
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)

                Text("Tidak ada laporan dari pengguna.\nAplikasi berjalan dengan baik!")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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

    private var pendingAppeals: [AccountAppeal] {
        adminVM.filteredAppeals(by: .pending)
    }

    private var approvedAppeals: [AccountAppeal] {
        adminVM.filteredAppeals(by: .approved)
    }

    private var rejectedAppeals: [AccountAppeal] {
        adminVM.filteredAppeals(by: .rejected)
    }
}
