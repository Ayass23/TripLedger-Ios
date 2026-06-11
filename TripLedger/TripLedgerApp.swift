//
//  TripLedgerApp.swift
//  TripLedger
//
//  Created by Andreas Margono on 14/04/26.
//

import SwiftUI
import FirebaseCore

@main
struct TripLedgerApp: App {

    // MARK: - ViewModels (root-level, injected via environment)
    @StateObject private var authVM       = AuthViewModel()
    @StateObject private var tripVM       = TripViewModel()
    @StateObject private var notifVM      = NotificationsViewModel()
    @StateObject private var splitBillVM  = SplitBillViewModel()
    @StateObject private var friendsVM    = FriendsViewModel()
    @StateObject private var network      = NetworkMonitor.shared

    init() {
        FirebaseApp.configure()
        configureTabBarAppearance()
        configureNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authVM.isCheckingSession {
                    ZStack {
                        Color.baseFallback.ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.brandPrimary)
                            Text("Memuat TripLedger...")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }
                    }
                } else if authVM.isAuthenticated {
                    MainTabView()
                } else {
                    WelcomeView()
                }
            }
            .environmentObject(authVM)
            .environmentObject(tripVM)
            .environmentObject(notifVM)
            .environmentObject(splitBillVM)
            .environmentObject(friendsVM)
            .environmentObject(network)
            .preferredColorScheme(.light)
            .animation(.easeInOut(duration: 0.35), value: authVM.isAuthenticated)
        }
    }

    // MARK: - UI Appearance
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 250/255, green: 250/255, blue: 250/255, alpha: 0.95)
        UITabBar.appearance().standardAppearance    = appearance
        UITabBar.appearance().scrollEdgeAppearance  = appearance
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 250/255, green: 250/255, blue: 250/255, alpha: 1)
        let titleColor = UIColor(red: 13/255, green: 13/255, blue: 13/255, alpha: 1)
        appearance.titleTextAttributes          = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes     = [.foregroundColor: titleColor]
        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

