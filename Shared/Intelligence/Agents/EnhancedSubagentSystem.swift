// EnhancedSubagentSystem.swift
// Thea V2
//
// Enhanced subagent system with context isolation, parallel spawning,
// specialized agents, and result aggregation

import Foundation
import OSLog

// MARK: - Subagent Context

/// Isolated context for a subagent
public struct SubagentContext: Identifiable, Sendable {
    public let id: UUID
    public let parentContextId: UUID?
    public let agentType: SpecializedAgentType
    public let isolationLevel: ContextIsolationLevel
    public let inheritedContext: [String: String]
    public let contextWindow: Int
    public let createdAt: Date
    public var tokenBudget: Int
    public var tokensUsed: Int

    public init(
        id: UUID = UUID(),
        parentContextId: UUID? = nil,
        agentType: SpecializedAgentType,
        isolationLevel: ContextIsolationLevel = .partial,
        inheritedContext: [String: String] = [:],
        contextWindow: Int = 8192,
        tokenBudget: Int = 4096
    ) {
        self.id = id
        self.parentContextId = parentContextId
        self.agentType = agentType
        self.isolationLevel = isolationLevel
        self.inheritedContext = inheritedContext
        self.contextWindow = contextWindow
        self.createdAt = Date()
        self.tokenBudget = tokenBudget
        self.tokensUsed = 0
    }

    public var remainingTokens: Int {
        tokenBudget - tokensUsed
    }
}

public enum ContextIsolationLevel: String, Sendable {
    case full        // Completely isolated, no inherited context
    case partial     // Inherits summary of parent context
    case shared      // Full access to parent context
    case sandbox     // Isolated with read-only parent access
}

// MARK: - Specialized Agent Types

/// Types of specialized agents
public enum SpecializedAgentType: String, Codable, Sendable, CaseIterable {
    // Existing agents
    case explore         // Fast, read-only code search
    case plan            // Reasoning model for architecture
    case generalPurpose  // Versatile, all tools
    case bash            // Command execution specialist
    case research        // Web research focused

    // New specialized agents
    case database        // Database schema, queries, migrations
    case security        // Security analysis, vulnerability scanning
    case performance     // Performance profiling, optimization
    case api             // API design, integration
    case testing         // Test generation, coverage analysis
    case documentation   // Documentation generation
    case refactoring     // Code refactoring specialist
    case review          // Code review and feedback
    case debug           // Debugging and error analysis
    case deployment      // CI/CD, deployment configuration

    public var displayName: String {
        switch self {
        case .explore: return "Explorer"
        case .plan: return "Planner"
        case .generalPurpose: return "General Purpose"
        case .bash: return "Command Executor"
        case .research: return "Researcher"
        case .database: return "Database Expert"
        case .security: return "Security Analyst"
        case .performance: return "Performance Engineer"
        case .api: return "API Specialist"
        case .testing: return "Test Engineer"
        case .documentation: return "Documentation Writer"
        case .refactoring: return "Refactoring Expert"
        case .review: return "Code Reviewer"
        case .debug: return "Debug Specialist"
        case .deployment: return "DevOps Engineer"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .explore: return "magnifyingglass"
        case .plan: return "list.bullet.clipboard"
        case .generalPurpose: return "cpu"
        case .bash: return "terminal"
        case .research: return "globe"
        case .database: return "cylinder"
        case .security: return "lock.shield"
        case .performance: return "gauge.with.dots.needle.67percent"
        case .api: return "arrow.left.arrow.right"
        case .testing: return "checkmark.diamond"
        case .documentation: return "doc.text"
        case .refactoring: return "arrow.triangle.2.circlepath"
        case .review: return "eye"
        case .debug: return "ant"
        case .deployment: return "shippingbox"
        }
    }

    public var systemPrompt: String {
        switch self {
        case .explore:
            return "You are a fast, read-only code exploration agent. Search and analyze code without making changes."
        case .plan:
            return "You are a software architect. Design systems, plan implementations, and create technical specifications."
        case .generalPurpose:
            return "You are a versatile AI assistant with access to all tools. Handle any task efficiently."
        case .bash:
            return "You are a command-line specialist. Execute shell commands, manage files, and automate tasks."
        case .research:
            return "You are a thorough researcher. Search the web, gather information, and synthesize findings."
        case .database:
            return "You are a database expert. Design schemas, optimize queries, plan migrations, and ensure data integrity."
        case .security:
            return "You are a security analyst. Identify vulnerabilities, review code for security issues, and recommend fixes."
        case .performance:
            return "You are a performance engineer. Profile code, identify bottlenecks, and optimize for speed and efficiency."
        case .api:
            return "You are an API specialist. Design RESTful and GraphQL APIs, document endpoints, and handle integrations."
        case .testing:
            return "You are a test engineer. Generate comprehensive tests, analyze coverage, and ensure code reliability."
        case .documentation:
            return "You are a technical writer. Create clear documentation, API docs, and user guides."
        case .refactoring:
            return "You are a refactoring expert. Improve code structure while preserving functionality."
        case .review:
            return "You are a code reviewer. Analyze code for quality, patterns, and potential issues."
        case .debug:
            return "You are a debugging specialist. Analyze errors, trace issues, and identify root causes."
        case .deployment:
            return "You are a DevOps engineer. Configure CI/CD, manage deployments, and automate infrastructure."
        }
    }

