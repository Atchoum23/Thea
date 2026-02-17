//
//  AppIntegrationFramework.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
    import ApplicationServices
#endif

// MARK: - App Integration Framework

/// Central framework for integrating with and controlling other applications
public actor AppIntegrationFramework {
    public static let shared = AppIntegrationFramework()

    // MARK: - Components

    private let appStateMonitor = AppStateMonitor.shared
    private let elementInspector = UIElementInspector.shared
    private let capabilityRegistry = AppCapabilityRegistry.shared

    // MARK: - State

    private var isInitialized = false
    private var registeredApps: [String: AppIntegration] = [:]

    // MARK: - Initialization

    private init() {}

    /// Initialize the integration framework
    public func initialize() async throws {
        guard !isInitialized else { return }

        #if os(macOS)
            // Check accessibility permission
            guard AXIsProcessTrusted() else {
                throw IntegrationError.accessibilityNotGranted
            }
        #endif

        // Start monitoring
        await appStateMonitor.startMonitoring()

        // Load registered apps
        await loadRegisteredApps()

        isInitialized = true
    }

    /// Shutdown the framework
    public func shutdown() async {
        await appStateMonitor.stopMonitoring()
        isInitialized = false
    }

    // MARK: - App Discovery

    /// Get all running applications
    public func getRunningApps() async -> [AppInfo] {
        #if os(macOS)
            let workspace = NSWorkspace.shared
            return await MainActor.run {
                workspace.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .compactMap { app -> AppInfo? in
                        guard let bundleId = app.bundleIdentifier,
                              let name = app.localizedName
                        else {
                            return nil
                        }
                        return AppInfo(
                            bundleIdentifier: bundleId,
                            name: name,
                            isActive: app.isActive,
                            isHidden: app.isHidden,
                            processIdentifier: app.processIdentifier
                        )
                    }
            }
        #else
            return []
        #endif
    }

    /// Get the frontmost application
    public func getFrontmostApp() async -> AppInfo? {
        #if os(macOS)
            return await MainActor.run {
                guard let app = NSWorkspace.shared.frontmostApplication,
                      let bundleId = app.bundleIdentifier,
                      let name = app.localizedName
                else {
                    return nil
                }
                return AppInfo(
                    bundleIdentifier: bundleId,
                    name: name,
                    isActive: true,
                    isHidden: false,
                    processIdentifier: app.processIdentifier
                )
            }
        #else
            return nil
        #endif
    }

    // MARK: - App Control

    /// Activate an application
    public func activateApp(_ bundleId: String) async throws {
        #if os(macOS)
            guard let app = await getRunningApp(bundleId) else {
                throw IntegrationError.appNotFound(bundleId)
            }

            _ = await MainActor.run { [app] in
                app.activate()
            }
        #else
            throw IntegrationError.notSupported
        #endif
    }

    /// Launch an application
    public func launchApp(_ bundleId: String) async throws {
        #if os(macOS)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true

            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                throw IntegrationError.appNotFound(bundleId)
            }

            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        #else
            throw IntegrationError.notSupported
        #endif
    }

    /// Hide an application
    public func hideApp(_ bundleId: String) async throws {
        #if os(macOS)
            guard let app = await getRunningApp(bundleId) else {
                throw IntegrationError.appNotFound(bundleId)
            }

            _ = await MainActor.run { [app] in
                app.hide()
            }
        #else
            throw IntegrationError.notSupported
        #endif
    }

    #if os(macOS)
        private func getRunningApp(_ bundleId: String) async -> NSRunningApplication? {
            await MainActor.run {
                NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleId }
            }
        }
    #endif

    // MARK: - UI Interaction

    /// Click at a specific position
    public func click(at point: CGPoint) async throws {
        #if os(macOS)
            let source = CGEventSource(stateID: .hidSystemState)

            let mouseDown = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: .left
            )
            let mouseUp = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left
            )

            mouseDown?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(50)) // 50ms delay
            mouseUp?.post(tap: .cghidEventTap)
        #else
            throw IntegrationError.notSupported
        #endif
    }

    /// Type text
    public func typeText(_ text: String) async throws {
        #if os(macOS)
            let source = CGEventSource(stateID: .hidSystemState)

            for character in text {
                guard let keyCode = keyCodeForCharacter(character) else { continue }

                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

                // Handle shift for uppercase
                if character.isUppercase || character.isSymbol {
                    keyDown?.flags = .maskShift
                }

                keyDown?.post(tap: .cghidEventTap)
                try await Task.sleep(for: .milliseconds(10)) // 10ms delay
                keyUp?.post(tap: .cghidEventTap)
                try await Task.sleep(for: .milliseconds(10))
            }
        #else
            throw IntegrationError.notSupported
        #endif
    }

    #if os(macOS)
        private func keyCodeForCharacter(_ character: Character) -> CGKeyCode? {
            // Basic character to keycode mapping
            let mapping: [Character: CGKeyCode] = [
                "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
                "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
                "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9,
                "w": 13, "x": 7, "y": 16, "z": 6,
                "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26,
                "8": 28, "9": 25, "0": 29,
                " ": 49, "\n": 36, "\t": 48
            ]
            return mapping[character.lowercased().first ?? character]
        }
    #endif

    /// Press a keyboard shortcut
    public func pressShortcut(_ shortcut: IntegrationKeyboardShortcut) async throws {
        #if os(macOS)
            let source = CGEventSource(stateID: .hidSystemState)

            var flags: CGEventFlags = []
            if shortcut.modifiers.contains(.command) { flags.insert(.maskCommand) }
            if shortcut.modifiers.contains(.option) { flags.insert(.maskAlternate) }
            if shortcut.modifiers.contains(.control) { flags.insert(.maskControl) }
            if shortcut.modifiers.contains(.shift) { flags.insert(.maskShift) }

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false)

            keyDown?.flags = flags
            keyUp?.flags = flags

            keyDown?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(50))
            keyUp?.post(tap: .cghidEventTap)
        #else
            throw IntegrationError.notSupported
        #endif
    }

    // MARK: - Registration

    private func loadRegisteredApps() async {
        // Load app integrations from storage
    }

    /// Register a custom app integration
    public func registerIntegration(_ integration: AppIntegration) {
        registeredApps[integration.bundleIdentifier] = integration
    }

    /// Get integration for an app
    public func getIntegration(for bundleId: String) -> AppIntegration? {
        registeredApps[bundleId]
    }
}

