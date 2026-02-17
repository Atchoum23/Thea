// AgentObservability.swift
// Thea V2
//
// Comprehensive observability system for agent operations
// Includes trace visualization, token dashboard, and decision explanation

import Foundation
import OSLog

// MARK: - Agent Trace

/// A distributed trace of a complete agent execution, containing spans, events, and metrics.
public struct AgentTrace: Identifiable, Sendable {
    /// Unique trace identifier.
    public let id: UUID
    /// Session this trace belongs to.
    public let sessionId: UUID
    /// Agent that produced this trace.
    public let agentId: UUID
    /// Type descriptor of the agent (e.g. "CodeAgent", "ResearchAgent").
    public let agentType: String
    /// When the agent execution started.
    public let startTime: Date
    /// When the agent execution ended, or nil if still running.
    public var endTime: Date?
    /// Current execution status.
    public var status: TraceStatus
    /// Ordered list of operation spans within the trace.
    public var spans: [TraceSpan]
    /// Discrete events that occurred during the trace.
    public var events: [TraceEvent]
    /// Aggregated metrics for the trace.
    public var metrics: TraceMetrics

    /// Creates an agent trace.
    /// - Parameters:
    ///   - id: Trace identifier.
    ///   - sessionId: Parent session ID.
    ///   - agentId: Executing agent ID.
    ///   - agentType: Agent type descriptor.
    ///   - startTime: Execution start time.
    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        agentId: UUID,
        agentType: String,
        startTime: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.agentId = agentId
        self.agentType = agentType
        self.startTime = startTime
        self.endTime = nil
        self.status = .running
        self.spans = []
        self.events = []
        self.metrics = TraceMetrics()
    }

    /// Total wall-clock duration of the trace so far.
    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    /// Execution status of an agent trace.
    public enum TraceStatus: String, Sendable {
        /// Agent is still executing.
        case running
        /// Agent completed successfully.
        case completed
        /// Agent failed with an error.
        case failed
        /// Agent exceeded its time limit.
        case timeout
        /// Agent was cancelled by the user or system.
        case cancelled
    }
}

/// A span within a trace representing a single discrete operation (LLM call, tool use, etc.).
public struct TraceSpan: Identifiable, Sendable {
    /// Unique span identifier.
    public let id: UUID
    /// Parent span ID for nested operations, or nil for root spans.
    public let parentSpanId: UUID?
    /// Human-readable name of the operation.
    public let name: String
    /// Classification of the operation.
    public let operation: SpanOperation
    /// When the operation started.
    public let startTime: Date
    /// When the operation ended, or nil if still running.
    public var endTime: Date?
    /// Current execution status of the span.
    public var status: SpanStatus
    /// Key-value attributes attached to the span.
    public var attributes: [String: String]
    /// Error message if the span failed.
    public var error: String?

    /// Creates a trace span.
    /// - Parameters:
    ///   - id: Span identifier.
    ///   - parentSpanId: Parent span ID for nesting.
    ///   - name: Operation name.
    ///   - operation: Operation classification.
    ///   - startTime: Start time.
    public init(
        id: UUID = UUID(),
        parentSpanId: UUID? = nil,
        name: String,
        operation: SpanOperation,
        startTime: Date = Date()
    ) {
        self.id = id
        self.parentSpanId = parentSpanId
        self.name = name
        self.operation = operation
        self.startTime = startTime
        self.endTime = nil
        self.status = .running
        self.attributes = [:]
        self.error = nil
    }

    /// Duration of this span so far, in seconds.
    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    /// Classification of operations that can occur within a span.
    public enum SpanOperation: String, Sendable {
        /// Large language model API call.
        case llmCall
        /// Tool or function call.
        case toolCall
        /// Reading a file from disk.
        case fileRead
        /// Writing a file to disk.
        case fileWrite
        /// Web search query.
        case webSearch
        /// Fetching a web page.
        case webFetch
        /// Executing code in a sandbox.
        case codeExecution
        /// Chain-of-thought reasoning step.
        case reasoning
        /// Task planning and decomposition.
        case planning
        /// Self-reflection on previous output.
        case reflection
        /// Spawning a sub-agent.
        case subagentSpawn
        /// Aggregating results from multiple sources.
        case aggregation
        /// Custom operation type.
        case custom
    }

    /// Execution status of a span.
    public enum SpanStatus: String, Sendable {
        /// Span is still executing.
        case running
        /// Span completed successfully.
        case success
        /// Span failed with an error.
        case failure
    }
}

