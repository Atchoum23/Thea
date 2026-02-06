// IntegratedTestRunner.swift
// Thea V2
//
// Native test execution for multiple languages
// Supports Swift XCTest, Python pytest/unittest, Node.js Jest/Mocha
// Enables Replit-style self-testing capabilities
//
// Note: Test execution (IntegratedTestRunner actor) is macOS-only as it uses Process

import Foundation
import OSLog

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

// MARK: - Integrated Test Runner

/// Runs tests across multiple languages and frameworks
@MainActor
@Observable
public final class IntegratedTestRunner {
    public static let shared = IntegratedTestRunner()

    private let logger = Logger(subsystem: "com.thea.testing", category: "IntegratedTestRunner")

    // MARK: - State

    private(set) var isRunning = false
    private(set) var currentConfiguration: TestRunConfiguration?
    private(set) var recentResults: [TestRunResult] = []
    private(set) var runningTests: [String] = []

    // MARK: - Configuration

    /// Maximum concurrent test processes
    public var maxConcurrentRuns: Int = 4

    /// Default timeout per test suite
    public var defaultTimeout: TimeInterval = 300

    /// Auto-detect test framework from project
    public var autoDetectFramework: Bool = true

    private var activeProcesses: [UUID: Process] = [:]

    private init() {}

    // MARK: - Framework Detection

    /// Detect test framework from project structure
    public func detectFramework(at projectPath: String) async -> TestFramework? {
        let fileManager = FileManager.default

        // Check for Swift package
        let packageSwift = (projectPath as NSString).appendingPathComponent("Package.swift")
        if fileManager.fileExists(atPath: packageSwift) {
            return .swiftTesting
        }

        // Check for Xcode project
        let xcodeProj = try? fileManager.contentsOfDirectory(atPath: projectPath)
            .first { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
        if xcodeProj != nil {
            return .xctest
        }

        // Check for package.json (Node.js)
        let packageJson = (projectPath as NSString).appendingPathComponent("package.json")
        if fileManager.fileExists(atPath: packageJson) {
            // Read package.json to detect framework
            if let data = fileManager.contents(atPath: packageJson),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let deps = (json["devDependencies"] as? [String: Any]) ?? [:]
                let allDeps = deps.merging((json["dependencies"] as? [String: Any]) ?? [:]) { $1 }

                if allDeps["jest"] != nil { return .jest }
                if allDeps["mocha"] != nil { return .mocha }
                if allDeps["vitest"] != nil { return .vitest }
            }
            return .jest  // Default for Node.js
        }

        // Check for Python
        let pytestIni = (projectPath as NSString).appendingPathComponent("pytest.ini")
        let setupPy = (projectPath as NSString).appendingPathComponent("setup.py")
        let pyprojectToml = (projectPath as NSString).appendingPathComponent("pyproject.toml")

        if fileManager.fileExists(atPath: pytestIni) {
            return .pytest
        }
        if fileManager.fileExists(atPath: setupPy) || fileManager.fileExists(atPath: pyprojectToml) {
            return .pytest
        }

        // Check for Go
        let goMod = (projectPath as NSString).appendingPathComponent("go.mod")
        if fileManager.fileExists(atPath: goMod) {
            return .goTest
        }

        // Check for Rust
        let cargoToml = (projectPath as NSString).appendingPathComponent("Cargo.toml")
        if fileManager.fileExists(atPath: cargoToml) {
            return .rustCargo
        }

        return nil
    }

    // MARK: - Test Execution

    /// Run tests with the given configuration
    public func runTests(
        configuration: TestRunConfiguration,
        progressHandler: (@Sendable (TestRunProgress) -> Void)? = nil
    ) async throws -> TestRunResult {
        guard !isRunning else {
            throw TestRunnerError.alreadyRunning
        }

        isRunning = true
        currentConfiguration = configuration

        defer {
            isRunning = false
            currentConfiguration = nil
        }

        let startTime = Date()
        logger.info("Starting test run: \(configuration.framework.rawValue) at \(configuration.projectPath)")

        progressHandler?(TestRunProgress(
            phase: .starting,
            message: "Preparing test environment",
            progress: 0.1
        ))

        // Build command
        let command = buildCommand(for: configuration)

        progressHandler?(TestRunProgress(
            phase: .running,
            message: "Executing tests",
            progress: 0.3
        ))

        // Execute tests
        let (output, errorOutput, exitCode) = try await executeCommand(
            command: command,
            workingDirectory: configuration.projectPath,
            environment: configuration.environment,
            timeout: configuration.timeout
        )

        progressHandler?(TestRunProgress(
            phase: .parsing,
            message: "Parsing results",
            progress: 0.8
        ))

        // Parse results
        let testCases = parseTestOutput(
            output: output,
            errorOutput: errorOutput,
            framework: configuration.framework
        )

        // Parse coverage if enabled
        var coverageReport: CoverageReport?
        if configuration.coverage {
            coverageReport = parseCoverageReport(
                output: output,
                framework: configuration.framework,
                projectPath: configuration.projectPath
            )
        }

        let endTime = Date()
        let success = exitCode == 0 && testCases.allSatisfy { $0.status != .error }

        let result = TestRunResult(
            configuration: configuration,
            startTime: startTime,
            endTime: endTime,
            success: success,
            testCases: testCases,
            coverageReport: coverageReport,
            rawOutput: output,
            errorOutput: errorOutput
        )

        recentResults.insert(result, at: 0)
        if recentResults.count > 50 {
            recentResults.removeLast()
        }

        progressHandler?(TestRunProgress(
            phase: .completed,
            message: success ? "Tests passed" : "Tests failed",
            progress: 1.0
        ))

        logger.info("Test run complete: \(result.passedTests)/\(result.totalTests) passed in \(String(format: "%.2f", result.duration))s")

        return result
    }

