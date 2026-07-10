import SwiftUI
import FirebaseFirestore
import FirebaseCore
import Kingfisher

struct HomeView: View {
    @EnvironmentObject private var authVM:   AuthViewModel
    @EnvironmentObject private var tripVM:   TripViewModel
    @EnvironmentObject private var notifVM:  NotificationsViewModel
    @EnvironmentObject private var splitBillVM: SplitBillViewModel
    @EnvironmentObject private var friendsVM: FriendsViewModel

    @State private var showCreate        = false
    @State private var tripPendingExpenses: [ExpenseModel] = []

    /// Maximum trips to show on home before "See All"
    private let maxTripsOnHome = 3

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color.baseFallback.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // MARK: Header
                        headerSection

                        // MARK: Pending Bills
                        pendingBillsSection

                        // MARK: My Trips
                        myTripsSection

                        Spacer().frame(height: 100)
                    }
                }

                // MARK: FAB
                Button { showCreate = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                        Text("Trip Baru")
                            .font(AppFont.headline())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(LinearGradient.brandGradient)
                    .clipShape(Capsule())
                    .shadow(color: Color.primaryFallback.opacity(0.4), radius: 14)
                }
                .padding(.trailing, 20)
                .padding(.vertical)

            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCreate) {
            CreateTripView()
                .environmentObject(authVM)
                .environmentObject(tripVM)
        }
        .onAppear {
            // Always refresh debt data when home page appears
            Task {
                await refreshAllDebtData()
            }
        }
        .onChange(of: tripVM.activeTrips) { _ in
            Task {
                await fetchTripPendingExpenses()
            }
        }
        .refreshable {
            // Pull to refresh - reload all debt data
            await refreshAllDebtData()
        }
    }

    // MARK: - Refresh All Debt Data
    private func refreshAllDebtData() async {
        // Refresh split bills listener if needed
        if let uid = authVM.currentUser?.uid {
            splitBillVM.listenSplitBills(uid: uid)
        }
        // Fetch trip expenses
        await fetchTripPendingExpenses()
    }

    // MARK: - Pending Bills (from split bills & expenses)
    private var allPendingItems: [PendingBillItem] {
        guard let uid = authVM.currentUser?.uid else { return [] }

        var items: [PendingBillItem] = []

        // 1. Unpaid Split Bills
        let pendingSplits = splitBillVM.activeBills.filter { bill in
            // Cek apakah user saat ini ada di daftar partisipan (berdasarkan uid ATAU id) dan belum lunas
            if let myParticipation = bill.participants.first(where: { $0.uid == uid || $0.id == uid }) {
                return !myParticipation.isPaid
            }
            return false
        }
        items.append(contentsOf: pendingSplits.map { .splitBill($0) })

        // 2. Unpaid Trip Expenses - Accumulated by Trip
        // PENTING: Exclude expenses where current user is the payer (yang menalangi tidak punya hutang)
        let pendingExpenses = tripPendingExpenses.filter { exp in
            // Skip if current user is the one who paid (they don't owe themselves)
            if exp.paidByUID == uid { return false }

            // Check if user has unpaid split in this expense
            if let mySplit = exp.splits.first(where: { $0.uid == uid || $0.id == uid }) {
                return mySplit.isPaid != true // jika nil atau false, berarti belum lunas
            }
            return false
        }

        // Group expenses by tripID
        let groupedByTrip = Dictionary(grouping: pendingExpenses) { $0.tripID }

        // Create accumulated trip debt items
        for (tripID, expenses) in groupedByTrip {
            guard let trip = tripVM.activeTrips.first(where: { $0.id == tripID }) else { continue }

            // Calculate total debt for this user in this trip
            let totalDebt = expenses.reduce(0.0) { total, expense in
                if let mySplit = expense.splits.first(where: { $0.uid == uid || $0.id == uid }) {
                    return total + mySplit.amount
                }
                return total
            }

            items.append(.tripAccumulated(
                tripID: tripID,
                tripName: trip.name,
                tripEmoji: trip.coverEmoji,
                totalDebt: totalDebt,
                currency: trip.currency,
                expenseCount: expenses.count,
                expenses: expenses
            ))
        }

        // Urutkan berdasarkan yang paling baru
        return items.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }
    }
    
    private func fetchTripPendingExpenses() async {
        guard let uid = authVM.currentUser?.uid else { return }
        let db = FirestoreService.shared.db
        
        var fetchedExpenses: [ExpenseModel] = []
        
        // Loop through active trips and fetch their expenses
        for trip in tripVM.activeTrips {
            guard let tripID = trip.id else { continue }
            do {
                let snapshot = try await db.collection(Collection.expenses)
                    .whereField("tripID", isEqualTo: tripID)
                    .getDocuments()
                
                let expenses = snapshot.documents.compactMap { try? $0.data(as: ExpenseModel.self) }
                fetchedExpenses.append(contentsOf: expenses)
            } catch {
                print("Failed to fetch expenses for trip \(tripID): \(error)")
            }
        }
        
        await MainActor.run {
            self.tripPendingExpenses = fetchedExpenses
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
//                Text("Halo, \(authVM.currentUser?.displayName.components(separatedBy: " ").first ?? "Traveler") 👋")
//                    .font(AppFont.title2())
//                    .foregroundColor(.textPrimary)
                Text("TRIP LEDGER")
                    .font(AppFont.title1())
                    .foregroundColor(.brandPrimary)
            }
            Spacer()

            // Notification Bell — NavigationLink to full page
            NavigationLink(destination: NotificationsView()
                .environmentObject(notifVM)
                .environmentObject(authVM)
                .environmentObject(tripVM)
                .environmentObject(friendsVM)
            ) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.brandPrimary)
