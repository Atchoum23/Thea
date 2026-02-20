// THEAOrchestrator.swift
// Thea V2 - The Heart of THEA
//
// Central coordinator for ALL user interactions.
// NEVER bypassed - every input flows through here.
// Makes Meta-AI the true heart of the system.

import Foundation
import os.log

// MARK: - THEA Orchestrator

/// The central nervous system of THEA - coordinates all AI components
/// Every user interaction MUST go through this orchestrator
@MainActor
public final class MetaAICoordinator: ObservableObject {
    public static let shared = MetaAICoordinator()

    private let logger = Logger(subsystem: "ai.thea.app", category: "Orchestrator")

    // MARK: - Published State

    @Published public private(set) var isProcessing = false
    @Published public private(set) var currentDecision: THEADecision?
    @Published public private(set) var lastResponse: THEAResponse?
    @Published public private(set) var orchestratorStats = OrchestratorStats()

    // MARK: - Configuration

    /// Whether to show detailed reasoning to the user
    public var showDetailedReasoning: Bool = true

    /// Whether to provide proactive suggestions
    public var enableTHEASuggestions: Bool = true

    /// Whether to record all interactions for learning
    public var enableLearning: Bool = true

    // MARK: - Initialization

    private init() {
        logger.info("THEAOrchestrator initialized - I am the heart of THEA")
    }

    // MARK: - Core Processing (THE Entry Point)

    /// Process user input through the full Meta-AI pipeline
    /// This is THE entry point for all user interactions
    public func process(_ input: THEAInput) async throws -> THEAResponse {
        isProcessing = true
        defer { isProcessing = false }

        let startTime = Date()
        logger.info("Processing input: \(input.text.prefix(50))...")

        // Step 1: Capture full context (MANDATORY)
        let context = await captureFullContext(for: input)

        // Step 2: Recall relevant memories
        let memories = await recallRelevantMemories(for: input)

        // Step 3: Classify the task (MANDATORY)
        let classification = try await classifyTask(input.text)

        // Step 4: Make routing decision with full reasoning (MANDATORY)
        let decision = await makeDecision(
            input: input,
            context: context,
            classification: classification,
            memories: memories
        )
        currentDecision = decision

        // Step 5: Execute the decision
        let executionResult = try await executeDecision(input: input, decision: decision)

        // Step 6: Generate proactive suggestions
        let suggestions = await generateSuggestions(
            input: input,
            response: executionResult,
            context: context
        )

        // Step 7: Determine what was learned
        let learnings = await extractLearnings(
            input: input,
            decision: decision,
            response: executionResult
        )

        // Step 8: Build complete response
        let response = THEAResponse(
            id: UUID(),
            content: executionResult.content,
            decision: decision,
            metadata: THEAResponseMetadata(
                startTime: startTime,
                endTime: Date(),
                tokenCount: executionResult.tokenCount,
                modelUsed: decision.selectedModel,
                providerUsed: decision.selectedProvider
            ),
            suggestions: suggestions
        )

        lastResponse = response

        // Step 9: Record outcome for learning (MANDATORY if enabled)
        if enableLearning {
            await recordOutcome(input: input, decision: decision, response: response)
        }

        // Update stats
        orchestratorStats.totalProcessed += 1
        orchestratorStats.averageLatency = (orchestratorStats.averageLatency * Double(orchestratorStats.totalProcessed - 1) + response.metadata.latency) / Double(orchestratorStats.totalProcessed)

        logger.info("Processed in \(String(format: "%.2f", response.metadata.latency))s using \(decision.selectedModel)")

        return response
    }

    // Stream processing - returns an async stream with progressive response
    // swiftlint:disable:next function_body_length
    public func processStream(_ input: THEAInput) -> AsyncThrowingStream<THEAStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    isProcessing = true
                    defer { isProcessing = false }

                    let startTime = Date()

