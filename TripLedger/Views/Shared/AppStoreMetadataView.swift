import SwiftUI

// MARK: - App Store Metadata Form
/// Form bergaya App Store Connect untuk mengisi metadata app:
/// Promotional Text (170), Description (4000), Keywords (100)
struct AppStoreMetadataView: View {
    @Environment(\.dismiss) var dismiss

    @State private var promotionalText: String = ""
    @State private var description: String = ""
    @State private var keywords: String = ""

    @State private var showPromoHelp = false
    @State private var showDescHelp  = false
    @State private var showKwHelp    = false

    private let promoLimit = 170
    private let descLimit  = 4_000
    private let kwLimit    = 100

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {

                        // ── Promotional Text ────────────────────────────────
                        metadataTextEditorField(
                            label: "Promotional Text",
                            helpText: "Teks promosi dapat diperbarui kapan saja tanpa harus mengirim versi baru. Gunakan untuk mengumumkan promo atau acara khusus.",
                            placeholder: "Ceritakan hal baru atau menarik di versi ini...",
                            text: $promotionalText,
                            limit: promoLimit,
                            showHelp: $showPromoHelp,
                            minHeight: 100
                        )

                        dividerLine

                        // ── Description ─────────────────────────────────────
                        metadataTextEditorField(
                            label: "Description",
                            helpText: "Deskripsi aplikasi yang ditampilkan di halaman App Store. Jelaskan fitur utama dan manfaat app kamu.",
                            placeholder: "Jelaskan fitur utama aplikasimu kepada pengguna...",
                            text: $description,
                            limit: descLimit,
                            showHelp: $showDescHelp,
                            minHeight: 150
                        )

                        dividerLine

                        // ── Keywords ─────────────────────────────────────────
                        metadataKeywordsField

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .dismissKeyboardOnTap()
            }
            .navigationTitle("App Store Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { dismiss() }
                        .font(AppFont.headline())
                        .foregroundColor(.brandPrimary)
                }
            }
            .tint(.brandPrimary)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Generic TextEditor Field
    // ─────────────────────────────────────────────────────────────────────
    @ViewBuilder
    private func metadataTextEditorField(
        label: String,
        helpText: String,
        placeholder: String,
        text: Binding<String>,
        limit: Int,
        showHelp: Binding<Bool>,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            // Label row
            HStack(spacing: 6) {
                Text(label)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showHelp.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary.opacity(0.4))
                }
            }

            // Help balloon
            if showHelp.wrappedValue {
                Text(helpText)
                    .font(AppFont.footnote())
                    .foregroundColor(.textPrimary.opacity(0.65))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brandAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .stroke(Color.brandAccent.opacity(0.25), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // TextEditor box
            ZStack(alignment: .topLeading) {
                // Placeholder
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(AppFont.body())
                        .foregroundColor(.textPrimary.opacity(0.3))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(AppFont.body())
                    .foregroundColor(.textPrimary)
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
                    .onChange(of: text.wrappedValue) { newVal in
                        if newVal.count > limit {
                            text.wrappedValue = String(newVal.prefix(limit))
                        }
                    }
            }
            .padding(12)
            .background(Color.cardFallback)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(
                        text.wrappedValue.count >= limit
                            ? Color.warningAmber.opacity(0.6)
                            : Color.borderSoft,
                        lineWidth: 1
                    )
            )
            .shadow(color: AppShadow.soft, radius: 4, x: 0, y: 2)

            // Character counter
            HStack {
                Spacer()
                Text("\(text.wrappedValue.count)")
                    .foregroundColor(
                        text.wrappedValue.count >= limit
                            ? .warningAmber
                            : .textPrimary.opacity(0.35)
                    )
                +
                Text(" / \(limit)")
                    .foregroundColor(.textPrimary.opacity(0.25))
            }
            .font(AppFont.caption())
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Keywords Field
    // ─────────────────────────────────────────────────────────────────────
    private var metadataKeywordsField: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Label row
            HStack(spacing: 6) {
                Text("Keywords")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showKwHelp.toggle()
                    }
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary.opacity(0.4))
                }
            }

            // Help balloon
            if showKwHelp {
                Text("Masukkan kata kunci yang dipisahkan koma. Kata kunci membantu pengguna menemukan app-mu di App Store.")
                    .font(AppFont.footnote())
                    .foregroundColor(.textPrimary.opacity(0.65))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brandAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .stroke(Color.brandAccent.opacity(0.25), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Single-line TextField
            TextField("travel, trip, expense, split bill, ...", text: $keywords)
                .font(AppFont.body())
                .foregroundColor(.textPrimary)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .onChange(of: keywords) { newVal in
                    if newVal.count > kwLimit {
                        keywords = String(newVal.prefix(kwLimit))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(
                            keywords.count >= kwLimit
                                ? Color.warningAmber.opacity(0.6)
                                : Color.borderSoft,
                            lineWidth: 1
                        )
                )
                .shadow(color: AppShadow.soft, radius: 4, x: 0, y: 2)

            // Character counter
            HStack {
                Spacer()
                Text("\(keywords.count)")
                    .foregroundColor(
                        keywords.count >= kwLimit
                            ? .warningAmber
                            : .textPrimary.opacity(0.35)
                    )
                +
                Text(" / \(kwLimit)")
                    .foregroundColor(.textPrimary.opacity(0.25))
            }
            .font(AppFont.caption())
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────────────
    private var dividerLine: some View {
        Divider()
            .background(Color.borderSoft)
    }
}

#Preview {
    AppStoreMetadataView()
}
