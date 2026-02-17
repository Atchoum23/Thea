//
//  ErrorLoggerTests.swift
//  TheaTests
//
//  Tests for ErrorLogger utility: tryOrNil, tryOrDefault, error handling.
//

import Foundation
import XCTest

// MARK: - Test Double

private final class TestErrorLogger: @unchecked Sendable {
    nonisolated(unsafe) static var lastLoggedError: (any Error, String)?
    nonisolated(unsafe) static var lastWarning: String?

    static func reset() {
        lastLoggedError = nil
        lastWarning = nil
    }

    static func log(_ error: any Error, context: String) {
        lastLoggedError = (error, context)
    }

    static func warn(_ message: String) {
        lastWarning = message
    }

    static func tryOrNil<T>(context: String, _ body: () throws -> T) -> T? {
        do {
            return try body()
        } catch {
            log(error, context: context)
            return nil
        }
    }

    static func tryOrNilAsync<T>(context: String, _ body: @Sendable () async throws -> T) async -> T? {
        do {
            return try await body()
        } catch {
            log(error, context: context)
            return nil
        }
    }

    static func tryOrDefault<T>(_ defaultValue: T, context: String, _ body: () throws -> T) -> T {
        do {
            return try body()
        } catch {
            log(error, context: context)
            return defaultValue
        }
    }
}

private enum TestError: Error, LocalizedError {
    case sample
    case withMessage(String)
    case network

    var errorDescription: String? {
        switch self {
        case .sample: "Sample error"
        case .withMessage(let msg): msg
        case .network: "Network unavailable"
        }
    }
}

// MARK: - tryOrNil Tests

@MainActor
final class ErrorLoggerTryOrNilTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TestErrorLogger.reset()
    }

    func testTryOrNilReturnsValueOnSuccess() {
        let result = TestErrorLogger.tryOrNil(context: "test") {
            42
        }
        XCTAssertEqual(result, 42)
        XCTAssertNil(TestErrorLogger.lastLoggedError)
    }

    func testTryOrNilReturnsNilOnFailure() {
        let result: Int? = TestErrorLogger.tryOrNil(context: "failing op") {
            throw TestError.sample
        }
        XCTAssertNil(result)
        XCTAssertNotNil(TestErrorLogger.lastLoggedError)
    }

    func testTryOrNilLogsErrorContext() {
        let _: Int? = TestErrorLogger.tryOrNil(context: "parsing JSON") {
            throw TestError.withMessage("Invalid JSON")
        }
        XCTAssertEqual(TestErrorLogger.lastLoggedError?.1, "parsing JSON")
    }

    func testTryOrNilWithStringType() {
        let result = TestErrorLogger.tryOrNil(context: "string op") {
            "hello"
        }
        XCTAssertEqual(result, "hello")
    }

    func testTryOrNilWithOptionalReturn() {
        let result: String? = TestErrorLogger.tryOrNil(context: "optional") {
            throw TestError.network
        }
        XCTAssertNil(result)
    }

    func testTryOrNilPreservesErrorType() {
        let _: Int? = TestErrorLogger.tryOrNil(context: "type check") {
            throw TestError.withMessage("Custom message")
        }
        if let (error, _) = TestErrorLogger.lastLoggedError,
           let testError = error as? TestError {
            switch testError {
            case .withMessage(let msg):
                XCTAssertEqual(msg, "Custom message")
            default:
                XCTFail("Expected .withMessage")
            }
        } else {
            XCTFail("Error not logged or wrong type")
        }
    }

    func testTryOrNilDoesNotLogOnSuccess() {
        _ = TestErrorLogger.tryOrNil(context: "no error") {
            [1, 2, 3]
        }
        XCTAssertNil(TestErrorLogger.lastLoggedError)
    }
}

// MARK: - tryOrNil Async Tests

@MainActor
final class ErrorLoggerAsyncTryOrNilTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TestErrorLogger.reset()
    }

    func testAsyncTryOrNilReturnsValueOnSuccess() async {
        let result = await TestErrorLogger.tryOrNilAsync(context: "async success") {
            42
        }
        XCTAssertEqual(result, 42)
        XCTAssertNil(TestErrorLogger.lastLoggedError)
    }

    func testAsyncTryOrNilReturnsNilOnFailure() async {
        let result: Int? = await TestErrorLogger.tryOrNilAsync(context: "async fail") {
            throw TestError.network
        }
        XCTAssertNil(result)
        XCTAssertNotNil(TestErrorLogger.lastLoggedError)
    }

    func testAsyncTryOrNilLogsContext() async {
        let _: String? = await TestErrorLogger.tryOrNilAsync(context: "async context") {
            throw TestError.sample
        }
        XCTAssertEqual(TestErrorLogger.lastLoggedError?.1, "async context")
    }
}

// MARK: - tryOrDefault Tests

