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
    @StateObject private var adminVM      = AdminViewModel()
    @StateObject private var network      = NetworkMonitor.shared

    @State private var showAppealForm = false

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
                    // Check user role to show different UI
                    if authVM.currentUser?.role == .admin {
                        AdminDashboardView()
                    } else {
                        MainTabView()
                    }
                } else {
                    WelcomeView()
                }
            }
            .environmentObject(authVM)
            .environmentObject(tripVM)
            .environmentObject(notifVM)
            .environmentObject(splitBillVM)
            .environmentObject(friendsVM)
            .environmentObject(adminVM)
            .environmentObject(network)
            .preferredColorScheme(.light)
            .animation(.easeInOut(duration: 0.35), value: authVM.isAuthenticated)
            .alert("Akun Disuspend", isPresented: $authVM.showSuspendedAlert) {
                Button("Ajukan Banding") {
                    showAppealForm = true
                }
                Button("OK", role: .cancel) { }
            } message: {
                if let reason = authVM.suspendReason, !reason.isEmpty {
                    Text("Alasan: \(reason)\n\nJika kamu merasa ini adalah kesalahan, silakan ajukan banding.")
                } else {
                    Text("Akun kamu telah disuspend oleh admin.\n\nJika kamu merasa ini adalah kesalahan, silakan ajukan banding.")
                }
            }
            .sheet(isPresented: $showAppealForm) {
                if let info = authVM.suspendedUserInfo {
                    AppealFormView(
                        suspendReason: authVM.suspendReason ?? "Akun Anda telah disuspend oleh admin.",
                        userUID: info.uid,
                        userName: info.name,
                        userEmail: info.email
                    )
                    .environmentObject(authVM)
                } else {
                    PublicAppealFormView()
                }
            }
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