    /// Run tests for a specific file
    public func runTestsForFile(
        filePath: String,
        framework: TestFramework? = nil,
        progressHandler: (@Sendable (TestRunProgress) -> Void)? = nil
    ) async throws -> TestRunResult {
        let projectPath = findProjectRoot(from: filePath)
        let detectedFramework: TestFramework?
        if let framework = framework {
            detectedFramework = framework
        } else {
            detectedFramework = await detectFramework(at: projectPath)
        }

        guard let testFramework = detectedFramework else {
            throw TestRunnerError.frameworkNotDetected
        }

        let testPattern = extractTestPattern(from: filePath, framework: testFramework)

        let config = TestRunConfiguration(
            framework: testFramework,
            projectPath: projectPath,
            testPattern: testPattern
        )

        return try await runTests(configuration: config, progressHandler: progressHandler)
    }

    // MARK: - Command Building

    private func buildCommand(for config: TestRunConfiguration) -> String {
        var args: [String] = []

        switch config.framework {
        case .xctest:
            args = ["xcodebuild", "test"]
            if let pattern = config.testPattern {
                args += ["-only-testing:\(pattern)"]
            }

        case .swiftTesting:
            args = ["swift", "test"]
            if let pattern = config.testPattern {
                args += ["--filter", pattern]
            }
            if config.parallel {
                args += ["--parallel"]
            }

        case .pytest:
            args = ["python", "-m", "pytest"]
            if let pattern = config.testPattern {
                args += ["-k", pattern]
            }
            if config.verbose {
                args += ["-v"]
            }
            if config.coverage {
                args += ["--cov", "--cov-report=json"]
            }
            if config.parallel {
                args += ["-n", "auto"]
            }

        case .unittest:
            args = ["python", "-m", "unittest"]
            if let pattern = config.testPattern {
                args += [pattern]
            }
            if config.verbose {
                args += ["-v"]
            }

        case .jest:
            args = ["npx", "jest"]
            if let pattern = config.testPattern {
                args += ["--testPathPattern", pattern]
            }
            if config.coverage {
                args += ["--coverage"]
            }
            args += ["--json"]

        case .mocha:
            args = ["npx", "mocha"]
            if let pattern = config.testPattern {
                args += ["--grep", pattern]
            }
            args += ["--reporter", "json"]

        case .vitest:
            args = ["npx", "vitest", "run"]
            if let pattern = config.testPattern {
                args += [pattern]
            }
            args += ["--reporter=json"]

        case .goTest:
            args = ["go", "test"]
            if let pattern = config.testPattern {
                args += ["-run", pattern]
            }
            args += ["-v", "-json", "./..."]

        case .rustCargo:
            args = ["cargo", "test"]
            if let pattern = config.testPattern {
                args += [pattern]
            }
            args += ["--", "--format=json", "-Z", "unstable-options"]
        }

        return args.joined(separator: " ")
    }

    // MARK: - Command Execution

    private func executeCommand(
        command: String,
        workingDirectory: String,
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> (output: String, errorOutput: String, exitCode: Int32) {
        #if os(macOS)
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env

            let processId = UUID()
            Task { @MainActor in
                self.activeProcesses[processId] = process
            }

            // Timeout handling
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    process.terminate()
                }
            }

