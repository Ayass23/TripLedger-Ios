import SwiftUI
import FirebaseFirestore

// MARK: - Item & Split Sheets
extension CreateExpenseFromReceiptView {
    // MARK: - Edit Item Sheet
    @ViewBuilder
    func editItemSheet(item: ItemEntry) -> some View {
        NavigationStack {
            Form {
                Section("Informasi Item") {
                    TextField("Nama Item", text: $editingItemName)
                    TextField("Harga", text: $editingItemPrice)
                        .keyboardType(.numberPad)
                    Stepper("Jumlah: \(editingItemQuantity)", value: $editingItemQuantity, in: 1...99)
                }

                Section {
                    Button("Hapus Item", role: .destructive) {
                        items.removeAll { $0.id == item.id }
                        showEditItem = nil
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showEditItem = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                            items[index].name = editingItemName.trimmed
                            items[index].price = Double(editingItemPrice.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")) ?? 0
                            items[index].quantity = editingItemQuantity
                        }
                        showEditItem = nil
                    }
                    .disabled(editingItemName.isBlank || editingItemPrice.isBlank)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Add Item Sheet
    @ViewBuilder
    func addItemSheet() -> some View {
        NavigationStack {
            Form {
                Section("Informasi Item Baru") {
                    TextField("Nama Item", text: $editingItemName)
                    TextField("Harga", text: $editingItemPrice)
                        .keyboardType(.numberPad)
                    Stepper("Jumlah: \(editingItemQuantity)", value: $editingItemQuantity, in: 1...99)
                }
            }
            .navigationTitle("Tambah Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        showAddItem = false
                        editingItemName = ""
                        editingItemPrice = ""
                        editingItemQuantity = 1
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tambah") {
                        let newItem = ItemEntry(
                            name: editingItemName.trimmed,
                            price: Double(editingItemPrice.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")) ?? 0,
                            quantity: editingItemQuantity
                        )
                        items.append(newItem)
                        showAddItem = false
                        editingItemName = ""
                        editingItemPrice = ""
                        editingItemQuantity = 1
                    }
                    .disabled(editingItemName.isBlank || editingItemPrice.isBlank)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Atur Pembagian Sheet
    @ViewBuilder
    func aturPembagianSheet(item: ItemEntry) -> some View {
        let selectedParticipants = activeParticipants.filter { item.selectedParticipantIDs.contains($0.id) }
        let participantTuples = selectedParticipants.map { (id: $0.id, name: $0.name) }

        AturPembagianView(
            itemName: item.name,
            itemPrice: item.price * Double(item.quantity),
            itemQuantity: item.quantity,
            currency: currency,
            participants: participantTuples,
            onSave: { splits in
                // Update the item's custom splits
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].customSplits = splits

                    // Remove participants with 0 portion from selectedParticipantIDs
                    for (participantId, split) in splits {
                        if split.portion == 0 {
                            items[index].selectedParticipantIDs.remove(participantId)
                            items[index].customSplits.removeValue(forKey: participantId)
                            AppLog.debug("🔴 [CreateExpenseFromReceiptView] Removed \(split.name) from \(item.name) (0 porsi)")
                        } else {
                            AppLog.debug("   👤 \(split.name): \(split.portion) porsi = \(currency) \(Int(split.customAmount))")
                        }
                    }
                    AppLog.debug("✅ [CreateExpenseFromReceiptView] Custom splits saved for \(item.name)")
                }
            }
        )
    }

}
