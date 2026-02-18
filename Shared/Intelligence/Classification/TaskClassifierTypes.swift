// TaskClassifierTypes.swift
// Thea V2
//
// Supporting types for TaskClassifier
// Extracted from TaskClassifier.swift

import Foundation

// MARK: - Learning Types

/// A learned task pattern from historical classifications
public struct LearnedTaskPattern: Identifiable, Sendable {
    public let id = UUID()
    public let pattern: String
    public let taskType: TaskType
    public let confidence: Double
    public let usageCount: Int
    public let lastUsed: Date
}

/// An emerging pattern that might warrant a new task type
public struct EmergingTaskPattern: Identifiable, Sendable {
    public let id = UUID()
    public let suggestedName: String
    public let relatedType: TaskType
    public let patterns: [String]
    public let frequency: Int
    public let averageConfidence: Double
}

/// Insights about classification performance
public struct ClassificationInsights: Sendable {
    public let totalClassifications: Int
    public let confidentClassifications: Int
    public let correctionsCount: Int
    public let taskDistribution: [TaskType: Int]
    public let topLearnedPatterns: [LearnedTaskPattern]
    public let emergingPatterns: [EmergingTaskPattern]

    public var confidenceRate: Double {
        guard totalClassifications > 0 else { return 0 }
        return Double(confidentClassifications) / Double(totalClassifications)
    }

    public var correctionRate: Double {
        guard totalClassifications > 0 else { return 0 }
        return Double(correctionsCount) / Double(totalClassifications)
    }
}

// MARK: - Supporting Types

struct ClassificationResponse: Codable {
    let taskType: String
    let confidence: Double
    let reasoning: String?
    let alternatives: [AlternativeClassification]?

    enum CodingKeys: String, CodingKey {
        case taskType, confidence, reasoning, alternatives
    }
}

struct AlternativeClassification: Codable {
    let type: String
    let confidence: Double
}

/// A logged record of a single classification event, including correctness feedback when available.
public struct ClassificationRecord: Codable, Sendable, Identifiable {
    public let id: UUID
    public let query: String
    public let taskType: TaskType
    public let confidence: Double
    public let wasCorrect: Bool?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        query: String,
        taskType: TaskType,
        confidence: Double,
        wasCorrect: Bool? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.taskType = taskType
        self.confidence = confidence
        self.wasCorrect = wasCorrect
        self.timestamp = timestamp
    }
}

// MARK: - Errors

/// Errors thrown during task classification.
public enum ClassificationError: Error, LocalizedError {
    case invalidResponse(String)
    case unknownTaskType(String)
    case providerError(Error)
    case noProvider

    public var errorDescription: String? {
        switch self {
        case let .invalidResponse(details):
            return "Invalid classification response: \(details)"
        case let .unknownTaskType(type):
            return "Unknown task type: \(type)"
        case let .providerError(error):
            return "Provider error during classification: \(error.localizedDescription)"
        case .noProvider:
            return "No AI provider available for classification"
        }
    }
}

// MARK: - Semantic Embedding Types

/// Cached query embedding for similarity matching
struct QueryEmbedding: Codable {
    let query: String
    let embedding: [Float]
    let taskType: TaskType
    let timestamp: Date
}

/// Classification method used (typealias for compatibility)
public typealias ClassificationMethod = ClassificationMethodType

/// Calibration bucket for confidence calibration
struct CalibrationBucket {
    let rangeStart: Double
    let rangeEnd: Double
    var correctCount: Int = 0
    var totalCount: Int = 0

    var accuracy: Double {
        guard totalCount > 0 else { return (rangeStart + rangeEnd) / 2 }
        return Double(correctCount) / Double(totalCount)
    }

    mutating func add(wasCorrect: Bool) {
        totalCount += 1
        if wasCorrect {
            correctCount += 1
        }
    }
}

/// Seeded random number generator for reproducible prototype initialization
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
