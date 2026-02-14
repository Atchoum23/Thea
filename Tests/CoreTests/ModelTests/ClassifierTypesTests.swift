// ClassifierTypesTests.swift
// Tests for TaskClassifier supporting types

import Foundation
import XCTest

// MARK: - Mirrored Types

private enum TaskType: String, Codable, Sendable, CaseIterable {
    case codeGeneration, codeAnalysis, debugging, factual, creative
    case analysis, research, conversation, system, math
    case translation, summarization, planning, unknown
}

private struct CalibrationBucket {
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
        if wasCorrect { correctCount += 1 }
    }
}

private struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private struct ClassificationResponse: Codable {
    let taskType: String
    let confidence: Double
    let reasoning: String?
    let alternatives: [AlternativeClassification]?
}

private struct AlternativeClassification: Codable {
    let type: String
    let confidence: Double
}

private struct QueryEmbedding: Codable {
    let query: String
    let embedding: [Float]
    let taskType: TaskType
    let timestamp: Date
}

private struct ClassificationRecord: Codable, Identifiable {
    let id: UUID
    let query: String
    let taskType: TaskType
    let confidence: Double
    let wasCorrect: Bool?
    let timestamp: Date

    init(
        id: UUID = UUID(), query: String,
        taskType: TaskType, confidence: Double,
        wasCorrect: Bool? = nil, timestamp: Date = Date()
    ) {
        self.id = id
        self.query = query
        self.taskType = taskType
        self.confidence = confidence
        self.wasCorrect = wasCorrect
        self.timestamp = timestamp
    }
}

private struct ClassificationInsights: Sendable {
    let totalClassifications: Int
    let confidentClassifications: Int
    let correctionsCount: Int
    let taskDistribution: [TaskType: Int]

    var confidenceRate: Double {
        guard totalClassifications > 0 else { return 0 }
        return Double(confidentClassifications) / Double(totalClassifications)
    }

    var correctionRate: Double {
        guard totalClassifications > 0 else { return 0 }
        return Double(correctionsCount) / Double(totalClassifications)
    }
}

// MARK: - CalibrationBucket Tests

final class CalibrationBucketTests: XCTestCase {

    func testDefaultAccuracy() {
        let bucket = CalibrationBucket(
            rangeStart: 0.8, rangeEnd: 0.9
        )
        // No samples: returns midpoint
        XCTAssertEqual(bucket.accuracy, 0.85, accuracy: 0.001)
    }

    func testPerfectAccuracy() {
        var bucket = CalibrationBucket(
            rangeStart: 0.7, rangeEnd: 0.8
        )
        for _ in 0..<10 {
            bucket.add(wasCorrect: true)
        }
        XCTAssertEqual(bucket.accuracy, 1.0)
        XCTAssertEqual(bucket.totalCount, 10)
        XCTAssertEqual(bucket.correctCount, 10)
    }

    func testZeroAccuracy() {
        var bucket = CalibrationBucket(
            rangeStart: 0.5, rangeEnd: 0.6
        )
        for _ in 0..<5 {
            bucket.add(wasCorrect: false)
        }
        XCTAssertEqual(bucket.accuracy, 0.0)
        XCTAssertEqual(bucket.totalCount, 5)
        XCTAssertEqual(bucket.correctCount, 0)
    }

    func testMixedAccuracy() {
        var bucket = CalibrationBucket(
            rangeStart: 0.6, rangeEnd: 0.7
        )
        bucket.add(wasCorrect: true)
        bucket.add(wasCorrect: true)
        bucket.add(wasCorrect: false)
        bucket.add(wasCorrect: true)
        // 3/4 = 0.75
        XCTAssertEqual(bucket.accuracy, 0.75, accuracy: 0.001)
    }

    func testDifferentRanges() {
        // Low range bucket
        let low = CalibrationBucket(rangeStart: 0.0, rangeEnd: 0.1)
        XCTAssertEqual(low.accuracy, 0.05, accuracy: 0.001)

        // High range bucket
        let high = CalibrationBucket(rangeStart: 0.9, rangeEnd: 1.0)
        XCTAssertEqual(high.accuracy, 0.95, accuracy: 0.001)
    }
}

// MARK: - SeededRandomGenerator Tests

final class SeededRandomGeneratorTests: XCTestCase {

    func testDeterministic() {
        var gen1 = SeededRandomGenerator(seed: 42)
        var gen2 = SeededRandomGenerator(seed: 42)
        for _ in 0..<100 {
            XCTAssertEqual(gen1.next(), gen2.next())
        }
    }

    func testDifferentSeeds() {
        var gen1 = SeededRandomGenerator(seed: 42)
        var gen2 = SeededRandomGenerator(seed: 99)
        // Different seeds produce different sequences
        let val1 = gen1.next()
        let val2 = gen2.next()
        XCTAssertNotEqual(val1, val2)
    }

    func testNonZeroOutput() {
        var gen = SeededRandomGenerator(seed: 1)
        for _ in 0..<50 {
            XCTAssertNotEqual(gen.next(), 0)
        }
    }

    func testDistribution() {
        var gen = SeededRandomGenerator(seed: 12345)
        var values = Set<UInt64>()
        for _ in 0..<1000 {
            values.insert(gen.next())
        }
        // Should produce many unique values
        XCTAssertGreaterThan(values.count, 900)
    }
}

// MARK: - ClassificationResponse Tests

