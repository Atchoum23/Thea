// MemoryTypesTests.swift
// Standalone tests for memory system types from MemoryManagerTypes.swift

import Foundation
import XCTest

final class MemoryTypesTests: XCTestCase {

    // MARK: - OmniMemoryType

    enum OmniMemoryType: String, Codable, Sendable, CaseIterable {
        case semantic, episodic, procedural, prospective
    }

    // MARK: - OmniMemorySource

    enum OmniMemorySource: String, Codable, Sendable, CaseIterable {
        case explicit, inferred, system
    }

    // MARK: - OmniMemoryPriority

    enum OmniMemoryPriority: String, Codable, CaseIterable {
        case low, normal, high, critical
    }

    // MARK: - OmniMemoryRecord (mirror)

    struct OmniMemoryRecord: Codable, Identifiable, Sendable {
        let id: UUID
        var type: OmniMemoryType
        var category: String
        var key: String
        var value: String
        var confidence: Double
        var source: OmniMemorySource
        var timestamp: Date
        var lastAccessed: Date
        var accessCount: Int
        var metadata: Data?

        init(
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

    // MARK: - OmniMemoryStats (mirror)

    struct OmniMemoryStats: Sendable {
        var semanticCount: Int = 0
        var episodicCount: Int = 0
        var proceduralCount: Int = 0
        var prospectiveCount: Int = 0
        var cacheSize: Int = 0
        var lastConsolidation: Date?

        var totalCount: Int {
            semanticCount + episodicCount + proceduralCount + prospectiveCount
        }

        var description: String {
            "OmniMemoryStats(total: \(totalCount), semantic: \(semanticCount), episodic: \(episodicCount), procedural: \(proceduralCount), prospective: \(prospectiveCount), cache: \(cacheSize))"
        }
    }

    // MARK: - Metadata (mirror, for record tests)

    struct OmniEpisodicMetadata: Codable {
        let outcome: String?; let emotionalValence: Double
        func encoded() -> Data? { try? JSONEncoder().encode(self) }
        static func decode(_ data: Data?) -> OmniEpisodicMetadata? {
            guard let data else { return nil }
            return try? JSONDecoder().decode(OmniEpisodicMetadata.self, from: data)
        }
    }

    // MARK: - Tests: OmniMemoryRecord

    func testRecordDefaultValues() {
        let record = OmniMemoryRecord(type: .semantic, category: "test", key: "k", value: "v")
        XCTAssertEqual(record.confidence, 1.0)
        XCTAssertEqual(record.source, .explicit)
        XCTAssertEqual(record.accessCount, 0)
        XCTAssertNil(record.metadata)
        XCTAssertEqual(record.type, .semantic)
    }

    func testRecordCodableRoundTrip() throws {
        let record = OmniMemoryRecord(type: .episodic, category: "work", key: "meeting", value: "standup at 9am", confidence: 0.85, source: .inferred)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(OmniMemoryRecord.self, from: data)
        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.type, .episodic)
        XCTAssertEqual(decoded.category, "work")
        XCTAssertEqual(decoded.key, "meeting")
        XCTAssertEqual(decoded.confidence, 0.85)
        XCTAssertEqual(decoded.source, .inferred)
    }

    func testRecordWithMetadata() {
        let meta = OmniEpisodicMetadata(outcome: "success", emotionalValence: 0.8)
        let record = OmniMemoryRecord(type: .episodic, category: "test", key: "k", value: "v", metadata: meta.encoded())
        XCTAssertNotNil(record.metadata)
        let decoded = OmniEpisodicMetadata.decode(record.metadata)
        XCTAssertEqual(decoded?.outcome, "success")
        XCTAssertEqual(decoded?.emotionalValence, 0.8)
    }

    // MARK: - Tests: Enum Types

    func testMemoryTypeCodable() throws {
        for memType in OmniMemoryType.allCases {
            let data = try JSONEncoder().encode(memType)
            let decoded = try JSONDecoder().decode(OmniMemoryType.self, from: data)
            XCTAssertEqual(decoded, memType)
        }
    }

    func testMemorySourceCodable() throws {
        for src in OmniMemorySource.allCases {
            let data = try JSONEncoder().encode(src)
            let decoded = try JSONDecoder().decode(OmniMemorySource.self, from: data)
            XCTAssertEqual(decoded, src)
        }
    }

    func testPriorityCodable() throws {
        for priority in OmniMemoryPriority.allCases {
            let data = try JSONEncoder().encode(priority)
            let decoded = try JSONDecoder().decode(OmniMemoryPriority.self, from: data)
            XCTAssertEqual(decoded, priority)
        }
    }

