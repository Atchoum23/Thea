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
public actor XcodeIntegration: IntegrationModule {
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
            throw IntegrationModuleError.appNotRunning(displayName)
        }
        isConnected = true
        #else
        throw IntegrationModuleError.notSupported
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
        let url = URL(fileURLWithPath: path)
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        #else
        throw IntegrationModuleError.notSupported
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
        throw IntegrationModuleError.notSupported
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
        throw IntegrationModuleError.notSupported
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
        throw IntegrationModuleError.notSupported
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
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Open a file in Xcode
    public func openFile(_ path: String, line: Int? = nil) async throws {
        #if os(macOS)
        let lineArg = line.map { " line=\($0)" } ?? ""
        let script = """
        do shell script "open -a Xcode '\(path)'\(lineArg)"
        """
        _ = try await executeAppleScript(script)
        #else
        throw IntegrationModuleError.notSupported
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
        throw IntegrationModuleError.notSupported
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
        throw IntegrationModuleError.notSupported
        #endif
    }

    /// Build using xcodebuild CLI
    public func buildWithXcodebuild(scheme: String, configuration: String = "Debug", projectPath: String) async throws -> XcodeBuildResult {
        let command: String
        if projectPath.hasSuffix(".xcworkspace") {
            command = "xcodebuild -workspace '\(projectPath)' -scheme '\(scheme)' -configuration \(configuration) build 2>&1"
        } else {
            command = "xcodebuild -project '\(projectPath)' -scheme '\(scheme)' -configuration \(configuration) build 2>&1"
        }

        let result = try await TerminalIntegration.shared.runShellCommand(command)

        return XcodeBuildResult(
            succeeded: result.succeeded,
            output: result.output,
            errors: parseErrors(from: result.output),
            warnings: parseWarnings(from: result.output)
        )
    }

    private func parseErrors(from output: String) -> [XcodeBuildIssue] {
        var issues: [XcodeBuildIssue] = []
        let pattern = #"(.+):(\d+):(\d+): error: (.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return issues }

        let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
        for match in matches {
            if let fileRange = Range(match.range(at: 1), in: output),
               let lineRange = Range(match.range(at: 2), in: output),
               let messageRange = Range(match.range(at: 4), in: output) {
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
               let messageRange = Range(match.range(at: 4), in: output) {
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

    #if os(macOS)
    private func executeAppleScript(_ source: String) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    let result = script.executeAndReturnError(&error)
                    if let error = error {
                        continuation.resume(throwing: IntegrationModuleError.scriptError(error.description))
                    } else {
                        continuation.resume(returning: result.stringValue)
                    }
                } else {
                    continuation.resume(throwing: IntegrationModuleError.scriptError("Failed to create script"))
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
