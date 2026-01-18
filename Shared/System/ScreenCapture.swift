#if os(macOS)
import CoreGraphics
import Foundation
import OSLog
import AppKit
@preconcurrency import ScreenCaptureKit

// MARK: - ScreenCapture
// Modern screen capture service using ScreenCaptureKit (macOS 14.0+)
// Note: Legacy CGWindowListCreateImage APIs were removed in macOS 15.0
// Thea requires macOS 14.0+ so we use ScreenCaptureKit exclusively

public actor ScreenCapture {
    public static let shared = ScreenCapture()

    private let logger = Logger(subsystem: "com.thea.system", category: "ScreenCapture")

    // Cache for ScreenCaptureKit content
    private var availableContent: SCShareableContent?
    private var lastContentUpdate: Date?

    private init() {}

    // MARK: - Public Types

    public enum CaptureError: LocalizedError, Sendable {
        case notSupported
        case permissionDenied
        case captureFailed(String)
        case windowNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .notSupported:
                return "Screen capture is not supported on this platform"
            case .permissionDenied:
                return "Screen recording permission denied"
            case .captureFailed(let message):
                return "Capture failed: \(message)"
            case .windowNotFound(let name):
                return "Window not found: \(name)"
            }
        }
    }

    // MARK: - Capture Full Screen

    public func captureScreen() async throws -> CGImage {
        logger.info("Capturing full screen")

        // Get available content
        let content = try await getShareableContent()

        // Get the main display
        guard let display = content.displays.first else {
            throw CaptureError.captureFailed("No displays available")
        }

        // Create filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure capture
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.scalesToFit = false

        // Capture the image
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        logger.info("Screen captured: \(image.width)x\(image.height)")
        return image
    }

    private func getShareableContent() async throws -> SCShareableContent {
        // Cache content for 5 seconds to avoid repeated queries
        if let cached = availableContent,
           let lastUpdate = lastContentUpdate,
           Date().timeIntervalSince(lastUpdate) < 5 {
            return cached
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        self.availableContent = content
        self.lastContentUpdate = Date()

        return content
    }

    // MARK: - Capture Window

    public func captureWindow(named windowName: String) async throws -> CGImage {
        logger.info("Capturing window: \(windowName)")

        let content = try await getShareableContent()

        // Find window by name
        guard let window = content.windows.first(where: { window in
            window.title?.contains(windowName) ?? false ||
            window.owningApplication?.applicationName.contains(windowName) ?? false
        }) else {
            throw CaptureError.windowNotFound(windowName)
        }

        // Create filter for the window
        let filter = SCContentFilter(desktopIndependentWindow: window)

        // Configure capture
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.scalesToFit = false

        // Capture the image
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        logger.info("Window captured: \(image.width)x\(image.height)")
        return image
    }

    // MARK: - Capture Region

    public func captureRegion(_ rect: CGRect) async throws -> CGImage {
        logger.info("Capturing region: width=\(rect.width), height=\(rect.height)")

        let content = try await getShareableContent()

        guard let display = content.displays.first else {
            throw CaptureError.captureFailed("No displays available")
        }

        // Create filter for the display
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure capture with the specified region
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.scalesToFit = false

        // Capture the image
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        logger.info("Region captured: \(image.width)x\(image.height)")
        return image
    }

    // MARK: - Save to File

    public func saveToFile(_ image: CGImage, path: String) throws {
        let url = URL(fileURLWithPath: path)

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw CaptureError.captureFailed("Failed to create image destination")
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.captureFailed("Failed to write image file")
        }

        logger.info("Saved screenshot to: \(path)")
    }

    // MARK: - Permission Check

    public func checkPermission() async -> Bool {
        // Check screen recording permission
        CGPreflightScreenCaptureAccess()
    }

    public func requestPermission() async -> Bool {
        CGRequestScreenCaptureAccess()
    }
}

#endif
