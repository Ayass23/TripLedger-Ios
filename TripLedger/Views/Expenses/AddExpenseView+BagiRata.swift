import SwiftUI
import UIKit
import FirebaseCore
import FirebaseFirestore

// MARK: - Bagi Rata Mode Views
extension AddExpenseView {
    // MARK: - Bagi Rata View
    var bagiRataView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick Actions
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    distributeEvenly()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16))
                    Text("Bagi Rata Otomatis")
                        .font(AppFont.subheadline())
                        .fontWeight(.semibold)
                }
                .foregroundColor(.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brandPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Info Text
            Text("Masukkan nominal pembagian untuk masing-masing orang. Total harus sama dengan total tagihan.")
                .font(AppFont.caption())
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 4)

            // Participants Amount List
            VStack(spacing: 12) {
                ForEach(activeParticipants) { participant in
                    bagiRataParticipantRow(participant: participant)
                }
            }

            // Total Summary
            bagiRataSummary
        }
    }

    // MARK: - Bagi Rata Participant Row
    func bagiRataParticipantRow(participant: ParticipantEntry) -> some View {
        let amountBinding = Binding<String>(
            get: { participantAmounts[participant.id] ?? "" },
            set: { participantAmounts[participant.id] = $0 }
        )
        let participantAmount = parseAmount(amountBinding.wrappedValue)
        let hasAmount = participantAmount > 0

        return HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(String(participant.name.prefix(1)).uppercased())
                    .font(AppFont.subheadline())
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.bold)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(participant.name)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)

                if hasAmount {
                    Text(participantAmount.toCurrency(symbol: trip.currency))
                        .font(AppFont.caption())
                        .foregroundColor(.brandPrimary)
                }
            }

            Spacer()

            // Amount Input
            HStack(spacing: 4) {
                Text(trip.currency)
                    .font(AppFont.caption())
                    .foregroundColor(.textSecondary)
                    .fixedSize()

                TextField("0", text: amountBinding)
                    .keyboardType(.numberPad)
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(!hasAmount ? Color.warningAmber.opacity(0.5) : Color.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Bagi Rata Summary
    var bagiRataSummary: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Total Input")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(bagiRataTotalInput.toCurrency(symbol: trip.currency))
                    .font(AppFont.headline())
                    .foregroundColor(isBagiRataMatching ? .successGreen : .errorRed)
            }

            HStack {
                Text("Total Tagihan")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(amount.toCurrency(symbol: trip.currency))
                    .font(AppFont.headline())
                    .foregroundColor(.textPrimary)
            }

            if !isBagiRataMatching {
                let difference = amount - bagiRataTotalInput
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text(difference > 0 ?
                         "Kurang \(difference.toCurrency(symbol: trip.currency))" :
                         "Lebih \(abs(difference).toCurrency(symbol: trip.currency))")
                        .font(AppFont.caption())
                }
                .foregroundColor(.errorRed)
            } else if allParticipantsHaveAmount {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Pembagian sudah sesuai!")
                        .font(AppFont.caption())
                }
                .foregroundColor(.successGreen)
            }

            if !allParticipantsHaveAmount {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill.xmark")
                        .font(.system(size: 12))
                    Text("Semua peserta harus memiliki nominal")
                        .font(AppFont.caption())
                }
                .foregroundColor(.warningAmber)
            }
        }
        .padding(16)
        .background(Color.cardFallback)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

}
