// NetworkManagerTypesTests.swift
// Tests for NetworkManager value types: ConnectionType, CachePolicy,
// NetworkRetryPolicy, NetworkConfiguration, RequestRecord, WebSocketMessage,
// NetworkError, and rate limiter logic.

import Foundation
import XCTest

// MARK: - Mirrored: ConnectionType

private enum TestConnectionType: String, CaseIterable {
    case wifi, cellular, ethernet, unknown
}

// MARK: - Mirrored: CachePolicy

private enum TestCachePolicy: CaseIterable {
    case `default`, noCache, cacheResponse, cacheOnly
}

// MARK: - Mirrored: NetworkRetryPolicy

private struct TestRetryPolicy {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    let retryableCodes: Set<Int>

    static let `default` = TestRetryPolicy(
        maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0,
        multiplier: 2.0, retryableCodes: [408, 429, 500, 502, 503, 504]
    )

    static let none = TestRetryPolicy(
        maxRetries: 0, baseDelay: 0, maxDelay: 0,
        multiplier: 0, retryableCodes: []
    )

    func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(multiplier, Double(attempt - 1))
        return min(delay, maxDelay)
    }
}

// MARK: - Mirrored: NetworkConfiguration

private struct TestNetworkConfig {
    var timeout: TimeInterval?
    var cacheEnabled: Bool = true
    var maxConcurrentRequests: Int = 10
}

// MARK: - Mirrored: RequestRecord

private struct TestRequestRecord: Identifiable {
    let id = UUID()
    let url: String
    let method: String
    let statusCode: Int
    let responseSize: Int
    let timestamp: Date
}

// MARK: - Mirrored: NetworkError

private enum TestNetworkError: Error {
    case noConnection
    case timeout
    case invalidResponse
    case httpError(Int, Data?)
    case decodingError(Error)
    case unknown

    var errorDescription: String {
        switch self {
        case .noConnection: "No network connection"
        case .timeout: "Request timed out"
        case .invalidResponse: "Invalid response"
        case let .httpError(code, _): "HTTP error: \(code)"
        case let .decodingError(error): "Decoding error: \(error.localizedDescription)"
        case .unknown: "Unknown error"
        }
    }
}

// MARK: - Mirrored: Rate Limiter

private class TestRateLimiter {
    let requestsPerSecond: Double
    var tokens: Double
    var lastRefill: Date

    init(requestsPerSecond: Double) {
        self.requestsPerSecond = requestsPerSecond
        self.tokens = requestsPerSecond
        self.lastRefill = Date()
    }

    func shouldAllow() -> Bool {
        refill()
        if tokens >= 1.0 {
            tokens -= 1.0
            return true
        }
        return false
    }

    private func refill() {
        let elapsed = Date().timeIntervalSince(lastRefill)
        tokens = min(tokens + elapsed * requestsPerSecond, requestsPerSecond)
        lastRefill = Date()
    }
}

// MARK: - Tests

final class NetworkManagerTypesTests: XCTestCase {

    // MARK: - ConnectionType Tests

    func testAllConnectionTypes() {
        XCTAssertEqual(TestConnectionType.allCases.count, 4)
    }

    func testConnectionTypeRawValues() {
        XCTAssertEqual(TestConnectionType.wifi.rawValue, "wifi")
        XCTAssertEqual(TestConnectionType.cellular.rawValue, "cellular")
        XCTAssertEqual(TestConnectionType.ethernet.rawValue, "ethernet")
        XCTAssertEqual(TestConnectionType.unknown.rawValue, "unknown")
    }

    // MARK: - CachePolicy Tests

    func testAllCachePolicies() {
        XCTAssertEqual(TestCachePolicy.allCases.count, 4)
    }

    // MARK: - RetryPolicy Tests

    func testDefaultRetryPolicyValues() {
        let policy = TestRetryPolicy.default
        XCTAssertEqual(policy.maxRetries, 3)
        XCTAssertEqual(policy.baseDelay, 1.0)
        XCTAssertEqual(policy.maxDelay, 30.0)
        XCTAssertEqual(policy.multiplier, 2.0)
    }

    func testDefaultRetryableStatusCodes() {
        let policy = TestRetryPolicy.default
        XCTAssertTrue(policy.retryableCodes.contains(408))  // timeout
        XCTAssertTrue(policy.retryableCodes.contains(429))  // rate limit
        XCTAssertTrue(policy.retryableCodes.contains(500))  // server error
        XCTAssertTrue(policy.retryableCodes.contains(502))  // bad gateway
        XCTAssertTrue(policy.retryableCodes.contains(503))  // unavailable
        XCTAssertTrue(policy.retryableCodes.contains(504))  // gateway timeout
        XCTAssertFalse(policy.retryableCodes.contains(400)) // bad request
        XCTAssertFalse(policy.retryableCodes.contains(401)) // unauthorized
        XCTAssertFalse(policy.retryableCodes.contains(403)) // forbidden
        XCTAssertFalse(policy.retryableCodes.contains(404)) // not found
    }

