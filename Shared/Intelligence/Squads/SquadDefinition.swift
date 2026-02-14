// SquadDefinition.swift
// Thea V2
//
// Multi-Agent Squads for complex workflows
// Inspired by:
// - Vapi: Squads with specialized assistants and handoffs
// - Claude Code: Task-specific subagents
// - smolagents: Multi-agent orchestration

import Foundation
import OSLog

// MARK: - Squad Definition

/// A squad is a group of specialized agents that work together
/// Each member has specific capabilities and can hand off to others
public struct SquadDefinition: Identifiable, Codable, Sendable {
    public let id: String
    public var name: String
    public var description: String
    public var members: [SquadMember]
    public var firstMemberId: String  // Agent that handles initial requests
    public var handoffRules: [HandoffRule]
    public var scope: SquadScope
    public var isEnabled: Bool

    public init(
        id: String,
        name: String,
        description: String,
        members: [SquadMember],
        firstMemberId: String,
        handoffRules: [HandoffRule] = [],
        scope: SquadScope = .workspace,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.members = members
        self.firstMemberId = firstMemberId
        self.handoffRules = handoffRules
        self.scope = scope
        self.isEnabled = isEnabled
    }

    /// Get member by ID
    public func member(id: String) -> SquadMember? {
        members.first { $0.id == id }
    }

    /// Get first member (entry point)
    public var firstMember: SquadMember? {
        member(id: firstMemberId)
    }
}

public enum SquadScope: String, Codable, Sendable {
    case builtin
    case global
    case workspace
}

// MARK: - Squad Member

/// A specialized agent within a squad
public struct SquadMember: Identifiable, Codable, Sendable {
    public let id: String
    public var name: String
    public var role: String
    public var systemPrompt: String
    public var model: String?  // Override model for this member
    public var tools: [String]  // Tools this member can use
    public var handoffDestinations: [String]  // Member IDs this can hand off to
    public var contextTransferMode: ContextTransferMode

    public init(
        id: String,
        name: String,
        role: String,
        systemPrompt: String,
        model: String? = nil,
        tools: [String] = [],
        handoffDestinations: [String] = [],
        contextTransferMode: ContextTransferMode = .fullHistory
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.systemPrompt = systemPrompt
        self.model = model
        self.tools = tools
        self.handoffDestinations = handoffDestinations
        self.contextTransferMode = contextTransferMode
    }
}

/// How context is transferred during handoffs
/// Inspired by Vapi's Context Engineering
public enum ContextTransferMode: String, Codable, Sendable {
    /// Transfer full conversation history
    case fullHistory

    /// Transfer only a summary
    case summaryOnly

    /// Transfer specific variables/data
    case variablesOnly

    /// No context transfer (fresh start)
    case none

    public var displayName: String {
        switch self {
        case .fullHistory: return "Full History"
        case .summaryOnly: return "Summary Only"
        case .variablesOnly: return "Variables Only"
        case .none: return "None"
        }
    }
}

// MARK: - Handoff

/// A handoff rule defining when and how to transfer to another agent
public struct HandoffRule: Identifiable, Codable, Sendable {
    public let id: UUID
    public var fromMemberId: String
    public var toMemberId: String
    public var trigger: HandoffTrigger
    public var priority: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        fromMemberId: String,
        toMemberId: String,
        trigger: HandoffTrigger,
        priority: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.fromMemberId = fromMemberId
        self.toMemberId = toMemberId
        self.trigger = trigger
        self.priority = priority
        self.isEnabled = isEnabled
    }
}

/// What triggers a handoff
public enum HandoffTrigger: Codable, Sendable {
    /// Keyword in user message
    case keyword(String)

    /// Task type classification
    case taskType(String)

    /// Explicit handoff request
    case explicit

    /// Tool invocation
    case toolUse(String)

    /// Condition expression
    case condition(String)

    public var displayName: String {
        switch self {
        case .keyword(let word): return "Keyword: \(word)"
        case .taskType(let type): return "Task: \(type)"
        case .explicit: return "Explicit Request"
        case .toolUse(let tool): return "Tool: \(tool)"
        case .condition(let expr): return "Condition: \(expr)"
        }
    }
}

/// Result of a handoff
public struct HandoffResult: Sendable {
    public var fromMember: SquadMember
    public var toMember: SquadMember
    public var contextSummary: String?
    public var transferredVariables: [String: String]
    public var timestamp: Date

    public init(
        fromMember: SquadMember,
        toMember: SquadMember,
        contextSummary: String? = nil,
        transferredVariables: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.fromMember = fromMember
        self.toMember = toMember
        self.contextSummary = contextSummary
        self.transferredVariables = transferredVariables
        self.timestamp = timestamp
    }
}

