import Foundation

// MARK: - Bill Split Calculator
/// Pure money-math helpers shared by the bill/expense wizards.
/// The formulas here must not change: a 1-rupiah difference is a behavior break.
enum BillSplitCalculator {

    /// How much one participant owes based on their item selections.
    ///
    /// Per item: a custom split amount wins if present, otherwise the item's
    /// line total (price × quantity) is divided equally among its buyers.
    /// Tax, service charge, and rounding are then added — and discount
    /// subtracted — proportionally to the participant's share of the items
    /// subtotal. Callers without additional charges pass the default 0s,
    /// which leaves the item total unchanged.
    static func participantAmount(
        for participantID: String,
        items: [ItemEntry],
        taxAmount: Double = 0,
        serviceCharge: Double = 0,
        rounding: Double = 0,
        discount: Double = 0
    ) -> Double {
        var itemTotal: Double = 0

        // Calculate items
        for item in items {
            if item.selectedParticipantIDs.contains(participantID) {
                // Check if custom split exists for this item and participant
                if let customSplit = item.customSplits[participantID], !item.customSplits.isEmpty {
                    itemTotal += customSplit.customAmount
                } else {
                    // Default: equal split
                    let shareCount = item.selectedParticipantIDs.count
                    if shareCount > 0 {
                        itemTotal += (item.price * Double(item.quantity)) / Double(shareCount)
                    }
                }
            }
        }

        // Add proportional tax, service charge, rounding, and subtract proportional discount
        let itemsTotal = items.reduce(0.0) { $0 + ($1.price * Double($1.quantity)) }
        if itemsTotal > 0 {
            let proportion = itemTotal / itemsTotal
            itemTotal += (taxAmount + serviceCharge + rounding) * proportion
            itemTotal -= discount * proportion
        }

        return itemTotal
    }

    /// Parses a user-typed rupiah string ("15.000" / "15,000") into a Double.
    static func parseAmount(_ str: String) -> Double {
        let cleaned = str
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(cleaned) ?? 0
    }

    /// Splits `total` evenly across `participantIDs` as whole-rupiah strings.
    /// Every participant gets floor(total/count); the LAST participant gets the
    /// remainder so the sum always equals `total` exactly.
    static func evenDistribution(total: Double, participantIDs: [String]) -> [String: String] {
        var amounts: [String: String] = [:]
        let count = participantIDs.count
        guard count > 0 else { return amounts }
        let evenAmount = total / Double(count)
        let roundedAmount = floor(evenAmount)  // Round down to avoid exceeding total

        for (index, participantID) in participantIDs.enumerated() {
            if index == participantIDs.count - 1 {
                // Last person gets the remainder to ensure exact total
                let currentTotal = Double(participantIDs.count - 1) * roundedAmount
                let remainder = total - currentTotal
                amounts[participantID] = String(Int(remainder))
            } else {
                amounts[participantID] = String(Int(roundedAmount))
            }
        }
        return amounts
    }
}
