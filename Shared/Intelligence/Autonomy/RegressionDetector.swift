// RegressionDetector.swift
// Thea — Detects quality regressions between autonomous sessions
//
// Compares test count, build warnings, and SwiftLint violations
// before and after each autonomous session. Flags regressions.

import Foundation
import OSLog

#if os(macOS)
// periphery:ignore - Reserved: RegressionDetector type reserved for future feature activation
actor RegressionDetector {
    static let shared = RegressionDetector()

    private let logger = Logger(subsystem: "com.thea.app", category: "RegressionDetector")

    // MARK: - Types

    struct Snapshot: Codable, Sendable {
        let timestamp: Date
        let testCount: Int
        let testsPassing: Bool
        let buildWarningCount: Int
        let swiftLintViolations: Int
        let buildSucceeded: Bool
        let commitHash: String?

        static let empty = Snapshot(
            timestamp: Date(),
            testCount: 0,
            testsPassing: false,
            buildWarningCount: 0,
            swiftLintViolations: 0,
            buildSucceeded: false,
            commitHash: nil
        )
    }

    struct RegressionReport: Sendable {
        let before: Snapshot
        let after: Snapshot
        let regressions: [Regression]
        let improvements: [Improvement]

        var hasRegressions: Bool { !regressions.isEmpty }
        var isClean: Bool { regressions.isEmpty }

        var summary: String {
            if isClean {
                let improvementText = improvements.isEmpty
                    ? "No regressions detected."
                    : "No regressions. \(improvements.count) improvement(s): \(improvements.map(\.description).joined(separator: ", "))"
                return improvementText
            }
            return "REGRESSIONS DETECTED: \(regressions.map(\.description).joined(separator: "; "))"
        }
    }

    struct Regression: Sendable {
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

    struct Improvement: Sendable {
        let description: String
    }

    // MARK: - Snapshot Capture

    func captureSnapshot(projectPath: String) async -> Snapshot {
        let commitHash = await getCommitHash(projectPath: projectPath)
        let testResult = await runTests(projectPath: projectPath)
        let buildResult = await checkBuild(projectPath: projectPath)
        let lintResult = await checkLint(projectPath: projectPath)

        return Snapshot(
            timestamp: Date(),
            testCount: testResult.count,
            testsPassing: testResult.allPassing,
            buildWarningCount: buildResult.warningCount,
            swiftLintViolations: lintResult,
            buildSucceeded: buildResult.succeeded,
            commitHash: commitHash
        )
    }

    // MARK: - Regression Detection

    func compare(before: Snapshot, after: Snapshot) -> RegressionReport {
        var regressions: [Regression] = []
        var improvements: [Improvement] = []

        // Test count must not decrease
        if after.testCount < before.testCount {
            regressions.append(Regression(
                category: .testCountDecreased,
                description: "Test count decreased: \(before.testCount) → \(after.testCount) (-\(before.testCount - after.testCount))"
            ))
        } else if after.testCount > before.testCount {
            improvements.append(Improvement(
                description: "Test count increased: \(before.testCount) → \(after.testCount) (+\(after.testCount - before.testCount))"
            ))
        }

        // Tests must still pass
        if before.testsPassing && !after.testsPassing {
            regressions.append(Regression(
                category: .testsNowFailing,
                description: "Tests were passing, now failing"
            ))
        } else if !before.testsPassing && after.testsPassing {
            improvements.append(Improvement(description: "Tests now passing"))
        }

        // Build must not break
        if before.buildSucceeded && !after.buildSucceeded {
            regressions.append(Regression(
                category: .buildBroken,
                description: "Build was succeeding, now failing"
            ))
        } else if !before.buildSucceeded && after.buildSucceeded {
            improvements.append(Improvement(description: "Build now succeeding"))
        }

        // Warnings must not increase
        if after.buildWarningCount > before.buildWarningCount {
            regressions.append(Regression(
                category: .moreWarnings,
                description: "Build warnings increased: \(before.buildWarningCount) → \(after.buildWarningCount)"
            ))
        } else if after.buildWarningCount < before.buildWarningCount {
            improvements.append(Improvement(
                description: "Build warnings decreased: \(before.buildWarningCount) → \(after.buildWarningCount)"
            ))
        }

        // SwiftLint violations must not increase
        if after.swiftLintViolations > before.swiftLintViolations {
            regressions.append(Regression(
                category: .moreLintViolations,
                description: "SwiftLint violations increased: \(before.swiftLintViolations) → \(after.swiftLintViolations)"
            ))
        } else if after.swiftLintViolations < before.swiftLintViolations {
            improvements.append(Improvement(
                description: "SwiftLint violations decreased: \(before.swiftLintViolations) → \(after.swiftLintViolations)"
            ))
        }

        let report = RegressionReport(
            before: before,
            after: after,
            regressions: regressions,
            improvements: improvements
        )

        if report.hasRegressions {
            logger.warning("⚠️ \(report.summary)")
        } else {
            logger.info("✅ \(report.summary)")
        }

        return report
    }

    // MARK: - Snapshot Persistence

    private var storagePath: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("Thea/regression_snapshots.json")
    }

    func saveSnapshot(_ snapshot: Snapshot) {
        var history = loadHistory()
        history.append(snapshot)

        // Keep last 50 snapshots
        if history.count > 50 {
            history = Array(history.suffix(50))
        }

        do {
            let dir = storagePath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(history)
            try data.write(to: storagePath)
        } catch {
            logger.error("Failed to save snapshot: \(error.localizedDescription)")
        }
    }

    func loadHistory() -> [Snapshot] {
        let data: Data
        do {
            data = try Data(contentsOf: storagePath)
        } catch {
            // File may not exist yet — not an error on first run
            logger.debug("No regression snapshot history found: \(error.localizedDescription)")
            return []
        }
        do {
            return try JSONDecoder().decode([Snapshot].self, from: data)
        } catch {
            logger.error("Failed to decode regression snapshots: \(error.localizedDescription)")
            return []
        }
    }

    func lastSnapshot() -> Snapshot? {
        loadHistory().last
    }

    // MARK: - Helpers

    private func getCommitHash(projectPath: String) async -> String? {
        let output = await runShell("cd \"\(projectPath)\" && git rev-parse --short HEAD 2>/dev/null")
        let hash = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return hash.isEmpty ? nil : hash
    }

    private func runTests(projectPath: String) async -> (count: Int, allPassing: Bool) {
        let output = await runShell("cd \"\(projectPath)\" && swift test 2>&1 | tail -5")
        let allPassing = output.contains("passed") && !output.contains("failed")

        // Parse test count from "Test run with N tests" pattern
        var count = 0
        if let range = output.range(of: #"(\d+) tests?"#, options: .regularExpression) {
            let match = String(output[range])
            let digits = match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            count = Int(digits) ?? 0
        }

        return (count, allPassing)
    }

    private func checkBuild(projectPath: String) async -> (succeeded: Bool, warningCount: Int) {
        let output = await runShell("cd \"\(projectPath)\" && swift build 2>&1")
        let succeeded = output.contains("Build complete")
        let warningCount = output.components(separatedBy: "warning:").count - 1
        return (succeeded, max(0, warningCount))
    }

    private func checkLint(projectPath: String) async -> Int {
        let output = await runShell("cd \"\(projectPath)\" && which swiftlint > /dev/null 2>&1 && swiftlint lint --quiet 2>&1 | wc -l || echo 0")
        return Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func runShell(_ command: String) async -> String {
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
            return ""
        }
    }
}
#endif
