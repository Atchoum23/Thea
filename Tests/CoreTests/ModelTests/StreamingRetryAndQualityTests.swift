// StreamingRetryAndQualityTests.swift
// Tests for streaming error recovery logic + CodeQualityGate/RegressionDetector types

import Testing
import Foundation

// MARK: - Retry Delay Tests

/// Mirrors ChatManager.retryDelay() logic
private func retryDelay(attempt: Int, jitter: Double = 0) -> TimeInterval {
    let base = min(pow(2.0, Double(attempt)), 10.0)
    return base + jitter
}

/// Mirrors ChatManager.isRetryableError() logic
private func isRetryableError(_ description: String) -> Bool {
    let lower = description.lowercased()
    if lower.contains("429") || lower.contains("rate limit") { return true }
    if lower.contains("500") || lower.contains("502") ||
        lower.contains("503") || lower.contains("504") { return true }
    if lower.contains("timeout") || lower.contains("timed out") { return true }
    return false
}

@Suite("Retry Delay")
struct RetryDelayTests {
    @Test("Attempt 0 delay is ~1s")
    func attempt0() {
        let delay = retryDelay(attempt: 0)
        #expect(delay >= 1.0)
        #expect(delay <= 1.5)
    }

    @Test("Attempt 1 delay is ~2s")
    func attempt1() {
        let delay = retryDelay(attempt: 1)
        #expect(delay >= 2.0)
        #expect(delay <= 2.5)
    }

    @Test("Attempt 2 delay is ~4s")
    func attempt2() {
        let delay = retryDelay(attempt: 2)
        #expect(delay >= 4.0)
        #expect(delay <= 4.5)
    }

    @Test("Attempt 3 delay is ~8s")
    func attempt3() {
        let delay = retryDelay(attempt: 3)
        #expect(delay >= 8.0)
        #expect(delay <= 8.5)
    }

    @Test("Delay caps at 10s")
    func delayCap() {
        let delay = retryDelay(attempt: 10)
        #expect(delay >= 10.0)
        #expect(delay <= 10.5)
    }

    @Test("Jitter adds to base delay")
    func jitter() {
        let delayNoJitter = retryDelay(attempt: 1, jitter: 0)
        let delayWithJitter = retryDelay(attempt: 1, jitter: 0.5)
        #expect(delayWithJitter == delayNoJitter + 0.5)
    }

    @Test("Exponential growth: each attempt roughly doubles")
    func exponentialGrowth() {
        let d0 = retryDelay(attempt: 0)
        let d1 = retryDelay(attempt: 1)
        let d2 = retryDelay(attempt: 2)
        #expect(d1 > d0)
        #expect(d2 > d1)
        #expect(d1 / d0 >= 1.9) // ~2x
        #expect(d2 / d1 >= 1.9)
    }
}

// MARK: - Retryable Error Tests

@Suite("Retryable Errors")
struct RetryableErrorTests {
    @Test("429 rate limit is retryable")
    func rateLimitRetryable() {
        #expect(isRetryableError("HTTP 429 Too Many Requests"))
        #expect(isRetryableError("rate limit exceeded"))
        #expect(isRetryableError("Rate Limit"))
    }

    @Test("500 server error is retryable")
    func serverErrorRetryable() {
        #expect(isRetryableError("HTTP 500 Internal Server Error"))
    }

    @Test("502 bad gateway is retryable")
    func badGatewayRetryable() {
        #expect(isRetryableError("502 Bad Gateway"))
    }

    @Test("503 service unavailable is retryable")
    func serviceUnavailableRetryable() {
        #expect(isRetryableError("503 Service Unavailable"))
    }

    @Test("504 gateway timeout is retryable")
    func gatewayTimeoutRetryable() {
        #expect(isRetryableError("504 Gateway Timeout"))
    }

    @Test("Timeout is retryable")
    func timeoutRetryable() {
        #expect(isRetryableError("Request timed out"))
        #expect(isRetryableError("Connection timeout"))
    }

    @Test("400 bad request is NOT retryable")
    func badRequestNotRetryable() {
        #expect(!isRetryableError("HTTP 400 Bad Request"))
    }

    @Test("401 unauthorized is NOT retryable")
    func unauthorizedNotRetryable() {
        #expect(!isRetryableError("HTTP 401 Unauthorized"))
    }

    @Test("403 forbidden is NOT retryable")
    func forbiddenNotRetryable() {
        #expect(!isRetryableError("HTTP 403 Forbidden"))
    }

    @Test("404 not found is NOT retryable")
    func notFoundNotRetryable() {
        #expect(!isRetryableError("HTTP 404 Not Found"))
    }

    @Test("Generic error is NOT retryable")
    func genericNotRetryable() {
        #expect(!isRetryableError("Something went wrong"))
        #expect(!isRetryableError("Invalid API key"))
        #expect(!isRetryableError("Model not found"))
    }
}

// MARK: - CodeQualityGate Types Tests

private struct TestGateResult: Sendable {
    let passed: Bool
    let checks: [TestCheckResult]
    let timestamp: Date
    let duration: TimeInterval

