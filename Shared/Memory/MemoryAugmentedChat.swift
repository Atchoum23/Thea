// MemoryAugmentedChat.swift
// Thea
//
// Memory-augmented chat system that automatically injects relevant context
// Provides RAG-like capabilities for enhanced AI conversations

import Foundation
import OSLog

// MARK: - Memory Augmented Chat

/// Wraps AI chat with automatic memory retrieval and context injection
@MainActor
public final class MemoryAugmentedChat {
    public static let shared = MemoryAugmentedChat()

    private let logger = Logger(subsystem: "com.thea.ai", category: "MemoryAugmentedChat")
    private let retrieval = ActiveMemoryRetrieval.shared

    // Configuration
    public var config = AugmentationConfig()

    // Statistics
    private var stats = AugmentationStatistics()

    private init() {}

    // MARK: - Public API

    /// Process a user message with memory augmentation
    public func processMessage(
        _ userMessage: String,
        conversationId: UUID,
        projectId: UUID? = nil,
        existingMessages: [ChatMessage] = []
    ) async -> AugmentedMessage {
        logger.debug("Processing message with memory augmentation")

        let startTime = Date()

        // 1. Classify the task to determine context needs
        let taskType = await classifyTask(userMessage)

        // 2. Retrieve relevant context
        let enhancedPrompt = await retrieval.enhancePromptWithContext(
            originalPrompt: userMessage,
            conversationId: conversationId,
            projectId: projectId,
            taskType: taskType
        )

        // 3. Build the system context
        let systemContext = buildSystemContext(
            taskType: taskType,
            retrievedSources: enhancedPrompt.injectedSources,
            projectId: projectId
        )

        // 4. Determine if context should be injected
        let shouldInject = shouldInjectContext(
            confidence: enhancedPrompt.confidence,
            taskType: taskType,
            messageCount: existingMessages.count
        )

        // Update statistics
        let duration = Date().timeIntervalSince(startTime)
        stats.totalAugmentations += 1
        stats.contextInjections += shouldInject ? 1 : 0
        stats.averageLatency = (stats.averageLatency * Double(stats.totalAugmentations - 1) + duration) / Double(stats.totalAugmentations)

        return AugmentedMessage(
            originalMessage: userMessage,
            augmentedMessage: shouldInject ? enhancedPrompt.prompt : userMessage,
            systemContext: systemContext,
            wasAugmented: shouldInject,
            retrievedSources: enhancedPrompt.injectedSources,
            confidence: enhancedPrompt.confidence,
            taskType: taskType,
            processingTime: duration
        )
    }

    /// Process AI response and learn from the exchange
    public func processResponse(
        userMessage: String,
        assistantResponse: String,
        conversationId: UUID,
        wasHelpful: Bool? = nil
    ) async {
        guard config.enableLearning else { return }

        // Learn from the exchange
        await retrieval.learnFromExchange(
            userMessage: userMessage,
            assistantResponse: assistantResponse,
            conversationId: conversationId,
            wasHelpful: wasHelpful
        )

        // Record to conversation memory
        await ConversationMemory.shared.recordConversation(
            userMessage: userMessage,
            assistantResponse: assistantResponse,
            projectId: nil,
            messageIndex: stats.totalAugmentations
        )
    }

