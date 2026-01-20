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
    public func executeCommand(_ command: String, inNewWindow: Bool = false) async throws {
        #if os(macOS)
        let windowPart = inNewWindow ? "do script" : "do script in front window"
        let script = """
        tell application "Terminal"
            activate
            \(windowPart) "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        _ = try await executeAppleScript(script)
        #else
        throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Open a new Terminal window at a path
    public func openAtPath(_ path: String) async throws {
        #if os(macOS)
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(path)'"
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
    public func runShellCommand(_ command: String, arguments: [String] = []) async throws -> ShellResult {
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

    #if os(macOS)
    private func executeAppleScript(_ source: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    let result = script.executeAndReturnError(&error)
                    if let error = error {
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