/// A discrete event that occurred during a trace.
public struct TraceEvent: Identifiable, Sendable {
    /// Unique event identifier.
    public let id: UUID
    /// When the event occurred.
    public let timestamp: Date
    /// Short name describing the event.
    public let name: String
    /// Severity level of the event.
    public let severity: EventSeverity
    /// Detailed event message.
    public let message: String
    /// Additional attributes as key-value pairs.
    public let attributes: [String: String]

    /// Creates a trace event.
    /// - Parameters:
    ///   - id: Event identifier.
    ///   - timestamp: Event timestamp.
    ///   - name: Event name.
    ///   - severity: Event severity.
    ///   - message: Event message.
    ///   - attributes: Additional attributes.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        name: String,
        severity: EventSeverity = .info,
        message: String,
        attributes: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.name = name
        self.severity = severity
        self.message = message
        self.attributes = attributes
    }

    /// Severity levels for trace events.
    public enum EventSeverity: String, Sendable {
        /// Detailed debugging information.
        case debug
        /// Informational event.
        case info
        /// Potential issue that may need attention.
        case warning
        /// Error that affected the operation.
        case error
        /// Critical error requiring immediate attention.
        case critical
    }
}

/// Aggregated metrics collected during a trace.
public struct TraceMetrics: Sendable {
    /// Total input tokens consumed across all LLM calls.
    public var inputTokens: Int
    /// Total output tokens generated across all LLM calls.
    public var outputTokens: Int
    /// Total tokens (input + output).
    public var totalTokens: Int
    /// Estimated cost in USD for all API calls.
    public var estimatedCost: Double
    /// Number of LLM API calls made.
    public var llmCalls: Int
    /// Number of tool/function calls made.
    public var toolCalls: Int
    /// Number of retried operations.
    public var retries: Int
    /// Number of cache hits (prompt caching, embedding cache, etc.).
    public var cacheHits: Int
    /// Number of cache misses.
    public var cacheMisses: Int

    /// Creates trace metrics with optional initial values.
    /// - Parameters:
    ///   - inputTokens: Input tokens consumed.
    ///   - outputTokens: Output tokens generated.
    ///   - totalTokens: Total tokens.
    ///   - estimatedCost: Estimated USD cost.
    ///   - llmCalls: LLM call count.
    ///   - toolCalls: Tool call count.
    ///   - retries: Retry count.
    ///   - cacheHits: Cache hit count.
    ///   - cacheMisses: Cache miss count.
    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        totalTokens: Int = 0,
        estimatedCost: Double = 0,
        llmCalls: Int = 0,
        toolCalls: Int = 0,
        retries: Int = 0,
        cacheHits: Int = 0,
        cacheMisses: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.estimatedCost = estimatedCost
        self.llmCalls = llmCalls
        self.toolCalls = toolCalls
        self.retries = retries
        self.cacheHits = cacheHits
        self.cacheMisses = cacheMisses
    }
}

// MARK: - Token Dashboard

/// Aggregated token usage data for dashboard display, broken down by time, model, and task type.
public struct TokenDashboard: Sendable {
    /// When this dashboard snapshot was created.
    public let timestamp: Date
    /// Hourly token usage breakdown.
    public let hourlyUsage: [HourlyUsage]
    /// Daily token usage breakdown.
    public let dailyUsage: [DailyUsage]
    /// Token usage broken down by model.
    public let modelBreakdown: [ModelUsageBreakdown]
    /// Token usage broken down by task type.
    public let taskTypeBreakdown: [TaskTypeBreakdown]
    /// Current budget spending status.
    public let budgetStatus: BudgetStatus

    /// Token usage for a single hour.
    public struct HourlyUsage: Identifiable, Sendable {
        /// Unique entry identifier.
        public let id: UUID
        /// The hour this data covers.
        public let hour: Date
        /// Input tokens consumed.
        public let inputTokens: Int
        /// Output tokens generated.
        public let outputTokens: Int
        /// Estimated cost in USD.
        public let cost: Double

        /// Creates an hourly usage entry.
        /// - Parameters:
        ///   - id: Entry identifier.
        ///   - hour: Hour timestamp.
        ///   - inputTokens: Input tokens.
        ///   - outputTokens: Output tokens.
        ///   - cost: USD cost.
        public init(id: UUID = UUID(), hour: Date, inputTokens: Int, outputTokens: Int, cost: Double) {
            self.id = id
            self.hour = hour
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cost = cost
        }
    }

    /// Token usage for a single day.
    public struct DailyUsage: Identifiable, Sendable {
        /// Unique entry identifier.
        public let id: UUID
        /// The date this data covers.
        public let date: Date
        /// Input tokens consumed.
        public let inputTokens: Int
        /// Output tokens generated.
        public let outputTokens: Int
        /// Estimated cost in USD.
        public let cost: Double
        /// Number of API requests made.
        public let requests: Int

