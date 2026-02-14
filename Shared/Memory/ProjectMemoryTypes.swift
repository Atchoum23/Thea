//
//  ProjectMemoryTypes.swift
//  Thea
//
//  Supporting types for ProjectMemoryManager
//

import Foundation

// MARK: - Project Memory Types

/// Represents a remembered project/codebase
public struct ProjectMemory: Identifiable, Codable, Sendable, Hashable {
    public static func == (lhs: ProjectMemory, rhs: ProjectMemory) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public let id: UUID
    public var name: String
    public var path: String
    public var lastAccessed: Date
    public var accessCount: Int
    public var metadata: ProjectMetadata
    public var learnedPatterns: [LearnedPattern]
    public var keyFacts: [KeyFact]
    public var preferences: ProjectPreferences
    public var recentTopics: [String]
    public var relatedProjects: [UUID]

    public init(
        id: UUID = UUID(),
        name: String,
        path: String
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.lastAccessed = Date()
        self.accessCount = 1
        self.metadata = ProjectMetadata()
        self.learnedPatterns = []
        self.keyFacts = []
        self.preferences = ProjectPreferences()
        self.recentTopics = []
        self.relatedProjects = []
    }

    public mutating func recordAccess() {
        lastAccessed = Date()
        accessCount += 1
    }
}

/// Metadata about a project
public struct ProjectMetadata: Codable, Sendable {
    public var projectType: ProjectType = .unknown
    public var primaryLanguage: String?
    public var frameworks: [String] = []
    public var buildSystem: String?
    public var versionControl: String?
    public var teamSize: TeamSize = .unknown
    public var estimatedComplexity: Complexity = .unknown
    public var lastAnalyzed: Date?

    public enum ProjectType: String, Codable, Sendable {
        case ios, macos, watchos, tvos
        case web, backend, fullstack
        case library, framework
        case cli, script
        case dataScience, ml
        case unknown
    }

    public enum TeamSize: String, Codable, Sendable {
        case solo, small, medium, large, enterprise, unknown
    }

    public enum Complexity: String, Codable, Sendable {
        case simple, moderate, complex, veryComplex, unknown
    }
}

/// A pattern learned from user interactions
public struct LearnedPattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public var patternType: PatternType
    public var description: String
    public var examples: [String]
    public var confidence: Double
    public var timesApplied: Int
    public var lastApplied: Date?
    public var createdAt: Date

    public enum PatternType: String, Codable, Sendable {
        case codingStyle       // How they write code
        case namingConvention  // Variable/function naming
        case errorHandling     // How they handle errors
        case testing          // Testing preferences
        case documentation    // Comment/doc style
        case architecture     // Design patterns used
        case workflow         // How they work
        case communication    // How they like responses
    }

    public init(
        id: UUID = UUID(),
        patternType: PatternType,
        description: String,
        examples: [String] = []
    ) {
        self.id = id
        self.patternType = patternType
        self.description = description
        self.examples = examples
        self.confidence = 0.5
        self.timesApplied = 0
        self.createdAt = Date()
    }

    public mutating func recordApplication() {
        timesApplied += 1
        lastApplied = Date()
        confidence = min(0.95, confidence + 0.05)
    }
}

/// A key fact remembered about a project
public struct KeyFact: Identifiable, Codable, Sendable {
    public let id: UUID
    public var category: FactCategory
    public var fact: String
    public var source: String?
    public var importance: Importance
    public var createdAt: Date
    public var confirmedAt: Date?
    public var isStale: Bool = false

    public enum FactCategory: String, Codable, Sendable {
        case architecture
        case dependency
        case convention
        case bug
        case todo
        case decision
        case context
        case person
        case deadline
        case other
    }

    public enum Importance: String, Codable, Sendable, Comparable {
        case low, medium, high, critical

        public static func < (lhs: Importance, rhs: Importance) -> Bool {
            let order: [Importance] = [.low, .medium, .high, .critical]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }

    public init(
        id: UUID = UUID(),
        category: FactCategory,
        fact: String,
        source: String? = nil,
        importance: Importance = .medium
    ) {
        self.id = id
        self.category = category
        self.fact = fact
        self.source = source
        self.importance = importance
        self.createdAt = Date()
    }
}

/// User preferences specific to a project
public struct ProjectPreferences: Codable, Sendable {
    public var preferredModel: String?
    public var responseStyle: ResponseStyle = .balanced
    public var detailLevel: DetailLevel = .standard
    public var codeBlockLanguage: String?
    public var autoFormat: Bool = true
    public var includeTodos: Bool = true
    public var suggestTests: Bool = true

    public enum ResponseStyle: String, Codable, Sendable {
        case concise, balanced, detailed, educational
    }

    public enum DetailLevel: String, Codable, Sendable {
        case minimal, standard, comprehensive
    }
}

// MARK: - Memory Summary

/// Summary of project memory for context injection
public struct MemorySummary: Sendable {
    public let projectName: String
    public let projectType: ProjectMetadata.ProjectType
    public let primaryLanguage: String?
    public let frameworks: [String]
    public let keyPatterns: [String]
    public let importantFacts: [String]
    public let recentTopics: [String]
    public let preferences: ProjectPreferences

    public var contextString: String {
        var parts: [String] = []

        parts.append("Project: \(projectName)")
        if let lang = primaryLanguage {
            parts.append("Language: \(lang)")
        }
        if !frameworks.isEmpty {
            parts.append("Frameworks: \(frameworks.joined(separator: ", "))")
        }
        if !keyPatterns.isEmpty {
            parts.append("Patterns: \(keyPatterns.joined(separator: "; "))")
        }
        if !importantFacts.isEmpty {
            parts.append("Key facts: \(importantFacts.joined(separator: "; "))")
        }
        if !recentTopics.isEmpty {
            parts.append("Recent topics: \(recentTopics.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Extensions

extension KeyFact.FactCategory: CaseIterable {
    public static let allCases: [KeyFact.FactCategory] = [
        .architecture, .dependency, .convention, .bug, .todo,
        .decision, .context, .person, .deadline, .other
    ]
}

extension LearnedPattern.PatternType: CaseIterable {
    public static let allCases: [LearnedPattern.PatternType] = [
        .codingStyle, .namingConvention, .errorHandling, .testing,
        .documentation, .architecture, .workflow, .communication
    ]
}
