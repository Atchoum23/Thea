// EventBusCrossCuttingTests.swift
// Cross-event ID uniqueness and category mapping tests
// that validate all 11 event types together.
// Companion to EventBusEventCreationTests.swift and
// EventBusEventExtendedTests.swift.
// Mirrors types in Shared/Core/EventBus/EventBusEvents.swift.

import Foundation
import XCTest

final class EventBusCrossCuttingTests: XCTestCase {

    // MARK: - Mirror Enums

    enum EventSource: String, Sendable { case user, ai, system, agent, memory, verification }
    enum EventCategory: String, Sendable {
        case message, action, navigation, state, error, performance
        case learning, memory, verification, lifecycle
    }
    enum MessageRole: String, Sendable { case user, assistant, system }
    enum ActionType: String, Sendable { case apiCall }
    enum LearningType: String, Sendable { case patternDetected }
    enum MemoryOperation: String, Sendable { case store }
    enum MemoryTier: String, Sendable { case working }
    enum VerificationType: String, Sendable { case multiModel }
    enum LifecycleType: String, Sendable { case appLaunch }

    // MARK: - Mirror Structs

    struct MessageEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .message }
        let conversationId: UUID; let content: String; let role: MessageRole
        let model: String?; let confidence: Double?; let tokenCount: Int?
    }
    struct ActionEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .action }
        let actionType: ActionType; let target: String?
        let parameters: [String: String]; let success: Bool
        let duration: TimeInterval?; let error: String?
    }
    struct StateEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .state }
        let component: String; let previousState: String?
        let newState: String; let reason: String?
    }
    struct ErrorEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .error }
        let errorType: String; let message: String
        let context: [String: String]; let recoverable: Bool; let stackTrace: String?
    }
    struct PerformanceEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .performance }
        let operation: String; let duration: TimeInterval; let metadata: [String: String]
    }
    struct LearningEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .learning }
        let learningType: LearningType; let relatedEventId: UUID?
        let data: [String: String]; let improvement: Double?
    }
    struct MemoryEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .memory }
        let operation: MemoryOperation; let tier: MemoryTier
        let itemCount: Int; let relevanceScore: Double?
    }
    struct VerificationEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .verification }
        let verificationType: VerificationType; let confidence: Double
        let sources: [String]; let conflicts: Int
    }
    struct NavigationEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .navigation }
        let fromView: String?; let toView: String; let parameters: [String: String]
    }
    struct ComponentEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .state }
        let action: String; let component: String; let details: [String: String]
    }
    struct LifecycleEvent: Identifiable {
        let id: UUID; let timestamp: Date; let source: EventSource
        var category: EventCategory { .lifecycle }
        let event: LifecycleType; let details: [String: String]
    }

    // MARK: - Cross-Event ID Uniqueness

    func testAllEventIDsAreUnique() {
        let ids = (0..<11).map { _ in UUID() }
        let events: [any Identifiable] = [
            MessageEvent(id: ids[0], timestamp: Date(), source: .user,
                         conversationId: UUID(), content: "msg",
                         role: .user, model: nil, confidence: nil, tokenCount: nil),
            ActionEvent(id: ids[1], timestamp: Date(), source: .ai,
                        actionType: .apiCall, target: nil, parameters: [:],
                        success: true, duration: nil, error: nil),
            StateEvent(id: ids[2], timestamp: Date(), source: .system,
                       component: "X", previousState: nil, newState: "Y", reason: nil),
            ErrorEvent(id: ids[3], timestamp: Date(), source: .system,
                       errorType: "E", message: "M", context: [:],
                       recoverable: true, stackTrace: nil),
            PerformanceEvent(id: ids[4], timestamp: Date(), source: .system,
                             operation: "op", duration: 0.1, metadata: [:]),
            LearningEvent(id: ids[5], timestamp: Date(), source: .ai,
                          learningType: .patternDetected, relatedEventId: nil,
                          data: [:], improvement: nil),
            MemoryEvent(id: ids[6], timestamp: Date(), source: .memory,
                        operation: .store, tier: .working,
                        itemCount: 1, relevanceScore: nil),
            VerificationEvent(id: ids[7], timestamp: Date(), source: .verification,
                              verificationType: .multiModel, confidence: 0.5,
                              sources: [], conflicts: 0),
            NavigationEvent(id: ids[8], timestamp: Date(), source: .user,
                            fromView: nil, toView: "V", parameters: [:]),
            ComponentEvent(id: ids[9], timestamp: Date(), source: .system,
                           action: "a", component: "c", details: [:]),
            LifecycleEvent(id: ids[10], timestamp: Date(), source: .system,
                           event: .appLaunch, details: [:])
        ]
        var seenIDs = Set<String>()
        for event in events {
            let idString = String(describing: event.id)
            XCTAssertFalse(seenIDs.contains(idString), "Duplicate event ID: \(idString)")
            seenIDs.insert(idString)
        }
        XCTAssertEqual(seenIDs.count, 11)
    }

    // MARK: - Event Category Mapping

    func testEachEventTypeReturnsCorrectCategory() {
        XCTAssertEqual(
            MessageEvent(id: UUID(), timestamp: Date(), source: .user,
                         conversationId: UUID(), content: "", role: .user,
                         model: nil, confidence: nil, tokenCount: nil).category, .message)
        XCTAssertEqual(
            ActionEvent(id: UUID(), timestamp: Date(), source: .ai,
                        actionType: .apiCall, target: nil, parameters: [:],
                        success: true, duration: nil, error: nil).category, .action)
        XCTAssertEqual(
            StateEvent(id: UUID(), timestamp: Date(), source: .system,
                       component: "X", previousState: nil, newState: "Y",
                       reason: nil).category, .state)
        XCTAssertEqual(
            ErrorEvent(id: UUID(), timestamp: Date(), source: .system,
                       errorType: "E", message: "M", context: [:],
                       recoverable: true, stackTrace: nil).category, .error)
        XCTAssertEqual(
            PerformanceEvent(id: UUID(), timestamp: Date(), source: .system,
                             operation: "op", duration: 0.1, metadata: [:]).category,
            .performance)
        XCTAssertEqual(
            LearningEvent(id: UUID(), timestamp: Date(), source: .ai,
                          learningType: .patternDetected, relatedEventId: nil,
                          data: [:], improvement: nil).category, .learning)
        XCTAssertEqual(
            MemoryEvent(id: UUID(), timestamp: Date(), source: .memory,
                        operation: .store, tier: .working,
                        itemCount: 1, relevanceScore: nil).category, .memory)
        XCTAssertEqual(
            VerificationEvent(id: UUID(), timestamp: Date(), source: .verification,
                              verificationType: .multiModel, confidence: 0.5,
                              sources: [], conflicts: 0).category, .verification)
        XCTAssertEqual(
            NavigationEvent(id: UUID(), timestamp: Date(), source: .user,
                            fromView: nil, toView: "V", parameters: [:]).category,
            .navigation)
        XCTAssertEqual(
            ComponentEvent(id: UUID(), timestamp: Date(), source: .system,
                           action: "a", component: "c", details: [:]).category, .state)
        XCTAssertEqual(
            LifecycleEvent(id: UUID(), timestamp: Date(), source: .system,
                           event: .appLaunch, details: [:]).category, .lifecycle)
    }
}
