//
//  ClaudeAppBridge.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
import ApplicationServices

// MARK: - Claude App Bridge

/// Bridge to interact with the Claude.app desktop application
/// Enables reading, writing, and prompting Claude directly
@MainActor
public class ClaudeAppBridge: ObservableObject {
    public static let shared = ClaudeAppBridge()
    
    // MARK: - Published State
    
    @Published public private(set) var isClaudeInstalled = false
    @Published public private(set) var isClaudeRunning = false
    @Published public private(set) var currentConversationId: String?
    @Published public private(set) var lastError: ClaudeBridgeError?
    
    // MARK: - Constants
    
    private let claudeBundleId = "com.anthropic.claudefordesktop"
    private let claudeAppName = "Claude"
    
    // MARK: - Initialization
    
    private init() {
        checkClaudeInstallation()
        setupAppMonitoring()
    }
    
    // MARK: - App Detection
    
    private func checkClaudeInstallation() {
        let workspace = NSWorkspace.shared
        isClaudeInstalled = workspace.urlForApplication(withBundleIdentifier: claudeBundleId) != nil
    }
    
    private func setupAppMonitoring() {
        // Monitor for Claude app launch/quit
        let workspace = NSWorkspace.shared
        
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == self?.claudeBundleId else { return }
            self?.isClaudeRunning = true
        }
        
        workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == self?.claudeBundleId else { return }
            self?.isClaudeRunning = false
        }
        
        // Check current state
        isClaudeRunning = workspace.runningApplications.contains { $0.bundleIdentifier == claudeBundleId }
    }
    
    // MARK: - App Control
    
    /// Launch Claude.app
    public func launchClaude() async throws {
        guard isClaudeInstalled else {
            throw ClaudeBridgeError.claudeNotInstalled
        }
        
        let workspace = NSWorkspace.shared
        guard let claudeURL = workspace.urlForApplication(withBundleIdentifier: claudeBundleId) else {
            throw ClaudeBridgeError.claudeNotInstalled
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        try await workspace.openApplication(at: claudeURL, configuration: configuration)
        
        // Wait for app to be ready
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isClaudeRunning = true
    }
    
    /// Bring Claude.app to foreground
    public func activateClaude() throws {
        guard isClaudeRunning else {
            throw ClaudeBridgeError.claudeNotRunning
        }
        
        guard let claudeApp = NSRunningApplication.runningApplications(
            withBundleIdentifier: claudeBundleId
        ).first else {
            throw ClaudeBridgeError.claudeNotRunning
        }
        
        claudeApp.activate(options: [.activateIgnoringOtherApps])
    }
    
    // MARK: - Send Prompt
    
    /// Send a prompt to Claude.app via AppleScript/Accessibility
    public func sendPrompt(_ prompt: String) async throws -> String {
        if !isClaudeRunning {
            try await launchClaude()
        }
        
        // Activate Claude
        try activateClaude()
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Use AppleScript to interact with Claude
        let script = """
        tell application "Claude"
            activate
        end tell
        
        delay 0.5
        
        tell application "System Events"
            tell process "Claude"
                -- Find the input field and type
                keystroke "a" using {command down}
                keystroke "\(prompt.replacingOccurrences(of: "\"", with: "\\\""))"
                keystroke return
            end tell
        end tell
        """
        
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw ClaudeBridgeError.scriptError("Failed to create AppleScript")
        }
        
        appleScript.executeAndReturnError(&error)
        
        if let error = error {
            throw ClaudeBridgeError.scriptError(error.description)
        }
        
        // Wait for response (this is a simplified version - real implementation would monitor for response)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        return "Prompt sent to Claude.app"
    }
    
    /// Read current conversation from Claude.app
    public func readCurrentConversation() async throws -> ClaudeConversation {
        guard isClaudeRunning else {
            throw ClaudeBridgeError.claudeNotRunning
        }
        
        // Use Accessibility API to read conversation
        guard let claudeApp = NSRunningApplication.runningApplications(
            withBundleIdentifier: claudeBundleId
        ).first else {
            throw ClaudeBridgeError.claudeNotRunning
        }
        
        let pid = claudeApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get the main window
        var windowRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &windowRef)
        
        guard windowResult == .success, let window = windowRef else {
            throw ClaudeBridgeError.accessibilityError("Cannot access Claude window")
        }
        
        // Extract conversation content (simplified - real implementation would traverse UI hierarchy)
        // swiftlint:disable:next force_cast
        let messages = try extractMessages(from: window as! AXUIElement)
        
        return ClaudeConversation(
            id: currentConversationId ?? UUID().uuidString,
            title: "Claude Conversation",
            messages: messages,
            lastUpdated: Date()
        )
    }
    
    private func extractMessages(from element: AXUIElement) throws -> [ClaudeMessage] {
        // Traverse UI hierarchy to find message elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let childArray = children as? [AXUIElement] else {
            return []
        }
        
        var messages: [ClaudeMessage] = []
        
        for child in childArray {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
            
            if let roleString = role as? String, roleString == "AXStaticText" {
                var value: CFTypeRef?
                AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &value)
                
                if let text = value as? String, !text.isEmpty {
                    messages.append(ClaudeMessage(
                        role: messages.count % 2 == 0 ? .user : .assistant,
                        content: text,
                        timestamp: Date()
                    ))
                }
            }
            
            // Recursively check children
            messages.append(contentsOf: try extractMessages(from: child))
        }
        
        return messages
    }
    
    // MARK: - New Conversation
    
    /// Start a new conversation in Claude.app
    public func startNewConversation(withPrompt prompt: String? = nil) async throws {
        if !isClaudeRunning {
            try await launchClaude()
        }
        
        try activateClaude()
        
        // Use keyboard shortcut for new conversation
        let script = """
        tell application "System Events"
            tell process "Claude"
                keystroke "n" using {command down}
            end tell
        end tell
        """
        
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw ClaudeBridgeError.scriptError("Failed to create AppleScript")
        }
        
        appleScript.executeAndReturnError(&error)
        
        if let error = error {
            throw ClaudeBridgeError.scriptError(error.description)
        }
        
        currentConversationId = UUID().uuidString
        
        if let prompt = prompt {
            try await Task.sleep(nanoseconds: 500_000_000)
            _ = try await sendPrompt(prompt)
        }
    }
    
    // MARK: - Copy Response
    
    /// Copy the last response from Claude.app
    public func copyLastResponse() async throws -> String {
        guard isClaudeRunning else {
            throw ClaudeBridgeError.claudeNotRunning
        }
        
        try activateClaude()
        
        // Use AppleScript to copy last response
        let script = """
        tell application "System Events"
            tell process "Claude"
                -- Navigate to last response and copy
                keystroke "c" using {command down, shift down}
            end tell
        end tell
        
        delay 0.3
        
        the clipboard
        """
        
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw ClaudeBridgeError.scriptError("Failed to create AppleScript")
        }
        
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            throw ClaudeBridgeError.scriptError(error.description)
        }
        
        return result.stringValue ?? ""
    }
    
    // MARK: - MCP Server Connection
    
    /// Check if Claude.app has MCP servers configured
    public func getMCPServers() async throws -> [ClaudeMCPServer] {
        // Read from Claude's config file
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return []
        }
        
        let data = try Data(contentsOf: configPath)
        let config = try JSONDecoder().decode(ClaudeDesktopConfig.self, from: data)
        
        return config.mcpServers.map { name, server in
            ClaudeMCPServer(
                name: name,
                command: server.command,
                args: server.args ?? [],
                env: server.env ?? [:]
            )
        }
    }
    
    /// Add an MCP server to Claude.app configuration
    public func addMCPServer(_ server: ClaudeMCPServer) async throws {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
        
        var config: ClaudeDesktopConfig
        
        if FileManager.default.fileExists(atPath: configPath.path) {
            let data = try Data(contentsOf: configPath)
            config = try JSONDecoder().decode(ClaudeDesktopConfig.self, from: data)
        } else {
            config = ClaudeDesktopConfig(mcpServers: [:])
        }
        
        config.mcpServers[server.name] = MCPServerConfig(
            command: server.command,
            args: server.args,
            env: server.env
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        
        // Create directory if needed
        try FileManager.default.createDirectory(
            at: configPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        try data.write(to: configPath)
    }
}

// MARK: - Data Models

public struct ClaudeConversation: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let messages: [ClaudeMessage]
    public let lastUpdated: Date
}

