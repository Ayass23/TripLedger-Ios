import SwiftUI
import FirebaseCore

struct SplitBillView: View {
    @EnvironmentObject private var authVM:      AuthViewModel
    @EnvironmentObject private var splitBillVM: SplitBillViewModel
    @EnvironmentObject private var friendsVM:   FriendsViewModel

    @State private var showManualCreate = false
    @State private var showPhotoSourcePicker = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var showProcessingPage = false
    @State private var showScanThenCreate = false
    @State private var selectedReceiptImage: UIImage?
    @State private var scannedResult: OCRResult?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // MARK: Header
                        headerSection

                        // MARK: Action Buttons
                        actionButtons
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        // MARK: Split Bills List
                        if !splitBillVM.splitBills.isEmpty {
                            sectionHeader("Split bill List", count: splitBillVM.splitBills.count)
                            LazyVStack(spacing: 12) {
                                ForEach(splitBillVM.splitBills) { bill in
                                    NavigationLink(destination: SplitBillDetailView(bill: bill)
                                        .environmentObject(authVM)
                                        .environmentObject(splitBillVM)) {
                                        SplitBillCard(bill: bill)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        } else {
                            // MARK: Empty State
                            emptyState
                        }

                        Spacer().frame(height: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showManualCreate) {
                CreateSplitBillView(source: .manual, scannedResult: nil, receiptImage: nil)
                    .environmentObject(authVM)
                    .environmentObject(splitBillVM)
                    .environmentObject(friendsVM)
            }
            .navigationDestination(isPresented: $showPhotoSourcePicker) {
                PhotoSourcePickerPage(
                    onSelectCamera: {
                        showCamera = true
                    },
                    onSelectGallery: {
                        showGallery = true
                    }
                )
            }
            .navigationDestination(isPresented: $showProcessingPage) {
                if let image = selectedReceiptImage {
                    ReceiptProcessingPage(
                        selectedImage: image,
                        onSuccess: { result in
                            scannedResult = result
                            // Keep selectedReceiptImage for CreateSplitBillView
                            print("✅ [SplitBillView] OCR Success - selectedReceiptImage still available: \(selectedReceiptImage != nil)")
                            showProcessingPage = false
                            showScanThenCreate = true
                        },
                        onError: {
                            selectedReceiptImage = nil
                            showProcessingPage = false
                            showPhotoSourcePicker = true
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showScanThenCreate) {
                CreateSplitBillView(source: .scan, scannedResult: scannedResult, receiptImage: selectedReceiptImage)
                    .environmentObject(authVM)
                    .environmentObject(splitBillVM)
                    .environmentObject(friendsVM)
                    .onDisappear {
                        // Clear image when leaving CreateSplitBillView
                        selectedReceiptImage = nil
                    }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(selectedImage: $selectedReceiptImage, sourceType: .camera)
                .ignoresSafeArea()
                .onDisappear {
                    if selectedReceiptImage != nil {
                        showProcessingPage = true
                    }
                }
        }
        .sheet(isPresented: $showGallery) {
            ImagePicker(selectedImage: $selectedReceiptImage, sourceType: .photoLibrary)
                .onDisappear {
                    if selectedReceiptImage != nil {
                        showProcessingPage = true
                    }
                }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Split Bill")
                .font(AppFont.title1())
                .foregroundColor(.textPrimary)
            Text("Bagi tagihan dengan teman-temanmu")
                .font(AppFont.footnote())
                .foregroundColor(.textPrimary.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 14) {
            // Manual Input
            Button { showManualCreate = true } label: {
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
                    Text("Masukkan data tagihan")
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
            Button { showPhotoSourcePicker = true } label: {
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
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary.opacity(0.55))
            Spacer()
            Text("\(count)")
                .font(AppFont.caption())
                .foregroundColor(.brandAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandAccent.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("💸")
                .font(.system(size: 56))
            Text("Belum ada split bill")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary.opacity(0.8))
            Text("Mulai bagi tagihan dengan menekan\ntombol di atas!")
                .font(AppFont.footnote())
                .foregroundColor(.textPrimary.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

}

// MARK: - Split Bill Card
struct SplitBillCard: View {
    let bill: SplitBillModel
    var dimmed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row
            HStack {
                // Source icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(bill.source == .scan ? Color.brandPrimary.opacity(0.1) : Color.brandAccent.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: bill.source == .scan ? "doc.text.viewfinder" : "square.and.pencil")
                        .font(.system(size: 18))
                        .foregroundColor(bill.source == .scan ? .brandPrimary : .brandAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(bill.title)
                        .font(AppFont.headline())
                        .foregroundColor(dimmed ? .textPrimary.opacity(0.5) : .textPrimary)
                        .lineLimit(1)
                    Text(bill.createdAt.dateValue().timeAgo())
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.35))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(bill.totalAmount.toCurrency(symbol: bill.currency))
                        .font(AppFont.headline())
                        .foregroundColor(dimmed ? .textPrimary.opacity(0.4) : .brandPrimary)
                    statusBadge
                }
            }

            // Participant progress
            if !dimmed {
                HStack(spacing: 6) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.textPrimary.opacity(0.08))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient.brandGradient)
                                .frame(width: geo.size.width * progressRatio)
                        }
                    }
                    .frame(height: 6)

                    Text("\(bill.participants.filter { $0.isPaid }.count)/\(bill.participants.count)")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.4))
                        .frame(width: 30)
                }
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(dimmed ? 0.03 : 0.07), radius: 8, y: 3)
    }

    private var progressRatio: CGFloat {
        guard !bill.participants.isEmpty else { return 0 }
        return CGFloat(bill.participants.filter { $0.isPaid }.count) / CGFloat(bill.participants.count)
    }

    private var statusBadge: some View {
        Group {
            if bill.status == .settled {
                Text("Lunas")
                    .font(AppFont.caption2())
                    .foregroundColor(.successGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.successGreen.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Text("\(bill.unpaidCount) belum bayar")
                    .font(AppFont.caption2())
                    .foregroundColor(.warningAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.warningAmber.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    SplitBillView()
        .environmentObject(AuthViewModel())
        .environmentObject(SplitBillViewModel())
        .environmentObject(FriendsViewModel())
}
