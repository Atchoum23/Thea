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
    static let shared = TheaIntelligenceOrchestrator()

    private let logger = Logger(subsystem: "com.thea.app", category: "IntelligenceOrchestrator")

    // MARK: - State

    private(set) var isRunning = false
    private(set) var lastEvaluationDate: Date?
    private(set) var evaluationCount = 0
    private(set) var systemStatus: IntelligenceSystemStatus = .idle

    /// Periodic evaluation timer
    private var evaluationTimer: Timer?

    // MARK: - Configuration

    /// Master switch for the intelligence orchestrator
    var isEnabled = true

    /// Evaluation interval in minutes
    var evaluationIntervalMinutes = 30

    /// Whether to auto-start when the app launches
    var autoStart = true

    private init() {}

    // MARK: - Lifecycle

    /// Start the intelligence orchestrator. Call this from app startup.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        systemStatus = .active

        logger.info("Intelligence Orchestrator starting...")

        // Initialize all subsystems
        initializeSubsystems()

        // Start periodic evaluation
        startPeriodicEvaluation()

        // Run initial evaluation
        Task {
            await evaluate()
        }

        logger.info("Intelligence Orchestrator started")
    }

    /// Stop the intelligence orchestrator.
    func stop() {
        isRunning = false
        systemStatus = .idle
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        logger.info("Intelligence Orchestrator stopped")
    }

    // MARK: - Initialization

    private func initializeSubsystems() {
        // Load persisted state from disk
        Task {
            await PersonalKnowledgeGraph.shared.load()
            BehavioralFingerprint.shared.load()
        }

        logger.info("Subsystems initialized")
    }

    // MARK: - Periodic Evaluation

    private func startPeriodicEvaluation() {
        evaluationTimer?.invalidate()
        evaluationTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(evaluationIntervalMinutes * 60),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.evaluate()
            }
        }
    }

    /// Run a full evaluation cycle across all intelligence systems.
    func evaluate() async {
        guard isEnabled else { return }

        systemStatus = .evaluating
        evaluationCount += 1
        let startTime = Date()

        logger.info("Evaluation cycle #\(self.evaluationCount) starting...")

        // 1. Update behavioral fingerprint with current activity
        BehavioralFingerprint.shared.recordActivity(.idle) // Will be overridden by actual activity

        // 2. Run health coaching analysis (respects its own cooldown)
        await HealthCoachingPipeline.shared.runAnalysis()

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

    /// Process an AI response through the intelligence pipeline.
    /// Call this after receiving a response from any AI provider.
    func processAIResponse(
        task: String,
        response: String,
        conversationContext: String = ""
    ) async -> String {
        guard isEnabled else { return response }

        // Run through reflexion if needed
        let reflexionResult = await ChatReflexionIntegration.shared.processResponse(
            task: task,
            response: response,
            conversationContext: conversationContext
        )

        return reflexionResult.response
    }

    /// Extract memory from a completed conversation
    func extractConversationMemory(_ conversation: Conversation) async {
        guard isEnabled else { return }
        await ConversationMemoryExtractor.shared.extractFromConversation(conversation)
    }

    /// Extract memory from a single user message (real-time)
    func extractMessageMemory(_ text: String) async {
        guard isEnabled else { return }
        await ConversationMemoryExtractor.shared.extractFromMessage(text)
    }

    // MARK: - AI Query with Fallback

    /// Send an AI query through the resilient fallback chain
    func query(_ prompt: String) async throws -> String {
        try await ResilientAIFallbackChain.shared.quickQuery(prompt)
    }

    /// Send a full chat through the resilient fallback chain
    func chat(messages: [AIMessage]) async throws -> FallbackChatResult {
        try await ResilientAIFallbackChain.shared.chat(messages: messages)
    }

    // MARK: - System Status

    /// Get a comprehensive status report of all intelligence systems
    func statusReport() async -> IntelligenceStatusReport {
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
