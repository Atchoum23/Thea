// LiveAutoCorrectTypes.swift
// Thea V4 — Data models for LiveAutoCorrect
//
// Extracted from LiveAutoCorrect.swift (SRP: data models are separate
// from the correction service and its UI).

import Foundation

// MARK: - Correction Result

public struct CorrectionResult: Sendable {
    public let original: String
    public let corrected: String
    public let corrections: [Correction]
    public var language: String = "en"
    public var confidence: Double = 0
    public var processingTime: TimeInterval = 0

    public var hasCorrections: Bool {
        !corrections.isEmpty
    }

    public var correctionCount: Int {
        corrections.count
    }
}

// MARK: - Individual Correction

public struct Correction: Sendable, Identifiable {
    public let id = UUID()
    public let original: String
    public let replacement: String
    public let type: CorrectionType
    public let confidence: Double
    public let alternatives: [String]
}

// MARK: - Correction Type

public enum CorrectionType: String, Sendable, Codable {
    case spelling
    case grammar
    case punctuation
    case capitalization
    case whitespace
}

// MARK: - Statistics

public struct AutoCorrectStats: Sendable {
    public var totalCorrections: Int = 0
    public var textsProcessed: Int = 0
    public var averageProcessingTime: TimeInterval = 0
    public var languagesDetected: [String: Int] = [:]
}

// MARK: - Internal Types

struct WordToken {
    let text: String
    let range: Range<String.Index>?
}
