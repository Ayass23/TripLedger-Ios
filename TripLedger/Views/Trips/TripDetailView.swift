import SwiftUI
import FirebaseCore
import FirebaseFirestore

enum ReportType {
    case tripSummary
    case personalExpense
}

struct TripDetailView: View {
    let trip: TripModel

    @EnvironmentObject private var authVM:    AuthViewModel
    @EnvironmentObject private var tripVM:    TripViewModel
    @StateObject private var expenseVM = ExpenseViewModel()
    @Environment(\.dismiss) private var dismiss

    // Real-time trip data
    @State private var currentTrip: TripModel
    @State private var tripListener: ListenerRegistration?

    @State private var showReportPreview = false
    @State private var showSelectReportSheet = false
    @State private var selectedReportType: ReportType?
    @State private var reportPDFURL: URL?
    @State private var reportTitle = ""
    @State private var showDeleteAlert = false
    @State private var showLeaveAlert  = false
    @State private var showFinishAlert = false
    @State private var showFinishSuccess = false
    @State private var showInvite      = false
    @State private var showKickAlert   = false
    @State private var showEditTrip    = false
    @State private var memberToKick:   TripMember?
    @State private var selectedTab     = 0
    @State private var isAddingExpense = false

    init(trip: TripModel) {
        self.trip = trip
        _currentTrip = State(initialValue: trip)
    }

    private var isOwner: Bool {
        currentTrip.ownerUID == authVM.currentUser?.uid
    }

    private var isAdmin: Bool {
        guard let uid = authVM.currentUser?.uid else { return false }
        return currentTrip.adminUIDs.contains(uid)
    }

    private var statusColor: Color {
        switch currentTrip.status {
        case .planned:  return .brandAccent
        case .active:   return .successGreen
        case .finished: return .textPrimary.opacity(0.35)
        case .deleted:  return .errorRed
        }
    }

    private var statusText: String {
        switch currentTrip.status {
        case .planned:  return "Direncanakan"
        case .active:   return "Aktif"
        case .finished: return "Selesai"
        case .deleted:  return "Dihapus"
        }
    }

    private var tripHasEnded: Bool {
        guard let endDate = currentTrip.endDate?.dateValue() else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let tripEnd = Calendar.current.startOfDay(for: endDate)
        return tripEnd < today
    }

