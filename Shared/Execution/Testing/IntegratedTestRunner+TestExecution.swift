// IntegratedTestRunner+TestExecution.swift
// Thea V2
//
// Test execution and command building for IntegratedTestRunner

import Foundation

#if os(macOS)

extension IntegratedTestRunner {

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

        logger.info(
            "Test run complete: \(result.passedTests)/\(result.totalTests) passed"
            + " in \(String(format: "%.2f", result.duration))s"
        )

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

    func buildCommand(for config: TestRunConfiguration) -> String {
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

    func executeCommand(
        command: String,
        workingDirectory: String,
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> (output: String, errorOutput: String, exitCode: Int32) {
        try await withCheckedThrowingContinuation { continuation in
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
    }
}

#endif  // os(macOS)
