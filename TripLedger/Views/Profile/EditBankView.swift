import SwiftUI

struct EditBankView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject var profileVM: ProfileViewModel

    @State private var bankName = ""
    @State private var bankNum = ""
    @State private var bankAcc = ""

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Icon header
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#10B981").opacity(0.15), Color(hex: "#059669").opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)

                        Image(systemName: "banknote.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .padding(.top, 8)

                    VStack(spacing: 8) {
                        Text("Info Rekening")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)

                        Text("Informasi ini digunakan untuk penyelesaian hutang")
                            .font(AppFont.subheadline())
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    VStack(spacing: 14) {
                        TLTextField(icon: "building.columns.fill", placeholder: "Nama Bank (cth: BCA)", text: $bankName)
                        TLTextField(icon: "creditcard.fill", placeholder: "Nomor Rekening", text: $bankNum, keyboardType: .numberPad)
                        TLTextField(icon: "person.fill", placeholder: "Nama Pemilik Rekening", text: $bankAcc)
                    }

                    Button {
                        Task {
                            guard let uid = authVM.currentUser?.uid else { return }
                            await profileVM.updateBankInfo(
                                bankName: bankName,
                                accountNumber: bankNum,
                                accountName: bankAcc,
                                uid: uid
                            )
                            await authVM.refreshUser()
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if profileVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("Simpan Informasi")
                                    .font(AppFont.headline())
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(hex: "#10B981").opacity(0.3), radius: 8, y: 4)
                    }
                    .disabled(profileVM.isLoading || bankName.isBlank || bankNum.isBlank || bankAcc.isBlank)
                    .opacity((profileVM.isLoading || bankName.isBlank || bankNum.isBlank || bankAcc.isBlank) ? 0.5 : 1)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Info Rekening")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let bank = authVM.currentUser?.bankInfo
            bankName = bank?.bankName ?? ""
            bankNum = bank?.accountNumber ?? ""
            bankAcc = bank?.accountName ?? ""
        }
    }
}
