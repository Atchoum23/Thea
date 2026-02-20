// ResilienceManager.swift
// Comprehensive resilience system with circuit breakers, fallbacks, and retry logic
import Foundation
import OSLog

/// Manages resilience patterns for AI provider calls:
/// - Circuit breaker to prevent cascading failures
/// - Exponential backoff with jitter for retries
/// - Provider fallback chains
/// - Health monitoring and adaptive thresholds
///
/// Based on 2025-2026 best practices from Azure, Portkey, and LangChain patterns.
@MainActor
@Observable
public final class ResilienceManager {
    public static let shared = ResilienceManager()

    private let logger = Logger(subsystem: "com.thea.metaai", category: "ResilienceManager")

    /// Circuit breaker states for each provider
    private var circuitBreakers: [String: CircuitBreaker] = [:]

    /// Provider health scores (0.0 = unhealthy, 1.0 = healthy)
    private var providerHealth: [String: ProviderHealthScore] = [:]

    /// Configuration
    public var config = ResilienceConfig()

    /// Statistics for monitoring
    public private(set) var stats = ResilienceStats()

    private init() {}

    // MARK: - Resilient Execution

    /// Execute a chat request with full resilience: circuit breaker, retries, fallbacks
    func executeChat(
        messages: [AIMessage],
        model: String,
        primaryProvider: String,
        fallbackProviders: [String] = [],
        stream: Bool = false
    ) async throws -> String {
        let allProviders = [primaryProvider] + fallbackProviders

        var lastError: Error?

        for providerId in allProviders {
            // Check circuit breaker
            let breaker = getCircuitBreaker(for: providerId)

            guard breaker.allowsRequest() else {
                logger.info("Circuit breaker OPEN for \(providerId), skipping")
                stats.circuitBreakerTrips += 1
                continue
            }

            do {
                let result = try await executeChatWithRetry(
                    messages: messages,
                    model: model,
                    providerId: providerId,
                    stream: stream
                )

                // Success - record it
                breaker.recordSuccess()
                updateProviderHealth(providerId, success: true)
                stats.successfulRequests += 1

                return result

            } catch {
                lastError = error
                logger.warning("Provider \(providerId) failed: \(error.localizedDescription)")

                // Record failure
                breaker.recordFailure()
                updateProviderHealth(providerId, success: false)
                stats.failedRequests += 1

                // Continue to next provider in fallback chain
            }
        }

        // All providers failed
        stats.totalFallbackExhausted += 1
        throw ResilienceError.allProvidersFailed(lastError: lastError)
    }

    // MARK: - Retry Logic

    private func executeChatWithRetry(
        messages: [AIMessage],
        model: String,
        providerId: String,
        stream: Bool
    ) async throws -> String {
        guard let provider = ProviderRegistry.shared.getProvider(id: providerId) else {
            throw ResilienceError.providerNotAvailable(providerId)
        }

        var lastError: Error?
        var attempt = 0

        while attempt <= config.maxRetries {
            do {
                if attempt > 0 {
                    // Apply backoff delay
                    let delay = calculateBackoffDelay(attempt: attempt)
                    logger.info("Retry \(attempt) for \(providerId) after \(delay)s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                // Execute the chat request with timeout (V2 API)
                var response = ""
                let chatStream = try await provider.chat(messages: messages, model: model, stream: stream)
                for try await chunk in chatStream {
                    switch chunk.type {
                    case let .delta(text):
                        response += text
                    case .complete:
                        break
                    case let .error(error):
                        throw error
                    }
                }

                return response

            } catch {
                lastError = error
                attempt += 1

                // Check if error is retryable
                if !isRetryableError(error) {
                    logger.info("Non-retryable error for \(providerId): \(error.localizedDescription)")
                    throw error
                }

                stats.retryAttempts += 1
            }
        }

        throw lastError ?? ResilienceError.maxRetriesExceeded
    }

    /// Calculate exponential backoff with jitter
    private func calculateBackoffDelay(attempt: Int) -> Double {
        let baseDelay = config.baseRetryDelay
        let maxDelay = config.maxRetryDelay

        // Exponential: 1s, 2s, 4s, 8s...
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))

        // Cap at max
        let cappedDelay = min(exponentialDelay, maxDelay)

        // Add jitter (±25%) to prevent thundering herd
        let jitter = cappedDelay * 0.25 * Double.random(in: -1...1)

        return cappedDelay + jitter
    }

    // MARK: - Circuit Breaker