    private var finishAlertMessage: String {
        if tripHasEnded {
            return "Trip \"\(currentTrip.name)\" akan ditandai sebagai selesai. Kamu masih bisa melihat riwayat trip ini."
        } else if let endDate = currentTrip.endDate?.dateValue() {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "id_ID")
            formatter.dateFormat = "d MMMM yyyy"
            let dateStr = formatter.string(from: endDate)
            return "Trip ini dijadwalkan sampai \(dateStr). Kamu masih bisa selesaikan sekarang jika sudah tidak diperlukan."
        } else {
            return "Trip \"\(currentTrip.name)\" akan ditandai sebagai selesai. Kamu masih bisa melihat riwayat trip ini."
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.baseFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom segmented picker
                pickerSection

                TabView(selection: $selectedTab) {
                    detailsTab.tag(0)
                    expensesTab.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // FAB — only on Expenses tab and trip is not finished/deleted
            if selectedTab == 1 && (currentTrip.status == .planned || currentTrip.status == .active) {
                Button {
                    isAddingExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(LinearGradient.brandGradient)
                        .clipShape(Circle())
                        .shadow(color: Color.primaryFallback.opacity(0.45), radius: 12)
                }
                .navigationDestination(isPresented: $isAddingExpense) {
                    AddExpenseMethodView(trip: currentTrip, isAddingExpense: $isAddingExpense)
                        .environmentObject(authVM)
                        .environmentObject(expenseVM)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Detail Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if isOwner || isAdmin {
                        Button { showEditTrip = true } label: {
                            Label("Edit Trip", systemImage: "pencil")
                        }
                    }

                    // Laporan - Opens sheet
                    Button {
                        showSelectReportSheet = true
                    } label: {
                        Label("Laporan", systemImage: "chart.bar.fill")
                    }

                    Divider()
                    if isOwner {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Hapus Trip", systemImage: "trash.fill")
                        }
                    } else {
                        Button(role: .destructive) {
                            showLeaveAlert = true
                        } label: {
                            Label("Keluar Trip", systemImage: "rectangle.portrait.and.arrow.right.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
            }
        }
        .onAppear {
            expenseVM.listenExpenses(tripID: trip.id ?? "")
            listenToTripUpdates()
        }
        .onDisappear {
            tripListener?.remove()
        }
        .fullScreenCover(isPresented: $showReportPreview) {
            if let url = reportPDFURL {
                PDFPreviewView(pdfURL: url, title: reportTitle)
            }
        }
        .sheet(isPresented: $showSelectReportSheet) {
            SelectReportTypeSheet(
                onSelectTripSummary: {
                    selectedReportType = .tripSummary
                    generateReport()
                },
                onSelectPersonalExpense: {
                    selectedReportType = .personalExpense
                    generateReport()
                }
            )
            .presentationDetents([.height(350)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditTrip) {
            EditTripView(trip: currentTrip)
                .environmentObject(authVM)
                .environmentObject(tripVM)
        }
        .alert("Hapus Trip?", isPresented: $showDeleteAlert) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) {
                Task {
                    guard let tripID = trip.id, !tripID.isEmpty else { return }
                    await tripVM.deleteTrip(tripID: tripID)
                    dismiss()
                }
            }
        } message: {
            Text("Trip \"\(currentTrip.name)\" akan dihapus secara permanen. Tindakan ini tidak bisa dibatalkan.")
        }
        .alert("Keluar dari Trip?", isPresented: $showLeaveAlert) {
            Button("Batal", role: .cancel) {}
            Button("Keluar", role: .destructive) {
                Task {
                    guard let tripID = trip.id, let uid = authVM.currentUser?.uid else { return }
                    await tripVM.leaveTrip(tripID: tripID, uid: uid)
                    dismiss()
                }
            }
        } message: {
            Text("Anda akan keluar dari trip \"\(currentTrip.name)\" dan tidak bisa mengaksesnya lagi kecuali diundang kembali.")
        }
        .alert("Keluarkan Anggota?", isPresented: $showKickAlert) {
            Button("Batal", role: .cancel) { memberToKick = nil }
            Button("Keluarkan", role: .destructive) {
                if let member = memberToKick, let tripID = trip.id {
                    Task { await tripVM.kickMember(tripID: tripID, memberUID: member.uid) }
                    memberToKick = nil
                }
            }
        } message: {
            Text("Anggota \"\(memberToKick?.displayName ?? "")\" akan dikeluarkan dari trip ini.")
        }
        .alert("Selesaikan Trip?", isPresented: $showFinishAlert) {
            Button("Batal", role: .cancel) {}
            Button("Selesaikan") {
                Task {
                    guard let tripID = currentTrip.id else { return }
                    await tripVM.finishTrip(tripID: tripID, trip: currentTrip, currentUser: authVM.currentUser)
                    showFinishSuccess = true
                }
            }
        } message: {
            Text(finishAlertMessage)
        }
        .tint(.brandPrimary)
        .alert("Selamat! 🎉", isPresented: $showFinishSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Trip \"\(currentTrip.name)\" sudah selesai. Terima kasih sudah berpetualang bersama!")
        }
        .tint(.brandPrimary)
    }

    // MARK: - Native Segmented Picker
    private var pickerSection: some View {
        Picker("Menu", selection: $selectedTab) {
            Text("Details").tag(0)
            Text("Expenses").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.baseFallback)
        .onAppear {
            let primaryColor = UIColor(Color.brandPrimary)
            UISegmentedControl.appearance().selectedSegmentTintColor = primaryColor
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(Color.textPrimary.opacity(0.6))], for: .normal)
        }
    }

    // MARK: - Details Tab
    private var detailsTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Trip Info Card
                tripInfoCard

                // Members Section
                membersSection

                // Finish Trip Button (Owner only, Active trips only)
                if isOwner && currentTrip.isActive {
                    finishTripButton
                }

