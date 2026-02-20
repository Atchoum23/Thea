// TheaIntelligenceOrchestrator.swift
// Thea — Unified Cross-System Intelligence Orchestrator
//
// The "brain" that coordinates all intelligence subsystems into a
// coherent autonomous agent. Manages lifecycle, periodic evaluation,
// and system-wide intelligence state.
//
// Subsystems managed:
//   - ResilientAIFallbackChain (AI provider resilience)
//   - PersonalKnowledgeGraph (entity-relationship memory)
//   - BehavioralFingerprint (temporal user patterns)
//   - SmartNotificationScheduler (optimal delivery timing)
//   - HealthCoachingPipeline (health data → coaching)
//   - PersonalBaselineMonitor (rolling health baselines + anomaly detection)
//   - ProactiveEngagementEngine (autonomous initiative)
//   - ChatReflexionIntegration (response quality improvement)
//   - ConversationMemoryExtractor (session-to-session memory)
//   - TaskPlanDAG (task decomposition and execution)

import Foundation
import OSLog

// MARK: - Intelligence Orchestrator

@MainActor
@Observable
final class TheaIntelligenceOrchestrator {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = TheaIntelligenceOrchestrator()

    private let logger = Logger(subsystem: "com.thea.app", category: "IntelligenceOrchestrator")

    // MARK: - State

    private(set) var isRunning = false
    private(set) var lastEvaluationDate: Date?
    private(set) var evaluationCount = 0
    private(set) var systemStatus: IntelligenceSystemStatus = .idle

    /// Periodic evaluation timer
    private var evaluationTimer: Timer?

// periphery:ignore - Reserved: shared static property reserved for future feature activation

    // periphery:ignore - Reserved: logger property reserved for future feature activation
    // MARK: - Configuration

    /// Master switch for the intelligence orchestrator
    var isEnabled = true

    /// Evaluation interval in minutes
    var evaluationIntervalMinutes = 30

    /// Whether to auto-start when the app launches
    var autoStart = true

    private init() {}

    // MARK: - Lifecycle

    // periphery:ignore - Reserved: start() instance method — reserved for future feature activation
    /// Start the intelligence orchestrator. Call this from app startup.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        systemStatus = .active

        logger.info("Intelligence Orchestrator starting...")

        // Initialize all subsystems
        initializeSubsystems()

        // Start periodic evaluation
        // periphery:ignore - Reserved: start() instance method reserved for future feature activation
        startPeriodicEvaluation()

        // Run initial evaluation
        Task {
            await evaluate()
        }

        logger.info("Intelligence Orchestrator started")
    }

    // periphery:ignore - Reserved: stop() instance method — reserved for future feature activation
    /// Stop the intelligence orchestrator.
    func stop() {
        isRunning = false
        systemStatus = .idle
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        logger.info("Intelligence Orchestrator stopped")
    }

    // MARK: - Initialization

    // periphery:ignore - Reserved: stop() instance method reserved for future feature activation
    private func initializeSubsystems() {
        // Load persisted state from disk
        Task {
            await PersonalKnowledgeGraph.shared.load()
            BehavioralFingerprint.shared.load()
            // Touch PersonalBaselineMonitor.shared to trigger loadFromDisk()
            // and pruneAlertHistory() on first access.
            _ = PersonalBaselineMonitor.shared.baselines.count
        }

// periphery:ignore - Reserved: initializeSubsystems() instance method reserved for future feature activation

        logger.info("Subsystems initialized")
    }

    // MARK: - Periodic Evaluation

    // periphery:ignore - Reserved: startPeriodicEvaluation() instance method — reserved for future feature activation
    private func startPeriodicEvaluation() {
        evaluationTimer?.invalidate()
        evaluationTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(evaluationIntervalMinutes * 60),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.evaluate()
            // periphery:ignore - Reserved: startPeriodicEvaluation() instance method reserved for future feature activation
            }
        }
    }

    // periphery:ignore - Reserved: evaluate() instance method — reserved for future feature activation
    /// Run a full evaluation cycle across all intelligence systems.
    func evaluate() async {
        guard isEnabled else { return }

        systemStatus = .evaluating
        evaluationCount += 1
        let startTime = Date()

        // periphery:ignore - Reserved: evaluate() instance method reserved for future feature activation
        logger.info("Evaluation cycle #\(self.evaluationCount) starting...")

        // 1. Update behavioral fingerprint with current activity
        BehavioralFingerprint.shared.recordActivity(.idle) // Will be overridden by actual activity

        // 2. Run health coaching analysis (respects its own cooldown)
        await HealthCoachingPipeline.shared.runAnalysis()

        // 2b. Run personal baseline check (queries HealthKit, updates rolling
        //     baselines, runs z-score + CUSUM anomaly detection).
        await PersonalBaselineMonitor.shared.runDailyCheck()

        // 3. Evaluate proactive engagement opportunities
        await ProactiveEngagementEngine.shared.evaluate()

        // 4. Persist state
        await PersonalKnowledgeGraph.shared.save()
        BehavioralFingerprint.shared.save()

        let elapsed = Date().timeIntervalSince(startTime)
        lastEvaluationDate = Date()
        systemStatus = .active

        logger.info("Evaluation cycle #\(self.evaluationCount) completed in \(String(format: "%.1f", elapsed))s")
    }

    // MARK: - Chat Integration

    // periphery:ignore - Reserved: processAIResponse(task:response:conversationContext:) instance method — reserved for future feature activation
    /// Process an AI response through the intelligence pipeline.
    /// Call this after receiving a response from any AI provider.
    func processAIResponse(
        task: String,
        response: String,
        conversationContext: String = "",
        conversationID: UUID? = nil
    ) async -> String {
        guard isEnabled else { return response }

        // U3: MemoryAugmentedChat — learn from exchange, record to conversation memory
        await MemoryAugmentedChat.shared.processResponse(
            userMessage: task,
            assistantResponse: response,
            conversationId: conversationID ?? UUID()
        )

        // Run through reflexion if needed
        let reflexionResult = await ChatReflexionIntegration.shared.processResponse(
            task: task,
            response: response,
            conversationContext: conversationContext
        )

        return reflexionResult.response
    }

    // periphery:ignore - Reserved: extractConversationMemory(_:) instance method — reserved for future feature activation
    /// Extract memory from a completed conversation
    func extractConversationMemory(_ conversation: Conversation) async {
        guard isEnabled else { return }
        await ConversationMemoryExtractor.shared.extractFromConversation(conversation)
    }

    // periphery:ignore - Reserved: extractConversationMemory(_:) instance method reserved for future feature activation
    /// Extract memory from a single user message (real-time)
    func extractMessageMemory(_ text: String) async {
        guard isEnabled else { return }
        await ConversationMemoryExtractor.shared.extractFromMessage(text)
    }

