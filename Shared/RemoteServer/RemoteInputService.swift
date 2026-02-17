//
//  RemoteInputService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
    import CoreGraphics
#else
    import UIKit
#endif

// MARK: - Accessibility Permission Helper

#if os(macOS)
    /// Check accessibility with prompt option - uses hard-coded key to avoid C global concurrency issues
    private func checkAccessibilityTrustedWithPrompt() -> Bool {
        // kAXTrustedCheckOptionPrompt is "AXTrustedCheckOptionPrompt" - use literal to avoid concurrency warning
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
#endif

// MARK: - Key Modifiers

/// Use RemoteKeyModifiers as the internal key modifiers type
typealias KeyModifiers = RemoteKeyModifiers

// MARK: - Remote Input Service

/// Handles remote mouse and keyboard input for remote control
@MainActor
public class RemoteInputService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isEnabled = false
    @Published public private(set) var lastInputTime: Date?
    @Published public private(set) var inputCount: Int64 = 0

    // MARK: - Configuration

    public var mouseSpeed: Double = 1.0
    public var keyboardDelay: TimeInterval = 0.01

    // MARK: - Initialization

    public init() {
        #if os(macOS)
            checkAccessibilityPermission()
        #endif
    }

    // MARK: - Permission Check

    #if os(macOS)
        private func checkAccessibilityPermission() {
            let trusted = AXIsProcessTrusted()
            isEnabled = trusted
        }

        /// Requests macOS Accessibility permission, prompting the user if not already granted.
        /// - Returns: `true` if the process is trusted for accessibility access, `false` otherwise.
        public func requestAccessibilityPermission() -> Bool {
            // Request accessibility permission with prompt option
            let trusted = checkAccessibilityTrustedWithPrompt()
            isEnabled = trusted
            return trusted
        }
    #endif

    // MARK: - Request Handling

    /// Processes an incoming remote input request by dispatching it to the appropriate handler.
    ///
    /// Supports mouse operations (move, click, down, up, drag, scroll), keyboard operations
    /// (key press, key down, key up, text typing), and clipboard operations.
    /// Increments the input counter and updates ``lastInputTime`` on success.
    ///
    /// - Parameter request: The ``InputRequest`` describing the input event to simulate.
    /// - Throws: ``RemoteInputError/accessibilityNotEnabled`` if Accessibility permission has not been granted (macOS).
    /// - Throws: ``RemoteInputError/notSupportedOnPlatform`` on non-macOS platforms.
    public func handleRequest(_ request: InputRequest) async throws {
        #if os(macOS)
            guard isEnabled else {
                throw RemoteInputError.accessibilityNotEnabled
            }

            switch request {
            case let .mouseMove(x, y):
                try await moveMouse(to: x, y)

            case let .mouseClick(x, y, button, clickCount):
                try await click(at: x, y, button: button, clickCount: clickCount)

            case let .mouseDown(x, y, button):
                try await mouseDown(at: x, y, button: button)

            case let .mouseUp(x, y, button):
                try await mouseUp(at: x, y, button: button)

            case let .mouseDrag(fromX, fromY, toX, toY, button):
                try await drag(from: fromX, fromY, to: toX, toY, button: button)

            case let .scroll(x, y, deltaX, deltaY):
                try await scroll(at: x, y, deltaX: deltaX, deltaY: deltaY)

            case let .keyPress(keyCode, modifiers):
                try await keyPress(keyCode: keyCode, modifiers: modifiers)

            case let .keyDown(keyCode, modifiers):
                try await keyDown(keyCode: keyCode, modifiers: modifiers)

            case let .keyUp(keyCode, modifiers):
                try await keyUp(keyCode: keyCode, modifiers: modifiers)

            case let .typeText(text):
                try await typeText(text)

            case let .setClipboard(text):
                try await setClipboard(text)

            case .getClipboard:
                // Handled separately as it returns a value
                break
            }

            inputCount += 1
            lastInputTime = Date()
        #else
            throw RemoteInputError.notSupportedOnPlatform
        #endif
    }

    // MARK: - Clipboard

    /// Retrieves the current plain-text content from the system clipboard.
    /// - Returns: The clipboard string, or an empty string if no text is available.
    public func getClipboardContent() async throws -> String {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            return pasteboard.string(forType: .string) ?? ""
        #else
            return UIPasteboard.general.string ?? ""
        #endif
    }

    // MARK: - Mouse Operations (macOS)

    #if os(macOS)
        private func moveMouse(to x: Int, _ y: Int) async throws {
            let point = CGPoint(x: CGFloat(x) * mouseSpeed, y: CGFloat(y) * mouseSpeed)

            let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)
        }

        private func click(at x: Int, _ y: Int, button: InputRequest.MouseButton, clickCount: Int) async throws {
            let point = CGPoint(x: x, y: y)
            let (downType, upType, cgButton) = mouseEventTypes(for: button)

            for _ in 0 ..< clickCount {
                let downEvent = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: cgButton)
                downEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
                downEvent?.post(tap: .cghidEventTap)

                try await Task.sleep(for: .milliseconds(50)) // 50ms

                let upEvent = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: cgButton)
                upEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
                upEvent?.post(tap: .cghidEventTap)

                if clickCount > 1 {
                    try await Task.sleep(for: .milliseconds(100)) // 100ms between clicks
                }
            }
        }

        private func mouseDown(at x: Int, _ y: Int, button: InputRequest.MouseButton) async throws {
            let point = CGPoint(x: x, y: y)
            let (downType, _, cgButton) = mouseEventTypes(for: button)

            let event = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: cgButton)
            event?.post(tap: .cghidEventTap)
        }

        private func mouseUp(at x: Int, _ y: Int, button: InputRequest.MouseButton) async throws {
            let point = CGPoint(x: x, y: y)
            let (_, upType, cgButton) = mouseEventTypes(for: button)

            let event = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: cgButton)
            event?.post(tap: .cghidEventTap)
        }

        private func drag(from fromX: Int, _ fromY: Int, to toX: Int, _ toY: Int, button: InputRequest.MouseButton) async throws {
            let fromPoint = CGPoint(x: fromX, y: fromY)
            let toPoint = CGPoint(x: toX, y: toY)
            let (downType, upType, cgButton) = mouseEventTypes(for: button)

            // Mouse down at start
            let downEvent = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: fromPoint, mouseButton: cgButton)
            downEvent?.post(tap: .cghidEventTap)

            try await Task.sleep(for: .milliseconds(50))

            // Drag to destination
            let dragType: CGEventType = button == .left ? .leftMouseDragged : button == .right ? .rightMouseDragged : .otherMouseDragged

            let steps = 10
            for i in 1 ... steps {
                let progress = CGFloat(i) / CGFloat(steps)
                let x = fromPoint.x + (toPoint.x - fromPoint.x) * progress
                let y = fromPoint.y + (toPoint.y - fromPoint.y) * progress

                let dragEvent = CGEvent(mouseEventSource: nil, mouseType: dragType, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: cgButton)
                dragEvent?.post(tap: .cghidEventTap)

                try await Task.sleep(for: .milliseconds(10)) // 10ms between drag points
            }

            // Mouse up at end
            let upEvent = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: toPoint, mouseButton: cgButton)
            upEvent?.post(tap: .cghidEventTap)
        }

        private func scroll(at x: Int, _ y: Int, deltaX: Int, deltaY: Int) async throws {
            // First move to position
            try await moveMouse(to: x, y)

            // Then scroll
            let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY), wheel2: Int32(deltaX), wheel3: 0)
            scrollEvent?.post(tap: .cghidEventTap)
        }

        private func mouseEventTypes(for button: InputRequest.MouseButton) -> (CGEventType, CGEventType, CGMouseButton) {
            switch button {
            case .left:
                (.leftMouseDown, .leftMouseUp, .left)
            case .right:
                (.rightMouseDown, .rightMouseUp, .right)
            case .middle:
                (.otherMouseDown, .otherMouseUp, .center)
            }
        }
    #endif

    // MARK: - Keyboard Operations (macOS)

    #if os(macOS)
        private func keyPress(keyCode: UInt16, modifiers: KeyModifiers) async throws {
            try await keyDown(keyCode: keyCode, modifiers: modifiers)
            try await Task.sleep(for: .seconds(keyboardDelay))
            try await keyUp(keyCode: keyCode, modifiers: modifiers)
        }

        private func keyDown(keyCode: UInt16, modifiers: KeyModifiers) async throws {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            event?.flags = cgEventFlags(from: modifiers)
            event?.post(tap: .cghidEventTap)
        }

        private func keyUp(keyCode: UInt16, modifiers: KeyModifiers) async throws {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            event?.flags = cgEventFlags(from: modifiers)
            event?.post(tap: .cghidEventTap)
        }

        private func typeText(_ text: String) async throws {
            for character in text {
                if let keyCode = keyCodeForCharacter(character) {
                    let needsShift = character.isUppercase || shiftCharacters.contains(character)
                    let modifiers: KeyModifiers = needsShift ? .shift : []

                    try await keyPress(keyCode: keyCode, modifiers: modifiers)
                    try await Task.sleep(for: .seconds(keyboardDelay))
                } else {
                    // For special characters, use Unicode input
                    try await typeUnicode(character)
                }
            }
        }

        private func typeUnicode(_ character: Character) async throws {
            guard let scalar = character.unicodeScalars.first else { return }

            let source = CGEventSource(stateID: .hidSystemState)
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)

            var unicodeChar = UniChar(scalar.value)
            event?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicodeChar)
            event?.post(tap: .cghidEventTap)

            let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            upEvent?.post(tap: .cghidEventTap)
        }

        private func setClipboard(_ text: String) async throws {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        private func cgEventFlags(from modifiers: KeyModifiers) -> CGEventFlags {
            var flags: CGEventFlags = []

            if modifiers.contains(.shift) {
                flags.insert(.maskShift)
            }
            if modifiers.contains(.control) {
                flags.insert(.maskControl)
            }
            if modifiers.contains(.option) {
                flags.insert(.maskAlternate)
            }
            if modifiers.contains(.command) {
                flags.insert(.maskCommand)
            }
            if modifiers.contains(.function) {
                flags.insert(.maskSecondaryFn)
            }
            if modifiers.contains(.capsLock) {
                flags.insert(.maskAlphaShift)
            }

            return flags
        }

        // Character to key code mapping
        private func keyCodeForCharacter(_ char: Character) -> UInt16? {
            let lowercased = char.lowercased().first ?? char
            return keyCodeMap[lowercased]
        }

        private let shiftCharacters: Set<Character> = Set("~!@#$%^&*()_+{}|:\"<>?")

        private let keyCodeMap: [Character: UInt16] = [
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
            "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
            "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
            "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
            "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
            "z": 0x06,
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
            "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, "\\": 0x2A,
            ";": 0x29, "'": 0x27, ",": 0x2B, ".": 0x2F, "/": 0x2C,
            "`": 0x32, " ": 0x31, "\n": 0x24, "\t": 0x30
        ]
    #endif
}