                    // Pre-processing (same as non-streaming)
                    let context = await captureFullContext(for: input)
                    let memories = await recallRelevantMemories(for: input)
                    let classification = try await classifyTask(input.text)
                    let decision = await makeDecision(
                        input: input,
                        context: context,
                        classification: classification,
                        memories: memories
                    )

                    await MainActor.run { currentDecision = decision }

                    // Send decision chunk first (so UI can show reasoning)
                    continuation.yield(.decision(decision))

                    // Plan mode: decompose, create visible plan, execute step by step
                    if decision.strategy == .planMode {
                        let decomposition = try await QueryDecomposer.shared.decompose(input.text)

                        let plan = PlanManager.shared.createSimplePlan(
                            title: self.generatePlanTitle(input.text),
                            steps: decomposition.subQueries.map { $0.query },
                            conversationId: input.conversationId
                        )

                        continuation.yield(.planCreated(plan))
                        PlanManager.shared.showPanel()
                        PlanManager.shared.startExecution()

                        var fullContent = ""
                        var tokenCount = 0
                        var completedIds = Set<UUID>()

                        for phase in plan.phases {
                            for step in phase.steps {
                                guard let subQuery = decomposition.subQueries.first(where: { $0.id == step.subQueryId }) else {
                                    continue
                                }

                                // Wait for dependencies
                                guard subQuery.canExecute(completed: completedIds) else { continue }

                                continuation.yield(.planStepStarted(step.id))
                                PlanManager.shared.stepStarted(step.id, modelUsed: decision.selectedModel)

                                do {
                                    let stepResult = try await self.executeSubQuery(subQuery, decision: decision)
                                    continuation.yield(.content(stepResult.content))
                                    continuation.yield(.planStepCompleted(step.id, stepResult.content))
                                    PlanManager.shared.stepCompleted(step.id, result: stepResult.content)
                                    fullContent += stepResult.content + "\n\n"
                                    tokenCount += stepResult.tokenCount
                                    completedIds.insert(subQuery.id)
                                } catch {
                                    continuation.yield(.planStepFailed(step.id, error.localizedDescription))
                                    PlanManager.shared.stepFailed(step.id, error: error.localizedDescription)
                                }
                            }
                        }

                        if let finalPlan = PlanManager.shared.activePlan {
                            continuation.yield(.planCompleted(finalPlan))
                        }

                        // Build final response
                        let response = THEAResponse(
                            id: UUID(),
                            content: fullContent.trimmingCharacters(in: .whitespacesAndNewlines),
                            decision: decision,
                            metadata: THEAResponseMetadata(
                                startTime: startTime,
                                endTime: Date(),
                                tokenCount: tokenCount,
                                modelUsed: decision.selectedModel,
                                providerUsed: decision.selectedProvider
                            ),
                            suggestions: []
                        )

                        continuation.yield(.complete(response))

                        if self.enableLearning {
                            await self.recordOutcome(input: input, decision: decision, response: response)
                        }

                        continuation.finish()
                        return
                    }

                    // Execute with streaming (non-plan-mode path)
                    var fullContent = ""
                    var tokenCount = 0

                    let stream = try await executeDecisionStreaming(input: input, decision: decision)

                    for try await chunk in stream {
                        fullContent += chunk.text
                        tokenCount += chunk.tokens
                        continuation.yield(.content(chunk.text))
                    }

                    // Post-processing
                    let suggestions = await generateSuggestions(
                        input: input,
                        response: THEAExecutionResult(content: fullContent, tokenCount: tokenCount),
                        context: context
                    )

                    _ = await extractLearnings(
                        input: input,
                        decision: decision,
                        response: THEAExecutionResult(content: fullContent, tokenCount: tokenCount)
                    )

                    // Send final metadata
                    let response = THEAResponse(
                        id: UUID(),
                        content: fullContent,
                        decision: decision,
                        metadata: THEAResponseMetadata(
                            startTime: startTime,
                            endTime: Date(),
                            tokenCount: tokenCount,
                            modelUsed: decision.selectedModel,
                            providerUsed: decision.selectedProvider
                        ),
                        suggestions: suggestions
                    )