                Spacer().frame(height: 20)
            }
            .padding(16)
        }
    }

    // MARK: - Helper Functions
    private func listenToTripUpdates() {
        guard let tripID = trip.id else { return }
        let db = FirestoreService.shared.db

        tripListener = db.collection(Collection.trips)
            .document(tripID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to trip updates: \(error)")
                    return
                }

                guard let snapshot = snapshot,
                      let updatedTrip = try? snapshot.data(as: TripModel.self) else {
                    return
                }

                currentTrip = updatedTrip
            }
    }

    private var tripInfoCard: some View {
        VStack(spacing: 0) {
            // Top row: Emoji kiri | Nama + Status kanan
            HStack(alignment: .center, spacing: 16) {
                // Cover Emoji
                Text(currentTrip.coverEmoji)
                    .font(.system(size: 48))
                    .frame(width: 72, height: 72)
                    .background(Color.textPrimary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Nama + Status
                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.name)
                        .font(AppFont.title2())
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)

                    // Status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text(statusText)
                            .font(AppFont.caption())
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(20)

            Divider().padding(.horizontal, 16)

            // Detail: Berangkat → Pulang, Durasi, Anggota
            HStack(spacing: 0) {
                // Tanggal berangkat - pulang
                VStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.brandAccent)
                    Text("Tanggal")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.4))
                    Text(tripDateRangeLabel)
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 44)

                // Durasi
                VStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.brandAccent)
                    Text("Durasi")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.4))
                    Text(tripDurationLabel)
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 44)

                // Anggota
                VStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.brandAccent)
                    Text("Anggota")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.4))
                    Text("\(trip.memberCount)")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 14)
        }
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // Computed: "12 Apr – 15 Apr 2026" atau "–" jika tidak ada
    private var tripDateRangeLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMM"
        let fYear = DateFormatter()
        fYear.locale = Locale(identifier: "id_ID")
        fYear.dateFormat = "d MMM yyyy"

        if let start = trip.startDate?.dateValue(), let end = trip.endDate?.dateValue() {
            return "\(f.string(from: start)) –\n\(fYear.string(from: end))"
        }
        return "–"
    }

    // Computed: "3 Hari" atau "–"
    private var tripDurationLabel: String {
        if let start = trip.startDate?.dateValue(), let end = trip.endDate?.dateValue() {
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
            return "\(max(1, days + 1)) Hari"
        }
        return "–"
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f.string(from: date)
    }


    // MARK: - Members Section
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Members")
                    .font(AppFont.title3())
                    .foregroundColor(.textPrimary)
                Spacer()

                // Add member button (owner/admin only)
                if (isOwner || isAdmin) && trip.isActive {
                    Button { showInvite = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 13))
                            Text("Tambah")
                                .font(AppFont.caption())
                        }
                        .foregroundColor(.brandAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandAccent.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .sheet(isPresented: $showInvite) {
                        inviteMemberSheet
                    }
                }
            }

            ForEach(trip.members) { member in
                HStack(spacing: 14) {
                    AvatarView(url: member.avatarURL, initials: String(member.displayName.prefix(2)).uppercased(), size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(member.displayName)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                            if member.uid == authVM.currentUser?.uid {
                                Text("Kamu")
                                    .font(AppFont.caption2())
                                    .foregroundColor(Color.accentFallback)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.accentFallback.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(member.role.rawValue.capitalized)
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.4))
                    }
                    Spacer()

                    // Role badge
                    roleBadge(member.role)

                    // Delete button (owner only, cannot delete self)
                    if isOwner && member.uid != authVM.currentUser?.uid && trip.isActive {
                        Button {
                            memberToKick = member
                            showKickAlert = true
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.errorRed.opacity(0.7))
                        }
                    }
                }
                .padding(14)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            }
        }
    }

    // MARK: - Finish Trip Button
    private var finishTripButton: some View {
        Button {
            showFinishAlert = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "flag.pattern.checkered")
                    .font(.system(size: 16, weight: .semibold))
                Text("Selesaikan Trip")
                    .font(AppFont.headline())
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                (LinearGradient.brandGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.purple.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func roleBadge(_ role: TripMemberRole) -> some View {
        if role == .pending {
            Text("Pending")
                .font(AppFont.caption2())
                .foregroundColor(.warningAmber)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.warningAmber.opacity(0.15))
                .clipShape(Capsule())
        } else {
            let (color, icon): (Color, String) = {
                switch role {
                case .owner:  return (.warningAmber, "crown.fill")
                case .admin:  return (.primaryFallback, "star.fill")
                case .member: return (.textPrimary.opacity(0.3), "person.fill")
                case .pending: return (.clear, "")
                }
            }()
            Image(systemName: icon).foregroundColor(color).font(.system(size: 14))
        }
    }

    // MARK: - Invite Member Sheet
    private var inviteMemberSheet: some View {
        InviteMemberSheetView(trip: trip, showInvite: $showInvite)
            .environmentObject(authVM)
            .environmentObject(tripVM)
    }

    // MARK: - Expenses Tab
    private var expensesTab: some View {
        ScrollView {
            if expenseVM.expenses.isEmpty {
                emptyState(icon: "receipt.fill", text: "Belum ada pengeluaran", sub: "Tap + untuk tambah expense pertamamu!")
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(groupedExpensesByDay.keys.sorted(by: >), id: \.self) { date in
                        VStack(alignment: .leading, spacing: 12) {
                            // Date Header
                            Text(formatDateHeader(date))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary.opacity(0.8))
                                .padding(.horizontal, 16)

                            // Expenses for this day
                            VStack(spacing: 12) {
                                ForEach(groupedExpensesByDay[date] ?? []) { expense in
                                    NavigationLink(destination: ExpenseDetailView(expense: expense, currency: trip.currency)
                                        .environmentObject(expenseVM)
                                        .environmentObject(authVM)) {
                                        ExpenseRow(expense: expense, currency: trip.currency)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Group Expenses by Day
    private var groupedExpensesByDay: [Date: [ExpenseModel]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: expenseVM.expenses) { expense in
            calendar.startOfDay(for: expense.createdAt.dateValue())
        }
        return grouped
    }

    // MARK: - Format Date Header
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "EEEE, d MMMM yyyy" // "Rabu, 25 Juli 2026"
        return formatter.string(from: date)
    }

    // MARK: - Generate Report
    private func generateReport() {
        guard let reportType = selectedReportType,
              let currentUserUID = authVM.currentUser?.uid,
              let currentUserName = authVM.currentUser?.displayName else {
            print("❌ Missing data for report generation")
            return
        }

        // Generate PDF based on report type
        let pdfURL: URL?
        let title: String

        switch reportType {
        case .tripSummary:
            pdfURL = TripReportGenerator.generateTripSummaryReport(
                trip: currentTrip,
                expenses: expenseVM.expenses
            )
            title = "Laporan Ringkasan Trip"

        case .personalExpense:
            pdfURL = TripReportGenerator.generatePersonalExpenseReport(
                trip: currentTrip,
                expenses: expenseVM.expenses,
                currentUserUID: currentUserUID,
                currentUserName: currentUserName
            )
            title = "Laporan Pengeluaran Pribadi"
        }

        if let url = pdfURL {
            reportPDFURL = url
            reportTitle = title
            showReportPreview = true
            print("✅ Report PDF generated: \(url.lastPathComponent)")
        } else {
            print("❌ Failed to generate report PDF")
        }
    }

    private func emptyState(icon: String, text: String, sub: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundColor(.textPrimary.opacity(0.2))
            Text(text).font(AppFont.headline()).foregroundColor(.textPrimary.opacity(0.6))
            Text(sub).font(AppFont.footnote()).foregroundColor(.textPrimary.opacity(0.35)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - Expense Row
struct ExpenseRow: View {
    let expense:  ExpenseModel
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: expense.category.color).opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: expense.category.icon)
                        .foregroundColor(Color(hex: expense.category.color))
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(expense.title)
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        if expense.receiptURL != nil {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.brandPrimary)
                        }
                        Text("Dibayar \(expense.paidByName)")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.45))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text(expense.amount.toCurrency(symbol: currency))
                        .font(AppFont.headline())
                        .foregroundColor(.brandPrimary)
                    
                    let unpaidCount = expense.splits.filter { $0.isPaid != true }.count
                    if unpaidCount == 0 && !expense.splits.isEmpty {
                        Text("Lunas")
                            .font(AppFont.caption2())
                            .foregroundColor(.successGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.successGreen.opacity(0.15))
                            .clipShape(Capsule())
                    } else {
                        Text("\(unpaidCount) belum bayar")
                            .font(AppFont.caption2())
                            .foregroundColor(.warningAmber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.warningAmber.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Progress Bar
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.textPrimary.opacity(0.08))
                        
                        let paidCount = expense.splits.filter { $0.isPaid == true }.count
                        let ratio = expense.splits.isEmpty ? 0 : CGFloat(paidCount) / CGFloat(expense.splits.count)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient.brandGradient)
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(height: 6)

                let paidCount = expense.splits.filter { $0.isPaid == true }.count
                Text("\(paidCount)/\(expense.splits.count)")
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.4))
                    .frame(width: 30)
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(Color.borderSoft, lineWidth: 1)
        )
    }
}

