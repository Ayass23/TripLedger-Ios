import SwiftUI
import FirebaseCore

struct AllTripsView: View {
    @EnvironmentObject private var tripVM: TripViewModel
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var selectedFilter: TripFilter = .all

    enum TripFilter: String, CaseIterable {
        case all      = "Semua"
        case active   = "Aktif"
        case finished = "Selesai"
    }

    private var filteredTrips: [TripModel] {
        let baseList: [TripModel]
        switch selectedFilter {
        case .all:      baseList = tripVM.activeTrips + tripVM.historyTrips
        case .active:   baseList = tripVM.activeTrips
        case .finished: baseList = tripVM.historyTrips
        }

        guard !searchText.isBlank else { return baseList }

        let query = searchText.lowercased()
        return baseList.filter { trip in
            // Search by name
            if trip.name.lowercased().contains(query) { return true }
            // Search by date (formatted)
            let dateStr = trip.createdAt.dateValue().display()
            if dateStr.lowercased().contains(query) { return true }
            return false
        }
    }

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Search Bar
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // MARK: - Filter Tabs
                filterTabs
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // MARK: - Trip List
                if filteredTrips.isEmpty {
                    emptySearchState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredTrips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip)) {
                                    TripCard(trip: trip, dimmed: trip.status == .finished)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("Semua Trip")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.textPrimary.opacity(0.35))
            TextField("Cari berdasarkan nama atau tanggal...", text: $searchText)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.textPrimary.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.textPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: 8) {
            ForEach(TripFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(AppFont.subheadline())
                        .foregroundColor(selectedFilter == filter ? .white : .textPrimary.opacity(0.55))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.brandPrimary : Color.textPrimary.opacity(0.06))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.textPrimary.opacity(0.15))
            Text(searchText.isBlank ? "Tidak ada trip" : "Tidak ditemukan")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary.opacity(0.5))
            if !searchText.isBlank {
                Text("Coba kata kunci lain")
                    .font(AppFont.footnote())
                    .foregroundColor(.textPrimary.opacity(0.35))
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        AllTripsView()
            .environmentObject(TripViewModel())
    }
}
