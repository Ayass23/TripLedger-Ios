import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct TripDetailView: View {
    let trip: TripModel

    @EnvironmentObject var authVM:    AuthViewModel
    @EnvironmentObject private var tripVM:    TripViewModel
    @StateObject var expenseVM = ExpenseViewModel()
    @StateObject private var settlementVM = SettlementViewModel()
    @Environment(\.dismiss) private var dismiss

    // Real-time trip data
    @State var currentTrip: TripModel
    @State private var tripListener: ListenerRegistration?

    @State var showReportPreview = false
    @State private var showSelectReportSheet = false
    @State var selectedReportType: ReportType?
    @State var reportPDFURL: URL?
    @State var reportTitle = ""
    @State private var showDeleteAlert = false
    @State private var showLeaveAlert  = false
    @State private var showFinishAlert = false
    @State private var showFinishSuccess = false
    @State private var showUnpaidExpensesAlert = false
    @State private var showMemberHasDebtAlert = false
    @State private var showTransferOwnerSheet = false
    @State private var showTransferSuccessAlert = false
    @State private var newOwnerName = ""
    @State private var showCannotLeaveAlert = false
    @State private var showInvite      = false
    @State private var showKickAlert   = false
    @State private var showEditTrip    = false
    @State private var memberToKick:   TripMember?
    @State private var selectedTab     = 0
    @State private var isAddingExpense = false
    @State private var suspendedMemberUIDs: Set<String> = []
    @State private var expenseSearchText = ""
    @State private var selectedCategory: ExpenseCategory? = nil

    // Settlement states
    @State private var showFinancialDetail = false
    @State private var showPaymentSheet = false
    @State private var showVerifySheet = false
    @State private var selectedBalance: UserBalance?
    @State private var selectedSettlement: Settlement?
    @State private var userBalances: [UserBalance] = []

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

    private var hasUnpaidExpenses: Bool {
        expenseVM.expenses.contains { expense in
            expense.splits.contains { $0.isPaid != true }
        }
    }

    private var unpaidExpensesCount: Int {
        expenseVM.expenses.filter { expense in
            expense.splits.contains { $0.isPaid != true }
        }.count
    }

    /// Check if a member has unpaid debts (owes money to others)
    private func memberHasDebt(_ memberUID: String) -> Bool {
        for expense in expenseVM.expenses {
            // Check if member has unpaid splits (they owe money)
            let hasUnpaidSplit = expense.splits.contains { split in
                split.uid == memberUID && split.isPaid != true
            }
            if hasUnpaidSplit { return true }
        }
        return false
    }

    /// Check if a member has unpaid receivables (others owe them money)
    private func memberHasReceivables(_ memberUID: String) -> Bool {
        for expense in expenseVM.expenses {
            // If member is the payer, check if others haven't paid
            if expense.paidByUID == memberUID {
                let hasUnpaidFromOthers = expense.splits.contains { split in
                    split.uid != memberUID && split.isPaid != true
                }
                if hasUnpaidFromOthers { return true }
            }
        }
        return false
    }

    /// Check if a member has any outstanding balance (debt or receivables)
    private func memberHasOutstandingBalance(_ memberUID: String) -> Bool {
        return memberHasDebt(memberUID) || memberHasReceivables(memberUID)
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

    // MARK: - Main Content
    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.baseFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                pickerSection

                TabView(selection: $selectedTab) {
                    detailsTab.tag(0)
                    expensesTab.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            fabButton
        }
    }

    // MARK: - FAB Button
    @ViewBuilder
    private var fabButton: some View {
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

    var body: some View {
        mainContent
            .modifier(AlertModifiers(
                showDeleteAlert: $showDeleteAlert,
                showLeaveAlert: $showLeaveAlert,
                showKickAlert: $showKickAlert,
                showFinishAlert: $showFinishAlert,
                showFinishSuccess: $showFinishSuccess,
                memberToKick: $memberToKick,
                currentTripName: currentTrip.name,
                finishAlertMessage: finishAlertMessage,
                onDelete: {
                    Task {
                        guard let tripID = trip.id, !tripID.isEmpty else { return }
                        await tripVM.deleteTrip(tripID: tripID)
                        dismiss()
                    }
                },
                onLeave: {
                    Task {
                        guard let tripID = trip.id, let uid = authVM.currentUser?.uid else { return }
                        await tripVM.leaveTrip(tripID: tripID, uid: uid)
                        dismiss()
                    }
                },
                onKick: {
                    guard let member = memberToKick, let tripID = trip.id else { return }
                    let uid = member.uid
                    let kicker = authVM.currentUser
                    Task { await tripVM.kickMember(tripID: tripID, memberUID: uid, kickedBy: kicker) }
                    memberToKick = nil
                },
                onFinish: {
                    Task {
                        guard let tripID = currentTrip.id else { return }
                        await tripVM.finishTrip(tripID: tripID, trip: currentTrip, currentUser: authVM.currentUser)
                        showFinishSuccess = true
                    }
                },
                onFinishSuccessOK: { dismiss() }
            ))
            .alert("Masih Ada Expense Belum Lunas", isPresented: $showUnpaidExpensesAlert) {
                Button("Batal", role: .cancel) {}
                Button("Tetap Selesaikan", role: .destructive) {
                    showFinishAlert = true
                }
            } message: {
                Text("Terdapat \(unpaidExpensesCount) expense yang masih memiliki pembayaran belum lunas. Apakah kamu yakin ingin menyelesaikan trip ini?")
            }
            .alert("Tidak Dapat Menghapus Anggota", isPresented: $showMemberHasDebtAlert) {
                Button("OK", role: .cancel) {
                    memberToKick = nil
                }
            } message: {
                if let member = memberToKick {
                    let hasDebt = memberHasDebt(member.uid)
                    let hasReceivables = memberHasReceivables(member.uid)
                    if hasDebt && hasReceivables {
                        Text("\(member.displayName) masih memiliki hutang dan piutang yang belum diselesaikan. Selesaikan semua transaksi terlebih dahulu.")
                    } else if hasDebt {
                        Text("\(member.displayName) masih memiliki hutang yang belum dibayar. Selesaikan pembayaran terlebih dahulu.")
                    } else {
                        Text("\(member.displayName) masih memiliki piutang yang belum diterima. Selesaikan semua transaksi terlebih dahulu.")
                    }
                } else {
                    Text("Anggota masih memiliki transaksi yang belum diselesaikan.")
                }
            }
            .modifier(NavigationDestinationsModifier(
                showFinancialDetail: $showFinancialDetail,
                showPaymentSheet: $showPaymentSheet,
                showVerifySheet: $showVerifySheet,
                userBalances: userBalances,
                currentTrip: currentTrip,
                trip: trip,
                authVM: authVM,
                settlementVM: settlementVM,
                selectedBalance: $selectedBalance,
                selectedSettlement: $selectedSettlement
            ))
            .navigationTitle("Detail Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear {
                expenseVM.listenExpenses(tripID: trip.id ?? "")
                listenToTripUpdates()
                Task { await loadSuspendedMembers() }
                if let uid = authVM.currentUser?.uid, let tripID = trip.id {
                    settlementVM.listenPendingSettlements(tripID: tripID, userUID: uid)
                }
            }
            .onChange(of: expenseVM.expenses) { _, _ in recalculateBalances() }
            .onDisappear { tripListener?.remove() }
            .fullScreenCover(isPresented: $showReportPreview) { reportPreviewContent }
            .sheet(isPresented: $showSelectReportSheet) { selectReportSheetContent }
            .sheet(isPresented: $showEditTrip) { editTripContent }
            .sheet(isPresented: $showVerifySheet) { verifySheetContent }
            .sheet(isPresented: $showTransferOwnerSheet) {
                TransferOwnerSheet(
                    isPresented: $showTransferOwnerSheet,
                    trip: currentTrip,
                    suspendedMemberUIDs: suspendedMemberUIDs,
                    onTransfer: { newOwnerUID, newOwnerDisplayName in
                        Task {
                            guard let tripID = currentTrip.id else { return }
                            await tripVM.transferOwnership(tripID: tripID, newOwnerUID: newOwnerUID)
                            newOwnerName = newOwnerDisplayName
                            showTransferSuccessAlert = true
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert("Kepemilikan Dialihkan! 🎉", isPresented: $showTransferSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("\(newOwnerName) sekarang menjadi owner trip ini. Kamu sekarang menjadi member biasa.")
            }
            .alert("Tidak Dapat Keluar Trip", isPresented: $showCannotLeaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let uid = authVM.currentUser?.uid {
                    let hasDebt = memberHasDebt(uid)
                    let hasReceivables = memberHasReceivables(uid)
                    if hasDebt && hasReceivables {
                        Text("Kamu masih memiliki hutang dan piutang yang belum diselesaikan. Selesaikan semua transaksi terlebih dahulu sebelum keluar dari trip.")
                    } else if hasDebt {
                        Text("Kamu masih memiliki hutang yang belum dibayar. Selesaikan pembayaran terlebih dahulu sebelum keluar dari trip.")
                    } else {
                        Text("Kamu masih memiliki piutang yang belum diterima. Selesaikan semua transaksi terlebih dahulu sebelum keluar dari trip.")
                    }
                } else {
                    Text("Kamu masih memiliki transaksi yang belum diselesaikan.")
                }
            }
            .tint(.brandPrimary)
    }

    // MARK: - Toolbar Content
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                if isOwner || isAdmin {
                    Button { showEditTrip = true } label: {
                        Label("Edit Trip", systemImage: "pencil")
                    }
                }
                Button {
                    showSelectReportSheet = true
                } label: {
                    Label("Laporan", systemImage: "chart.bar.fill")
                }
                if isOwner && currentTrip.members.count > 1 {
                    Button { showTransferOwnerSheet = true } label: {
                        Label("Alihkan Kepemilikan", systemImage: "crown.fill")
                    }
                }
                Divider()
                if isOwner {
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Hapus Trip", systemImage: "trash.fill")
                    }
                } else {
                    Button(role: .destructive) {
                        // Check if current user has outstanding balance before allowing leave
                        if let uid = authVM.currentUser?.uid, memberHasOutstandingBalance(uid) {
                            showCannotLeaveAlert = true
                        } else {
                            showLeaveAlert = true
                        }
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


    // MARK: - Sheet Contents
    private var editTripContent: some View {
        EditTripView(trip: currentTrip)
            .environmentObject(authVM)
            .environmentObject(tripVM)
    }

    private var selectReportSheetContent: some View {
        SelectReportTypeSheet(
            isOwner: isOwner,
            onSelectTripSummary: {
                selectedReportType = .tripSummary
                generateReport()
            },
            onSelectPersonalExpense: {
                selectedReportType = .personalExpense
                generateReport()
            }
        )
        .presentationDetents([.height(isOwner ? 350 : 250)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var verifySheetContent: some View {
        if let settlement = selectedSettlement {
            SettlementVerifySheet(
                isPresented: $showVerifySheet,
                settlementVM: settlementVM,
                expenseVM: expenseVM,
                settlement: settlement
            )
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var reportPreviewContent: some View {
        if let url = reportPDFURL {
            PDFPreviewView(pdfURL: url, title: reportTitle)
        }
    }

    // MARK: - Native Segmented Picker
    private var pickerSection: some View {
        Picker("Menu", selection: $selectedTab) {
            Text("Detail").tag(0)
            Text("Pengeluaran").tag(1)
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
    private func recalculateBalances() {
        guard let uid = authVM.currentUser?.uid else { return }
        userBalances = settlementVM.calculateBalances(
            expenses: expenseVM.expenses,
            members: currentTrip.members,
            currentUID: uid
        )
    }

    private func loadSuspendedMembers() async {
        let memberUIDs = currentTrip.memberUIDs
        guard !memberUIDs.isEmpty else { return }

        do {
            let db = FirestoreService.shared.db
            let snapshot = try await db.collection(Collection.users)
                .whereField("uid", in: memberUIDs)
                .getDocuments()

            let suspended = snapshot.documents.compactMap { doc -> String? in
                guard let user = try? doc.data(as: UserModel.self),
                      user.isSuspended else { return nil }
                return user.uid
            }

            suspendedMemberUIDs = Set(suspended)
        } catch {
            print("Error loading suspended members: \(error)")
        }
    }

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

                // Add member button (owner/admin only, for planned or active trips)
                if (isOwner || isAdmin) && (trip.status == .planned || trip.status == .active) {
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

            ForEach(currentTrip.members) { member in
                let isSuspended = suspendedMemberUIDs.contains(member.uid)
                HStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(url: member.avatarURL, initials: String(member.displayName.prefix(2)).uppercased(), size: 42)
                            .opacity(isSuspended ? 0.5 : 1.0)

                        if isSuspended {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.errorRed)
                                .background(Circle().fill(Color.cardFallback).frame(width: 16, height: 16))
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(member.displayName)
                                .font(AppFont.subheadline())
                                .foregroundColor(isSuspended ? .textPrimary.opacity(0.5) : .textPrimary)
                            if member.uid == authVM.currentUser?.uid {
                                Text("Kamu")
                                    .font(AppFont.caption2())
                                    .foregroundColor(Color.accentFallback)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.accentFallback.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            if isSuspended {
                                Text("Ditangguhkan")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.errorRed)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.errorRed.opacity(0.15))
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
                    if isOwner && member.uid != authVM.currentUser?.uid && currentTrip.isActive {
                        Button {
                            memberToKick = member
                            // Check if member has outstanding balance before allowing kick
                            if memberHasOutstandingBalance(member.uid) {
                                showMemberHasDebtAlert = true
                            } else {
                                showKickAlert = true
                            }
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
            if hasUnpaidExpenses {
                showUnpaidExpensesAlert = true
            } else {
                showFinishAlert = true
            }
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

    // MARK: - Financial Summary Card View
    @ViewBuilder
    private var financialSummaryCardView: some View {
        FinancialSummaryCard(
            balances: userBalances,
            pendingSettlements: settlementVM.pendingSettlements,
            myPendingSettlements: settlementVM.myPendingSettlements,
            currency: currentTrip.currency,
            onShowDetail: { showFinancialDetail = true },
            onVerifySettlement: { settlement in
                selectedSettlement = settlement
                showVerifySheet = true
            }
        )
    }

    // MARK: - Expenses Tab
    private var expensesTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Financial Summary Card
                financialSummaryCardView

                if expenseVM.expenses.isEmpty {
                    emptyState(icon: "receipt.fill", text: "Belum ada pengeluaran", sub: "Tap + untuk tambah expense pertamamu!")
                } else {
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.textPrimary.opacity(0.4))

                        TextField("Cari pengeluaran...", text: $expenseSearchText)
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)

                        if !expenseSearchText.isEmpty {
                            Button {
                                expenseSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textPrimary.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.borderSoft, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Category Filter Pills
                    if !availableCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // "Semua" pill
                                Button {
                                    selectedCategory = nil
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.grid.2x2")
                                            .font(.system(size: 12))
                                        Text("Semua")
                                            .font(AppFont.caption())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == nil ? Color.brandPrimary : Color.cardFallback)
                                    .foregroundColor(selectedCategory == nil ? .white : .textPrimary.opacity(0.7))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedCategory == nil ? Color.clear : Color.borderSoft, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)

                                // Category pills
                                ForEach(availableCategories, id: \.self) { category in
                                    let isSelected = selectedCategory == category
                                    let categoryColor = Color(hex: category.color)

                                    Button {
                                        if selectedCategory == category {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = category
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: category.icon)
                                                .font(.system(size: 12))
                                            Text(category.displayName)
                                                .font(AppFont.caption())
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? categoryColor : Color.cardFallback)
                                        .foregroundColor(isSelected ? .white : .textPrimary.opacity(0.7))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.clear : Color.borderSoft, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 8)
                        .padding(.top, 8)
                    }

                    if filteredExpenses.isEmpty {
                        // No search results
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(.textPrimary.opacity(0.2))
                            Text("Tidak ada hasil")
                                .font(AppFont.headline())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Text("Coba kata kunci lain")
                                .font(AppFont.footnote())
                                .foregroundColor(.textPrimary.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
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
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Filtered Expenses
    private var filteredExpenses: [ExpenseModel] {
        var results = expenseVM.expenses

        // Filter by search text
        if !expenseSearchText.isEmpty {
            results = results.filter { expense in
                expense.title.localizedCaseInsensitiveContains(expenseSearchText)
            }
        }

        // Filter by category
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        return results
    }

    // MARK: - Available Categories (only show categories that have expenses)
    private var availableCategories: [ExpenseCategory] {
        let usedCategories = Set(expenseVM.expenses.map { $0.category })
        return ExpenseCategory.allCases.filter { usedCategories.contains($0) }
    }

    // MARK: - Group Expenses by Day
    private var groupedExpensesByDay: [Date: [ExpenseModel]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { expense in
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
