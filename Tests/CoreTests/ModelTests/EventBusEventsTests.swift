// EventBusEventsTests.swift
// Tests for EventSource, EventCategory, nested enums (MessageRole, ActionType,
// LearningType, MemoryOperation, MemoryTier, VerificationType, LifecycleType),
// and EventStatistics.
// Mirrors types in Shared/Core/EventBus/EventBusEvents.swift and EventBus.swift.
// Concrete event struct tests are in EventBusEventCreationTests.swift.

import Foundation
import XCTest

final class EventBusEventsTests: XCTestCase {

    // MARK: - EventSource (mirror EventBusEvents.swift)

    enum EventSource: String, Sendable, Codable, CaseIterable {
        case user, ai, system, agent, integration, scheduler, memory, verification
    }

    // MARK: - EventCategory (mirror EventBusEvents.swift)

    enum EventCategory: String, Sendable, Codable, CaseIterable {
        case message, action, navigation, state, error, performance
        case learning, integration, memory, verification, configuration, lifecycle
    }

    // MARK: - MessageRole (mirror MessageEvent.MessageRole)

    enum MessageRole: String, Sendable, Codable, CaseIterable {
        case user, assistant, system
    }

    // MARK: - ActionType (mirror ActionEvent.ActionType)

    enum ActionType: String, Sendable, Codable, CaseIterable {
        case codeExecution, terminalCommand, fileOperation
        case webSearch, apiCall, modelQuery
        case memoryStore, memoryRetrieve
        case verification, classification, routing
        case agentSpawn, workflowStep
    }

    // MARK: - LearningType (mirror LearningEvent.LearningType)

    enum LearningType: String, Sendable, Codable, CaseIterable {
        case userCorrection, patternDetected, preferenceInferred
        case errorFixed, workflowOptimized, feedbackPositive, feedbackNegative
    }

    // MARK: - MemoryOperation (mirror MemoryEvent.MemoryOperation)

    enum MemoryOperation: String, Sendable, Codable, CaseIterable {
        case store, retrieve, consolidate, prune, search
    }

    // MARK: - MemoryTier (mirror MemoryEvent.MemoryTier)

    enum MemoryTier: String, Sendable, Codable, CaseIterable {
        case working, episodic, semantic, procedural
    }

    // MARK: - VerificationType (mirror VerificationEvent.VerificationType)

    enum VerificationType: String, Sendable, Codable, CaseIterable {
        case multiModel, webSearch, codeExecution, staticAnalysis, userFeedback
    }

    // MARK: - LifecycleType (mirror LifecycleEvent.LifecycleType)

    enum LifecycleType: String, Sendable, Codable, CaseIterable {
        case appLaunch, appTerminate, appBackground, appForeground
        case sessionStart, sessionEnd, configurationChange
    }

    // MARK: - EventStatistics (mirror EventBus.EventStatistics)

    struct EventStatistics: Sendable {
        let totalEvents: Int
        let eventsByCategory: [EventCategory: Int]
        let eventsBySource: [EventSource: Int]
        let errorRate: Double
        let averageEventsPerMinute: Double
    }

    // =========================================================================
    // MARK: - EventSource Tests
    // =========================================================================

    func testEventSourceAllCasesExist() {
        let allCases = EventSource.allCases
        XCTAssertEqual(allCases.count, 8)
        XCTAssertTrue(allCases.contains(.user))
        XCTAssertTrue(allCases.contains(.ai))
        XCTAssertTrue(allCases.contains(.system))
        XCTAssertTrue(allCases.contains(.agent))
        XCTAssertTrue(allCases.contains(.integration))
        XCTAssertTrue(allCases.contains(.scheduler))
        XCTAssertTrue(allCases.contains(.memory))
        XCTAssertTrue(allCases.contains(.verification))
    }