public struct ClaudeMessage: Identifiable, Sendable {
    public let id = UUID()
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    
    public enum MessageRole: String, Sendable {
        case user
        case assistant
    }
}

public struct ClaudeMCPServer: Identifiable, Codable, Sendable {
    public var id: String { name }
    public let name: String
    public let command: String
    public let args: [String]
    public let env: [String: String]
    
    public init(name: String, command: String, args: [String] = [], env: [String: String] = [:]) {
        self.name = name
        self.command = command
        self.args = args
        self.env = env
    }
}

public struct ClaudeDesktopConfig: Codable {
    public var mcpServers: [String: MCPServerConfig]
}

public struct MCPServerConfig: Codable {
    public let command: String
    public let args: [String]?
    public let env: [String: String]?
}

// MARK: - Errors

public enum ClaudeBridgeError: Error, LocalizedError {
    case claudeNotInstalled
    case claudeNotRunning
    case accessibilityError(String)
    case scriptError(String)
    case configurationError(String)
    case notSupported

    public var errorDescription: String? {
        switch self {
        case .claudeNotInstalled:
            return "Claude.app is not installed. Please install it from claude.ai"
        case .claudeNotRunning:
            return "Claude.app is not running"
        case .accessibilityError(let message):
            return "Accessibility error: \(message)"
        case .scriptError(let message):
            return "Script error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .notSupported:
            return "Claude.app integration is only available on macOS"
        }
    }
}

#else
// iOS/tvOS/watchOS stub
@MainActor
public class ClaudeAppBridge: ObservableObject {
    public static let shared = ClaudeAppBridge()
    @Published public private(set) var isClaudeInstalled = false
    @Published public private(set) var isClaudeRunning = false

    private init() {}

    public func launchClaude() async throws {
        throw ClaudeBridgeError.notSupported
    }

    public func sendPrompt(_ prompt: String) async throws -> String {
        throw ClaudeBridgeError.notSupported
    }
}

public enum ClaudeBridgeError: Error, LocalizedError {
    case claudeNotInstalled
    case claudeNotRunning
    case accessibilityError(String)
    case scriptError(String)
    case configurationError(String)
    case notSupported

    public var errorDescription: String? {
        switch self {
        case .claudeNotInstalled:
            return "Claude.app is not installed. Please install it from claude.ai"
        case .claudeNotRunning:
            return "Claude.app is not running"
        case .accessibilityError(let message):
            return "Accessibility error: \(message)"
        case .scriptError(let message):
            return "Script error: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .notSupported:
            return "Claude.app integration is only available on macOS"
        }
    }
}
#endif
