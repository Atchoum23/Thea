import Foundation
import CoreGraphics

#if os(macOS)
import AppKit

// MARK: - Pointer Tracker
// Tracks mouse pointer position and movements using CGEvent
// Requires Accessibility permission

@MainActor
@Observable
final class PointerTracker {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = PointerTracker()

    // MARK: - State

    private(set) var currentPosition: CGPoint = .zero
    private(set) var isTracking = false
    // periphery:ignore - Reserved: shared static property reserved for future feature activation
    private(set) var lastError: Error?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    // MARK: - Permission Check

    /// Check if Accessibility permission is granted
    // periphery:ignore - Reserved: hasPermission property — reserved for future feature activation
    var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission (opens System Settings)
    // periphery:ignore - Reserved: hasPermission property reserved for future feature activation
    func requestPermission() {
        // Prompt for accessibility permission
        // Use string literal to avoid concurrency warning on kAXTrustedCheckOptionPrompt global
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true as CFBoolean]
        // periphery:ignore - Reserved: requestPermission() instance method reserved for future feature activation
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            print("[PointerTracker] Opening System Settings for Accessibility permission")
        } else {
            print("[PointerTracker] Accessibility permission already granted")
        }
    }

    // MARK: - Tracking

    /// Start tracking pointer position
    // periphery:ignore - Reserved: startTracking() instance method — reserved for future feature activation
    func startTracking() {
        guard hasPermission else {
            lastError = PointerTrackingError.permissionDenied
            // periphery:ignore - Reserved: startTracking() instance method reserved for future feature activation
            print("[PointerTracker] Cannot start tracking - Accessibility permission denied")
            return
        }

        guard !isTracking else {
            print("[PointerTracker] Already tracking")
            return
        }

        // Get current mouse location as starting point
        if let currentEvent = CGEvent(source: nil) {
            currentPosition = currentEvent.location
        }

        // Create event tap for mouse moved events
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                       (1 << CGEventType.leftMouseDragged.rawValue) |
                       (1 << CGEventType.rightMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Listen-only doesn't require sudo
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }

                let tracker = Unmanaged<PointerTracker>.fromOpaque(refcon).takeUnretainedValue()

                Task { @MainActor in
                    let location = event.location
                    tracker.currentPosition = location
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = PointerTrackingError.eventTapCreationFailed
            print("[PointerTracker] Failed to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = runLoopSource else {
            lastError = PointerTrackingError.runLoopSourceCreationFailed
            print("[PointerTracker] Failed to create run loop source")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isTracking = true
        lastError = nil
        print("[PointerTracker] Started tracking pointer")
    }

    /// Stop tracking pointer position
    // periphery:ignore - Reserved: stopTracking() instance method — reserved for future feature activation
    func stopTracking() {
        guard isTracking else { return }

// periphery:ignore - Reserved: stopTracking() instance method reserved for future feature activation

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }

        isTracking = false
        print("[PointerTracker] Stopped tracking pointer")
    }

    /// Get current pointer position without continuous tracking
    // periphery:ignore - Reserved: getCurrentPosition() instance method — reserved for future feature activation
    func getCurrentPosition() -> CGPoint {
        // periphery:ignore - Reserved: getCurrentPosition() instance method reserved for future feature activation
        if let currentEvent = CGEvent(source: nil) {
            return currentEvent.location
        }
        return currentPosition
    }

    // No deinit needed — singleton never deallocates, and
    // @MainActor properties can't be accessed from nonisolated deinit
}

// MARK: - Errors

// periphery:ignore - Reserved: PointerTrackingError type reserved for future feature activation
enum PointerTrackingError: Error, LocalizedError {
    case permissionDenied
    case eventTapCreationFailed
    case runLoopSourceCreationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Accessibility permission denied. Grant permission in System Settings → Privacy & Security → Accessibility."
        case .eventTapCreationFailed:
            "Failed to create event tap for pointer tracking"
        case .runLoopSourceCreationFailed:
            "Failed to create run loop source for event tap"
        }
    }
}

#endif
