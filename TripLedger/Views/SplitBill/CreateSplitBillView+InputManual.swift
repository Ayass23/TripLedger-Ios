import SwiftUI
import UIKit
import FirebaseFirestore

// MARK: - Input Manual Mode View
extension CreateSplitBillView {
    // MARK: - Input Manual View (Original Step 3)
    var inputManualView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Helper Text
            Text("Centang item yang dibeli oleh masing-masing orang")
                .font(AppFont.caption())
                .foregroundColor(.textPrimary.opacity(0.6))
                .padding(.horizontal, 4)

            // Items List
            VStack(spacing: 16) {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 12) {
                        // Item Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                // Item name with quantity prefix (always show)
                                Text("\(item.quantity)x \(item.name)")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                                // Show price breakdown clearly
                                if item.quantity > 1 {
                                    // Format: @ Rp 5,000 = Rp 15,000
                                    HStack(spacing: 4) {
                                        Text("@")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.textPrimary.opacity(0.5))
                                        Text(item.price.toCurrency(symbol: currency))
                                            .font(AppFont.caption())
                                            .foregroundColor(.brandPrimary)
                                        Text("=")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.textPrimary.opacity(0.5))
                                        Text((item.price * Double(item.quantity)).toCurrency(symbol: currency))
                                            .font(AppFont.caption())
                                            .foregroundColor(.brandPrimary)
                                            .fontWeight(.semibold)
                                    }
                                } else {
                                    // Single item: just show price
                                    Text(item.price.toCurrency(symbol: currency))
                                        .font(AppFont.caption())
                                        .foregroundColor(.brandPrimary)
                                }
                            }
                            Spacer()
                            // Edit button
                            Button {
                                showEditItem = item
                                editingItemName = item.name
                                editingItemPrice = String(Int(item.price))
                                editingItemQuantity = item.quantity
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.textPrimary.opacity(0.5))
                            }
                            // Count badge
                            if !item.selectedParticipantIDs.isEmpty {
                                Text("\(item.selectedParticipantIDs.count)")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.brandPrimary)
                                    .clipShape(Capsule())
                            }
                        }

                        // Participants Chips
                        FlowLayout(spacing: 8) {
                            ForEach(activeParticipants) { participant in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if item.selectedParticipantIDs.contains(participant.id) {
                                            item.selectedParticipantIDs.remove(participant.id)
                                            // Also remove from custom splits
                                            item.customSplits.removeValue(forKey: participant.id)
                                            print("🔴 [Step3] Removed \(participant.name) from \(item.name)")
                                        } else {
                                            item.selectedParticipantIDs.insert(participant.id)
                                            print("✅ [Step3] Added \(participant.name) to \(item.name)")
                                        }
                                        print("   Current selections for \(item.name): \(item.selectedParticipantIDs.count) people")
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: item.selectedParticipantIDs.contains(participant.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 14))
                                        Text(participant.name)
                                            .font(AppFont.caption())
                                    }
                                    .foregroundColor(item.selectedParticipantIDs.contains(participant.id) ? .white : .textPrimary.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(item.selectedParticipantIDs.contains(participant.id) ? Color.brandPrimary : Color.textPrimary.opacity(0.08))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Atur Pembagian Button (only show if more than 1 participant)
                        if item.selectedParticipantIDs.count > 1 {
                            Button {
                                showAturPembagian = item
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 14))
                                    Text("Atur Pembagian")
                                        .font(AppFont.caption())
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.brandAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.brandAccent.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.brandAccent.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(item.selectedParticipantIDs.isEmpty ? Color.errorRed.opacity(0.3) : Color.borderSoft, lineWidth: 1)
                    )
                }

                // Add Item Button
                Button {
                    showAddItem = true
                    editingItemName = ""
                    editingItemPrice = ""
                    editingItemQuantity = 1
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("Tambah Item Manual")
                            .font(AppFont.subheadline())
                    }
                    .foregroundColor(.brandAccent)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.brandAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(.brandAccent)
                    )
                }
                .buttonStyle(.plain)
            }

            // Additional charges section (editable)
            VStack(alignment: .leading, spacing: 12) {
                Text("Biaya Tambahan (Opsional)")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                VStack(spacing: 10) {
                    // Tax
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.warningAmber.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "percent")
                                .font(.system(size: 16))
                                .foregroundColor(.warningAmber)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pajak / PPN")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            TextField("0", text: $taxAmountStr)
                                .keyboardType(.decimalPad)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                        }

                        Spacer()

                        if !taxAmountStr.isEmpty {
                            Button {
                                taxAmountStr = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(taxAmountStr.isEmpty ? Color.borderSoft : Color.warningAmber.opacity(0.3), lineWidth: 1)
                    )

                    // Service Charge
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.brandAccent.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "bell.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.brandAccent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Service Charge")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            TextField("0", text: $serviceChargeStr)
                                .keyboardType(.decimalPad)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                        }

                        Spacer()

                        if !serviceChargeStr.isEmpty {
                            Button {
                                serviceChargeStr = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(serviceChargeStr.isEmpty ? Color.borderSoft : Color.brandAccent.opacity(0.3), lineWidth: 1)
                    )

                    // Discount
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.successGreen.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "tag.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.successGreen)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Diskon")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary.opacity(0.6))
                                Text("(cth: 10000)")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textPrimary.opacity(0.4))
                            }
                            TextField("0", text: $discountStr)
                                .keyboardType(.decimalPad)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                        }

                        Spacer()

                        if !discountStr.isEmpty {
                            Button {
                                discountStr = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(discountStr.isEmpty ? Color.borderSoft : Color.successGreen.opacity(0.3), lineWidth: 1)
                    )

                    // Rounding (Pembulatan)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.textSecondary.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Pembulatan")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary.opacity(0.6))
                                Text("(bisa - atau +)")
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textPrimary.opacity(0.4))
                            }
                            TextField("0", text: $roundingStr)
                                .keyboardType(.numbersAndPunctuation)
                                .font(AppFont.subheadline())
                                .foregroundColor(.textPrimary)
                        }

                        Spacer()

                        if !roundingStr.isEmpty {
                            Button {
                                roundingStr = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(roundingStr.isEmpty ? Color.borderSoft : Color.textSecondary.opacity(0.3), lineWidth: 1)
                    )
                }

                // Info text
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 Otomatis terdeteksi dari struk. Kamu bisa edit atau hapus jika salah.")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.5))
                    Text("*Dibagi proporsional sesuai item yang dibeli")
                        .font(AppFont.caption2())
                        .foregroundColor(.textPrimary.opacity(0.5))
                        .italic()
                }
            }

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("Ringkasan Pembagian")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                VStack(spacing: 8) {
                    ForEach(activeParticipants) { participant in
                        let amount = calculateParticipantAmount(participant.id)
                        if amount > 0 {
                            HStack {
                                Text(participant.name)
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Text(amount.toCurrency(symbol: currency))
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.brandPrimary)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Divider()

                    // Breakdown of calculation
                    let itemsOnlyTotal = items.reduce(0.0) { $0 + ($1.price * Double($1.quantity)) }

                    // Items subtotal
                    HStack {
                        Text("Total Items")
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                        Spacer()
                        Text(itemsOnlyTotal.toCurrency(symbol: currency))
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                    }
                    .padding(.vertical, 4)

                    // Tax (if any)
                    if taxAmount > 0 {
                        HStack {
                            Text("Pajak")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Spacer()
                            Text("+ " + taxAmount.toCurrency(symbol: currency))
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }
                        .padding(.vertical, 2)
                    }

                    // Service Charge (if any)
                    if serviceCharge > 0 {
                        HStack {
                            Text("Service Charge")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Spacer()
                            Text("+ " + serviceCharge.toCurrency(symbol: currency))
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }
                        .padding(.vertical, 2)
                    }

                    // Discount (if any)
                    if discount > 0 {
                        HStack {
                            Text("Diskon")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Spacer()
                            Text("- " + discount.toCurrency(symbol: currency))
                                .font(AppFont.caption())
                                .foregroundColor(.successGreen)
                        }
                        .padding(.vertical, 2)
                    }

                    // Rounding (if any)
                    if rounding != 0 {
                        HStack {
                            Text("Pembulatan")
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                            Spacer()
                            Text((rounding >= 0 ? "+ " : "- ") + abs(rounding).toCurrency(symbol: currency))
                                .font(AppFont.caption())
                                .foregroundColor(.textPrimary.opacity(0.6))
                        }
                        .padding(.vertical, 2)
                    }

                    // Show proportional distribution note if there are additional charges
                    if taxAmount > 0 || serviceCharge > 0 || discount > 0 || rounding != 0 {
                        Text("*Dibagi proporsional sesuai item yang dibeli")
                            .font(AppFont.caption2())
                            .foregroundColor(.textPrimary.opacity(0.5))
                            .italic()
                            .padding(.top, 4)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Total Tagihan (from step 1)
                    HStack {
                        Text("Total Tagihan")
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                        Spacer()
                        Text(totalAmount.toCurrency(symbol: currency))
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary.opacity(0.7))
                    }
                    .padding(.vertical, 4)

                    // Total Calculated (items + tax + service - discount)
                    HStack {
                        Text("Total Terhitung")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(calculatedTotal.toCurrency(symbol: currency))
                            .font(AppFont.headline())
                            .foregroundColor(isTotalMatching ? .brandPrimary : .errorRed)
                    }

                    // Warning if not matching
                    if !isTotalMatching {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("Total terhitung harus sama dengan total tagihan")
                                .font(AppFont.caption2())
                        }
                        .foregroundColor(.errorRed)
                        .padding(.top, 4)
                    }

                    // Warning if some participants don't have items
                    if !participantsWithoutItems.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill.xmark")
                                    .font(.system(size: 12))
                                Text("Peserta berikut belum punya item:")
                                    .font(AppFont.caption2())
                            }
                            .foregroundColor(.errorRed)

                            Text(participantsWithoutItems.map { $0.name }.joined(separator: ", "))
                                .font(AppFont.caption2())
                                .fontWeight(.medium)
                                .foregroundColor(.errorRed)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(12)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            }
        }
    }

}
