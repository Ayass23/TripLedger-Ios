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
                colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
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
                            .fill(Color(hex: "#EF4444").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#EF4444"))
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

    // MARK: - Recent Users Section
    private var recentUsersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#3B82F6").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#3B82F6"))
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

    // MARK: - Stats Cards
    private var statsCards: some View {
        VStack(spacing: 12) {
            // Main stat - Total Users (larger)
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
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
            .shadow(color: Color(hex: "#7C3AED").opacity(0.15), radius: 12, y: 4)

            // Secondary stats row
            HStack(spacing: 12) {
                // Pending Reports
                StatCardCompact(
                    icon: "exclamationmark.triangle.fill",
                    title: "Laporan Pending",
                    value: "\(pendingReportsCount)",
                    color: Color(hex: "#EF4444"),
                    isUrgent: pendingReportsCount > 0
                )

                // Suspended Users
                StatCardCompact(
                    icon: "person.fill.xmark",
                    title: "User Suspend",
                    value: "\(suspendedUsersCount)",
                    color: Color(hex: "#F59E0B"),
                    isUrgent: false
                )

                // Active Users
                StatCardCompact(
                    icon: "checkmark.circle.fill",
                    title: "User Aktif",
                    value: "\(adminVM.allUsers.count - suspendedUsersCount)",
                    color: Color(hex: "#10B981"),
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
                        .foregroundColor(Color(hex: "#7C3AED").opacity(0.7))

                    Text(kelolaSegment == 0 ? "Pengguna" : "Laporan")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Notification badge for pending items
                if pendingReportsCount > 0 && kelolaSegment == 1 {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#EF4444"))
                            .frame(width: 8, height: 8)
                        Text("\(pendingReportsCount) pending")
                            .font(AppFont.caption2())
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#EF4444"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#EF4444").opacity(0.1))
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
                        .foregroundColor(Color(hex: "#7C3AED"))
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
                            colors: [Color(hex: "#7C3AED"), Color(hex: "#5B21B6")],
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
                    .foregroundColor(Color(hex: "#7C3AED"))

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
                    .stroke(Color(hex: "#7C3AED").opacity(0.2), lineWidth: 1)
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
                        .tint(Color(hex: "#7C3AED"))
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
                filterPill(title: "Semua", count: filteredUsers.count, index: 0, icon: "person.2.fill", color: Color(hex: "#7C3AED"))
                filterPill(title: "Aktif", count: activeUsers.count, index: 1, icon: "checkmark.circle.fill", color: Color(hex: "#10B981"))
                filterPill(title: "Tersuspend", count: suspendedUsers.count, index: 2, icon: "xmark.circle.fill", color: Color(hex: "#EF4444"))
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
                            colors: [Color(hex: "#7C3AED").opacity(0.1), Color(hex: "#7C3AED").opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(Color(hex: "#7C3AED").opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: "person.2.slash")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(hex: "#7C3AED").opacity(0.6))
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
                    .foregroundColor(Color(hex: "#7C3AED"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#7C3AED").opacity(0.1))
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
                            colors: [Color(hex: "#10B981").opacity(0.15), Color(hex: "#10B981").opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(Color(hex: "#10B981").opacity(0.2))
                    .frame(width: 70, height: 70)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(hex: "#10B981"))
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

// MARK: - Appeal Card Component
struct AppealCard: View {
    let appeal: AccountAppeal
    @ObservedObject var adminVM: AdminViewModel
    let currentAdminUID: String

    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.brandPrimary.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.brandPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.brandPrimary)
                            Text("BANDING PEMULIHAN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.brandPrimary)
                        }

                        Text(appeal.userName)
                            .font(AppFont.subheadline())
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text(appeal.userEmail)
                            .font(AppFont.caption())
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(timeAgo(from: appeal.createdAt.dateValue()))
                                .font(AppFont.caption2())
                        }
                        .foregroundColor(.textSecondary.opacity(0.7))
                    }

                    Spacer()

                    // Status Badge
                    Text(appeal.status.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor)
                        .clipShape(Capsule())
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Alasan Banding:")
                        .font(AppFont.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(.textSecondary)

                    Text(appeal.appealReason)
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            AppealDetailSheet(appeal: appeal, adminVM: adminVM, currentAdminUID: currentAdminUID)
        }
    }

    private var statusColor: Color {
        switch appeal.status {
        case .pending: return Color.warningAmber
        case .approved: return Color.successGreen
        case .rejected: return Color.errorRed
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

// MARK: - Rounded Corner Helper
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Stat Card Compact Component
struct StatCardCompact: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let isUrgent: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)

            Text(title)
                .font(AppFont.caption2())
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUrgent ? color.opacity(0.4) : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
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
