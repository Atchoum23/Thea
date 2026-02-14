// EventBusEventCreationTests.swift
// Tests for concrete event struct creation: MessageEvent, ActionEvent,
// StateEvent, ErrorEvent, PerformanceEvent, LearningEvent, MemoryEvent,
// VerificationEvent, NavigationEvent, ComponentEvent, LifecycleEvent.
// Mirrors types in Shared/Core/EventBus/EventBusEvents.swift.
// Enum/statistics tests are in EventBusEventsTests.swift.

import Foundation
import XCTest

final class EventBusEventCreationTests: XCTestCase {

    // MARK: - Shared Enums (mirrors for struct fields)

    enum EventSource: String, Sendable, Codable, CaseIterable {
        case user, ai, system, agent, integration, scheduler, memory, verification
    }

    enum EventCategory: String, Sendable, Codable, CaseIterable {
        case message, action, navigation, state, error, performance
        case learning, integration, memory, verification, configuration, lifecycle
    }

    enum MessageRole: String, Sendable, Codable, CaseIterable {
        case user, assistant, system
    }

    enum ActionType: String, Sendable, Codable, CaseIterable {
        case codeExecution, terminalCommand, fileOperation
        case webSearch, apiCall, modelQuery
        case memoryStore, memoryRetrieve
        case verification, classification, routing
        case agentSpawn, workflowStep
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

    // MARK: - Concrete Event Structs (mirrors)

