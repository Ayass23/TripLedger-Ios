import SwiftUI
import FirebaseFirestore

struct EditTripView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var tripVM: TripViewModel

    let trip: TripModel

    @State private var name: String = ""
    @State private var currency: String = ""
    @State private var emoji: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isSaving = false
    @State private var showSuccessAlert = false

    private let emojiOptions = ["🏝️","🏔️","🌆","🚢","🎡","🌴","🗺️","✈️","🏕️","🌊"]
    private let currencies   = ["IDR","USD","EUR","SGD","MYR","JPY","AUD"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.baseFallback.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // Cover emoji picker
                        emojiPickerSection

                        // Nama Trip
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nama Trip")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))

                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.brandPrimary.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.system(size: 18))
                                        .foregroundColor(.brandPrimary)
                                }

                                TextField("Nama Trip", text: $name)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                            }
                            .padding(14)
                            .background(Color.cardFallback)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(name.isEmpty ? Color.borderSoft : Color.brandPrimary.opacity(0.3), lineWidth: 1)
                            )
                        }

                        // Tanggal Liburan
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tanggal Liburan")
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary.opacity(0.6))

                            VStack(spacing: 1) {
                                // Start date row
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.successGreen.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "airplane.departure")
                                            .font(.system(size: 16))
                                            .foregroundColor(.successGreen)
                                    }

                                    Text("Berangkat")
                                        .font(AppFont.subheadline())
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    DatePicker("", selection: $startDate, in: Date()..., displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(.brandPrimary)
                                        .onChange(of: startDate) { newVal in
                                            if endDate < newVal { endDate = newVal.addingTimeInterval(86400) }
                                        }
                                }
                                .padding(14)
                                .background(Color.cardFallback)

                                Divider()
                                    .background(Color.borderSoft)

                                // End date row
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.warningAmber.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "airplane.arrival")
                                            .font(.system(size: 16))
                                            .foregroundColor(.warningAmber)
                                    }

                                    Text("Pulang")
                                        .font(AppFont.subheadline())
                                        .foregroundColor(.textPrimary)

                                    Spacer()

                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .labelsHidden()
                                        .tint(.brandPrimary)
                                }
                                .padding(14)
                                .background(Color.cardFallback)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(Color.borderSoft, lineWidth: 1)
                            )
                        }

                        // Mata Uang
                        currencyPickerSection

                        // Save button
                        Button {
                            Task { await saveChanges() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Simpan Perubahan")
                                        .font(AppFont.headline())
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(name.isBlank ? AnyShapeStyle(Color.textPrimary.opacity(0.1)) : AnyShapeStyle(LinearGradient.brandGradient))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                        }
                        .disabled(name.isBlank || isSaving)
                    }
                    .padding(20)
                }
                .dismissKeyboardOnTap()
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundColor(.textPrimary.opacity(0.7))
                }
            }
            .alert("Berhasil Diperbarui", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Informasi trip telah diperbarui.")
            }
        }
        .onAppear {
            // Initialize with current trip data
            name = trip.name
            currency = trip.currency
            emoji = trip.coverEmoji
            startDate = trip.startDate?.dateValue() ?? Date()
            endDate = trip.endDate?.dateValue() ?? Date().addingTimeInterval(86400 * 3)
        }
    }

    // MARK: - Subviews

    private var emojiPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cover Trip")
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(emojiOptions, id: \.self) { e in
                        Text(e)
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .background(emoji == e ? Color.brandPrimary.opacity(0.15) : Color.cardFallback)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(emoji == e ? Color.brandPrimary.opacity(0.5) : Color.borderSoft, lineWidth: emoji == e ? 2 : 1)
                            )
                            .shadow(color: emoji == e ? Color.brandPrimary.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 4)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    emoji = e
                                }
                            }
                    }
                }
            }
        }
    }

    private var currencyPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mata Uang")
                .font(AppFont.subheadline())
                .foregroundColor(.textPrimary.opacity(0.6))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(currencies, id: \.self) { c in
                        currencyButton(for: c)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func currencyButton(for c: String) -> some View {
        let isSelected = currency == c

        HStack(spacing: 6) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            Text(c)
                .font(AppFont.subheadline())
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .foregroundColor(isSelected ? .white : .textPrimary.opacity(0.6))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(isSelected ? AnyShapeStyle(LinearGradient.brandGradient) : AnyShapeStyle(Color.cardFallback))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.full)
                .stroke(isSelected ? Color.clear : Color.borderSoft, lineWidth: 1)
        )
        .shadow(color: isSelected ? Color.brandPrimary.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                currency = c
            }
        }
    }

    // MARK: - Save Changes

    private func saveChanges() async {
        guard let tripID = trip.id else { return }

        isSaving = true
        defer { isSaving = false }

        await tripVM.updateTrip(
            tripID: tripID,
            name: name,
            currency: currency,
            emoji: emoji,
            startDate: startDate,
            endDate: endDate
        )

        // Show success alert if no error
        if tripVM.errorMessage == nil {
            showSuccessAlert = true
        }
    }
}