// MARK: - My Debt Row (highlighted)
struct MyDebtRow: View {
    let transaction: Transaction
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.warningAmber.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.warningAmber)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Bayar ke \(transaction.toName)")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                Text("Belum dibayar")
                    .font(AppFont.caption())
                    .foregroundColor(.warningAmber)
            }
            Spacer()
            Text(transaction.amount.toCurrency(symbol: currency))
                .font(AppFont.headline())
                .foregroundColor(.warningAmber)
        }
        .padding(14)
        .background(Color.warningAmber.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.warningAmber.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Debt Row
struct DebtRow: View {
    let transaction: Transaction
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.fromName)
                    .font(AppFont.subheadline())
                    .foregroundColor(.errorRed)
                Text("bayar ke \(transaction.toName)")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.45))
            }
            Spacer()
            Text(transaction.amount.toCurrency(symbol: currency))
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Settlement Row
struct SettlementRow: View {
    let settlement: SettlementModel

    private var statusColor: Color {
        switch settlement.status {
        case .pending:  return .warningAmber
        case .verified: return .successGreen
        case .rejected: return .errorRed
        }
    }

    private var statusLabel: String {
        switch settlement.status {
        case .pending:  return "Menunggu"
        case .verified: return "Terverifikasi"
        case .rejected: return "Ditolak"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: settlement.status == .verified ? "checkmark" : settlement.status == .rejected ? "xmark" : "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(settlement.fromName) → \(settlement.toName)")
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(settlement.amount.toCurrency(symbol: settlement.currency))
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.7))
            }

            Spacer()

            Text(statusLabel)
                .font(AppFont.caption2())
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
