//
//  BlockerAnticipator.swift
//  Thea
//
//  Real-time detection of user blockers: stuck tasks, repeated queries,
//  error loops, and complexity overload. Enables proactive assistance.
//

import Foundation
import Observation
import os.log

private let blockerLogger = Logger(subsystem: "ai.thea.app", category: "BlockerAnticipator")

// MARK: - Blocker Signal

public struct BlockerSignal: Identifiable, Sendable {
    public let id: UUID
    public let type: SignalType
    public let severity: Double
    public let timestamp: Date
    public let context: [String: String]

    public enum SignalType: String, Sendable {
        case longTaskDuration      // Task taking longer than expected
        case repeatedQuery         // Same/similar question asked multiple times
        case queryReformulation    // Rephrasing the same question
        case errorOccurrence       // Error in response or execution
        case highEditFrequency     // Lots of small edits (frustration signal)
        case longIdlePeriod        // User stopped after error/issue
        case modelSwitch           // User switching models (dissatisfaction)
        case conversationRestart   // Starting new conversation on same topic
        case negativeLanguage      // Frustrated language detected
        case helpRequest           // Explicit help request
    }

    public init(
        id: UUID = UUID(),
        type: SignalType,
        severity: Double,
        timestamp: Date = Date(),
        context: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.timestamp = timestamp
        self.context = context
    }
}

// MARK: - Blocker Analysis

public struct BlockerAnalysis: Sendable {
    public let blocker: DetectedBlocker
    public let signals: [BlockerSignal]
    public let confidence: Double
    public let suggestedInterventions: [Intervention]
    public let analysisTime: Date

    public struct Intervention: Sendable {
        public let type: InterventionType
        public let message: String
        public let action: InterventionAction
        public let priority: Int

        public enum InterventionType: String, Sendable {
            case offerAlternativeApproach
            case suggestBreakdown
            case provideExample
            case askClarifyingQuestion
            case suggestDocumentation
            case offerSimplification
            case suggestBreak
            case escalateComplexity
        }

        public enum InterventionAction: Sendable {
            case showMessage(String)
            case insertSuggestion(String)
            case loadContext([String])
            case switchModel(String)
            case showDocumentation(String)
        }

        public init(
            type: InterventionType,
            message: String,
            action: InterventionAction,
            priority: Int = 1
        ) {
            self.type = type
            self.message = message
            self.action = action
            self.priority = priority
        }
    }

    public init(
        blocker: DetectedBlocker,
        signals: [BlockerSignal],
        confidence: Double,
        suggestedInterventions: [Intervention],
        analysisTime: Date = Date()
    ) {
        self.blocker = blocker
        self.signals = signals
        self.confidence = confidence
        self.suggestedInterventions = suggestedInterventions
        self.analysisTime = analysisTime
    }
}

// MARK: - Task Tracking

public struct TaskTracker: Sendable {
    public let taskId: UUID
    public let startTime: Date
    public let taskType: String
    public let initialQuery: String
    public var queries: [String]
    public var errors: [String]
    public var modelSwitches: Int
    public var editCount: Int
    public var lastActivityTime: Date

    public init(
        taskId: UUID = UUID(),
        startTime: Date = Date(),
        taskType: String,
        initialQuery: String
    ) {
        self.taskId = taskId
        self.startTime = startTime
        self.taskType = taskType
        self.initialQuery = initialQuery
        self.queries = [initialQuery]
        self.errors = []
        self.modelSwitches = 0
        self.editCount = 0
        self.lastActivityTime = startTime
    }

    public var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    public var idleTime: TimeInterval {
        Date().timeIntervalSince(lastActivityTime)
    }
}
