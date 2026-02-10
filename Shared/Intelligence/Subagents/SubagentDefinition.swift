// SubagentDefinition.swift
// Thea V2
//
// Subagent system for specialized AI assistants
// Inspired by:
// - Claude Code: Built-in subagents (Explore, Plan, General-purpose)
// - Cursor: Context isolation, parallel execution, specialized expertise
// - Antigravity: Browser Subagent, task delegation

import Foundation
import OSLog

// MARK: - Subagent Definition

/// A specialized subagent with specific capabilities
public struct SubagentDefinition: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let systemPrompt: String
    public let model: SubagentModel
    public let tools: SubagentTools
    public let executionMode: SubagentExecutionMode
    public let scope: SubagentScope
    public let thoroughness: SubagentThoroughness?

    public init(
        id: String,
        name: String,
        description: String,
        systemPrompt: String,
        model: SubagentModel = .inherit,
        tools: SubagentTools = .all,
        executionMode: SubagentExecutionMode = .foreground,
        scope: SubagentScope = .builtin,
        thoroughness: SubagentThoroughness? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.model = model
        self.tools = tools
        self.executionMode = executionMode
        self.scope = scope
        self.thoroughness = thoroughness
    }
}

// MARK: - Subagent Model

/// Model configuration for subagent
public enum SubagentModel: Codable, Sendable {
    /// Use parent conversation's model
    case inherit

    /// Use a specific model (faster/cheaper for specialized tasks)
    case specific(String)

    /// Use a fast model (e.g., Haiku, Flash)
    case fast

    /// Use a reasoning model (e.g., Opus, Pro with thinking)
    case reasoning

    public var displayName: String {
        switch self {
        case .inherit: return "Inherit from parent"
        case .specific(let model): return model
        case .fast: return "Fast model"
        case .reasoning: return "Reasoning model"
        }
    }
}

// MARK: - Subagent Tools

/// Tool access configuration for subagent
public enum SubagentTools: Codable, Sendable {
    /// All tools available
    case all

    /// Read-only tools (no Write, Edit)
    case readOnly

    /// Specific tools only
    case specific([String])

    /// All except specified
    case except([String])

    public var displayName: String {
        switch self {
        case .all: return "All tools"
        case .readOnly: return "Read-only"
        case .specific(let tools): return "\(tools.count) specific tools"
        case .except(let tools): return "All except \(tools.count)"
        }
    }
}

// MARK: - Subagent Execution Mode

/// How the subagent executes
public enum SubagentExecutionMode: String, Codable, Sendable {
    /// Run in foreground, user sees progress
    case foreground

    /// Run in background, user is notified when complete
    case background

    /// Run in parallel with other tasks
    case parallel

    public var displayName: String {
        switch self {
        case .foreground: return "Foreground"
        case .background: return "Background"
        case .parallel: return "Parallel"
        }
    }
}

// MARK: - Subagent Scope

/// Where the subagent is defined
public enum SubagentScope: String, Codable, Sendable {
    /// Built-in subagent
    case builtin

    /// User-defined global subagent
    case global

    /// Workspace-specific subagent
    case workspace
}

// MARK: - Subagent Thoroughness

/// Thoroughness level for exploration subagents
/// Inspired by Claude Code's Explore subagent
public enum SubagentThoroughness: String, Codable, Sendable {
    /// Quick: Basic searches, targeted lookups
    case quick

    /// Medium: Balanced exploration
    case medium

    /// Very Thorough: Comprehensive analysis across multiple locations
    case veryThorough

    public var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .medium: return "Medium"
        case .veryThorough: return "Very Thorough"
        }
    }

    public var description: String {
        switch self {
        case .quick:
            return "Basic searches and targeted lookups"
        case .medium:
            return "Balanced exploration with moderate depth"
        case .veryThorough:
            return "Comprehensive analysis across multiple locations and naming conventions"
        }
    }
}

// MARK: - Subagent Registry

/// Central registry for all subagents
@MainActor
public final class SubagentRegistry: ObservableObject {
    public static let shared = SubagentRegistry()

    private let logger = Logger(subsystem: "com.thea.v2", category: "SubagentRegistry")

    @Published public private(set) var subagents: [String: SubagentDefinition] = [:]

    private init() {
        registerBuiltinSubagents()
    }

    // MARK: - Built-in Subagents

