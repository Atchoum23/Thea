// IntegratedTestRunner+ResultParsing.swift
// Thea V2
//
// Result parsing and helper methods for IntegratedTestRunner

import Foundation

#if os(macOS)

extension IntegratedTestRunner {

    // MARK: - Result Parsing

    func parseTestOutput(
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

    // MARK: - XCTest / Swift Testing

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
                    let duration = Double(
                        components.last?.replacingOccurrences(of: ")", with: "") ?? "0"
                    ) ?? 0

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
                    let duration = Double(
                        components.last?.replacingOccurrences(of: ")", with: "") ?? "0"
                    ) ?? 0

                    results.append(TestCaseResult(
                        name: testName ?? "unknown",
                        className: className,
                        status: .failed,
                        duration: duration,
                        errorMessage: extractErrorMessage(
                            from: errorOutput,
                            testName: testName ?? ""
                        )
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Python

    private func parsePytestOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        // Try JSON parsing first
        if let jsonData = output.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
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
            } catch {
                // JSON parse failed — fall through to text parsing below
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

    // MARK: - JavaScript / TypeScript

    private func parseJestOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        if let jsonData = output.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let testResults = json["testResults"] as? [[String: Any]] {
                    for file in testResults {
                        if let assertionResults = file["assertionResults"] as? [[String: Any]] {
                            for test in assertionResults {
                                let name = test["fullName"] as? String
                                    ?? test["title"] as? String
                                    ?? "unknown"
                                let statusStr = test["status"] as? String ?? "unknown"
                                let duration = (test["duration"] as? Double ?? 0) / 1000

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
                                    errorMessage: (test["failureMessages"] as? [String])?
                                        .joined(separator: "\n")
                                ))
                            }
                        }
                    }
                }
            } catch {
                // JSON parse failed — no Jest output to parse
            }
        }

        return results
    }

    private func parseMochaOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        if let jsonData = output.data(using: .utf8) {
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    if let passes = json["passes"] as? [[String: Any]] {
                        for test in passes {
                            let name = test["fullTitle"] as? String
                                ?? test["title"] as? String
                                ?? "unknown"
                            let duration = (test["duration"] as? Double ?? 0) / 1000
                            results.append(TestCaseResult(
                                name: name, status: .passed, duration: duration
                            ))
                        }
                    }
                    if let failures = json["failures"] as? [[String: Any]] {
                        for test in failures {
                            let name = test["fullTitle"] as? String
                                ?? test["title"] as? String
                                ?? "unknown"
                            let duration = (test["duration"] as? Double ?? 0) / 1000
                            let error = (test["err"] as? [String: Any])?["message"] as? String
                            results.append(TestCaseResult(
                                name: name, status: .failed, duration: duration, errorMessage: error
                            ))
                        }
                    }
                }
            } catch {
                // JSON parse failed — no Mocha output to parse
            }
        }

        return results
    }

    private func parseVitestOutput(output: String) -> [TestCaseResult] {
        // Similar to Jest parsing
        parseJestOutput(output: output)
    }

    // MARK: - Go

    private func parseGoTestOutput(output: String) -> [TestCaseResult] {
        var results: [TestCaseResult] = []

        for line in output.components(separatedBy: .newlines) {
            guard let data = line.data(using: .utf8) else { continue }
            let json: [String: Any]
            do {
                guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                json = parsed
            } catch {
                continue // not valid JSON line
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

    // MARK: - Rust

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

    func parseCoverageReport(
        output: String,
        framework: TestFramework,
        // periphery:ignore - Reserved: output parameter kept for API compatibility
        // periphery:ignore - Reserved: framework parameter kept for API compatibility
        // periphery:ignore - Reserved: projectPath parameter kept for API compatibility
        projectPath: String
    ) -> CoverageReport? {
        // Simplified coverage parsing - would need framework-specific handling
        nil
    }

    // MARK: - Helper Methods

    func findProjectRoot(from filePath: String) -> String {
        var current = (filePath as NSString).deletingLastPathComponent
        let fileManager = FileManager.default

        let markers = [
            "Package.swift", "package.json", "Cargo.toml",
            "go.mod", "setup.py", "pyproject.toml"
        ]

        while current != "/" {
            for marker in markers {
                let markerPath = (current as NSString).appendingPathComponent(marker)
                if fileManager.fileExists(atPath: markerPath) {
                    return current
                }
            }

            // Check for .xcodeproj or .xcworkspace
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: current)
                if contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
                    return current
                }
            } catch {
                // Can't read this directory — continue searching upward
            }

            current = (current as NSString).deletingLastPathComponent
        }

        return (filePath as NSString).deletingLastPathComponent
    }

    func extractTestPattern(from filePath: String, framework: TestFramework) -> String {
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

    func extractErrorMessage(from errorOutput: String, testName: String) -> String? {
        // Find error message related to the test
        let lines = errorOutput.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() where line.contains(testName) {
            if index + 1 < lines.count {
                return lines[index + 1]
            }
        }
        return nil
    }
}

#endif  // os(macOS)
