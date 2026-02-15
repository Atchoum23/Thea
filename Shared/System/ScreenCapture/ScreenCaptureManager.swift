import Foundation
import CoreGraphics
import AppKit

#if os(macOS)
import ScreenCaptureKit

// MARK: - Screen Capture Manager
// Uses ScreenCaptureKit to capture displays, windows, or regions
// Provides CGImage output for vision model processing

@MainActor
@Observable
final class ScreenCaptureManager {

    // MARK: - State

    private(set) var isAuthorized: Bool = false
    private(set) var authorizationError: Error?

    // MARK: - Capture Mode

    enum CaptureMode {
        case fullScreen
        case activeWindow
        case window(bundleID: String)
        case region(CGRect)
    }

    // MARK: - Initialization

    init() {
        Task {
            await checkAuthorization()
        }
    }

    // MARK: - Authorization

    func checkAuthorization() async {
        do {
            // Request access to screen recording
            let canCapture = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            isAuthorized = !canCapture.displays.isEmpty
            authorizationError = nil
        } catch {
            isAuthorized = false
            authorizationError = error
            print("❌ ScreenCaptureManager: Authorization failed - \(error.localizedDescription)")
        }
    }

    func requestAuthorization() async throws {
        // Trigger authorization prompt by attempting capture
        _ = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        await checkAuthorization()

        if !isAuthorized {
            throw ScreenCaptureError.notAuthorized
        }
    }

    // MARK: - Capture Operations

    /// Capture the main display
    func captureScreen() async throws -> CGImage {
        guard isAuthorized else {
            throw ScreenCaptureError.notAuthorized
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        return try await captureWithFilter(filter)
    }

    /// Capture a specific window by bundle ID
    func captureWindow(bundleID: String) async throws -> CGImage {
        guard isAuthorized else {
            throw ScreenCaptureError.notAuthorized
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let window = content.windows.first(where: {
            $0.owningApplication?.bundleIdentifier == bundleID
        }) else {
            throw ScreenCaptureError.windowNotFound(bundleID)
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)

        return try await captureWithFilter(filter)
    }

    /// Capture the currently active (frontmost) window
    func captureActiveWindow() async throws -> CGImage {
        guard isAuthorized else {
            throw ScreenCaptureError.notAuthorized
        }

        // Get frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            throw ScreenCaptureError.noActiveWindow
        }

        return try await captureWindow(bundleID: bundleID)
    }

    /// Capture a specific region of the screen
    func captureRegion(_ rect: CGRect) async throws -> CGImage {
        guard isAuthorized else {
            throw ScreenCaptureError.notAuthorized
        }

        // Capture full screen first
        let fullImage = try await captureScreen()

        // Crop to specified rect
        guard let cropped = fullImage.cropping(to: rect) else {
            throw ScreenCaptureError.cropFailed
        }

        return cropped
    }

    // MARK: - Private Capture Logic

    private func captureWithFilter(_ filter: SCContentFilter) async throws -> CGImage {
        let config = SCStreamConfiguration()

        // High quality capture
        config.width = 1920
        config.height = 1080
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }
}

// MARK: - Screen Capture Errors

enum ScreenCaptureError: Error, LocalizedError {
    case notAuthorized
    case noDisplayFound
    case windowNotFound(String)
    case noActiveWindow
    case cropFailed
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen recording permission not granted. Please enable in System Settings → Privacy & Security → Screen Recording."
        case .noDisplayFound:
            return "No display found for screen capture."
        case .windowNotFound(let bundleID):
            return "Window not found for app: \(bundleID)"
        case .noActiveWindow:
            return "No active window found."
        case .cropFailed:
            return "Failed to crop captured image to specified region."
        case .captureFailed(let reason):
            return "Screen capture failed: \(reason)"
        }
    }
}

#endif
