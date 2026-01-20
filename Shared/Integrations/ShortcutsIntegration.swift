//
//  ShortcutsIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
#endif

// MARK: - Shortcuts Integration

/// Integration module for Shortcuts app
public actor ShortcutsIntegration: IntegrationModule {
    public static let shared = ShortcutsIntegration()

    public let moduleId = "shortcuts"
    public let displayName = "Shortcuts"
    public let bundleIdentifier = "com.apple.shortcuts"
    public let icon = "square.stack.3d.up"

    private var isConnected = false
    private var cachedShortcuts: [ShortcutInfo] = []

    private init() {}

    public func connect() async throws {
        #if os(macOS)
        isConnected = true
        try await refreshShortcutsList()
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    public func disconnect() async {
        isConnected = false
        cachedShortcuts = []
    }

    public func isAvailable() async -> Bool {
        #if os(macOS)
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        #else
        return false
        #endif
    }

    /// Run a shortcut by name
    public func runShortcut(_ name: String, input: String? = nil) async throws -> String? {
        #if os(macOS)
        var command = "shortcuts run '\(name)'"
        if let input = input {
            command += " <<< '\(input)'"
        }

        let result = try await TerminalIntegration.shared.runShellCommand(command)

        if !result.succeeded {
            throw IntegrationModuleError.operationFailed("Shortcut failed: \(result.error)")
        }

        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Get all available shortcuts
    public func getAllShortcuts() async throws -> [ShortcutInfo] {
        try await refreshShortcutsList()
        return cachedShortcuts
    }

    /// Refresh the shortcuts list
    public func refreshShortcutsList() async throws {
        #if os(macOS)
        let result = try await TerminalIntegration.shared.runShellCommand("shortcuts list")

        if !result.succeeded {
            throw IntegrationModuleError.operationFailed("Failed to list shortcuts: \(result.error)")
        }

        cachedShortcuts = result.output
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { ShortcutInfo(name: $0) }
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Open Shortcuts app
    public func openShortcutsApp() async throws {
        #if os(macOS)
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw IntegrationModuleError.appNotInstalled(displayName)
        }
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Open a specific shortcut for editing
    public func editShortcut(_ name: String) async throws {
        #if os(macOS)
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        if let url = URL(string: "shortcuts://open-shortcut?name=\(encodedName)") {
            await MainActor.run {
                NSWorkspace.shared.open(url)
            }
        }
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Create a new shortcut (opens Shortcuts app)
    public func createNewShortcut() async throws {
        #if os(macOS)
        if let url = URL(string: "shortcuts://create-shortcut") {
            await MainActor.run {
                NSWorkspace.shared.open(url)
            }
        }
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Sign a shortcut for sharing
    public func signShortcut(_ name: String, mode: SigningMode = .anyone) async throws -> URL {
        #if os(macOS)
        let tempDir = FileManager.default.temporaryDirectory
        let outputPath = tempDir.appendingPathComponent("\(name).shortcut")

        let modeFlag = mode == .anyone ? "--mode anyone" : "--mode people-who-know-me"
        let command = "shortcuts sign --input '\(name)' --output '\(outputPath.path)' \(modeFlag)"

        let result = try await TerminalIntegration.shared.runShellCommand(command)

        if !result.succeeded {
            throw IntegrationModuleError.operationFailed("Failed to sign shortcut: \(result.error)")
        }

        return outputPath
        #else
        throw IntegrationModuleError.notSupported
        #endif
    }

    public enum SigningMode: String, Sendable {
        case anyone = "anyone"
        case peopleWhoKnowMe = "people-who-know-me"
    }
}

public struct ShortcutInfo: Sendable, Identifiable {
    public var id: String { name }
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

// MARK: - Shortcuts Builder

/// Helper for building complex shortcut automations
public struct ShortcutBuilder {
    private var actions: [ShortcutAction] = []

    public init() {}

    public mutating func addAction(_ action: ShortcutAction) {
        actions.append(action)
    }

    /// Create a sequence of shortcut runs
    public func buildSequence() -> [String] {
        actions.map(\.shortcutName)
    }

    /// Run all shortcuts in sequence
    public func runSequence() async throws -> [String?] {
        var results: [String?] = []
        for action in actions {
            let result = try await ShortcutsIntegration.shared.runShortcut(action.shortcutName, input: action.input)
            results.append(result)
        }
        return results
    }
}

public struct ShortcutAction: Sendable {
    public let shortcutName: String
    public let input: String?

    public init(shortcutName: String, input: String? = nil) {
        self.shortcutName = shortcutName
        self.input = input
    }
}
