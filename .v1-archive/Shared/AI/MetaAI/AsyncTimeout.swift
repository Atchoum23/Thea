// AsyncTimeout.swift
// Comprehensive timeout utilities for async operations
// Based on 2025-2026 best practices for AI agent reliability

import Foundation
import OSLog

/// Errors related to async timeout operations
public enum TimeoutError: LocalizedError, Sendable {
    case timeout(duration: TimeInterval, operation: String)
    case cancelled
    case executionFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case let .timeout(duration, operation):
            "Operation '\(operation)' timed out after \(String(format: "%.1f", duration)) seconds"
        case .cancelled:
            "Operation was cancelled"
        case let .executionFailed(underlying):
            "Execution failed: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Timeout Execution

/// Execute an async operation with a timeout
/// Based on 2025 best practices: "Timeouts prevent your system from hanging indefinitely"
public func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: String = "async operation",
    execute: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual operation
        group.addTask {
            try await execute()
        }

        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError.timeout(duration: seconds, operation: operation)
        }

        // Wait for first completion
        guard let result = try await group.next() else {
            throw TimeoutError.timeout(duration: seconds, operation: operation)
        }

        // Cancel the other task
        group.cancelAll()

        return result
    }
}

/// Execute an async operation with timeout and cancellation support
public func withTimeoutCancellable<T: Sendable>(
    seconds: TimeInterval,
    operation: String = "async operation",
    execute: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withTaskCancellationHandler {
        try await withTimeout(seconds: seconds, operation: operation, execute: execute)
    } onCancel: {
        // Cancellation requested - the task group will handle it
    }
}

// MARK: - Retry with Timeout

/// Configuration for retry operations
public struct RetryConfig: Sendable {
    /// Maximum number of retry attempts
    public var maxRetries: Int

    /// Base delay between retries (exponential backoff applied)
    public var baseDelay: TimeInterval

    /// Maximum delay between retries
    public var maxDelay: TimeInterval

    /// Timeout for each individual attempt
    public var attemptTimeout: TimeInterval

    /// Whether to add jitter to delays (prevents thundering herd)
    public var useJitter: Bool

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        attemptTimeout: TimeInterval = 60.0,
        useJitter: Bool = true
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.attemptTimeout = attemptTimeout
        self.useJitter = useJitter
    }

    public static let `default` = RetryConfig()

    public static let aggressive = RetryConfig(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 15.0,
        attemptTimeout: 30.0
    )

    public static let conservative = RetryConfig(
        maxRetries: 2,
        baseDelay: 2.0,
        maxDelay: 60.0,
        attemptTimeout: 120.0
    )
}

