import Foundation
import CoreGraphics

#if os(macOS)
import AppKit

// MARK: - Action Executor
// Simulates user actions (clicks, typing, mouse movement) using CGEvent
// Used for "control handoff" feature - allows Thea to perform actions on behalf of user
// Requires Accessibility permission

@MainActor
final class ActionExecutor {
    static let shared = ActionExecutor()

    // MARK: - State

    private(set) var lastError: Error?
    private(set) var isExecutingAction = false

    private init() {}

    // MARK: - Permission Check

    /// Check if Accessibility permission is granted
    var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission (opens System Settings)
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            print("[ActionExecutor] Opening System Settings for Accessibility permission")
        } else {
            print("[ActionExecutor] Accessibility permission already granted")
        }
    }

    // MARK: - Mouse Actions

    /// Move mouse pointer to specific coordinates
    func movePointer(to point: CGPoint) throws {
        guard hasPermission else {
            throw ActionExecutionError.permissionDenied
        }

        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            throw ActionExecutionError.eventCreationFailed("mouse move")
        }

        moveEvent.post(tap: .cghidEventTap)
        print("[ActionExecutor] Moved pointer to (\(point.x), \(point.y))")
    }

    /// Click at specific coordinates
    func click(at point: CGPoint, button: MouseButton = .left) async throws {
        guard hasPermission else {
            throw ActionExecutionError.permissionDenied
        }

        isExecutingAction = true
        defer { isExecutingAction = false }

        // Move to position
        try movePointer(to: point)

        // Brief delay to ensure pointer movement is registered
        try await Task.sleep(for: .milliseconds(50))

        // Mouse down
        guard let downEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: button == .left ? .leftMouseDown : .rightMouseDown,
            mouseCursorPosition: point,
            mouseButton: button == .left ? .left : .right
        ) else {
            throw ActionExecutionError.eventCreationFailed("mouse down")
        }
        downEvent.post(tap: .cghidEventTap)

        // Brief delay between down and up
        try await Task.sleep(for: .milliseconds(50))

        // Mouse up
        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: button == .left ? .leftMouseUp : .rightMouseUp,
            mouseCursorPosition: point,
            mouseButton: button == .left ? .left : .right
        ) else {
            throw ActionExecutionError.eventCreationFailed("mouse up")
        }
        upEvent.post(tap: .cghidEventTap)

        print("[ActionExecutor] Clicked at (\(point.x), \(point.y)) with \(button == .left ? "left" : "right") button")
    }

    /// Double-click at specific coordinates
    func doubleClick(at point: CGPoint) async throws {
        guard hasPermission else {
            throw ActionExecutionError.permissionDenied
        }

        isExecutingAction = true
        defer { isExecutingAction = false }

        // First click
        try await click(at: point)

        // Brief delay between clicks
        try await Task.sleep(for: .milliseconds(100))

        // Second click
        try await click(at: point)

        print("[ActionExecutor] Double-clicked at (\(point.x), \(point.y))")
    }

    // MARK: - Keyboard Actions

    /// Type text at current cursor position
    func type(_ text: String) async throws {
        guard hasPermission else {
            throw ActionExecutionError.permissionDenied
        }

        isExecutingAction = true
        defer { isExecutingAction = false }

        for character in text {
            try await typeCharacter(character)
            // Brief delay between keystrokes for natural typing
            try await Task.sleep(for: .milliseconds(20))
        }

        print("[ActionExecutor] Typed text: '\(text)'")
    }

    /// Type a single character
    private func typeCharacter(_ character: Character) async throws {
        let string = String(character)

        // Create keyboard event
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0,  // Will be set by Unicode
            keyDown: true
        ) else {
            throw ActionExecutionError.eventCreationFailed("key down")
        }

        // Set Unicode string
        keyDownEvent.keyboardSetUnicodeString(
            stringLength: string.utf16.count,
            unicodeString: Array(string.utf16)
        )

        keyDownEvent.post(tap: .cghidEventTap)

        // Brief delay
        try await Task.sleep(for: .milliseconds(10))

        // Key up
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0,
            keyDown: false
        ) else {
            throw ActionExecutionError.eventCreationFailed("key up")
        }

        keyUpEvent.keyboardSetUnicodeString(
            stringLength: string.utf16.count,
            unicodeString: Array(string.utf16)
        )

        keyUpEvent.post(tap: .cghidEventTap)
    }

    /// Press a specific key (e.g., Enter, Tab, Escape)
    func pressKey(_ key: KeyCode, modifiers: [KeyModifier] = []) async throws {
        guard hasPermission else {
            throw ActionExecutionError.permissionDenied
        }

        isExecutingAction = true
        defer { isExecutingAction = false }

        // Build modifier flags
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier {
            case .command: flags.insert(.maskCommand)
            case .shift: flags.insert(.maskShift)
            case .option: flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            }
        }

        // Key down
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: key.rawValue,
            keyDown: true
        ) else {
            throw ActionExecutionError.eventCreationFailed("key down")
        }
        keyDownEvent.flags = flags
        keyDownEvent.post(tap: .cghidEventTap)

        // Brief delay
        try await Task.sleep(for: .milliseconds(50))

        // Key up
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: key.rawValue,
            keyDown: false
        ) else {
            throw ActionExecutionError.eventCreationFailed("key up")
        }
        keyUpEvent.flags = flags
        keyUpEvent.post(tap: .cghidEventTap)

        print("[ActionExecutor] Pressed key: \(key) with modifiers: \(modifiers)")
    }

    // MARK: - Mouse Button

    enum MouseButton {
        case left
        case right
    }

    // MARK: - Key Codes

    enum KeyCode: CGKeyCode {
        case returnKey = 36
        case tab = 48
        case space = 49
        case delete = 51
        case escape = 53
        case command = 55
        case shift = 56
        case capsLock = 57
        case option = 58
        case control = 59
        case rightCommand = 54
        case rightShift = 60
        case rightOption = 61
        case rightControl = 62
        case function = 63
        case f1 = 122
        case f2 = 120
        case f3 = 99
        case f4 = 118
        case f5 = 96
        case f6 = 97
        case f7 = 98
        case f8 = 100
        case f9 = 101
        case f10 = 109
        case f11 = 103
        case f12 = 111
        case leftArrow = 123
        case rightArrow = 124
        case downArrow = 125
        case upArrow = 126
    }

    enum KeyModifier {
        case command
        case shift
        case option
        case control
    }
}

// MARK: - Errors

enum ActionExecutionError: Error, LocalizedError {
    case permissionDenied
    case eventCreationFailed(String)
    case actionFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Accessibility permission denied. Grant permission in System Settings → Privacy & Security → Accessibility."
        case .eventCreationFailed(let action):
            "Failed to create CGEvent for action: \(action)"
        case .actionFailed(let reason):
            "Action execution failed: \(reason)"
        }
    }
}

#endif
