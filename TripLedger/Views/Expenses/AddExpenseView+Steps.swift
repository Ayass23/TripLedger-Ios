import SwiftUI
import UIKit
import FirebaseCore
import FirebaseFirestore

// MARK: - Wizard Steps (1-3) & Bottom Nav
extension AddExpenseView {
    // MARK: - Step 1: Info Dasar
    var step1View: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Receipt Image
            VStack(alignment: .leading, spacing: 10) {
                Text("Foto Struk (Opsional)")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                if let image = selectedImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .contentShape(Rectangle())
                            .onTapGesture { showPhotoSourcePicker = true }

                        Button {
                            selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        .padding(8)
                    }
                } else {
                    Button { showPhotoSourcePicker = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                            Text("Pilih Foto Struk")
                                .font(AppFont.subheadline())
                        }
                        .foregroundColor(Color.accentFallback)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentFallback.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(Color.accentFallback.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                }
            }

            // Nama Pengeluaran
            VStack(alignment: .leading, spacing: 10) {
                Text("Nama Pengeluaran")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "tag.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.brandPrimary)
                    }

                    TextField("Cth: Makan Siang Bersama", text: $title)
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary)
                }
                .padding(14)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(title.isEmpty ? Color.borderSoft : Color.brandPrimary.opacity(0.3), lineWidth: 1)
                )
            }

            // Jumlah
            VStack(alignment: .leading, spacing: 10) {
                Text("Jumlah (\(trip.currency))")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.successGreen.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.successGreen)
                    }

                    TextField("0", text: $amountStr)
                        .keyboardType(.decimalPad)
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                }
                .padding(14)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(amountStr.isEmpty ? Color.borderSoft : Color.successGreen.opacity(0.3), lineWidth: 1)
                )
            }

            // Tanggal Transaksi
            VStack(alignment: .leading, spacing: 10) {
                Text("Tanggal Transaksi")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                Button {
                    showDatePicker = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.warningAmber.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "calendar")
                                .font(.system(size: 18))
                                .foregroundColor(.warningAmber)
                        }

                        Text(formatTransactionDate(transactionDate))
                            .font(AppFont.subheadline())
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.textPrimary.opacity(0.3))
                    }
                    .padding(14)
                    .background(Color.cardFallback)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(Color.warningAmber.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Kategori
            VStack(alignment: .leading, spacing: 10) {
                Text("Kategori")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 10) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        Button {
                            category = cat
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: cat.color))
                                Text(cat.displayName)
                                    .font(AppFont.caption2())
                                    .foregroundColor(.textPrimary.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(category == cat ? Color(hex: cat.color).opacity(0.2) : Color.textPrimary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(category == cat ? Color(hex: cat.color) : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Catatan
            VStack(alignment: .leading, spacing: 10) {
                Text("Catatan (opsional)")
                    .font(AppFont.subheadline())
                    .foregroundColor(.textPrimary.opacity(0.6))

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.warningAmber.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "note.text")
                            .font(.system(size: 18))
                            .foregroundColor(.warningAmber)
                    }

                    TextField("Tambahkan catatan...", text: $notes)
                        .font(AppFont.subheadline())
                        .foregroundColor(.textPrimary)
                }
                .padding(14)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(Color.borderSoft, lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Step 2: Pilih Anggota
    var step2View: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Siapa yang ikut patungan?")
                .font(AppFont.headline())
                .foregroundColor(.textPrimary)

            VStack(spacing: 12) {
                ForEach($participants) { $participant in
                    let isSuspended = suspendedMemberUIDs.contains(participant.uid)

                    Button {
                        if !isSuspended {
                            participant.isSelected.toggle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isSuspended {
                                Image(systemName: "nosign")
                                    .foregroundColor(.errorRed.opacity(0.5))
                                    .font(.system(size: 22))
                            } else {
                                Image(systemName: participant.isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundColor(participant.isSelected ? .brandPrimary : .textPrimary.opacity(0.3))
                                    .font(.system(size: 22))
                            }

                            ZStack {
                                Circle()
                                    .fill(isSuspended ? Color.errorRed.opacity(0.12) : Color.brandAccent.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Text(String(participant.name.prefix(1)).uppercased())
                                    .font(AppFont.caption())
                                    .foregroundColor(isSuspended ? .errorRed : .brandAccent)
                            }
                            .opacity(isSuspended ? 0.5 : 1.0)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(participant.name)
                                        .font(AppFont.subheadline())
                                        .foregroundColor(isSuspended ? .textPrimary.opacity(0.5) : .textPrimary)

                                    if isSuspended {
                                        Text("Ditangguhkan")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.errorRed)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.errorRed.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                }
                                if participant.uid == authVM.currentUser?.uid {
                                    Text("Kamu")
                                        .font(AppFont.caption2())
                                        .foregroundColor(.textPrimary.opacity(0.5))
                                }
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(Color.cardFallback)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(isSuspended ? Color.errorRed.opacity(0.3) : (participant.isSelected ? Color.brandPrimary : Color.borderSoft), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSuspended)
                }
            }

            // Payer Selection Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💳 Siapa yang bayar dulu?")
                            .font(AppFont.headline())
                            .foregroundColor(.textPrimary)
                        Text("Orang ini yang harus dibayar balik")
                            .font(AppFont.caption())
                            .foregroundColor(.textPrimary.opacity(0.6))
                    }
                    Spacer()
                }

                VStack(spacing: 12) {
                    // Only show non-suspended selected participants as potential payers
                    ForEach(participants.filter { $0.isSelected && !suspendedMemberUIDs.contains($0.uid) }) { participant in
                        Button {
                            paidByParticipant = participant
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: paidByParticipant?.id == participant.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(paidByParticipant?.id == participant.id ? .brandPrimary : .textPrimary.opacity(0.3))
                                    .font(.system(size: 22))

                                ZStack {
                                    Circle()
                                        .fill(Color.brandAccent.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Text(String(participant.name.prefix(1)).uppercased())
                                        .font(AppFont.caption())
                                        .foregroundColor(.brandAccent)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participant.name)
                                        .font(AppFont.subheadline())
                                        .foregroundColor(.textPrimary)
                                    if participant.uid == authVM.currentUser?.uid {
                                        Text("Kamu")
                                            .font(AppFont.caption2())
                                            .foregroundColor(.textPrimary.opacity(0.5))
                                    }
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(Color.cardFallback)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.md)
                                    .stroke(paidByParticipant?.id == participant.id ? Color.brandPrimary : Color.borderSoft, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Step 3: Siapa Beli Apa
    var step3View: some View {
        VStack(alignment: .leading, spacing: 20) {
            // If source is scan, go directly to input manual (item-based)
            if source == .scan {
                // Header for scan
                VStack(alignment: .leading, spacing: 8) {
                    Text("Siapa aja yang beli apa?")
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                    Text("Centang item yang dibeli oleh masing-masing orang")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.6))
                }

                inputManualView
            } else {
                // Header for manual
                VStack(alignment: .leading, spacing: 8) {
                    Text("Atur Pembagian")
                        .font(AppFont.headline())
                        .foregroundColor(.textPrimary)
                    Text("Pilih metode pembagian tagihan")
                        .font(AppFont.caption())
                        .foregroundColor(.textPrimary.opacity(0.6))
                }

                // Split Mode Selector (only for manual source)
                HStack(spacing: 0) {
                    ForEach(BillSplitMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                splitMode = mode
                                if mode == .bagiRata {
                                    initializeParticipantAmounts()
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode == .bagiRata ? "equal.circle.fill" : "list.bullet.clipboard.fill")
                                    .font(.system(size: 14))
                                Text(mode.rawValue)
                                    .font(AppFont.subheadline())
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(splitMode == mode ? .white : .textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(splitMode == mode ? Color.brandPrimary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        }
                    }
                }
                .padding(4)
                .background(Color.cardFallback)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(Color.borderSoft, lineWidth: 1)
                )

                // Content based on mode
                if splitMode == .bagiRata {
                    bagiRataView
                } else {
                    inputManualView
                }
            }
        }
        .onAppear {
            if source == .manual {
                initializeParticipantAmounts()
            }
        }
    }

    // MARK: - Bottom Nav View
    var bottomNavView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if step > 1 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Text("Kembali")
                            .font(AppFont.headline())
                            .foregroundColor(.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.brandPrimary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                }
                
                if step < 3 {
                    Button {
                        handleNextStep()
                    } label: {
                        Text("Selanjutnya")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background((step == 1 ? isStep1Valid : isStep2Valid) ? LinearGradient.brandGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                    .disabled(step == 1 ? !isStep1Valid : !isStep2Valid)
                } else {
                    // For scan source, always use item-based validation
                    // For manual source, check split mode
                    let isValid = source == .scan ? isStep3Valid : (splitMode == .bagiRata ? isStep3ValidBagiRata : isStep3Valid)
                    Button {
                        if isTripEnded {
                            showPostTripAlert = true
                        } else {
                            Task { await saveExpense() }
                        }
                    } label: {
                        Text(expenseVM.isLoading ? "Menyimpan..." : "Simpan Pengeluaran")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValid ? LinearGradient.brandGradient : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                    .disabled(!isValid || expenseVM.isLoading)
                    .alert("Pengeluaran Setelah Trip", isPresented: $showPostTripAlert) {
                        Button("Batal", role: .cancel) {}
                        Button("Tetap Simpan") {
                            Task { await saveExpense() }
                        }
                    } message: {
                        Text("Pengeluaran ini dibuat setelah tanggal akhir trip. Apakah kamu yakin ingin menyimpannya?")
                    }
                }
            }
            .padding(20)
            .background(Color.baseFallback)
        }
    }

}
