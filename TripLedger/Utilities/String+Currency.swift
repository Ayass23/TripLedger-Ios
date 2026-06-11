import Foundation

extension String {
    func formattedAsCurrency() -> String {
        let digits = self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let number = Double(digits) else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? ""
    }
}