    /// Get context-aware suggestions based on current state
    public func getSuggestions(
        conversationId: UUID,
        recentMessages: [ChatMessage],
        projectId: UUID? = nil
    ) async -> [ContextualSuggestion] {
        var suggestions: [ContextualSuggestion] = []

        // Get last user message for context
        guard let lastUserMessage = recentMessages.last(where: { $0.role == "user" }) else {
            return suggestions
        }

        let content = lastUserMessage.content.textValue

        // Retrieve related procedural memories (how-to knowledge)
        do {
            let procedures = try await MemorySystem.shared.retrieveProceduralMemories(
                for: content,
                limit: 3
            )

            for procedure in procedures where procedure.successRate > 0.7 {
                suggestions.append(ContextualSuggestion(
                    type: .procedure,
                    title: procedure.skill,
                    description: "You've done this before with \(Int(procedure.successRate * 100))% success",
                    action: procedure.steps.first ?? "",
                    confidence: Double(procedure.successRate)
                ))
            }
        } catch {
            logger.warning("Failed to get procedural suggestions: \(error.localizedDescription)")
        }

        // Get relevant facts that might help
        let context = ConversationMemory.shared.retrieveContext(for: content, projectId: projectId)

        for fact in context.facts.prefix(2) where fact.confidence > 0.8 {
            suggestions.append(ContextualSuggestion(
                type: .relatedFact,
                title: fact.category.displayName,
                description: fact.fact,
                action: "",
                confidence: fact.confidence
            ))
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Private Methods

    private func classifyTask(_ message: String) async -> TaskType {
        // Use the AI-powered task classifier
        do {
            let classification = try await TaskClassifier.shared.classify(message)
            return classification.taskType
        } catch {
            logger.warning("Task classification failed: \(error.localizedDescription)")
            return .general
        }
    }

    private func buildSystemContext(
        taskType: TaskType,
        retrievedSources: [RetrievalSource],
        projectId: UUID?
    ) -> String? {
        guard config.enableSystemContext else { return nil }

        var context = ""

        // Add task-specific context
        switch taskType {
        case .codeGeneration, .debugging, .appDevelopment:
            context += "You are an expert software developer. "
            // Add any retrieved technical context
            let techSources = retrievedSources.filter { $0.type == .semantic || $0.metadata["category"] == "technicalContext" }
            if !techSources.isEmpty {
                context += "The user works with: \(techSources.map(\.content).joined(separator: ", ")). "
            }

        case .factual, .research:
            context += "Provide accurate, well-sourced information. "

        case .creative:
            context += "Be creative and engage with the user's ideas. "

        case .analysis:
            context += "Provide thorough analysis with clear reasoning. "

        default:
            break
        }

        // Add any user preferences from memory
        let prefSources = retrievedSources.filter { $0.type == .userPreference }
        if !prefSources.isEmpty {
            context += "User preferences: \(prefSources.map(\.content).joined(separator: "; ")). "
        }

        return context.isEmpty ? nil : context
    }

    private func shouldInjectContext(
        confidence: Double,
        taskType: TaskType,
        messageCount: Int
    ) -> Bool {
        // Don't inject for first message (let user establish context)
        if messageCount == 0 && !config.injectOnFirstMessage {
            return false
        }

        // Always inject for certain task types
        if taskType == .debugging || taskType == .appDevelopment {
            return confidence > 0.3
        }

        // Use confidence threshold
        return confidence > config.minConfidenceToInject
    }

    // MARK: - Statistics

    public func getStatistics() -> AugmentationStatistics {
        stats
    }

    public func resetStatistics() {
        stats = AugmentationStatistics()
    }
}

// MARK: - Supporting Types

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

    public var contextInjected: Bool {
        wasAugmented && !retrievedSources.isEmpty
    }
}

public struct ContextualSuggestion: Sendable, Identifiable {
    public let id = UUID()
    public let type: SuggestionType
    public let title: String
    public let description: String
    public let action: String
    public let confidence: Double

    public enum SuggestionType: String, Sendable {
        case procedure = "How-To"
        case relatedFact = "Related"
        case previousSolution = "Previous Solution"
        case suggestion = "Suggestion"
    }
}

public struct AugmentationStatistics: Sendable {
    public var totalAugmentations: Int = 0
    public var contextInjections: Int = 0
    public var averageLatency: TimeInterval = 0.0
    public var learningEvents: Int = 0

    public var injectionRate: Double {
        totalAugmentations > 0 ? Double(contextInjections) / Double(totalAugmentations) : 0.0
    }
}
