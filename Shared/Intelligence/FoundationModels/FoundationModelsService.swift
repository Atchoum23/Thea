// FoundationModelsService.swift
// Thea — AAH3: FoundationModels Intelligence Pipeline
//
// Intelligence-pipeline wrapper around Apple's FoundationModels framework.
// Focuses on Thea-specific tasks: context summarization, intent classification,
// conversation title generation, and query expansion.
//
// This service is DIFFERENT from OnDeviceAIService:
//   OnDeviceAIService — general-purpose text generation / chat API
//   FoundationModelsService — discrete intelligence tasks for Thea pipelines
//
// Availability: macOS 26+, iOS 26+, with Apple Intelligence enabled.
// Guard: #if canImport(FoundationModels)
//
// Wiring: TaskClassifier and PersonalParameters can query this service.
// The service manages its own LanguageModelSession (KV-cache preserved across calls).

import Foundation
import OSLog

#if canImport(FoundationModels)
    import FoundationModels
#endif

// MARK: - FoundationModelsService

/// Intelligence-pipeline service using Apple's on-device FoundationModels.
/// Provides discrete, structured outputs for Thea intelligence subsystems.
@MainActor
public final class FoundationModelsService: ObservableObject {
    public static let shared = FoundationModelsService()

    private let logger = Logger(subsystem: "ai.thea.app", category: "FoundationModelsIntelligence")

    // MARK: - Published State

    @Published public private(set) var isAvailable: Bool = false
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var lastError: String?

    // MARK: - Private State

    #if canImport(FoundationModels)
        private var session: LanguageModelSession?
    #endif

    // MARK: - Init

    private init() {
        Task { await refreshAvailability() }
    }

    // MARK: - Availability

    /// Refresh whether Apple Intelligence / FoundationModels is available.
    public func refreshAvailability() async {
        #if canImport(FoundationModels)
            let availability = SystemLanguageModel.default.availability
            isAvailable = (availability == .available)
            if isAvailable, session == nil {
                session = LanguageModelSession()
                logger.info("FoundationModelsService: session created, on-device AI ready")
            } else if !isAvailable {
                logger.info("FoundationModelsService: Apple Intelligence unavailable (not enabled?)")
            }
        #else
            isAvailable = false
        #endif
    }

    // MARK: - Intelligence Tasks

    /// Summarize a long context string into a concise paragraph (max ~100 words).
    /// - Parameter context: Raw context text (conversation history, notes, etc.)
    /// - Returns: Concise summary, or the original if FoundationModels is unavailable.
    public func summarizeContext(_ context: String) async -> String {
        guard isAvailable, !context.isEmpty else { return context }

        // ABB3: Wrap user content in explicit delimiters to reduce prompt injection risk
        let prompt = """
        Summarize the following context concisely (≤100 words). Return only the summary.

        <user_input>
        \(context.prefix(4000))
        </user_input>
        """
        do {
            return try await generate(prompt: prompt)
        } catch {
            logger.error("FoundationModelsService.summarizeContext failed: \(error.localizedDescription)")
            return context
        }
    }

    /// Classify the intent of a user query into a concise label.
    /// - Parameter query: The user's raw query string.
    /// - Returns: A short intent label (e.g. "code", "question", "planning", "health"), or "general".
    public func classifyIntent(_ query: String) async -> String {
        guard isAvailable, !query.isEmpty else { return "general" }

        // ABB3: Wrap user input in delimiters to prevent prompt injection
        let prompt = """
        Classify the intent of this query with a single lowercase word from this list:
        code, question, planning, health, finance, creative, search, general.
        Return only the single word, no punctuation.

        <user_input>\(query.prefix(500))</user_input>
        """
        do {
            let raw = try await generate(prompt: prompt)
            return raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        } catch {
            logger.error("FoundationModelsService.classifyIntent failed: \(error.localizedDescription)")
            return "general"
        }
    }

    /// Generate a short, descriptive title for a conversation given its messages.
    /// - Parameter messages: Conversation messages joined as a single string.
    /// - Returns: A 3–7 word title, or "New Conversation" as fallback.
    public func generateConversationTitle(from messages: String) async -> String {
        guard isAvailable, !messages.isEmpty else { return "New Conversation" }

        // ABB3: Wrap user content in delimiters to prevent prompt injection
        let prompt = """
        Generate a concise 3–7 word title for this conversation. Return only the title, no quotes.

        <user_input>
        \(messages.prefix(2000))
        </user_input>
        """
        do {
            return try await generate(prompt: prompt)
        } catch {
            logger.error("FoundationModelsService.generateConversationTitle failed: \(error.localizedDescription)")
            return "New Conversation"
        }
    }

    /// Expand a short search query into semantically richer terms for embedding search.
    /// - Parameter query: Short query (e.g. "apple stock").
    /// - Returns: Expanded query (e.g. "Apple Inc AAPL stock price investment market"), or original.
    public func expandQuery(_ query: String) async -> String {
        guard isAvailable, !query.isEmpty else { return query }

        // ABB3: Wrap user input in delimiters to prevent prompt injection
        let prompt = """
        Expand this search query with semantically related terms (≤20 words total). Return only the expanded query.

        <user_input>\(query.prefix(200))</user_input>
        """
        do {
            return try await generate(prompt: prompt)
        } catch {
            logger.error("FoundationModelsService.expandQuery failed: \(error.localizedDescription)")
            return query
        }
    }

    // MARK: - Shared Generation Engine

    private func generate(prompt: String) async throws -> String {
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }

        #if canImport(FoundationModels)
            let activeSession = session ?? LanguageModelSession()
            do {
                let response = try await activeSession.respond(to: prompt)
                return response.content
            } catch {
                lastError = error.localizedDescription
                throw error
            }
        #else
            throw FoundationModelsServiceError.unavailable
        #endif
    }
}

// MARK: - Error

public enum FoundationModelsServiceError: LocalizedError {
    case unavailable
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "FoundationModels is not available. Requires macOS 26+ / iOS 26+ with Apple Intelligence enabled."
        case .generationFailed(let msg):
            return "On-device generation failed: \(msg)"
        }
    }
}