    func testNoneRetryPolicy() {
        let policy = TestRetryPolicy.none
        XCTAssertEqual(policy.maxRetries, 0)
        XCTAssertTrue(policy.retryableCodes.isEmpty)
    }

    func testExponentialBackoffAttempt1() {
        let policy = TestRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 1), 1.0)  // 1 * 2^0 = 1
    }

    func testExponentialBackoffAttempt2() {
        let policy = TestRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 2), 2.0)  // 1 * 2^1 = 2
    }

    func testExponentialBackoffAttempt3() {
        let policy = TestRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 3), 4.0)  // 1 * 2^2 = 4
    }

    func testExponentialBackoffAttempt4() {
        let policy = TestRetryPolicy.default
        XCTAssertEqual(policy.delay(for: 4), 8.0)  // 1 * 2^3 = 8
    }

    func testExponentialBackoffCappedAtMaxDelay() {
        let policy = TestRetryPolicy.default
        let delay = policy.delay(for: 10)  // 1 * 2^9 = 512 > 30
        XCTAssertEqual(delay, 30.0)
    }

    func testCustomRetryPolicy() {
        let policy = TestRetryPolicy(
            maxRetries: 5, baseDelay: 0.5, maxDelay: 10.0,
            multiplier: 3.0, retryableCodes: [500, 503]
        )
        XCTAssertEqual(policy.delay(for: 1), 0.5)   // 0.5 * 3^0
        XCTAssertEqual(policy.delay(for: 2), 1.5)   // 0.5 * 3^1
        XCTAssertEqual(policy.delay(for: 3), 4.5)   // 0.5 * 3^2
        XCTAssertEqual(policy.delay(for: 4), 10.0)  // capped
    }

    // MARK: - NetworkConfiguration Tests

    func testDefaultConfig() {
        let config = TestNetworkConfig()
        XCTAssertNil(config.timeout)
        XCTAssertTrue(config.cacheEnabled)
        XCTAssertEqual(config.maxConcurrentRequests, 10)
    }

    func testCustomConfig() {
        var config = TestNetworkConfig()
        config.timeout = 60
        config.cacheEnabled = false
        config.maxConcurrentRequests = 5
        XCTAssertEqual(config.timeout, 60)
        XCTAssertFalse(config.cacheEnabled)
        XCTAssertEqual(config.maxConcurrentRequests, 5)
    }

    // MARK: - RequestRecord Tests

    func testRequestRecordCreation() {
        let record = TestRequestRecord(
            url: "https://api.anthropic.com/v1/messages",
            method: "POST",
            statusCode: 200,
            responseSize: 4096,
            timestamp: Date()
        )
        XCTAssertEqual(record.url, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(record.method, "POST")
        XCTAssertEqual(record.statusCode, 200)
        XCTAssertEqual(record.responseSize, 4096)
    }

    func testRequestRecordIdentifiable() {
        let r1 = TestRequestRecord(url: "a", method: "GET", statusCode: 200, responseSize: 0, timestamp: Date())
        let r2 = TestRequestRecord(url: "a", method: "GET", statusCode: 200, responseSize: 0, timestamp: Date())
        XCTAssertNotEqual(r1.id, r2.id)
    }

    // MARK: - NetworkError Tests

    func testNetworkErrorDescriptions() {
        XCTAssertEqual(TestNetworkError.noConnection.errorDescription, "No network connection")
        XCTAssertEqual(TestNetworkError.timeout.errorDescription, "Request timed out")
        XCTAssertEqual(TestNetworkError.invalidResponse.errorDescription, "Invalid response")
        XCTAssertEqual(TestNetworkError.unknown.errorDescription, "Unknown error")
    }

    func testHTTPErrorDescription() {
        let error = TestNetworkError.httpError(429, nil)
        XCTAssertEqual(error.errorDescription, "HTTP error: 429")
    }

    func testHTTPErrorWithData() {
        let data = "rate limited".data(using: .utf8)
        let error = TestNetworkError.httpError(429, data)
        XCTAssertTrue(error.errorDescription.contains("429"))
    }

    func testDecodingErrorDescription() {
        struct Dummy: Decodable { let x: Int }
        let invalidData = "not json".data(using: .utf8)!
        do {
            _ = try JSONDecoder().decode(Dummy.self, from: invalidData)
            XCTFail("Should have thrown")
        } catch {
            let netError = TestNetworkError.decodingError(error)
            XCTAssertTrue(netError.errorDescription.contains("Decoding error"))
        }
    }

    // MARK: - Rate Limiter Tests

    func testRateLimiterAllowsInitial() {
        let limiter = TestRateLimiter(requestsPerSecond: 10)
        XCTAssertTrue(limiter.shouldAllow())
    }

    func testRateLimiterDrainsTokens() {
        let limiter = TestRateLimiter(requestsPerSecond: 3)
        XCTAssertTrue(limiter.shouldAllow())
        XCTAssertTrue(limiter.shouldAllow())
        XCTAssertTrue(limiter.shouldAllow())
        XCTAssertFalse(limiter.shouldAllow())
    }
}