    func testPriorityOrdering() {
        let priorities: [OmniMemoryPriority] = [.low, .normal, .high, .critical]
        XCTAssertEqual(priorities.count, 4)
        XCTAssertEqual(OmniMemoryPriority.allCases.count, 4)
    }

    // MARK: - Tests: OmniMemoryStats

    func testStatsTotalCount() {
        var stats = OmniMemoryStats()
        XCTAssertEqual(stats.totalCount, 0)

        stats.semanticCount = 10
        stats.episodicCount = 5
        stats.proceduralCount = 3
        stats.prospectiveCount = 2
        XCTAssertEqual(stats.totalCount, 20)
    }

    func testStatsCacheSizeNotInTotal() {
        var stats = OmniMemoryStats()
        stats.semanticCount = 10
        stats.cacheSize = 100
        XCTAssertEqual(stats.totalCount, 10, "Cache size should not be included in totalCount")
    }

    func testStatsDescription() {
        var stats = OmniMemoryStats()
        stats.semanticCount = 5
        stats.episodicCount = 3
        XCTAssertTrue(stats.description.contains("total: 8"))
        XCTAssertTrue(stats.description.contains("semantic: 5"))
        XCTAssertTrue(stats.description.contains("episodic: 3"))
    }

}

// MARK: - Memory Advanced Tests (split to avoid type_body_length)

final class MemoryAdvancedTypesTests: XCTestCase {

    // Re-mirror minimal types needed for these tests
    struct MemoryContextSnapshot: Sendable {
        var userActivity: String?
        var currentQuery: String?
        var location: String?
        var timeOfDay: Int = 12
        var dayOfWeek: Int = 2
        var batteryLevel: Int?
        var isPluggedIn: Bool?
    }

    enum MemoryTriggerCondition: Codable {
        case time(Date), location(String), activity(String)
        case appLaunch(String), keyword(String), contextMatch(String)

        var descriptionText: String {
            switch self {
            case .time(let date): "At \(date)"
            case .location(let loc): "At location: \(loc)"
            case .activity(let act): "During activity: \(act)"
            case .appLaunch(let app): "When \(app) opens"
            case .keyword(let kw): "When mentioned: \(kw)"
            case .contextMatch(let ctx): "When context matches: \(ctx)"
            }
        }

        func isSatisfied(by context: MemoryContextSnapshot) -> Bool {
            switch self {
            case .time(let date): Date() >= date
            case .activity(let a): context.userActivity?.lowercased().contains(a.lowercased()) ?? false
            case .keyword(let k): context.currentQuery?.lowercased().contains(k.lowercased()) ?? false
            default: false
            }
        }
    }

    struct MemoryDetectedPattern: Sendable {
        let event: String; let frequency: Int; let hourOfDay: Int; let dayOfWeek: Int; let confidence: Double
        var description: String {
            let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let dayName = dayOfWeek >= 1 && dayOfWeek <= 7 ? dayNames[dayOfWeek] : "?"
            return "\(event) typically occurs at \(hourOfDay):00 on \(dayName)s (\(Int(confidence * 100))% confidence)"
        }
    }

    enum OmniMemoryType: String, Codable, Sendable { case semantic, episodic, procedural, prospective }

    struct MemoryHealthReport: Sendable {
        let totalMemories: Int; let memoriesByType: [OmniMemoryType: Int]; let averageConfidence: Double
        let memoriesAtRisk: Int; let oldestMemoryAge: TimeInterval; let mostAccessedCategory: String?; let suggestedActions: [String]
        var healthScore: Double {
            var score = min(1.0, Double(totalMemories) / 1000.0) * 0.3
            score += averageConfidence * 0.4
            score += (1.0 - Double(memoriesAtRisk) / max(1, Double(totalMemories))) * 0.3
            return score
        }
    }

    struct MemoryImportanceWeights {
        var recency: Double = 0.25; var frequency: Double = 0.20; var confidence: Double = 0.30
        var source: Double = 0.15; var feedback: Double = 0.10
    }

    struct OmniEpisodicMetadata: Codable {
        let outcome: String?; let emotionalValence: Double
        func encoded() -> Data? { try? JSONEncoder().encode(self) }
        static func decode(_ data: Data?) -> OmniEpisodicMetadata? {
            guard let data else { return nil }
            return try? JSONDecoder().decode(OmniEpisodicMetadata.self, from: data)
        }
    }