                    continuation.yield(.complete(response))

                    // Record outcome
                    if enableLearning {
                        await recordOutcome(input: input, decision: decision, response: response)
                    }

                    continuation.finish()
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Step 1: Context Capture

    private func captureFullContext(for input: THEAInput) async -> AggregatedContext {
        let context = await ContextAggregator.shared.captureContext(
            query: input.text,
            intent: nil // Will be filled by classification
        )

        logger.debug("Context captured: battery=\(context.device.batteryLevel ?? -1), network=\(context.device.networkStatus.rawValue)")

        return context
    }

    // MARK: - Step 2: Memory Recall

    private func recallRelevantMemories(for input: THEAInput) async -> [OmniMemoryRecord] {
        // Semantic search for relevant memories
        let semanticMatches = await MemoryManager.shared.semanticSearch(
            query: input.text,
            limit: 5
        )

        // Also check for conversation-specific memories
        let conversationMemories = await MemoryManager.shared.retrieveEpisodicMemories(
            from: Calendar.current.date(byAdding: .hour, value: -24, to: Date()),
            limit: 3
        )

        // Combine and dedupe
        var allMemories = semanticMatches
        for memory in conversationMemories {
            if !allMemories.contains(where: { $0.id == memory.id }) {
                allMemories.append(memory)
            }
        }

        logger.debug("Recalled \(allMemories.count) relevant memories")

        return allMemories
    }

    // MARK: - Step 3: Task Classification

    private func classifyTask(_ text: String) async throws -> ClassificationResult {
        let result = try await TaskClassifier.shared.classify(text)

        logger.debug("Classified as \(result.taskType.rawValue) with \(String(format: "%.0f", result.confidence * 100))% confidence")

        return result
    }

    // MARK: - Step 4: Decision Making

    private func makeDecision(
        input: THEAInput,
        context: AggregatedContext,
        classification: ClassificationResult,
        memories: [OmniMemoryRecord]
    ) async -> THEADecision {
        // Get context-aware routing weights
        let weights = ContextAggregator.shared.recommendRoutingWeights()

        // Check if local models should be preferred
        let localPreference = ContextAggregator.shared.shouldPreferLocalModels()

        // Get best model from historical performance
        let bestModel = ContextAggregator.shared.getBestModelForContext(
            taskType: classification.taskType,
            context: context
        )

        // Use ModelRouter for final selection
        // Get routing from ModelRouter using existing API
        let modelRouterDecision = ModelRouter.shared.route(
            classification: classification,
            context: RoutingContext()
        )
        let routingResult = OrchestratorRoutingResult(
            modelId: modelRouterDecision.model.id,
            providerId: modelRouterDecision.provider,
            strategy: determineStrategy(classification: classification, input: input, context: context)
        )

        // Build reasoning explanation
        let reasoning = buildReasoning(
            classification: classification,
            context: context,
            weights: weights,
            localPreference: localPreference,
            bestModel: bestModel,
            routingResult: routingResult
        )

        // Determine execution strategy
        let strategy = determineStrategy(
            classification: classification,
            input: input,
            context: context
        )

        // Build context factors that influenced the decision
        let contextFactors = buildContextFactors(context: context, weights: weights)

        return THEADecision(
            id: UUID(),
            reasoning: reasoning,
            selectedModel: routingResult.modelId,
            selectedProvider: routingResult.providerId,
            strategy: strategy,
            confidenceScore: classification.confidence,
            contextFactors: contextFactors,
            timestamp: Date()
        )
    }

