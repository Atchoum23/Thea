#if os(macOS)
    import Foundation
    import UserNotifications

    // MARK: - QA Tools Manager

    // Service for programmatically running third-party QA tools

    @MainActor
    @Observable
    final class QAToolsManager {
        static let shared = QAToolsManager()

        private(set) var isRunning = false
        private(set) var currentTool: QATool?
        private(set) var lastResults: [QATool: QAToolResult] = [:]
        private(set) var history: [QAToolResult] = []

        private var config: QAToolsConfiguration {
            AppConfiguration.shared.qaToolsConfig
        }

        private init() {
            loadHistory()
        }

        // MARK: - Public API

        /// Run all enabled QA tools
        func runAllTools() async -> [QAToolResult] {
            var results: [QAToolResult] = []

            if config.swiftLintEnabled {
                let result = await runSwiftLint()
                results.append(result)
            }

            // Note: CodeCov, SonarCloud, and DeepSource typically run in CI
            // but we provide methods for local testing/validation

            return results
        }

        /// Run SwiftLint analysis
        func runSwiftLint(autoFix: Bool? = nil) async -> QAToolResult {
            let startTime = Date()
            currentTool = .swiftLint
            isRunning = true

            defer {
                isRunning = false
                currentTool = nil
            }

            let shouldAutoFix = autoFix ?? config.swiftLintAutoFix
            let projectPath = resolveProjectPath()
            let configPath = "\(projectPath)/\(config.swiftLintConfigPath)"

            var arguments = ["lint"]
            if shouldAutoFix {
                arguments = ["lint", "--fix"]
            }
            arguments.append(contentsOf: ["--config", configPath, "--reporter", "json"])

            let (output, exitCode) = await runCommand(
                config.swiftLintExecutablePath,
                arguments: arguments,
                workingDirectory: projectPath
            )

            let duration = Date().timeIntervalSince(startTime)
            let (issues, warnings, errors) = parseSwiftLintOutput(output)

            let result = QAToolResult(
                tool: .swiftLint,
                success: exitCode == 0,
                issuesFound: issues.count,
                warningsFound: warnings,
                errorsFound: errors,
                duration: duration,
                output: output,
                details: issues
            )

            lastResults[.swiftLint] = result
            addToHistory(result)

            return result
        }

        /// Upload coverage to CodeCov
        func uploadCoverage() async -> QAToolResult {
            let startTime = Date()
            currentTool = .codeCov
            isRunning = true

            defer {
                isRunning = false
                currentTool = nil
            }

            guard !config.codeCovToken.isEmpty else {
                let result = QAToolResult(
                    tool: .codeCov,
                    success: false,
                    output: "CodeCov token not configured"
                )
                lastResults[.codeCov] = result
                return result
            }

            let projectPath = resolveProjectPath()

            // First, generate coverage report
            let coverageResult = await generateCoverageReport()
            guard coverageResult.success else {
                return coverageResult
            }

            // Upload to CodeCov using their uploader
            // SECURITY: Pass token via environment variable, not command line args
            let (output, exitCode) = await runCommand(
                "bash",
                arguments: [
                    "-c",
                    "curl -Os https://cli.codecov.io/latest/macos/codecov && " +
                        "chmod +x codecov && " +
                        "./codecov upload-process"
                ],
                workingDirectory: projectPath,
                environment: ["CODECOV_TOKEN": config.codeCovToken]
            )

            let duration = Date().timeIntervalSince(startTime)

            let result = QAToolResult(
                tool: .codeCov,
                success: exitCode == 0,
                duration: duration,
                output: output
            )

            lastResults[.codeCov] = result
            addToHistory(result)

            return result
        }

        /// Run SonarCloud analysis
        func runSonarAnalysis() async -> QAToolResult {
            let startTime = Date()
            currentTool = .sonarCloud
            isRunning = true

            defer {
                isRunning = false
                currentTool = nil
            }

            guard !config.sonarCloudToken.isEmpty else {
                let result = QAToolResult(
                    tool: .sonarCloud,
                    success: false,
                    output: "SonarCloud token not configured"
                )
                lastResults[.sonarCloud] = result
                return result
            }

            guard !config.sonarCloudOrganization.isEmpty else {
                let result = QAToolResult(
                    tool: .sonarCloud,
                    success: false,
                    output: "SonarCloud organization not configured"
                )
                lastResults[.sonarCloud] = result
                return result
            }

            let projectPath = resolveProjectPath()

            // Run sonar-scanner (requires installation: brew install sonar-scanner)
            // SECURITY: Pass token via environment variable, not command line args
            let (output, exitCode) = await runCommand(
                "sonar-scanner",
                arguments: [
                    "-Dsonar.organization=\(config.sonarCloudOrganization)",
                    "-Dsonar.projectKey=\(config.sonarCloudProjectKey)",
                    "-Dsonar.host.url=\(config.sonarCloudBaseURL)"
                ],
                workingDirectory: projectPath,
                environment: ["SONAR_TOKEN": config.sonarCloudToken]
            )

            let duration = Date().timeIntervalSince(startTime)

            let result = QAToolResult(
                tool: .sonarCloud,
                success: exitCode == 0,
                duration: duration,
                output: output
            )

            lastResults[.sonarCloud] = result
            addToHistory(result)

            return result
        }

        /// Run DeepSource analysis
        func runDeepSourceAnalysis() async -> QAToolResult {
            let startTime = Date()
            currentTool = .deepSource
            isRunning = true

            defer {
                isRunning = false
                currentTool = nil
            }

            guard !config.deepSourceDSN.isEmpty else {
                let result = QAToolResult(
                    tool: .deepSource,
                    success: false,
                    output: "DeepSource DSN not configured"
                )
                lastResults[.deepSource] = result
                return result
            }

            let projectPath = resolveProjectPath()

            // DeepSource analysis is typically triggered via git push
            // For local analysis, we can use their CLI if available
            let (output, exitCode) = await runCommand(
                "deepsource",
                arguments: ["report", "--analyzer", "swift"],
                workingDirectory: projectPath,
                environment: ["DEEPSOURCE_DSN": config.deepSourceDSN]
            )

            let duration = Date().timeIntervalSince(startTime)

            let result = QAToolResult(
                tool: .deepSource,
                success: exitCode == 0,
                duration: duration,
                output: output
            )

            lastResults[.deepSource] = result
            addToHistory(result)

            return result
        }

        /// Generate code coverage report using xcodebuild
        func generateCoverageReport() async -> QAToolResult {
            let startTime = Date()
            let projectPath = resolveProjectPath()

            let (output, exitCode) = await runCommand(
                "xcodebuild",
                arguments: [
                    "test",
                    "-scheme", config.xcodeScheme,
                    "-destination", config.xcodeDestination,
                    "-enableCodeCoverage", "YES",
                    "-resultBundlePath", config.testResultBundlePath
                ],
                workingDirectory: projectPath
            )

            let duration = Date().timeIntervalSince(startTime)

            return QAToolResult(
                tool: .codeCov,
                success: exitCode == 0,
                duration: duration,
                output: output
            )
        }

        /// Check if a QA tool is available on the system
        func isToolAvailable(_ tool: QATool) async -> Bool {
            switch tool {
            case .swiftLint:
                let (_, exitCode) = await runCommand("which", arguments: ["swiftlint"])
                return exitCode == 0
            case .codeCov:
                // CodeCov uses curl-based uploader, always available
                return true
            case .sonarCloud:
                let (_, exitCode) = await runCommand("which", arguments: ["sonar-scanner"])
                return exitCode == 0
            case .deepSource:
                let (_, exitCode) = await runCommand("which", arguments: ["deepsource"])
                return exitCode == 0
            }
        }

        /// Get the last result for a specific tool
        func getLastResult(for tool: QATool) -> QAToolResult? {
            lastResults[tool]
        }

        /// Clear history
        func clearHistory() {
            history.removeAll()
            saveHistory()
        }

        // MARK: - Private Helpers

        private func resolveProjectPath() -> String {
            if !config.projectRootPath.isEmpty {
                return config.projectRootPath
            }
            // Dynamic base path for the project
            if let bundlePath = Bundle.main.resourcePath {
                let appPath = (bundlePath as NSString).deletingLastPathComponent
                let devPath = (appPath as NSString).deletingLastPathComponent
                if FileManager.default.fileExists(atPath: (devPath as NSString).appendingPathComponent("Shared")) {
                    return devPath
                }
            }
            // Return current directory as fallback - never hardcode paths
            return FileManager.default.currentDirectoryPath
        }

        private func runCommand(
            _ command: String,
            arguments: [String] = [],
            workingDirectory: String? = nil,
            environment: [String: String]? = nil
        ) async -> (output: String, exitCode: Int32) {
            await withCheckedContinuation { continuation in
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: command)
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = pipe

                if let workingDirectory {
                    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                }

                if let environment {
                    var env = ProcessInfo.processInfo.environment
                    for (key, value) in environment {
                        env[key] = value
                    }
                    process.environment = env
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    continuation.resume(returning: (output, process.terminationStatus))
                } catch {
                    continuation.resume(returning: ("Error: \(error.localizedDescription)", -1))
                }
            }
        }

        private func parseSwiftLintOutput(_ jsonOutput: String) -> (issues: [QAIssue], warnings: Int, errors: Int) {
            var issues: [QAIssue] = []
            var warnings = 0
            var errors = 0

            guard let data = jsonOutput.data(using: .utf8) else {
                return (issues, warnings, errors)
            }

            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in jsonArray {
                        let severityString = item["severity"] as? String ?? "warning"
                        let severity: QAIssueSeverity = severityString == "error" ? .error : .warning

                        if severity == .error {
                            errors += 1
                        } else {
                            warnings += 1
                        }

                        let issue = QAIssue(
                            severity: severity,
                            message: item["reason"] as? String ?? "Unknown issue",
                            file: item["file"] as? String,
                            line: item["line"] as? Int,
                            column: item["character"] as? Int,
                            rule: item["rule_id"] as? String
                        )
                        issues.append(issue)
                    }
                }
            } catch {
                // If JSON parsing fails, try line-by-line parsing
                let lines = jsonOutput.components(separatedBy: "\n")
                for line in lines where line.contains(": error:") || line.contains(": warning:") {
                    let isError = line.contains(": error:")
                    if isError {
                        errors += 1
                    } else {
                        warnings += 1
                    }

                    let issue = QAIssue(
                        severity: isError ? .error : .warning,
                        message: line
                    )
                    issues.append(issue)
                }
            }

            return (issues, warnings, errors)
        }

        // MARK: - Persistence

        private func loadHistory() {
            guard let data = UserDefaults.standard.data(forKey: "QAToolsManager.history"),
                  let decoded = try? JSONDecoder().decode([QAToolResult].self, from: data)
            else {
                return
            }

            // Filter out old entries
            let cutoffDate = Calendar.current.date(
                byAdding: .day,
                value: -config.keepHistoryDays,
                to: Date()
            ) ?? Date()

            history = decoded.filter { $0.timestamp > cutoffDate }

            // Limit entries
            if history.count > config.maxHistoryEntries {
                history = Array(history.suffix(config.maxHistoryEntries))
            }
        }

        private func saveHistory() {
            if let data = try? JSONEncoder().encode(history) {
                UserDefaults.standard.set(data, forKey: "QAToolsManager.history")
            }
        }

        private func addToHistory(_ result: QAToolResult) {
            history.append(result)

            // Trim history if needed
            if history.count > config.maxHistoryEntries {
                history = Array(history.suffix(config.maxHistoryEntries))
            }

            saveHistory()

            // Post notification if enabled
            if config.showQANotifications {
                postQANotification(for: result)
            }
        }

        private func postQANotification(for result: QAToolResult) {
            let content = UNMutableNotificationContent()
            content.title = "QA: \(result.tool.displayName)"
            content.body = result.success ? "✅ Passed" : "❌ Failed — check results"
            content.sound = result.success ? .default : .defaultCritical

            let request = UNNotificationRequest(
                identifier: "qa-\(result.tool.rawValue)-\(Date.now.timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("QA notification error: \(error.localizedDescription)")
                }
            }
        }
    }

#endif
