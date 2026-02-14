//
//  IntegratedTestRunnerTypes.swift
//  Thea
//
//  Supporting types for IntegratedTestRunner
//

import Foundation

// MARK: - Test Framework Types (Available on all platforms)

/// Supported test frameworks
public enum TestFramework: String, Codable, Sendable, CaseIterable {
    case xctest = "XCTest"           // Swift
    case pytest = "pytest"           // Python
    case unittest = "unittest"       // Python stdlib
    case jest = "Jest"               // JavaScript/TypeScript
    case mocha = "Mocha"             // JavaScript
    case vitest = "Vitest"           // Vite/Vue
    case swiftTesting = "SwiftTesting" // Swift Testing macro
    case goTest = "go test"          // Go
    case rustCargo = "cargo test"    // Rust

    public var language: ProgrammingLanguage {
        switch self {
        case .xctest, .swiftTesting: return .swift
        case .pytest, .unittest: return .python
        case .jest, .mocha, .vitest: return .javascript
        case .goTest: return .go
        case .rustCargo: return .rust
        }
    }

    public var command: String {
        switch self {
        case .xctest: return "xcodebuild test"
        case .swiftTesting: return "swift test"
        case .pytest: return "pytest"
        case .unittest: return "python -m unittest"
        case .jest: return "npx jest"
        case .mocha: return "npx mocha"
        case .vitest: return "npx vitest run"
        case .goTest: return "go test"
        case .rustCargo: return "cargo test"
        }
    }
}

// Note: ProgrammingLanguage is defined in SemanticCodeIndexer.swift
// Reuse that definition to avoid duplication

#if os(macOS)

// MARK: - Test Run Configuration

/// Configuration for running tests
public struct TestRunConfiguration: Sendable {
    public let framework: TestFramework
    public let projectPath: String
    public let testPattern: String?      // Filter tests by pattern
    public let parallel: Bool            // Run tests in parallel
    public let coverage: Bool            // Generate coverage report
    public let timeout: TimeInterval     // Max test duration
    public let environment: [String: String]
    public let verbose: Bool

    public init(
        framework: TestFramework,
        projectPath: String,
        testPattern: String? = nil,
        parallel: Bool = true,
        coverage: Bool = false,
        timeout: TimeInterval = 300,
        environment: [String: String] = [:],
        verbose: Bool = false
    ) {
        self.framework = framework
        self.projectPath = projectPath
        self.testPattern = testPattern
        self.parallel = parallel
        self.coverage = coverage
        self.timeout = timeout
        self.environment = environment
        self.verbose = verbose
    }
}

// MARK: - Test Result Types

/// Result of a test run
public struct TestRunResult: Identifiable, Sendable {
    public let id: UUID
    public let configuration: TestRunConfiguration
    public let startTime: Date
    public let endTime: Date
    public let success: Bool
    public let testCases: [TestCaseResult]
    public let coverageReport: CoverageReport?
    public let rawOutput: String
    public let errorOutput: String

    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    public var totalTests: Int { testCases.count }
    public var passedTests: Int { testCases.filter { $0.status == .passed }.count }
    public var failedTests: Int { testCases.filter { $0.status == .failed }.count }
    public var skippedTests: Int { testCases.filter { $0.status == .skipped }.count }

    public var passRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(passedTests) / Double(totalTests)
    }

    public init(
        id: UUID = UUID(),
        configuration: TestRunConfiguration,
        startTime: Date,
        endTime: Date,
        success: Bool,
        testCases: [TestCaseResult],
        coverageReport: CoverageReport? = nil,
        rawOutput: String,
        errorOutput: String
    ) {
        self.id = id
        self.configuration = configuration
        self.startTime = startTime
        self.endTime = endTime
        self.success = success
        self.testCases = testCases
        self.coverageReport = coverageReport
        self.rawOutput = rawOutput
        self.errorOutput = errorOutput
    }
}

/// Result of a single test case
public struct TestCaseResult: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let className: String?
    public let status: TestStatus
    public let duration: TimeInterval
    public let errorMessage: String?
    public let stackTrace: String?
    public let filePath: String?
    public let lineNumber: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        className: String? = nil,
        status: TestStatus,
        duration: TimeInterval,
        errorMessage: String? = nil,
        stackTrace: String? = nil,
        filePath: String? = nil,
        lineNumber: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.className = className
        self.status = status
        self.duration = duration
        self.errorMessage = errorMessage
        self.stackTrace = stackTrace
        self.filePath = filePath
        self.lineNumber = lineNumber
    }

    public var fullName: String {
        if let className = className {
            return "\(className).\(name)"
        }
        return name
    }
}

public enum TestStatus: String, Codable, Sendable {
    case passed
    case failed
    case skipped
    case error
    case timeout
}

/// Code coverage report
public struct CoverageReport: Sendable {
    public let overallPercentage: Double
    public let fileCoverage: [FileCoverage]
    public let uncoveredLines: [UncoveredLine]

    public struct FileCoverage: Sendable {
        public let filePath: String
        public let linesCovered: Int
        public let totalLines: Int
        public var percentage: Double {
            guard totalLines > 0 else { return 0 }
            return Double(linesCovered) / Double(totalLines) * 100
        }
    }

    public struct UncoveredLine: Sendable {
        public let filePath: String
        public let lineNumber: Int
        public let code: String?
    }
}

// MARK: - Progress

public struct TestRunProgress: Sendable {
    public let phase: Phase
    public let message: String
    public let progress: Double

    public enum Phase: String, Sendable {
        case starting
        case building
        case running
        case parsing
        case completed
    }
}

// MARK: - Errors

public enum TestRunnerError: LocalizedError {
    case alreadyRunning
    case frameworkNotDetected
    case executionFailed(String)
    case timeout
    case processNotFound

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            "Test runner is already running"
        case .frameworkNotDetected:
            "Could not detect test framework"
        case .executionFailed(let message):
            "Test execution failed: \(message)"
        case .timeout:
            "Test execution timed out"
        case .processNotFound:
            "Test process not found"
        }
    }
}

#endif  // os(macOS)
