import SwiftUI
import FirebaseCore

struct TripDetailView: View {
    let trip: TripModel

    @EnvironmentObject private var authVM:    AuthViewModel
    @EnvironmentObject private var tripVM:    TripViewModel
    @StateObject private var expenseVM = ExpenseViewModel()
    @StateObject private var debtVM    = DebtViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showSettlement  = false
    @State private var showReport      = false
    @State private var showDeleteAlert = false
    @State private var showLeaveAlert  = false
    @State private var showInvite      = false
    @State private var showKickAlert   = false
    @State private var memberToKick:   TripMember?
    @State private var selectedTab     = 0
    @State private var isAddingExpense = false

    private var isOwner: Bool {
        trip.ownerUID == authVM.currentUser?.uid
    }

    private var isAdmin: Bool {
        guard let uid = authVM.currentUser?.uid else { return false }
        return trip.adminUIDs.contains(uid)
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
                    debtTab.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            // FAB — only on Expenses tab
            if selectedTab == 1 && trip.isActive {
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
                    AddExpenseMethodView(trip: trip, isAddingExpense: $isAddingExpense)
                        .environmentObject(authVM)
                        .environmentObject(expenseVM)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showReport = true } label: {
                        Label("Laporan", systemImage: "chart.bar.fill")
                    }
                    if trip.isActive {
                        Button { showSettlement = true } label: {
                            Label("Settlement", systemImage: "banknote.fill")
                        }
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
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
            }
        }
        .onAppear {
            expenseVM.listenExpenses(tripID: trip.id ?? "")
            debtVM.listenSettlements(tripID: trip.id ?? "")
        }
        .sheet(isPresented: $showSettlement) {
            SettlementView(trip: trip)
                .environmentObject(authVM)
                .environmentObject(expenseVM)
                .environmentObject(debtVM)
        }
        .sheet(isPresented: $showReport) {
            ReportView(trip: trip)
                .environmentObject(expenseVM)
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
            Text("Trip \"\(trip.name)\" akan dihapus secara permanen. Tindakan ini tidak bisa dibatalkan.")
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
            Text("Anda akan keluar dari trip \"\(trip.name)\" dan tidak bisa mengaksesnya lagi kecuali diundang kembali.")
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
    }

    // MARK: - Native Segmented Picker
    private var pickerSection: some View {
        Picker("Menu", selection: $selectedTab) {
            Text("Details").tag(0)
            Text("Expenses").tag(1)
            Text("Hutang").tag(2)
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
            }
            .padding(16)
        }
    }

    private var tripInfoCard: some View {
        VStack(spacing: 0) {
            // Top row: Emoji kiri | Nama + Status kanan
            HStack(alignment: .center, spacing: 16) {
                // Cover Emoji
                Text(trip.coverEmoji)
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
                            .fill(trip.isActive ? Color.successGreen : Color.textPrimary.opacity(0.35))
                            .frame(width: 7, height: 7)
                        Text(trip.isActive ? "Aktif" : "Selesai")
                            .font(AppFont.caption())
                            .foregroundColor(trip.isActive ? .successGreen : .textPrimary.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(trip.isActive ? Color.successGreen.opacity(0.1) : Color.textPrimary.opacity(0.06))
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

    // MARK: - Debt Tab (Pending Bills / Hutang)
    private var debtTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Recalculate button
                Button {
                    debtVM.computeDebts(expenses: expenseVM.expenses, members: trip.members, currency: trip.currency)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Hitung Ulang Hutang")
                    }
                    .font(AppFont.subheadline())
                    .foregroundColor(.brandAccent)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.brandAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if debtVM.transactions.isEmpty {
                    emptyState(icon: "checkmark.seal.fill", text: "Semua lunas! 🎉", sub: "Tidak ada hutang tersisa.")
                } else {
                    // MARK: Section 1 — My Unpaid Debts
                    let myDebts = debtVM.transactions.filter { $0.fromUID == authVM.currentUser?.uid }
                    if !myDebts.isEmpty {
                        debtSectionHeader(title: "Hutang Kamu", subtitle: "Belum dibayar", icon: "exclamationmark.triangle.fill", color: .warningAmber)

                        LazyVStack(spacing: 10) {
                            ForEach(myDebts) { tx in
                                MyDebtRow(transaction: tx, currency: trip.currency)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    // MARK: Section 2 — All Debts
                    debtSectionHeader(title: "Semua Hutang", subtitle: "Ringkasan semua anggota", icon: "list.bullet.rectangle", color: .brandPrimary)

                    LazyVStack(spacing: 10) {
                        ForEach(debtVM.transactions) { tx in
                            DebtRow(transaction: tx, currency: trip.currency)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    // MARK: - Settlements
                    if !debtVM.settlements.isEmpty {
                        debtSectionHeader(title: "Riwayat Pembayaran", subtitle: "Hutang sudah dibayar", icon: "checkmark.circle.fill", color: .successGreen)

                        LazyVStack(spacing: 10) {
                            ForEach(debtVM.settlements) { settlement in
                                SettlementRow(settlement: settlement)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private func debtSectionHeader(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(AppFont.caption2())
                    .foregroundColor(.textPrimary.opacity(0.4))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
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
