# THEA L3 FILE SPECIFICATION

**Version**: 1.0.0
**Created**: February 1, 2026
**Purpose**: File-level architecture specification with class/struct details

---

## TABLE OF CONTENTS

1. [AI Verification Files](#1-ai-verification-files)
2. [AI Memory Files](#2-ai-memory-files)
3. [AI Provider Files](#3-ai-provider-files)
4. [Core Service Files](#4-core-service-files)
5. [Core Manager Files](#5-core-manager-files)
6. [Event System Files](#6-event-system-files)
7. [UI Component Files](#7-ui-component-files)

---

## 1. AI VERIFICATION FILES

### 1.1 ConfidenceSystem.swift

**Location**: `/Shared/AI/Verification/ConfidenceSystem.swift`
**Lines**: ~410
**Dependencies**: `MultiModelConsensus`, `WebSearchVerifier`, `CodeExecutionVerifier`, `StaticAnalysisVerifier`, `UserFeedbackLearner`

#### Types Defined

```swift
// Result of confidence validation
public struct ConfidenceResult: Sendable, Identifiable {
    public let id: UUID
    public let overallConfidence: Double        // 0.0 - 1.0
    public let level: ConfidenceLevel           // .high, .medium, .low, .unverified
    public let sources: [ConfidenceSource]      // Contributing sources
    public let decomposition: ConfidenceDecomposition
    public let timestamp: Date

    public var reasoning: String                // Human-readable explanation
    public var improvementSuggestions: [String] // How to improve confidence
}

// Confidence level enum
public enum ConfidenceLevel: String, Sendable, CaseIterable {
    case high = "High Confidence"       // ≥ 0.85
    case medium = "Medium Confidence"   // 0.60 - 0.84
    case low = "Low Confidence"         // 0.30 - 0.59
    case unverified = "Unverified"      // < 0.30

    public var color: String            // For UI
    public var icon: String             // SF Symbol name
    public var actionRequired: Bool     // Should user verify?
}

// Individual confidence source
public struct ConfidenceSource: Sendable, Identifiable {
    public let id: UUID
    public let type: SourceType         // What kind of verification
    public let name: String             // Display name
    public let confidence: Double       // This source's confidence
    public let weight: Double           // Contribution weight
    public let details: String          // Explanation
    public let verified: Bool           // Was verification successful?

    public enum SourceType: String, Sendable, CaseIterable {
        case modelConsensus     // Multiple models agree
        case webVerification    // Verified via web search
        case codeExecution      // Code was executed
        case staticAnalysis     // Static analysis passed
        case cachedKnowledge    // From memory
        case userFeedback       // User confirmed
        case patternMatch       // Matches known pattern
        case semanticAnalysis   // AI semantic check
    }
}

// Explains WHY confidence is at a level
public struct ConfidenceDecomposition: Sendable {
    public let factors: [DecompositionFactor]   // Contributing factors
    public let conflicts: [ConflictInfo]        // Conflicting info
    public let reasoning: String                // Summary
    public let suggestions: [String]            // Improvements

    public struct DecompositionFactor: Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let contribution: Double         // -1.0 to 1.0
        public let explanation: String
    }

    public struct ConflictInfo: Sendable, Identifiable {
        public let id: UUID
        public let source1: String
        public let source2: String
        public let description: String
        public let severity: ConflictSeverity   // .minor, .moderate, .major
    }
}

// Main coordinator class
@MainActor
public final class ConfidenceSystem {
    public static let shared: ConfidenceSystem

    // Sub-systems
    private let multiModelConsensus: MultiModelConsensus
    private let webVerifier: WebSearchVerifier
    private let codeExecutor: CodeExecutionVerifier
    private let staticAnalyzer: StaticAnalysisVerifier
    private let feedbackLearner: UserFeedbackLearner

    // Configuration
    public var enableMultiModel: Bool
    public var enableWebVerification: Bool
    public var enableCodeExecution: Bool
    public var enableStaticAnalysis: Bool
    public var enableFeedbackLearning: Bool

    public var sourceWeights: [ConfidenceSource.SourceType: Double]

    // Main API
    public func validateResponse(
        _ response: String,
        query: String,
        taskType: TaskType,
        context: ValidationContext
    ) async -> ConfidenceResult

    public func recordFeedback(
        responseId: UUID,
        wasCorrect: Bool,
        userCorrection: String?,
        taskType: TaskType
    ) async
}

// Validation context
public struct ValidationContext: Sendable {
    public let allowMultiModel: Bool
    public let allowWebSearch: Bool
    public let allowCodeExecution: Bool
    public let language: CodeLanguage
    public let maxLatency: TimeInterval

    public static let `default`: ValidationContext
    public static let fast: ValidationContext
}
```

#### Method Signatures

```swift
// Private methods
private func calculateOverallConfidence(from sources: [ConfidenceSource]) -> Double
private func generateDecomposition(
    factors: [ConfidenceDecomposition.DecompositionFactor],
    conflicts: [ConfidenceDecomposition.ConflictInfo],
    confidence: Double,
    sources: [ConfidenceSource]
) -> ConfidenceDecomposition
```

---

### 1.2 MultiModelConsensus.swift

**Location**: `/Shared/AI/Verification/MultiModelConsensus.swift`
**Lines**: ~350
**Dependencies**: `ProviderRegistry`, `AIMessage`, `TaskType`

#### Types Defined

```swift
public struct ConsensusResult: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let conflicts: [ConfidenceDecomposition.ConflictInfo]
    public let responses: [ModelResponse]       // Individual model responses
}

struct ModelResponse: Sendable {
    let modelId: String
    let response: String
    let confidence: Double
    let latency: TimeInterval
}

@MainActor
public final class MultiModelConsensus {
    // Configuration
    public var minModelsForConsensus: Int = 2
    public var maxModelsToQuery: Int = 3
    public var consensusThreshold: Double = 0.7
    public var timeout: TimeInterval = 15.0

    // Model selection by task
    private let modelPreferences: [TaskType: [String]]

    // Main API
    public func validate(
        query: String,
        response: String,
        taskType: TaskType
    ) async -> ConsensusResult
}
```

---

### 1.3 WebSearchVerifier.swift

**Location**: `/Shared/AI/Verification/WebSearchVerifier.swift`
**Lines**: ~300
**Dependencies**: `ProviderRegistry`, `AIMessage`

#### Types Defined

```swift
public struct VerifiedClaim: Sendable {
    public let claim: String
    public let confirmed: Bool
    public let confidence: Double
    public let source: String?
    public let correction: String?
}

public struct WebVerificationResult: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let verifiedClaims: [VerifiedClaim]
    public let unverifiedClaims: [String]
}

@MainActor
public final class WebSearchVerifier {
    public var maxClaimsToVerify: Int = 5
    public var minConfidenceToVerify: Double = 0.3
    public var timeout: TimeInterval = 10.0

    public func verify(
        response: String,
        query: String
    ) async -> WebVerificationResult
}
```

---

### 1.4 CodeExecutionVerifier.swift

**Location**: `/Shared/AI/Verification/CodeExecutionVerifier.swift`
**Lines**: ~450
**Dependencies**: `JavaScriptCore`, `Process`

#### Types Defined

```swift
public struct CodeVerificationResult: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let executions: [CodeExecResult]
}

public struct CodeExecResult: Sendable {
    public let language: String
    public let code: String
    public let success: Bool
    public let output: String
    public let error: String?
    public let executionTime: TimeInterval
}

// Language-specific engines
final class JavaScriptEngine {
    func execute(_ code: String, timeout: TimeInterval) async -> CodeExecResult
}

#if os(macOS)
final class SwiftExecutionEngine {
    func execute(_ code: String, timeout: TimeInterval) async -> CodeExecResult
}

final class PythonExecutionEngine {
    func execute(_ code: String, timeout: TimeInterval) async -> CodeExecResult
}
#endif

@MainActor
public final class CodeExecutionVerifier {
    public var enableJavaScript: Bool = true
    public var enableSwift: Bool = true      // macOS only
    public var enablePython: Bool = true     // macOS only
    public var executionTimeout: TimeInterval = 10.0

    public func verify(
        response: String,
        language: ValidationContext.CodeLanguage
    ) async -> CodeVerificationResult
}
```

---

### 1.5 StaticAnalysisVerifier.swift

**Location**: `/Shared/AI/Verification/StaticAnalysisVerifier.swift`
**Lines**: ~400
**Dependencies**: `Process`, `ProviderRegistry`

#### Types Defined

```swift
public struct StaticAnalysisResult: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let issues: [AnalysisIssue]
    public let passed: Bool
}

public struct AnalysisIssue: Sendable {
    public let severity: IssueSeverity     // .error, .warning, .info
    public let message: String
    public let line: Int?
    public let column: Int?
    public let rule: String?
}

@MainActor
public final class StaticAnalysisVerifier {
    public var enableSwiftLint: Bool = true
    public var enableCompilerCheck: Bool = true
    public var enableAIAnalysis: Bool = true
    public var maxIssuesBeforeFail: Int = 5

    public func analyze(
        response: String,
        language: ValidationContext.CodeLanguage
    ) async -> StaticAnalysisResult
}
```

---

### 1.6 UserFeedbackLearner.swift

**Location**: `/Shared/AI/Verification/UserFeedbackLearner.swift`
**Lines**: ~250
**Dependencies**: `UserDefaults`

#### Types Defined

```swift
public struct FeedbackAssessment: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let historicalAccuracy: Double
    public let sampleSize: Int
}

struct FeedbackRecord: Codable, Sendable {
    let id: UUID
    let responseId: UUID
    let taskType: TaskType
    let wasCorrect: Bool
    let userCorrection: String?
    let timestamp: Date
    let responseHash: String
}

@MainActor
public final class UserFeedbackLearner {
    public var maxHistorySize: Int = 1000
    public var decayFactor: Double = 0.95

    public func assessFromHistory(
        taskType: TaskType,
        responsePattern: String
    ) async -> FeedbackAssessment

    public func recordFeedback(
        responseId: UUID,
        wasCorrect: Bool,
        userCorrection: String?,
        taskType: TaskType
    ) async
}
```

---

## 2. AI MEMORY FILES

### 2.1 ActiveMemoryRetrieval.swift

**Location**: `/Shared/AI/Memory/ActiveMemoryRetrieval.swift`
**Lines**: ~550
**Dependencies**: `MemorySystem`, `ConversationMemory`, `KnowledgeGraph`, `EventBus`

#### Types Defined

```swift
public struct RetrievalConfig: Sendable {
    public var enableMemorySystemRetrieval: Bool = true
    public var enableConversationMemory: Bool = true
    public var enableKnowledgeGraph: Bool = true
    public var enableEventHistory: Bool = true
    public var enableAIRanking: Bool = true

    public var memorySystemWeight: Double = 0.35
    public var conversationWeight: Double = 0.30
    public var knowledgeGraphWeight: Double = 0.20
    public var eventHistoryWeight: Double = 0.15

    public var maxTotalResults: Int = 15
    public var minSimilarityThreshold: Float = 0.3
    public var minConfidenceToInject: Double = 0.4
}

public struct ActiveRetrievalResult: Sendable {
    public let sources: [RetrievalSource]
    public let contextPrompt: String
    public let confidence: Double
    public let retrievalTime: TimeInterval
    public let queryEmbedding: [Float]?

    public var isEmpty: Bool
}

public struct RetrievalSource: Sendable {
    public let type: SourceType
    public let tier: MemoryTierType
    public var content: String
    public var relevanceScore: Double
    public let timestamp: Date
    public let metadata: [String: String]

    public enum SourceType: String, Sendable {
        case memorySystem, episodic, semantic, procedural
        case conversationFact, conversationSummary, userPreference
        case knowledgeNode, recentError, learningEvent
    }
}

public enum MemoryTierType: String, Sendable {
    case working = "Working Memory"
    case longTerm = "Long-Term Memory"
    case episodic = "Episodic Memory"
    case semantic = "Semantic Memory"
    case procedural = "Procedural Memory"
}

public struct EnhancedPrompt: Sendable {
    public let prompt: String
    public let hasInjectedContext: Bool
    public let injectedSources: [RetrievalSource]
    public let confidence: Double
}

@MainActor
public final class ActiveMemoryRetrieval {
    public static let shared: ActiveMemoryRetrieval
    public var config: RetrievalConfig

    public func retrieveContext(
        for query: String,
        conversationId: UUID?,
        projectId: UUID?,
        taskType: TaskType?
    ) async -> ActiveRetrievalResult

    public func enhancePromptWithContext(
        originalPrompt: String,
        conversationId: UUID?,
        projectId: UUID?,
        taskType: TaskType?
    ) async -> EnhancedPrompt

    public func learnFromExchange(
        userMessage: String,
        assistantResponse: String,
        conversationId: UUID,
        wasHelpful: Bool?
    ) async
}
```

---

### 2.2 MemoryAugmentedChat.swift

**Location**: `/Shared/AI/Memory/MemoryAugmentedChat.swift`
**Lines**: ~280
**Dependencies**: `ActiveMemoryRetrieval`, `ConversationMemory`, `TaskClassifier`

#### Types Defined

```swift
public struct AugmentationConfig: Sendable {
    public var enableContextInjection: Bool = true
    public var enableSystemContext: Bool = true
    public var enableLearning: Bool = true
    public var injectOnFirstMessage: Bool = false
    public var minConfidenceToInject: Double = 0.4
    public var maxContextLength: Int = 2000
}

public struct AugmentedMessage: Sendable {
    public let originalMessage: String
    public let augmentedMessage: String
    public let systemContext: String?
    public let wasAugmented: Bool
    public let retrievedSources: [RetrievalSource]
    public let confidence: Double
    public let taskType: TaskType
    public let processingTime: TimeInterval

    public var contextInjected: Bool
}

public struct ContextualSuggestion: Sendable, Identifiable {
    public let id: UUID
    public let type: SuggestionType
    public let title: String
    public let description: String
    public let action: String
    public let confidence: Double

    public enum SuggestionType: String, Sendable {
        case procedure, relatedFact, previousSolution, suggestion
    }
}

@MainActor
public final class MemoryAugmentedChat {
    public static let shared: MemoryAugmentedChat
    public var config: AugmentationConfig

    public func processMessage(
        _ userMessage: String,
        conversationId: UUID,
        projectId: UUID?,
        existingMessages: [AIMessage]
    ) async -> AugmentedMessage

    public func processResponse(
        userMessage: String,
        assistantResponse: String,
        conversationId: UUID,
        wasHelpful: Bool?
    ) async

    public func getSuggestions(
        conversationId: UUID,
        recentMessages: [AIMessage],
        projectId: UUID?
    ) async -> [ContextualSuggestion]
}
```

---

## 3. AI PROVIDER FILES

### 3.1 ProviderRegistry.swift

**Location**: `/Shared/AI/Providers/ProviderRegistry.swift`
**Lines**: ~200
**Dependencies**: Individual providers

#### Types Defined

```swift
@MainActor
public final class ProviderRegistry: ObservableObject {
    public static let shared: ProviderRegistry

    @Published public private(set) var providers: [String: any AIProvider]
    @Published public private(set) var configuredProviders: [String]

    public func registerProvider(_ provider: any AIProvider)
    public func getProvider(id: String) -> (any AIProvider)?
    public func getConfiguredProviders() -> [any AIProvider]
    public func refreshProviderStatus()
}
```

### 3.2 AIProvider Protocol

**Location**: `/Shared/AI/Providers/AIProvider.swift`
**Lines**: ~100

#### Types Defined

```swift
public protocol AIProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var isConfigured: Bool { get }
    var supportedModels: [AIModel] { get }
    var capabilities: ProviderCapabilities { get }

    func chat(
        messages: [AIMessage],
        model: String,
        stream: Bool
    ) async throws -> AsyncThrowingStream<StreamChunk, Error>

    func validateConfiguration() async -> Bool
}

public struct ProviderCapabilities: OptionSet, Sendable {
    public static let streaming: ProviderCapabilities
    public static let vision: ProviderCapabilities
    public static let functionCalling: ProviderCapabilities
    public static let embedding: ProviderCapabilities
    public static let webSearch: ProviderCapabilities
}

public enum StreamChunk: Sendable {
    case delta(String)
    case complete(String)
    case error(Error)
}
```

---

## 4. CORE SERVICE FILES

### 4.1 ProjectService.swift

**Location**: `/Shared/Core/Services/ProjectService.swift`
**Lines**: ~150
**Dependencies**: `SwiftData`, `Project`

```swift
public protocol ProjectServiceProtocol {
    func createProject(title: String, description: String?) async throws -> Project
    func getProject(id: UUID) async throws -> Project?
    func updateProject(_ project: Project) async throws
    func deleteProject(id: UUID) async throws
    func getAllProjects() async throws -> [Project]
    func linkConversation(_ conversationId: UUID, to projectId: UUID) async throws
    func unlinkConversation(_ conversationId: UUID, from projectId: UUID) async throws
}

@MainActor
public final class ProjectService: ProjectServiceProtocol {
    private let modelContext: ModelContext

    // Implements all protocol methods
}
```

---

## 5. CORE MANAGER FILES

### 5.1 SettingsManager.swift

**Location**: `/Shared/Core/Managers/SettingsManager.swift`
**Lines**: ~400
**Dependencies**: `UserDefaults`, `SecureStorage`

```swift
@MainActor
@Observable
public final class SettingsManager {
    public static let shared: SettingsManager

    // Provider settings
    @Published public var defaultProvider: String
    @Published public var defaultModel: String

    // Feature toggles
    @Published public var enableMultiModelConsensus: Bool
    @Published public var enableWebVerification: Bool
    @Published public var enableCodeExecution: Bool
    @Published public var enableMemorySystem: Bool

    // Appearance
    @Published public var theme: AppTheme
    @Published public var fontSize: CGFloat

    // Privacy
    @Published public var enableAnalytics: Bool
    @Published public var enableCloudSync: Bool

    // API keys (secure storage)
    public func getAPIKey(for provider: String) -> String?
    public func setAPIKey(_ key: String, for provider: String)
    public func clearAPIKey(for provider: String)
}
```

---

## 6. EVENT SYSTEM FILES

### 6.1 EventBus.swift

**Location**: `/Shared/Core/EventBus/EventBus.swift`
**Lines**: ~525
**Dependencies**: `Combine`, `UserDefaults`

```swift
// Base event protocol
public protocol TheaEvent: Sendable, Codable, Identifiable {
    var id: UUID { get }
    var timestamp: Date { get }
    var source: EventSource { get }
    var category: EventCategory { get }
}

public enum EventSource: String, Sendable, Codable {
    case user, ai, system, agent, integration, scheduler
}

public enum EventCategory: String, Sendable, Codable, CaseIterable {
    case message, action, navigation, state, error, performance, learning, integration
}

// Concrete events
public struct MessageEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .message

    public let conversationId: UUID
    public let content: String
    public let role: MessageRole
    public let model: String?
}

public struct ActionEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .action

    public let actionType: ActionType
    public let details: [String: String]
    public let success: Bool
    public let error: String?
}

public struct ErrorEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .error

    public let errorType: String
    public let message: String
    public let stackTrace: String?
    public let recoverable: Bool
}

public struct LearningEvent: TheaEvent {
    public let id: UUID
    public let timestamp: Date
    public let source: EventSource
    public let category: EventCategory = .learning

    public let learningType: LearningType
    public let relatedEventId: UUID?
    public let data: [String: String]
}

// Event bus
@MainActor
public final class EventBus: ObservableObject {
    public static let shared: EventBus

    @Published public private(set) var recentEvents: [any TheaEvent]

    public var maxRecentEvents: Int = 100
    public var maxHistorySize: Int = 10000
    public var persistEvents: Bool = true

    // Publishing
    public func publish<E: TheaEvent>(_ event: E)

    // Subscribing
    public func subscribe(to category: EventCategory, handler: @escaping (any TheaEvent) -> Void)
    public func subscribeToAll(handler: @escaping (any TheaEvent) -> Void)

    // Querying
    public func getEvents(
        category: EventCategory?,
        source: EventSource?,
        since: Date?,
        limit: Int
    ) -> [any TheaEvent]

    // Convenience methods
    public func logMessage(conversationId: UUID, content: String, role: MessageEvent.MessageRole, model: String?)
    public func logAction(_ actionType: ActionEvent.ActionType, details: [String: String], success: Bool, error: String?)
    public func logError(_ errorType: String, message: String, recoverable: Bool)
    public func logPerformance(operation: String, duration: TimeInterval, metadata: [String: String])
    public func logLearning(type: LearningEvent.LearningType, relatedTo eventId: UUID?, data: [String: String])
}
```

---

## 7. UI COMPONENT FILES

### 7.1 ConfidenceIndicatorViews.swift

**Location**: `/Shared/UI/Components/ConfidenceIndicatorViews.swift`
**Lines**: ~580
**Dependencies**: `SwiftUI`, `ConfidenceResult`

```swift
// Compact badge
public struct ConfidenceBadge: View {
    let result: ConfidenceResult
    @State private var isExpanded: Bool

    public var body: some View
    // Displays level icon + text, tappable for detail popover
}

// Full detail view
public struct ConfidenceDetailView: View {
    let result: ConfidenceResult
    @Environment(\.dismiss) private var dismiss

    // Sections: header, sourceBreakdown, factors, conflicts, suggestions
    public var body: some View
}

// Circular gauge
public struct ConfidenceGauge: View {
    let confidence: Double
    let size: CGFloat
    var showLabel: Bool = true

    public var body: some View
    // Circular progress with percentage
}

// Horizontal bar
public struct ConfidenceMiniBar: View {
    let confidence: Double

    public var body: some View
    // Colored progress bar
}

// Small inline indicator
public struct ConfidenceIndicatorSmall: View {
    let level: ConfidenceLevel

    public var body: some View
    // Dot + short label
}
```

### 7.2 MemoryContextView.swift

**Location**: `/Shared/UI/Components/MemoryContextView.swift`
**Lines**: ~300
**Dependencies**: `SwiftUI`, `RetrievalSource`

```swift
// Badge showing memory was used
public struct MemoryContextBadge: View {
    let sourceCount: Int
    let confidence: Double

    public var body: some View
}

// Full source list
public struct MemorySourcesView: View {
    let sources: [RetrievalSource]

    public var body: some View
    // Grouped by tier, with relevance indicators
}

// Status indicator
public struct MemoryStatusIndicator: View {
    let isActive: Bool
    let sourcesUsed: Int

    public var body: some View
    // Brain icon with count
}

// Suggestions display
public struct ContextualSuggestionsView: View {
    let suggestions: [ContextualSuggestion]
    let onSelect: (ContextualSuggestion) -> Void

    public var body: some View
    // Horizontal scroll of suggestion chips
}
```

---

## APPENDIX: File Statistics Summary

| File | Lines | Types | Methods | Dependencies |
|------|-------|-------|---------|--------------|
| ConfidenceSystem.swift | 410 | 6 | 4 | 5 |
| MultiModelConsensus.swift | 350 | 3 | 5 | 3 |
| WebSearchVerifier.swift | 300 | 3 | 4 | 2 |
| CodeExecutionVerifier.swift | 450 | 5 | 6 | 3 |
| StaticAnalysisVerifier.swift | 400 | 3 | 5 | 2 |
| UserFeedbackLearner.swift | 250 | 3 | 3 | 1 |
| ActiveMemoryRetrieval.swift | 550 | 7 | 8 | 4 |
| MemoryAugmentedChat.swift | 280 | 4 | 5 | 3 |
| EventBus.swift | 525 | 8 | 12 | 2 |
| ConfidenceIndicatorViews.swift | 580 | 8 | - | 2 |
| MemoryContextView.swift | 300 | 5 | - | 2 |

---

*This L3 specification documents every public type, method, and property for core Thea files. Use this as the authoritative reference for API contracts.*
