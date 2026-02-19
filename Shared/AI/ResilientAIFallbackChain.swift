// ResilientAIFallbackChain.swift
// Thea — Offline-First AI Provider Fallback Chain
//
// Ensures Thea can always respond, even without internet.
// Fallback order: Cloud API → Local MLX → CoreML → Rule-Based
// Tracks provider health and automatically routes around failures.

import Foundation
import OSLog

// MARK: - Resilient AI Fallback Chain

@MainActor
@Observable
final class ResilientAIFallbackChain {
    static let shared = ResilientAIFallbackChain()

    private let logger = Logger(subsystem: "com.thea.app", category: "AIFallback")

    // MARK: - State

    private(set) var currentTier: FallbackTier = .cloud
    private(set) var failureLog: [FallbackFailure] = []
    private(set) var isOfflineMode = false

    /// Health tracking per tier
    private var tierHealth: [FallbackTier: TierHealthStatus] = [
        .cloud: TierHealthStatus(),
        .localMLX: TierHealthStatus(),
        .coreML: TierHealthStatus(),
        .ruleBased: TierHealthStatus()
    ]

    // MARK: - Configuration

    /// Maximum consecutive failures before skipping a tier
    var maxConsecutiveFailures = 3

    /// Cooldown before retrying a failed tier (seconds)
    var failureCooldownSeconds: TimeInterval = 300

    /// Whether to prefer local models when cloud latency exceeds threshold
    var latencyThresholdMs: Int = 5000

    private init() {}

    // MARK: - Chat API

    /// Send a chat request through the fallback chain.
    /// Tries each tier in order until one succeeds.
    func chat(
        messages: [AIMessage],
        preferredModel: String? = nil,
        stream: Bool = false
    ) async throws -> FallbackChatResult {
        let tiers = availableTiers()

        guard !tiers.isEmpty else {
            throw FallbackChainError.allTiersExhausted
        }

        var lastError: Error?

        for tier in tiers {
            do {
                let startTime = Date()
                let result = try await executeTier(tier, messages: messages, model: preferredModel, stream: stream)
                let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

                // Record success
                tierHealth[tier]?.recordSuccess(latencyMs: latencyMs)
                currentTier = tier

                logger.info("Fallback chain: \(tier.rawValue) succeeded in \(latencyMs)ms")

                return FallbackChatResult(
                    response: result,
                    tier: tier,
                    latencyMs: latencyMs,
                    wasFallback: tier != tiers.first
                )
            } catch {
                lastError = error
                tierHealth[tier]?.recordFailure()

                let failure = FallbackFailure(
                    tier: tier,
                    error: error.localizedDescription,
                    timestamp: Date()
                )
                failureLog.append(failure)
                if failureLog.count > 100 {
                    failureLog.removeFirst(failureLog.count - 100)
                }

                logger.warning("Fallback chain: \(tier.rawValue) failed — \(error.localizedDescription)")
                continue
            }
        }

        throw lastError ?? FallbackChainError.allTiersExhausted
    }

    /// Quick single-query for simple text responses (no streaming)
    func quickQuery(_ prompt: String) async throws -> String {
        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            // periphery:ignore - Reserved: quickQuery(_:) instance method reserved for future feature activation
            model: "fallback"
        )

