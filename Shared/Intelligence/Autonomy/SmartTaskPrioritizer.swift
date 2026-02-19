// SmartTaskPrioritizer.swift
// AI-driven task prioritization based on codebase quality signals

#if os(macOS)
import Foundation
import os.log

/// Analyzes codebase quality signals and dynamically prioritizes work items.
/// Uses test coverage, lint violations, build warnings, and crash reports
/// to determine what should be worked on next.
// periphery:ignore - Reserved: SmartTaskPrioritizer type reserved for future feature activation
actor SmartTaskPrioritizer {
    static let shared = SmartTaskPrioritizer()

    private let logger = Logger(subsystem: "ai.thea.app", category: "TaskPrioritizer")

    // MARK: - Types

    struct QualitySignal: Codable, Sendable {
        let testCount: Int
        let testsPassing: Bool
        let lintViolations: Int
        let buildWarnings: Int
        let buildErrors: Int
        let coveragePercent: Double
        let timestamp: Date

        static var empty: QualitySignal {
            QualitySignal(
                testCount: 0,
                testsPassing: true,
                lintViolations: 0,
                buildWarnings: 0,
                buildErrors: 0,
                coveragePercent: 0,
                timestamp: Date()
            )
        }
    }

    enum WorkCategory: String, Codable, Sendable, CaseIterable {
        case fixBuildErrors
        case fixFailingTests
        case fixLintViolations
        case reduceBuildWarnings
        case increaseTestCoverage
        case stubRemediation
        case featureImplementation
        case performanceOptimization
        case securityHardening
        case documentation

        var basePriority: Int {
            switch self {
            case .fixBuildErrors: return 100
            case .fixFailingTests: return 90
            case .fixLintViolations: return 70
            case .reduceBuildWarnings: return 60
            case .increaseTestCoverage: return 50
            case .stubRemediation: return 45
            case .featureImplementation: return 40
            case .performanceOptimization: return 30
            case .securityHardening: return 35
            case .documentation: return 20
            }
        }

        var description: String {
            switch self {
            case .fixBuildErrors: return "Fix build errors to restore compilation"
            case .fixFailingTests: return "Fix failing tests to restore test suite"
            case .fixLintViolations: return "Fix SwiftLint violations"
            case .reduceBuildWarnings: return "Reduce build warnings"
            case .increaseTestCoverage: return "Increase test coverage"
            case .stubRemediation: return "Replace stub implementations"
            case .featureImplementation: return "Implement new features"
            case .performanceOptimization: return "Optimize performance"
            case .securityHardening: return "Improve security posture"
            case .documentation: return "Improve documentation"
            }
        }
    }

    struct PrioritizedTask: Codable, Sendable, Identifiable {
        let id: UUID
        let category: WorkCategory
        let title: String
        let reason: String
        let priority: Int
        let estimatedEffort: String
        let timestamp: Date

        init(category: WorkCategory, title: String, reason: String, priority: Int, estimatedEffort: String) {
            self.id = UUID()
            self.category = category
            self.title = title
            self.reason = reason
            self.priority = priority
            self.estimatedEffort = estimatedEffort
            self.timestamp = Date()
        }
    }

    // MARK: - State

    private var lastSignal: QualitySignal?
    private var taskHistory: [PrioritizedTask] = []
    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let theaDir = appSupport.appendingPathComponent("Thea")
        do {
            try FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        } catch {
            logger.debug("Could not create Thea directory: \(error.localizedDescription)")
        }
        storageURL = theaDir.appendingPathComponent("task_priorities.json")

        // Load persisted history
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let data = try Data(contentsOf: storageURL)
                taskHistory = try JSONDecoder().decode([PrioritizedTask].self, from: data)
            } catch {
                logger.debug("Could not load task history: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Public API

    /// Collects current quality signals from the codebase
    func collectSignals() async -> QualitySignal {
        let testResult = await runCommand("cd \"/Users/alexis/Documents/IT & Tech/MyApps/Thea\" && swift test 2>&1 | tail -5")
        let testCount = parseTestCount(from: testResult)
        let testsPassing = testResult.contains("passed")

        let lintResult = await runCommand("cd \"/Users/alexis/Documents/IT & Tech/MyApps/Thea\" && swiftlint lint --quiet 2>&1 | wc -l")
        let lintViolations = Int(lintResult.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let buildResult = await runCommand(
            "cd \"/Users/alexis/Documents/IT & Tech/MyApps/Thea\" && " +
            "xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -destination 'platform=macOS' " +
            "CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO " +
            "build 2>&1 | grep -c 'warning:'"
        )
        let buildWarnings = Int(buildResult.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let signal = QualitySignal(
            testCount: testCount,
            testsPassing: testsPassing,
            lintViolations: lintViolations,
            buildWarnings: buildWarnings,
            buildErrors: 0,
            coveragePercent: 0,
            timestamp: Date()
        )

        lastSignal = signal
        logger.info("Quality signals collected: \(testCount) tests, \(lintViolations) lint, \(buildWarnings) warnings")
        return signal
    }

    /// Generates prioritized task list based on quality signals
    func prioritize(signal: QualitySignal? = nil) -> [PrioritizedTask] {
        let sig = signal ?? lastSignal ?? .empty
        var tasks: [PrioritizedTask] = []

        // Build errors are highest priority
        if sig.buildErrors > 0 {
            tasks.append(PrioritizedTask(
                category: .fixBuildErrors,
                title: "Fix \(sig.buildErrors) build errors",
                reason: "Build is broken — nothing else can proceed until this is fixed",
                priority: 100,
                estimatedEffort: "1-4 hours"
            ))
        }

        // Failing tests
        if !sig.testsPassing {
            tasks.append(PrioritizedTask(
                category: .fixFailingTests,
                title: "Fix failing tests",
                reason: "Tests must pass before any new work can be verified",
                priority: 90,
                estimatedEffort: "30 min - 2 hours"
            ))
        }

        // Lint violations
        if sig.lintViolations > 0 {
            let urgency = min(sig.lintViolations * 2, 30)
            tasks.append(PrioritizedTask(
                category: .fixLintViolations,
                title: "Fix \(sig.lintViolations) SwiftLint violations",
                reason: "Code quality regressions compound over time",
                priority: WorkCategory.fixLintViolations.basePriority + urgency,
                estimatedEffort: sig.lintViolations < 10 ? "15 min" : "30 min - 1 hour"
            ))
        }

        // Build warnings
        if sig.buildWarnings > 5 {
            tasks.append(PrioritizedTask(
                category: .reduceBuildWarnings,
                title: "Reduce \(sig.buildWarnings) build warnings",
                reason: "Warnings hide real issues and indicate code quality decline",
                priority: WorkCategory.reduceBuildWarnings.basePriority + min(sig.buildWarnings, 20),
                estimatedEffort: "30 min - 2 hours"
            ))
        }

        // Test coverage
        if sig.testCount < 2000 {
            tasks.append(PrioritizedTask(
                category: .increaseTestCoverage,
                title: "Add more tests (currently \(sig.testCount))",
                reason: "Higher test count improves regression detection",
                priority: WorkCategory.increaseTestCoverage.basePriority,
                estimatedEffort: "1-3 hours"
            ))
        }

        // Feature implementation (always lowest urgency but always available)
        tasks.append(PrioritizedTask(
            category: .featureImplementation,
            title: "Continue feature implementation",
            reason: "Implement next capability from the ADDENDA priority list",
            priority: WorkCategory.featureImplementation.basePriority,
            estimatedEffort: "2-8 hours"
        ))

        // Sort by priority descending
        tasks.sort { $0.priority > $1.priority }
        taskHistory.append(contentsOf: tasks)
        saveHistory()
        return tasks
    }

    /// Returns the single highest-priority task
    func nextTask(signal: QualitySignal? = nil) -> PrioritizedTask? {
        prioritize(signal: signal).first
    }

    // MARK: - Helpers

    private func parseTestCount(from output: String) -> Int {
        // Match pattern like "Test run with 2027 tests"
        if let range = output.range(of: #"(\d+) tests?"#, options: .regularExpression) {
            let match = output[range]
            let digits = match.filter(\.isNumber)
            return Int(digits) ?? 0
        }
        return 0
    }

    private func runCommand(_ command: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", command]
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    // MARK: - Persistence

    private func saveHistory() {
        // Keep last 100 tasks
        if taskHistory.count > 100 {
            taskHistory = Array(taskHistory.suffix(100))
        }
        do {
            let data = try JSONEncoder().encode(taskHistory)
            try data.write(to: storageURL)
        } catch {
            logger.error("Failed to save task history: \(error.localizedDescription)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            taskHistory = try JSONDecoder().decode([PrioritizedTask].self, from: data)
        } catch {
            logger.debug("Could not load task history: \(error.localizedDescription)")
        }
    }
}
#endif
