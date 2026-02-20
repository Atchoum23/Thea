// ComputerUseHandler.swift
// Thea — L3: Computer Use Integration
//
// Implements macOS GUI automation for the computer_use tool.
// Enables Claude to take screenshots, click, type, scroll, and press keys.
//
// Security: All actions require "Computer Use" to be enabled in Autonomy settings.
// iOS: Not available (sandbox prevents GUI automation).

#if os(macOS)
import AppKit
import CoreGraphics
import Foundation
import OSLog

// MARK: - Computer Use Handler

/// Handles computer_use tool calls from Claude API on macOS.
/// Provides screenshot capture, mouse events, keyboard input, and scrolling.
actor ComputerUseHandler {

    private static let logger = Logger(subsystem: "ai.thea.app", category: "ComputerUse")

    // MARK: - Entry Point

    /// Execute a computer_use tool action from a tool call input dictionary.
    /// - Returns: String result description, or a data URI for screenshots.
    static func execute(_ input: [String: Any]) async -> String {
        guard UserDefaults.standard.bool(forKey: "thea.computerUseEnabled") else {
            return "Error: Computer Use is disabled. Enable it in Thea Settings → Agent → Computer Use."
        }

        let action = input["action"] as? String ?? "screenshot"

        switch action {
        case "screenshot":
            return await takeScreenshot()
        case "click":
            guard let coords = input["coordinate"] as? [Int], coords.count >= 2 else {
                return "Error: 'coordinate' [x, y] required for click action"
            }
            return await performClick(x: coords[0], y: coords[1])
        case "type":
            let text = input["text"] as? String ?? ""
            guard !text.isEmpty else { return "Error: 'text' required for type action" }
            return await typeText(text)
        case "scroll":
            guard let coords = input["coordinate"] as? [Int], coords.count >= 2 else {
                return "Error: 'coordinate' [x, y] required for scroll action"
            }
            let delta = input["delta"] as? Int ?? 3
            return await performScroll(x: coords[0], y: coords[1], delta: delta)
        case "key":
            let key = input["key"] as? String ?? ""
            guard !key.isEmpty else { return "Error: 'key' required for key action" }
            return await pressKey(key)
        default:
            return "Error: Unknown computer_use action '\(action)'. Valid: screenshot, click, type, scroll, key."
        }
    }

    // MARK: - Screenshot

    private static func takeScreenshot() async -> String {
        return await MainActor.run {
            // Capture the main display
            let displayID = CGMainDisplayID()
            guard let cgImage = CGDisplayCreateImage(displayID) else {
                return "Error: Could not capture screenshot — check Screen Recording permission"
            }

            // Scale down for API: max 1280px wide
            let maxWidth: CGFloat = 1280
            let origWidth = CGFloat(cgImage.width)
            let origHeight = CGFloat(cgImage.height)
            let scale = origWidth > maxWidth ? maxWidth / origWidth : 1.0
            let newSize = NSSize(width: origWidth * scale, height: origHeight * scale)

            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            let resized = NSImage(size: newSize)
            resized.lockFocus()
            nsImage.draw(in: NSRect(origin: .zero, size: newSize),
                         from: NSRect(origin: .zero, size: nsImage.size),
                         operation: .copy,
                         fraction: 1.0)
            resized.unlockFocus()

            guard let tiff = resized.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let pngData = bitmap.representation(using: .png, properties: [.compressionFactor: 0.8]) else {
                return "Error: Could not encode screenshot as PNG"
            }

            let base64 = pngData.base64EncodedString()
            logger.info("Screenshot: \(Int(newSize.width))×\(Int(newSize.height)) (\(pngData.count / 1024)KB)")
            return "data:image/png;base64,\(base64)"
        }
    }

    // MARK: - Mouse Click

    private static func performClick(x: Int, y: Int) async -> String {
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
        try? await Task.sleep(for: .milliseconds(50))
        mouseUp?.post(tap: .cghidEventTap)

        logger.info("Click at (\(x), \(y))")
        return "Clicked at (\(x), \(y))"
    }

    // MARK: - Keyboard Typing

    private static func typeText(_ text: String) async -> String {
        let source = CGEventSource(stateID: .hidSystemState)

        for scalar in text.unicodeScalars {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            var unicodeValue = scalar.value
            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicodeValue)
            keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unicodeValue)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            // Small delay between keystrokes for reliability
            try? await Task.sleep(for: .milliseconds(10))
        }

        let preview = String(text.prefix(50))
        logger.info("Typed \(text.count) characters: \(preview)")
        return "Typed: \(preview)\(text.count > 50 ? "..." : "")"
    }

    // MARK: - Scroll

    private static func performScroll(x: Int, y: Int, delta: Int) async -> String {
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: Int32(-delta),  // Negative = scroll down
            wheel2: 0,
            wheel3: 0
        )
        scrollEvent?.location = CGPoint(x: x, y: y)
        scrollEvent?.post(tap: .cghidEventTap)

        let direction = delta > 0 ? "up" : "down"
        logger.info("Scrolled \(abs(delta)) lines \(direction) at (\(x), \(y))")
        return "Scrolled \(abs(delta)) lines \(direction) at (\(x), \(y))"
    }

    // MARK: - Key Press

    private static func pressKey(_ keyCombo: String) async -> String {
        let source = CGEventSource(stateID: .hidSystemState)
        let components = keyCombo.lowercased().components(separatedBy: "+")

        // Resolve modifier flags
        var flags = CGEventFlags()
        var keyString = keyCombo

        if components.count > 1 {
            keyString = components.last ?? keyCombo
            for modifier in components.dropLast() {
                switch modifier {
                case "cmd", "command": flags.insert(.maskCommand)
                case "ctrl", "control": flags.insert(.maskControl)
                case "alt", "option": flags.insert(.maskAlternate)
                case "shift": flags.insert(.maskShift)
                case "fn": flags.insert(.maskSecondaryFn)
                default: break
                }
            }
        }

        // Resolve virtual key code
        let keyCode = resolveKeyCode(keyString)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(50))
        keyUp?.post(tap: .cghidEventTap)

        logger.info("Pressed key: \(keyCombo)")
        return "Pressed key: \(keyCombo)"
    }

    // MARK: - Key Code Resolution

    private static func resolveKeyCode(_ key: String) -> CGKeyCode {
        // Common key mappings
        let keyCodes: [String: CGKeyCode] = [
            "return": 36, "enter": 36,
            "tab": 48,
            "space": 49,
            "delete": 51, "backspace": 51,
            "escape": 53, "esc": 53,
            "command": 55, "cmd": 55,
            "shift": 56,
            "capslock": 57,
            "option": 58, "alt": 58,
            "control": 59, "ctrl": 59,
            "rightshift": 60,
            "rightoption": 61,
            "rightcontrol": 62,
            "fn": 63,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
            "home": 115, "pageup": 116, "forwarddelete": 117,
            "end": 119, "pagedown": 121,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
            "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
            "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25
        ]
        return keyCodes[key.lowercased()] ?? 0
    }
}

// MARK: - Computer Use Settings Extension

extension UserDefaults {
    var computerUseEnabled: Bool {
        get { bool(forKey: "thea.computerUseEnabled") }
        set { set(newValue, forKey: "thea.computerUseEnabled") }
    }
}

#endif
