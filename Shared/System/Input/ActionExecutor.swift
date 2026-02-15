import Foundation
import CoreGraphics
import AppKit

#if os(macOS)

// MARK: - Action Executor
// Uses CGEvent to simulate mouse clicks, typing, and mouse movement
// Enables "control handoff" feature for automated UI interactions

@MainActor
final class SystemActionExecutor {

    // MARK: - Authorization

    func isAuthorized() -> Bool {
        return AXIsProcessTrusted()
    }

    nonisolated func requestAuthorization() {
        // kAXTrustedCheckOptionPrompt is a global constant - safe to access
        let promptKey = unsafeBitCast(
            kAXTrustedCheckOptionPrompt,
            to: CFString.self
        ) as String
        let options: NSDictionary = [promptKey: true]
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Mouse Actions

    /// Click at a specific screen position
    func click(at point: CGPoint, button: MouseButton = .left) throws {
        guard isAuthorized() else {
            throw SystemActionExecutorError.notAuthorized
        }

        let (downType, upType) = button.eventTypes

        // Mouse down
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: downType,
            mouseCursorPosition: point,
            mouseButton: button.cgButton
        ) else {
            throw SystemActionExecutorError.eventCreationFailed
        }

        // Mouse up
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: upType,
            mouseCursorPosition: point,
            mouseButton: button.cgButton
        ) else {
            throw SystemActionExecutorError.eventCreationFailed
        }

        // Post events
        mouseDown.post(tap: .cghidEventTap)
        usleep(50_000) // 50ms delay
        mouseUp.post(tap: .cghidEventTap)

        print("🖱️ SystemActionExecutor: Clicked \(button) at (\(point.x), \(point.y))")
    }

    /// Double-click at a specific position
    func doubleClick(at point: CGPoint, button: MouseButton = .left) throws {
        guard isAuthorized() else {
            throw SystemActionExecutorError.notAuthorized
        }

        let (downType, upType) = button.eventTypes

        // First click
        guard let mouseDown1 = CGEvent(
            mouseEventSource: nil,
            mouseType: downType,
            mouseCursorPosition: point,
            mouseButton: button.cgButton
        ) else {
            throw SystemActionExecutorError.eventCreationFailed
        }

        guard let mouseUp1 = CGEvent(
            mouseEventSource: nil,
            mouseType: upType,
            mouseCursorPosition: point,
            mouseButton: button.cgButton
        ) else {
            throw SystemActionExecutorError.eventCreationFailed
        }

        // Second click with clickCount = 2
        guard let mouseDown2 = CGEvent(
            mouseEventSource: nil,
            mouseType: downType,
            mouseCursorPosition: point,
            mouseButton: button.cgButton
        ) else {
            throw SystemActionExecutorError.eventCreationFailed
        }
        mouseDown2.setIntegerValueField(.mouseEventClickState, value: 2)

        guard let mouseUp2 = CGEvent(
            mouseEventSource: nil,
            mouseType: upType,
            mouseCursorPosition: point,
            mouseButton: button.cgButton
        ) else {
            throw SystemActionExecutorError.eventCreationFailed
        }
        mouseUp2.setIntegerValueField(.mouseEventClickState, value: 2)

        // Post events
        mouseDown1.post(tap: .cghidEventTap)
        mouseUp1.post(tap: .cghidEventTap)
        usleep(100_000) // 100ms delay
        mouseDown2.post(tap: .cghidEventTap)
        mouseUp2.post(tap: .cghidEventTap)

        print("🖱️ SystemActionExecutor: Double-clicked at (\(point.x), \(point.y))")
    }

    /// Move mouse pointer to a specific position
    func movePointer(to point: CGPoint, animated: Bool = false) throws {
        guard isAuthorized() else {
            throw SystemActionExecutorError.notAuthorized
        }

        if animated {
            // Smooth animation over 0.5 seconds
            let currentPos = CGEvent(source: nil)?.location ?? .zero
            let duration: TimeInterval = 0.5
            let steps = 50
            let stepDelay = duration / Double(steps)

            for i in 0...steps {
                let progress = Double(i) / Double(steps)
                let interpolated = CGPoint(
                    x: currentPos.x + (point.x - currentPos.x) * progress,
                    y: currentPos.y + (point.y - currentPos.y) * progress
                )

                CGWarpMouseCursorPosition(interpolated)
                usleep(UInt32(stepDelay * 1_000_000))
            }
        } else {
            CGWarpMouseCursorPosition(point)
        }

        print("🖱️ SystemActionExecutor: Moved pointer to (\(point.x), \(point.y))")
    }

    // MARK: - Keyboard Actions

    /// Type text using keyboard events
    func type(_ text: String) throws {
        guard isAuthorized() else {
            throw SystemActionExecutorError.notAuthorized
        }

        for char in text {
            try typeCharacter(char)
            usleep(20_000) // 20ms delay between keystrokes
        }

        print("⌨️ SystemActionExecutor: Typed text: \(text)")
    }

    /// Press a specific key
    func pressKey(_ keyCode: CGKeyCode, modifiers: CGEventFlags = []) throws {
        guard isAuthorized() else {
            throw SystemActionExecutorError.notAuthorized
        }

        // Key down
        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ) else {
            throw SystemActionExecutorError.eventCreationFailed
        }
        keyDown.flags = modifiers

        // Key up
        guard let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            throw SystemActionExecutorError.eventCreationFailed
        }
        keyUp.flags = modifiers

        keyDown.post(tap: .cghidEventTap)
        usleep(50_000) // 50ms delay
        keyUp.post(tap: .cghidEventTap)

        print("⌨️ SystemActionExecutor: Pressed key code \(keyCode)")
    }

    /// Press Return/Enter key
    func pressReturn() throws {
        try pressKey(0x24) // Return key code
    }

    /// Press Tab key
    func pressTab() throws {
        try pressKey(0x30) // Tab key code
    }

    /// Press Escape key
    func pressEscape() throws {
        try pressKey(0x35) // Escape key code
    }

    // MARK: - Private Helpers

    private func typeCharacter(_ char: Character) throws {
        let string = String(char)

        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            throw SystemActionExecutorError.eventCreationFailed
        }

        event.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))
        event.post(tap: .cghidEventTap)

        usleep(10_000) // 10ms delay
    }
}

// MARK: - Mouse Button

enum MouseButton {
    case left
    case right

    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        }
    }

    var eventTypes: (down: CGEventType, up: CGEventType) {
        switch self {
        case .left: return (.leftMouseDown, .leftMouseUp)
        case .right: return (.rightMouseDown, .rightMouseUp)
        }
    }
}

// MARK: - Action Executor Errors

enum SystemActionExecutorError: Error, LocalizedError {
    case notAuthorized
    case eventCreationFailed
    case actionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Accessibility permission not granted. Please enable in System Settings → Privacy & Security → Accessibility."
        case .eventCreationFailed:
            return "Failed to create system event for action execution."
        case .actionFailed(let reason):
            return "Action execution failed: \(reason)"
        }
    }
}

#endif