    func testEventSourceUniqueRawValues() {
        let rawValues = EventSource.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "EventSource raw values must be unique")
    }

    func testEventSourceRawValues() {
        XCTAssertEqual(EventSource.user.rawValue, "user")
        XCTAssertEqual(EventSource.ai.rawValue, "ai")
        XCTAssertEqual(EventSource.system.rawValue, "system")
        XCTAssertEqual(EventSource.agent.rawValue, "agent")
        XCTAssertEqual(EventSource.integration.rawValue, "integration")
        XCTAssertEqual(EventSource.scheduler.rawValue, "scheduler")
        XCTAssertEqual(EventSource.memory.rawValue, "memory")
        XCTAssertEqual(EventSource.verification.rawValue, "verification")
    }

    func testEventSourceCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for source in EventSource.allCases {
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(EventSource.self, from: data)
            XCTAssertEqual(decoded, source, "\(source) should survive Codable roundtrip")
        }
    }

    func testEventSourceInitFromRawValue() {
        for source in EventSource.allCases {
            XCTAssertEqual(EventSource(rawValue: source.rawValue), source)
        }
        XCTAssertNil(EventSource(rawValue: "nonexistent"))
        XCTAssertNil(EventSource(rawValue: ""))
    }

    // =========================================================================
    // MARK: - EventCategory Tests
    // =========================================================================

    func testEventCategoryAllCasesExist() {
        let allCases = EventCategory.allCases
        XCTAssertEqual(allCases.count, 12)
        XCTAssertTrue(allCases.contains(.message))
        XCTAssertTrue(allCases.contains(.action))
        XCTAssertTrue(allCases.contains(.navigation))
        XCTAssertTrue(allCases.contains(.state))
        XCTAssertTrue(allCases.contains(.error))
        XCTAssertTrue(allCases.contains(.performance))
        XCTAssertTrue(allCases.contains(.learning))
        XCTAssertTrue(allCases.contains(.integration))
        XCTAssertTrue(allCases.contains(.memory))
        XCTAssertTrue(allCases.contains(.verification))
        XCTAssertTrue(allCases.contains(.configuration))
        XCTAssertTrue(allCases.contains(.lifecycle))
    }

    func testEventCategoryUniqueRawValues() {
        let rawValues = EventCategory.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "EventCategory raw values must be unique")
    }

    func testEventCategoryRawValues() {
        XCTAssertEqual(EventCategory.message.rawValue, "message")
        XCTAssertEqual(EventCategory.action.rawValue, "action")
        XCTAssertEqual(EventCategory.navigation.rawValue, "navigation")
        XCTAssertEqual(EventCategory.state.rawValue, "state")
        XCTAssertEqual(EventCategory.error.rawValue, "error")
        XCTAssertEqual(EventCategory.performance.rawValue, "performance")
        XCTAssertEqual(EventCategory.learning.rawValue, "learning")
        XCTAssertEqual(EventCategory.integration.rawValue, "integration")
        XCTAssertEqual(EventCategory.memory.rawValue, "memory")
        XCTAssertEqual(EventCategory.verification.rawValue, "verification")
        XCTAssertEqual(EventCategory.configuration.rawValue, "configuration")
        XCTAssertEqual(EventCategory.lifecycle.rawValue, "lifecycle")
    }

    func testEventCategoryCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for category in EventCategory.allCases {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(EventCategory.self, from: data)
            XCTAssertEqual(decoded, category, "\(category) should survive Codable roundtrip")
        }
    }

    func testEventCategoryInitFromRawValue() {
        for category in EventCategory.allCases {
            XCTAssertEqual(EventCategory(rawValue: category.rawValue), category)
        }
        XCTAssertNil(EventCategory(rawValue: "bogus"))
    }

    // =========================================================================
    // MARK: - MessageRole Tests
    // =========================================================================

    func testMessageRoleAllCases() {
        let allCases = MessageRole.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.user))
        XCTAssertTrue(allCases.contains(.assistant))
        XCTAssertTrue(allCases.contains(.system))
    }

    func testMessageRoleCodableRoundtrip() throws {
        for role in MessageRole.allCases {
            let data = try JSONEncoder().encode(role)
            let decoded = try JSONDecoder().decode(MessageRole.self, from: data)
            XCTAssertEqual(decoded, role)
        }
    }

    func testMessageRoleRawValues() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }

    // =========================================================================
    // MARK: - ActionType Tests
    // =========================================================================

    func testActionTypeAllCases() {
        let allCases = ActionType.allCases
        XCTAssertEqual(allCases.count, 13)
        XCTAssertTrue(allCases.contains(.codeExecution))
        XCTAssertTrue(allCases.contains(.terminalCommand))
        XCTAssertTrue(allCases.contains(.fileOperation))
        XCTAssertTrue(allCases.contains(.webSearch))
        XCTAssertTrue(allCases.contains(.apiCall))
        XCTAssertTrue(allCases.contains(.modelQuery))
        XCTAssertTrue(allCases.contains(.memoryStore))
        XCTAssertTrue(allCases.contains(.memoryRetrieve))
        XCTAssertTrue(allCases.contains(.verification))
        XCTAssertTrue(allCases.contains(.classification))
        XCTAssertTrue(allCases.contains(.routing))
        XCTAssertTrue(allCases.contains(.agentSpawn))
        XCTAssertTrue(allCases.contains(.workflowStep))
    }

    func testActionTypeUniqueRawValues() {
        let rawValues = ActionType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "ActionType raw values must be unique")
    }

    func testActionTypeCodableRoundtrip() throws {
        for actionType in ActionType.allCases {
            let data = try JSONEncoder().encode(actionType)
            let decoded = try JSONDecoder().decode(ActionType.self, from: data)
            XCTAssertEqual(decoded, actionType, "\(actionType) should survive Codable roundtrip")
        }
    }

    // =========================================================================
    // MARK: - LearningType Tests
    // =========================================================================

    func testLearningTypeAllCases() {
        let allCases = LearningType.allCases
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.userCorrection))
        XCTAssertTrue(allCases.contains(.patternDetected))
        XCTAssertTrue(allCases.contains(.preferenceInferred))
        XCTAssertTrue(allCases.contains(.errorFixed))
        XCTAssertTrue(allCases.contains(.workflowOptimized))
        XCTAssertTrue(allCases.contains(.feedbackPositive))
        XCTAssertTrue(allCases.contains(.feedbackNegative))
    }

    func testLearningTypeUniqueRawValues() {
        let rawValues = LearningType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "LearningType raw values must be unique")
    }

    func testLearningTypeCodableRoundtrip() throws {
        for learningType in LearningType.allCases {
            let data = try JSONEncoder().encode(learningType)
            let decoded = try JSONDecoder().decode(LearningType.self, from: data)
            XCTAssertEqual(decoded, learningType)
        }
    }

    // =========================================================================
    // MARK: - MemoryOperation Tests
    // =========================================================================

    func testMemoryOperationAllCases() {
        let allCases = MemoryOperation.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.store))
        XCTAssertTrue(allCases.contains(.retrieve))
        XCTAssertTrue(allCases.contains(.consolidate))
        XCTAssertTrue(allCases.contains(.prune))
        XCTAssertTrue(allCases.contains(.search))
    }

    func testMemoryOperationUniqueRawValues() {
        let rawValues = MemoryOperation.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testMemoryOperationCodableRoundtrip() throws {
        for op in MemoryOperation.allCases {
            let data = try JSONEncoder().encode(op)
            let decoded = try JSONDecoder().decode(MemoryOperation.self, from: data)
            XCTAssertEqual(decoded, op)
        }
    }

    // =========================================================================
    // MARK: - MemoryTier Tests
    // =========================================================================

    func testMemoryTierAllCases() {
        let allCases = MemoryTier.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.working))
        XCTAssertTrue(allCases.contains(.episodic))
        XCTAssertTrue(allCases.contains(.semantic))
        XCTAssertTrue(allCases.contains(.procedural))
    }

    func testMemoryTierUniqueRawValues() {
        let rawValues = MemoryTier.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testMemoryTierCodableRoundtrip() throws {
        for tier in MemoryTier.allCases {
            let data = try JSONEncoder().encode(tier)
            let decoded = try JSONDecoder().decode(MemoryTier.self, from: data)
            XCTAssertEqual(decoded, tier)
        }
    }

    // =========================================================================
    // MARK: - VerificationType Tests
    // =========================================================================

    func testVerificationTypeAllCases() {
        let allCases = VerificationType.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.multiModel))
        XCTAssertTrue(allCases.contains(.webSearch))
        XCTAssertTrue(allCases.contains(.codeExecution))
        XCTAssertTrue(allCases.contains(.staticAnalysis))
        XCTAssertTrue(allCases.contains(.userFeedback))
    }

    func testVerificationTypeUniqueRawValues() {
        let rawValues = VerificationType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testVerificationTypeCodableRoundtrip() throws {
        for vType in VerificationType.allCases {
            let data = try JSONEncoder().encode(vType)
            let decoded = try JSONDecoder().decode(VerificationType.self, from: data)
            XCTAssertEqual(decoded, vType)
        }
    }

    // =========================================================================
    // MARK: - LifecycleType Tests
    // =========================================================================

    func testLifecycleTypeAllCases() {
        let allCases = LifecycleType.allCases
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.appLaunch))
        XCTAssertTrue(allCases.contains(.appTerminate))
        XCTAssertTrue(allCases.contains(.appBackground))
        XCTAssertTrue(allCases.contains(.appForeground))
        XCTAssertTrue(allCases.contains(.sessionStart))
        XCTAssertTrue(allCases.contains(.sessionEnd))
        XCTAssertTrue(allCases.contains(.configurationChange))
    }

    func testLifecycleTypeUniqueRawValues() {
        let rawValues = LifecycleType.allCases.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count)
    }

    func testLifecycleTypeCodableRoundtrip() throws {
        for lcType in LifecycleType.allCases {
            let data = try JSONEncoder().encode(lcType)
            let decoded = try JSONDecoder().decode(LifecycleType.self, from: data)
            XCTAssertEqual(decoded, lcType)
        }
    }

    func testLifecycleTypeRawValues() {
        XCTAssertEqual(LifecycleType.appLaunch.rawValue, "appLaunch")
        XCTAssertEqual(LifecycleType.appTerminate.rawValue, "appTerminate")
        XCTAssertEqual(LifecycleType.appBackground.rawValue, "appBackground")
        XCTAssertEqual(LifecycleType.appForeground.rawValue, "appForeground")
        XCTAssertEqual(LifecycleType.sessionStart.rawValue, "sessionStart")
        XCTAssertEqual(LifecycleType.sessionEnd.rawValue, "sessionEnd")
        XCTAssertEqual(LifecycleType.configurationChange.rawValue, "configurationChange")
    }

    // =========================================================================
    // MARK: - EventStatistics Tests
    // =========================================================================

    func testEventStatisticsEmpty() {
        let stats = EventStatistics(
            totalEvents: 0, eventsByCategory: [:], eventsBySource: [:],
            errorRate: 0.0, averageEventsPerMinute: 0.0
        )
        XCTAssertEqual(stats.totalEvents, 0)
        XCTAssertTrue(stats.eventsByCategory.isEmpty)
        XCTAssertTrue(stats.eventsBySource.isEmpty)
        XCTAssertEqual(stats.errorRate, 0.0)
        XCTAssertEqual(stats.averageEventsPerMinute, 0.0)
    }

    func testEventStatisticsPopulated() {
        let stats = EventStatistics(
            totalEvents: 250,
            eventsByCategory: [.message: 100, .action: 60, .error: 15, .performance: 40, .state: 35],
            eventsBySource: [.user: 80, .ai: 90, .system: 50, .agent: 30],
            errorRate: 0.06, averageEventsPerMinute: 12.5
        )
        XCTAssertEqual(stats.totalEvents, 250)
        XCTAssertEqual(stats.eventsByCategory[.message], 100)
        XCTAssertEqual(stats.eventsByCategory[.action], 60)
        XCTAssertEqual(stats.eventsByCategory[.error], 15)
        XCTAssertNil(stats.eventsByCategory[.lifecycle])
        XCTAssertEqual(stats.eventsBySource[.user], 80)
        XCTAssertEqual(stats.eventsBySource[.ai], 90)
        XCTAssertNil(stats.eventsBySource[.scheduler])
        XCTAssertEqual(stats.errorRate, 0.06, accuracy: 0.001)
        XCTAssertEqual(stats.averageEventsPerMinute, 12.5, accuracy: 0.001)
    }

    func testEventStatisticsErrorRateCalculation() {
        let totalEvents = 200
        let errorCount = 10
        let errorRate = totalEvents > 0 ? Double(errorCount) / Double(totalEvents) : 0
        let stats = EventStatistics(
            totalEvents: totalEvents,
            eventsByCategory: [.error: errorCount, .message: 190],
            eventsBySource: [.system: 200],
            errorRate: errorRate, averageEventsPerMinute: 5.0
        )
        XCTAssertEqual(stats.errorRate, 0.05, accuracy: 0.0001)
    }

    func testEventStatisticsZeroErrorRate() {
        let stats = EventStatistics(
            totalEvents: 100, eventsByCategory: [.message: 50, .action: 50],
            eventsBySource: [.user: 100], errorRate: 0.0, averageEventsPerMinute: 3.0
        )
        XCTAssertEqual(stats.errorRate, 0.0)
        XCTAssertNil(stats.eventsByCategory[.error])
    }

    func testEventStatisticsHighErrorRate() {
        let stats = EventStatistics(
            totalEvents: 10, eventsByCategory: [.error: 8, .message: 2],
            eventsBySource: [.system: 10], errorRate: 0.8, averageEventsPerMinute: 1.0
        )
        XCTAssertEqual(stats.errorRate, 0.8, accuracy: 0.001)
        XCTAssertEqual(stats.eventsByCategory[.error], 8)
    }
}
