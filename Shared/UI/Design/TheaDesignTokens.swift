// TheaDesignTokens.swift
// Thea V2 - Design Tokens
//
// Brand colors, spacing, radius, size, shadow, animation, and theme tokens
// extracted from TheaDesignSystem.swift
//
// Created: February 3, 2026
// Updated: February 4, 2026 - Brand colors extracted from icon

import SwiftUI

// MARK: - Brand Colors (Extracted from THEA Icon)

/// THEA's brand palette - the golden spiral identity
public enum TheaBrandColors {
    // MARK: - Primary (The Golden Spiral)

    /// Primary gold - heart of the spiral
    public static let gold = Color(hex: "F5A623")

    /// Deep amber - outer spiral
    public static let amber = Color(hex: "FF8C00")

    /// Warm orange - energy accent
    public static let warmOrange = Color(hex: "FF7518")

    /// Light gold - highlights
    public static let lightGold = Color(hex: "FFD93D")

    /// Core glow - intelligent center
    public static let coreGlow = Color(hex: "FFFAEB")

    // MARK: - Background (The Deep Canvas)

    /// Deep navy - primary dark bg
    public static let deepNavy = Color(hex: "1A1A2E")

    /// Charcoal blue - secondary dark bg
    public static let charcoalBlue = Color(hex: "16213E")

    /// Midnight - darkest
    public static let midnight = Color(hex: "0F0F1A")

    /// Soft dark - elevated surfaces
    public static let softDark = Color(hex: "232340")

    // MARK: - Light Mode

    /// Warm white - primary light bg
    public static let warmWhite = Color(hex: "FEFDFB")

    /// Cream - secondary light bg
    public static let cream = Color(hex: "FFF9F0")

    // MARK: - Semantic

    public static let success = Color(hex: "4CAF50")
    public static let warning = Color(hex: "FFC107")
    public static let error = Color(hex: "E57373")
    public static let info = Color(hex: "64B5F6")

    // MARK: - Gradients

    /// The signature THEA spiral gradient
    public static let spiralGradient = LinearGradient(
        colors: [lightGold, gold, amber, warmOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Thinking/pulsing gradient
    public static let thinkingGradient = LinearGradient(
        colors: [gold.opacity(0.8), amber, gold.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Core glow radial gradient
    public static let coreGlowGradient = RadialGradient(
        colors: [coreGlow, gold.opacity(0.6), gold.opacity(0)],
        center: .center,
        startRadius: 0,
        endRadius: 50
    )

    /// Background gradient
    public static let backgroundGradient = LinearGradient(
        colors: [deepNavy, charcoalBlue, midnight],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Adaptive Helpers

    public static func adaptiveBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? deepNavy : warmWhite
    }

    public static func adaptiveSurface(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? softDark : cream
    }

    public static func adaptiveText(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : Color(hex: "2D2D3A")
    }
}

// MARK: - Design Tokens

/// Core spacing values
public enum TheaSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
    public static let jumbo: CGFloat = 48
}

/// Core corner radii
public enum TheaRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 28
    public static let pill: CGFloat = 999
}

/// Corner radius tokens (alias used by DesignTokens consumers on macOS)
public enum TheaCornerRadius {
    public static let sm: CGFloat = TheaRadius.sm
    public static let md: CGFloat = TheaRadius.md
    public static let lg: CGFloat = TheaRadius.lg
    public static let xl: CGFloat = TheaRadius.xl
    public static let card: CGFloat = 24
    public static let capsule: CGFloat = .infinity

    public static func concentric(outer: CGFloat, padding: CGFloat) -> CGFloat {
        max(0, outer - padding)
    }
}

/// Size tokens for consistent component dimensions
public enum TheaSize {
    public static let minTouchTarget: CGFloat = 44
    public static let buttonHeight: CGFloat = 48
    public static let capsuleButtonHeight: CGFloat = 56
    public static let inputFieldMinHeight: CGFloat = 44
    public static let inputFieldMaxHeight: CGFloat = 200
    public static let sidebarMinWidth: CGFloat = 240
    public static let sidebarIdealWidth: CGFloat = 280
    public static let messageMaxWidth: CGFloat = 680
    public static let messageAvatarSize: CGFloat = 28
    public static let iconSmall: CGFloat = 16
    public static let iconMedium: CGFloat = 20
    public static let iconLarge: CGFloat = 24
    public static let iconXLarge: CGFloat = 32
    public static let tvMessageMaxWidth: CGFloat = 1000
    public static let tvMinTouchTarget: CGFloat = 66
}

/// Shadow definitions for layered depth
public enum TheaShadow {
    /// Subtle elevation for cards
    public static let subtle = Shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    /// Medium elevation for floating elements
    public static let medium = Shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    /// Strong elevation for modals and popovers
    public static let strong = Shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
    /// Glow effect for interactive elements
    public static let glow = Shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 0)

    /// Design token representing a shadow with color, blur radius, and offset.
    public struct Shadow: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }
}