//                        .frame(width: 44, height: 44)
//                        .background(Color.textPrimary.opacity(0.06))
//                        .clipShape(Circle())

                    // Badge
                    if notifVM.unreadCount > 0 || !tripVM.pendingInvites.isEmpty {
                        ZStack {
                            Circle()
                                .stroke(Color.baseFallback, lineWidth: 2)
                                .frame(width: 14, height: 14)
                            Circle()
                                .fill(Color.errorRed)
                                .frame(width: 10, height: 10)
                        }
                        .offset(x: -2, y: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
//        .padding(.bottom, 24)
    }
    
    // MARK: - Pending Bills Section
    private var pendingBillsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
                Text("Daftar Hutang")
                    .font(AppFont.title2())
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                if allPendingItems.isEmpty {
                    VStack(spacing: 12) {
                        Text("🧾")
                            .font(.system(size: 44))
                        Text("Tidak ada tagihan tertunda")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary.opacity(0.8))
                        Text("Semua tagihan sudah lunas\natau belum ada tagihan.")
                            .font(AppFont.footnote())
                            .foregroundColor(.textPrimary.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(allPendingItems) { item in
                                if let splitBill = item.underlyingSplitBill {
                                    NavigationLink(destination: SplitBillDetailView(bill: splitBill)
                                        .environmentObject(authVM)
                                        .environmentObject(splitBillVM)) {
                                            PendingBillCard(item: item)
                                        }
                                        .buttonStyle(.plain)
                                } else if let tripData = item.underlyingTripAccumulated {
                                    // Navigate to TripDetailView for accumulated trip debts
                                    if let trip = tripVM.activeTrips.first(where: { $0.id == tripData.tripID }) {
                                        NavigationLink(destination: TripDetailView(trip: trip)) {
                                            TripDebtCard(item: item)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                } else if let expense = item.underlyingExpense {
                                    // Find trip currency (fallback to IDR)
                                    let tripCurrency = tripVM.activeTrips.first(where: { $0.id == expense.tripID })?.currency ?? "IDR"
                                    // We need an ExpenseViewModel for the specific trip to pass to ExpenseDetailView
                                    let expVM = ExpenseViewModel()
                                    NavigationLink(destination: ExpenseDetailView(expense: expense, currency: tripCurrency)
                                        .environmentObject(expVM)
                                        .environmentObject(authVM)
                                        .onAppear { expVM.listenExpenses(tripID: expense.tripID) }) {
                                            PendingBillCard(item: item)
                                        }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 24)
    }

    // MARK: - My Trips Section
    private var myTripsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header with "See All"
            HStack {
                Text("Daftar Trip")
                    .font(AppFont.title2())
                    .foregroundColor(.textPrimary)

                Spacer()

                NavigationLink(destination: AllTripsView()) {
                    HStack(spacing: 4) {
                        Text("Lihat Semua")
                            .font(AppFont.caption())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.brandAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if allTrips.isEmpty {
                emptyTripsView
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(Array(allTrips.prefix(maxTripsOnHome))) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            TripCard(trip: trip, dimmed: trip.status == .finished)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var allTrips: [TripModel] {
        tripVM.plannedTrips + tripVM.activeTrips + tripVM.historyTrips
    }

    private var emptyTripsView: some View {
        VStack(spacing: 16) {
            Text("🏝️")
                .font(.system(size: 56))
            Text("Belum ada trip")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary.opacity(0.8))
            Text("Tap tombol \"Trip Baru\" untuk mulai\nmencatat perjalananmu!")
                .font(AppFont.footnote())
                .foregroundColor(.textPrimary.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(AppFont.title2())
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
    }
}

// MARK: - Pending Bill Card (horizontal scroll - for Split Bills)
struct PendingBillCard: View {
    let item: PendingBillItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Icon + Title
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.brandAccent.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "rectangle.split.3x1.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.brandAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Text("\(item.unpaidCount) orang belum bayar")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.45))
                }
                Spacer()
            }

            // Amount Section
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Tagihan")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.5))
                    Text(item.amount.toCurrency(symbol: item.currency))
                        .font(AppFont.title3())
                        .fontWeight(.semibold)
                        .foregroundColor(.errorRed)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary.opacity(0.25))
            }

            // Type Badge
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                Text("Split Bill")
                    .font(AppFont.caption2())
            }
            .foregroundColor(.brandAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brandAccent.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(16)
        .frame(width: 220, height: 150)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// MARK: - Trip Debt Card (for accumulated trip debts)
struct TripDebtCard: View {
    let item: PendingBillItem

    private var tripEmoji: String {
        if case .tripAccumulated(_, _, let emoji, _, _, _, _) = item {
            return emoji
        }
        return "✈️"
    }

    private var expenseCount: Int {
        if case .tripAccumulated(_, _, _, _, _, let count, _) = item {
            return count
        }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Emoji + Title
            HStack(spacing: 10) {
                Text(tripEmoji)
                    .font(.system(size: 22))
                    .frame(width: 42, height: 42)
                    .background(Color.brandPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Text("\(expenseCount) pengeluaran")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.45))
                }
                Spacer()
            }

            // Amount Section
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Hutang")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.5))
                    Text(item.amount.toCurrency(symbol: item.currency))
                        .font(AppFont.title3())
                        .fontWeight(.semibold)
                        .foregroundColor(.errorRed)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textPrimary.opacity(0.25))
            }

            // Type Badge
            HStack(spacing: 4) {
                Image(systemName: "airplane")
                    .font(.system(size: 10))
                Text("Trip")
                    .font(AppFont.caption2())
            }
            .foregroundColor(.brandPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brandPrimary.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(16)
        .frame(width: 220, height: 150)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// MARK: - Trip Card
struct TripCard: View {
    let trip:  TripModel
    var dimmed: Bool = false

    private var formattedDate: String {
        let date = trip.startDate?.dateValue() ?? trip.createdAt.dateValue()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "id_ID")
        return formatter.string(from: date)
    }

    private var statusColor: Color {
        switch trip.status {
        case .planned:  return .brandAccent
        case .active:   return .successGreen
        case .finished: return .textPrimary.opacity(0.4)
        case .deleted:  return .errorRed
        }
    }

    private var statusLabel: String {
        switch trip.status {
        case .planned:  return "Direncanakan"
        case .active:   return "Aktif"
        case .finished: return "Selesai"
        case .deleted:  return "Dihapus"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Emoji avatar
            Text(trip.coverEmoji)
                .font(.system(size: 30))
                .frame(width: 52, height: 52)
                .background(Color.textPrimary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // Trip info
            VStack(alignment: .leading, spacing: 5) {
                Text(trip.name)
                    .font(AppFont.headline())
                    .foregroundColor(dimmed ? .textPrimary.opacity(0.5) : .textPrimary)
                    .lineLimit(1)

                // Date row
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(formattedDate)
                }
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.45))

                // Members + Status row
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(trip.memberCount) anggota")
                    }
                    .font(AppFont.caption())
                    .foregroundColor(.textPrimary.opacity(0.4))

                    // Status badge
                    Text(statusLabel)
                        .font(AppFont.caption2())
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textPrimary.opacity(0.25))
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// MARK: - Avatar View (reusable) - Using Kingfisher for disk caching
struct AvatarView: View {
    let url:      String?
    let initials: String
    let size:     CGFloat

    var body: some View {
        Group {
            if let url, let imgURL = URL(string: url) {
                KFImage(imgURL)
                    .placeholder {
                        initialsView
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            )
                    }
                    .onFailure { _ in }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        ZStack {
            LinearGradient.brandGradient
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(TripViewModel())
        .environmentObject(NotificationsViewModel())
        .environmentObject(SplitBillViewModel())
        .environmentObject(FriendsViewModel())
}
