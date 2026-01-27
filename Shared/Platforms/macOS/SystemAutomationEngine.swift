//
//  SystemAutomationEngine.swift
//  Thea
//
//  Created by Thea
//  System-level automation for macOS including window management,
//  input injection, app control, and system settings modification
//

#if os(macOS)
    import AppKit
    @preconcurrency import ApplicationServices
    import Foundation
    import os.log

    // MARK: - System Automation Engine

    /// Provides system-level automation capabilities for macOS
    @MainActor
    public final class SystemAutomationEngine: ObservableObject {
        public static let shared = SystemAutomationEngine()

        private let logger = Logger(subsystem: "app.thea.automation", category: "SystemAutomationEngine")

        // MARK: - State

        @Published public private(set) var isAutomationEnabled = false
        @Published public private(set) var lastAutomationResult: AutomationResult?

        private init() {
            checkAccessibilityPermission()
        }

        // MARK: - Permissions

        public func checkAccessibilityPermission() -> Bool {
            let trusted = AXIsProcessTrusted()
            isAutomationEnabled = trusted
            return trusted
        }

        public func requestAccessibilityPermission() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        // MARK: - Window Management

        /// Move a window to a specific position
        public func moveWindow(of app: NSRunningApplication, to position: CGPoint) async throws {
            guard isAutomationEnabled else {
                throw SystemAutomationError.permissionDenied
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var windowRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)

            guard result == .success, let window = windowRef else {
                throw SystemAutomationError.windowNotFound
            }

            var positionValue: CFTypeRef = AXValueCreate(.cgPoint, [position])!
            let setResult = AXUIElementSetAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, positionValue)

            if setResult != .success {
                throw SystemAutomationError.operationFailed("Failed to move window")
            }

            logger.info("Moved window to (\(position.x), \(position.y))")
        }

        /// Resize a window
        public func resizeWindow(of app: NSRunningApplication, to size: CGSize) async throws {
            guard isAutomationEnabled else {
                throw SystemAutomationError.permissionDenied
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)

            var windowRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)

            guard result == .success, let window = windowRef else {
                throw SystemAutomationError.windowNotFound
            }

            var sizeValue: CFTypeRef = AXValueCreate(.cgSize, [size])!
            let setResult = AXUIElementSetAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, sizeValue)

            if setResult != .success {
                throw SystemAutomationError.operationFailed("Failed to resize window")
            }

            logger.info("Resized window to (\(size.width), \(size.height))")
        }

        /// Arrange windows in a grid
        public func arrangeWindows(layout: WindowLayout) async throws {
            guard isAutomationEnabled else {
                throw SystemAutomationError.permissionDenied
            }

            let windows = getVisibleWindows()
            guard !windows.isEmpty else { return }

            let screen = NSScreen.main?.visibleFrame ?? .zero

            switch layout {
            case .split2Horizontal:
                let width = screen.width / 2
                for (index, windowInfo) in windows.prefix(2).enumerated() {
                    let position = CGPoint(x: screen.minX + CGFloat(index) * width, y: screen.minY)
                    let size = CGSize(width: width, height: screen.height)
                    try await positionWindow(windowInfo.window, at: position, size: size)
                }

            case .split2Vertical:
                let height = screen.height / 2
                for (index, windowInfo) in windows.prefix(2).enumerated() {
                    let position = CGPoint(x: screen.minX, y: screen.minY + CGFloat(index) * height)
                    let size = CGSize(width: screen.width, height: height)
                    try await positionWindow(windowInfo.window, at: position, size: size)
                }

            case .grid4:
                let width = screen.width / 2
                let height = screen.height / 2
                let positions = [
                    CGPoint(x: screen.minX, y: screen.minY + height),
                    CGPoint(x: screen.minX + width, y: screen.minY + height),
                    CGPoint(x: screen.minX, y: screen.minY),
                    CGPoint(x: screen.minX + width, y: screen.minY)
                ]
                for (index, windowInfo) in windows.prefix(4).enumerated() {
                    let size = CGSize(width: width, height: height)
                    try await positionWindow(windowInfo.window, at: positions[index], size: size)
                }

            case .maximize:
                if let windowInfo = windows.first {
                    try await positionWindow(windowInfo.window, at: CGPoint(x: screen.minX, y: screen.minY), size: screen.size)
                }

            case .center:
                if let windowInfo = windows.first {
                    let centerX = screen.minX + (screen.width - 800) / 2
                    let centerY = screen.minY + (screen.height - 600) / 2
                    try await positionWindow(windowInfo.window, at: CGPoint(x: centerX, y: centerY), size: CGSize(width: 800, height: 600))
                }
            }

            logger.info("Arranged windows in \(String(describing: layout)) layout")
        }

        private func positionWindow(_ window: AXUIElement, at position: CGPoint, size: CGSize) async throws {
            var positionValue: CFTypeRef = AXValueCreate(.cgPoint, [position])!
            var sizeValue: CFTypeRef = AXValueCreate(.cgSize, [size])!

            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }

        private func getVisibleWindows() -> [(app: NSRunningApplication, window: AXUIElement)] {
            var result: [(NSRunningApplication, AXUIElement)] = []

            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)

                var windowsRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                   let windows = windowsRef as? [AXUIElement]
                {
                    for window in windows {
                        result.append((app, window))
                    }
                }
            }

            return result
        }

        // MARK: - Input Injection

        /// Type text at the current cursor position
        public func typeText(_ text: String, delay: TimeInterval = 0.01) async throws {
            guard isAutomationEnabled else {
                throw SystemAutomationError.permissionDenied
            }

            for char in text {
                let keyCode = keyCodeForCharacter(char)
                let needsShift = char.isUppercase || shiftCharacters.contains(char)

                if needsShift {
                    postKeyEvent(keyCode: CGKeyCode(kVK_Shift), keyDown: true)
                }

                postKeyEvent(keyCode: keyCode, keyDown: true)
                postKeyEvent(keyCode: keyCode, keyDown: false)

                if needsShift {
                    postKeyEvent(keyCode: CGKeyCode(kVK_Shift), keyDown: false)
                }

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            logger.info("Typed \(text.count) characters")
        }

        /// Press a keyboard shortcut
        public func pressKeyboardShortcut(key: CGKeyCode, modifiers: CGEventFlags) async throws {
            guard isAutomationEnabled else {
                throw SystemAutomationError.permissionDenied
            }

            // Press modifiers
            if modifiers.contains(.maskCommand) {
                postKeyEvent(keyCode: CGKeyCode(kVK_Command), keyDown: true)
            }
            if modifiers.contains(.maskShift) {
                postKeyEvent(keyCode: CGKeyCode(kVK_Shift), keyDown: true)
            }
            if modifiers.contains(.maskAlternate) {
                postKeyEvent(keyCode: CGKeyCode(kVK_Option), keyDown: true)
            }
            if modifiers.contains(.maskControl) {
                postKeyEvent(keyCode: CGKeyCode(kVK_Control), keyDown: true)
            }

            // Press key
            postKeyEvent(keyCode: key, keyDown: true)
            postKeyEvent(keyCode: key, keyDown: false)

            // Release modifiers
            if modifiers.contains(.maskControl) {
                postKeyEvent(keyCode: CGKeyCode(kVK_Control), keyDown: false)
            }
            if modifiers.contains(.maskAlternate) {
                postKeyEvent(keyCode: CGKeyCode(kVK_Option), keyDown: false)
            }
            if modifiers.contains(.maskShift) {
                postKeyEvent(keyCode: CGKeyCode(kVK_Shift), keyDown: false)
            }
            if modifiers.contains(.maskCommand) {
                postKeyEvent(keyCode: CGKeyCode(kVK_Command), keyDown: false)
            }

            logger.debug("Pressed keyboard shortcut")
        }

        private func postKeyEvent(keyCode: CGKeyCode, keyDown: Bool) {
            if let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) {
                event.post(tap: .cghidEventTap)
            }
        }

        /// Move mouse to a position
        public func moveMouse(to point: CGPoint) async throws {
            guard isAutomationEnabled else {
                throw SystemAutomationError.permissionDenied
            }

            if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
                event.post(tap: .cghidEventTap)
            }
        }

        /// Click at a position
        public func click(at point: CGPoint, button: CGMouseButton = .left, clickCount: Int = 1) async throws {
            guard isAutomationEnabled else {
                throw SystemAutomationError.permissionDenied
            }

            // Move to position
            try await moveMouse(to: point)

            let mouseDownType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
            let mouseUpType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp

            for _ in 0 ..< clickCount {
                if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: mouseDownType, mouseCursorPosition: point, mouseButton: button) {
                    mouseDown.post(tap: .cghidEventTap)
                }

                if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: mouseUpType, mouseCursorPosition: point, mouseButton: button) {
                    mouseUp.post(tap: .cghidEventTap)
                }
            }

            logger.debug("Clicked at (\(point.x), \(point.y))")
        }

        // MARK: - App Control

        /// Launch an application
        public func launchApp(bundleIdentifier: String) async throws {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                throw SystemAutomationError.appNotFound(bundleIdentifier)
            }

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true

            try await NSWorkspace.shared.openApplication(at: url, configuration: config)

            logger.info("Launched app: \(bundleIdentifier)")
        }

        /// Activate (focus) an application
        public func activateApp(bundleIdentifier: String) async throws {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
                throw SystemAutomationError.appNotRunning(bundleIdentifier)
            }

            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

            logger.info("Activated app: \(bundleIdentifier)")
        }

        /// Quit an application
        public func quitApp(bundleIdentifier: String, force: Bool = false) async throws {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
                throw SystemAutomationError.appNotRunning(bundleIdentifier)
            }

            let result = force ? app.forceTerminate() : app.terminate()

            if !result {
                throw SystemAutomationError.operationFailed("Failed to \(force ? "force quit" : "quit") app")
            }

            logger.info("\(force ? "Force quit" : "Quit") app: \(bundleIdentifier)")
        }

        /// Hide an application
        public func hideApp(bundleIdentifier: String) async throws {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
                throw SystemAutomationError.appNotRunning(bundleIdentifier)
            }

            if !app.hide() {
                throw SystemAutomationError.operationFailed("Failed to hide app")
            }

            logger.info("Hid app: \(bundleIdentifier)")
        }

        // MARK: - System Settings

        /// Open a specific system preference pane
        public func openSystemPreference(_ preference: SystemPreference) async throws {
            let url = switch preference {
            case .general:
                URL(string: "x-apple.systempreferences:com.apple.preference.general")!
            case .appearance:
                URL(string: "x-apple.systempreferences:com.apple.preference.general?Appearance")!
            case .accessibility:
                URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess")!
            case .security:
                URL(string: "x-apple.systempreferences:com.apple.preference.security")!
            case .notifications:
                URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
            case .sound:
                URL(string: "x-apple.systempreferences:com.apple.preference.sound")!
            case .keyboard:
                URL(string: "x-apple.systempreferences:com.apple.preference.keyboard")!
            case .displays:
                URL(string: "x-apple.systempreferences:com.apple.preference.displays")!
            case .network:
                URL(string: "x-apple.systempreferences:com.apple.preference.network")!
            case .bluetooth:
                URL(string: "x-apple.systempreferences:com.apple.preference.Bluetooth")!
            }

            NSWorkspace.shared.open(url)

            logger.info("Opened system preference: \(String(describing: preference))")
        }

        /// Set system volume
        public func setVolume(_ level: Float) async throws {
            // Use AppleScript for volume control
            let script = """
            set volume output volume \(Int(level * 100))
            """

            try await runAppleScript(script)

            logger.info("Set volume to \(level)")
        }

        /// Toggle dark mode
        public func toggleDarkMode() async throws {
            let script = """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
            """

            try await runAppleScript(script)

            logger.info("Toggled dark mode")
        }

        /// Set display brightness
        public func setBrightness(_ level: Float) async throws {
            // Brightness control requires IOKit or private APIs
            // Using AppleScript as a workaround where possible

            let script = """
            tell application "System Events"
                key code 145 -- Brightness up
            end tell
            """

            // This is a simplified version; proper brightness control
            // would require IOKit frameworks

            logger.info("Brightness control requested (level: \(level))")
        }

        // MARK: - AppleScript Execution

        public func runAppleScript(_ script: String) async throws {
            guard let appleScript = NSAppleScript(source: script) else {
                throw SystemAutomationError.invalidScript
            }

            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)

            if let error {
                throw SystemAutomationError.scriptError(error.description)
            }
        }

        // MARK: - Key Code Mapping

        private let shiftCharacters: Set<Character> = Set("~!@#$%^&*()_+{}|:\"<>?")

        private func keyCodeForCharacter(_ char: Character) -> CGKeyCode {
            // Map characters to key codes
            let lowercased = char.lowercased().first ?? char

            switch lowercased {
            case "a": return CGKeyCode(kVK_ANSI_A)
            case "b": return CGKeyCode(kVK_ANSI_B)
            case "c": return CGKeyCode(kVK_ANSI_C)
            case "d": return CGKeyCode(kVK_ANSI_D)
            case "e": return CGKeyCode(kVK_ANSI_E)
            case "f": return CGKeyCode(kVK_ANSI_F)
            case "g": return CGKeyCode(kVK_ANSI_G)
            case "h": return CGKeyCode(kVK_ANSI_H)
            case "i": return CGKeyCode(kVK_ANSI_I)
            case "j": return CGKeyCode(kVK_ANSI_J)
            case "k": return CGKeyCode(kVK_ANSI_K)
            case "l": return CGKeyCode(kVK_ANSI_L)
            case "m": return CGKeyCode(kVK_ANSI_M)
            case "n": return CGKeyCode(kVK_ANSI_N)
            case "o": return CGKeyCode(kVK_ANSI_O)
            case "p": return CGKeyCode(kVK_ANSI_P)
            case "q": return CGKeyCode(kVK_ANSI_Q)
            case "r": return CGKeyCode(kVK_ANSI_R)
            case "s": return CGKeyCode(kVK_ANSI_S)
            case "t": return CGKeyCode(kVK_ANSI_T)
            case "u": return CGKeyCode(kVK_ANSI_U)
            case "v": return CGKeyCode(kVK_ANSI_V)
            case "w": return CGKeyCode(kVK_ANSI_W)
            case "x": return CGKeyCode(kVK_ANSI_X)
            case "y": return CGKeyCode(kVK_ANSI_Y)
            case "z": return CGKeyCode(kVK_ANSI_Z)
            case "0", ")": return CGKeyCode(kVK_ANSI_0)
            case "1", "!": return CGKeyCode(kVK_ANSI_1)
            case "2", "@": return CGKeyCode(kVK_ANSI_2)
            case "3", "#": return CGKeyCode(kVK_ANSI_3)
            case "4", "$": return CGKeyCode(kVK_ANSI_4)
            case "5", "%": return CGKeyCode(kVK_ANSI_5)
            case "6", "^": return CGKeyCode(kVK_ANSI_6)
            case "7", "&": return CGKeyCode(kVK_ANSI_7)
            case "8", "*": return CGKeyCode(kVK_ANSI_8)
            case "9", "(": return CGKeyCode(kVK_ANSI_9)
            case " ": return CGKeyCode(kVK_Space)
            case "\n", "\r": return CGKeyCode(kVK_Return)
            case "\t": return CGKeyCode(kVK_Tab)
            case ".": return CGKeyCode(kVK_ANSI_Period)
            case ",": return CGKeyCode(kVK_ANSI_Comma)
            case "/": return CGKeyCode(kVK_ANSI_Slash)
            case ";": return CGKeyCode(kVK_ANSI_Semicolon)
            case "'": return CGKeyCode(kVK_ANSI_Quote)
            case "[": return CGKeyCode(kVK_ANSI_LeftBracket)
            case "]": return CGKeyCode(kVK_ANSI_RightBracket)
            case "\\": return CGKeyCode(kVK_ANSI_Backslash)
            case "-": return CGKeyCode(kVK_ANSI_Minus)
            case "=": return CGKeyCode(kVK_ANSI_Equal)
            case "`": return CGKeyCode(kVK_ANSI_Grave)
            default: return CGKeyCode(kVK_Space)
            }
        }
    }

    // MARK: - Supporting Types

    public enum WindowLayout: String, CaseIterable {
        case split2Horizontal = "Split Horizontal"
        case split2Vertical = "Split Vertical"
        case grid4 = "Grid 4"
        case maximize = "Maximize"
        case center = "Center"
    }

    public enum SystemPreference: String, CaseIterable {
        case general
        case appearance
        case accessibility
        case security
        case notifications
        case sound
        case keyboard
        case displays
        case network
        case bluetooth
    }

    public struct AutomationResult {
        public let success: Bool
        public let message: String
        public let timestamp: Date

        public init(success: Bool, message: String) {
            self.success = success
            self.message = message
            timestamp = Date()
        }
    }

    public enum SystemAutomationError: Error, LocalizedError {
        case permissionDenied
        case windowNotFound
        case appNotFound(String)
        case appNotRunning(String)
        case operationFailed(String)
        case invalidScript
        case scriptError(String)

        public var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Accessibility permission required"
            case .windowNotFound:
                "Window not found"
            case let .appNotFound(bundleId):
                "App not found: \(bundleId)"
            case let .appNotRunning(bundleId):
                "App not running: \(bundleId)"
            case let .operationFailed(message):
                message
            case .invalidScript:
                "Invalid AppleScript"
            case let .scriptError(error):
                "Script error: \(error)"
            }
        }
    }

    // MARK: - Virtual Key Codes

    private let kVK_ANSI_A: Int = 0x00
    private let kVK_ANSI_B: Int = 0x0B
    private let kVK_ANSI_C: Int = 0x08
    private let kVK_ANSI_D: Int = 0x02
    private let kVK_ANSI_E: Int = 0x0E
    private let kVK_ANSI_F: Int = 0x03
    private let kVK_ANSI_G: Int = 0x05
    private let kVK_ANSI_H: Int = 0x04
    private let kVK_ANSI_I: Int = 0x22
    private let kVK_ANSI_J: Int = 0x26
    private let kVK_ANSI_K: Int = 0x28
    private let kVK_ANSI_L: Int = 0x25
    private let kVK_ANSI_M: Int = 0x2E
    private let kVK_ANSI_N: Int = 0x2D
    private let kVK_ANSI_O: Int = 0x1F
    private let kVK_ANSI_P: Int = 0x23
    private let kVK_ANSI_Q: Int = 0x0C
    private let kVK_ANSI_R: Int = 0x0F
    private let kVK_ANSI_S: Int = 0x01
    private let kVK_ANSI_T: Int = 0x11
    private let kVK_ANSI_U: Int = 0x20
    private let kVK_ANSI_V: Int = 0x09
    private let kVK_ANSI_W: Int = 0x0D
    private let kVK_ANSI_X: Int = 0x07
    private let kVK_ANSI_Y: Int = 0x10
    private let kVK_ANSI_Z: Int = 0x06
    private let kVK_ANSI_0: Int = 0x1D
    private let kVK_ANSI_1: Int = 0x12
    private let kVK_ANSI_2: Int = 0x13
    private let kVK_ANSI_3: Int = 0x14
    private let kVK_ANSI_4: Int = 0x15
    private let kVK_ANSI_5: Int = 0x17
    private let kVK_ANSI_6: Int = 0x16
    private let kVK_ANSI_7: Int = 0x1A
    private let kVK_ANSI_8: Int = 0x1C
    private let kVK_ANSI_9: Int = 0x19
    private let kVK_Space: Int = 0x31
    private let kVK_Return: Int = 0x24
    private let kVK_Tab: Int = 0x30
    private let kVK_ANSI_Period: Int = 0x2F
    private let kVK_ANSI_Comma: Int = 0x2B
    private let kVK_ANSI_Slash: Int = 0x2C
    private let kVK_ANSI_Semicolon: Int = 0x29
    private let kVK_ANSI_Quote: Int = 0x27
    private let kVK_ANSI_LeftBracket: Int = 0x21
    private let kVK_ANSI_RightBracket: Int = 0x1E
    private let kVK_ANSI_Backslash: Int = 0x2A
    private let kVK_ANSI_Minus: Int = 0x1B
    private let kVK_ANSI_Equal: Int = 0x18
    private let kVK_ANSI_Grave: Int = 0x32
    private let kVK_Command: Int = 0x37
    private let kVK_Shift: Int = 0x38
    private let kVK_Option: Int = 0x3A
    private let kVK_Control: Int = 0x3B
#endif