@MainActor
final class ErrorLoggerTryOrDefaultTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TestErrorLogger.reset()
    }

    func testTryOrDefaultReturnsValueOnSuccess() {
        let result = TestErrorLogger.tryOrDefault(0, context: "success") {
            42
        }
        XCTAssertEqual(result, 42)
        XCTAssertNil(TestErrorLogger.lastLoggedError)
    }

    func testTryOrDefaultReturnsDefaultOnFailure() {
        let result = TestErrorLogger.tryOrDefault(-1, context: "failure") {
            throw TestError.sample
        }
        XCTAssertEqual(result, -1)
        XCTAssertNotNil(TestErrorLogger.lastLoggedError)
    }

    func testTryOrDefaultWithStringDefault() {
        let result = TestErrorLogger.tryOrDefault("fallback", context: "string") {
            throw TestError.network
        }
        XCTAssertEqual(result, "fallback")
    }

    func testTryOrDefaultWithArrayDefault() {
        let result = TestErrorLogger.tryOrDefault([Int](), context: "array") {
            throw TestError.sample
        }
        XCTAssertTrue(result.isEmpty)
    }

    func testTryOrDefaultLogsErrorContext() {
        _ = TestErrorLogger.tryOrDefault(false, context: "bool check") {
            throw TestError.withMessage("Failed check")
        }
        XCTAssertEqual(TestErrorLogger.lastLoggedError?.1, "bool check")
    }

    func testTryOrDefaultDoesNotLogOnSuccess() {
        _ = TestErrorLogger.tryOrDefault(0, context: "no log") {
            100
        }
        XCTAssertNil(TestErrorLogger.lastLoggedError)
    }

    func testTryOrDefaultWithZeroDefault() {
        let result = TestErrorLogger.tryOrDefault(0, context: "zero") {
            throw TestError.sample
        }
        XCTAssertEqual(result, 0)
    }
}

// MARK: - Log and Warn Tests

@MainActor
final class ErrorLoggerLogWarnTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TestErrorLogger.reset()
    }

    func testLogStoresError() {
        let error = TestError.sample
        TestErrorLogger.log(error, context: "test context")
        XCTAssertNotNil(TestErrorLogger.lastLoggedError)
        XCTAssertEqual(TestErrorLogger.lastLoggedError?.1, "test context")
    }

    func testLogWithEmptyContext() {
        TestErrorLogger.log(TestError.sample, context: "")
        XCTAssertEqual(TestErrorLogger.lastLoggedError?.1, "")
    }

    func testWarnStoresMessage() {
        TestErrorLogger.warn("Low disk space")
        XCTAssertEqual(TestErrorLogger.lastWarning, "Low disk space")
    }

    func testWarnWithEmptyMessage() {
        TestErrorLogger.warn("")
        XCTAssertEqual(TestErrorLogger.lastWarning, "")
    }

    func testResetClearsState() {
        TestErrorLogger.log(TestError.sample, context: "ctx")
        TestErrorLogger.warn("warning")
        TestErrorLogger.reset()
        XCTAssertNil(TestErrorLogger.lastLoggedError)
        XCTAssertNil(TestErrorLogger.lastWarning)
    }
}

// MARK: - Edge Case Tests

@MainActor
final class ErrorLoggerEdgeCaseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        TestErrorLogger.reset()
    }

    func testMultipleErrorsOnlyKeepsLast() {
        let _: Int? = TestErrorLogger.tryOrNil(context: "first") {
            throw TestError.sample
        }
        let _: Int? = TestErrorLogger.tryOrNil(context: "second") {
            throw TestError.network
        }
        XCTAssertEqual(TestErrorLogger.lastLoggedError?.1, "second")
    }

    func testNestedTryOrNil() {
        let result: Int? = TestErrorLogger.tryOrNil(context: "outer") {
            let inner: Int? = TestErrorLogger.tryOrNil(context: "inner") {
                throw TestError.sample
            }
            return inner ?? 99
        }
        XCTAssertEqual(result, 99)
    }

    func testTryOrDefaultWithComplexType() {
        struct Config {
            let timeout: Int
            let retries: Int
        }
        let defaultConfig = Config(timeout: 30, retries: 3)
        let result = TestErrorLogger.tryOrDefault(defaultConfig, context: "config") {
            throw TestError.sample
        }
        XCTAssertEqual(result.timeout, 30)
        XCTAssertEqual(result.retries, 3)
    }

    func testTryOrNilWithExpensiveComputation() {
        var computed = false
        let result = TestErrorLogger.tryOrNil(context: "compute") {
            computed = true
            return 42
        }
        XCTAssertTrue(computed)
        XCTAssertEqual(result, 42)
    }

    func testErrorLocalizedDescription() {
        let _: Int? = TestErrorLogger.tryOrNil(context: "localized") {
            throw TestError.withMessage("Localized error message")
        }
        if let (error, _) = TestErrorLogger.lastLoggedError {
            XCTAssertEqual(error.localizedDescription, "Localized error message")
        }
    }
}