        /// Creates a daily usage entry.
        /// - Parameters:
        ///   - id: Entry identifier.
        ///   - date: Date.
        ///   - inputTokens: Input tokens.
        ///   - outputTokens: Output tokens.
        ///   - cost: USD cost.
        ///   - requests: Request count.
        public init(id: UUID = UUID(), date: Date, inputTokens: Int, outputTokens: Int, cost: Double, requests: Int) {
            self.id = id
            self.date = date
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cost = cost
            self.requests = requests
        }
    }

    /// Token usage attributed to a specific model.
    public struct ModelUsageBreakdown: Identifiable, Sendable {
        /// Unique entry identifier.
        public let id: UUID
        /// Model identifier.
        public let modelId: String
        /// Input tokens consumed by this model.
        public let inputTokens: Int
        /// Output tokens generated by this model.
        public let outputTokens: Int
        /// Estimated cost for this model in USD.
        public let cost: Double
        /// Percentage of total usage attributed to this model.
        public let percentage: Float

        /// Creates a model usage breakdown entry.
        /// - Parameters:
        ///   - id: Entry identifier.
        ///   - modelId: Model identifier.
        ///   - inputTokens: Input tokens.
        ///   - outputTokens: Output tokens.
        ///   - cost: USD cost.
        ///   - percentage: Usage percentage.
        public init(id: UUID = UUID(), modelId: String, inputTokens: Int, outputTokens: Int, cost: Double, percentage: Float) {
            self.id = id
            self.modelId = modelId
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cost = cost
            self.percentage = percentage
        }
    }

    /// Token usage attributed to a specific task type.
    public struct TaskTypeBreakdown: Identifiable, Sendable {
        /// Unique entry identifier.
        public let id: UUID
        /// Task type name.
        public let taskType: String
        /// Total tokens consumed for this task type.
        public let tokens: Int
        /// Estimated cost for this task type in USD.
        public let cost: Double
        /// Number of requests for this task type.
        public let count: Int

        /// Creates a task type breakdown entry.
        /// - Parameters:
        ///   - id: Entry identifier.
        ///   - taskType: Task type name.
        ///   - tokens: Total tokens.
        ///   - cost: USD cost.
        ///   - count: Request count.
        public init(id: UUID = UUID(), taskType: String, tokens: Int, cost: Double, count: Int) {
            self.id = id
            self.taskType = taskType
            self.tokens = tokens
            self.cost = cost
            self.count = count
        }
    }

    /// Current token budget spending status.
    public struct BudgetStatus: Sendable {
        /// Daily spending budget in USD.
        public let dailyBudget: Double
        /// Amount spent today in USD.
        public let dailySpent: Double
        /// Monthly spending budget in USD.
        public let monthlyBudget: Double
        /// Amount spent this month in USD.
        public let monthlySpent: Double
        /// Remaining daily budget in USD.
        public let remainingDaily: Double
        /// Remaining monthly budget in USD.
        public let remainingMonthly: Double
        /// Whether spending exceeds either budget.
        public let isOverBudget: Bool

        /// Creates a budget status.
        /// - Parameters:
        ///   - dailyBudget: Daily budget in USD.
        ///   - dailySpent: Daily spending in USD.
        ///   - monthlyBudget: Monthly budget in USD.
        ///   - monthlySpent: Monthly spending in USD.
        public init(
            dailyBudget: Double,
            dailySpent: Double,
            monthlyBudget: Double,
            monthlySpent: Double
        ) {
            self.dailyBudget = dailyBudget
            self.dailySpent = dailySpent
            self.monthlyBudget = monthlyBudget
            self.monthlySpent = monthlySpent
            self.remainingDaily = dailyBudget - dailySpent
            self.remainingMonthly = monthlyBudget - monthlySpent
            self.isOverBudget = dailySpent > dailyBudget || monthlySpent > monthlyBudget
        }
    }

    /// Creates a token dashboard.
    /// - Parameters:
    ///   - timestamp: Snapshot timestamp.
    ///   - hourlyUsage: Hourly usage data.
    ///   - dailyUsage: Daily usage data.
    ///   - modelBreakdown: Per-model breakdown.
    ///   - taskTypeBreakdown: Per-task-type breakdown.
    ///   - budgetStatus: Budget status.
    public init(
        timestamp: Date = Date(),
        hourlyUsage: [HourlyUsage] = [],
        dailyUsage: [DailyUsage] = [],
        modelBreakdown: [ModelUsageBreakdown] = [],
        taskTypeBreakdown: [TaskTypeBreakdown] = [],
        budgetStatus: BudgetStatus
    ) {
        self.timestamp = timestamp
        self.hourlyUsage = hourlyUsage
        self.dailyUsage = dailyUsage
        self.modelBreakdown = modelBreakdown
        self.taskTypeBreakdown = taskTypeBreakdown
        self.budgetStatus = budgetStatus
    }
}