    private func buildReasoning(
        classification: ClassificationResult,
        context: AggregatedContext,
        weights: ContextRoutingWeights,
        localPreference: (prefer: Bool, reason: String),
        bestModel: (model: String?, confidence: Double),
        routingResult: OrchestratorRoutingResult
    ) -> THEAReasoning {
        // Build human-readable explanation
        var whyThisModel = "Selected \(routingResult.modelId) because: "

        if localPreference.prefer {
            whyThisModel += "\(localPreference.reason). "
        }

        switch classification.taskType {
        case .codeGeneration, .codeDebugging, .codeAnalysis, .codeRefactoring:
            whyThisModel += "Code tasks require strong reasoning capabilities. "
        case .creative, .creativeWriting:
            whyThisModel += "Creative tasks benefit from this model's writing abilities. "
        case .math, .mathLogic:
            whyThisModel += "Mathematical reasoning is required. "
        case .factual, .research:
            whyThisModel += "Factual accuracy is important for this query. "
        case .conversation:
            whyThisModel += "Conversational response optimized for natural interaction. "
        default:
            whyThisModel += "Best match for this task type. "
        }

        if bestModel.model != nil && bestModel.confidence > 0.7 {
            whyThisModel += "Historical data shows good performance for similar queries."
        }

        let whyThisStrategy: String
        switch routingResult.strategy {
        case .direct:
            whyThisStrategy = "Direct execution is most efficient for this query."
        case .decomposed:
            whyThisStrategy = "Query is complex and benefits from decomposition."
        case .multiModel:
            whyThisStrategy = "Multiple models will provide best coverage."
        case .localFallback:
            whyThisStrategy = "Using local model for privacy/speed."
        case .planMode:
            whyThisStrategy = "Complex multi-step task — creating a visible plan with tracked progress."
        }

        // Build alternatives
        var alternatives: [(model: String, reason: String)] = []
        if let alt = classification.alternativeTypes?.first {
            alternatives.append((
                model: getDefaultModel(for: alt.0),
                reason: "Would be better if this was a \(alt.0.description) task"
            ))
        }

        return THEAReasoning(
            taskType: classification.taskType,
            taskTypeDescription: classification.taskType.description,
            taskConfidence: classification.confidence,
            whyThisModel: whyThisModel,
            whyThisStrategy: whyThisStrategy,
            alternativesConsidered: alternatives,
            classificationMethod: classification.classificationMethod
        )
    }

    private func determineStrategy(
        classification: ClassificationResult,
        input: THEAInput,
        context: AggregatedContext
    ) -> THEAExecutionStrategy {
        // If network is constrained, prefer local
        if context.device.networkStatus == .disconnected && context.aiResources.localModelCount > 0 {
            return .localFallback
        }

        let _wordCount = input.text.split(separator: " ").count
        let complexity: QueryComplexity = _wordCount < 10 ? .simple : _wordCount < 40 ? .moderate : .complex

        // Plan mode: planning-type tasks with moderate+ complexity
        if classification.taskType == .planning && complexity != .simple {
            return .planMode
        }

        // Plan mode: complex queries that benefit from visible decomposition
        if complexity == .complex && input.text.count > 200 {
            return .planMode
        }

        // Plan mode: multi-domain queries (low confidence + multiple alternative types)
        if classification.confidence < 0.6 &&
            (classification.alternativeTypes?.count ?? 0) >= 2 &&
            input.text.count > 150
        {
            return .planMode
        }

        // Plan mode: substantial research/analysis tasks
        if [.research, .analysis].contains(classification.taskType) && input.text.count > 300 {
            return .planMode
        }

        // Decomposition for moderately complex queries
        if classification.confidence < 0.6 && input.text.count > 200 {
            return .decomposed
        }

        // Default to direct execution
        return .direct
    }

