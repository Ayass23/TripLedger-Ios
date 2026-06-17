import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    let pdfURL: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                PDFKitView(url: pdfURL)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Kembali")
                        }
                        .foregroundColor(.brandPrimary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.brandPrimary)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [pdfURL])
            }
        }
    }
}

// MARK: - PDFKit View Wrapper
struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}

#Preview {
    PDFPreviewView(
        pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf"),
        title: "Laporan Trip"
    )
}