// MARK: - Squad Registry

/// Central registry for all squads
@MainActor
public final class SquadRegistry: ObservableObject {
    public static let shared = SquadRegistry()

    private let logger = Logger(subsystem: "com.thea.v2", category: "SquadRegistry")

    @Published public private(set) var squads: [String: SquadDefinition] = [:]

    private init() {
        registerBuiltinSquads()
    }

    /// Register built-in squads
    private func registerBuiltinSquads() {
        let builtins = [
            // Code Development Squad
            SquadDefinition(
                id: "code-development",
                name: "Code Development Squad",
                description: "Full-stack development team with specialized roles",
                members: [
                    SquadMember(
                        id: "architect",
                        name: "Architect",
                        role: "Software Architect",
                        systemPrompt: """
                        You are the Software Architect. Your role is to:
                        1. Understand requirements and design solutions
                        2. Make architectural decisions
                        3. Define patterns and best practices
                        4. Hand off implementation details to developers

                        When the architecture is defined, hand off to the appropriate developer.
                        """,
                        tools: ["file_read", "search", "web_search"],
                        handoffDestinations: ["frontend-dev", "backend-dev", "reviewer"],
                        contextTransferMode: .summaryOnly
                    ),
                    SquadMember(
                        id: "frontend-dev",
                        name: "Frontend Developer",
                        role: "Frontend Specialist",
                        systemPrompt: """
                        You are the Frontend Developer. Your role is to:
                        1. Implement UI components
                        2. Handle user interactions
                        3. Ensure responsive design
                        4. Follow the architect's design decisions

                        When frontend work is complete, hand off to reviewer.
                        """,
                        tools: ["file_read", "file_write", "terminal"],
                        handoffDestinations: ["reviewer", "architect"],
                        contextTransferMode: .fullHistory
                    ),
                    SquadMember(
                        id: "backend-dev",
                        name: "Backend Developer",
                        role: "Backend Specialist",
                        systemPrompt: """
                        You are the Backend Developer. Your role is to:
                        1. Implement server-side logic
                        2. Design and implement APIs
                        3. Handle data persistence
                        4. Follow the architect's design decisions

                        When backend work is complete, hand off to reviewer.
                        """,
                        tools: ["file_read", "file_write", "terminal", "database"],
                        handoffDestinations: ["reviewer", "architect"],
                        contextTransferMode: .fullHistory
                    ),
                    SquadMember(
                        id: "reviewer",
                        name: "Code Reviewer",
                        role: "Quality Assurance",
                        systemPrompt: """
                        You are the Code Reviewer. Your role is to:
                        1. Review code for quality and best practices
                        2. Identify bugs and security issues
                        3. Suggest improvements
                        4. Ensure code meets requirements

                        If issues found, hand back to appropriate developer.
                        If all good, confirm completion.
                        """,
                        tools: ["file_read", "search", "terminal"],
                        handoffDestinations: ["frontend-dev", "backend-dev", "architect"],
                        contextTransferMode: .fullHistory
                    )
                ],
                firstMemberId: "architect",
                handoffRules: [
                    HandoffRule(
                        fromMemberId: "architect",
                        toMemberId: "frontend-dev",
                        trigger: .taskType("ui"),
                        priority: 1
                    ),
                    HandoffRule(
                        fromMemberId: "architect",
                        toMemberId: "backend-dev",
                        trigger: .taskType("api"),
                        priority: 1
                    )
                ],
                scope: .builtin
            ),

            // Research Squad
            SquadDefinition(
                id: "research",
                name: "Research Squad",
                description: "Team for comprehensive research and analysis",
                members: [
                    SquadMember(
                        id: "coordinator",
                        name: "Research Coordinator",
                        role: "Coordinator",
                        systemPrompt: """
                        You are the Research Coordinator. Your role is to:
                        1. Break down research questions
                        2. Delegate to specialists
                        3. Synthesize findings
                        4. Present conclusions
                        """,
                        tools: ["search", "web_search"],
                        handoffDestinations: ["web-researcher", "code-analyst", "synthesizer"],
                        contextTransferMode: .summaryOnly
                    ),
                    SquadMember(
                        id: "web-researcher",
                        name: "Web Researcher",
                        role: "Web Research Specialist",
                        systemPrompt: """
                        You are the Web Researcher. Your role is to:
                        1. Search the web for relevant information
                        2. Verify sources
                        3. Extract key findings
                        4. Report back to coordinator
                        """,
                        tools: ["web_search", "web_fetch"],
                        handoffDestinations: ["coordinator", "synthesizer"],
                        contextTransferMode: .variablesOnly
                    ),
                    SquadMember(
                        id: "code-analyst",
                        name: "Code Analyst",
                        role: "Codebase Research Specialist",
                        systemPrompt: """
                        You are the Code Analyst. Your role is to:
                        1. Search and analyze codebases
                        2. Understand patterns and implementations
                        3. Document findings
                        4. Report back to coordinator
                        """,
                        tools: ["file_read", "search", "grep"],
                        handoffDestinations: ["coordinator", "synthesizer"],
                        contextTransferMode: .variablesOnly
                    ),
                    SquadMember(
                        id: "synthesizer",
                        name: "Synthesizer",
                        role: "Research Synthesizer",
                        systemPrompt: """
                        You are the Synthesizer. Your role is to:
                        1. Combine findings from all researchers
                        2. Identify patterns and insights
                        3. Create comprehensive summaries
                        4. Prepare final report
                        """,
                        tools: ["file_write"],
                        handoffDestinations: ["coordinator"],
                        contextTransferMode: .fullHistory
                    )
                ],
                firstMemberId: "coordinator",
                scope: .builtin
            )
        ]

        for squad in builtins {
            squads[squad.id] = squad
        }

        logger.info("Registered \(builtins.count) built-in squads")
    }