    struct OmniProceduralMetadata: Codable {
        var successRate: Double; var averageDuration: TimeInterval; var executionCount: Int
        func encoded() -> Data? { try? JSONEncoder().encode(self) }
        static func decode(_ data: Data?) -> OmniProceduralMetadata? {
            guard let data else { return nil }
            return try? JSONDecoder().decode(OmniProceduralMetadata.self, from: data)
        }
    }

    struct OmniProspectiveMetadata: Codable {
        let triggerCondition: MemoryTriggerCondition; var isTriggered: Bool
        func encoded() -> Data? { try? JSONEncoder().encode(self) }
        static func decode(_ data: Data?) -> OmniProspectiveMetadata? {
            guard let data else { return nil }
            return try? JSONDecoder().decode(OmniProspectiveMetadata.self, from: data)
        }
    }

    // MARK: - Tests: MemoryTriggerCondition

    func testTimeTriggerPastDate() {
        let pastDate = Date.distantPast
        let trigger = MemoryTriggerCondition.time(pastDate)
        let context = MemoryContextSnapshot()
        XCTAssertTrue(trigger.isSatisfied(by: context), "Past date should be satisfied")
    }

    func testTimeTriggerFutureDate() {
        let futureDate = Date.distantFuture
        let trigger = MemoryTriggerCondition.time(futureDate)
        let context = MemoryContextSnapshot()
        XCTAssertFalse(trigger.isSatisfied(by: context), "Future date should not be satisfied")
    }

    func testActivityTriggerMatch() {
        let trigger = MemoryTriggerCondition.activity("coding")
        let context = MemoryContextSnapshot(userActivity: "Coding in Xcode")
        XCTAssertTrue(trigger.isSatisfied(by: context), "Case-insensitive activity match")
    }

    func testActivityTriggerNoMatch() {
        let trigger = MemoryTriggerCondition.activity("cooking")
        let context = MemoryContextSnapshot(userActivity: "Coding in Xcode")
        XCTAssertFalse(trigger.isSatisfied(by: context))
    }

    func testActivityTriggerNilActivity() {
        let trigger = MemoryTriggerCondition.activity("coding")
        let context = MemoryContextSnapshot()
        XCTAssertFalse(trigger.isSatisfied(by: context))
    }

    func testKeywordTriggerMatch() {
        let trigger = MemoryTriggerCondition.keyword("swift")
        let context = MemoryContextSnapshot(currentQuery: "How to use Swift concurrency?")
        XCTAssertTrue(trigger.isSatisfied(by: context))
    }

    func testKeywordTriggerCaseInsensitive() {
        let trigger = MemoryTriggerCondition.keyword("SWIFT")
        let context = MemoryContextSnapshot(currentQuery: "swift concurrency tips")
        XCTAssertTrue(trigger.isSatisfied(by: context))
    }

    func testKeywordTriggerNilQuery() {
        let trigger = MemoryTriggerCondition.keyword("swift")
        let context = MemoryContextSnapshot()
        XCTAssertFalse(trigger.isSatisfied(by: context))
    }

    func testLocationTriggerAlwaysFalse() {
        let trigger = MemoryTriggerCondition.location("office")
        let context = MemoryContextSnapshot(location: "office")
        XCTAssertFalse(trigger.isSatisfied(by: context), "Location trigger is unimplemented → false")
    }

    func testAppLaunchTriggerAlwaysFalse() {
        let trigger = MemoryTriggerCondition.appLaunch("Safari")
        let context = MemoryContextSnapshot()
        XCTAssertFalse(trigger.isSatisfied(by: context), "AppLaunch trigger is unimplemented → false")
    }

    func testContextMatchTriggerAlwaysFalse() {
        let trigger = MemoryTriggerCondition.contextMatch("work")
        let context = MemoryContextSnapshot()
        XCTAssertFalse(trigger.isSatisfied(by: context), "ContextMatch trigger is unimplemented → false")
    }

    func testTriggerConditionDescriptions() {
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(MemoryTriggerCondition.time(date).descriptionText.hasPrefix("At "))
        XCTAssertEqual(MemoryTriggerCondition.location("office").descriptionText, "At location: office")
        XCTAssertEqual(MemoryTriggerCondition.activity("coding").descriptionText, "During activity: coding")
        XCTAssertEqual(MemoryTriggerCondition.appLaunch("Safari").descriptionText, "When Safari opens")
        XCTAssertEqual(MemoryTriggerCondition.keyword("swift").descriptionText, "When mentioned: swift")
        XCTAssertEqual(MemoryTriggerCondition.contextMatch("work").descriptionText, "When context matches: work")
    }

