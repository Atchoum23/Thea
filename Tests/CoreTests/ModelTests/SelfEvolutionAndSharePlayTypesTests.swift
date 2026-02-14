// SelfEvolutionAndSharePlayTypesTests.swift
// Tests for SelfEvolutionEngine types and SharePlay types

import Testing
import Foundation

// MARK: - Test Doubles: FeatureCategory

private enum TestFeatureCategory: String, Sendable, CaseIterable {
    case ui, networking, ai, data, settings, security, core
}

// MARK: - Test Doubles: ImplementationScope

private enum TestImplementationScope: String, Sendable, CaseIterable {
    case minor, moderate, major

    var estimatedHours: Int {
        switch self {
        case .minor: return 1
        case .moderate: return 4
        case .major: return 16
        }
    }
}

// MARK: - Test Doubles: FileAction

private enum TestFileAction: String, Sendable, CaseIterable {
    case create, modify
}

// MARK: - Test Doubles: BuildPhase

private enum TestBuildPhase: String, Sendable, CaseIterable {
    case preparing, compiling, linking, signing

    var order: Int {
        switch self {
        case .preparing: return 0
        case .compiling: return 1
        case .linking: return 2
        case .signing: return 3
        }
    }
}

// MARK: - Test Doubles: ComplexityLevel

private enum TestComplexityLevel: String, Sendable, CaseIterable {
    case trivial, simple, moderate, complex, extreme

    var maxSteps: Int {
        switch self {
        case .trivial: return 3
        case .simple: return 5
        case .moderate: return 10
        case .complex: return 20
        case .extreme: return 50
        }
    }
}

// MARK: - Test Doubles: ScopeClassifier

private enum TestScopeClassifier {
    static func determineScope(from description: String) -> TestImplementationScope {
        let wordCount = description.split(separator: " ").count
        if wordCount < 10 { return .minor }
        if wordCount < 30 { return .moderate }
        return .major
    }
}

// MARK: - Test Doubles: CategoryClassifier

private enum TestEvolutionCategoryClassifier {
    static func categorize(_ request: String) -> TestFeatureCategory {
        let lower = request.lowercased()
        if lower.contains("ui") || lower.contains("view") || lower.contains("button") || lower.contains("layout") || lower.contains("theme") { return .ui }
        if lower.contains("network") || lower.contains("api") || lower.contains("http") || lower.contains("url") { return .networking }
        let words = Set(lower.split(separator: " ").map(String.init))
        if words.contains("ai") || lower.contains("model") || lower.contains("inference") || lower.contains("llm") { return .ai }
        if lower.contains("database") || lower.contains("storage") || lower.contains("persist") || lower.contains("swiftdata") { return .data }
        if lower.contains("setting") || lower.contains("preference") || lower.contains("config") { return .settings }
        if lower.contains("security") || lower.contains("auth") || lower.contains("encrypt") || lower.contains("permission") { return .security }
        return .core
    }
}

// MARK: - Test Doubles: BuildResult

private struct TestBuildResult: Sendable {
    let success: Bool
    let duration: Int
    let warnings: [String]
    let errors: [String]

    var hasWarnings: Bool { !warnings.isEmpty }
    var hasErrors: Bool { !errors.isEmpty }
    var isClean: Bool { success && !hasWarnings && !hasErrors }
}

// MARK: - Test Doubles: ImplementationStep

private struct TestImplementationStep: Sendable {
    let order: Int
    let title: String
    let description: String
    let filePath: String?
    let estimatedDuration: Int

    init(order: Int, title: String, description: String = "", filePath: String? = nil, estimatedDuration: Int = 5) {
        self.order = order
        self.title = title
        self.description = description
        self.filePath = filePath
        self.estimatedDuration = estimatedDuration
    }
}

// MARK: - Test Doubles: ImplementationPlan

private struct TestImplementationPlan: Sendable {
    let steps: [TestImplementationStep]
    let requiredCapabilities: [String]

    var estimatedTotalDuration: Int {
        steps.reduce(0) { $0 + $1.estimatedDuration }
    }

    var stepCount: Int { steps.count }
}

// MARK: - Test Doubles: SharePlayMessage

private enum TestSharePlayMessage: Codable, Sendable {
    case chatMessage(ChatContent)
    case aiResponse(AIResponseContent)
    case typing(TypingIndicator)
    case reaction(Reaction)
    case syncRequest
    case syncResponse(SyncData)
    case participantJoined(ParticipantInfo)
    case participantLeft(ParticipantInfo)

    struct ChatContent: Codable, Sendable {
        let id: String
        let senderId: String
        let senderName: String
        let text: String
        let timestamp: Date
    }

    struct AIResponseContent: Codable, Sendable {
        let id: String
        let promptId: String
        let response: String
        let isComplete: Bool
        let timestamp: Date
    }

    struct TypingIndicator: Codable, Sendable {
        let participantId: String
        let participantName: String
        let isTyping: Bool
    }

    struct Reaction: Codable, Sendable {
        let participantId: String
        let messageId: String
        let emoji: String
    }