    struct MessageEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .message }
        let conversationId: UUID
        let content: String
        let role: MessageRole
        let model: String?
        let confidence: Double?
        let tokenCount: Int?
    }

    struct ActionEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .action }
        let actionType: ActionType
        let target: String?
        let parameters: [String: String]
        let success: Bool
        let duration: TimeInterval?
        let error: String?
    }

    struct StateEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .state }
        let component: String
        let previousState: String?
        let newState: String
        let reason: String?
    }

    struct ErrorEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .error }
        let errorType: String
        let message: String
        let context: [String: String]
        let recoverable: Bool
        let stackTrace: String?
    }

    struct PerformanceEvent: Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let source: EventSource
        var category: EventCategory { .performance }
        let operation: String
        let duration: TimeInterval
        let metadata: [String: String]
    }

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
    // MARK: - MessageEvent Tests
    // =========================================================================

    func testMessageEventCreation() {
        let id = UUID()
        let now = Date()
        let convId = UUID()
        let event = MessageEvent(
            id: id, timestamp: now, source: .user,
            conversationId: convId, content: "Hello world",
            role: .user, model: nil, confidence: nil, tokenCount: nil
        )
        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.timestamp, now)
        XCTAssertEqual(event.source, .user)
        XCTAssertEqual(event.category, .message)
        XCTAssertEqual(event.conversationId, convId)
        XCTAssertEqual(event.content, "Hello world")
        XCTAssertEqual(event.role, .user)
        XCTAssertNil(event.model)
        XCTAssertNil(event.confidence)
        XCTAssertNil(event.tokenCount)
    }

    func testMessageEventWithAllFields() {
        let event = MessageEvent(
            id: UUID(), timestamp: Date(), source: .ai,
            conversationId: UUID(), content: "AI response here",
            role: .assistant, model: "claude-opus-4-5",
            confidence: 0.95, tokenCount: 350
        )
        XCTAssertEqual(event.category, .message)
        XCTAssertEqual(event.source, .ai)
        XCTAssertEqual(event.role, .assistant)
        XCTAssertEqual(event.model, "claude-opus-4-5")
        XCTAssertEqual(event.confidence!, 0.95, accuracy: 0.001)
        XCTAssertEqual(event.tokenCount, 350)
    }

    func testMessageEventSystemRole() {
        let event = MessageEvent(
            id: UUID(), timestamp: Date(), source: .system,
            conversationId: UUID(), content: "System prompt",
            role: .system, model: nil, confidence: nil, tokenCount: nil
        )
        XCTAssertEqual(event.role, .system)
        XCTAssertEqual(event.source, .system)
    }

    // =========================================================================
    // MARK: - ActionEvent Tests
    // =========================================================================

    func testActionEventCreation() {
        let id = UUID()
        let now = Date()
        let event = ActionEvent(
            id: id, timestamp: now, source: .ai,
            actionType: .codeExecution, target: "main.swift",
            parameters: ["lang": "swift"], success: true,
            duration: 1.5, error: nil
        )
        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.timestamp, now)
        XCTAssertEqual(event.source, .ai)
        XCTAssertEqual(event.category, .action)
        XCTAssertEqual(event.actionType, .codeExecution)
        XCTAssertEqual(event.target, "main.swift")
        XCTAssertEqual(event.parameters["lang"], "swift")
        XCTAssertTrue(event.success)
        XCTAssertEqual(event.duration!, 1.5, accuracy: 0.001)
        XCTAssertNil(event.error)
    }

    func testActionEventFailure() {
        let event = ActionEvent(
            id: UUID(), timestamp: Date(), source: .agent,
            actionType: .terminalCommand, target: nil,
            parameters: [:], success: false,
            duration: 0.01, error: "Command not found"
        )
        XCTAssertFalse(event.success)
        XCTAssertEqual(event.error, "Command not found")
        XCTAssertEqual(event.actionType, .terminalCommand)
    }

    func testActionEventAllTypes() {
        for actionType in ActionType.allCases {
            let event = ActionEvent(
                id: UUID(), timestamp: Date(), source: .system,
                actionType: actionType, target: nil,
                parameters: [:], success: true, duration: nil, error: nil
            )
            XCTAssertEqual(event.category, .action)
            XCTAssertEqual(event.actionType, actionType)
        }
    }

    // =========================================================================
    // MARK: - StateEvent Tests
    // =========================================================================

    func testStateEventCreation() {
        let event = StateEvent(
            id: UUID(), timestamp: Date(), source: .system,
            component: "ChatManager", previousState: "idle",
            newState: "loading", reason: "User sent message"
        )
        XCTAssertEqual(event.category, .state)
        XCTAssertEqual(event.component, "ChatManager")
        XCTAssertEqual(event.previousState, "idle")
        XCTAssertEqual(event.newState, "loading")
        XCTAssertEqual(event.reason, "User sent message")
    }

    func testStateEventWithoutPreviousState() {
        let event = StateEvent(
            id: UUID(), timestamp: Date(), source: .system,
            component: "AppDelegate", previousState: nil,
            newState: "initialized", reason: nil
        )
        XCTAssertNil(event.previousState)
        XCTAssertNil(event.reason)
        XCTAssertEqual(event.newState, "initialized")
    }

    // =========================================================================
    // MARK: - ErrorEvent Tests
    // =========================================================================

    func testErrorEventCreation() {
        let event = ErrorEvent(
            id: UUID(), timestamp: Date(), source: .system,
            errorType: "NetworkError", message: "Connection timed out",
            context: ["url": "https://api.example.com", "attempt": "3"],
            recoverable: true, stackTrace: nil
        )
        XCTAssertEqual(event.category, .error)
        XCTAssertEqual(event.errorType, "NetworkError")
        XCTAssertEqual(event.message, "Connection timed out")
        XCTAssertEqual(event.context["url"], "https://api.example.com")
        XCTAssertEqual(event.context["attempt"], "3")
        XCTAssertTrue(event.recoverable)
        XCTAssertNil(event.stackTrace)
    }

    func testErrorEventNonRecoverable() {
        let event = ErrorEvent(
            id: UUID(), timestamp: Date(), source: .ai,
            errorType: "FatalError", message: "Model crashed",
            context: [:], recoverable: false,
            stackTrace: "Thread 1: Fatal error at line 42"
        )
        XCTAssertFalse(event.recoverable)
        XCTAssertNotNil(event.stackTrace)
        XCTAssertEqual(event.stackTrace, "Thread 1: Fatal error at line 42")
    }

    // =========================================================================
    // MARK: - PerformanceEvent Tests
    // =========================================================================

    func testPerformanceEventCreation() {
        let event = PerformanceEvent(
            id: UUID(), timestamp: Date(), source: .system,
            operation: "modelInference", duration: 2.345,
            metadata: ["model": "llama-70b", "tokens": "500"]
        )
        XCTAssertEqual(event.category, .performance)
        XCTAssertEqual(event.operation, "modelInference")
        XCTAssertEqual(event.duration, 2.345, accuracy: 0.001)
        XCTAssertEqual(event.metadata["model"], "llama-70b")
        XCTAssertEqual(event.metadata["tokens"], "500")
    }

    func testPerformanceEventEmptyMetadata() {
        let event = PerformanceEvent(
            id: UUID(), timestamp: Date(), source: .ai,
            operation: "tokenization", duration: 0.001, metadata: [:]
        )
        XCTAssertTrue(event.metadata.isEmpty)
        XCTAssertEqual(event.duration, 0.001, accuracy: 0.0001)
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

    // =========================================================================
    // MARK: - Cross-Event ID Uniqueness Tests
    // =========================================================================

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
        XCTAssertEqual(seenIDs.count, 11, "Should have 11 unique event IDs")
    }

    // =========================================================================
    // MARK: - Event Category Mapping Tests
    // =========================================================================

    func testEachEventTypeReturnsCorrectCategory() {
        XCTAssertEqual(
            MessageEvent(id: UUID(), timestamp: Date(), source: .user,
                         conversationId: UUID(), content: "", role: .user,
                         model: nil, confidence: nil, tokenCount: nil).category,
            .message)
        XCTAssertEqual(
            ActionEvent(id: UUID(), timestamp: Date(), source: .ai,
                        actionType: .apiCall, target: nil, parameters: [:],
                        success: true, duration: nil, error: nil).category,
            .action)
        XCTAssertEqual(
            StateEvent(id: UUID(), timestamp: Date(), source: .system,
                       component: "X", previousState: nil, newState: "Y",
                       reason: nil).category,
            .state)
        XCTAssertEqual(
            ErrorEvent(id: UUID(), timestamp: Date(), source: .system,
                       errorType: "E", message: "M", context: [:],
                       recoverable: true, stackTrace: nil).category,
            .error)
        XCTAssertEqual(
            PerformanceEvent(id: UUID(), timestamp: Date(), source: .system,
                             operation: "op", duration: 0.1, metadata: [:]).category,
            .performance)
        XCTAssertEqual(
            LearningEvent(id: UUID(), timestamp: Date(), source: .ai,
                          learningType: .patternDetected, relatedEventId: nil,
                          data: [:], improvement: nil).category,
            .learning)
        XCTAssertEqual(
            MemoryEvent(id: UUID(), timestamp: Date(), source: .memory,
                        operation: .store, tier: .working,
                        itemCount: 1, relevanceScore: nil).category,
            .memory)
        XCTAssertEqual(
            VerificationEvent(id: UUID(), timestamp: Date(), source: .verification,
                              verificationType: .multiModel, confidence: 0.5,
                              sources: [], conflicts: 0).category,
            .verification)
        XCTAssertEqual(
            NavigationEvent(id: UUID(), timestamp: Date(), source: .user,
                            fromView: nil, toView: "V", parameters: [:]).category,
            .navigation)
        XCTAssertEqual(
            ComponentEvent(id: UUID(), timestamp: Date(), source: .system,
                           action: "a", component: "c", details: [:]).category,
            .state)
        XCTAssertEqual(
            LifecycleEvent(id: UUID(), timestamp: Date(), source: .system,
                           event: .appLaunch, details: [:]).category,
            .lifecycle)
    }
}