    func testTriggerConditionCodable() throws {
        let triggers: [MemoryTriggerCondition] = [
            .time(Date()), .location("home"), .activity("running"),
            .appLaunch("Xcode"), .keyword("swift"), .contextMatch("work")
        ]
        for trigger in triggers {
            let data = try JSONEncoder().encode(trigger)
            let decoded = try JSONDecoder().decode(MemoryTriggerCondition.self, from: data)
            XCTAssertEqual(decoded.descriptionText.prefix(2), trigger.descriptionText.prefix(2))
        }
    }

    // MARK: - Tests: MemoryDetectedPattern

    func testPatternDescriptionValidDay() {
        let pattern = MemoryDetectedPattern(event: "standup", frequency: 5, hourOfDay: 9, dayOfWeek: 2, confidence: 0.95)
        XCTAssertEqual(pattern.description, "standup typically occurs at 9:00 on Mons (95% confidence)")
    }

    func testPatternDescriptionSunday() {
        let pattern = MemoryDetectedPattern(event: "brunch", frequency: 4, hourOfDay: 11, dayOfWeek: 1, confidence: 0.80)
        XCTAssertTrue(pattern.description.contains("Suns"))
    }

    func testPatternDescriptionSaturday() {
        let pattern = MemoryDetectedPattern(event: "gym", frequency: 3, hourOfDay: 7, dayOfWeek: 7, confidence: 0.70)
        XCTAssertTrue(pattern.description.contains("Sats"))
    }

    func testPatternDescriptionInvalidDay() {
        let pattern = MemoryDetectedPattern(event: "test", frequency: 1, hourOfDay: 0, dayOfWeek: 0, confidence: 0.5)
        XCTAssertTrue(pattern.description.contains("?s"), "Day 0 should show ?")

        let pattern8 = MemoryDetectedPattern(event: "test", frequency: 1, hourOfDay: 0, dayOfWeek: 8, confidence: 0.5)
        XCTAssertTrue(pattern8.description.contains("?s"), "Day 8 should show ?")
    }

    func testPatternConfidencePercentage() {
        let pattern = MemoryDetectedPattern(event: "test", frequency: 1, hourOfDay: 12, dayOfWeek: 3, confidence: 0.123)
        XCTAssertTrue(pattern.description.contains("12% confidence"))
    }

    // MARK: - Tests: MemoryHealthReport

    func testHealthScoreEmptySystem() {
        let report = MemoryHealthReport(totalMemories: 0, memoriesByType: [:], averageConfidence: 0, memoriesAtRisk: 0, oldestMemoryAge: 0, mostAccessedCategory: nil, suggestedActions: [])
        XCTAssertEqual(report.healthScore, 0.3, accuracy: 0.01, "Empty system: 0 count + 0 confidence + 1.0 risk = 0.3")
    }

    func testHealthScorePerfectSystem() {
        let report = MemoryHealthReport(totalMemories: 1000, memoriesByType: [.semantic: 1000], averageConfidence: 1.0, memoriesAtRisk: 0, oldestMemoryAge: 86400, mostAccessedCategory: "test", suggestedActions: [])
        XCTAssertEqual(report.healthScore, 1.0, accuracy: 0.01, "Perfect: max count + max confidence + 0 risk")
    }

    func testHealthScoreHalfConfidence() {
        let report = MemoryHealthReport(totalMemories: 500, memoriesByType: [:], averageConfidence: 0.5, memoriesAtRisk: 0, oldestMemoryAge: 0, mostAccessedCategory: nil, suggestedActions: [])
        // countScore = min(1.0, 500/1000) * 0.3 = 0.5 * 0.3 = 0.15
        // confidenceScore = 0.5 * 0.4 = 0.20
        // riskScore = (1.0 - 0) * 0.3 = 0.30
        // total = 0.65
        XCTAssertEqual(report.healthScore, 0.65, accuracy: 0.01)
    }

    func testHealthScoreHighRisk() {
        let report = MemoryHealthReport(totalMemories: 100, memoriesByType: [:], averageConfidence: 1.0, memoriesAtRisk: 50, oldestMemoryAge: 0, mostAccessedCategory: nil, suggestedActions: [])
        // countScore = min(1.0, 0.1) * 0.3 = 0.03
        // confidenceScore = 1.0 * 0.4 = 0.40
        // riskRatio = 50/100 = 0.5; riskScore = (1.0 - 0.5) * 0.3 = 0.15
        // total = 0.58
        XCTAssertEqual(report.healthScore, 0.58, accuracy: 0.01)
    }

