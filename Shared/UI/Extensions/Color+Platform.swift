import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-Platform Color Extensions
// Provides consistent system colors across macOS and iOS

public extension Color {
    /// Control background color - used for UI controls and containers
    static var controlBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(.secondarySystemBackground)
        #endif
    }

    /// Window background color - used for main window/view backgrounds
    static var windowBackground: Color {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    /// Text background color - used for text editing areas
    static var textBackground: Color {
        #if os(macOS)
        Color(NSColor.textBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    /// Tertiary label color
    static var tertiaryLabel: Color {
        #if os(macOS)
        Color(NSColor.tertiaryLabelColor)
        #else
        Color(.tertiaryLabel)
        #endif
    }

    /// Quaternary label color
    static var quaternaryLabel: Color {
        #if os(macOS)
        Color(NSColor.quaternaryLabelColor)
        #else
        Color(.quaternaryLabel)
        #endif
    }

    /// Separator color
    static var separatorColor: Color {
        #if os(macOS)
        Color(NSColor.separatorColor)
        #else
        Color(.separator)
        #endif
    }
}
