// EventBusEventExtendedTests.swift
// Tests for LearningEvent, MemoryEvent, VerificationEvent,
// NavigationEvent, ComponentEvent, and LifecycleEvent creation.
// Companion to EventBusEventCreationTests.swift.
// Mirrors types in Shared/Core/EventBus/EventBusEvents.swift.

import Foundation
import XCTest

final class EventBusEventExtendedTests: XCTestCase {

    // MARK: - Mirror Enums

    enum EventSource: String, Sendable, Codable, CaseIterable {
        case user, ai, system, agent, integration, scheduler, memory, verification
    }

    enum EventCategory: String, Sendable, Codable, CaseIterable {
        case message, action, navigation, state, error, performance
        case learning, integration, memory, verification, configuration, lifecycle
    }

    enum LearningType: String, Sendable, Codable, CaseIterable {
        case userCorrection, patternDetected, preferenceInferred
        case errorFixed, workflowOptimized, feedbackPositive, feedbackNegative
    }

    enum MemoryOperation: String, Sendable, Codable, CaseIterable {
        case store, retrieve, consolidate, prune, search
    }

    enum MemoryTier: String, Sendable, Codable, CaseIterable {
        case working, episodic, semantic, procedural
    }

    enum VerificationType: String, Sendable, Codable, CaseIterable {
        case multiModel, webSearch, codeExecution, staticAnalysis, userFeedback
    }

    enum LifecycleType: String, Sendable, Codable, CaseIterable {
        case appLaunch, appTerminate, appBackground, appForeground
        case sessionStart, sessionEnd, configurationChange
    }

    // MARK: - Mirror Structs

