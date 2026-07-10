import SwiftUI

// MARK: - Color Palette
extension Color {
    
    // Brand
    static let brandPrimary = Color.hex("#433075")   // Deep Purple
    static let brandAccent  = Color.hex("#A58CF4")   // Lavender
    static let brandDanger  = Color.hex("#E5484D")
    
    // Surfaces
    static let surfaceBase     = Color.hex("#FAFAFA") // Soft White
    static let surfaceCard     = Color.white
    static let surfaceElevated = Color.hex("#F4F1FF")
    
    // Text
    static let textPrimary   = Color.hex("#0D0D0D") // Jet Black
    static let textSecondary = Color.hex("#0D0D0D").opacity(0.65)
    static let textTertiary  = Color.hex("#0D0D0D").opacity(0.35)
    
    // Semantic
    static let successGreen = Color.hex("#22C55E")
    static let warningAmber = Color.hex("#F59E0B")
    static let errorRed     = Color.hex("#E5484D")
    
    // Borders
    static let borderSoft   = Color.hex("#E9E2FF")
    static let borderStrong = Color.hex("#CFC2FF")
    
    // Fallbacks
    static let primaryFallback = Color.hex("#433075")
    static let accentFallback  = Color.hex("#A58CF4")
    static let cardFallback    = Color.white
    static let baseFallback    = Color.hex("#FAFAFA")

    // Extended palette — shades used by the Admin dashboard and Auth screens.
    // Values are unchanged from the previous hardcoded literals; they only
    // received names here so screens stop bypassing the theme.
    static let adminPurple        = Color.hex("#7C3AED")
    static let adminPurpleDark    = Color.hex("#5B21B6")
    static let successEmerald     = Color.hex("#10B981")
    static let successEmeraldDark = Color.hex("#059669")
    static let dangerRed          = Color.hex("#EF4444")
    static let infoBlue           = Color.hex("#3B82F6")
    static let authViolet         = Color.hex("#8E6BFF")
    static let authDeepPurple     = Color.hex("#2A1D50")
    static let authMidnight       = Color.hex("#1A1040")
}

// MARK: - Hex Support
extension Color {
    /// Delegates to the canonical `Color(hex:)` initializer in Extensions.swift.
    /// All call sites use 6-digit "#RRGGBB" constants, for which both parsers
    /// produce identical colors.
    static func hex(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

// MARK: - Typography
struct AppFont {
    static func largeTitle()  -> Font { .system(size: 34, weight: .bold, design: .rounded) }
    static func title1()      -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func title2()      -> Font { .system(size: 22, weight: .semibold, design: .rounded) }
    static func title3()      -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
    static func headline()    -> Font { .system(size: 17, weight: .semibold, design: .rounded) }
    static func body()        -> Font { .system(size: 17, weight: .regular, design: .rounded) }
    static func callout()     -> Font { .system(size: 16, weight: .regular, design: .rounded) }
    static func subheadline() -> Font { .system(size: 15, weight: .medium, design: .rounded) }
    static func footnote()    -> Font { .system(size: 13, weight: .regular, design: .rounded) }
    static func caption()     -> Font { .system(size: 12, weight: .regular, design: .rounded) }
    static func caption2()    -> Font { .system(size: 11, weight: .medium, design: .rounded) }
}

// MARK: - Spacing
struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Radius
struct AppRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let full: CGFloat = 999
}

// MARK: - Gradients
extension LinearGradient {
    
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color.brandPrimary, Color.brandAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white, Color.surfaceElevated],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.brandPrimary,
                Color.brandAccent.opacity(0.9)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Shadows
struct AppShadow {
    static let soft   = Color.brandPrimary.opacity(0.08)
    static let medium = Color.brandPrimary.opacity(0.14)
}

// MARK: - Card Modifier
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(LinearGradient.cardGradient)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppRadius.lg,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: AppRadius.lg,
                    style: .continuous
                )
                .stroke(Color.borderSoft, lineWidth: 1)
            )
            .shadow(
                color: AppShadow.soft,
                radius: 12,
                x: 0,
                y: 6
            )
    }
}

// MARK: - Glass Modifier
struct GlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AppRadius.lg,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: AppRadius.lg,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
    
    func glassStyle() -> some View {
        modifier(GlassModifier())
    }
}
