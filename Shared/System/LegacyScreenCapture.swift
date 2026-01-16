import Foundation
import CoreGraphics

#if os(macOS)
// MARK: - Legacy Screen Capture Utilities
// These functions use deprecated APIs intentionally for backward compatibility with macOS 12-13
// When CGWindowListCreateImage is called from here, the deprecation warning is expected
// but does not indicate a bug - ScreenCaptureKit is used on macOS 14+

// swiftlint:disable all

/// Legacy helper for capturing full screen on macOS 12-13
/// - Returns: CGImage of the captured screen
/// - Note: Intentionally uses deprecated CGWindowListCreateImage for backward compatibility
@available(macOS, introduced: 12.0, deprecated: 14.0, message: "Use ScreenCaptureKit for macOS 14.0+")
func legacyCaptureScreen() -> CGImage? {
    let screenBounds = CGDisplayBounds(CGMainDisplayID())
    return CGWindowListCreateImage(
        screenBounds,
        .optionOnScreenOnly,
        kCGNullWindowID,
        [.boundsIgnoreFraming, .bestResolution]
    )
}

/// Legacy helper for capturing a window on macOS 12-13
/// - Parameter windowID: The CGWindowID of the window to capture
/// - Returns: CGImage of the captured window
/// - Note: Intentionally uses deprecated CGWindowListCreateImage for backward compatibility
@available(macOS, introduced: 12.0, deprecated: 14.0, message: "Use ScreenCaptureKit for macOS 14.0+")
func legacyCaptureWindow(windowID: CGWindowID) -> CGImage? {
    return CGWindowListCreateImage(
        .null,
        .optionIncludingWindow,
        windowID,
        [.boundsIgnoreFraming, .bestResolution]
    )
}

/// Legacy helper for capturing a region on macOS 12-13
/// - Parameter rect: The region to capture
/// - Returns: CGImage of the captured region
/// - Note: Intentionally uses deprecated CGWindowListCreateImage for backward compatibility
@available(macOS, introduced: 12.0, deprecated: 14.0, message: "Use ScreenCaptureKit for macOS 14.0+")
func legacyCaptureRegion(_ rect: CGRect) -> CGImage? {
    return CGWindowListCreateImage(
        rect,
        .optionOnScreenOnly,
        kCGNullWindowID,
        [.boundsIgnoreFraming, .bestResolution]
    )
}

// swiftlint:enable all
#endif