/// Execute an async operation with retry logic and timeout
/// Based on: "Exponential backoff with jitter intelligently increases delay between retries"
public func withRetry<T: Sendable>(
    config: RetryConfig = .default,
    operation: String = "async operation",
    shouldRetry: @escaping @Sendable (Error) -> Bool = { _ in true },
    execute: @escaping @Sendable () async throws -> T
) async throws -> T {
    let logger = Logger(subsystem: "com.thea.async", category: "Retry")
    var lastError: Error?
    var attempt = 0

    while attempt <= config.maxRetries {
        do {
            // Execute with timeout
            let result = try await withTimeout(
                seconds: config.attemptTimeout,
                operation: "\(operation) (attempt \(attempt + 1))"
            ) {
                try await execute()
            }
            return result

        } catch {
            lastError = error
            attempt += 1

            // Check if we should retry
            guard attempt <= config.maxRetries, shouldRetry(error) else {
                logger.warning("Operation '\(operation)' failed after \(attempt) attempts: \(error.localizedDescription)")
                throw error
            }

            // Calculate delay with exponential backoff
            let exponentialDelay = config.baseDelay * pow(2.0, Double(attempt - 1))
            var delay = min(exponentialDelay, config.maxDelay)

            // Add jitter (±25%) to prevent thundering herd
            if config.useJitter {
                let jitter = delay * 0.25 * Double.random(in: -1...1)
                delay += jitter
            }

            logger.info("Retrying '\(operation)' in \(String(format: "%.2f", delay))s (attempt \(attempt + 1)/\(config.maxRetries + 1))")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    throw lastError ?? TimeoutError.executionFailed(underlying: NSError(domain: "RetryExhausted", code: -1))
}

// MARK: - Parallel Execution with Timeout

/// Result of a parallel execution attempt
public struct ParallelResult<T: Sendable>: Sendable {
    public let index: Int
    public let result: Result<T, Error>

    public var value: T? {
        if case let .success(v) = result { return v }
        return nil
    }

    public var error: Error? {
        if case let .failure(e) = result { return e }
        return nil
    }

    public var isSuccess: Bool {
        if case .success = result { return true }
        return false
    }
}

/// Execute multiple operations in parallel with timeout and error tolerance
/// Based on: "Serve stale data rather than no data" - partial results are valuable
public func withParallelTimeout<T: Sendable>(
    operations: [@Sendable () async throws -> T],
    timeout: TimeInterval,
    continueOnError: Bool = true
) async throws -> [ParallelResult<T>] {
    guard !operations.isEmpty else { return [] }

    return try await withThrowingTaskGroup(of: (Int, Result<T, Error>).self) { group in
        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError.timeout(duration: timeout, operation: "parallel execution")
        }

        // Add all operations
        for (index, operation) in operations.enumerated() {
            group.addTask {
                do {
                    let result = try await operation()
                    return (index, .success(result))
                } catch {
                    return (index, .failure(error))
                }
            }
        }

        var results: [ParallelResult<T>] = []
        var completedCount = 0
        let targetCount = operations.count

        // Collect results until all complete or timeout
        while completedCount < targetCount {
            do {
                guard let (index, result) = try await group.next() else { break }

                // Check if this is a real result (not timeout marker)
                if index >= 0 && index < targetCount {
                    results.append(ParallelResult(index: index, result: result))
                    completedCount += 1

                    // If not continuing on error and we got a failure, throw
                    if !continueOnError, case let .failure(error) = result {
                        group.cancelAll()
                        throw error
                    }
                }
            } catch is TimeoutError {
                // Timeout reached - return what we have
                break
            } catch {
                if !continueOnError {
                    group.cancelAll()
                    throw error
                }
            }
        }

        group.cancelAll()

        // Sort by index to maintain order
        return results.sorted { $0.index < $1.index }
    }
}

// MARK: - Stream with Timeout

/// Collect stream results with timeout
public func collectStreamWithTimeout<Element: Sendable>(
    stream: AsyncThrowingStream<Element, Error>,
    timeout: TimeInterval,
    maxElements: Int = Int.max
) async throws -> [Element] {
    try await withTimeout(seconds: timeout, operation: "stream collection") {
        var elements: [Element] = []
        for try await element in stream {
            elements.append(element)
            if elements.count >= maxElements {
                break
            }
        }
        return elements
    }
}

/// Process stream with timeout, accumulating results
public func processStreamWithTimeout<Element: Sendable, Result: Sendable>(
    stream: AsyncThrowingStream<Element, Error>,
    timeout: TimeInterval,
    initial: Result,
    accumulator: @escaping @Sendable (Result, Element) -> Result
) async throws -> Result {
    try await withTimeout(seconds: timeout, operation: "stream processing") {
        var result = initial
        for try await element in stream {
            result = accumulator(result, element)
        }
        return result
    }
}

// MARK: - Deadline-based Execution

/// Execute operations within a deadline - MainActor-isolated version for UI code
@MainActor
public final class DeadlineExecutor {
    private let deadline: Date
    private var cancelled = false

    public init(deadline: Date) {
        self.deadline = deadline
    }

    public init(timeout: TimeInterval) {
        self.deadline = Date().addingTimeInterval(timeout)
    }

    public var remainingTime: TimeInterval {
        max(0, deadline.timeIntervalSinceNow)
    }

    public var isExpired: Bool {
        Date() >= deadline
    }

    public func cancel() {
        cancelled = true
    }

    public var isCancelled: Bool {
        cancelled
    }

    /// Check if deadline is still valid, throw if expired
    public func checkDeadline() throws {
        guard !cancelled else {
            throw TimeoutError.cancelled
        }
        guard remainingTime > 0 else {
            throw TimeoutError.timeout(duration: 0, operation: "deadline exceeded")
        }
    }
}

/// Execute operations within a deadline - Actor-isolated version for concurrent code
public actor DeadlineExecutorActor {
    private let deadline: Date
    private var cancelled = false

    public init(deadline: Date) {
        self.deadline = deadline
    }

    public init(timeout: TimeInterval) {
        self.deadline = Date().addingTimeInterval(timeout)
    }

    public var remainingTime: TimeInterval {
        max(0, deadline.timeIntervalSinceNow)
    }

    public var isExpired: Bool {
        Date() >= deadline
    }

    public func cancel() {
        cancelled = true
    }

    public var isCancelled: Bool {
        cancelled
    }

    /// Execute if deadline not exceeded
    public func execute<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        guard !cancelled else {
            throw TimeoutError.cancelled
        }

        let remaining = remainingTime
        guard remaining > 0 else {
            throw TimeoutError.timeout(duration: 0, operation: "deadline exceeded")
        }

        return try await withTimeout(seconds: remaining, operation: "deadline execution") {
            try await operation()
        }
    }
}

// MARK: - Rate Limiting

/// Actor-based rate limiter for async operations
public actor AsyncRateLimiter {
    private let maxRequests: Int
    private let windowSeconds: TimeInterval
    private var requestTimes: [Date] = []

    public init(maxRequests: Int, perSeconds windowSeconds: TimeInterval) {
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }

    /// Wait if necessary and execute
    public func execute<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        // Clean old requests
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        requestTimes = requestTimes.filter { $0 > cutoff }

        // Wait if at limit
        if requestTimes.count >= maxRequests {
            if let oldest = requestTimes.first {
                let waitTime = oldest.addingTimeInterval(windowSeconds).timeIntervalSinceNow
                if waitTime > 0 {
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }

        // Record this request
        requestTimes.append(Date())

        return try await operation()
    }
}
