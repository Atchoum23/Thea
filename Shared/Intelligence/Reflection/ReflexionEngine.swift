// ReflexionEngine.swift
// Thea V2
//
// Self-reflection and improvement system
// Implements Generate → Critique → Improve loop for higher quality outputs

import Foundation
import OSLog

// MARK: - Reflexion Cycle

/// A complete reflexion cycle with original, critique, and improved output
public struct ReflexionCycle: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let taskDescription: String
    public let originalOutput: String
    public let selfCritique: SelfCritique
    public let improvedOutput: String?
    public let confidenceScore: Float  // 0.0 - 1.0
    public let iterationCount: Int
    public let totalDuration: TimeInterval
    public let wasSuccessful: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        taskDescription: String,
        originalOutput: String,
        selfCritique: SelfCritique,
        improvedOutput: String? = nil,
        confidenceScore: Float,
        iterationCount: Int = 1,
        totalDuration: TimeInterval,
        wasSuccessful: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskDescription = taskDescription
        self.originalOutput = originalOutput
        self.selfCritique = selfCritique
        self.improvedOutput = improvedOutput
        self.confidenceScore = confidenceScore
        self.iterationCount = iterationCount
        self.totalDuration = totalDuration
        self.wasSuccessful = wasSuccessful
    }
}

// MARK: - Self Critique

/// Self-critique analysis of an output
public struct SelfCritique: Sendable {
    public let overallQuality: QualityLevel
    public let strengths: [String]
    public let weaknesses: [String]
    public let suggestions: [String]
    public let factualAccuracy: Float  // 0.0 - 1.0
    public let completeness: Float     // 0.0 - 1.0
    public let clarity: Float          // 0.0 - 1.0
    public let relevance: Float        // 0.0 - 1.0
    public let shouldImprove: Bool
    public let reasoning: String

    public init(
        overallQuality: QualityLevel,
        strengths: [String] = [],
        weaknesses: [String] = [],
        suggestions: [String] = [],
        factualAccuracy: Float = 0.5,
        completeness: Float = 0.5,
        clarity: Float = 0.5,
        relevance: Float = 0.5,
        shouldImprove: Bool = false,
        reasoning: String = ""
    ) {
        self.overallQuality = overallQuality
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.suggestions = suggestions
        self.factualAccuracy = factualAccuracy
        self.completeness = completeness
        self.clarity = clarity
        self.relevance = relevance
        self.shouldImprove = shouldImprove
        self.reasoning = reasoning
    }

    public var averageScore: Float {
        (factualAccuracy + completeness + clarity + relevance) / 4.0
    }
}

public enum QualityLevel: String, Codable, Sendable {
    case excellent
    case good
    case acceptable
    case needsImprovement
    case poor
}

// MARK: - Failure Analysis

/// Analysis of a failed task
public struct FailureAnalysis: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let taskDescription: String
    public let errorType: FailureType
    public let errorMessage: String
    public let rootCause: String
    public let contributingFactors: [String]
    public let suggestedFixes: [String]
    public let preventionStrategies: [String]
    public let severity: FailureSeverity
    public let isRecurring: Bool
    public let relatedFailures: [UUID]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        taskDescription: String,
        errorType: FailureType,
        errorMessage: String,
        rootCause: String,
        contributingFactors: [String] = [],
        suggestedFixes: [String] = [],
        preventionStrategies: [String] = [],
        severity: FailureSeverity = .medium,
        isRecurring: Bool = false,
        relatedFailures: [UUID] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskDescription = taskDescription
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.rootCause = rootCause
        self.contributingFactors = contributingFactors
        self.suggestedFixes = suggestedFixes
        self.preventionStrategies = preventionStrategies
        self.severity = severity
        self.isRecurring = isRecurring
        self.relatedFailures = relatedFailures
    }
}

