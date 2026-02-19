import SwiftUI

// MARK: - Platform Color Extensions

// Cross-platform color helpers for macOS and iOS compatibility
// Provides consistent colors across different UI frameworks

extension Color {
    /// Control background color - used for form elements and containers
    static var controlBackground: Color {
        #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
        #else
            Color(.secondarySystemBackground)
        #endif
    }

    /// Window background color - used for main view backgrounds
    static var windowBackground: Color {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
        #else
            Color(.systemBackground)
        #endif
    }

    /// Text background color - used for text container backgrounds
    static var textBackground: Color {
        #if os(macOS)
            Color(nsColor: .textBackgroundColor)
        #else
            Color(.systemBackground)
        #endif
    }

    /// Tertiary label color
    static var tertiaryLabel: Color {
        // periphery:ignore - Reserved: tertiaryLabel static property reserved for future feature activation
        #if os(macOS)
            Color(nsColor: .tertiaryLabelColor)
        #else
            Color(.tertiaryLabel)
        #endif
    }

    /// Quaternary label color
    // periphery:ignore - Reserved: quaternaryLabel static property reserved for future feature activation
    static var quaternaryLabel: Color {
        #if os(macOS)
            Color(nsColor: .quaternaryLabelColor)
        #else
            Color(.quaternaryLabel)
        #endif
    }

    /// Separator color
    static var separatorColor: Color {
        #if os(macOS)
            Color(nsColor: .separatorColor)
        #else
            Color(.separator)
        #endif
    }
}