// MARK: - Remote Input Error

/// Errors that can occur when processing remote keyboard and mouse input events.
public enum RemoteInputError: Error, LocalizedError, Sendable {
    case accessibilityNotEnabled
    case notSupportedOnPlatform
    case invalidKeyCode
    case eventCreationFailed

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotEnabled: "Accessibility permission is required for input control"
        case .notSupportedOnPlatform: "Remote input is not supported on this platform"
        case .invalidKeyCode: "Invalid key code provided"
        case .eventCreationFailed: "Failed to create input event"
        }
    }
}

// MARK: - Key Codes

/// Common virtual key codes for macOS
public enum VirtualKeyCode: UInt16, Sendable {
    // Letters
    case a = 0x00, s = 0x01, d = 0x02, f = 0x03, h = 0x04
    case g = 0x05, z = 0x06, x = 0x07, c = 0x08, v = 0x09
    case b = 0x0B, q = 0x0C, w = 0x0D, e = 0x0E, r = 0x0F
    case y = 0x10, t = 0x11, o = 0x1F, u = 0x20, i = 0x22
    case p = 0x23, l = 0x25, j = 0x26, k = 0x28, n = 0x2D
    case m = 0x2E

    // Numbers
    case key1 = 0x12, key2 = 0x13, key3 = 0x14, key4 = 0x15
    case key5 = 0x17, key6 = 0x16, key7 = 0x1A, key8 = 0x1C
    case key9 = 0x19, key0 = 0x1D

