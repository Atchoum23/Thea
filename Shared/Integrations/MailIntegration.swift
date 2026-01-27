//
//  MailIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
#endif

// MARK: - Mail Integration

/// Integration module for Mail app
/// Security: All user inputs are properly escaped for AppleScript
public actor MailIntegration: AppIntegrationModule {
    public static let shared = MailIntegration()

    public let moduleId = "mail"
    public let displayName = "Mail"
    public let bundleIdentifier = "com.apple.mail"
    public let icon = "envelope"

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

    /// Compose a new email
    /// - Parameters:
    ///   - to: Array of email addresses (validated)
    ///   - subject: Email subject (safely escaped)
    ///   - body: Email body (safely escaped)
    ///   - attachments: Array of file URLs (validated)
    public func composeEmail(to: [String], subject: String, body: String, attachments: [URL] = []) async throws {
        #if os(macOS)
            // Validate email addresses
            for email in to {
                try validateEmailAddress(email)
            }

            // Validate attachments exist
            for url in attachments {
                try validateAttachmentPath(url)
            }

            // Build attachment script with proper escaping
            var attachmentLines: [String] = []
            for url in attachments {
                let escapedPath = escapeForAppleScript(url.path)
                attachmentLines.append("make new attachment with properties {file name:POSIX file \(escapedPath)} at after the last paragraph")
            }
            let attachmentScript = attachmentLines.joined(separator: "\n")

            // Build recipient script
            let recipientLines = to.map { email in
                "make new to recipient at end of to recipients with properties {address:\(escapeForAppleScript(email))}"
            }
            let recipientScript = recipientLines.joined(separator: "\n")

            // Build the full script with escaped values
            let escapedSubject = escapeForAppleScript(subject)
            let escapedBody = escapeForAppleScript(body)

            let script = """
            tell application "Mail"
                set newMessage to make new outgoing message with properties {subject:\(escapedSubject), content:\(escapedBody), visible:true}
                tell newMessage
                    \(recipientScript)
                    \(attachmentScript)
                end tell
                activate
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get unread message count
    public func getUnreadCount() async throws -> Int {
        #if os(macOS)
            let script = """
            tell application "Mail"
                return unread count of inbox
            end tell
            """
            let result = try await executeAppleScript(script)
            return Int(result ?? "0") ?? 0
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Check for new mail
    public func checkForNewMail() async throws {
        #if os(macOS)
            let script = """
            tell application "Mail"
                check for new mail
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Security Helpers

    /// Escape a string for safe use in AppleScript
    /// Returns a properly quoted AppleScript string literal
    private func escapeForAppleScript(_ input: String) -> String {
        var escaped = input
        // Escape backslashes first, then quotes
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        // Prevent newline/carriage return injection
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        escaped = escaped.replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    /// Validate email address format
    private func validateEmailAddress(_ email: String) throws {
        // Basic email validation
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard let regex = try? NSRegularExpression(pattern: emailRegex),
              regex.firstMatch(in: email, range: NSRange(email.startIndex..., in: email)) != nil
        else {
            throw AppIntegrationModuleError.invalidInput("Invalid email address format: \(email)")
        }

        // Check for injection attempts
        guard !email.contains("\n"), !email.contains("\r"), !email.contains("\0") else {
            throw AppIntegrationModuleError.securityError("Invalid characters in email address")
        }
    }

    /// Validate attachment path exists and is safe
    private func validateAttachmentPath(_ url: URL) throws {
        let path = url.path

        // Check for null bytes
        guard !path.contains("\0") else {
            throw AppIntegrationModuleError.securityError("Null byte detected in attachment path")
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw AppIntegrationModuleError.invalidPath("Attachment does not exist: \(path)")
        }

        // Verify it's a file, not a directory
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        guard !isDirectory.boolValue else {
            throw AppIntegrationModuleError.invalidPath("Attachment path is a directory, not a file")
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
