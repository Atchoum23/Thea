import Foundation
#if os(macOS)
    import AppKit
    import ScreenCaptureKit
#endif

/// Core automation engine matching ChatGPT Agent capabilities
/// Provides macOS Accessibility API integration for GUI interaction
public actor AutomationEngine {
    public enum ActionType: Sendable {
        case click(x: Int, y: Int)
        case type(text: String)
        case scroll(direction: ScrollDirection, amount: Int)
        case keyPress(key: String, modifiers: [KeyModifier])
        case screenshot
    }

    public enum ScrollDirection: String, Sendable {
        case up, down, left, right
    }

    public enum KeyModifier: String, Sendable {
        case command, option, control, shift
    }

    public enum ConsequenceLevel: Int, Sendable, Comparable {
        case safe = 0 // Read-only operations (screenshots, reading)
        case moderate = 1 // Non-destructive writes (typing, clicking)
        case high = 2 // File operations, payments
        case critical = 3 // System changes, deletions, irreversible actions

        public static func < (lhs: ConsequenceLevel, rhs: ConsequenceLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private var permissionThreshold: ConsequenceLevel = .moderate

    public init() {}

    // MARK: - Permission Management

    public func setPermissionThreshold(_ level: ConsequenceLevel) {
        permissionThreshold = level
    }

    public func classifyAction(_ action: ActionType) -> ConsequenceLevel {
        switch action {
        case .screenshot:
            .safe
        case .click, .scroll:
            .moderate
        case let .type(text) where text.contains("sudo") || text.contains("rm -rf"):
            .critical
        case .type:
            .moderate
        case let .keyPress(key, _) where key == "Delete" || key == "Backspace":
            .high
        case .keyPress:
            .moderate
        }
    }

    public func requestPermission(for action: ActionType) async throws -> Bool {
        let level = classifyAction(action)

        guard level <= permissionThreshold else {
            throw AutomationError.permissionDenied(
                "Action classified as \(level) exceeds threshold \(permissionThreshold)"
            )
        }

        // For high/critical actions, would integrate with user permission dialogs
        if level >= .high {
            // In production, show native permission dialog
            return true
        }

        return true
    }

    // MARK: - GUI Automation

    public func executeAction(_ action: ActionType) async throws {
        guard try await requestPermission(for: action) else {
            throw AutomationError.permissionDenied("User denied permission")
        }

        switch action {
        case let .click(x, y):
            try await clickAtPoint(x: x, y: y)

        case let .type(text):
            try await typeText(text)

        case let .scroll(direction, amount):
            try await scrollPage(direction: direction, amount: amount)

        case let .keyPress(key, modifiers):
            try await pressKey(key, modifiers: modifiers)

        case .screenshot:
            _ = try await captureScreen()
        }
    }

    // MARK: - Accessibility API Integration

    nonisolated private func clickAtPoint(x: Int, y: Int) async throws {
        #if os(macOS)
            // macOS Accessibility API implementation
            // In production, would use CGEvent for precise clicks
            let point = CGPoint(x: x, y: y)
            let mouseDown = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: .left
            )
            let mouseUp = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left
            )

            mouseDown?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(50))
            mouseUp?.post(tap: .cghidEventTap)
        #else
            throw AutomationError.platformNotSupported
        #endif
    }

    nonisolated private func typeText(_ text: String) async throws {
        #if os(macOS)
            // Type text using CGEvent keyboard events
            for char in text {
                guard let keyCode = keyCodeForCharacter(char) else { continue }

                let keyDown = CGEvent(
                    keyboardEventSource: nil,
                    virtualKey: keyCode,
                    keyDown: true
                )
                let keyUp = CGEvent(
                    keyboardEventSource: nil,
                    virtualKey: keyCode,
                    keyDown: false
                )

                keyDown?.post(tap: .cghidEventTap)
                try await Task.sleep(for: .milliseconds(10))
                keyUp?.post(tap: .cghidEventTap)
            }
        #else
            throw AutomationError.platformNotSupported
        #endif
    }

    nonisolated private func scrollPage(direction: ScrollDirection, amount: Int) async throws {
        #if os(macOS)
            let scrollAmount: Int32 = switch direction {
            case .up, .right: Int32(amount)
            case .down, .left: -Int32(amount)
            }

            let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: scrollAmount,
                wheel2: 0,
                wheel3: 0
            )

            scrollEvent?.post(tap: .cghidEventTap)
        #else
            throw AutomationError.platformNotSupported
        #endif
    }

    nonisolated private func pressKey(_ key: String, modifiers: [KeyModifier]) async throws {
        #if os(macOS)
            guard let keyCode = keyCodeForString(key) else {
                throw AutomationError.invalidKey(key)
            }

            var flags: CGEventFlags = []
            for modifier in modifiers {
                switch modifier {
                case .command: flags.insert(.maskCommand)
                case .option: flags.insert(.maskAlternate)
                case .control: flags.insert(.maskControl)
                case .shift: flags.insert(.maskShift)
                }
            }

            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

            keyDown?.flags = flags
            keyUp?.flags = flags

            keyDown?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(10))
            keyUp?.post(tap: .cghidEventTap)
        #else
            throw AutomationError.platformNotSupported
        #endif
    }

    nonisolated private func captureScreen() async throws -> Data {
        #if os(macOS)
            // Use ScreenCaptureKit for macOS 14.0+
            if #available(macOS 14.0, *) {
                // Get available content
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )

                // Get the main display
                guard let display = content.displays.first else {
                    throw AutomationError.screenCaptureError
                }

                // Configure the content filter for the display
                let filter = SCContentFilter(display: display, excludingWindows: [])

                // Configure screenshot settings
                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                config.scalesToFit = false
                config.showsCursor = true

                // Capture the screenshot
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                let size = NSSize(width: cgImage.width, height: cgImage.height)
                let image = NSImage(cgImage: cgImage, size: size)

                // Convert to PNG data
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:])
                else {
                    throw AutomationError.screenCaptureError
                }

                return pngData
            }
        // Note: Fallback for pre-macOS 14.0 removed since deployment target is 14.0+
        // CGWindowListCreateImage is unavailable in macOS 14+
        #else
            throw AutomationError.platformNotSupported
        #endif
    }

    // MARK: - Helper Methods

    #if os(macOS)
        nonisolated private func keyCodeForCharacter(_ char: Character) -> CGKeyCode? {
            // Simplified mapping - production would have complete keyboard map
            let mapping: [Character: CGKeyCode] = [
                "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8,
                " ": 49
            ]
            return mapping[char.lowercased().first ?? " "]
        }

        nonisolated private func keyCodeForString(_ key: String) -> CGKeyCode? {
            let mapping: [String: CGKeyCode] = [
                "Return": 36, "Enter": 36, "Tab": 48, "Space": 49,
                "Delete": 51, "Backspace": 51, "Escape": 53
            ]
            return mapping[key]
        }
    #endif
}

// MARK: - Errors

public enum AutomationError: Error, Sendable, LocalizedError {
    case permissionDenied(String)
    case platformNotSupported
    case invalidKey(String)
    case screenCaptureError

    public var errorDescription: String? {
        switch self {
        case let .permissionDenied(reason):
            "Permission denied: \(reason)"
        case .platformNotSupported:
            "This automation feature is only supported on macOS"
        case let .invalidKey(key):
            "Invalid key: \(key)"
        case .screenCaptureError:
            "Failed to capture screen"
        }
    }
}