// MARK: - Decision Explanation

/// Human-readable explanation of a routing, model selection, or strategy decision.
public struct DecisionExplanation: Identifiable, Sendable {
    /// Unique explanation identifier.
    public let id: UUID
    /// When the decision was made.
    public let timestamp: Date
    /// Type of decision being explained.
    public let decisionType: DecisionType
    /// Input that the decision was based on.
    public let input: DecisionInput
    /// Weighted factors that influenced the decision.
    public let factors: [DecisionFactor]
    /// Alternative options that were considered.
    public let alternatives: [AlternativeOption]
    /// Name of the option that was selected.
    public let selectedOption: String
    /// Human-readable explanation of why this option was chosen.
    public let reasoning: String
    /// Confidence in the decision (0.0 - 1.0).
    public let confidence: Float

    /// Creates a decision explanation.
    /// - Parameters:
    ///   - id: Explanation identifier.
    ///   - timestamp: Decision timestamp.
    ///   - decisionType: Type of decision.
    ///   - input: Decision input.
    ///   - factors: Influencing factors.
    ///   - alternatives: Considered alternatives.
    ///   - selectedOption: Chosen option.
    ///   - reasoning: Explanation text.
    ///   - confidence: Decision confidence.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        decisionType: DecisionType,
        input: DecisionInput,
        factors: [DecisionFactor],
        alternatives: [AlternativeOption],
        selectedOption: String,
        reasoning: String,
        confidence: Float
    ) {
        self.id = id
        self.timestamp = timestamp
        self.decisionType = decisionType
        self.input = input
        self.factors = factors
        self.alternatives = alternatives
        self.selectedOption = selectedOption
        self.reasoning = reasoning
        self.confidence = confidence
    }

    /// Classification of decision types that can be explained.
    public enum DecisionType: String, Sendable {
        /// Choosing which AI model to use.
        case modelSelection
        /// Choosing which agent to dispatch to.
        case agentSelection
        /// Choosing which tool to invoke.
        case toolSelection
        /// Choosing an execution strategy.
        case strategySelection
        /// Routing a request to a provider or subsystem.
        case routingDecision
        /// Deciding whether to escalate to human or higher authority.
        case escalationDecision
    }

    /// Input data that a decision was based on.
    public struct DecisionInput: Sendable {
        /// Description of the task to be handled.
        public let taskDescription: String
        /// Classified task type.
        public let taskType: String
        /// Constraints applied to the decision (budget, latency, etc.).
        public let constraints: [String: String]

        /// Creates decision input.
        /// - Parameters:
        ///   - taskDescription: Task description.
        ///   - taskType: Task type.
        ///   - constraints: Applied constraints.
        public init(taskDescription: String, taskType: String, constraints: [String: String] = [:]) {
            self.taskDescription = taskDescription
            self.taskType = taskType
            self.constraints = constraints
        }
    }

    /// A weighted factor that influenced a decision.
    public struct DecisionFactor: Identifiable, Sendable {
        /// Unique factor identifier.
        public let id: UUID
        /// Factor name (e.g. "cost", "latency", "capability match").
        public let name: String
        /// Weight of this factor in the decision (0.0 - 1.0).
        public let weight: Float
        /// Score this option received for this factor (0.0 - 1.0).
        public let score: Float
        /// Human-readable explanation of why this score was assigned.
        public let explanation: String

        /// Creates a decision factor.
        /// - Parameters:
        ///   - id: Factor identifier.
        ///   - name: Factor name.
        ///   - weight: Factor weight.
        ///   - score: Factor score.
        ///   - explanation: Score explanation.
        public init(id: UUID = UUID(), name: String, weight: Float, score: Float, explanation: String) {
            self.id = id
            self.name = name
            self.weight = weight
            self.score = score
            self.explanation = explanation
        }
    }

    /// An alternative option that was considered but not selected.
    public struct AlternativeOption: Identifiable, Sendable {
        /// Unique option identifier.
        public let id: UUID
        /// Option name (e.g. model name, agent name).
        public let name: String
        /// Overall score this option received.
        public let score: Float
        /// Explanation of why this option was not selected.
        public let whyNotSelected: String

        /// Creates an alternative option.
        /// - Parameters:
        ///   - id: Option identifier.
        ///   - name: Option name.
        ///   - score: Option score.
        ///   - whyNotSelected: Reason not selected.
        public init(id: UUID = UUID(), name: String, score: Float, whyNotSelected: String) {
            self.id = id
            self.name = name
            self.score = score
            self.whyNotSelected = whyNotSelected
        }
    }
}