    struct LearningEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .learning }
        let learningType: LearningType
        let relatedEventId: UUID?
        let data: [String: String]
        let improvement: Double?
    }

    struct MemoryEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .memory }
        let operation: MemoryOperation
        let tier: MemoryTier
        let itemCount: Int
        let relevanceScore: Double?
    }

    struct VerificationEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .verification }
        let verificationType: VerificationType
        let confidence: Double
        let sources: [String]
        let conflicts: Int
    }

    struct NavigationEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .navigation }
        let fromView: String?
        let toView: String
        let parameters: [String: String]
    }

    struct ComponentEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .state }
        let action: String
        let component: String
        let details: [String: String]
    }

    struct LifecycleEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .lifecycle }
        let event: LifecycleType
        let details: [String: String]
    }

    // =========================================================================
    // MARK: - LearningEvent Tests
    // =========================================================================

    func testLearningEventCreation() {
        let relatedId = UUID()
        let event = LearningEvent(
            id: UUID(), timestamp: Date(), source: .ai,
            learningType: .userCorrection, relatedEventId: relatedId,
            data: ["original": "wrong answer", "correction": "right answer"],
            improvement: 0.15
        )
        XCTAssertEqual(event.category, .learning)
        XCTAssertEqual(event.learningType, .userCorrection)
        XCTAssertEqual(event.relatedEventId, relatedId)
        XCTAssertEqual(event.data["original"], "wrong answer")
        XCTAssertEqual(event.improvement!, 0.15, accuracy: 0.001)
    }

    func testLearningEventAllTypes() {
        for learningType in LearningType.allCases {
            let event = LearningEvent(
                id: UUID(), timestamp: Date(), source: .ai,
                learningType: learningType, relatedEventId: nil,
                data: [:], improvement: nil
            )
            XCTAssertEqual(event.category, .learning)
            XCTAssertEqual(event.learningType, learningType)
        }
    }

    func testLearningEventWithoutOptionals() {
        let event = LearningEvent(
            id: UUID(), timestamp: Date(), source: .memory,
            learningType: .patternDetected, relatedEventId: nil,
            data: [:], improvement: nil
        )
        XCTAssertNil(event.relatedEventId)
        XCTAssertNil(event.improvement)
        XCTAssertTrue(event.data.isEmpty)
    }

    // =========================================================================
    // MARK: - MemoryEvent Tests
    // =========================================================================

    func testMemoryEventCreation() {
        let event = MemoryEvent(
            id: UUID(), timestamp: Date(), source: .memory,
            operation: .store, tier: .episodic,
            itemCount: 5, relevanceScore: 0.85
        )
        XCTAssertEqual(event.category, .memory)
        XCTAssertEqual(event.operation, .store)
        XCTAssertEqual(event.tier, .episodic)
        XCTAssertEqual(event.itemCount, 5)
        XCTAssertEqual(event.relevanceScore!, 0.85, accuracy: 0.001)
    }

    func testMemoryEventAllOperationsAndTiers() {
        for op in MemoryOperation.allCases {
            for tier in MemoryTier.allCases {
                let event = MemoryEvent(
                    id: UUID(), timestamp: Date(), source: .memory,
                    operation: op, tier: tier, itemCount: 1, relevanceScore: nil
                )
                XCTAssertEqual(event.category, .memory)
                XCTAssertEqual(event.operation, op)
                XCTAssertEqual(event.tier, tier)
            }
        }
    }

    func testMemoryEventWithoutRelevance() {
        let event = MemoryEvent(
            id: UUID(), timestamp: Date(), source: .ai,
            operation: .prune, tier: .working,
            itemCount: 0, relevanceScore: nil
        )
        XCTAssertNil(event.relevanceScore)
        XCTAssertEqual(event.itemCount, 0)
    }

    // =========================================================================
    // MARK: - VerificationEvent Tests
    // =========================================================================

    func testVerificationEventCreation() {
        let event = VerificationEvent(
            id: UUID(), timestamp: Date(), source: .verification,
            verificationType: .multiModel, confidence: 0.92,
            sources: ["claude-opus-4-5", "gpt-4o"], conflicts: 1
        )
        XCTAssertEqual(event.category, .verification)
        XCTAssertEqual(event.verificationType, .multiModel)
        XCTAssertEqual(event.confidence, 0.92, accuracy: 0.001)
        XCTAssertEqual(event.sources.count, 2)
        XCTAssertTrue(event.sources.contains("claude-opus-4-5"))
        XCTAssertTrue(event.sources.contains("gpt-4o"))
        XCTAssertEqual(event.conflicts, 1)
    }

    func testVerificationEventAllTypes() {
        for vType in VerificationType.allCases {
            let event = VerificationEvent(
                id: UUID(), timestamp: Date(), source: .verification,
                verificationType: vType, confidence: 0.5,
                sources: [], conflicts: 0
            )
            XCTAssertEqual(event.category, .verification)
            XCTAssertEqual(event.verificationType, vType)
        }
    }

    func testVerificationEventZeroConflicts() {
        let event = VerificationEvent(
            id: UUID(), timestamp: Date(), source: .verification,
            verificationType: .webSearch, confidence: 0.99,
            sources: ["perplexity"], conflicts: 0
        )
        XCTAssertEqual(event.conflicts, 0)
        XCTAssertEqual(event.confidence, 0.99, accuracy: 0.001)
    }

    // =========================================================================
    // MARK: - NavigationEvent Tests
    // =========================================================================

    func testNavigationEventCreation() {
        let event = NavigationEvent(
            id: UUID(), timestamp: Date(), source: .user,
            fromView: "ChatView", toView: "SettingsView",
            parameters: ["tab": "sync"]
        )
        XCTAssertEqual(event.category, .navigation)
        XCTAssertEqual(event.fromView, "ChatView")
        XCTAssertEqual(event.toView, "SettingsView")
        XCTAssertEqual(event.parameters["tab"], "sync")
    }

    func testNavigationEventWithoutFromView() {
        let event = NavigationEvent(
            id: UUID(), timestamp: Date(), source: .system,
            fromView: nil, toView: "OnboardingView", parameters: [:]
        )
        XCTAssertNil(event.fromView)
        XCTAssertEqual(event.toView, "OnboardingView")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    // =========================================================================
    // MARK: - ComponentEvent Tests
    // =========================================================================

    func testComponentEventCreation() {
        let event = ComponentEvent(
            id: UUID(), timestamp: Date(), source: .system,
            action: "initialized", component: "EventBus",
            details: ["subscribers": "5"]
        )
        XCTAssertEqual(event.category, .state)
        XCTAssertEqual(event.action, "initialized")
        XCTAssertEqual(event.component, "EventBus")
        XCTAssertEqual(event.details["subscribers"], "5")
    }

    func testComponentEventEmptyDetails() {
        let event = ComponentEvent(
            id: UUID(), timestamp: Date(), source: .agent,
            action: "shutdown", component: "AutonomousAgent", details: [:]
        )
        XCTAssertEqual(event.category, .state)
        XCTAssertTrue(event.details.isEmpty)
        XCTAssertEqual(event.source, .agent)
    }

    // =========================================================================
    // MARK: - LifecycleEvent Tests
    // =========================================================================

    func testLifecycleEventCreation() {
        let event = LifecycleEvent(
            id: UUID(), timestamp: Date(), source: .system,
            event: .appLaunch, details: ["version": "2.0"]
        )
        XCTAssertEqual(event.category, .lifecycle)
        XCTAssertEqual(event.event, .appLaunch)
        XCTAssertEqual(event.details["version"], "2.0")
    }

    func testLifecycleEventAllTypes() {
        for lcType in LifecycleType.allCases {
            let event = LifecycleEvent(
                id: UUID(), timestamp: Date(), source: .system,
                event: lcType, details: [:]
            )
            XCTAssertEqual(event.category, .lifecycle)
            XCTAssertEqual(event.event, lcType)
        }
    }

    func testLifecycleEventConfigurationChange() {
        let event = LifecycleEvent(
            id: UUID(), timestamp: Date(), source: .user,
            event: .configurationChange,
            details: ["setting": "darkMode", "value": "true"]
        )
        XCTAssertEqual(event.event, .configurationChange)
        XCTAssertEqual(event.source, .user)
        XCTAssertEqual(event.details["setting"], "darkMode")
        XCTAssertEqual(event.details["value"], "true")
    }
}
