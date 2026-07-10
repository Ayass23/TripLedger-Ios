import Foundation

// MARK: - Bill Item Entry
// Shared by the three bill/expense wizards:
// CreateSplitBillView, AddExpenseView, CreateExpenseFromReceiptView.
struct ItemEntry: Identifiable {
    let id = UUID()
    var name: String
    var price: Double
    var quantity: Int = 1
    var selectedParticipantIDs: Set<String> = []  // IDs of participants who bought this item
    var customSplits: [String: ParticipantSplitDetail] = [:]  // Custom split per participant
}

// MARK: - Custom split per participant (per item)
struct ParticipantSplitDetail: Identifiable, Hashable {
    let id: String
    let name: String
    var portion: Int  // Number of portions (for portion mode)
    var customAmount: Double  // Custom amount (for price mode)
}

// MARK: - Bill Split Mode (Step 3)
// "Bagi Rata" = equal split per person; "Input Manual" = item-based assignment.
enum BillSplitMode: String, CaseIterable {
    case bagiRata = "Bagi Rata"
    case inputManual = "Input Manual"
}