    private func getCircuitBreaker(for providerId: String) -> CircuitBreaker {
        if let existing = circuitBreakers[providerId] {
            return existing
        }

        let breaker = CircuitBreaker(
            name: providerId,
            failureThreshold: config.circuitBreakerFailureThreshold,
            resetTimeout: config.circuitBreakerResetTimeout,
            halfOpenMaxRequests: config.circuitBreakerHalfOpenRequests
        )
        circuitBreakers[providerId] = breaker
        return breaker
    }

    // MARK: - Health Tracking

    private func updateProviderHealth(_ providerId: String, success: Bool) {
        var health = providerHealth[providerId] ?? ProviderHealthScore(providerId: providerId)

        health.recordResult(success: success)
        providerHealth[providerId] = health
    }

    /// Get health score for a provider (0.0 - 1.0)
    public func getHealthScore(for providerId: String) -> Double {
        providerHealth[providerId]?.score ?? 1.0
    }

    /// Get all provider health scores
    public func getAllHealthScores() -> [String: Double] {
        var scores: [String: Double] = [:]
        for (id, health) in providerHealth {
            scores[id] = health.score
        }
        return scores
    }

    /// Get providers sorted by health (healthiest first)
    public func getProvidersByHealth() -> [String] {
        providerHealth
            .sorted { $0.value.score > $1.value.score }
            .map(\.key)
    }

    // MARK: - Error Classification

    private func isRetryableError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()

        // Retryable errors
        let retryablePatterns = [
            "timeout",
            "network",
            "rate limit",
            "temporarily unavailable",
            "503",
            "502",
            "504",
            "connection",
            "timed out",
            "overloaded"
        ]

        for pattern in retryablePatterns {
            if errorString.contains(pattern) {
                return true
            }
        }

        // Non-retryable: client errors (400s except rate limits)
        let nonRetryablePatterns = [
            "invalid api key",
            "unauthorized",
            "forbidden",
            "invalid request",
            "400",
            "401",
            "403",
            "404"
        ]

        for pattern in nonRetryablePatterns {
            if errorString.contains(pattern) {
                return false
            }
        }

        // Default: retry unknown errors once
        return true
    }

    // MARK: - Fallback Chain Builder

    /// Build an optimal fallback chain based on health and configuration
    public func buildFallbackChain(
        for taskType: TaskType,
        preference: OrchestratorConfiguration.LocalModelPreference
    ) -> [String] {
        var chain: [String] = []

        // Get available providers
        let registry = ProviderRegistry.shared

        // Get local models from providers that are local (MLX, Ollama, etc.)
        let localProviders = registry.configuredProviders.filter {
            $0.metadata.name.lowercased().contains("local") ||
            $0.metadata.name.lowercased().contains("mlx") ||
            $0.metadata.name.lowercased().contains("ollama")
        }
        let localModels = localProviders.map { "local:\($0.metadata.name)" }

        // Based on preference, order providers
        switch preference {
        case .always:
            // Only local models
            chain = localModels

        case .prefer:
            // Local first, then cloud by health
            chain = localModels
            chain += getCloudProvidersByHealth()

        case .balanced:
            // Mix based on task type
            if taskType.isSimple {
                // Simple tasks: local first
                chain = localModels
                chain += getCloudProvidersByHealth()
            } else {
                // Complex tasks: cloud first
                chain = getCloudProvidersByHealth()
                chain += localModels
            }

        case .cloudFirst:
            // Cloud first, local as fallback
            chain = getCloudProvidersByHealth()
            chain += localModels
        }

        // Filter out providers with open circuit breakers
        chain = chain.filter { providerId in
            getCircuitBreaker(for: providerId).allowsRequest()
        }

        logger.info("Built fallback chain: \(chain.joined(separator: " → "))")
        return chain
    }

    private func getCloudProvidersByHealth() -> [String] {
        let cloudProviders = ["openrouter", "openai", "anthropic", "google", "groq", "perplexity"]

        // Filter to configured providers and sort by health
        return cloudProviders
            .filter { ProviderRegistry.shared.getProvider(id: $0) != nil }
            .sorted { getHealthScore(for: $0) > getHealthScore(for: $1) }
    }

    // MARK: - Reset

    /// Reset circuit breakers (e.g., after configuration change)
    public func resetCircuitBreakers() {
        circuitBreakers.removeAll()
        logger.info("All circuit breakers reset")
    }

    /// Reset all health scores
    public func resetHealthScores() {
        providerHealth.removeAll()
        logger.info("All health scores reset")
    }

    /// Reset statistics
    public func resetStats() {
        stats = ResilienceStats()
    }
}

// MARK: - Circuit Breaker Implementation

