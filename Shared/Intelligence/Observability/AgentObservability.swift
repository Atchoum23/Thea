// AgentObservability.swift
// Thea V2
//
// Comprehensive observability system for agent operations
// Includes trace visualization, token dashboard, and decision explanation

import Foundation
import OSLog

// MARK: - Agent Trace

/// A trace of agent execution
public struct AgentTrace: Identifiable, Sendable {
    public let id: UUID
    public let sessionId: UUID
    public let agentId: UUID
    public let agentType: String
    public let startTime: Date
    public var endTime: Date?
    public var status: TraceStatus
    public var spans: [TraceSpan]
    public var events: [TraceEvent]
    public var metrics: TraceMetrics

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

    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    public enum TraceStatus: String, Sendable {
        case running
        case completed
        case failed
        case timeout
        case cancelled
    }
}

/// A span within a trace (represents a single operation)
public struct TraceSpan: Identifiable, Sendable {
    public let id: UUID
    public let parentSpanId: UUID?
    public let name: String
    public let operation: SpanOperation
    public let startTime: Date
    public var endTime: Date?
    public var status: SpanStatus
    public var attributes: [String: String]
    public var error: String?

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

    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    public enum SpanOperation: String, Sendable {
        case llmCall
        case toolCall
        case fileRead
        case fileWrite
        case webSearch
        case webFetch
        case codeExecution
        case reasoning
        case planning
        case reflection
        case subagentSpawn
        case aggregation
        case custom
    }

    public enum SpanStatus: String, Sendable {
        case running
        case success
        case failure
    }
}

/// An event within a trace
public struct TraceEvent: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let name: String
    public let severity: EventSeverity
    public let message: String
    public let attributes: [String: String]

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

    public enum EventSeverity: String, Sendable {
        case debug
        case info
        case warning
        case error
        case critical
    }
}

/// Metrics collected during trace
public struct TraceMetrics: Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var totalTokens: Int
    public var estimatedCost: Double
    public var llmCalls: Int
    public var toolCalls: Int
    public var retries: Int
    public var cacheHits: Int
    public var cacheMisses: Int

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

/// Token usage dashboard data
public struct TokenDashboard: Sendable {
    public let timestamp: Date
    public let hourlyUsage: [HourlyUsage]
    public let dailyUsage: [DailyUsage]
    public let modelBreakdown: [ModelUsageBreakdown]
    public let taskTypeBreakdown: [TaskTypeBreakdown]
    public let budgetStatus: BudgetStatus

    public struct HourlyUsage: Identifiable, Sendable {
        public let id: UUID
        public let hour: Date
        public let inputTokens: Int
        public let outputTokens: Int
        public let cost: Double

        public init(id: UUID = UUID(), hour: Date, inputTokens: Int, outputTokens: Int, cost: Double) {
            self.id = id
            self.hour = hour
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cost = cost
        }
    }

    public struct DailyUsage: Identifiable, Sendable {
        public let id: UUID
        public let date: Date
        public let inputTokens: Int
        public let outputTokens: Int
        public let cost: Double
        public let requests: Int

        public init(id: UUID = UUID(), date: Date, inputTokens: Int, outputTokens: Int, cost: Double, requests: Int) {
            self.id = id
            self.date = date
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cost = cost
            self.requests = requests
        }
    }

    public struct ModelUsageBreakdown: Identifiable, Sendable {
        public let id: UUID
        public let modelId: String
        public let inputTokens: Int
        public let outputTokens: Int
        public let cost: Double
        public let percentage: Float

        public init(id: UUID = UUID(), modelId: String, inputTokens: Int, outputTokens: Int, cost: Double, percentage: Float) {
            self.id = id
            self.modelId = modelId
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cost = cost
            self.percentage = percentage
        }
    }

    public struct TaskTypeBreakdown: Identifiable, Sendable {
        public let id: UUID
        public let taskType: String
        public let tokens: Int
        public let cost: Double
        public let count: Int

        public init(id: UUID = UUID(), taskType: String, tokens: Int, cost: Double, count: Int) {
            self.id = id
            self.taskType = taskType
            self.tokens = tokens
            self.cost = cost
            self.count = count
        }
    }

    public struct BudgetStatus: Sendable {
        public let dailyBudget: Double
        public let dailySpent: Double
        public let monthlyBudget: Double
        public let monthlySpent: Double
        public let remainingDaily: Double
        public let remainingMonthly: Double
        public let isOverBudget: Bool

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

/// Explanation of a routing/model selection decision
public struct DecisionExplanation: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let decisionType: DecisionType
    public let input: DecisionInput
    public let factors: [DecisionFactor]
    public let alternatives: [AlternativeOption]
    public let selectedOption: String
    public let reasoning: String
    public let confidence: Float

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

    public enum DecisionType: String, Sendable {
        case modelSelection
        case agentSelection
        case toolSelection
        case strategySelection
        case routingDecision
        case escalationDecision
    }

    public struct DecisionInput: Sendable {
        public let taskDescription: String
        public let taskType: String
        public let constraints: [String: String]

        public init(taskDescription: String, taskType: String, constraints: [String: String] = [:]) {
            self.taskDescription = taskDescription
            self.taskType = taskType
            self.constraints = constraints
        }
    }

    public struct DecisionFactor: Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let weight: Float
        public let score: Float
        public let explanation: String

        public init(id: UUID = UUID(), name: String, weight: Float, score: Float, explanation: String) {
            self.id = id
            self.name = name
            self.weight = weight
            self.score = score
            self.explanation = explanation
        }
    }

    public struct AlternativeOption: Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let score: Float
        public let whyNotSelected: String

        public init(id: UUID = UUID(), name: String, score: Float, whyNotSelected: String) {
            self.id = id
            self.name = name
            self.score = score
            self.whyNotSelected = whyNotSelected
        }
    }
}

