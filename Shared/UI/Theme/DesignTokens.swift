import SwiftUI

// MARK: - Design Tokens

/// Centralized spacing values following Apple HIG
enum TheaSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let jumbo: CGFloat = 48
}

/// Corner radius tokens following Apple's concentric design principle
enum TheaCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let card: CGFloat = 24
    static let capsule: CGFloat = .infinity

    /// Concentric radius: inner = outer - padding (Apple HIG rule)
    static func concentric(outer: CGFloat, padding: CGFloat) -> CGFloat {
        max(0, outer - padding)
    }
}

/// Size tokens for consistent component dimensions
enum TheaSize {
    // Touch targets (Apple HIG: minimum 44pt)
    static let minTouchTarget: CGFloat = 44
    static let buttonHeight: CGFloat = 48
    static let capsuleButtonHeight: CGFloat = 56

    // Input areas
    static let inputFieldMinHeight: CGFloat = 44
    static let inputFieldMaxHeight: CGFloat = 200

    // Sidebar
    static let sidebarMinWidth: CGFloat = 240
    static let sidebarIdealWidth: CGFloat = 280

    // Messages
    static let messageMaxWidth: CGFloat = 680
    static let messageAvatarSize: CGFloat = 28

    // Icons
    static let iconSmall: CGFloat = 16
    static let iconMedium: CGFloat = 20
    static let iconLarge: CGFloat = 24
    static let iconXLarge: CGFloat = 32

    // tvOS specific
    static let tvMessageMaxWidth: CGFloat = 1000
    static let tvMinTouchTarget: CGFloat = 66
}

/// Animation duration tokens
enum TheaDuration {
    static let instant: Double = 0.1
    static let fast: Double = 0.2
    static let normal: Double = 0.3
    static let slow: Double = 0.5
    static let morphing: Double = 0.4
}