// periphery:ignore - Reserved: extractMessageMemory(_:) instance method reserved for future feature activation

    // MARK: - AI Query with Fallback

    /// Send an AI query through the resilient fallback chain
    func query(_ prompt: String) async throws -> String {
        try await ResilientAIFallbackChain.shared.quickQuery(prompt)
    }

// periphery:ignore - Reserved: query(_:) instance method reserved for future feature activation

    /// Send a full chat through the resilient fallback chain
    func chat(messages: [AIMessage]) async throws -> FallbackChatResult {
        try await ResilientAIFallbackChain.shared.chat(messages: messages)
    // periphery:ignore - Reserved: chat(messages:) instance method reserved for future feature activation
    }

    // MARK: - System Status

    // periphery:ignore - Reserved: statusReport() instance method — reserved for future feature activation
    /// Get a comprehensive status report of all intelligence systems
    func statusReport() async -> IntelligenceStatusReport {
        // periphery:ignore - Reserved: statusReport() instance method reserved for future feature activation
        let graph = PersonalKnowledgeGraph.shared
        let fingerprint = BehavioralFingerprint.shared
        let scheduler = SmartNotificationScheduler.shared
        let health = HealthCoachingPipeline.shared
        let proactive = ProactiveEngagementEngine.shared
        let reflexion = ChatReflexionIntegration.shared
        let memory = ConversationMemoryExtractor.shared
        let fallback = ResilientAIFallbackChain.shared

        let graphEntities = await graph.entityCount
        let graphEdges = await graph.edgeCount

        return IntelligenceStatusReport(
            isRunning: isRunning,
            evaluationCount: evaluationCount,
            lastEvaluation: lastEvaluationDate,
            knowledgeGraphEntities: graphEntities,
            knowledgeGraphEdges: graphEdges,
            behavioralSlotsRecorded: fingerprint.totalRecordedSlots,
            notificationsScheduled: scheduler.scheduledCount,
            notificationsDeferred: scheduler.deferredCount,
            healthInsightsActive: health.activeInsights.count,
            healthOverallScore: health.lastAnalysis?.overallScore,
            proactiveEngagementsToday: proactive.todayEngagementCount,
            reflexionCount: reflexion.reflexionCount,
            reflexionImprovementRate: reflexion.improvementRate,
            memoryExtractedCount: memory.extractedCount,
            fallbackCurrentTier: fallback.currentTier,
            fallbackIsOffline: fallback.isOfflineMode
        )
    }
}

// MARK: - Types

enum IntelligenceSystemStatus: String, Sendable {
    case idle
    case active
    case evaluating
    case error
}

// periphery:ignore - Reserved: IntelligenceStatusReport type reserved for future feature activation
struct IntelligenceStatusReport: Sendable {
    let isRunning: Bool
    let evaluationCount: Int
    let lastEvaluation: Date?

    // Knowledge Graph
    let knowledgeGraphEntities: Int
    let knowledgeGraphEdges: Int

    // Behavioral
    let behavioralSlotsRecorded: Int

    // Notifications
    let notificationsScheduled: Int
    let notificationsDeferred: Int

    // Health
    let healthInsightsActive: Int
    let healthOverallScore: Double?

    // Proactive
    let proactiveEngagementsToday: Int

    // Reflexion
    let reflexionCount: Int
    let reflexionImprovementRate: Double

    // Memory
    let memoryExtractedCount: Int

    // Fallback
    let fallbackCurrentTier: FallbackTier
    let fallbackIsOffline: Bool
}

// MARK: - Meta-AI Extension

extension TheaIntelligenceOrchestrator {
    /// Process a user query through the MetaAI coordination layer.
    /// Routes the query via MetaAICoordinator which applies full orchestration:
    /// classification, model selection, plan mode, decomposition, and learning.
    /// - Parameters:
    ///   - query: The raw user query text.
    ///   - classification: Optional pre-computed classification result.
    /// - Returns: The full THEA response with decision and metadata.
    @discardableResult
    func processWithMetaAI(
        _ query: String,
        classification: ClassificationResult? = nil
    ) async throws -> THEAResponse {
        let input = THEAInput(
            text: query,
            conversationId: UUID()
        )
        return try await MetaAICoordinator.shared.process(input)
    }
}
