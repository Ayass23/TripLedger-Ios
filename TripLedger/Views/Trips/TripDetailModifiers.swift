import SwiftUI

// MARK: - AlertModifiers
struct AlertModifiers: ViewModifier {
    @Binding var showDeleteAlert: Bool
    @Binding var showLeaveAlert: Bool
    @Binding var showKickAlert: Bool
    @Binding var showFinishAlert: Bool
    @Binding var showFinishSuccess: Bool
    @Binding var memberToKick: TripMember?

    let currentTripName: String
    let finishAlertMessage: String

    let onDelete: () -> Void
    let onLeave: () -> Void
    let onKick: () -> Void
    let onFinish: () -> Void
    let onFinishSuccessOK: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Hapus Trip?", isPresented: $showDeleteAlert) {
                Button("Batal", role: .cancel) {}
                Button("Hapus", role: .destructive) { onDelete() }
            } message: {
                Text("Trip \"\(currentTripName)\" akan dihapus secara permanen. Tindakan ini tidak bisa dibatalkan.")
            }
            .alert("Keluar dari Trip?", isPresented: $showLeaveAlert) {
                Button("Batal", role: .cancel) {}
                Button("Keluar", role: .destructive) { onLeave() }
            } message: {
                Text("Anda akan keluar dari trip \"\(currentTripName)\" dan tidak bisa mengaksesnya lagi kecuali diundang kembali.")
            }
            .alert("Keluarkan Anggota?", isPresented: $showKickAlert) {
                Button("Batal", role: .cancel) { memberToKick = nil }
                Button("Keluarkan", role: .destructive) { onKick() }
            } message: {
                Text("Anggota \"\(memberToKick?.displayName ?? "")\" akan dikeluarkan dari trip ini.")
            }
            .alert("Selesaikan Trip?", isPresented: $showFinishAlert) {
                Button("Batal", role: .cancel) {}
                Button("Selesaikan") { onFinish() }
            } message: {
                Text(finishAlertMessage)
            }
            .alert("Selamat! 🎉", isPresented: $showFinishSuccess) {
                Button("OK") { onFinishSuccessOK() }
            } message: {
                Text("Trip \"\(currentTripName)\" sudah selesai. Terima kasih sudah berpetualang bersama!")
            }
    }
}

// MARK: - NavigationDestinationsModifier
struct NavigationDestinationsModifier: ViewModifier {
    @Binding var showFinancialDetail: Bool
    @Binding var showPaymentSheet: Bool
    @Binding var showVerifySheet: Bool

    let userBalances: [UserBalance]
    let currentTrip: TripModel
    let trip: TripModel
    let authVM: AuthViewModel
    let settlementVM: SettlementViewModel

    @Binding var selectedBalance: UserBalance?
    @Binding var selectedSettlement: Settlement?

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $showFinancialDetail) {
                financialDetailDestination
            }
            .navigationDestination(isPresented: $showPaymentSheet) {
                paymentDestination
            }
    }

    @ViewBuilder
    private var financialDetailDestination: some View {
        if let uid = authVM.currentUser?.uid,
           let name = authVM.currentUser?.displayName {
            FinancialDetailView(
                balances: userBalances,
                currency: currentTrip.currency,
                tripID: trip.id ?? "",
                tripName: currentTrip.name,
                currentUser: (uid, name),
                settlementVM: settlementVM,
                selectedBalance: $selectedBalance,
                showPaymentView: $showPaymentSheet
            )
        }
    }

    @ViewBuilder
    private var paymentDestination: some View {
        if let balance = selectedBalance,
           let uid = authVM.currentUser?.uid,
           let name = authVM.currentUser?.displayName {
            SettlementPaymentView(
                settlementVM: settlementVM,
                balance: balance,
                currency: currentTrip.currency,
                tripID: trip.id ?? "",
                tripName: currentTrip.name,
                currentUser: (uid, name)
            )
        }
    }
}