/// Circuit breaker with three states: Closed, Open, Half-Open
final class CircuitBreaker: @unchecked Sendable {
    enum State {
        case closed      // Normal operation
        case open        // Blocking requests
        case halfOpen    // Testing recovery
    }

    let name: String
    private(set) var state: State = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?
    private var halfOpenRequestCount: Int = 0

    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    private let halfOpenMaxRequests: Int

    private let lock = NSLock()

    init(
        name: String,
        failureThreshold: Int,
        resetTimeout: TimeInterval,
        halfOpenMaxRequests: Int
    ) {
        self.name = name
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
        self.halfOpenMaxRequests = halfOpenMaxRequests
    }

    func allowsRequest() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        switch state {
        case .closed:
            return true

        case .open:
            // Check if reset timeout has passed
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) >= resetTimeout
            {
                state = .halfOpen
                halfOpenRequestCount = 0
                return true
            }
            return false

        case .halfOpen:
            // Allow limited requests in half-open state
            if halfOpenRequestCount < halfOpenMaxRequests {
                halfOpenRequestCount += 1
                return true
            }
            return false
        }
    }

    func recordSuccess() {
        lock.lock()
        defer { lock.unlock() }

        successCount += 1

        switch state {
        case .closed:
            // Reset failure count on success
            failureCount = 0

        case .halfOpen:
            // If enough successes in half-open, close the circuit
            if successCount >= halfOpenMaxRequests {
                state = .closed
                failureCount = 0
                successCount = 0
            }

        case .open:
            break
        }
    }

    func recordFailure() {
        lock.lock()
        defer { lock.unlock() }

        failureCount += 1
        lastFailureTime = Date()

        switch state {
        case .closed:
            // Check if we should open the circuit
            if failureCount >= failureThreshold {
                state = .open
            }

        case .halfOpen:
            // Any failure in half-open state reopens the circuit
            state = .open
            successCount = 0

        case .open:
            break
        }
    }
}

// MARK: - Provider Health Score

struct ProviderHealthScore {
    let providerId: String
    private var recentResults: [Bool] = []
    private let windowSize: Int = 20

    var score: Double {
        guard !recentResults.isEmpty else { return 1.0 }
        let successes = recentResults.filter { $0 }.count
        return Double(successes) / Double(recentResults.count)
    }

    mutating func recordResult(success: Bool) {
        recentResults.append(success)
        if recentResults.count > windowSize {
            recentResults.removeFirst()
        }
    }

    init(providerId: String) {
        self.providerId = providerId
    }
}

// MARK: - Configuration

/// Configuration for resilience behavior
public struct ResilienceConfig: Sendable {
    /// Maximum number of retries per provider
    public var maxRetries: Int = 3

    /// Base delay for exponential backoff (seconds)
    public var baseRetryDelay: Double = 1.0

    /// Maximum retry delay (seconds)
    public var maxRetryDelay: Double = 30.0

    /// Request timeout (seconds)
    public var requestTimeout: TimeInterval = 60.0

    /// Number of failures before circuit opens
    public var circuitBreakerFailureThreshold: Int = 5

    /// Time before circuit breaker resets (seconds)
    public var circuitBreakerResetTimeout: TimeInterval = 60.0

    /// Number of test requests in half-open state
    public var circuitBreakerHalfOpenRequests: Int = 3

    public init() {}
}

// MARK: - Statistics

/// Statistics for monitoring resilience behavior
public struct ResilienceStats: Sendable {
    public var successfulRequests: Int = 0
    public var failedRequests: Int = 0
    public var retryAttempts: Int = 0
    public var circuitBreakerTrips: Int = 0
    public var totalFallbackExhausted: Int = 0

    public var successRate: Double {
        let total = successfulRequests + failedRequests
        guard total > 0 else { return 1.0 }
        return Double(successfulRequests) / Double(total)
    }
}

// MARK: - Errors

public enum ResilienceError: LocalizedError {
    case providerNotAvailable(String)
    case timeout
    case maxRetriesExceeded
    case allProvidersFailed(lastError: Error?)
    case circuitBreakerOpen(String)

    public var errorDescription: String? {
        switch self {
        case let .providerNotAvailable(id):
            "Provider not available: \(id)"
        case .timeout:
            "Request timed out"
        case .maxRetriesExceeded:
            "Maximum retry attempts exceeded"
        case let .allProvidersFailed(lastError):
            "All providers failed. Last error: \(lastError?.localizedDescription ?? "unknown")"
        case let .circuitBreakerOpen(id):
            "Circuit breaker open for provider: \(id)"
        }
    }
}

// MARK: - TaskType Extension
// Note: isSimple is defined in TaskType.swift