    struct SyncData: Codable, Sendable {
        let messages: [ChatContent]
        let aiResponses: [AIResponseContent]
        let conversationTitle: String
    }

    struct ParticipantInfo: Codable, Sendable {
        let id: String
        let name: String
        let deviceType: String
    }
}

// MARK: - Test Doubles: SharePlayError

private enum TestSharePlayError: Error, LocalizedError, Sendable {
    case activationDisabled
    case cancelled
    case notInSession
    case messageFailed

    var errorDescription: String? {
        switch self {
        case .activationDisabled: return "SharePlay is disabled"
        case .cancelled: return "SharePlay session was cancelled"
        case .notInSession: return "Not in a SharePlay session"
        case .messageFailed: return "Failed to send SharePlay message"
        }
    }
}

// MARK: - Tests: FeatureCategory

@Suite("Feature Category")
struct FeatureCategoryTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestFeatureCategory.allCases.count == 7)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let values = Set(TestFeatureCategory.allCases.map(\.rawValue))
        #expect(values.count == TestFeatureCategory.allCases.count)
    }
}

// MARK: - Tests: ImplementationScope

@Suite("Implementation Scope")
struct ImplementationScopeTests {
    @Test("Estimated hours increase with scope")
    func hoursIncrease() {
        #expect(TestImplementationScope.minor.estimatedHours < TestImplementationScope.moderate.estimatedHours)
        #expect(TestImplementationScope.moderate.estimatedHours < TestImplementationScope.major.estimatedHours)
    }

    @Test("Minor scope is 1 hour")
    func minorHours() {
        #expect(TestImplementationScope.minor.estimatedHours == 1)
    }
}

// MARK: - Tests: BuildPhase

@Suite("Build Phase")
struct BuildPhaseTests {
    @Test("Phase order is sequential")
    func ordering() {
        let phases = TestBuildPhase.allCases.sorted { $0.order < $1.order }
        #expect(phases.first == .preparing)
        #expect(phases.last == .signing)
    }

    @Test("Orders are unique")
    func uniqueOrders() {
        let orders = Set(TestBuildPhase.allCases.map(\.order))
        #expect(orders.count == TestBuildPhase.allCases.count)
    }
}

// MARK: - Tests: ComplexityLevel

@Suite("Complexity Level")
struct ComplexityLevelTests {
    @Test("Max steps increase with complexity")
    func maxStepsIncrease() {
        let steps = TestComplexityLevel.allCases.map(\.maxSteps)
        for i in 1..<steps.count {
            #expect(steps[i] > steps[i - 1])
        }
    }

    @Test("Trivial has fewest steps")
    func trivialMinSteps() {
        #expect(TestComplexityLevel.trivial.maxSteps <= 3)
    }
}

// MARK: - Tests: ScopeClassifier

@Suite("Scope Classifier")
struct ScopeClassifierTests {
    @Test("Short description is minor")
    func shortIsMinor() {
        #expect(TestScopeClassifier.determineScope(from: "Fix button color") == .minor)
    }

    @Test("Medium description is moderate")
    func mediumIsModerate() {
        #expect(TestScopeClassifier.determineScope(from: "Add a new settings tab with toggle controls for each monitoring type and a slider for sampling interval") == .moderate)
    }

    @Test("Long description is major")
    func longIsMajor() {
        let long = Array(repeating: "word", count: 35).joined(separator: " ")
        #expect(TestScopeClassifier.determineScope(from: long) == .major)
    }

    @Test("Empty description is minor")
    func emptyIsMinor() {
        #expect(TestScopeClassifier.determineScope(from: "") == .minor)
    }
}

// MARK: - Tests: CategoryClassifier

@Suite("Evolution Category Classifier")
struct EvolutionCategoryClassifierTests {
    @Test("UI categories")
    func uiCategories() {
        #expect(TestEvolutionCategoryClassifier.categorize("Add a new button to the toolbar") == .ui)
        #expect(TestEvolutionCategoryClassifier.categorize("Improve view layout") == .ui)
        #expect(TestEvolutionCategoryClassifier.categorize("Change theme colors") == .ui)
    }

    @Test("Networking categories")
    func networkingCategories() {
        #expect(TestEvolutionCategoryClassifier.categorize("Fix API endpoint") == .networking)
        #expect(TestEvolutionCategoryClassifier.categorize("Add HTTP retry logic") == .networking)
    }

    @Test("AI categories")
    func aiCategories() {
        #expect(TestEvolutionCategoryClassifier.categorize("Improve AI model routing") == .ai)
        #expect(TestEvolutionCategoryClassifier.categorize("Add LLM inference") == .ai)
    }

    @Test("Data categories")
    func dataCategories() {
        #expect(TestEvolutionCategoryClassifier.categorize("Fix database migration") == .data)
        #expect(TestEvolutionCategoryClassifier.categorize("Add SwiftData storage") == .data)
    }

    @Test("Settings categories")
    func settingsCategories() {
        #expect(TestEvolutionCategoryClassifier.categorize("Add new setting for font") == .settings)
        #expect(TestEvolutionCategoryClassifier.categorize("Update preference sync") == .settings)
    }

