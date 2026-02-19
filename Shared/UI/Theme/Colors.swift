import SwiftUI

extension Color {
    // MARK: - Primary Colors (Configurable)

    @MainActor
    static var theaPrimary: Color {
        Color(hex: AppConfiguration.shared.themeConfig.primaryColor)
    }

    @MainActor
    static var theaAccent: Color {
        Color(hex: AppConfiguration.shared.themeConfig.accentColor)
    }

    // MARK: - Secondary Colors (Configurable)

    // periphery:ignore - Reserved: theaPurple static property — reserved for future feature activation
    @MainActor
    static var theaPurple: Color {
        Color(hex: AppConfiguration.shared.themeConfig.purpleColor)
    }

    // periphery:ignore - Reserved: theaGold static property — reserved for future feature activation
    @MainActor
    static var theaGold: Color {
        Color(hex: AppConfiguration.shared.themeConfig.goldColor)
    }

    // MARK: - Static Defaults (for use in non-MainActor contexts)

    static let theaPrimaryDefault = Color(hex: "0066FF")
    static let theaAccentDefault = Color(hex: "00D4AA")
    // periphery:ignore - Reserved: theaPurple static property reserved for future feature activation
    static let theaPurpleDefault = Color(hex: "8B5CF6")
    static let theaGoldDefault = Color(hex: "FFB84D")

    // MARK: - Semantic Colors

// periphery:ignore - Reserved: theaGold static property reserved for future feature activation

    static let theaSuccess = Color.green
    static let theaWarning = Color.orange
    static let theaError = Color.red
    static let theaInfo = Color.blue

    // MARK: - Gradients

// periphery:ignore - Reserved: theaPurpleDefault static property reserved for future feature activation

// periphery:ignore - Reserved: theaGoldDefault static property reserved for future feature activation

    @MainActor
    static var theaPrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [theaPrimary, theaAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // periphery:ignore - Reserved: theaHeroGradient static property — reserved for future feature activation
    @MainActor
    static var theaHeroGradient: LinearGradient {
        LinearGradient(
            colors: [theaPurple, theaPrimary, theaAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // periphery:ignore - Reserved: theaHeroGradient static property reserved for future feature activation
    // MARK: - Static Gradients (for non-MainActor contexts)

    static let theaPrimaryGradientDefault = LinearGradient(
        colors: [theaPrimaryDefault, theaAccentDefault],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // periphery:ignore - Reserved: theaHeroGradientDefault static property — reserved for future feature activation
    static let theaHeroGradientDefault = LinearGradient(
        colors: [theaPurpleDefault, theaPrimaryDefault, theaAccentDefault],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Glass-Harmonized Colors

// periphery:ignore - Reserved: theaHeroGradientDefault static property reserved for future feature activation

    /// Subtle brand tint for Liquid Glass surfaces
    static let theaGlassTint = Color(hex: "0066FF").opacity(0.3)

    // periphery:ignore - Reserved: theaGlassAccentTint static property — reserved for future feature activation
    /// Subtle accent tint for Liquid Glass surfaces
    static let theaGlassAccentTint = Color(hex: "00D4AA").opacity(0.25)

    // periphery:ignore - Reserved: theaGlassTint static property reserved for future feature activation
    /// Platform-adaptive surface color for cards and containers
    static var theaSurface: Color {
        #if os(macOS)
        // periphery:ignore - Reserved: theaGlassAccentTint static property reserved for future feature activation
        Color(nsColor: .controlBackgroundColor)
        #elseif os(watchOS) || os(tvOS)
        Color.gray.opacity(0.15)
        #else
        Color(.secondarySystemGroupedBackground)
        #endif
    }

    // periphery:ignore - Reserved: theaSurfaceElevated static property — reserved for future feature activation
    /// Elevated surface color for nested containers
    static var theaSurfaceElevated: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #elseif os(watchOS) || os(tvOS)
        // periphery:ignore - Reserved: theaSurfaceElevated static property reserved for future feature activation
        Color.gray.opacity(0.2)
        #else
        Color(.tertiarySystemGroupedBackground)
        #endif
    }

    /// User message bubble background
    static let theaUserBubble = Color(hex: "0066FF")

    /// Assistant message bubble background
    static var theaAssistantBubble: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #elseif os(watchOS) || os(tvOS)
        Color.gray.opacity(0.2)
        #else
        Color(.secondarySystemGroupedBackground)
        #endif
    }

    // periphery:ignore - Reserved: theaGlassGradient static property — reserved for future feature activation
    /// Subtle brand gradient for glass tinting
    static let theaGlassGradient = LinearGradient(
        colors: [
            Color(hex: "0066FF").opacity(0.08),
            // periphery:ignore - Reserved: theaGlassGradient static property reserved for future feature activation
            Color(hex: "00D4AA").opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Hex Initializer

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - ShapeStyle Extension for Nonisolated Context

extension ShapeStyle where Self == Color {
    /// Primary brand color for Thea - nonisolated version using default
    static var theaPrimary: Color {
        Color.theaPrimaryDefault
    }

    // periphery:ignore - Reserved: theaAccent static property — reserved for future feature activation
    /// Accent brand color for Thea - nonisolated version using default
    static var theaAccent: Color {
        Color.theaAccentDefault
    // periphery:ignore - Reserved: theaAccent static property reserved for future feature activation
    }

    // periphery:ignore - Reserved: theaPurple static property — reserved for future feature activation
    /// Purple brand color for Thea - nonisolated version using default
    static var theaPurple: Color {
        // periphery:ignore - Reserved: theaPurple static property reserved for future feature activation
        Color.theaPurpleDefault
    }

    // periphery:ignore - Reserved: theaGold static property reserved for future feature activation
    /// Gold brand color for Thea - nonisolated version using default
    static var theaGold: Color {
        Color.theaGoldDefault
    }
}
