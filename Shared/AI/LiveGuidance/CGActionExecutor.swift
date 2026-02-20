// CGActionExecutor.swift
// Thea — L3/M3: GUI Action Execution
//
// Programmatic macOS GUI automation via CGEvent.
// Used by LocalVisionGuidance for control handoff actions.
// macOS only — iOS sandbox prohibits GUI automation.

#if os(macOS)
import AppKit
import CoreGraphics
import Foundation

// MARK: - CGAction Executor

/// Performs programmatic mouse/keyboard actions on macOS.
/// Requires Accessibility permission for control handoff.
@MainActor
final class CGActionExecutor {
    static let shared = CGActionExecutor()

    private init() {}

    // MARK: - Permission

    /// True when Accessibility (Trusted Process) permission is granted.
    var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Compatible alias for view code that calls isAuthorized().
    func isAuthorized() -> Bool { hasPermission }

    /// Prompt the user for Accessibility permission via System Settings.
    func requestAuthorization() {
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true as CFBoolean]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Alias matching PointerTracker.requestPermission() naming convention.
    func requestPermission() { requestAuthorization() }

    // MARK: - Mouse Click

    func click(at point: CGPoint) async throws {
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                           mouseCursorPosition: point, mouseButton: .left)
        let up   = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                           mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(50))
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - Text Typing

    func type(_ text: String) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        for scalar in text.unicodeScalars {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            var unicode = scalar.value
            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicode)
            keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicode)
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: - Key Press

    enum KeyCode: CGKeyCode {
        case returnKey = 36
        case tab       = 48
        case space     = 49
        case delete    = 51
        case escape    = 53
    }

    func pressKey(_ keyCode: KeyCode) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode.rawValue, keyDown: true)
        let up   = CGEvent(keyboardEventSource: source, virtualKey: keyCode.rawValue, keyDown: false)
        down?.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(50))
        up?.post(tap: .cghidEventTap)
    }
}

#endif