    private func buildContextFactors(context: AggregatedContext, weights: ContextRoutingWeights) -> [ContextFactor] {
        var factors: [ContextFactor] = []

        // Battery
        if let battery = context.device.batteryLevel {
            factors.append(ContextFactor(
                name: "Battery",
                value: "\(battery)%",
                influence: battery < 30 ? .high : .low,
                description: battery < 30 ? "Low battery - preferring efficient models" : "Battery OK"
            ))
        }

        // Network
        factors.append(ContextFactor(
            name: "Network",
            value: context.device.networkStatus.rawValue,
            influence: context.device.networkStatus == .disconnected ? .critical : .low,
            description: context.device.networkStatus == .disconnected ? "Offline - using local models" : "Network available"
        ))

        // Time
        factors.append(ContextFactor(
            name: "Time",
            value: context.temporal.isWorkingHours ? "Work hours" : "Personal time",
            influence: .medium,
            description: context.temporal.isWorkingHours ? "Optimizing for productivity" : "Relaxed mode"
        ))

        // Routing weights
        factors.append(ContextFactor(
            name: "Priority",
            value: weights.description,
            influence: .medium,
            description: "Current optimization: Quality \(Int(weights.quality*100))%, Speed \(Int(weights.speed*100))%, Cost \(Int(weights.cost*100))%"
        ))

        return factors
    }

    private func getDefaultModel(for taskType: TaskType) -> String {
        switch taskType {
        case .codeGeneration, .codeDebugging, .codeAnalysis, .codeRefactoring, .codeExplanation:
            return "claude-sonnet-4"
        case .creative, .creativeWriting:
            return "claude-sonnet-4"
        case .math, .mathLogic, .analysis, .complexReasoning:
            return "gpt-4o"
        case .conversation, .factual:
            return "gpt-4o-mini"
        default:
            return "claude-sonnet-4"
        }
    }

    // MARK: - Step 5: Execution

    private func executeDecision(input: THEAInput, decision: THEADecision) async throws -> THEAExecutionResult {
        // Get the provider
        guard let provider = ProviderRegistry.shared.getProvider(id: decision.selectedProvider) else {
            throw THEAError.providerNotAvailable(decision.selectedProvider)
        }

        // Build messages
        let systemPrompt = THEASelfAwareness.shared.generateSystemPrompt(
            for: decision.reasoning.taskType
        )

        let messages = [
            AIMessage(id: UUID(), conversationID: UUID(), role: .system, content: .text(systemPrompt), timestamp: Date(), model: ""),
            AIMessage(id: UUID(), conversationID: UUID(), role: .user, content: .text(input.text), timestamp: Date(), model: "")
        ]

        // Execute
        var collectedText = ""
        let chatStream1 = try await provider.chat(messages: messages, model: decision.selectedModel, stream: false)
        for try await chunk in chatStream1 {
            if case let .delta(text) = chunk.type { collectedText += text }
        }

        return THEAExecutionResult(
            content: collectedText,
            tokenCount: 0
        )
    }

