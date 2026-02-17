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
/// Security: All command-line parameters are passed via Process arguments array
public actor ShortcutsIntegration: AppIntegrationModule {
    public static let shared = ShortcutsIntegration()

    public let moduleId = "shortcuts"
    public let displayName = "Shortcuts"
    public let bundleIdentifier = "com.apple.shortcuts"
    public let icon = "square.stack.3d.up"

    private var isConnected = false
    private var cachedShortcuts: [ShortcutInfo] = []

    private init() {}

    /// Activates the Shortcuts integration and refreshes the available shortcuts list (macOS only).
    public func connect() async throws {
        #if os(macOS)
            isConnected = true
            try await refreshShortcutsList()
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Disconnects and clears the cached shortcuts list.
    public func disconnect() async {
        isConnected = false
        cachedShortcuts = []
    }

    /// Returns whether the Shortcuts app is installed.
    public func isAvailable() async -> Bool {
        #if os(macOS)
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        #else
            return false
        #endif
    }

    /// Run a shortcut by name
    /// - Parameters:
    ///   - name: Name of the shortcut (validated)
    ///   - input: Optional input text to pass to the shortcut
    /// - Returns: Output from the shortcut, if any
    public func runShortcut(_ name: String, input: String? = nil) async throws -> String? {
        #if os(macOS)
            // Validate shortcut name
            try validateShortcutName(name)

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // If input is provided, pass it via stdin
            if let _ = input {
                process.standardInput = inputPipe
            }

            try process.run()

            // Write input if provided
            if let inputText = input {
                let inputData = inputText.data(using: .utf8) ?? Data()
                inputPipe.fileHandleForWriting.write(inputData)
                inputPipe.fileHandleForWriting.closeFile()
            }

            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if process.terminationStatus != 0 {
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw AppIntegrationModuleError.operationFailed("Shortcut failed: \(errorMessage)")
            }

            let output = String(data: outputData, encoding: .utf8) ?? ""
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
            throw AppIntegrationModuleError.notSupported
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
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw AppIntegrationModuleError.operationFailed("Failed to list shortcuts: \(errorMessage)")
            }

            cachedShortcuts = output
                .components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
                .map { ShortcutInfo(name: $0) }
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Open Shortcuts app
    public func openShortcutsApp() async throws {
        #if os(macOS)
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                throw AppIntegrationModuleError.appNotInstalled(displayName)
            }
            await MainActor.run {
                _ = NSWorkspace.shared.open(url)
            }
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Open a specific shortcut for editing
    /// - Parameter name: Name of the shortcut (validated and URL-encoded)
    public func editShortcut(_ name: String) async throws {
        #if os(macOS)
            try validateShortcutName(name)
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
            if let url = URL(string: "shortcuts://open-shortcut?name=\(encodedName)") {
                await MainActor.run {
                    _ = NSWorkspace.shared.open(url)
                }
            }
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Create a new shortcut (opens Shortcuts app)
    public func createNewShortcut() async throws {
        #if os(macOS)
            if let url = URL(string: "shortcuts://create-shortcut") {
                await MainActor.run {
                    _ = NSWorkspace.shared.open(url)
                }
            }
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Sign a shortcut for sharing
    /// - Parameters:
    ///   - name: Name of the shortcut (validated)
    ///   - mode: Signing mode (anyone or people-who-know-me)
    /// - Returns: URL to the signed shortcut file
    public func signShortcut(_ name: String, mode: SigningMode = .anyone) async throws -> URL {
        #if os(macOS)
            // Validate shortcut name
            try validateShortcutName(name)

            let tempDir = FileManager.default.temporaryDirectory
            // Use UUID to avoid path injection through name
            let safeFilename = UUID().uuidString + ".shortcut"
            let outputPath = tempDir.appendingPathComponent(safeFilename)

            let process = Process()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["sign", "--input", name, "--output", outputPath.path, "--mode", mode.rawValue]
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw AppIntegrationModuleError.operationFailed("Failed to sign shortcut: \(errorMessage)")
            }

            return outputPath
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Security Validation

    /// Validate shortcut name doesn't contain injection attempts
    private func validateShortcutName(_ name: String) throws {
        // Check for empty name
        guard !name.isEmpty else {
            throw AppIntegrationModuleError.invalidInput("Shortcut name cannot be empty")
        }

        // Check for reasonable length
        guard name.count < 256 else {
            throw AppIntegrationModuleError.invalidInput("Shortcut name too long")
        }

        // Check for null bytes
        guard !name.contains("\0") else {
            throw AppIntegrationModuleError.securityError("Null byte detected in shortcut name")
        }

        // Check for newlines (potential injection)
        guard !name.contains("\n"), !name.contains("\r") else {
            throw AppIntegrationModuleError.securityError("Newline detected in shortcut name")
        }
    }

    public enum SigningMode: String, Sendable {
        case anyone
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

/// Represents a shortcut to run with optional input
public struct ShortcutRunItem: Sendable {
    public let shortcutName: String
    public let input: String?

    public init(shortcutName: String, input: String? = nil) {
        self.shortcutName = shortcutName
        self.input = input
    }
}

/// Helper for building complex shortcut automations
public struct ShortcutBuilder {
    private var actions: [ShortcutRunItem] = []

    public init() {}

    /// Appends a shortcut run item to the builder's action sequence.
    public mutating func addAction(_ action: ShortcutRunItem) {
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