    @Test("Security categories")
    func securityCategories() {
        #expect(TestEvolutionCategoryClassifier.categorize("Fix authentication flow") == .security)
        #expect(TestEvolutionCategoryClassifier.categorize("Add encryption for logs") == .security)
    }

    @Test("Core fallback")
    func coreFallback() {
        #expect(TestEvolutionCategoryClassifier.categorize("Refactor the startup sequence") == .core)
    }
}

// MARK: - Tests: BuildResult

@Suite("Build Result")
struct BuildResultTests {
    @Test("Clean build")
    func cleanBuild() {
        let result = TestBuildResult(success: true, duration: 30, warnings: [], errors: [])
        #expect(result.isClean)
        #expect(!result.hasWarnings)
        #expect(!result.hasErrors)
    }

    @Test("Build with warnings")
    func withWarnings() {
        let result = TestBuildResult(success: true, duration: 45, warnings: ["Unused variable"], errors: [])
        #expect(!result.isClean)
        #expect(result.hasWarnings)
        #expect(!result.hasErrors)
    }

    @Test("Failed build")
    func failedBuild() {
        let result = TestBuildResult(success: false, duration: 10, warnings: [], errors: ["Type mismatch"])
        #expect(!result.isClean)
        #expect(result.hasErrors)
    }
}

// MARK: - Tests: ImplementationPlan

@Suite("Implementation Plan")
struct ImplementationPlanTests {
    @Test("Total duration calculation")
    func totalDuration() {
        let steps = [
            TestImplementationStep(order: 1, title: "Create file", estimatedDuration: 5),
            TestImplementationStep(order: 2, title: "Add logic", estimatedDuration: 15),
            TestImplementationStep(order: 3, title: "Add tests", estimatedDuration: 10)
        ]
        let plan = TestImplementationPlan(steps: steps, requiredCapabilities: ["swift"])
        #expect(plan.estimatedTotalDuration == 30)
        #expect(plan.stepCount == 3)
    }

    @Test("Empty plan")
    func emptyPlan() {
        let plan = TestImplementationPlan(steps: [], requiredCapabilities: [])
        #expect(plan.estimatedTotalDuration == 0)
        #expect(plan.stepCount == 0)
    }
}

// MARK: - Tests: SharePlayMessage

@Suite("SharePlay Message")
struct SharePlayMessageTests {
    @Test("Chat content creation")
    func chatContent() {
        let content = TestSharePlayMessage.ChatContent(id: "1", senderId: "user1", senderName: "Alexis", text: "Hello", timestamp: Date())
        #expect(content.senderName == "Alexis")
        #expect(content.text == "Hello")
    }

    @Test("AI response creation")
    func aiResponse() {
        let response = TestSharePlayMessage.AIResponseContent(id: "1", promptId: "p1", response: "Hi!", isComplete: true, timestamp: Date())
        #expect(response.isComplete)
    }

    @Test("Typing indicator")
    func typingIndicator() {
        let indicator = TestSharePlayMessage.TypingIndicator(participantId: "p1", participantName: "Alice", isTyping: true)
        #expect(indicator.isTyping)
    }

    @Test("Reaction")
    func reaction() {
        let reaction = TestSharePlayMessage.Reaction(participantId: "p1", messageId: "m1", emoji: "👍")
        #expect(reaction.emoji == "👍")
    }

    @Test("Sync data with messages")
    func syncData() {
        let msg = TestSharePlayMessage.ChatContent(id: "1", senderId: "u1", senderName: "A", text: "Hi", timestamp: Date())
        let syncData = TestSharePlayMessage.SyncData(messages: [msg], aiResponses: [], conversationTitle: "Test Chat")
        #expect(syncData.messages.count == 1)
        #expect(syncData.conversationTitle == "Test Chat")
    }

    @Test("Participant info")
    func participantInfo() {
        let info = TestSharePlayMessage.ParticipantInfo(id: "p1", name: "Bob", deviceType: "iPhone")
        #expect(info.deviceType == "iPhone")
    }

    @Test("ChatContent Codable roundtrip")
    func chatContentCodable() throws {
        let content = TestSharePlayMessage.ChatContent(id: "1", senderId: "u1", senderName: "Test", text: "Hello", timestamp: Date())
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(TestSharePlayMessage.ChatContent.self, from: data)
        #expect(decoded.text == "Hello")
    }
}

// MARK: - Tests: SharePlayError

@Suite("SharePlay Error")
struct SharePlayErrorTests {
    @Test("All errors have descriptions")
    func descriptions() {
        let errors: [TestSharePlayError] = [.activationDisabled, .cancelled, .notInSession, .messageFailed]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Descriptions are unique")
    func uniqueDescriptions() {
        let errors: [TestSharePlayError] = [.activationDisabled, .cancelled, .notInSession, .messageFailed]
        let descs = Set(errors.compactMap(\.errorDescription))
        #expect(descs.count == errors.count)
    }
}