    /// Register a custom squad
    public func register(_ squad: SquadDefinition) {
        squads[squad.id] = squad
        logger.info("Registered squad: \(squad.name)")
    }

    /// Get squad by ID
    public func squad(id: String) -> SquadDefinition? {
        squads[id]
    }

    /// Get all squads sorted by name
    public var sortedSquads: [SquadDefinition] {
        Array(squads.values).sorted { $0.name < $1.name }
    }
}

// MARK: - Squad Execution State

/// Current state of squad execution
@MainActor
public final class SquadExecutionState: ObservableObject {
    @Published public var activeSquad: SquadDefinition?
    @Published public var activeMember: SquadMember?
    @Published public var handoffHistory: [HandoffResult] = []
    @Published public var contextVariables: [String: String] = [:]

    private let logger = Logger(subsystem: "com.thea.v2", category: "SquadExecutionState")

    public init() {}

    /// Start squad execution
    public func start(squad: SquadDefinition) {
        activeSquad = squad
        activeMember = squad.firstMember
        handoffHistory.removeAll()
        contextVariables.removeAll()
        logger.info("Started squad: \(squad.name) with \(squad.firstMember?.name ?? "unknown")")
    }

    /// Perform handoff to another member
    public func handoff(
        to memberId: String,
        contextSummary: String? = nil,
        variables: [String: String] = [:]
    ) -> HandoffResult? {
        guard let squad = activeSquad,
              let fromMember = activeMember,
              let toMember = squad.member(id: memberId)
        else {
            logger.error("Cannot hand off: invalid member or no active squad")
            return nil
        }

        // Merge variables
        for (key, value) in variables {
            contextVariables[key] = value
        }

        let result = HandoffResult(
            fromMember: fromMember,
            toMember: toMember,
            contextSummary: contextSummary,
            transferredVariables: variables
        )

        handoffHistory.append(result)
        activeMember = toMember

        logger.info("Handoff: \(fromMember.name) → \(toMember.name)")
        return result
    }

    /// End squad execution
    public func end() {
        logger.info("Ended squad: \(self.activeSquad?.name ?? "unknown")")
        activeSquad = nil
        activeMember = nil
    }

    /// Check if a handoff is needed based on rules
    public func checkHandoffRules(
        message: String,
        taskType: String? = nil
    ) -> SquadMember? {
        guard let squad = activeSquad,
              let currentMember = activeMember
        else { return nil }

        // Get applicable rules
        let rules = squad.handoffRules
            .filter { $0.fromMemberId == currentMember.id && $0.isEnabled }
            .sorted { $0.priority > $1.priority }

        for rule in rules {
            let shouldHandoff: Bool

            switch rule.trigger {
            case .keyword(let word):
                shouldHandoff = message.lowercased().contains(word.lowercased())

            case .taskType(let type):
                shouldHandoff = taskType == type

            case .explicit:
                shouldHandoff = message.lowercased().contains("hand off") ||
                               message.lowercased().contains("transfer to")

            case .toolUse:
                // Would need tool usage tracking
                shouldHandoff = false

            case .condition:
                // Would need expression evaluation
                shouldHandoff = false
            }

            if shouldHandoff {
                return squad.member(id: rule.toMemberId)
            }
        }

        return nil
    }
}