public enum FailureType: String, Codable, Sendable {
    case misunderstanding     // Misunderstood the request
    case incompleteContext    // Missing necessary context
    case technicalError       // Code/execution error
    case hallucination        // Generated incorrect information
    case timeout              // Task took too long
    case resourceLimit        // Hit token/memory limits
    case toolFailure          // External tool failed
    case validationFailure    // Output didn't meet requirements
    case userRejection        // User rejected the output
    case unknown
}

public enum FailureSeverity: String, Codable, Sendable {
    case low      // Minor issue, easy to recover
    case medium   // Moderate impact, requires retry
    case high     // Significant impact, needs attention
    case critical // Major failure, blocks progress
}

// MARK: - Strategy Evolution

/// A learned strategy for handling specific task types
public struct LearnedStrategy: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let taskTypes: [String]
    public let approach: String
    public let steps: [String]
    public let prerequisites: [String]
    public let antiPatterns: [String]  // What NOT to do
    public let successRate: Float
    public let usageCount: Int
    public let lastUsed: Date
    public let createdAt: Date
    public let sourceFailures: [UUID]  // Failures that led to this strategy
    public let sourceSuccesses: [UUID] // Successes that validated it

    public init(
        id: UUID = UUID(),
        name: String,
        taskTypes: [String],
        approach: String,
        steps: [String] = [],
        prerequisites: [String] = [],
        antiPatterns: [String] = [],
        successRate: Float = 0.5,
        usageCount: Int = 0,
        lastUsed: Date = Date(),
        createdAt: Date = Date(),
        sourceFailures: [UUID] = [],
        sourceSuccesses: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.taskTypes = taskTypes
        self.approach = approach
        self.steps = steps
        self.prerequisites = prerequisites
        self.antiPatterns = antiPatterns
        self.successRate = successRate
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.createdAt = createdAt
        self.sourceFailures = sourceFailures
        self.sourceSuccesses = sourceSuccesses
    }
}

// MARK: - Confidence Calibration

/// Tracks prediction accuracy for confidence calibration
public struct ConfidenceCalibration: Codable, Sendable {
    public var totalPredictions: Int
    public var correctPredictions: Int
    public var calibrationBuckets: [ReflexionCalibrationBucket]

    public init() {
        self.totalPredictions = 0
        self.correctPredictions = 0
        self.calibrationBuckets = (0..<10).map { ReflexionCalibrationBucket(rangeStart: Float($0) / 10.0, rangeEnd: Float($0 + 1) / 10.0) }
    }

    public var overallAccuracy: Float {
        guard totalPredictions > 0 else { return 0 }
        return Float(correctPredictions) / Float(totalPredictions)
    }

    public mutating func record(predictedConfidence: Float, wasCorrect: Bool) {
        totalPredictions += 1
        if wasCorrect {
            correctPredictions += 1
        }

        // Update appropriate bucket
        let bucketIndex = min(9, Int(predictedConfidence * 10))
        calibrationBuckets[bucketIndex].record(wasCorrect: wasCorrect)
    }

    /// Returns calibrated confidence (adjusts for over/under confidence)
    public func calibrate(rawConfidence: Float) -> Float {
        let bucketIndex = min(9, Int(rawConfidence * 10))
        let bucket = calibrationBuckets[bucketIndex]

        guard bucket.sampleCount > 10 else {
            // Not enough data, return raw
            return rawConfidence
        }

        // Adjust based on actual accuracy in this bucket
        return bucket.actualAccuracy
    }
}

public struct ReflexionCalibrationBucket: Codable, Sendable {
    public let rangeStart: Float
    public let rangeEnd: Float
    public var sampleCount: Int
    public var correctCount: Int

    public init(rangeStart: Float, rangeEnd: Float) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.sampleCount = 0
        self.correctCount = 0
    }

    public var actualAccuracy: Float {
        guard sampleCount > 0 else { return rangeStart + 0.05 }
        return Float(correctCount) / Float(sampleCount)
    }

    public mutating func record(wasCorrect: Bool) {
        sampleCount += 1
        if wasCorrect {
            correctCount += 1
        }
    }
}
