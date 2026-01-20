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
    public func composeEmail(to: [String], subject: String, body: String, attachments: [URL] = []) async throws {
        #if os(macOS)
        var attachmentScript = ""
        for url in attachments {
            attachmentScript += "make new attachment with properties {file name:POSIX file \"\(url.path)\"} at after the last paragraph\n"
        }

        let script = """
        tell application "Mail"
            set newMessage to make new outgoing message with properties {subject:"\(subject)", content:"\(body)", visible:true}
            tell newMessage
                \(to.map { "make new to recipient at end of to recipients with properties {address:\"\($0)\"}" }.joined(separator: "\n"))
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
