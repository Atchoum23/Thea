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

// MARK: - Observability Manager

/// Central manager for observability
@MainActor
public final class ObservabilityManager: ObservableObject {
    public static let shared = ObservabilityManager()

    private let logger = Logger(subsystem: "com.thea.observability", category: "Manager")
    private let storageURL: URL

    @Published public private(set) var activeTraces: [AgentTrace] = []
    @Published public private(set) var recentDecisions: [DecisionExplanation] = []
    @Published public private(set) var currentDashboard: TokenDashboard?

    // Configuration
    public var maxTraceHistory: Int = 100
    public var maxDecisionHistory: Int = 50
    public var isEnabled: Bool = true

    // Accumulated usage
    private var hourlyUsage: [Date: (input: Int, output: Int, cost: Double)] = [:]
    private var dailyUsage: [Date: (input: Int, output: Int, cost: Double, requests: Int)] = [:]
    private var modelUsage: [String: (input: Int, output: Int, cost: Double)] = [:]
    private var taskTypeUsage: [String: (tokens: Int, cost: Double, count: Int)] = [:]

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = documentsPath.appendingPathComponent("thea_observability.json")
        loadState()
    }

    // MARK: - Trace Management

    /// Start a new trace
    public func startTrace(agentId: UUID, agentType: String) -> AgentTrace {
        let trace = AgentTrace(
            sessionId: UUID(),
            agentId: agentId,
            agentType: agentType
        )
        activeTraces.append(trace)
        logger.debug("Started trace \(trace.id) for \(agentType)")
        return trace
    }

    /// Add a span to a trace
    public func addSpan(
        to traceId: UUID,
        name: String,
        operation: TraceSpan.SpanOperation,
        parentSpanId: UUID? = nil
    ) -> TraceSpan? {
        guard let index = activeTraces.firstIndex(where: { $0.id == traceId }) else { return nil }

        let span = TraceSpan(
            parentSpanId: parentSpanId,
            name: name,
            operation: operation
        )

        activeTraces[index].spans.append(span)
        return span
    }

    /// Complete a span
    public func completeSpan(traceId: UUID, spanId: UUID, success: Bool, error: String? = nil) {
        guard let traceIndex = activeTraces.firstIndex(where: { $0.id == traceId }),
              let spanIndex = activeTraces[traceIndex].spans.firstIndex(where: { $0.id == spanId }) else {
            return
        }

        activeTraces[traceIndex].spans[spanIndex].endTime = Date()
        activeTraces[traceIndex].spans[spanIndex].status = success ? .success : .failure
        activeTraces[traceIndex].spans[spanIndex].error = error
    }

    /// Add an event to a trace
    public func addEvent(
        to traceId: UUID,
        name: String,
        severity: TraceEvent.EventSeverity = .info,
        message: String,
        attributes: [String: String] = [:]
    ) {
        guard let index = activeTraces.firstIndex(where: { $0.id == traceId }) else { return }

        let event = TraceEvent(
            name: name,
            severity: severity,
            message: message,
            attributes: attributes
        )

        activeTraces[index].events.append(event)
    }

    /// Update metrics for a trace
    public func updateMetrics(traceId: UUID, _ update: (inout TraceMetrics) -> Void) {
        guard let index = activeTraces.firstIndex(where: { $0.id == traceId }) else { return }
        update(&activeTraces[index].metrics)
    }

    /// Complete a trace
    public func completeTrace(traceId: UUID, status: AgentTrace.TraceStatus) {
        guard let index = activeTraces.firstIndex(where: { $0.id == traceId }) else { return }

        activeTraces[index].endTime = Date()
        activeTraces[index].status = status

        logger.info("Completed trace \(traceId) with status \(status.rawValue)")

        // Archive old traces
        if activeTraces.count > maxTraceHistory {
            activeTraces = Array(activeTraces.suffix(maxTraceHistory))
        }

        saveState()
    }

    // MARK: - Token Usage Tracking

    /// Record token usage
    public func recordTokenUsage(
        modelId: String,
        taskType: String,
        inputTokens: Int,
        outputTokens: Int,
        cost: Double
    ) {
        let now = Date()
        let hourKey = Calendar.current.startOfHour(for: now)
        let dayKey = Calendar.current.startOfDay(for: now)

        // Update hourly
        var hourly = hourlyUsage[hourKey] ?? (0, 0, 0)
        hourly.input += inputTokens
        hourly.output += outputTokens
        hourly.cost += cost
        hourlyUsage[hourKey] = hourly

        // Update daily
        var daily = dailyUsage[dayKey] ?? (0, 0, 0, 0)
        daily.input += inputTokens
        daily.output += outputTokens
        daily.cost += cost
        daily.requests += 1
        dailyUsage[dayKey] = daily

        // Update by model
        var model = modelUsage[modelId] ?? (0, 0, 0)
        model.input += inputTokens
        model.output += outputTokens
        model.cost += cost
        modelUsage[modelId] = model

        // Update by task type
        var task = taskTypeUsage[taskType] ?? (0, 0, 0)
        task.tokens += inputTokens + outputTokens
        task.cost += cost
        task.count += 1
        taskTypeUsage[taskType] = task

        // Update dashboard
        updateDashboard()
    }

    /// Get current dashboard
    public func getDashboard() -> TokenDashboard {
        updateDashboard()
        return currentDashboard!
    }

    private func updateDashboard() {
        let now = Date()

        // Build hourly usage (last 24 hours)
        let hourlyData = hourlyUsage.compactMap { hour, usage -> TokenDashboard.HourlyUsage? in
            guard now.timeIntervalSince(hour) < 86400 else { return nil }
            return TokenDashboard.HourlyUsage(
                hour: hour,
                inputTokens: usage.input,
                outputTokens: usage.output,
                cost: usage.cost
            )
        }.sorted { $0.hour < $1.hour }

        // Build daily usage (last 30 days)
        let dailyData = dailyUsage.compactMap { day, usage -> TokenDashboard.DailyUsage? in
            guard now.timeIntervalSince(day) < 30 * 86400 else { return nil }
            return TokenDashboard.DailyUsage(
                date: day,
                inputTokens: usage.input,
                outputTokens: usage.output,
                cost: usage.cost,
                requests: usage.requests
            )
        }.sorted { $0.date < $1.date }

        // Build model breakdown
        let totalModelTokens = modelUsage.values.map { $0.input + $0.output }.reduce(0, +)
        let modelData = modelUsage.map { modelId, usage -> TokenDashboard.ModelUsageBreakdown in
            let tokens = usage.input + usage.output
            return TokenDashboard.ModelUsageBreakdown(
                modelId: modelId,
                inputTokens: usage.input,
                outputTokens: usage.output,
                cost: usage.cost,
                percentage: totalModelTokens > 0 ? Float(tokens) / Float(totalModelTokens) : 0
            )
        }.sorted { $0.cost > $1.cost }

        // Build task type breakdown
        let taskData = taskTypeUsage.map { taskType, usage -> TokenDashboard.TaskTypeBreakdown in
            TokenDashboard.TaskTypeBreakdown(
                taskType: taskType,
                tokens: usage.tokens,
                cost: usage.cost,
                count: usage.count
            )
        }.sorted { $0.cost > $1.cost }

        // Calculate budget status
        let today = Calendar.current.startOfDay(for: now)
        let todayUsage = dailyUsage[today] ?? (0, 0, 0, 0)
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now))!
        let monthlySpent = dailyUsage.filter { $0.key >= monthStart }.values.map { $0.cost }.reduce(0, +)

        let budgetStatus = TokenDashboard.BudgetStatus(
            dailyBudget: 10.0,  // $10 daily
            dailySpent: todayUsage.cost,
            monthlyBudget: 200.0,  // $200 monthly
            monthlySpent: monthlySpent
        )

        currentDashboard = TokenDashboard(
            hourlyUsage: hourlyData,
            dailyUsage: dailyData,
            modelBreakdown: modelData,
            taskTypeBreakdown: taskData,
            budgetStatus: budgetStatus
        )
    }

    // MARK: - Decision Tracking

    /// Record a decision
    public func recordDecision(_ decision: DecisionExplanation) {
        recentDecisions.append(decision)

        if recentDecisions.count > maxDecisionHistory {
            recentDecisions = Array(recentDecisions.suffix(maxDecisionHistory))
        }

        logger.debug("Recorded \(decision.decisionType.rawValue) decision: \(decision.selectedOption)")
        saveState()
    }

    /// Create a decision explanation
    public func explainModelSelection(
        task: String,
        taskType: String,
        selectedModel: String,
        alternatives: [(name: String, score: Float, reason: String)],
        factors: [(name: String, weight: Float, score: Float, explanation: String)],
        reasoning: String,
        confidence: Float
    ) -> DecisionExplanation {
        let decision = DecisionExplanation(
            decisionType: .modelSelection,
            input: DecisionExplanation.DecisionInput(
                taskDescription: task,
                taskType: taskType
            ),
            factors: factors.map { factor in
                DecisionExplanation.DecisionFactor(
                    name: factor.name,
                    weight: factor.weight,
                    score: factor.score,
                    explanation: factor.explanation
                )
            },
            alternatives: alternatives.map { alt in
                DecisionExplanation.AlternativeOption(
                    name: alt.name,
                    score: alt.score,
                    whyNotSelected: alt.reason
                )
            },
            selectedOption: selectedModel,
            reasoning: reasoning,
            confidence: confidence
        )

        recordDecision(decision)
        return decision
    }

    // MARK: - Trace Visualization

    /// Get a visual representation of a trace
    public func visualizeTrace(_ traceId: UUID) -> TraceVisualization? {
        guard let trace = activeTraces.first(where: { $0.id == traceId }) else { return nil }

        return TraceVisualization(
            traceId: traceId,
            agentType: trace.agentType,
            duration: trace.duration,
            status: trace.status.rawValue,
            spanTimeline: buildSpanTimeline(trace.spans),
            eventLog: trace.events.map { event in
                TraceVisualization.EventEntry(
                    timestamp: event.timestamp,
                    name: event.name,
                    severity: event.severity.rawValue,
                    message: event.message
                )
            },
            metrics: TraceVisualization.MetricsSummary(
                totalTokens: trace.metrics.totalTokens,
                estimatedCost: trace.metrics.estimatedCost,
                llmCalls: trace.metrics.llmCalls,
                toolCalls: trace.metrics.toolCalls
            )
        )
    }

    private func buildSpanTimeline(_ spans: [TraceSpan]) -> [TraceVisualization.SpanEntry] {
        let startTime = spans.map { $0.startTime }.min() ?? Date()

        return spans.map { span in
            TraceVisualization.SpanEntry(
                id: span.id,
                parentId: span.parentSpanId,
                name: span.name,
                operation: span.operation.rawValue,
                startOffset: span.startTime.timeIntervalSince(startTime),
                duration: span.duration,
                status: span.status.rawValue,
                depth: calculateSpanDepth(span, allSpans: spans)
            )
        }
    }

    private func calculateSpanDepth(_ span: TraceSpan, allSpans: [TraceSpan]) -> Int {
        var depth = 0
        var currentParentId = span.parentSpanId

        while let parentId = currentParentId {
            depth += 1
            currentParentId = allSpans.first { $0.id == parentId }?.parentSpanId
        }

        return depth
    }

    // MARK: - Persistence

    private func loadState() {
        // Load persisted usage data
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let state = try JSONDecoder().decode(ObservabilityState.self, from: data)
            // Restore daily usage for current month
            logger.info("Loaded observability state")
        } catch {
            logger.error("Failed to load observability state: \(error.localizedDescription)")
        }
    }

    private func saveState() {
        // Save usage data
        do {
            let state = ObservabilityState(
                lastUpdated: Date()
            )
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageURL)
        } catch {
            logger.error("Failed to save observability state: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

public struct TraceVisualization: Sendable {
    public let traceId: UUID
    public let agentType: String
    public let duration: TimeInterval
    public let status: String
    public let spanTimeline: [SpanEntry]
    public let eventLog: [EventEntry]
    public let metrics: MetricsSummary

    public struct SpanEntry: Identifiable, Sendable {
        public let id: UUID
        public let parentId: UUID?
        public let name: String
        public let operation: String
        public let startOffset: TimeInterval
        public let duration: TimeInterval
        public let status: String
        public let depth: Int
    }

    public struct EventEntry: Sendable {
        public let timestamp: Date
        public let name: String
        public let severity: String
        public let message: String
    }

    public struct MetricsSummary: Sendable {
        public let totalTokens: Int
        public let estimatedCost: Double
        public let llmCalls: Int
        public let toolCalls: Int
    }
}

private struct ObservabilityState: Codable {
    let lastUpdated: Date
}

// MARK: - Calendar Extension

private extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
    }
}
