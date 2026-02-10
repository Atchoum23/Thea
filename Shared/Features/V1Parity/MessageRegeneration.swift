// MessageRegeneration.swift
// Thea V2
//
// Message regeneration capability from V1.
// Allows users to regenerate AI responses with different parameters.
//
// V1 FEATURE PARITY
// CREATED: February 2, 2026

import Foundation
import OSLog

// MARK: - Message Regeneration Service

@MainActor
@Observable
public final class MessageRegenerationService {
    public static let shared = MessageRegenerationService()

    private let logger = Logger(subsystem: "com.thea.features", category: "Regeneration")

    // MARK: - Configuration

    public var defaultVariations: Int = 3
    public var preserveContext: Bool = true
    public var adjustTemperature: Bool = true

    // MARK: - State

    public private(set) var isRegenerating: Bool = false
    public private(set) var regenerationHistory: [RegenerationRecord] = []

    private init() {}

    // MARK: - Public API

    /// Regenerate a message at a given index with the same prompt but fresh response
    func regenerate(
        messageIndex: Int,
        conversation: [AIMessage],
        provider: AIProvider? = nil
    ) async throws -> AIMessage {
        isRegenerating = true
        defer { isRegenerating = false }

        logger.info("Regenerating message at index \(messageIndex)...")

        let targetProvider = provider ?? ProviderRegistry.shared.getDefaultProvider()
        guard let targetProvider else {
            throw RegenerationError.noProviderAvailable
        }

        // Validate index
        guard messageIndex >= 0 && messageIndex < conversation.count else {
            throw RegenerationError.messageNotFound
        }

        // Get the user prompt that generated this message (should be the previous message)
        let userPromptIndex = messageIndex - 1
        guard userPromptIndex >= 0 else {
            throw RegenerationError.noPromptFound
        }

        let prompt = conversation[userPromptIndex]
        guard prompt.role == .user else {
            throw RegenerationError.noPromptFound
        }

        // Build context from conversation history (messages before the user prompt)
        let contextMessages = preserveContext
            ? Array(conversation.prefix(userPromptIndex))
            : []

        // Adjust temperature for variation
        let model = await DynamicConfig.shared.bestModel(for: .conversation)
        _ = DynamicConfig.shared.temperature(for: .conversation)
        // Note: temperature/maxTokens are not part of the active AIProvider.chat() API;
        // they would need provider-specific configuration. Using default streaming.

        // Generate new response
        let stream = try await targetProvider.chat(
            messages: contextMessages + [prompt],
            model: model,
            stream: true
        )

        var responseText = ""
        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text):
                responseText += text
            case .complete:
                break
            case .error(let error):
                throw error
            }
        }

        let newMessage = AIMessage(
            id: UUID(),
            conversationID: prompt.conversationID,
            role: .assistant,
            content: .text(responseText),
            timestamp: Date(),
            model: model
        )

        // Record regeneration
        regenerationHistory.append(RegenerationRecord(
            originalIndex: messageIndex,
            timestamp: Date(),
            temperature: 0.7
        ))

        logger.info("Regeneration complete")
        return newMessage
    }

    /// Generate multiple variations of a response
    func generateVariations(
        messageIndex: Int,
        conversation: [AIMessage],
        count: Int? = nil
    ) async throws -> [AIMessage] {
        let variationCount = count ?? defaultVariations
        var variations: [AIMessage] = []

        for i in 0..<variationCount {
            logger.info("Generating variation \(i + 1)/\(variationCount)")

            let variation = try await regenerate(
                messageIndex: messageIndex,
                conversation: conversation
            )
            variations.append(variation)
        }

        return variations
    }

    /// Clear regeneration history
    public func clearHistory() {
        regenerationHistory.removeAll()
    }
}

// MARK: - Supporting Types

public struct RegenerationRecord: Sendable, Identifiable {
    public let id = UUID()
    public let originalIndex: Int
    public let timestamp: Date
    public let temperature: Double
}

public enum RegenerationError: Error, LocalizedError {
    case noProviderAvailable
    case messageNotFound
    case noPromptFound
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            return "No AI provider available for regeneration"
        case .messageNotFound:
            return "Original message not found in conversation"
        case .noPromptFound:
            return "Could not find the user prompt for this message"
        case .generationFailed(let reason):
            return "Regeneration failed: \(reason)"
        }
    }
}
