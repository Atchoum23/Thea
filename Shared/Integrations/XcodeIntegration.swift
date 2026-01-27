//
//  XcodeIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
#endif

// MARK: - Xcode Integration

/// Integration module for Xcode
/// Security: All command-line parameters are validated and passed via Process arguments array
public actor XcodeIntegration: AppIntegrationModule {
    public static let shared = XcodeIntegration()

    public let moduleId = "xcode"
    public let displayName = "Xcode"
    public let bundleIdentifier = "com.apple.dt.Xcode"
    public let icon = "hammer"

    private var isConnected = false

    private init() {}

    public func connect() async throws {
        #if os(macOS)
            guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else {
                throw AppIntegrationModuleError.appNotRunning(displayName)
            }
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

    /// Open a project/workspace
    public func openProject(_ path: String) async throws {
        #if os(macOS)
            // Validate path exists
            try validatePath(path)
            let url = URL(fileURLWithPath: path)
            await MainActor.run {
                _ = NSWorkspace.shared.open(url)
            }
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Build the current project
    public func buildProject() async throws {
        #if os(macOS)
            let script = """
            tell application "Xcode"
                activate
                tell application "System Events"
                    keystroke "b" using command down
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Run the current scheme
    public func runProject() async throws {
        #if os(macOS)
            let script = """
            tell application "Xcode"
                activate
                tell application "System Events"
                    keystroke "r" using command down
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Stop the current task
    public func stopTask() async throws {
        #if os(macOS)
            let script = """
            tell application "Xcode"
                activate
                tell application "System Events"
                    keystroke "." using command down
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get the current project path
    public func getCurrentProjectPath() async throws -> String? {
        #if os(macOS)
            let script = """
            tell application "Xcode"
                if (count of workspace documents) > 0 then
                    return path of front workspace document
                end if
            end tell
            """
            return try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Open a file in Xcode
    /// - Parameters:
    ///   - path: Path to the file (validated)
    ///   - line: Optional line number to navigate to
    public func openFile(_ path: String, line: Int? = nil) async throws {
        #if os(macOS)
            // Validate path
            try validatePath(path)

            // Use open command with arguments array (safer than shell string)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Xcode", path]

            try process.run()
            process.waitUntilExit()

            // Note: line navigation via command line isn't directly supported
            // The user can navigate manually or we could use AppleScript to go to line
            if let targetLine = line {
                // Give Xcode time to open the file
                try await Task.sleep(nanoseconds: 500_000_000)
                try await goToLine(targetLine)
            }
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Navigate to a specific line in the current file
    private func goToLine(_ line: Int) async throws {
        #if os(macOS)
            // Validate line number is reasonable
            guard line > 0, line < 1_000_000 else {
                throw AppIntegrationModuleError.invalidInput("Invalid line number: \(line)")
            }

            let script = """
            tell application "Xcode"
                activate
                tell application "System Events"
                    keystroke "l" using command down
                    delay 0.2
                    keystroke "\(line)"
                    keystroke return
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #endif
    }

    /// Run tests
    public func runTests() async throws {
        #if os(macOS)
            let script = """
            tell application "Xcode"
                activate
                tell application "System Events"
                    keystroke "u" using command down
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Clean build folder
    public func cleanBuildFolder() async throws {
        #if os(macOS)
            let script = """
            tell application "Xcode"
                activate
                tell application "System Events"
                    keystroke "k" using {command down, shift down}
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Build using xcodebuild CLI
    /// Security: Uses Process with arguments array instead of shell string interpolation
    public func buildWithXcodebuild(scheme: String, configuration: String = "Debug", projectPath: String) async throws -> XcodeBuildResult {
        #if os(macOS)
            // Validate inputs
            try validateScheme(scheme)
            try validateConfiguration(configuration)
            try validatePath(projectPath)

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")

            // Build arguments array (safe from injection)
            var arguments: [String] = []
            if projectPath.hasSuffix(".xcworkspace") {
                arguments.append(contentsOf: ["-workspace", projectPath])
            } else {
                arguments.append(contentsOf: ["-project", projectPath])
            }
            arguments.append(contentsOf: ["-scheme", scheme])
            arguments.append(contentsOf: ["-configuration", configuration])
            arguments.append("build")

            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = (String(data: outputData, encoding: .utf8) ?? "") +
                (String(data: errorData, encoding: .utf8) ?? "")

            return XcodeBuildResult(
                succeeded: process.terminationStatus == 0,
                output: output,
                errors: parseErrors(from: output),
                warnings: parseWarnings(from: output)
            )
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    private func parseErrors(from output: String) -> [XcodeBuildIssue] {
        var issues: [XcodeBuildIssue] = []
        let pattern = #"(.+):(\d+):(\d+): error: (.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return issues }

        let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
        for match in matches {
            if let fileRange = Range(match.range(at: 1), in: output),
               let lineRange = Range(match.range(at: 2), in: output),
               let messageRange = Range(match.range(at: 4), in: output)
            {
                issues.append(XcodeBuildIssue(
                    type: .error,
                    file: String(output[fileRange]),
                    line: Int(output[lineRange]) ?? 0,
                    message: String(output[messageRange])
                ))
            }
        }
        return issues
    }

    private func parseWarnings(from output: String) -> [XcodeBuildIssue] {
        var issues: [XcodeBuildIssue] = []
        let pattern = #"(.+):(\d+):(\d+): warning: (.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return issues }

        let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
        for match in matches {
            if let fileRange = Range(match.range(at: 1), in: output),
               let lineRange = Range(match.range(at: 2), in: output),
               let messageRange = Range(match.range(at: 4), in: output)
            {
                issues.append(XcodeBuildIssue(
                    type: .warning,
                    file: String(output[fileRange]),
                    line: Int(output[lineRange]) ?? 0,
                    message: String(output[messageRange])
                ))
            }
        }
        return issues
    }

    // MARK: - Security Validation

    /// Validate that a path exists and doesn't contain injection attempts
    private func validatePath(_ path: String) throws {
        // Check for null bytes
        guard !path.contains("\0") else {
            throw AppIntegrationModuleError.securityError("Null byte detected in path")
        }

        // Resolve to canonical path to prevent traversal
        let url = URL(fileURLWithPath: path)
        let resolvedPath = url.standardized.path

        // Verify the path exists
        guard FileManager.default.fileExists(atPath: resolvedPath) else {
            throw AppIntegrationModuleError.invalidPath("Path does not exist: \(resolvedPath)")
        }
    }

    /// Validate scheme name contains only safe characters
    private func validateScheme(_ scheme: String) throws {
        // Scheme names should only contain alphanumeric, dash, underscore, space
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        guard scheme.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw AppIntegrationModuleError.invalidInput("Invalid characters in scheme name")
        }

        guard !scheme.isEmpty, scheme.count < 256 else {
            throw AppIntegrationModuleError.invalidInput("Invalid scheme name length")
        }
    }

    /// Validate configuration name
    private func validateConfiguration(_ configuration: String) throws {
        // Standard configurations are Debug, Release, or custom alphanumeric names
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard configuration.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            throw AppIntegrationModuleError.invalidInput("Invalid characters in configuration name")
        }

        guard !configuration.isEmpty, configuration.count < 64 else {
            throw AppIntegrationModuleError.invalidInput("Invalid configuration name length")
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

public struct XcodeBuildResult: Sendable {
    public let succeeded: Bool
    public let output: String
    public let errors: [XcodeBuildIssue]
    public let warnings: [XcodeBuildIssue]
}

public struct XcodeBuildIssue: Sendable, Identifiable {
    public let id = UUID()
    public let type: IssueType
    public let file: String
    public let line: Int
    public let message: String

    public enum IssueType: String, Sendable {
        case error
        case warning
    }
}
