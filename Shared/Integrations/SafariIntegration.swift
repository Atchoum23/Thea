//
//  SafariIntegration.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
    import SafariServices
#endif

// MARK: - Safari Integration

/// Integration module for Safari browser automation
public actor SafariIntegration: AppIntegrationModule {
    public static let shared = SafariIntegration()

    // MARK: - Module Info

    public let moduleId = "safari"
    public let displayName = "Safari"
    public let bundleIdentifier = "com.apple.Safari"
    public let icon = "safari"

    // MARK: - State

    private var isConnected = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Connection

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

    public func disconnect() async {
        isConnected = false
    }

    public func isAvailable() async -> Bool {
        #if os(macOS)
            return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
        #else
            return false
        #endif
    }

    // MARK: - Browser Actions

    /// Get the current URL from Safari
    public func getCurrentURL() async throws -> URL? {
        #if os(macOS)
            let script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of current tab of front window
                end if
            end tell
            """
            let result = try await executeAppleScript(script)
            return result.flatMap { URL(string: $0) }
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get the page title
    public func getCurrentPageTitle() async throws -> String? {
        #if os(macOS)
            let script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return name of current tab of front window
                end if
            end tell
            """
            return try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Navigate to a URL
    public func navigateTo(_ url: URL) async throws {
        #if os(macOS)
            let script = """
            tell application "Safari"
                if (count of windows) = 0 then
                    make new document
                end if
                set URL of current tab of front window to "\(url.absoluteString)"
                activate
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Open a new tab
    public func openNewTab(with url: URL? = nil) async throws {
        #if os(macOS)
            let urlPart = url.map { "set URL of newTab to \"\($0.absoluteString)\"" } ?? ""
            let script = """
            tell application "Safari"
                if (count of windows) = 0 then
                    make new document
                else
                    tell front window
                        set newTab to make new tab
                        \(urlPart)
                    end tell
                end if
                activate
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get all open tabs
    public func getAllTabs() async throws -> [BrowserTab] {
        #if os(macOS)
            let script = """
            tell application "Safari"
                set tabList to {}
                repeat with w in windows
                    repeat with t in tabs of w
                        set end of tabList to {URL of t, name of t}
                    end repeat
                end repeat
                return tabList
            end tell
            """

            // Parse the result - simplified implementation
            let result = try await executeAppleScript(script)
            guard let resultString = result else { return [] }

            // Parse AppleScript list result
            var tabs: [BrowserTab] = []
            // Basic parsing - would need more robust parsing in production
            let components = resultString.components(separatedBy: ", ")
            for i in stride(from: 0, to: components.count - 1, by: 2) {
                if let url = URL(string: components[i].trimmingCharacters(in: CharacterSet(charactersIn: "{}"))) {
                    let title = i + 1 < components.count ? components[i + 1].trimmingCharacters(in: CharacterSet(charactersIn: "{}")) : ""
                    tabs.append(BrowserTab(url: url, title: title))
                }
            }
            return tabs
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Execute JavaScript in current tab
    public func executeJavaScript(_ script: String) async throws -> String? {
        #if os(macOS)
            let escapedScript = script.replacingOccurrences(of: "\"", with: "\\\"")
            let appleScript = """
            tell application "Safari"
                do JavaScript "\(escapedScript)" in current tab of front window
            end tell
            """
            return try await executeAppleScript(appleScript)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    /// Get page source
    public func getPageSource() async throws -> String? {
        try await executeJavaScript("document.documentElement.outerHTML")
    }

    /// Search on current page
    public func searchPage(for text: String) async throws {
        #if os(macOS)
            let script = """
            tell application "Safari"
                activate
                tell application "System Events"
                    keystroke "f" using command down
                    delay 0.2
                    keystroke "\(text)"
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Reading Mode

    /// Enter reader mode
    public func enterReaderMode() async throws {
        #if os(macOS)
            let script = """
            tell application "Safari"
                activate
                tell application "System Events"
                    keystroke "r" using {command down, shift down}
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Bookmarks

    /// Bookmark current page
    public func bookmarkCurrentPage() async throws {
        #if os(macOS)
            let script = """
            tell application "Safari"
                activate
                tell application "System Events"
                    keystroke "d" using command down
                end tell
            end tell
            """
            _ = try await executeAppleScript(script)
        #else
            throw AppIntegrationModuleError.notSupported
        #endif
    }

    // MARK: - Helper Methods

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

// MARK: - Browser Tab

public struct BrowserTab: Sendable, Identifiable {
    public let id = UUID()
    public let url: URL
    public let title: String

    public init(url: URL, title: String) {
        self.url = url
        self.title = title
    }
}
