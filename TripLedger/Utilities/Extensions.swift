import SwiftUI

// MARK: - Double formatting
extension Double {
    /// Format as currency string, e.g. "Rp 150.000"
    func toCurrency(symbol: String = "Rp") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        let number = formatter.string(from: NSNumber(value: self)) ?? "0"
        return "\(symbol) \(number)"
    }

    /// Format with 2 decimal places
    var formatted2f: String {
        String(format: "%.2f", self)
    }
}

// MARK: - Date formatting
extension Date {
    func display(style: DateFormatter.Style = .medium) -> String {
        let f = DateFormatter()
        f.dateStyle = style
        f.timeStyle = .none
        f.locale = Locale(identifier: "id_ID")
        return f.string(from: self)
    }

    func timeAgo() -> String {
        let seconds = -timeIntervalSinceNow
        switch seconds {
        case ..<60:        return "Baru saja"
        case ..<3600:      return "\(Int(seconds / 60)) menit lalu"
        case ..<86400:     return "\(Int(seconds / 3600)) jam lalu"
        case ..<604800:    return "\(Int(seconds / 86400)) hari lalu"
        default:           return display()
        }
    }
}

// MARK: - String helpers
extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }
    var isValidEmail: Bool {
        NSPredicate(format: "SELF MATCHES %@",
                    "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}").evaluate(with: self)
    }
}

// MARK: - View helpers
extension View {
    /// Add a rounded border with colour
    func roundedBorder(_ color: Color, radius: CGFloat = 12, width: CGFloat = 1) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(color, lineWidth: width)
        )
    }

    /// Hide / show conditionally
    @ViewBuilder func hidden(_ condition: Bool) -> some View {
        if condition { self.hidden() } else { self }
    }

    /// Tap to dismiss keyboard
    func dismissKeyboardOnTap() -> some View {
        onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

// MARK: - Color from hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255,
                  opacity: Double(a)/255)
    }
}

// MARK: - Binding debug helper
extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}
