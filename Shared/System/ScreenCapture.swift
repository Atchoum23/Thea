import Foundation
import CoreGraphics
import OSLog

#if os(macOS)
import ScreenCaptureKit
import AppKit
#endif

// MARK: - ScreenCapture
// Modern screen capture service with ScreenCaptureKit (macOS 14.0+) and legacy fallback

public actor ScreenCapture {
    public static let shared = ScreenCapture()

    private let logger = Logger(subsystem: "com.thea.system", category: "ScreenCapture")
    
    #if os(macOS)
    // Cache for ScreenCaptureKit content
    @available(macOS 14.0, *)
    private var availableContent: SCShareableContent?
    
    @available(macOS 14.0, *)
    private var lastContentUpdate: Date?
    #endif

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
        #if os(macOS)
        logger.info("Capturing full screen")

        if #available(macOS 14.0, *) {
            // Use modern ScreenCaptureKit
            return try await captureScreenModern()
        } else {
            // Fall back to legacy API for macOS 13 and earlier
            return try capturScreenLegacy()
        }
        #else
        throw CaptureError.notSupported
        #endif
    }
    
    #if os(macOS)
    // MARK: - Modern ScreenCaptureKit Implementation (macOS 14.0+)
    
    @available(macOS 14.0, *)
    private func captureScreenModern() async throws -> CGImage {
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
        
        logger.info("Screen captured (modern): \(image.width)x\(image.height)")
        return image
    }
    
    @available(macOS 14.0, *)
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
    
    // MARK: - Legacy Implementation (macOS 13 and earlier)
    
    @available(macOS, deprecated: 14.0, message: "Legacy fallback for macOS 13 and earlier")
    private func capturScreenLegacy() throws -> CGImage {
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        
        let image = CGWindowListCreateImage(
            screenBounds,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .bestResolution]
        )
        
        guard let image = image else {
            throw CaptureError.captureFailed("Failed to create screen image")
        }
        
        logger.info("Screen captured (legacy): \(image.width)x\(image.height)")
        return image
    }
    #endif

    // MARK: - Capture Window

    public func captureWindow(named windowName: String) async throws -> CGImage {
        #if os(macOS)
        logger.info("Capturing window: \(windowName)")

        if #available(macOS 14.0, *) {
            // Use modern ScreenCaptureKit
            return try await captureWindowModern(named: windowName)
        } else {
            // Fall back to legacy API
            return try captureWindowLegacy(named: windowName)
        }
        #else
        throw CaptureError.notSupported
        #endif
    }
    
    #if os(macOS)
    @available(macOS 14.0, *)
    private func captureWindowModern(named windowName: String) async throws -> CGImage {
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
        
        logger.info("Window captured (modern): \(image.width)x\(image.height)")
        return image
    }
    
    @available(macOS, deprecated: 14.0, message: "Legacy fallback for macOS 13 and earlier")
    private func captureWindowLegacy(named windowName: String) throws -> CGImage {
        // Get window list
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw CaptureError.captureFailed("Failed to get window list")
        }

        // Find window by name
        var targetWindowID: CGWindowID?
        for window in windowList {
            if let name = window[kCGWindowName as String] as? String,
               name.contains(windowName) {
                if let windowID = window[kCGWindowNumber as String] as? CGWindowID {
                    targetWindowID = windowID
                    break
                }
            }
        }

        guard let windowID = targetWindowID else {
            throw CaptureError.windowNotFound(windowName)
        }

        // Capture the window
        let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )

        guard let image = image else {
            throw CaptureError.captureFailed("Failed to create window image")
        }

        logger.info("Window captured (legacy): \(image.width)x\(image.height)")
        return image
    }
    #endif

    // MARK: - Capture Region

    public func captureRegion(_ rect: CGRect) async throws -> CGImage {
        #if os(macOS)
        logger.info("Capturing region: width=\(rect.width), height=\(rect.height)")

        if #available(macOS 14.0, *) {
            // Use modern ScreenCaptureKit
            return try await captureRegionModern(rect)
        } else {
            // Fall back to legacy API
            return try captureRegionLegacy(rect)
        }
        #else
        throw CaptureError.notSupported
        #endif
    }
    
    #if os(macOS)
    @available(macOS 14.0, *)
    private func captureRegionModern(_ rect: CGRect) async throws -> CGImage {
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
        
        logger.info("Region captured (modern): \(image.width)x\(image.height)")
        return image
    }
    
    @available(macOS, deprecated: 14.0, message: "Legacy fallback for macOS 13 and earlier")
    private func captureRegionLegacy(_ rect: CGRect) throws -> CGImage {
        let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .bestResolution]
        )

        guard let image = image else {
            throw CaptureError.captureFailed("Failed to capture region")
        }

        logger.info("Region captured (legacy): \(image.width)x\(image.height)")
        return image
    }
    #endif

    // MARK: - Save to File

    public func saveToFile(_ image: CGImage, path: String) throws {
        #if os(macOS)
        let url = URL(fileURLWithPath: path)

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
            throw CaptureError.captureFailed("Failed to create image destination")
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.captureFailed("Failed to write image file")
        }

        logger.info("Saved screenshot to: \(path)")
        #else
        throw CaptureError.notSupported
        #endif
    }

    // MARK: - Permission Check

    public func checkPermission() async -> Bool {
        #if os(macOS)
        if #available(macOS 12.3, *) {
            // Check screen recording permission
            return CGPreflightScreenCaptureAccess()
        } else {
            // Assume permission on older systems
            return true
        }
        #else
        return false
        #endif
    }

    public func requestPermission() async -> Bool {
        #if os(macOS)
        if #available(macOS 12.3, *) {
            return CGRequestScreenCaptureAccess()
        } else {
            return true
        }
        #else
        return false
        #endif
    }
}
