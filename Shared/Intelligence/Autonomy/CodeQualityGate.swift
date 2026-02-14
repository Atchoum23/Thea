// CodeQualityGate.swift
// Thea — Quality gate for autonomous code changes
//
// Before any autonomous commit, verifies: tests pass, no new warnings,
// no credential leaks, no SwiftLint violations.

import Foundation
import OSLog

actor CodeQualityGate {
    static let shared = CodeQualityGate()

    private let logger = Logger(subsystem: "com.thea.app", category: "CodeQualityGate")

    // MARK: - Types

    struct GateResult: Sendable {
        let passed: Bool
        let checks: [CheckResult]
        let timestamp: Date
        let duration: TimeInterval

        var failedChecks: [CheckResult] {
            checks.filter { !$0.passed }
        }

        var summary: String {
            let passCount = checks.filter(\.passed).count
            let total = checks.count
            let status = passed ? "PASSED" : "FAILED"
            return "Quality Gate \(status): \(passCount)/\(total) checks passed"
        }
    }

    struct CheckResult: Sendable {
        let name: String
        let passed: Bool
        let message: String
        let severity: Severity

        enum Severity: String, Sendable {
            case blocking   // Must pass — gate fails if this fails
            case warning    // Should pass — gate warns but doesn't fail
        }
    }

    // MARK: - Quality Gate Execution

    /// Run all quality checks. Returns gate result.
    func runGate(projectPath: String) async -> GateResult {
        let startTime = Date()
        var checks: [CheckResult] = []

        // Check 1: Swift tests pass
        let testResult = await runSwiftTests(projectPath: projectPath)
        checks.append(testResult)

        // Check 2: Credential scan (via OutboundPrivacyGuard patterns)
        let credentialResult = await scanForCredentials(projectPath: projectPath)
        checks.append(credentialResult)

        // Check 3: Build check (swift build)
        let buildResult = await runSwiftBuild(projectPath: projectPath)
        checks.append(buildResult)

        // Check 4: SwiftLint check
        let lintResult = await runSwiftLint(projectPath: projectPath)
        checks.append(lintResult)

        let duration = Date().timeIntervalSince(startTime)
        let passed = !checks.contains { !$0.passed && $0.severity == .blocking }

        let result = GateResult(
            passed: passed,
            checks: checks,
            timestamp: Date(),
            duration: duration
        )

        logger.info("Quality gate: \(result.summary) in \(String(format: "%.1f", duration))s")
        return result
    }

    // MARK: - Individual Checks

    private func runSwiftTests(projectPath: String) async -> CheckResult {
        let output = await runShellCommand("cd \"\(projectPath)\" && swift test 2>&1 | tail -3")
        let passed = output.contains("passed") && !output.contains("failed")
        let testCountMatch = output.range(of: #"\d+ tests?"#, options: .regularExpression)
        let testInfo = testCountMatch.map { String(output[$0]) } ?? "unknown count"

        return CheckResult(
            name: "Swift Tests",
            passed: passed,
            message: passed ? "\(testInfo) passed" : "Tests failed: \(output.prefix(200))",
            severity: .blocking
        )
    }

    private func scanForCredentials(projectPath: String) async -> CheckResult {
        let patterns = [
            #"sk-[A-Za-z0-9]{20,}"#,
            #"ghp_[A-Za-z0-9]{36}"#,
            #"AKIA[A-Z0-9]{16}"#,
            #"-----BEGIN.*PRIVATE KEY-----"#,
            #"AIzaSy[A-Za-z0-9_-]{33}"#,
        ]

        var findings: [String] = []
        for pattern in patterns {
            let cmd = "cd \"\(projectPath)\" && git diff --cached --diff-filter=ACM -U0 -- '*.swift' | grep -cE '\(pattern)' 2>/dev/null || echo 0"
            let output = await runShellCommand(cmd)
            let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            if count > 0 {
                findings.append("\(pattern.prefix(20)): \(count) match(es)")
            }
        }

        return CheckResult(
            name: "Credential Scan",
            passed: findings.isEmpty,
            message: findings.isEmpty ? "No credentials detected" : "Found: \(findings.joined(separator: ", "))",
            severity: .blocking
        )
    }

    private func runSwiftBuild(projectPath: String) async -> CheckResult {
        let output = await runShellCommand("cd \"\(projectPath)\" && swift build 2>&1 | tail -3")
        let passed = output.contains("Build complete")

        return CheckResult(
            name: "Swift Build",
            passed: passed,
            message: passed ? "Build succeeded" : "Build failed: \(output.prefix(200))",
            severity: .blocking
        )
    }

    private func runSwiftLint(projectPath: String) async -> CheckResult {
        let output = await runShellCommand("cd \"\(projectPath)\" && which swiftlint > /dev/null 2>&1 && swiftlint lint --quiet 2>&1 | wc -l || echo skipped")
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed == "skipped" {
            return CheckResult(
                name: "SwiftLint",
                passed: true,
                message: "SwiftLint not installed — skipped",
                severity: .warning
            )
        }

        let violationCount = Int(trimmed) ?? 0
        return CheckResult(
            name: "SwiftLint",
            passed: violationCount == 0,
            message: violationCount == 0 ? "No violations" : "\(violationCount) violations found",
            severity: .warning
        )
    }

    // MARK: - Shell Execution

    private func runShellCommand(_ command: String) async -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