    /// Register built-in subagents inspired by Claude Code
    private func registerBuiltinSubagents() {
        let builtins = [
            // Explore: Fast read-only agent for searching and analyzing codebases
            SubagentDefinition(
                id: "explore",
                name: "Explore",
                description: "Fast agent for searching and analyzing codebases without making changes",
                systemPrompt: """
                You are the Explore subagent, specialized for fast codebase exploration.
                Your purpose is to search files, understand code structure, and gather context.
                You have read-only access - you cannot modify files.

                When exploring:
                1. Use efficient search strategies
                2. Look for patterns and conventions
                3. Summarize findings clearly
                4. Note relevant files and locations
                """,
                model: .fast,
                tools: .readOnly,
                executionMode: .foreground,
                scope: .builtin,
                thoroughness: .medium
            ),

            // Plan: Agent for designing implementation approaches
            SubagentDefinition(
                id: "plan",
                name: "Plan",
                description: "Software architect for designing implementation plans",
                systemPrompt: """
                You are the Plan subagent, specialized for software architecture and planning.
                Your purpose is to design implementation approaches and create detailed plans.

                When planning:
                1. Understand requirements thoroughly
                2. Consider multiple approaches
                3. Identify critical files and dependencies
                4. List step-by-step implementation tasks
                5. Note potential risks and trade-offs
                """,
                model: .reasoning,
                tools: .readOnly,
                executionMode: .foreground,
                scope: .builtin
            ),

            // General-purpose: Versatile agent for various tasks
            SubagentDefinition(
                id: "general-purpose",
                name: "General Purpose",
                description: "Versatile agent for researching and executing multi-step tasks",
                systemPrompt: """
                You are the General-purpose subagent, capable of handling diverse tasks.
                You can research questions, search code, and execute multi-step tasks.

                Approach tasks systematically:
                1. Understand the goal
                2. Gather necessary context
                3. Execute steps methodically
                4. Verify results
                """,
                model: .inherit,
                tools: .all,
                executionMode: .foreground,
                scope: .builtin
            ),

            // Bash: Command execution specialist
            SubagentDefinition(
                id: "bash",
                name: "Bash",
                description: "Command execution specialist for terminal operations",
                systemPrompt: """
                You are the Bash subagent, specialized for command-line operations.
                You handle git operations, build commands, and other terminal tasks.

                Guidelines:
                1. Use safe, non-destructive commands when possible
                2. Explain what commands do before running
                3. Check command results before proceeding
                4. Handle errors gracefully
                """,
                model: .fast,
                tools: .specific(["bash", "terminal"]),
                executionMode: .foreground,
                scope: .builtin
            ),

            // Research: Web and documentation research
            SubagentDefinition(
                id: "research",
                name: "Research",
                description: "Agent for web research and documentation lookup",
                systemPrompt: """
                You are the Research subagent, specialized for finding information.
                You search the web, fetch documentation, and synthesize findings.

                When researching:
                1. Use targeted search queries
                2. Verify information from multiple sources
                3. Summarize key findings
                4. Provide relevant citations
                """,
                model: .fast,
                tools: .specific(["web_search", "web_fetch", "read"]),
                executionMode: .background,
                scope: .builtin
            )
        ]

        for subagent in builtins {
            subagents[subagent.id] = subagent
        }

        logger.info("Registered \(builtins.count) built-in subagents")
    }

    // MARK: - Management

    /// Register a custom subagent
    public func register(_ subagent: SubagentDefinition) {
        subagents[subagent.id] = subagent
        logger.info("Registered subagent: \(subagent.name)")
    }

    /// Get subagent by ID
    public func subagent(id: String) -> SubagentDefinition? {
        subagents[id]
    }

    /// Get best subagent for a task type
    public func recommendedSubagent(for taskType: TaskType) -> SubagentDefinition? {
        switch taskType {
        case .research, .factual:
            return subagent(id: "research")
        case .codeGeneration, .codeRefactoring:
            return subagent(id: "plan")
        case .debugging, .analysis:
            return subagent(id: "explore")
        default:
            return subagent(id: "general-purpose")
        }
    }

    /// Get all subagents sorted by name
    public var sortedSubagents: [SubagentDefinition] {
        Array(subagents.values).sorted { $0.name < $1.name }
    }
}

// MARK: - Subagent Execution Context

/// Context for subagent execution
public struct SubagentExecutionContext: Sendable {
    public let parentConversationId: String?
    public let taskDescription: String
    public let thoroughness: SubagentThoroughness
    public let maxTurns: Int
    public let timeout: TimeInterval

    public init(
        parentConversationId: String? = nil,
        taskDescription: String,
        thoroughness: SubagentThoroughness = .medium,
        maxTurns: Int = 10,
        timeout: TimeInterval = 300
    ) {
        self.parentConversationId = parentConversationId
        self.taskDescription = taskDescription
        self.thoroughness = thoroughness
        self.maxTurns = maxTurns
        self.timeout = timeout
    }
}

// MARK: - Subagent Result

/// Result from subagent execution
public struct SubagentResult: Sendable {
    public let subagentId: String
    public let success: Bool
    public let output: String
    public let artifacts: [AgentModeArtifact]
    public let turnsUsed: Int
    public let duration: TimeInterval
    public let error: String?

    public init(
        subagentId: String,
        success: Bool,
        output: String,
        artifacts: [AgentModeArtifact] = [],
        turnsUsed: Int = 0,
        duration: TimeInterval = 0,
        error: String? = nil
    ) {
        self.subagentId = subagentId
        self.success = success
        self.output = output
        self.artifacts = artifacts
        self.turnsUsed = turnsUsed
        self.duration = duration
        self.error = error
    }
}

// AgentModeArtifact and AgentArtifactType now defined in AgentMode/AgentMode.swift (activated)
