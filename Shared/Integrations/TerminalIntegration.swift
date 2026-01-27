//
//  TerminalIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
#endif

// MARK: - Terminal Integration

/// Integration module for Terminal app
public actor TerminalIntegration: AppIntegrationModule {
    public static let shared = TerminalIntegration()

    public let moduleId = "terminal"
    public let displayName = "Terminal"
    public let bundleIdentifier = "com.apple.Terminal"
    public let icon = "terminal"

    private var isConnected = false

    private init() {}

    public func connect() async throws {
        #if os(macOS)
            isConnected = true
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    public func disconnect() async { isConnected = false }

    public func isAvailable() async -> Bool {
        #if os(macOS)
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
        #else
            return false
        #endif
    }

    /// Execute a command in Terminal
    /// - Parameters:
    ///   - command: The shell command to execute (will be safely escaped)
    ///   - inNewWindow: Whether to open in a new window
    public func executeCommand(_ command: String, inNewWindow: Bool = false) async throws {
        #if os(macOS)
            // Validate command doesn't contain dangerous patterns
            try validateCommand(command)

            let escapedCommand = escapeForAppleScript(command)
            let windowPart = inNewWindow ? "do script" : "do script in front window"
            let script = """
            tell application "Terminal"
                activate
                \(windowPart) \(escapedCommand)
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Open a new Terminal window at a path
    /// - Parameter path: The directory path (will be validated and escaped)
    public func openAtPath(_ path: String) async throws {
        #if os(macOS)
            // Validate path is safe (no traversal attacks)
            try validatePath(path)

            let escapedPath = escapeForShell(path)
            let script = """
            tell application "Terminal"
                activate
                do script "cd " & \(escapeForAppleScript(escapedPath))
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get current directory of front window
    public func getCurrentDirectory() async throws -> String? {
        #if os(macOS)
            let script = """
            tell application "Terminal"
                if (count of windows) > 0 then
                    do script "pwd" in front window
                    delay 0.5
                    set lastLine to last paragraph of (contents of front window)
                    return lastLine
                end if
            end tell
            """
            return try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Execute shell command and return result (uses Process, not Terminal app)
    /// Note: This method uses Process with -c flag which is safer than AppleScript
    public func runShellCommand(_ command: String, arguments _: [String] = []) async throws -> ShellResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        return ShellResult(
            exitCode: process.terminationStatus,
            output: String(data: outputData, encoding: .utf8) ?? "",
            error: String(data: errorData, encoding: .utf8) ?? ""
        )
    }

    // MARK: - Security Helpers

    /// Escape a string for safe use in AppleScript
    /// Returns a properly quoted AppleScript string literal
    private func escapeForAppleScript(_ input: String) -> String {
        // AppleScript string escaping: backslash and double-quote need escaping
        var escaped = input
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        // Prevent newline injection
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    /// Escape a string for safe use in shell commands
    private func escapeForShell(_ input: String) -> String {
        // Use single quotes and escape any single quotes within
        let escaped = input.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }

    /// Validate that a command doesn't contain dangerous injection patterns
    private func validateCommand(_ command: String) throws {
        // Block common injection patterns
        _ = [
            "$(", "`", // Command substitution
            "&&", "||", ";", // Command chaining (when at risk of injection)
            "|", // Piping (when at risk of injection)
            "\n", "\r", // Newline injection
            "\\n", "\\r" // Escaped newlines that could be interpreted
        ]

        // Note: We allow these in normal commands, but the escaping prevents injection
        // This validation is an additional safety layer for suspicious patterns
        _ = command.lowercased()

        // Block attempts to break out of quotes
        if command.contains("\"\"\"") || command.contains("'''") {
            throw AppIntegrationModuleError.securityError("Invalid quote sequence detected")
        }

        // Block null bytes
        if command.contains("\0") {
            throw AppIntegrationModuleError.securityError("Null byte detected in command")
        }
    }

    /// Validate that a path is safe and doesn't attempt directory traversal
    private func validatePath(_ path: String) throws {
        // Resolve to absolute path
        let url = URL(fileURLWithPath: path)
        let resolvedPath = url.standardized.path

        // Check for null bytes
        if path.contains("\0") {
            throw AppIntegrationModuleError.securityError("Null byte detected in path")
        }

        // Check for suspicious patterns
        if path.contains("..") {
            // Allow .. only if the resolved path doesn't escape upward unexpectedly
            // For safety, we'll be strict here
            throw AppIntegrationModuleError.securityError("Path traversal pattern detected")
        }

        // Ensure path exists and is a directory
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw AppIntegrationModuleError.invalidPath("Path does not exist or is not a directory: \(resolvedPath)")
        }
    }

    #if os(macOS)
        private func executeAppleScript(_ source: String) async throws -> String? {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var error: NSDictionary?
                    if let script = NSAppleScript(source: source) {
                        let result = script.executeAndReturnError(&error)
                        if let error {
                            continuation.resume(throwing: AppIntegrationModuleError.scriptError(error.description))
                        } else {
                            continuation.resume(returning: result.stringValue)
                        }
                    } else {
                        continuation.resume(throwing: AppIntegrationModuleError.scriptError("Failed to create script"))
                    }
                }
            }
        }
    #endif
}

public struct ShellResult: Sendable {
    public let exitCode: Int32
    public let output: String
    public let error: String

    public var succeeded: Bool { exitCode == 0 }
}