final class ClassificationResponseTests: XCTestCase {

    func testBasicCodable() throws {
        let json = Data("""
        {
            "taskType": "codeGeneration",
            "confidence": 0.95,
            "reasoning": "Contains code keywords",
            "alternatives": null
        }
        """.utf8)

        let response = try JSONDecoder().decode(
            ClassificationResponse.self, from: json
        )
        XCTAssertEqual(response.taskType, "codeGeneration")
        XCTAssertEqual(response.confidence, 0.95, accuracy: 0.001)
        XCTAssertEqual(response.reasoning, "Contains code keywords")
        XCTAssertNil(response.alternatives)
    }

    func testWithAlternatives() throws {
        let json = Data("""
        {
            "taskType": "analysis",
            "confidence": 0.7,
            "reasoning": null,
            "alternatives": [
                {"type": "research", "confidence": 0.2},
                {"type": "factual", "confidence": 0.1}
            ]
        }
        """.utf8)

        let response = try JSONDecoder().decode(
            ClassificationResponse.self, from: json
        )
        XCTAssertEqual(response.alternatives?.count, 2)
        XCTAssertEqual(response.alternatives?.first?.type, "research")
    }

    func testRoundTrip() throws {
        let response = ClassificationResponse(
            taskType: "debugging",
            confidence: 0.88,
            reasoning: "Error in code",
            alternatives: [
                AlternativeClassification(
                    type: "codeAnalysis", confidence: 0.12
                )
            ]
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(
            ClassificationResponse.self, from: data
        )
        XCTAssertEqual(decoded.taskType, "debugging")
        XCTAssertEqual(decoded.confidence, 0.88, accuracy: 0.001)
    }
}

// MARK: - QueryEmbedding Tests

final class QueryEmbeddingTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let embedding = QueryEmbedding(
            query: "How to fix a bug",
            embedding: [0.1, 0.2, 0.3, -0.5, 0.8],
            taskType: .debugging,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )
        let data = try JSONEncoder().encode(embedding)
        let decoded = try JSONDecoder().decode(
            QueryEmbedding.self, from: data
        )
        XCTAssertEqual(decoded.query, "How to fix a bug")
        XCTAssertEqual(decoded.embedding.count, 5)
        XCTAssertEqual(decoded.taskType, .debugging)
    }

    func testEmptyEmbedding() throws {
        let embedding = QueryEmbedding(
            query: "", embedding: [],
            taskType: .unknown,
            timestamp: Date()
        )
        let data = try JSONEncoder().encode(embedding)
        let decoded = try JSONDecoder().decode(
            QueryEmbedding.self, from: data
        )
        XCTAssertTrue(decoded.embedding.isEmpty)
    }
}

// MARK: - ClassificationRecord Tests

final class ClassificationRecordTests: XCTestCase {

    func testDefaults() {
        let record = ClassificationRecord(
            query: "What is Swift?",
            taskType: .factual,
            confidence: 0.92
        )
        XCTAssertNil(record.wasCorrect)
        XCTAssertEqual(record.query, "What is Swift?")
        XCTAssertEqual(record.taskType, .factual)
    }

    func testCodableRoundTrip() throws {
        let record = ClassificationRecord(
            query: "Write a sort function",
            taskType: .codeGeneration,
            confidence: 0.85,
            wasCorrect: true
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(
            ClassificationRecord.self, from: data
        )
        XCTAssertEqual(decoded.query, "Write a sort function")
        XCTAssertEqual(decoded.taskType, .codeGeneration)
        XCTAssertEqual(decoded.wasCorrect, true)
    }

    func testIdentifiable() {
        let a = ClassificationRecord(
            query: "test", taskType: .unknown,
            confidence: 0.5
        )
        let b = ClassificationRecord(
            query: "test", taskType: .unknown,
            confidence: 0.5
        )
        XCTAssertNotEqual(a.id, b.id)
    }
}

// MARK: - ClassificationInsights Tests

final class ClassificationInsightsTests: XCTestCase {

    func testConfidenceRate() {
        let insights = ClassificationInsights(
            totalClassifications: 100,
            confidentClassifications: 85,
            correctionsCount: 5,
            taskDistribution: [:]
        )
        XCTAssertEqual(
            insights.confidenceRate, 0.85, accuracy: 0.001
        )
    }

    func testCorrectionRate() {
        let insights = ClassificationInsights(
            totalClassifications: 200,
            confidentClassifications: 180,
            correctionsCount: 10,
            taskDistribution: [:]
        )
        XCTAssertEqual(
            insights.correctionRate, 0.05, accuracy: 0.001
        )
    }

    func testZeroClassifications() {
        let insights = ClassificationInsights(
            totalClassifications: 0,
            confidentClassifications: 0,
            correctionsCount: 0,
            taskDistribution: [:]
        )
        XCTAssertEqual(insights.confidenceRate, 0)
        XCTAssertEqual(insights.correctionRate, 0)
    }

    func testPerfectConfidence() {
        let insights = ClassificationInsights(
            totalClassifications: 50,
            confidentClassifications: 50,
            correctionsCount: 0,
            taskDistribution: [
                .codeGeneration: 20,
                .factual: 15,
                .creative: 10,
                .conversation: 5
            ]
        )
        XCTAssertEqual(insights.confidenceRate, 1.0)
        XCTAssertEqual(insights.correctionRate, 0.0)
    }
}