    private func executeDecisionStreaming(input: THEAInput, decision: THEADecision) async throws -> AsyncThrowingStream<THEAModelStreamChunk, Error> {
        guard let provider = ProviderRegistry.shared.getProvider(id: decision.selectedProvider) else {
            throw THEAError.providerNotAvailable(decision.selectedProvider)
        }

        let systemPrompt = THEASelfAwareness.shared.generateSystemPrompt(
            for: decision.reasoning.taskType
        )

        let messages = [
            AIMessage(id: UUID(), conversationID: UUID(), role: .system, content: .text(systemPrompt), timestamp: Date(), model: ""),
            AIMessage(id: UUID(), conversationID: UUID(), role: .user, content: .text(input.text), timestamp: Date(), model: "")
        ]

        let stream = try await provider.chat(
            messages: messages,
            model: decision.selectedModel,
            stream: true
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in stream {
                        switch chunk.type {
                        case .delta(let text):
                            continuation.yield(THEAModelStreamChunk(text: text, tokens: 1))
                        case .complete:
                            continuation.finish()
                        case .error(let error):
                            continuation.finish(throwing: error)
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Step 6: Suggestions

    private func generateSuggestions(
        input: THEAInput,
        response: THEAExecutionResult,
        context: AggregatedContext
    ) async -> [THEASuggestion] {
        guard enableTHEASuggestions else { return [] }

        var suggestions: [THEASuggestion] = []

        // Code-related suggestions
        if response.content.contains("```") {
            suggestions.append(THEASuggestion(
                type: .action,
                title: "Run this code?",
                description: "I can help you test this code if you'd like.",
                action: "run_code"
            ))
        }

        // Follow-up suggestions based on task type
        if let decision = currentDecision {
            switch decision.reasoning.taskType {
            case .codeGeneration:
                suggestions.append(THEASuggestion(
                    type: .followUp,
                    title: "Add tests?",
                    description: "Would you like me to generate unit tests for this code?",
                    action: "generate_tests"
                ))
            case .research:
                suggestions.append(THEASuggestion(
                    type: .followUp,
                    title: "Dive deeper?",
                    description: "I can explore any of these topics in more detail.",
                    action: "expand_research"
                ))
            case .planning:
                suggestions.append(THEASuggestion(
                    type: .followUp,
                    title: "Create tasks?",
                    description: "Want me to break this plan into actionable tasks?",
                    action: "create_tasks"
                ))
            default:
                break
            }
        }

        return suggestions
    }

    // MARK: - Step 7: Learning Extraction

    private func extractLearnings(
        input: THEAInput,
        decision: THEADecision,
        response: THEAExecutionResult
    ) async -> [THEALearning] {
        var learnings: [THEALearning] = []

        // Learn task type patterns
        learnings.append(THEALearning(
            type: .taskPattern,
            description: "Query patterns for \(decision.reasoning.taskType.description)",
            confidence: decision.reasoning.taskConfidence
        ))

        // Learn model performance (will be confirmed by user feedback)
        learnings.append(THEALearning(
            type: .modelPerformance,
            description: "\(decision.selectedModel) used for \(decision.reasoning.taskType.rawValue)",
            confidence: 0.5 // Initial, updated by feedback
        ))

        return learnings
    }

    // MARK: - Step 9: Outcome Recording

    private func recordOutcome(input: THEAInput, decision: THEADecision, response: THEAResponse) async {
        // Record in ContextAggregator for correlation learning
        await ContextAggregator.shared.recordOutcome(
            context: ContextAggregator.shared.currentContext,
            query: input.text,
            taskType: decision.reasoning.taskType,
            modelUsed: decision.selectedModel,
            success: true, // Will be updated by user feedback
            userSatisfaction: nil,
            latency: response.metadata.latency
        )

        // Record classification for learning
        await TaskClassifier.shared.storeSuccessfulClassification(
            query: input.text,
            result: ClassificationResult(
                taskType: decision.reasoning.taskType,
                confidence: decision.reasoning.taskConfidence,
                classificationMethod: decision.reasoning.classificationMethod
            ),
            wasUseful: true // Will be updated by user feedback
        )

        // Store episodic memory
        await MemoryManager.shared.storeEpisodicMemory(
            event: "chat_interaction",
            context: "Query: \(input.text.prefix(100))\nModel: \(decision.selectedModel)\nTask: \(decision.reasoning.taskType.rawValue)",
            outcome: "completed",
            emotionalValence: 0.0 // Neutral, updated by feedback
        )

        logger.debug("Recorded outcome for learning")
    }

    // MARK: - User Feedback

    // MARK: - Plan Mode Helpers

    private func generatePlanTitle(_ query: String) -> String {
        let firstSentence = query.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).first ?? query
        let trimmed = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 60 { return trimmed }
        return String(trimmed.prefix(57)) + "..."
    }

    private func executeSubQuery(_ subQuery: SubQuery, decision: THEADecision) async throws -> THEAExecutionResult {
        guard let provider = ProviderRegistry.shared.getProvider(id: decision.selectedProvider) else {
            throw THEAError.providerNotAvailable(decision.selectedProvider)
        }

        let systemPrompt = THEASelfAwareness.shared.generateSystemPrompt(for: subQuery.taskType)

        let messages = [
            AIMessage(id: UUID(), conversationID: UUID(), role: .system, content: .text(systemPrompt), timestamp: Date(), model: ""),
            AIMessage(id: UUID(), conversationID: UUID(), role: .user, content: .text(subQuery.query), timestamp: Date(), model: "")
        ]

        var collectedText = ""
        let chatStream1 = try await provider.chat(messages: messages, model: decision.selectedModel, stream: false)
        for try await chunk in chatStream1 {
            if case let .delta(text) = chunk.type { collectedText += text }
        }

        return THEAExecutionResult(
            content: collectedText,
            tokenCount: 0
        )
    }

    /// Record user feedback on a response (thumbs up/down, corrections)
    public func recordFeedback(
        responseId: UUID,
        wasHelpful: Bool,
        correctedTaskType: TaskType? = nil
    ) async {
        guard let response = lastResponse, response.id == responseId else { return }

        // Update TaskClassifier calibration
        TaskClassifier.shared.updateCalibration(
            confidence: response.decision.confidenceScore,
            wasCorrect: correctedTaskType == nil
        )

        // If task type was corrected, provide feedback
        if let corrected = correctedTaskType {
            TaskClassifier.shared.provideFeedback(
                for: response.decision.reasoning.taskType.rawValue,
                classified: response.decision.reasoning.taskType,
                actual: corrected
            )
        }

        // Update episodic memory with feedback
        await MemoryManager.shared.storeEpisodicMemory(
            event: "user_feedback",
            context: "Response: \(response.id)\nHelpful: \(wasHelpful)\nCorrected: \(correctedTaskType?.rawValue ?? "none")",
            outcome: wasHelpful ? "positive" : "negative",
            emotionalValence: wasHelpful ? 0.8 : -0.5
        )

        orchestratorStats.feedbackReceived += 1
        if wasHelpful {
            orchestratorStats.positiveFeeback += 1
        }

        logger.info("Recorded feedback: helpful=\(wasHelpful), corrected=\(correctedTaskType?.rawValue ?? "none")")
    }
}

// MARK: - Supporting Types

public struct THEAInput: Sendable {
    public let text: String
    public let conversationId: UUID?
    public let attachments: [THEAAttachment]
    public let timestamp: Date

    public init(
        text: String,
        conversationId: UUID? = nil,
        attachments: [THEAAttachment] = [],
        timestamp: Date = Date()
    ) {
        self.text = text
        self.conversationId = conversationId
        self.attachments = attachments
        self.timestamp = timestamp
    }
}

public struct THEAAttachment: Sendable {
    public let type: AttachmentType
    public let data: Data
    public let name: String

    public enum AttachmentType: String, Sendable {
        case image
        case file
        case code
    }
}

public struct OrchestratorStats: Sendable {
    public var totalProcessed: Int = 0
    public var averageLatency: TimeInterval = 0
    public var feedbackReceived: Int = 0
    public var positiveFeeback: Int = 0

    public var satisfactionRate: Double {
        guard feedbackReceived > 0 else { return 0 }
        return Double(positiveFeeback) / Double(feedbackReceived)
    }
}

public enum THEAStreamChunk: Sendable {
    case decision(THEADecision)
    case content(String)
    case complete(THEAResponse)
    case error(Error)
    // Plan mode events
    case planCreated(PlanState)
    case planStepStarted(UUID)
    case planStepCompleted(UUID, String?)
    case planStepFailed(UUID, String)
    case planModified(PlanModification)
    case planCompleted(PlanState)
}

struct THEAExecutionResult {
    let content: String
    let tokenCount: Int
}

struct THEAModelStreamChunk {
    let text: String
    let tokens: Int
}

struct OrchestratorRoutingResult {
    let modelId: String
    let providerId: String
    let strategy: THEAExecutionStrategy
}

public enum THEAError: Error, LocalizedError {
    case providerNotAvailable(String)
    case classificationFailed
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .providerNotAvailable(let provider):
            return "Provider not available: \(provider)"
        case .classificationFailed:
            return "Failed to classify the input"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}
