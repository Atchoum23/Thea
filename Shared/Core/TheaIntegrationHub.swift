//
//  TheaIntegrationHub.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import Combine

// MARK: - Thea Integration Hub

/// Central hub that orchestrates all Thea services and features
/// Provides unified access to notifications, sync, memory, artifacts, MCP, agents, and app automation
@MainActor
public class TheaIntegrationHub: ObservableObject {
    public static let shared = TheaIntegrationHub()
    
    // MARK: - Services
    
    /// Cross-device notification service
    public let notifications = UniversalNotificationService.shared
    
    /// iCloud sync service
    public let sync = CrossDeviceService.shared
    
    /// Memory service (Claude Memory equivalent)
    public let memory = MemoryService.shared
    
    /// Artifact manager (Claude Artifacts equivalent)
    public let artifacts = ArtifactManager.shared
    
    /// MCP server manager
    public let mcp = MCPServerManager.shared
    
    /// Custom agent builder (GPT equivalent)
    public let agents = CustomAgentBuilder.shared
    
    #if os(macOS)
    /// Claude.app bridge
    public let claudeApp = ClaudeAppBridge.shared
    
    /// Work with Apps service
    public let workWithApps = WorkWithAppsService.shared
    #endif
    
    // MARK: - Published State
    
    @Published public private(set) var isInitialized = false
    @Published public private(set) var initializationErrors: [String] = []
    @Published public private(set) var syncStatus: SyncStatus?
    
    // MARK: - Initialization
    
    private init() {}
    
    /// Initialize all services
    public func initialize() async {
        guard !isInitialized else { return }
        
        initializationErrors.removeAll()
        
        // Initialize services in parallel where possible
        let notificationService = notifications
        let syncService = sync
        let memoryService = memory

        await withTaskGroup(of: (String, Error?).self) { group in
            group.addTask {
                do {
                    try await notificationService.initialize()
                    return ("notifications", nil)
                } catch {
                    return ("notifications", error)
                }
            }

            group.addTask {
                do {
                    try await syncService.initialize()
                    return ("sync", nil)
                } catch {
                    return ("sync", error)
                }
            }

            group.addTask {
                do {
                    try await memoryService.load()
                    return ("memory", nil)
                } catch {
                    return ("memory", error)
                }
            }

            for await (service, error) in group {
                if let error = error {
                    initializationErrors.append("\(service): \(error.localizedDescription)")
                }
            }
        }
        
        // Get initial sync status
        syncStatus = await sync.getStatus()
        
        isInitialized = true
        
        // Start background tasks
        startBackgroundTasks()
    }
    
    // MARK: - Background Tasks
    
    private func startBackgroundTasks() {
        // Periodic sync status update
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute
                syncStatus = await sync.getStatus()
            }
        }
        
        // Device heartbeat for presence tracking
        Task {
            while true {
                try? await notifications.updateDeviceHeartbeat()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }
    
    // MARK: - Quick Actions
    
    /// Notify all devices of AI response completion
    public func notifyAIComplete(
        conversation: String,
        preview: String,
        success: Bool = true
    ) async {
        try? await notifications.notifyAIResponseComplete(
            conversationTitle: conversation,
            responsePreview: preview,
            success: success
        )
    }
    
    /// Notify all devices that user input is required
    public func notifyInputRequired(
        conversation: String,
        prompt: String
    ) async {
        try? await notifications.notifyUserInputRequired(
            conversationTitle: conversation,
            promptText: prompt
        )
    }
    
    /// Store a memory about the user
    public func remember(_ content: String, type: TheaMemoryType = .fact) async {
        _ = try? await memory.remember(content, type: type)
    }
    
    /// Recall relevant memories for a query
    public func recall(_ query: String) async -> [TheaMemory] {
        await memory.recall(query: query)
    }
    
    /// Create a code artifact
    public func createCodeArtifact(
        title: String,
        language: CodeLanguage,
        code: String
    ) async -> Artifact? {
        try? await artifacts.createCodeArtifact(title: title, language: language, code: code)
    }
    
    /// Get the current custom agent's system prompt
    public func getCurrentAgentPrompt() -> String? {
        agents.getSystemPrompt()
    }
    
    /// Get available MCP tools
    public func getAvailableTools() -> [MCPTool] {
        mcp.availableTools
    }
    
    /// Execute an MCP tool
    public func executeTool(
        _ toolId: String,
        arguments: [String: Any]
    ) async throws -> MCPServerToolResult {
        try await mcp.executeTool(toolId: toolId, arguments: arguments)
    }
    
    #if os(macOS)
    /// Send a prompt to Claude.app
    public func sendToClaude(_ prompt: String) async throws -> String {
        try await claudeApp.sendPrompt(prompt)
    }
    
    /// Execute an action on a connected app
    public func executeAppAction(
        _ action: String,
        app: ConnectedApp,
        parameters: [String: Any] = [:]
    ) async throws -> AppActionResult {
        try await workWithApps.execute(action: action, on: app, parameters: parameters)
    }
    #endif
    
    // MARK: - Sync Operations
    
    /// Perform a full sync
    public func performSync() async throws {
        try await sync.performFullSync()
        syncStatus = await sync.getStatus()
    }
    
    /// Get sync status
    public func getSyncStatus() async -> SyncStatus {
        await sync.getStatus()
    }
    
    // MARK: - Session Context
    
    /// Build complete context for AI conversation
    /// Includes memories, current agent prompt, and available tools
    public func buildConversationContext(forQuery query: String) async -> ConversationContext {
        let relevantMemories = await memory.getContextMemories(forQuery: query)
        let agentPrompt = agents.getSystemPrompt()
        let tools = mcp.availableTools.map { $0.name }
        
        return ConversationContext(
            memories: relevantMemories,
            agentSystemPrompt: agentPrompt,
            availableTools: tools,
            currentAgent: agents.currentAgent
        )
    }
}

// MARK: - Conversation Context

public struct ConversationContext: Sendable {
    public let memories: String
    public let agentSystemPrompt: String?
    public let availableTools: [String]
    public let currentAgent: CustomAgent?
    
    /// Build full system prompt with all context
    public func buildSystemPrompt(basePrompt: String = "") -> String {
        var prompt = basePrompt
        
        // Add agent system prompt if available
        if let agentPrompt = agentSystemPrompt {
            prompt = agentPrompt + "\n\n" + prompt
        }
        
        // Add memories
        if !memories.isEmpty {
            prompt += "\n\n" + memories
        }
        
        // Add available tools
        if !availableTools.isEmpty {
            prompt += "\n\nAvailable tools: \(availableTools.joined(separator: ", "))"
        }
        
        return prompt
    }
}

// MARK: - Convenience Extensions

public extension TheaIntegrationHub {
    /// Quick notification with default settings
    func notify(_ title: String, body: String) async {
        try? await notifications.notifyAllDevices(title: title, body: body)
    }
    
    /// Quick memory storage
    func rememberFact(_ fact: String) async {
        _ = try? await memory.rememberFact(fact)
    }
    
    /// Quick preference storage
    func rememberPreference(_ key: String, value: String) async {
        _ = try? await memory.rememberPreference(key: key, value: value)
    }
}