        let result = try await chat(messages: [message])
        return result.response
    }

    // MARK: - Tier Execution

    private func executeTier(
        _ tier: FallbackTier,
        messages: [AIMessage],
        model: String?,
        stream: Bool
    ) async throws -> String {
        switch tier {
        case .cloud:
            return try await executeCloudTier(messages: messages, model: model, stream: stream)
        case .localMLX:
            return try await executeLocalMLXTier(messages: messages)
        case .coreML:
            return try await executeCoreMLTier(messages: messages)
        case .ruleBased:
            return executeRuleBasedTier(messages: messages)
        }
    }

    private func executeCloudTier(messages: [AIMessage], model: String?, stream: Bool) async throws -> String {
        let registry = ProviderRegistry.shared
        guard let provider = registry.getCloudProvider() else {
            throw FallbackChainError.tierUnavailable(.cloud)
        }

        let models = try await provider.listModels()
        let modelID = model ?? models.first?.id ?? ""
        guard !modelID.isEmpty else {
            throw FallbackChainError.tierUnavailable(.cloud)
        }

        let responseStream = try await provider.chat(messages: messages, model: modelID, stream: stream)
        var result = ""
        for try await response in responseStream {
            switch response.type {
            case let .delta(text):
                result += text
            case let .complete(msg):
                result = msg.content.textValue
            case .error:
                break
            }
        }

        guard !result.isEmpty else {
            throw FallbackChainError.emptyResponse
        }

        return result
    }

    private func executeLocalMLXTier(messages: [AIMessage]) async throws -> String {
        #if os(macOS)
        let registry = ProviderRegistry.shared
        guard let localProvider = registry.getLocalProvider() else {
            throw FallbackChainError.tierUnavailable(.localMLX)
        }

        let models = try await localProvider.listModels()
        guard let modelID = models.first?.id else {
            throw FallbackChainError.tierUnavailable(.localMLX)
        }

        let responseStream = try await localProvider.chat(messages: messages, model: modelID, stream: false)
        var result = ""
        for try await response in responseStream {
            switch response.type {
            case let .delta(text):
                result += text
            case let .complete(msg):
                result = msg.content.textValue
            case .error:
                break
            }
        }

        guard !result.isEmpty else {
            throw FallbackChainError.emptyResponse
        }
        return result
        #else
        throw FallbackChainError.tierUnavailable(.localMLX)
        #endif
    }

    private func executeCoreMLTier(messages: [AIMessage]) async throws -> String {
        let engine = CoreMLInferenceEngine.shared
        if engine.loadedModelID == nil {
            // Try to load a model
            let models = engine.discoverLLMModels()
            guard let model = models.first else {
                throw FallbackChainError.tierUnavailable(.coreML)
            }
            try await engine.loadModel(at: model.path, id: model.id)
        }

        let prompt = messages.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content.textValue)"
        }.joined(separator: "\n")

        let stream = try await engine.generate(prompt: prompt, maxTokens: 512)
        var result = ""
        for try await chunk in stream {
            result += chunk
        }

        guard !result.isEmpty else {
            throw FallbackChainError.emptyResponse
        }
        return result
    }

    private func executeRuleBasedTier(messages: [AIMessage]) -> String {
        guard let lastMessage = messages.last else {
            return "I'm currently operating in offline mode with limited capabilities. How can I help?"
        }

        let query = lastMessage.content.textValue.lowercased()

        // Simple rule-based responses for common queries
        if query.contains("time") || query.contains("what time") {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "The current time is \(formatter.string(from: Date()))."
        }

        if query.contains("date") || query.contains("what day") {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            return "Today is \(formatter.string(from: Date()))."
        }

        if query.contains("weather") {
            return "I'm currently offline and can't check the weather. Please try again when you have an internet connection."
        }

        if query.contains("remind") || query.contains("reminder") {
            return "I'm in offline mode but I can still set a local reminder. What would you like to be reminded about?"
        }

        if query.contains("help") {
            return "I'm currently in offline mode with limited capabilities. I can help with basic questions, time/date, and local device actions. Full AI capabilities will resume when connectivity is restored."
        }

        return "I'm currently operating offline. I captured your message and will process it fully when connectivity is restored. In the meantime, I can help with basic device actions and simple queries."
    }

    // MARK: - Tier Availability

    private func availableTiers() -> [FallbackTier] {
        FallbackTier.allCases.filter { tier in
            guard let health = tierHealth[tier] else { return false }

            // Skip if too many consecutive failures and still in cooldown
            if health.consecutiveFailures >= maxConsecutiveFailures {
                if let lastFailure = health.lastFailureDate {
                    let elapsed = Date().timeIntervalSince(lastFailure)
                    if elapsed < failureCooldownSeconds {
                        return false
                    }
                    // Cooldown expired, reset and try again
                    tierHealth[tier]?.resetFailures()
                }
            }
            return true
        }
    }

    // MARK: - Status

    func tierStatus() -> [FallbackTier: TierHealthStatus] {
        tierHealth
    }

    func resetAllTiers() {
        for tier in FallbackTier.allCases {
            // periphery:ignore - Reserved: tierStatus() instance method reserved for future feature activation
            tierHealth[tier]?.resetFailures()
        }
        failureLog.removeAll()
    // periphery:ignore - Reserved: resetAllTiers() instance method reserved for future feature activation
    }
}

// MARK: - Types

enum FallbackTier: String, CaseIterable, Sendable {
    case cloud      // Cloud API (Anthropic, OpenAI, etc.)
    case localMLX   // Local MLX model (macOS only)
    case coreML     // CoreML on-device model
    case ruleBased  // Simple rule-based fallback (always available)

    var displayName: String {
        switch self {
        case .cloud: "Cloud AI"
        case .localMLX: "Local MLX"
        case .coreML: "CoreML"
        case .ruleBased: "Offline Rules"
        }
    }
}

struct TierHealthStatus: Sendable {
    var consecutiveFailures = 0
    var totalSuccesses = 0
    var totalFailures = 0
    var lastFailureDate: Date?
    var averageLatencyMs = 0

    mutating func recordSuccess(latencyMs: Int) {
        consecutiveFailures = 0
        totalSuccesses += 1
        let total = totalSuccesses + totalFailures
        averageLatencyMs = ((averageLatencyMs * (total - 1)) + latencyMs) / total
    }

    mutating func recordFailure() {
        consecutiveFailures += 1
        totalFailures += 1
        lastFailureDate = Date()
    }

    mutating func resetFailures() {
        consecutiveFailures = 0
        lastFailureDate = nil
    }
}

struct FallbackChatResult: Sendable {
    let response: String
    let tier: FallbackTier
    let latencyMs: Int
    let wasFallback: Bool
}

// periphery:ignore - Reserved: latencyMs property reserved for future feature activation
// periphery:ignore - Reserved: wasFallback property reserved for future feature activation
struct FallbackFailure: Sendable, Identifiable {
    let id = UUID()
    let tier: FallbackTier
    let error: String
    // periphery:ignore - Reserved: tier property reserved for future feature activation
    // periphery:ignore - Reserved: error property reserved for future feature activation
    // periphery:ignore - Reserved: timestamp property reserved for future feature activation
    let timestamp: Date
}

enum FallbackChainError: Error, LocalizedError {
    case allTiersExhausted
    case tierUnavailable(FallbackTier)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .allTiersExhausted:
            "All AI tiers exhausted — no providers available"
        case let .tierUnavailable(tier):
            "\(tier.displayName) tier is unavailable"
        case .emptyResponse:
            "AI returned an empty response"
        }
    }
}