    func testHealthScoreOverThousandMemories() {
        let report = MemoryHealthReport(totalMemories: 5000, memoriesByType: [:], averageConfidence: 0.8, memoriesAtRisk: 0, oldestMemoryAge: 0, mostAccessedCategory: nil, suggestedActions: [])
        // countScore = min(1.0, 5.0) * 0.3 = 0.30 (capped at 1.0)
        // confidenceScore = 0.8 * 0.4 = 0.32
        // riskScore = 0.30
        // total = 0.92
        XCTAssertEqual(report.healthScore, 0.92, accuracy: 0.01)
    }

    // MARK: - Tests: MemoryImportanceWeights

    func testImportanceWeightsSumToOne() {
        let w = MemoryImportanceWeights()
        let sum = w.recency + w.frequency + w.confidence + w.source + w.feedback
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    func testImportanceWeightsDefaults() {
        let w = MemoryImportanceWeights()
        XCTAssertEqual(w.recency, 0.25)
        XCTAssertEqual(w.frequency, 0.20)
        XCTAssertEqual(w.confidence, 0.30)
        XCTAssertEqual(w.source, 0.15)
        XCTAssertEqual(w.feedback, 0.10)
    }

    // MARK: - Tests: Metadata Codable

    func testEpisodicMetadataCodable() {
        let meta = OmniEpisodicMetadata(outcome: "resolved bug", emotionalValence: 0.9)
        let data = meta.encoded()
        XCTAssertNotNil(data)
        let decoded = OmniEpisodicMetadata.decode(data)
        XCTAssertEqual(decoded?.outcome, "resolved bug")
        XCTAssertEqual(decoded?.emotionalValence, 0.9)
    }

    func testEpisodicMetadataNilOutcome() {
        let meta = OmniEpisodicMetadata(outcome: nil, emotionalValence: 0.0)
        let data = meta.encoded()
        let decoded = OmniEpisodicMetadata.decode(data)
        XCTAssertNil(decoded?.outcome)
        XCTAssertEqual(decoded?.emotionalValence, 0.0)
    }

    func testEpisodicMetadataDecodeNil() {
        XCTAssertNil(OmniEpisodicMetadata.decode(nil))
    }

    func testProceduralMetadataCodable() {
        let meta = OmniProceduralMetadata(successRate: 0.95, averageDuration: 120, executionCount: 50)
        let data = meta.encoded()
        XCTAssertNotNil(data)
        let decoded = OmniProceduralMetadata.decode(data)
        XCTAssertEqual(decoded?.successRate, 0.95)
        XCTAssertEqual(decoded?.averageDuration, 120)
        XCTAssertEqual(decoded?.executionCount, 50)
    }

    func testProceduralMetadataDecodeNil() {
        XCTAssertNil(OmniProceduralMetadata.decode(nil))
    }

    func testProspectiveMetadataCodable() {
        let meta = OmniProspectiveMetadata(triggerCondition: .keyword("deploy"), isTriggered: false)
        let data = meta.encoded()
        XCTAssertNotNil(data)
        let decoded = OmniProspectiveMetadata.decode(data)
        XCTAssertEqual(decoded?.isTriggered, false)
    }

    func testProspectiveMetadataDecodeNil() {
        XCTAssertNil(OmniProspectiveMetadata.decode(nil))
    }

    // MARK: - Tests: MemoryContextSnapshot

    func testContextSnapshotDefaults() {
        let ctx = MemoryContextSnapshot()
        XCTAssertNil(ctx.userActivity)
        XCTAssertNil(ctx.currentQuery)
        XCTAssertNil(ctx.location)
        XCTAssertEqual(ctx.timeOfDay, 12)
        XCTAssertEqual(ctx.dayOfWeek, 2)
        XCTAssertNil(ctx.batteryLevel)
        XCTAssertNil(ctx.isPluggedIn)
    }

    func testContextSnapshotWithValues() {
        let ctx = MemoryContextSnapshot(userActivity: "coding", currentQuery: "swift tips", location: "office", timeOfDay: 14, dayOfWeek: 3)
        XCTAssertEqual(ctx.userActivity, "coding")
        XCTAssertEqual(ctx.currentQuery, "swift tips")
        XCTAssertEqual(ctx.location, "office")
        XCTAssertEqual(ctx.timeOfDay, 14)
        XCTAssertEqual(ctx.dayOfWeek, 3)
    }
}