/// Animation curves for smarter motion
public enum TheaAnimation {
    /// Quick micro-interaction (hover, tap feedback)
    public static let micro = Animation.easeOut(duration: 0.1)
    /// Standard interaction response
    public static let standard = Animation.easeInOut(duration: 0.2)
    /// Smooth content transitions
    public static let smooth = Animation.easeInOut(duration: 0.35)
    /// Elegant entrance animations
    public static let entrance = Animation.spring(response: 0.4, dampingFraction: 0.8)
    /// Bouncy feedback for success states
    public static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)

    // MARK: - Extended Presets

    /// Natural spring for general UI transitions
    public static let spring = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// Gentle spring for subtle movements
    public static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    /// Snappy animation for quick state changes
    public static let snappy = Animation.snappy(duration: 0.25)
    /// Morphing animation for shape/layout transitions
    public static let morphing = Animation.smooth(duration: 0.4)
    /// Message appear animation
    public static let messageAppear = Animation.spring(response: 0.4, dampingFraction: 0.75)
    /// Tab switch transition
    public static let tabSwitch = Animation.easeInOut(duration: 0.25)

    /// Staggered animation for lists and grids
    public static func staggered(index: Int, baseDelay: Double = 0.05) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
            .delay(Double(index) * baseDelay)
    }
}

// MARK: - Adaptive Theme

/// Adaptive theme that changes based on context
public struct AdaptiveTheme: Equatable {
    public let mode: ThemeMode
    public let accentVariant: AccentVariant
    public let intensity: Intensity

    /// Available theme modes including a midnight option for extra-dark late-night use.
    public enum ThemeMode: String, CaseIterable {
        case system
        case light
        case dark
        case midnight  // Extra dark for late night
    }

    /// Accent color variant options defining the app's gradient palette.
    public enum AccentVariant: String, CaseIterable {
        case ocean      // Blue-cyan gradient (default)
        case aurora     // Purple-green gradient
        case sunset     // Orange-pink gradient
        case forest     // Green-teal gradient
        case monochrome // Grayscale with subtle accent
    }

    /// Visual intensity level controlling how rich or muted UI colors appear.
    public enum Intensity: String, CaseIterable {
        case subtle     // Minimal color, focus on content
        case balanced   // Default balanced approach
        case vibrant    // Rich, expressive colors
    }

    public init(
        mode: ThemeMode = .system,
        accentVariant: AccentVariant = .ocean,
        intensity: Intensity = .balanced
    ) {
        self.mode = mode
        self.accentVariant = accentVariant
        self.intensity = intensity
    }

    /// Primary accent color based on variant
    public var primaryAccent: Color {
        switch accentVariant {
        case .ocean: return Color(hex: "0066FF")
        case .aurora: return Color(hex: "8B5CF6")
        case .sunset: return Color(hex: "F97316")
        case .forest: return Color(hex: "10B981")
        case .monochrome: return Color(hex: "6B7280")
        }
    }

    /// Secondary accent color for gradients
    public var secondaryAccent: Color {
        switch accentVariant {
        case .ocean: return Color(hex: "00D4AA")
        case .aurora: return Color(hex: "10B981")
        case .sunset: return Color(hex: "EC4899")
        case .forest: return Color(hex: "14B8A6")
        case .monochrome: return Color(hex: "9CA3AF")
        }
    }

    /// Hero gradient for key visual elements
    public var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primaryAccent, secondaryAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Opacity multiplier based on intensity
    public var opacityMultiplier: Double {
        switch intensity {
        case .subtle: return 0.6
        case .balanced: return 1.0
        case .vibrant: return 1.2
        }
    }
}

// MARK: - Dynamic Response Blocks

/// Block types for AI responses (beyond pure chat)
public enum ResponseBlockType: String, CaseIterable, Identifiable {
    case text
    case code
    case thinking       // Extended thinking process
    case dataTable      // Structured data display
    case actionButtons  // Quick action suggestions
    case progressCard   // Task progress indicator
    case imageGallery   // Generated or referenced images
    case citation       // Source citation with preview
    case formInput      // Interactive form for clarification
    case chart          // Data visualization
    case timeline       // Step-by-step process
    case comparison     // Side-by-side comparison
    case summary        // Collapsible summary card
    case warning        // Important notice
    case success        // Completion confirmation

    public var id: String { rawValue }

    /// Icon for the block type
    public var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .thinking: return "brain"
        case .dataTable: return "tablecells"
        case .actionButtons: return "hand.tap"
        case .progressCard: return "chart.bar.fill"
        case .imageGallery: return "photo.on.rectangle"
        case .citation: return "quote.opening"
        case .formInput: return "rectangle.and.pencil.and.ellipsis"
        case .chart: return "chart.xyaxis.line"
        case .timeline: return "timeline.selection"
        case .comparison: return "arrow.left.arrow.right"
        case .summary: return "doc.text.magnifyingglass"
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
}
