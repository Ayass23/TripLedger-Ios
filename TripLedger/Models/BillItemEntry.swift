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

// MARK: - Bill Split Mode (Step 3)
// "Bagi Rata" = equal split per person; "Input Manual" = item-based assignment.
enum BillSplitMode: String, CaseIterable {
    case bagiRata = "Bagi Rata"
    case inputManual = "Input Manual"
}
