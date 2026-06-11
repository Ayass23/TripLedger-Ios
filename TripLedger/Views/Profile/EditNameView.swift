import SwiftUI

struct EditNameView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authVM: AuthViewModel
    @ObservedObject var profileVM: ProfileViewModel

    @State private var newName = ""

    var body: some View {
        ZStack {
            Color.baseFallback.ignoresSafeArea()

            VStack(spacing: 24) {
                // Icon header
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brandPrimary.opacity(0.15), Color.brandAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.brandPrimary, Color.brandAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("Edit Nama")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)

                    Text("Perbarui nama tampilan kamu")
                        .font(AppFont.subheadline())
                        .foregroundColor(.textSecondary)
                }

                TLTextField(icon: "person.fill", placeholder: "Nama Baru", text: $newName)

                Button {
                    Task {
                        guard let uid = authVM.currentUser?.uid else { return }
                        await profileVM.updateName(newName, uid: uid)
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
                            Text("Simpan Perubahan")
                                .font(AppFont.headline())
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.brandPrimary.opacity(0.3), radius: 8, y: 4)
                }
                .disabled(profileVM.isLoading || newName.isBlank)
                .opacity((profileVM.isLoading || newName.isBlank) ? 0.5 : 1)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .navigationTitle("Edit Nama")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .onAppear {
            newName = authVM.currentUser?.displayName ?? ""
        }
    }
}
