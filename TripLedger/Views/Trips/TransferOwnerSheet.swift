import SwiftUI

// MARK: - Transfer Owner Sheet
struct TransferOwnerSheet: View {
    @Binding var isPresented: Bool
    let trip: TripModel
    let suspendedMemberUIDs: Set<String>
    let onTransfer: (String, String) -> Void

    @State private var selectedMemberUID: String?
    @State private var showConfirmAlert = false

    private var eligibleMembers: [TripMember] {
        trip.members.filter { member in
            member.uid != trip.ownerUID && member.role != .pending
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header description
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.warningAmber)
                        .padding(.top, 20)

                    Text("Alihkan Kepemilikan")
                        .font(AppFont.title3())
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)

                    Text("Pilih anggota yang akan menjadi owner baru trip ini. Kamu akan tetap menjadi admin setelah mengalihkan kepemilikan.")
                        .font(AppFont.footnote())
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)

                Divider()

                // Member list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(eligibleMembers) { member in
                            let isSuspended = suspendedMemberUIDs.contains(member.uid)
                            let isDisabled = isSuspended
                            let isSelected = selectedMemberUID == member.uid

                            Button {
                                if !isDisabled {
                                    selectedMemberUID = member.uid
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack(alignment: .bottomTrailing) {
                                        AvatarView(url: member.avatarURL, initials: String(member.displayName.prefix(2)).uppercased(), size: 44)
                                            .opacity(isDisabled ? 0.4 : 1.0)

                                        if isSuspended {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(.errorRed)
                                                .background(Circle().fill(Color.cardFallback).frame(width: 16, height: 16))
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(member.displayName)
                                                .font(AppFont.subheadline())
                                                .foregroundColor(isDisabled ? .textPrimary.opacity(0.4) : .textPrimary)

                                            if member.role == .admin {
                                                Text("Admin")
                                                    .font(AppFont.caption2())
                                                    .foregroundColor(.brandPrimary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.brandPrimary.opacity(0.15))
                                                    .clipShape(Capsule())
                                            }

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

                                        Text(member.role.rawValue.capitalized)
                                            .font(AppFont.caption())
                                            .foregroundColor(.textSecondary)
                                    }

                                    Spacer()

                                    if isDisabled {
                                        Image(systemName: "nosign")
                                            .font(.system(size: 20))
                                            .foregroundColor(.textPrimary.opacity(0.2))
                                    } else {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 24))
                                            .foregroundColor(isSelected ? .brandPrimary : .textPrimary.opacity(0.2))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(isSelected ? Color.brandPrimary.opacity(0.08) : Color.clear)
                            }
                            .disabled(isDisabled)

                            Divider().padding(.leading, 78)
                        }

                        if eligibleMembers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.textPrimary.opacity(0.3))
                                Text("Tidak ada anggota yang eligible")
                                    .font(AppFont.subheadline())
                                    .foregroundColor(.textSecondary)
                                Text("Semua anggota masih pending atau ditangguhkan")
                                    .font(AppFont.caption())
                                    .foregroundColor(.textPrimary.opacity(0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                }

                // Confirm button
                VStack(spacing: 12) {
                    Button {
                        showConfirmAlert = true
                    } label: {
                        Text("Alihkan Kepemilikan")
                            .font(AppFont.headline())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedMemberUID != nil
                                    ? AnyShapeStyle(LinearGradient.brandGradient)
                                    : AnyShapeStyle(Color.textPrimary.opacity(0.2))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.full))
                    }
                    .disabled(selectedMemberUID == nil)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.baseFallback)
            }
            .background(Color.baseFallback)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        isPresented = false
                    }
                    .foregroundColor(.textPrimary.opacity(0.7))
                }
            }
            .alert("Konfirmasi Pengalihan", isPresented: $showConfirmAlert) {
                Button("Batal", role: .cancel) { }
                Button("Alihkan") {
                    if let uid = selectedMemberUID,
                       let member = eligibleMembers.first(where: { $0.uid == uid }) {
                        isPresented = false
                        onTransfer(uid, member.displayName)
                    }
                }
            } message: {
                if let uid = selectedMemberUID,
                   let member = eligibleMembers.first(where: { $0.uid == uid }) {
                    Text("Kamu yakin ingin mengalihkan kepemilikan trip \"\(trip.name)\" ke \(member.displayName)?")
                } else {
                    Text("Pilih anggota terlebih dahulu.")
                }
            }
        }
    }
}
