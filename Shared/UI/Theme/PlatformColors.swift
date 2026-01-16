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
}