            process.terminationHandler = { [weak self] _ in
                timeoutTask.cancel()

                Task { @MainActor in
                    self?.activeProcesses.removeValue(forKey: processId)
                }

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                continuation.resume(returning: (output, errorOutput, process.terminationStatus))
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                continuation.resume(throwing: error)
            }
        }
        #else
        // Non-macOS platforms - return placeholder
        return ("Tests not supported on this platform", "", 1)
        #endif
    }

    // MARK: - Result Parsing

    private func parseTestOutput(
        output: String,
        errorOutput: String,
        framework: TestFramework
    ) -> [TestCaseResult] {
        switch framework {
        case .xctest, .swiftTesting:
            return parseXCTestOutput(output: output, errorOutput: errorOutput)
        case .pytest:
            return parsePytestOutput(output: output)
        case .unittest:
            return parseUnittestOutput(output: output)
        case .jest:
            return parseJestOutput(output: output)
        case .mocha:
            return parseMochaOutput(output: output)
        case .vitest:
            return parseVitestOutput(output: output)
        case .goTest:
            return parseGoTestOutput(output: output)
        case .rustCargo:
            return parseCargoTestOutput(output: output)
        }
    }

    private func parseXCTestOutput(output: String, errorOutput: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []
        let lines = output.components(separatedBy: .newlines)

        let passedPattern = #"Test Case '-\[(\w+) (\w+)\]' passed \((\d+\.\d+) seconds\)"#
        let failedPattern = #"Test Case '-\[(\w+) (\w+)\]' failed \((\d+\.\d+) seconds\)"#

        for line in lines {
            if let match = line.range(of: passedPattern, options: .regularExpression) {
                let components = String(line[match]).components(separatedBy: " ")
                if components.count >= 4 {
                    let nameMatch = line.firstMatch(of: /'-\[(\w+) (\w+)\]'/)
                    let className = nameMatch.map { String($0.1) }
                    let testName = nameMatch.map { String($0.2) }
                    let duration = Double(components.last?.replacingOccurrences(of: ")", with: "") ?? "0") ?? 0

                    results.append(TestCaseResult(
                        name: testName ?? "unknown",
                        className: className,
                        status: .passed,
                        duration: duration
                    ))
                }
            } else if let match = line.range(of: failedPattern, options: .regularExpression) {
                let components = String(line[match]).components(separatedBy: " ")
                if components.count >= 4 {
                    let nameMatch = line.firstMatch(of: /'-\[(\w+) (\w+)\]'/)
                    let className = nameMatch.map { String($0.1) }
                    let testName = nameMatch.map { String($0.2) }
                    let duration = Double(components.last?.replacingOccurrences(of: ")", with: "") ?? "0") ?? 0

                    results.append(TestCaseResult(
                        name: testName ?? "unknown",
                        className: className,
                        status: .failed,
                        duration: duration,
                        errorMessage: extractErrorMessage(from: errorOutput, testName: testName ?? "")
                    ))
                }
            }
        }

        return results
    }

    private func parsePytestOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        // Try JSON parsing first
        if let jsonData = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let tests = json["tests"] as? [[String: Any]] {
            for test in tests {
                let name = test["nodeid"] as? String ?? "unknown"
                let outcome = test["outcome"] as? String ?? "unknown"
                let duration = test["duration"] as? Double ?? 0

                let status: TestStatus = switch outcome {
                case "passed": .passed
                case "failed": .failed
                case "skipped": .skipped
                default: .error
                }

                results.append(TestCaseResult(
                    name: name,
                    status: status,
                    duration: duration
                ))
            }
        }

        // Fallback to text parsing
        if results.isEmpty {
            for line in output.components(separatedBy: .newlines) {
                if line.contains(" PASSED") {
                    let name = line.components(separatedBy: " ").first ?? "unknown"
                    results.append(TestCaseResult(name: name, status: .passed, duration: 0))
                } else if line.contains(" FAILED") {
                    let name = line.components(separatedBy: " ").first ?? "unknown"
                    results.append(TestCaseResult(name: name, status: .failed, duration: 0))
                }
            }
        }

        return results
    }

    private func parseUnittestOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        for line in output.components(separatedBy: .newlines) {
            if line.contains("... ok") {
                let name = line.replacingOccurrences(of: " ... ok", with: "")
                results.append(TestCaseResult(name: name, status: .passed, duration: 0))
            } else if line.contains("... FAIL") {
                let name = line.replacingOccurrences(of: " ... FAIL", with: "")
                results.append(TestCaseResult(name: name, status: .failed, duration: 0))
            } else if line.contains("... ERROR") {
                let name = line.replacingOccurrences(of: " ... ERROR", with: "")
                results.append(TestCaseResult(name: name, status: .error, duration: 0))
            }
        }

        return results
    }

    private func parseJestOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        if let jsonData = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let testResults = json["testResults"] as? [[String: Any]] {
            for file in testResults {
                if let assertionResults = file["assertionResults"] as? [[String: Any]] {
                    for test in assertionResults {
                        let name = test["fullName"] as? String ?? test["title"] as? String ?? "unknown"
                        let statusStr = test["status"] as? String ?? "unknown"
                        let duration = (test["duration"] as? Double ?? 0) / 1000  // Convert ms to s

                        let status: TestStatus = switch statusStr {
                        case "passed": .passed
                        case "failed": .failed
                        case "pending", "skipped": .skipped
                        default: .error
                        }

                        results.append(TestCaseResult(
                            name: name,
                            status: status,
                            duration: duration,
                            errorMessage: (test["failureMessages"] as? [String])?.joined(separator: "\n")
                        ))
                    }
                }
            }
        }

        return results
    }

    private func parseMochaOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        if let jsonData = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            if let passes = json["passes"] as? [[String: Any]] {
                for test in passes {
                    let name = test["fullTitle"] as? String ?? test["title"] as? String ?? "unknown"
                    let duration = (test["duration"] as? Double ?? 0) / 1000
                    results.append(TestCaseResult(name: name, status: .passed, duration: duration))
                }
            }
            if let failures = json["failures"] as? [[String: Any]] {
                for test in failures {
                    let name = test["fullTitle"] as? String ?? test["title"] as? String ?? "unknown"
                    let duration = (test["duration"] as? Double ?? 0) / 1000
                    let error = (test["err"] as? [String: Any])?["message"] as? String
                    results.append(TestCaseResult(name: name, status: .failed, duration: duration, errorMessage: error))
                }
            }
        }

        return results
    }

    private func parseVitestOutput(output: String) -> [TestCaseResult] {
        // Similar to Jest parsing
        parseJestOutput(output: output)
    }

    private func parseGoTestOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        for line in output.components(separatedBy: .newlines) {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            guard let action = json["Action"] as? String,
                  let test = json["Test"] as? String else {
                continue
            }

            if action == "pass" {
                let elapsed = json["Elapsed"] as? Double ?? 0
                results.append(TestCaseResult(name: test, status: .passed, duration: elapsed))
            } else if action == "fail" {
                let elapsed = json["Elapsed"] as? Double ?? 0
                results.append(TestCaseResult(name: test, status: .failed, duration: elapsed))
            } else if action == "skip" {
                results.append(TestCaseResult(name: test, status: .skipped, duration: 0))
            }
        }

        return results
    }

    private func parseCargoTestOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        for line in output.components(separatedBy: .newlines) {
            if line.contains("... ok") {
                let name = line.components(separatedBy: " ").first ?? "unknown"
                results.append(TestCaseResult(name: name, status: .passed, duration: 0))
            } else if line.contains("... FAILED") {
                let name = line.components(separatedBy: " ").first ?? "unknown"
                results.append(TestCaseResult(name: name, status: .failed, duration: 0))
            } else if line.contains("... ignored") {
                let name = line.components(separatedBy: " ").first ?? "unknown"
                results.append(TestCaseResult(name: name, status: .skipped, duration: 0))
            }
        }

        return results
    }

    // MARK: - Coverage Parsing

    private func parseCoverageReport(
        output: String,
        framework: TestFramework,
        projectPath: String
    ) -> CoverageReport? {
        // Simplified coverage parsing - would need framework-specific handling
        nil
    }

    // MARK: - Helper Methods

    private func findProjectRoot(from filePath: String) -> String {
        var current = (filePath as NSString).deletingLastPathComponent
        let fileManager = FileManager.default

        let markers = ["Package.swift", "package.json", "Cargo.toml", "go.mod", "setup.py", "pyproject.toml"]

        while current != "/" {
            for marker in markers {
                let markerPath = (current as NSString).appendingPathComponent(marker)
                if fileManager.fileExists(atPath: markerPath) {
                    return current
                }
            }

            // Check for .xcodeproj or .xcworkspace
            if let contents = try? fileManager.contentsOfDirectory(atPath: current),
               contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
                return current
            }

            current = (current as NSString).deletingLastPathComponent
        }

        return (filePath as NSString).deletingLastPathComponent
    }

    private func extractTestPattern(from filePath: String, framework: TestFramework) -> String {
        let fileName = (filePath as NSString).lastPathComponent
        let baseName = (fileName as NSString).deletingPathExtension

        switch framework {
        case .xctest, .swiftTesting:
            return baseName
        case .pytest, .unittest:
            return baseName
        case .jest, .mocha, .vitest:
            return fileName
        case .goTest:
            return ".*"
        case .rustCargo:
            return baseName.lowercased()
        }
    }

    private func extractErrorMessage(from errorOutput: String, testName: String) -> String? {
        // Find error message related to the test
        let lines = errorOutput.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() where line.contains(testName) {
            if index + 1 < lines.count {
                return lines[index + 1]
            }
        }
        return nil
    }

    // MARK: - Cleanup

    /// Cancel all running tests
    public func cancelAll() {
        for (_, process) in activeProcesses {
            if process.isRunning {
                process.terminate()
            }
        }
        activeProcesses.removeAll()
        isRunning = false
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
