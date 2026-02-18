// MemoryManagerTypes.swift
// Thea V2 - Memory system types, records, and metadata
//
// Supporting types for MemoryManager: records, enums, metadata, and search results.

import Foundation
import OSLog

private let memTypeLogger = Logger(subsystem: "com.thea.app", category: "MemoryManagerTypes")

// MARK: - Memory Record (File-based, not SwiftData)

/// A file-persisted memory record with type, category, key-value content, and access tracking.
public struct OmniMemoryRecord: Codable, Identifiable, Sendable {
    public let id: UUID
    public var type: OmniMemoryType
    public var category: String
    public var key: String
    public var value: String
    public var confidence: Double
    public var source: OmniMemorySource
    public var timestamp: Date
    public var lastAccessed: Date
    public var accessCount: Int
    public var metadata: Data?

    public init(
        id: UUID = UUID(),
        type: OmniMemoryType,
        category: String,
        key: String,
        value: String,
        confidence: Double = 1.0,
        source: OmniMemorySource = .explicit,
        metadata: Data? = nil
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.key = key
        self.value = value
        self.confidence = confidence
        self.source = source
        self.timestamp = Date()
        self.lastAccessed = Date()
        self.accessCount = 0
        self.metadata = metadata
    }
}

// MARK: - Supporting Types (Prefixed with Omni to avoid conflicts)

/// The functional category of a memory record.
public enum OmniMemoryType: String, Codable, Sendable {
    case semantic    // Learned facts and patterns
    case episodic    // Specific experiences
    case procedural  // How to do things
    case prospective // Future intentions
}

/// How a memory record was originally created.
public enum OmniMemorySource: String, Codable, Sendable {
    case explicit    // User explicitly stated
    case inferred    // THEA inferred from behavior
    case system      // System-generated
}

/// Importance level determining retention and retrieval priority for a memory record.
public enum OmniMemoryPriority: String, Codable {
    case low
    case normal
    case high
    case critical
}

/// Semantic domain classification for grouping related memories.
public enum OmniSemanticCategory: String, Codable {
    case userPreference
    case taskPattern
    case modelPerformance
    case workflowOptimization
    case contextAssociation
    case personality
}

/// Category of user preference captured in a memory record.
public enum OmniPreferenceCategory: String, Codable {
    case responseStyle    // verbose, concise, technical
    case modelSelection   // preferred models by task
    case timing           // when user prefers certain activities
    case communication    // tone, formality
    case privacy          // what to share/not share
}

// MARK: - Memory Trigger Conditions

/// Trigger condition for prospective memory evaluation
public enum MemoryTriggerCondition: Codable, CustomStringConvertible {
    case time(Date)
    case location(String)
    case activity(String)
    case appLaunch(String)
    case keyword(String)
    case contextMatch(String)

    public var description: String {
        switch self {
        case .time(let date): return "At \(date)"
        case .location(let loc): return "At location: \(loc)"
        case .activity(let act): return "During activity: \(act)"
        case .appLaunch(let app): return "When \(app) opens"
        case .keyword(let kw): return "When mentioned: \(kw)"
        case .contextMatch(let ctx): return "When context matches: \(ctx)"
        }
    }

    public func isSatisfied(by context: MemoryContextSnapshot) -> Bool {
        switch self {
        case .time(let date):
            return Date() >= date
        case .activity(let activity):
            return context.userActivity?.lowercased().contains(activity.lowercased()) ?? false
        case .keyword(let keyword):
            return context.currentQuery?.lowercased().contains(keyword.lowercased()) ?? false
        default:
            return false
        }
    }
}

// MARK: - Memory Context Snapshot (for trigger evaluation)

/// Lightweight context snapshot for memory trigger evaluation
public struct MemoryContextSnapshot: Sendable {
    public var userActivity: String?
    public var currentQuery: String?
    public var location: String?
    public var timeOfDay: Int  // Hour 0-23
    public var dayOfWeek: Int  // 1-7
    public var batteryLevel: Int?
    public var isPluggedIn: Bool?

    public init(
        userActivity: String? = nil,
        currentQuery: String? = nil,
        location: String? = nil,
        timeOfDay: Int = Calendar.current.component(.hour, from: Date()),
        dayOfWeek: Int = Calendar.current.component(.weekday, from: Date()),
        batteryLevel: Int? = nil,
        isPluggedIn: Bool? = nil
    ) {
        self.userActivity = userActivity
        self.currentQuery = currentQuery
        self.location = location
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.batteryLevel = batteryLevel
        self.isPluggedIn = isPluggedIn
    }
}

// MARK: - Memory Detected Pattern

/// Pattern detected from memory analysis
public struct MemoryDetectedPattern: Sendable {
    public let event: String
    public let frequency: Int
    public let hourOfDay: Int
    public let dayOfWeek: Int
    public let confidence: Double

