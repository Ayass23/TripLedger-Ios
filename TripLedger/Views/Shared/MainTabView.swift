import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authVM:       AuthViewModel
    @EnvironmentObject private var tripVM:       TripViewModel
    @EnvironmentObject private var notifVM:      NotificationsViewModel
    @EnvironmentObject private var splitBillVM:  SplitBillViewModel
    @EnvironmentObject private var network:      NetworkMonitor

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Trips", systemImage: "airplane.departure") }

            SplitBillView()
                .tabItem { Label("Split", systemImage: "scissors") }

            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .overlay(alignment: .top) {
            if !network.isConnected {
                OfflineBannerView()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: network.isConnected)
            }
        }
        .tint(Color.accentFallback)
        .preferredColorScheme(.dark)
        .onAppear {
            guard let uid = authVM.currentUser?.uid else { return }
            tripVM.listenTrips(uid: uid)
            tripVM.listenInvites(uid: uid)
            notifVM.listenNotifications(uid: uid)
            splitBillVM.listenSplitBills(uid: uid)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(TripViewModel())
        .environmentObject(NotificationsViewModel())
        .environmentObject(SplitBillViewModel())
}
