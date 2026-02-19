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

// periphery:ignore - Reserved: ConversationData type — reserved for future feature activation
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

// periphery:ignore - Reserved: LearningReport type — reserved for future feature activation
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

    // periphery:ignore - Reserved: init(category:patternSignature:exampleCode:context:confidence:) initializer — reserved for future feature activation
    init(category: String, patternSignature: String, exampleCode: String, context: String, confidence: Double) {
        // periphery:ignore - Reserved: ConversationData type reserved for future feature activation
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
        // periphery:ignore - Reserved: LearningReport type reserved for future feature activation
        context = dto.context
        confidence = dto.confidence
        occurrenceCount = dto.occurrenceCount
        lastSeen = dto.lastSeen
    }
}

struct SwiftLearnedPatternDTO: Codable {
    let category: String
    let patternSignature: String
    // periphery:ignore - Reserved: category property reserved for future feature activation
    // periphery:ignore - Reserved: patternSignature property reserved for future feature activation
    // periphery:ignore - Reserved: exampleCode property reserved for future feature activation
    // periphery:ignore - Reserved: context property reserved for future feature activation
    let exampleCode: String
    let context: String
    let confidence: Double
    let occurrenceCount: Int
    // periphery:ignore - Reserved: init(category:patternSignature:exampleCode:context:confidence:) initializer reserved for future feature activation
    let lastSeen: Date

    init(_ pattern: SwiftLearnedPattern) {
        category = pattern.category
        patternSignature = pattern.patternSignature
        exampleCode = pattern.exampleCode
        context = pattern.context
        // periphery:ignore - Reserved: init(from:) initializer reserved for future feature activation
        confidence = pattern.confidence
        occurrenceCount = pattern.occurrenceCount
        lastSeen = pattern.lastSeen
    }
}

// MARK: - Code Snippet

@Observable
final class CodeSnippet: Identifiable {
    // periphery:ignore - Reserved: SwiftLearnedPatternDTO type reserved for future feature activation
    let id = UUID()
    let code: String
    let language: String
    let purpose: String
    let tags: [String]
    let qualityScore: Double
    // periphery:ignore - Reserved: createdAt property — reserved for future feature activation
    let createdAt = Date()

    // periphery:ignore - Reserved: init(code:language:purpose:tags:qualityScore:) initializer — reserved for future feature activation
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

// periphery:ignore - Reserved: code property reserved for future feature activation

// periphery:ignore - Reserved: language property reserved for future feature activation

// periphery:ignore - Reserved: purpose property reserved for future feature activation

// periphery:ignore - Reserved: tags property reserved for future feature activation

// periphery:ignore - Reserved: qualityScore property reserved for future feature activation

// periphery:ignore - Reserved: createdAt property reserved for future feature activation

// periphery:ignore - Reserved: init(code:language:purpose:tags:qualityScore:) initializer reserved for future feature activation
struct CodeSnippetDTO: Codable {
    let code: String
    let language: String
    let purpose: String
    let tags: [String]
    let qualityScore: Double

    // periphery:ignore - Reserved: init(from:) initializer reserved for future feature activation
    init(_ snippet: CodeSnippet) {
        code = snippet.code
        language = snippet.language
        purpose = snippet.purpose
        tags = snippet.tags
        qualityScore = snippet.qualityScore
    }
}

// periphery:ignore - Reserved: CodeSnippetDTO type reserved for future feature activation

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
        // periphery:ignore - Reserved: errorPattern property reserved for future feature activation
        // periphery:ignore - Reserved: errorType property reserved for future feature activation
        // periphery:ignore - Reserved: resolution property reserved for future feature activation
        // periphery:ignore - Reserved: preventionRule property reserved for future feature activation
        errorPattern = dto.errorPattern
        errorType = dto.errorType
        // periphery:ignore - Reserved: init(errorPattern:errorType:resolution:preventionRule:) initializer reserved for future feature activation
        resolution = dto.resolution
        preventionRule = dto.preventionRule
        occurrenceCount = dto.occurrenceCount
    }
}

// periphery:ignore - Reserved: init(from:) initializer reserved for future feature activation
struct ErrorResolutionDTO: Codable {
    let errorPattern: String
    let errorType: String
    let resolution: String
    let preventionRule: String
    let occurrenceCount: Int

    init(_ resolution: ErrorResolution) {
        // periphery:ignore - Reserved: ErrorResolutionDTO type reserved for future feature activation
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
    // periphery:ignore - Reserved: title property — reserved for future feature activation
    let title: String
    // periphery:ignore - Reserved: practiceDescription property — reserved for future feature activation
    let practiceDescription: String
    // periphery:ignore - Reserved: exampleCode property — reserved for future feature activation
    let exampleCode: String
    // periphery:ignore - Reserved: context property — reserved for future feature activation
    let context: String

    // periphery:ignore - Reserved: practiceId property reserved for future feature activation
    // periphery:ignore - Reserved: category property reserved for future feature activation
    // periphery:ignore - Reserved: title property reserved for future feature activation
    // periphery:ignore - Reserved: practiceDescription property reserved for future feature activation
    // periphery:ignore - Reserved: exampleCode property reserved for future feature activation
    // periphery:ignore - Reserved: context property reserved for future feature activation
    init(practiceId: String, category: String, title: String, description: String, exampleCode: String, context: String) {
        // periphery:ignore - Reserved: init(practiceId:category:title:description:exampleCode:context:) initializer reserved for future feature activation
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
    // periphery:ignore - Reserved: count(of:) instance method reserved for future feature activation
    func count(of character: Character) -> Int {
        filter { $0 == character }.count
    }
}