    public var description: String {
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let dayName = dayOfWeek >= 1 && dayOfWeek <= 7 ? dayNames[dayOfWeek] : "?"
        return "\(event) typically occurs at \(hourOfDay):00 on \(dayName)s (\(Int(confidence * 100))% confidence)"
    }
}

// MARK: - Memory Stats

/// Statistical summary of the current memory store.
public struct OmniMemoryStats: Sendable, CustomStringConvertible {
    public var semanticCount: Int = 0
    public var episodicCount: Int = 0
    public var proceduralCount: Int = 0
    public var prospectiveCount: Int = 0
    public var cacheSize: Int = 0
    public var lastConsolidation: Date?

    public var totalCount: Int {
        semanticCount + episodicCount + proceduralCount + prospectiveCount
    }

    public var description: String {
        "OmniMemoryStats(total: \(totalCount), semantic: \(semanticCount), episodic: \(episodicCount), procedural: \(proceduralCount), prospective: \(prospectiveCount), cache: \(cacheSize))"
    }
}

// MARK: - Metadata Types

struct OmniEpisodicMetadata: Codable {
    let outcome: String?
    let emotionalValence: Double

    func encoded() -> Data? {
        do { return try JSONEncoder().encode(self) } catch {
            memTypeLogger.debug("Failed to encode OmniEpisodicMetadata: \(error.localizedDescription)")
            return nil
        }
    }

    static func decode(_ data: Data?) -> OmniEpisodicMetadata? {
        guard let data else { return nil }
        do { return try JSONDecoder().decode(OmniEpisodicMetadata.self, from: data) } catch {
            memTypeLogger.debug("Failed to decode OmniEpisodicMetadata: \(error.localizedDescription)")
            return nil
        }
    }
}

struct OmniProceduralMetadata: Codable {
    var successRate: Double
    var averageDuration: TimeInterval
    var executionCount: Int

    func encoded() -> Data? {
        do { return try JSONEncoder().encode(self) } catch {
            memTypeLogger.debug("Failed to encode OmniProceduralMetadata: \(error.localizedDescription)")
            return nil
        }
    }

    static func decode(_ data: Data?) -> OmniProceduralMetadata? {
        guard let data else { return nil }
        do { return try JSONDecoder().decode(OmniProceduralMetadata.self, from: data) } catch {
            memTypeLogger.debug("Failed to decode OmniProceduralMetadata: \(error.localizedDescription)")
            return nil
        }
    }
}

struct OmniProspectiveMetadata: Codable {
    let triggerCondition: MemoryTriggerCondition
    var isTriggered: Bool

    func encoded() -> Data? {
        do { return try JSONEncoder().encode(self) } catch {
            memTypeLogger.debug("Failed to encode OmniProspectiveMetadata: \(error.localizedDescription)")
            return nil
        }
    }

    static func decode(_ data: Data?) -> OmniProspectiveMetadata? {
        guard let data else { return nil }
        do { return try JSONDecoder().decode(OmniProspectiveMetadata.self, from: data) } catch {
            memTypeLogger.debug("Failed to decode OmniProspectiveMetadata: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Memory Importance Weights

/// Weights for calculating memory importance
struct MemoryImportanceWeights {
    /// Weight for recency (how recently the memory was accessed)
    var recency: Double = 0.25

    /// Weight for frequency (how often the memory was accessed)
    var frequency: Double = 0.20

    /// Weight for confidence (how confident we are in the memory)
    var confidence: Double = 0.30

    /// Weight for source credibility
    var source: Double = 0.15

    /// Weight for user feedback (explicit corrections)
    var feedback: Double = 0.10
}

// MARK: - Memory Health Report

/// Report on memory system health
public struct MemoryHealthReport: Sendable {
    public let totalMemories: Int
    public let memoriesByType: [OmniMemoryType: Int]
    public let averageConfidence: Double
    public let memoriesAtRisk: Int // Below minimum retention threshold
    public let oldestMemoryAge: TimeInterval
    public let mostAccessedCategory: String?
    public let suggestedActions: [String]

    public var healthScore: Double {
        // Calculate overall health (0-1)
        var score = 0.0

        // Memory count factor (having memories is good, but not too many)
        let countScore = min(1.0, Double(totalMemories) / 1000.0) * 0.3
        score += countScore

        // Confidence factor
        score += averageConfidence * 0.4

        // Low risk factor
        let riskRatio = Double(memoriesAtRisk) / max(1, Double(totalMemories))
        score += (1.0 - riskRatio) * 0.3

        return score
    }
}

// MARK: - Memory Search Result

/// Result from semantic or keyword search
/// A single result from a semantic or keyword memory search, with relevance score.
public struct MemorySearchResult: Identifiable, Sendable {
    public let id: UUID
    public let memory: OmniMemoryRecord
    public let relevanceScore: Double
    public let matchType: MemoryMatchType

    public enum MemoryMatchType: String, Sendable {
        case semantic    // Found via embedding similarity
        case keyword     // Found via keyword matching
        case exact       // Exact key match
    }
}
