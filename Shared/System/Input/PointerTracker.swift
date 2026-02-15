import Foundation
import CoreGraphics
import AppKit

#if os(macOS)

// MARK: - Pointer Tracker
// Uses CGEvent to track mouse position continuously
// Publishes current pointer position for live guidance

@MainActor
@Observable
final class PointerTracker {

    // MARK: - State

    private(set) var currentPosition: CGPoint = .zero
    private(set) var isTracking: Bool = false
    private(set) var isAuthorized: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Authorization

    func checkAuthorization() -> Bool {
        let trusted = AXIsProcessTrusted()
        isAuthorized = trusted
        return trusted
    }

    func requestAuthorization() {
        // Trigger authorization prompt
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Tracking Control

    func startTracking() {
        guard !isTracking else { return }

        if !checkAuthorization() {
            print("⚠️ PointerTracker: Not authorized. Request authorization first.")
            return
        }

        // Create event tap for mouse moved events
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                        (1 << CGEventType.leftMouseDragged.rawValue) |
                        (1 << CGEventType.rightMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly, // Non-invasive listening
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }

                let tracker = Unmanaged<PointerTracker>.fromOpaque(refcon).takeUnretainedValue()
                let location = event.location

                Task { @MainActor in
                    tracker.currentPosition = location
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ PointerTracker: Failed to create event tap")
            return
        }

        // Add to run loop
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)

        // Enable the event tap
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        isTracking = true

        print("✅ PointerTracker: Started tracking mouse position")
    }

    func stopTracking() {
        guard isTracking else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isTracking = false

        print("🛑 PointerTracker: Stopped tracking")
    }

    deinit {
        stopTracking()
    }
}

#endif
