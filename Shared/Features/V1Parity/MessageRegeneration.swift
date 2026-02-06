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
    public func regenerate(
        messageIndex: Int,
        conversation: [ChatMessage],
        provider: AIProvider? = nil
    ) async throws -> ChatMessage {
        isRegenerating = true
        defer { isRegenerating = false }

        logger.info("Regenerating message at index \(messageIndex)...")

        let targetProvider = provider ?? ProviderRegistry.shared.bestAvailableProvider
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
        guard prompt.role == "user" else {
            throw RegenerationError.noPromptFound
        }

        // Build context from conversation history (messages before the user prompt)
        let contextMessages = preserveContext
            ? Array(conversation.prefix(userPromptIndex))
            : []

        // Adjust temperature for variation
        let model = await DynamicConfig.shared.bestModel(for: .conversation)
        let baseTemp = DynamicConfig.shared.temperature(for: .conversation)
        let temperature = adjustTemperature ? min(baseTemp + 0.1, 1.0) : baseTemp

        // Generate new response
        let stream = try await targetProvider.chat(
            messages: contextMessages + [prompt],
            model: model,
            options: ChatOptions(
                temperature: temperature,
                maxTokens: DynamicConfig.shared.maxTokens(for: .conversation),
                stream: true
            )
        )

        var responseText = ""
        for try await chunk in stream {
            switch chunk {
            case .content(let text):
                responseText += text
            case .done:
                break
            case .error(let error):
                throw error
            }
        }

        let newMessage = ChatMessage(role: "assistant", text: responseText)

        // Record regeneration
        regenerationHistory.append(RegenerationRecord(
            originalIndex: messageIndex,
            timestamp: Date(),
            temperature: temperature
        ))

        logger.info("Regeneration complete")
        return newMessage
    }

    /// Generate multiple variations of a response
    public func generateVariations(
        messageIndex: Int,
        conversation: [ChatMessage],
        count: Int? = nil
    ) async throws -> [ChatMessage] {
        let variationCount = count ?? defaultVariations
        var variations: [ChatMessage] = []

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