    var failedChecks: [TestCheckResult] {
        checks.filter { !$0.passed }
    }

    var summary: String {
        let passCount = checks.filter(\.passed).count
        let total = checks.count
        let status = passed ? "PASSED" : "FAILED"
        return "Quality Gate \(status): \(passCount)/\(total) checks passed"
    }
}

private struct TestCheckResult: Sendable {
    let name: String
    let passed: Bool
    let message: String
    let severity: CheckSeverity

    enum CheckSeverity: String, Sendable {
        case blocking
        case warning
    }
}

@Suite("Quality Gate Types")
struct QualityGateTypesTests {
    @Test("Gate result — all checks pass")
    func allPass() {
        let checks = [
            TestCheckResult(name: "Tests", passed: true, message: "47 tests passed", severity: .blocking),
            TestCheckResult(name: "Build", passed: true, message: "Build succeeded", severity: .blocking),
            TestCheckResult(name: "Lint", passed: true, message: "No violations", severity: .warning)
        ]
        let result = TestGateResult(passed: true, checks: checks, timestamp: Date(), duration: 5.0)
        #expect(result.passed)
        #expect(result.failedChecks.isEmpty)
        #expect(result.summary.contains("PASSED"))
        #expect(result.summary.contains("3/3"))
    }

    @Test("Gate result — blocking check fails")
    func blockingFails() {
        let checks = [
            TestCheckResult(name: "Tests", passed: false, message: "3 failures", severity: .blocking),
            TestCheckResult(name: "Build", passed: true, message: "OK", severity: .blocking),
            TestCheckResult(name: "Lint", passed: true, message: "OK", severity: .warning)
        ]
        let result = TestGateResult(passed: false, checks: checks, timestamp: Date(), duration: 10.0)
        #expect(!result.passed)
        #expect(result.failedChecks.count == 1)
        #expect(result.failedChecks[0].name == "Tests")
        #expect(result.summary.contains("FAILED"))
        #expect(result.summary.contains("2/3"))
    }

    @Test("Gate result — warning check fails but gate passes")
    func warningFails() {
        let checks = [
            TestCheckResult(name: "Tests", passed: true, message: "OK", severity: .blocking),
            TestCheckResult(name: "Build", passed: true, message: "OK", severity: .blocking),
            TestCheckResult(name: "Lint", passed: false, message: "2 violations", severity: .warning)
        ]
        // Gate passes because only warnings failed
        let blockingFailed = checks.contains { !$0.passed && $0.severity == .blocking }
        let result = TestGateResult(passed: !blockingFailed, checks: checks, timestamp: Date(), duration: 3.0)
        #expect(result.passed)
        #expect(result.failedChecks.count == 1)
    }

    @Test("Gate result — empty checks")
    func emptyChecks() {
        let result = TestGateResult(passed: true, checks: [], timestamp: Date(), duration: 0)
        #expect(result.passed)
        #expect(result.failedChecks.isEmpty)
        #expect(result.summary.contains("0/0"))
    }

    @Test("Check severities are distinct")
    func severities() {
        #expect(TestCheckResult.CheckSeverity.blocking.rawValue != TestCheckResult.CheckSeverity.warning.rawValue)
    }
}

// MARK: - RegressionDetector Types Tests

private struct TestSnapshot: Codable, Sendable {
    let timestamp: Date
    let testCount: Int
    let testsPassing: Bool
    let buildWarningCount: Int
    let swiftLintViolations: Int
    let buildSucceeded: Bool
    let commitHash: String?

    static let empty = TestSnapshot(
        timestamp: Date(), testCount: 0, testsPassing: false,
        buildWarningCount: 0, swiftLintViolations: 0,
        buildSucceeded: false, commitHash: nil
    )
}

private struct TestRegression: Sendable {
    let category: Category
    let description: String

    enum Category: String, Sendable {
        case testCountDecreased
        case testsNowFailing
        case buildBroken
        case moreWarnings
        case moreLintViolations
    }
}

private struct TestImprovement: Sendable {
    let description: String
}

private func compareSnapshots(before: TestSnapshot, after: TestSnapshot) -> (regressions: [TestRegression], improvements: [TestImprovement]) {
    var regressions: [TestRegression] = []
    var improvements: [TestImprovement] = []

    if after.testCount < before.testCount {
        regressions.append(TestRegression(
            category: .testCountDecreased,
            description: "Tests: \(before.testCount) → \(after.testCount)"
        ))
    } else if after.testCount > before.testCount {
        improvements.append(TestImprovement(description: "Tests: \(before.testCount) → \(after.testCount)"))
    }

    if before.testsPassing && !after.testsPassing {
        regressions.append(TestRegression(category: .testsNowFailing, description: "Tests failing"))
    } else if !before.testsPassing && after.testsPassing {
        improvements.append(TestImprovement(description: "Tests now passing"))
    }

    if before.buildSucceeded && !after.buildSucceeded {
        regressions.append(TestRegression(category: .buildBroken, description: "Build broken"))
    } else if !before.buildSucceeded && after.buildSucceeded {
        improvements.append(TestImprovement(description: "Build fixed"))
    }

    if after.buildWarningCount > before.buildWarningCount {
        regressions.append(TestRegression(category: .moreWarnings, description: "More warnings"))
    } else if after.buildWarningCount < before.buildWarningCount {
        improvements.append(TestImprovement(description: "Fewer warnings"))
    }

    if after.swiftLintViolations > before.swiftLintViolations {
        regressions.append(TestRegression(category: .moreLintViolations, description: "More lint violations"))
    } else if after.swiftLintViolations < before.swiftLintViolations {
        improvements.append(TestImprovement(description: "Fewer lint violations"))
    }

    return (regressions, improvements)
}

