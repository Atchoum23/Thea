// SwiftKnowledgeLearnerTypes.swift
// Supporting types and DTOs extracted from SwiftKnowledgeLearner.swift
// for file_length compliance.

import Foundation

// MARK: - Feedback & Conversation Types

enum UserFeedback: String, Codable, Sendable {
    case positive
    case negative
    case correction
    case none
}

struct ConversationData: Sendable {
    let id: UUID
    let turns: [ConversationTurn]
}

struct ConversationTurn: Sendable {
    let userMessage: String
    let assistantResponse: String
    let wasSuccessful: Bool
    let feedback: UserFeedback?
}

struct LearningReport: Sendable {
    var turnsAnalyzed: Int = 0
    var patternsExtracted: Int = 0
    var completedAt: Date?
}

// MARK: - Learned Pattern

@Observable
final class SwiftLearnedPattern: Identifiable {
    let id = UUID()
    let category: String
    let patternSignature: String
    let exampleCode: String
    let context: String
    var confidence: Double
    var occurrenceCount = 1
    var lastSeen = Date()

    init(category: String, patternSignature: String, exampleCode: String, context: String, confidence: Double) {
        self.category = category
        self.patternSignature = patternSignature
        self.exampleCode = exampleCode
        self.context = context
        self.confidence = confidence
    }

    init(from dto: SwiftLearnedPatternDTO) {
        category = dto.category
        patternSignature = dto.patternSignature
        exampleCode = dto.exampleCode
        context = dto.context
        confidence = dto.confidence
        occurrenceCount = dto.occurrenceCount
        lastSeen = dto.lastSeen
    }
}

struct SwiftLearnedPatternDTO: Codable {
    let category: String
    let patternSignature: String
    let exampleCode: String
    let context: String
    let confidence: Double
    let occurrenceCount: Int
    let lastSeen: Date

    init(_ pattern: SwiftLearnedPattern) {
        category = pattern.category
        patternSignature = pattern.patternSignature
        exampleCode = pattern.exampleCode
        context = pattern.context
        confidence = pattern.confidence
        occurrenceCount = pattern.occurrenceCount
        lastSeen = pattern.lastSeen
    }
}

// MARK: - Code Snippet

@Observable
final class CodeSnippet: Identifiable {
    let id = UUID()
    let code: String
    let language: String
    let purpose: String
    let tags: [String]
    let qualityScore: Double
    let createdAt = Date()

    init(code: String, language: String, purpose: String, tags: [String], qualityScore: Double) {
        self.code = code
        self.language = language
        self.purpose = purpose
        self.tags = tags
        self.qualityScore = qualityScore
    }

    init(from dto: CodeSnippetDTO) {
        code = dto.code
        language = dto.language
        purpose = dto.purpose
        tags = dto.tags
        qualityScore = dto.qualityScore
    }
}

struct CodeSnippetDTO: Codable {
    let code: String
    let language: String
    let purpose: String
    let tags: [String]
    let qualityScore: Double

    init(_ snippet: CodeSnippet) {
        code = snippet.code
        language = snippet.language
        purpose = snippet.purpose
        tags = snippet.tags
        qualityScore = snippet.qualityScore
    }
}

// MARK: - Error Resolution

@Observable
final class ErrorResolution: Identifiable {
    let id = UUID()
    let errorPattern: String
    let errorType: String
    let resolution: String
    let preventionRule: String
    var occurrenceCount: Int = 1

    init(errorPattern: String, errorType: String, resolution: String, preventionRule: String) {
        self.errorPattern = errorPattern
        self.errorType = errorType
        self.resolution = resolution
        self.preventionRule = preventionRule
    }

    init(from dto: ErrorResolutionDTO) {
        errorPattern = dto.errorPattern
        errorType = dto.errorType
        resolution = dto.resolution
        preventionRule = dto.preventionRule
        occurrenceCount = dto.occurrenceCount
    }
}

struct ErrorResolutionDTO: Codable {
    let errorPattern: String
    let errorType: String
    let resolution: String
    let preventionRule: String
    let occurrenceCount: Int

    init(_ resolution: ErrorResolution) {
        errorPattern = resolution.errorPattern
        errorType = resolution.errorType
        self.resolution = resolution.resolution
        preventionRule = resolution.preventionRule
        occurrenceCount = resolution.occurrenceCount
    }
}

// MARK: - Best Practice

@Observable
final class BestPractice: Identifiable {
    let id = UUID()
    let practiceId: String
    let category: String
    let title: String
    let practiceDescription: String
    let exampleCode: String
    let context: String

    init(practiceId: String, category: String, title: String, description: String, exampleCode: String, context: String) {
        self.practiceId = practiceId
        self.category = category
        self.title = title
        practiceDescription = description
        self.exampleCode = exampleCode
        self.context = context
    }
}

// MARK: - String Extension

extension String {
    func count(of character: Character) -> Int {
        filter { $0 == character }.count
    }
}