    // Special
    case returnKey = 0x24, tab = 0x30, space = 0x31
    case delete = 0x33, escape = 0x35, command = 0x37
    case shift = 0x38, capsLock = 0x39, option = 0x3A
    case control = 0x3B, rightShift = 0x3C, rightOption = 0x3D
    case rightControl = 0x3E, function = 0x3F

    // Arrows
    case leftArrow = 0x7B, rightArrow = 0x7C
    case downArrow = 0x7D, upArrow = 0x7E

    // Function keys
    case f1 = 0x7A, f2 = 0x78, f3 = 0x63, f4 = 0x76
    case f5 = 0x60, f6 = 0x61, f7 = 0x62, f8 = 0x64
    case f9 = 0x65, f10 = 0x6D, f11 = 0x67, f12 = 0x6F

    // Numpad
    case keypad0 = 0x52, keypad1 = 0x53, keypad2 = 0x54
    case keypad3 = 0x55, keypad4 = 0x56, keypad5 = 0x57
    case keypad6 = 0x58, keypad7 = 0x59, keypad8 = 0x5B
    case keypad9 = 0x5C, keypadDecimal = 0x41, keypadPlus = 0x45
    case keypadMinus = 0x4E, keypadMultiply = 0x43, keypadDivide = 0x4B
    case keypadEnter = 0x4C, keypadEquals = 0x51, keypadClear = 0x47

    // Media
    case volumeUp = 0x48, volumeDown = 0x49, mute = 0x4A
}