@Suite("Regression Detector")
struct RegressionDetectorTests {
    @Test("No regressions when everything improves")
    func allImproved() {
        let before = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 5, swiftLintViolations: 3,
            buildSucceeded: true, commitHash: "abc123"
        )
        let after = TestSnapshot(
            timestamp: Date(), testCount: 150, testsPassing: true,
            buildWarningCount: 2, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: "def456"
        )
        let result = compareSnapshots(before: before, after: after)
        #expect(result.regressions.isEmpty)
        #expect(result.improvements.count == 3) // tests, warnings, lint
    }

    @Test("Test count decrease is regression")
    func testCountDecreased() {
        let before = TestSnapshot(
            timestamp: Date(), testCount: 200, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let after = TestSnapshot(
            timestamp: Date(), testCount: 180, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let result = compareSnapshots(before: before, after: after)
        #expect(result.regressions.count == 1)
        #expect(result.regressions[0].category == .testCountDecreased)
    }

    @Test("Tests now failing is regression")
    func testsNowFailing() {
        let before = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let after = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: false,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let result = compareSnapshots(before: before, after: after)
        #expect(result.regressions.count == 1)
        #expect(result.regressions[0].category == .testsNowFailing)
    }

    @Test("Build broken is regression")
    func buildBroken() {
        let before = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let after = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: false, commitHash: nil
        )
        let result = compareSnapshots(before: before, after: after)
        #expect(result.regressions.count == 1)
        #expect(result.regressions[0].category == .buildBroken)
    }

    @Test("More warnings is regression")
    func moreWarnings() {
        let before = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 2, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let after = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 5, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let result = compareSnapshots(before: before, after: after)
        #expect(result.regressions.count == 1)
        #expect(result.regressions[0].category == .moreWarnings)
    }

    @Test("More lint violations is regression")
    func moreLintViolations() {
        let before = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let after = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 3,
            buildSucceeded: true, commitHash: nil
        )
        let result = compareSnapshots(before: before, after: after)
        #expect(result.regressions.count == 1)
        #expect(result.regressions[0].category == .moreLintViolations)
    }

    @Test("No change means no regressions and no improvements")
    func noChange() {
        let snapshot = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let result = compareSnapshots(before: snapshot, after: snapshot)
        #expect(result.regressions.isEmpty)
        #expect(result.improvements.isEmpty)
    }

    @Test("Multiple regressions detected simultaneously")
    func multipleRegressions() {
        let before = TestSnapshot(
            timestamp: Date(), testCount: 200, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: nil
        )
        let after = TestSnapshot(
            timestamp: Date(), testCount: 150, testsPassing: false,
            buildWarningCount: 3, swiftLintViolations: 5,
            buildSucceeded: false, commitHash: nil
        )
        let result = compareSnapshots(before: before, after: after)
        #expect(result.regressions.count == 5) // all 5 categories
    }

    @Test("From empty to working is all improvements")
    func fromEmpty() {
        let before = TestSnapshot.empty
        let after = TestSnapshot(
            timestamp: Date(), testCount: 100, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: "abc123"
        )
        let result = compareSnapshots(before: before, after: after)
        #expect(result.regressions.isEmpty)
        #expect(result.improvements.count == 3) // tests up, tests passing, build fixed
    }

    @Test("Snapshot Codable roundtrip")
    func snapshotCodable() throws {
        let snapshot = TestSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            testCount: 4353, testsPassing: true,
            buildWarningCount: 0, swiftLintViolations: 0,
            buildSucceeded: true, commitHash: "abc1234"
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TestSnapshot.self, from: data)
        #expect(decoded.testCount == 4353)
        #expect(decoded.testsPassing)
        #expect(decoded.buildSucceeded)
        #expect(decoded.commitHash == "abc1234")
    }

    @Test("Empty snapshot has zero values")
    func emptySnapshot() {
        let s = TestSnapshot.empty
        #expect(s.testCount == 0)
        #expect(!s.testsPassing)
        #expect(s.buildWarningCount == 0)
        #expect(s.swiftLintViolations == 0)
        #expect(!s.buildSucceeded)
        #expect(s.commitHash == nil)
    }

    @Test("Regression categories are all distinct")
    func distinctCategories() {
        let allCategories = [
            TestRegression.Category.testCountDecreased,
            .testsNowFailing,
            .buildBroken,
            .moreWarnings,
            .moreLintViolations
        ]
        let rawValues = Set(allCategories.map(\.rawValue))
        #expect(rawValues.count == 5)
    }
}
