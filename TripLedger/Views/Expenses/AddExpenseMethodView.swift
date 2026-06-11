import SwiftUI

enum AddExpenseSource {
    case manual
    case scan
}

struct AddExpenseMethodView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var expenseVM: ExpenseViewModel
    
    let trip: TripModel
    @Binding var isAddingExpense: Bool
    
    @State private var showScanReceipt = false
    @State private var scannedResult: OCRResult?
    @State private var navigateToForm = false
    
    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Header
                Text("Pilih cara menambahkan pengeluaran baru")
                    .font(AppFont.title2())
                    .foregroundColor(.textPrimary.opacity(0.7))
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                
                // MARK: Action Buttons
                HStack(spacing: 14) {
                    // Manual Input
                    NavigationLink {
                        AddExpenseView(trip: trip, source: .manual, scannedResult: nil, isAddingExpense: $isAddingExpense)
                            .environmentObject(authVM)
                            .environmentObject(expenseVM)
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandAccent.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.brandAccent)
                            }
                            Text("Input Manual")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                            Text("Masukkan data pengeluaran")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.4))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                                .stroke(Color.borderSoft, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Scan Receipt
                    Button { showScanReceipt = true } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandPrimary.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.brandPrimary)
                            }
                            Text("Scan Struk")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                            Text("Foto & baca otomatis")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.4))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                                .stroke(Color.borderSoft, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationTitle("Tambah Pengeluaran")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showScanReceipt) {
            ReceiptScanView { result in
                scannedResult = result
                showScanReceipt = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    navigateToForm = true
                }
            }
        }
        .navigationDestination(isPresented: $navigateToForm) {
            AddExpenseView(trip: trip, source: .scan, scannedResult: scannedResult, isAddingExpense: $isAddingExpense)
                .environmentObject(authVM)
                .environmentObject(expenseVM)
        }
    }
}