// MARK: - App Info

public struct AppInfo: Identifiable, Sendable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public let name: String
    public let isActive: Bool
    public let isHidden: Bool
    public let processIdentifier: Int32

    public init(
        bundleIdentifier: String,
        name: String,
        isActive: Bool = false,
        isHidden: Bool = false,
        processIdentifier: Int32 = 0
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.isActive = isActive
        self.isHidden = isHidden
        self.processIdentifier = processIdentifier
    }
}

// MARK: - App Integration

public struct AppIntegration: Codable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let capabilities: [IntegrationCapability]
    public let actions: [IntegrationAction]

    public init(
        bundleIdentifier: String,
        displayName: String,
        capabilities: [IntegrationCapability] = [],
        actions: [IntegrationAction] = []
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.capabilities = capabilities
        self.actions = actions
    }
}

// MARK: - Integration Capability

public enum IntegrationCapability: String, Codable, Sendable {
    case readContent
    case writeContent
    case executeActions
    case captureScreen
    case automateUI
}

// MARK: - Integration Action

public struct IntegrationAction: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let shortcut: IntegrationKeyboardShortcut?

    public init(name: String, description: String, shortcut: IntegrationKeyboardShortcut? = nil) {
        self.name = name
        self.description = description
        self.shortcut = shortcut
    }
}

// MARK: - Keyboard Shortcut

public struct IntegrationKeyboardShortcut: Codable, Sendable {
    public let keyCode: CGKeyCode
    public let modifiers: IntegrationKeyModifiers

    public init(keyCode: CGKeyCode, modifiers: IntegrationKeyModifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Common shortcuts
    public static let copy = IntegrationKeyboardShortcut(keyCode: 8, modifiers: .command) // Cmd+C
    public static let paste = IntegrationKeyboardShortcut(keyCode: 9, modifiers: .command) // Cmd+V
    public static let selectAll = IntegrationKeyboardShortcut(keyCode: 0, modifiers: .command) // Cmd+A
    public static let save = IntegrationKeyboardShortcut(keyCode: 1, modifiers: .command) // Cmd+S
    public static let undo = IntegrationKeyboardShortcut(keyCode: 6, modifiers: .command) // Cmd+Z
}

// MARK: - Key Modifiers

public struct IntegrationKeyModifiers: OptionSet, Codable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = IntegrationKeyModifiers(rawValue: 1 << 0)
    public static let option = IntegrationKeyModifiers(rawValue: 1 << 1)
    public static let control = IntegrationKeyModifiers(rawValue: 1 << 2)
    public static let shift = IntegrationKeyModifiers(rawValue: 1 << 3)
}

// MARK: - Integration Error

public enum IntegrationError: Error, LocalizedError, Sendable {
    case accessibilityNotGranted
    case appNotFound(String)
    case elementNotFound
    case actionFailed(String)
    case notSupported
    case timeout

    public var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            "Accessibility permission is required. Please grant access in System Settings."
        case let .appNotFound(bundleId):
            "Application not found: \(bundleId)"
        case .elementNotFound:
            "UI element not found"
        case let .actionFailed(reason):
            "Action failed: \(reason)"
        case .notSupported:
            "This operation is not supported on this platform"
        case .timeout:
            "Operation timed out"
        }
    }
}
