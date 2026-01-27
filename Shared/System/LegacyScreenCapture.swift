import CoreGraphics
import Foundation

#if os(macOS)

    // MARK: - Legacy Screen Capture Utilities

    // NOTE: CGWindowListCreateImage was completely removed in macOS 15.0
    // Since Thea targets macOS 14.0+, we use ScreenCaptureKit exclusively.
    // These stub functions exist only for API compatibility and will throw errors
    // if somehow called on macOS 14 where ScreenCaptureKit should be used instead.

    // swiftlint:disable all

    /// Legacy helper stub - not available on macOS 15+
    /// - Returns: nil - use ScreenCaptureKit instead
    @available(macOS, introduced: 12.0, obsoleted: 15.0, message: "CGWindowListCreateImage removed in macOS 15. Use ScreenCaptureKit.")
    func legacyCaptureScreen() -> CGImage? {
        // CGWindowListCreateImage is unavailable on macOS 15+
        // ScreenCapture.swift should use ScreenCaptureKit for macOS 14+
        nil
    }

    /// Legacy helper stub - not available on macOS 15+
    /// - Parameter windowID: The CGWindowID of the window (unused)
    /// - Returns: nil - use ScreenCaptureKit instead
    @available(macOS, introduced: 12.0, obsoleted: 15.0, message: "CGWindowListCreateImage removed in macOS 15. Use ScreenCaptureKit.")
    func legacyCaptureWindow(windowID _: CGWindowID) -> CGImage? {
        // CGWindowListCreateImage is unavailable on macOS 15+
        // ScreenCapture.swift should use ScreenCaptureKit for macOS 14+
        nil
    }

    /// Legacy helper stub - not available on macOS 15+
    /// - Parameter rect: The region to capture (unused)
    /// - Returns: nil - use ScreenCaptureKit instead
    @available(macOS, introduced: 12.0, obsoleted: 15.0, message: "CGWindowListCreateImage removed in macOS 15. Use ScreenCaptureKit.")
    func legacyCaptureRegion(_: CGRect) -> CGImage? {
        // CGWindowListCreateImage is unavailable on macOS 15+
        // ScreenCapture.swift should use ScreenCaptureKit for macOS 14+
        nil
    }

    // swiftlint:enable all
#endif
