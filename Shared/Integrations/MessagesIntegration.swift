//
//  MessagesIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
#endif

// MARK: - Messages Integration

/// Integration module for Messages app
public actor MessagesIntegration: AppIntegrationModule {
    public static let shared = MessagesIntegration()

    public let moduleId = "messages"
    public let displayName = "Messages"
    public let bundleIdentifier = "com.apple.MobileSMS"
    public let icon = "message"

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

    /// Send a message
    public func sendMessage(to recipient: String, text: String) async throws {
        #if os(macOS)
            let script = """
            tell application "Messages"
                set targetService to 1st account whose service type = iMessage
                set targetBuddy to participant "\(recipient)" of targetService
                send "\(text)" to targetBuddy
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Open a conversation
    public func openConversation(with participant: String) async throws {
        #if os(macOS)
            let script = """
            tell application "Messages"
                activate
                set targetService to 1st account whose service type = iMessage
                set targetBuddy to participant "\(participant)" of targetService
                set targetChat to make new text chat with properties {participants:{targetBuddy}}
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
