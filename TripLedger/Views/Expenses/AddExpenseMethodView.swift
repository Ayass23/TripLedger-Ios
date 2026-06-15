import SwiftUI
import UIKit

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

    // Photo Source Selection Flow
    @State private var navigateToSourcePicker = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var selectedImage: UIImage?
    @State private var navigateToProcessing = false
    @State private var scannedResult: OCRResult?
    @State private var navigateToForm = false
    
    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Header
                Text("Pilih cara menambahkan pengeluaran baru")
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top)
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
                    Button { navigateToSourcePicker = true } label: {
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
        // Navigate to PhotoSourcePickerPage first
        .navigationDestination(isPresented: $navigateToSourcePicker) {
            PhotoSourcePickerPage(
                onSelectCamera: {
                    showCamera = true
                },
                onSelectGallery: {
                    showGallery = true
                }
            )
        }
        // Camera - Full Screen
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
                .ignoresSafeArea()
                .onDisappear {
                    if selectedImage != nil {
                        navigateToProcessing = true
                    }
                }
        }
        // Gallery - Sheet (modal)
        .sheet(isPresented: $showGallery) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
                .onDisappear {
                    if selectedImage != nil {
                        navigateToProcessing = true
                    }
                }
        }
        // ReceiptProcessingPage - AI loading
        .navigationDestination(isPresented: $navigateToProcessing) {
            if let image = selectedImage {
                ReceiptProcessingPage(
                    selectedImage: image,
                    onSuccess: { result in
                        scannedResult = result
                        navigateToProcessing = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigateToForm = true
                        }
                    },
                    onError: {
                        // Go back to method selection on error
                        navigateToProcessing = false
                        selectedImage = nil
                    }
                )
            }
        }
        // CreateExpenseFromReceiptView - Final form
        .navigationDestination(isPresented: $navigateToForm) {
            CreateExpenseFromReceiptView(
                trip: trip,
                scannedResult: scannedResult,
                receiptImage: selectedImage,
                isAddingExpense: $isAddingExpense
            )
            .environmentObject(authVM)
            .environmentObject(expenseVM)
        }
    }
}
