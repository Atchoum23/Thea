//
//  CausalPatternAnalyzer.swift
//  Thea
//
//  Analyzes patterns to understand WHY they occur, not just THAT they occur.
//  Provides causal explanations and actionable insights.
//

import Foundation
import Observation
import os.log

private let causalLogger = Logger(subsystem: "ai.thea.app", category: "CausalPatternAnalyzer")

// MARK: - Causal Relationship

public struct CausalRelationship: Identifiable, Sendable {
    public let id: UUID
    public let cause: CausalFactor
    public let effect: ObservedEffect
    public let strength: Double           // 0-1 correlation strength
    public let confidence: Double         // 0-1 confidence in causation
    public let evidence: [Evidence]
    public let discoveredAt: Date
    public let lastObserved: Date

    public init(
        id: UUID = UUID(),
        cause: CausalFactor,
        effect: ObservedEffect,
        strength: Double,
        confidence: Double,
        evidence: [Evidence] = [],
        discoveredAt: Date = Date(),
        lastObserved: Date = Date()
    ) {
        self.id = id
        self.cause = cause
        self.effect = effect
        self.strength = strength
        self.confidence = confidence
        self.evidence = evidence
        self.discoveredAt = discoveredAt
        self.lastObserved = lastObserved
    }
}

// MARK: - Causal Factor

public struct CausalFactor: Sendable {
    public let type: FactorType
    public let description: String
    public let observedValue: String
    public let normalValue: String?
    public let metadata: [String: String]

    public enum FactorType: String, Sendable {
        case timeOfDay          // Morning/afternoon/evening patterns
        case dayOfWeek          // Weekday vs weekend
        case taskComplexity     // Simple vs complex tasks
        case workDuration       // Session length
        case errorFrequency     // Recent error count
        case contextSwitch      // App/task switching
        case externalEvent      // Calendar, notifications
        case fatigue            // Estimated tiredness
        case toolUsage          // Specific tool patterns
        case modelPerformance   // AI model response quality
        case environmentChange  // New project, new codebase
        case learningCurve      // New technology adoption
    }

    public init(
        type: FactorType,
        description: String,
        observedValue: String,
        normalValue: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.type = type
        self.description = description
        self.observedValue = observedValue
        self.normalValue = normalValue
        self.metadata = metadata
    }
}

// MARK: - Observed Effect

public struct ObservedEffect: Sendable {
    public let type: EffectType
    public let description: String
    public let severity: Severity
    public let frequency: Int
    public let metadata: [String: String]

    public enum EffectType: String, Sendable {
        case productivityDrop     // Slower task completion
        case productivitySpike    // Faster completion
        case errorIncrease        // More errors
        case errorDecrease        // Fewer errors
        case frustration          // User frustration signals
        case satisfaction         // Positive signals
        case stuckBehavior        // Repeated queries
        case flowState            // Uninterrupted work
        case learningProgress     // Skill improvement
        case modelSwitch          // Changing AI models
        case abandonedTask        // Task not completed
    }

    public enum Severity: String, Sendable {
        case low
        case medium
        case high
        case critical
    }

    public init(
        type: EffectType,
        description: String,
        severity: Severity = .medium,
        frequency: Int = 1,
        metadata: [String: String] = [:]
    ) {
        self.type = type
        self.description = description
        self.severity = severity
        self.frequency = frequency
        self.metadata = metadata
    }
}

// MARK: - Evidence

public struct Evidence: Sendable {
    public let type: EvidenceType
    public let description: String
    public let timestamp: Date
    public let weight: Double

    public enum EvidenceType: String, Sendable {
        case coOccurrence       // Events happening together
        case temporalSequence   // A before B consistently
        case counterfactual     // Effect absent when cause absent
        case userConfirmation   // User validated the relationship
        case statisticalCorrelation
    }

    public init(
        type: EvidenceType,
        description: String,
        timestamp: Date = Date(),
        weight: Double = 0.5
    ) {
        self.type = type
        self.description = description
        self.timestamp = timestamp
        self.weight = weight
    }
}

// MARK: - Causal Insight

public struct CausalInsight: Identifiable, Sendable {
    public let id: UUID
    public let relationship: CausalRelationship
    public let explanation: String
    public let actionableAdvice: [String]
    public let preventionStrategy: String?
    public let expectedImpact: String
    public let priority: Priority

    public enum Priority: String, Sendable {
        case low
        case medium
        case high
        case critical
    }

    public init(
        id: UUID = UUID(),
        relationship: CausalRelationship,
        explanation: String,
        actionableAdvice: [String],
        preventionStrategy: String? = nil,
        expectedImpact: String,
        priority: Priority = .medium
    ) {
        self.id = id
        self.relationship = relationship
        self.explanation = explanation
        self.actionableAdvice = actionableAdvice
        self.preventionStrategy = preventionStrategy
        self.expectedImpact = expectedImpact
        self.priority = priority
    }
}

// MARK: - Event Timeline Entry

public struct CausalTimelineEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: String
    public let eventValue: String
    public let category: EventCategory
    public let metadata: [String: String]

    public enum EventCategory: String, Sendable {
        case userAction
        case systemEvent
        case externalTrigger
        case outcome
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: String,
        eventValue: String,
        category: EventCategory,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.eventValue = eventValue
        self.category = category
        self.metadata = metadata
    }
}