    public var suggestedTools: [String] {
        switch self {
        case .explore: return ["read", "search", "grep", "glob"]
        case .plan: return ["read", "write", "search"]
        case .generalPurpose: return ["*"]
        case .bash: return ["bash", "read", "write"]
        case .research: return ["web_search", "web_fetch", "read"]
        case .database: return ["read", "write", "bash"]
        case .security: return ["read", "search", "grep", "bash"]
        case .performance: return ["read", "bash", "search"]
        case .api: return ["read", "write", "web_fetch"]
        case .testing: return ["read", "write", "bash"]
        case .documentation: return ["read", "write"]
        case .refactoring: return ["read", "write", "search"]
        case .review: return ["read", "search", "grep"]
        case .debug: return ["read", "bash", "search", "grep"]
        case .deployment: return ["bash", "read", "write"]
        }
    }

    public var preferredModel: String {
        switch self {
        case .plan, .security, .review:
            return "claude-opus-4"  // Needs deep reasoning
        case .explore, .bash, .debug:
            return "claude-haiku-3.5"  // Fast, simple tasks
        default:
            return "claude-sonnet-4"  // Balanced
        }
    }
}

// MARK: - Subagent Task

/// A task to be executed by a subagent
public struct SubagentTask: Identifiable, Sendable {
    public let id: UUID
    public let parentTaskId: UUID?
    public let agentType: SpecializedAgentType
    public let description: String
    public let input: String
    public let priority: TaskPriority
    public let timeout: TimeInterval
    public let maxTokens: Int
    public let requiredOutput: OutputRequirement
    public let dependsOn: [UUID]

    public init(
        id: UUID = UUID(),
        parentTaskId: UUID? = nil,
        agentType: SpecializedAgentType,
        description: String,
        input: String,
        priority: TaskPriority = .normal,
        timeout: TimeInterval = 60,
        maxTokens: Int = 4096,
        requiredOutput: OutputRequirement = .text,
        dependsOn: [UUID] = []
    ) {
        self.id = id
        self.parentTaskId = parentTaskId
        self.agentType = agentType
        self.description = description
        self.input = input
        self.priority = priority
        self.timeout = timeout
        self.maxTokens = maxTokens
        self.requiredOutput = requiredOutput
        self.dependsOn = dependsOn
    }

    public enum TaskPriority: Int, Comparable, Sendable {
        case low = 0
        case normal = 50
        case high = 75
        case critical = 100

        public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public enum OutputRequirement: String, Sendable {
        case text
        case json
        case code
        case markdown
        case structured
    }
}

// MARK: - Enhanced Subagent Result

/// Result from an enhanced subagent execution
public struct EnhancedSubagentResult: Identifiable, Sendable {
    public let id: UUID
    public let taskId: UUID
    public let agentType: SpecializedAgentType
    public let status: EnhancedResultStatus
    public let output: String
    public let structuredOutput: [String: String]?
    public let confidence: Float
    public let tokensUsed: Int
    public let executionTime: TimeInterval
    public let error: String?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        agentType: SpecializedAgentType,
        status: EnhancedResultStatus,
        output: String,
        structuredOutput: [String: String]? = nil,
        confidence: Float = 0.8,
        tokensUsed: Int = 0,
        executionTime: TimeInterval = 0,
        error: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.taskId = taskId
        self.agentType = agentType
        self.status = status
        self.output = output
        self.structuredOutput = structuredOutput
        self.confidence = confidence
        self.tokensUsed = tokensUsed
        self.executionTime = executionTime
        self.error = error
        self.metadata = metadata
    }

    public enum EnhancedResultStatus: String, Sendable {
        case success
        case partialSuccess
        case failed
        case timeout
        case cancelled
    }
}

// MARK: - Aggregated Result

/// Aggregated result from multiple subagents
public struct SubagentAggregatedResult: Sendable {
    public let taskId: UUID
    public let results: [EnhancedSubagentResult]
    public let mergedOutput: String
    public let consensusConfidence: Float
    public let totalTokensUsed: Int
    public let totalExecutionTime: TimeInterval
    public let aggregationStrategy: AggregationStrategy

    public init(
        taskId: UUID,
        results: [EnhancedSubagentResult],
        mergedOutput: String,
        consensusConfidence: Float,
        totalTokensUsed: Int,
        totalExecutionTime: TimeInterval,
        aggregationStrategy: AggregationStrategy
    ) {
        self.taskId = taskId
        self.results = results
        self.mergedOutput = mergedOutput
        self.consensusConfidence = consensusConfidence
        self.totalTokensUsed = totalTokensUsed
        self.totalExecutionTime = totalExecutionTime
        self.aggregationStrategy = aggregationStrategy
    }

    public enum AggregationStrategy: String, Sendable {
        case merge          // Combine all outputs
        case consensus      // Take majority agreement
        case bestConfidence // Take highest confidence
        case sequential     // Chain outputs in order
        case custom         // Custom aggregation logic
    }
}
