// EventBusEventCreationTests.swift
// Tests for concrete event struct creation: MessageEvent, ActionEvent,
// StateEvent, ErrorEvent, PerformanceEvent.
// Mirrors types in Shared/Core/EventBus/EventBusEvents.swift.
// Extended event tests and cross-event validation are in
// EventBusEventExtendedTests.swift.
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
}
