import SwiftUI

struct ReceiptScanView: View {
    @Environment(\.dismiss) var dismiss
    let onScanComplete: (OCRResult) -> Void

    @State private var selectedImage: UIImage?
    @State private var isScanning    = false
    @State private var scanResult:   OCRResult?
    @State private var errorMsg:     String?
    @State private var showPicker    = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                VStack(spacing: 24) {
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        // Placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.textPrimary.opacity(0.05))
                                .frame(height: 220)
                            VStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 48)).foregroundColor(.textPrimary.opacity(0.2))
                                Text("Ambil foto struk")
                                    .font(AppFont.subheadline()).foregroundColor(.textPrimary.opacity(0.4))
                            }
                        }
                    }

                    if let result = scanResult {
                        // Result preview - AI Parsed Data
                        if let parsed = result.parsedReceipt {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Hasil Scan")
                                    .font(AppFont.subheadline()).foregroundColor(.textPrimary.opacity(0.6))

                                // Bill Name
                                HStack {
                                    Image(systemName: "building.2")
                                        .foregroundColor(.textPrimary.opacity(0.5))
                                    Text(parsed.billName)
                                        .font(AppFont.body()).foregroundColor(.textPrimary)
                                    Spacer()
                                }

                                // Total Amount
                                HStack {
                                    Image(systemName: "dollarsign.circle")
                                        .foregroundColor(.successGreen)
                                    Text("Total: \(parsed.currency) \(Int(parsed.totalAmount).description)")
                                        .font(AppFont.headline()).foregroundColor(.successGreen)
                                    Spacer()
                                }

                                // Category
                                if let category = parsed.category {
                                    HStack {
                                        Image(systemName: "tag")
                                            .foregroundColor(.textPrimary.opacity(0.5))
                                        Text(category)
                                            .font(AppFont.body()).foregroundColor(.textPrimary)
                                        Spacer()
                                    }
                                }

                                // Items
                                if !parsed.items.isEmpty {
                                    Divider().background(Color.textPrimary.opacity(0.2))

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Item (\(parsed.items.count))")
                                            .font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.6))

                                        ForEach(parsed.items.prefix(5)) { item in
                                            HStack {
                                                Text("• \(item.name)")
                                                    .font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.7))
                                                Spacer()
                                                Text("\(parsed.currency) \(Int(item.price).description)")
                                                    .font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.7))
                                            }
                                        }

                                        if parsed.items.count > 5 {
                                            Text("... dan \(parsed.items.count - 5) item lainnya")
                                                .font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.5))
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.textPrimary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            // Fallback to raw OCR if AI parsing failed
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Hasil OCR")
                                        .font(AppFont.subheadline()).foregroundColor(.textPrimary.opacity(0.6))
                                    Spacer()
                                    if let amt = result.parsedAmount {
                                        Text("Total: \(Int(amt).description)")
                                            .font(AppFont.headline()).foregroundColor(.successGreen)
                                    }
                                }
                                ScrollView {
                                    Text(result.fullText)
                                        .font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.6))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 120)
                                .padding(10)
                                .background(Color.textPrimary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    if let err = errorMsg {
                        Text(err).font(AppFont.footnote()).foregroundColor(.errorRed)
                    }

                    Spacer()

                    // Buttons
                    VStack(spacing: 12) {
                        if !isScanning {
                            Button { showPicker = true } label: {
                                Label(selectedImage == nil ? "Pilih / Ambil Foto" : "Ambil Foto Lagi", systemImage: "camera.fill")
                                    .font(AppFont.headline())
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.textPrimary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                            }
                        }

                        if isScanning {
                            VStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Memproses struk dengan AI...")
                                    .font(AppFont.caption()).foregroundColor(.textPrimary.opacity(0.6))
                            }
                        }

                        if let result = scanResult {
                            Button {
                                onScanComplete(result)
                                dismiss()
                            } label: {
                                Text("Gunakan Hasil Ini")
                                    .font(AppFont.headline())
                                    .foregroundColor(.textPrimary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.successGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Scan Struk")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showPicker) {
            ImagePickerView(image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newImage in
            if newImage != nil {
                // Auto-trigger OCR + AI parsing when image is selected
                Task { await runOCR() }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func runOCR() async {
        guard let img = selectedImage else {
            print("⚠️ [ReceiptScanView] No image selected")
            return
        }

        print("🎬 [ReceiptScanView] Starting OCR process...")
        isScanning = true
        errorMsg   = nil
        scanResult = nil

        do {
            // Use the new combined OCR + AI parsing method
            let result = try await OCRService.shared.recognizeAndParseReceipt(in: img)
            scanResult = result

            if result.parsedReceipt != nil {
                print("✅ [ReceiptScanView] Scan completed with AI parsing")
            } else {
                print("⚠️ [ReceiptScanView] Scan completed but no AI parsing (OCR only)")
            }
        } catch {
            print("❌ [ReceiptScanView] Scan failed: \(error.localizedDescription)")
            errorMsg = error.localizedDescription
        }

        isScanning = false
        print("🎬 [ReceiptScanView] OCR process finished\n")
    }
}

// MARK: - Image Picker Wrapper
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerView
        init(_ p: ImagePickerView) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
