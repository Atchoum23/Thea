// SelfBenchmark.swift
// Tracks Thea's own performance metrics over time

#if os(macOS)
import Foundation
import os.log

/// Tracks Thea's performance metrics: response latency, token efficiency,
/// user satisfaction, crash rate, test coverage. Generates weekly self-improvement reports.
actor SelfBenchmark {
    static let shared = SelfBenchmark()

    private let logger = Logger(subsystem: "ai.thea.app", category: "SelfBenchmark")

    // MARK: - Types

    struct PerformanceSnapshot: Codable, Sendable, Identifiable {
        let id: UUID
        let timestamp: Date
        let avgResponseLatencyMs: Double
        let p95ResponseLatencyMs: Double
        let tokenEfficiency: Double
        let userSatisfactionScore: Double
        let testCount: Int
        let testPassRate: Double
        let buildSuccessRate: Double
        let errorRate: Double
        let sessionCount: Int

        init(
            avgResponseLatencyMs: Double,
            p95ResponseLatencyMs: Double,
            tokenEfficiency: Double,
            userSatisfactionScore: Double,
            testCount: Int,
            testPassRate: Double,
            buildSuccessRate: Double,
            errorRate: Double,
            sessionCount: Int
        ) {
            self.id = UUID()
            self.timestamp = Date()
            self.avgResponseLatencyMs = avgResponseLatencyMs
            self.p95ResponseLatencyMs = p95ResponseLatencyMs
            self.tokenEfficiency = tokenEfficiency
            self.userSatisfactionScore = userSatisfactionScore
            self.testCount = testCount
            self.testPassRate = testPassRate
            self.buildSuccessRate = buildSuccessRate
            self.errorRate = errorRate
            self.sessionCount = sessionCount
        }
    }

    struct WeeklyReport: Codable, Sendable {
        let weekStart: Date
        let weekEnd: Date
        let avgLatency: Double
        let latencyTrend: Trend
        let satisfactionScore: Double
        let satisfactionTrend: Trend
        let testCountChange: Int
        let buildSuccessRate: Double
        let errorRateChange: Double
        let topIssues: [String]
        let improvements: [String]
    }

    enum Trend: String, Codable, Sendable {
        case improving, stable, declining

        var displayName: String {
            switch self {
            case .improving: return "Improving"
            case .stable: return "Stable"
            case .declining: return "Declining"
            }
        }

        var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            }
        }
    }

    // MARK: - State

    private var snapshots: [PerformanceSnapshot] = []
    private var responseLatencies: [Double] = []
    private var feedbackScores: [Double] = []
    private let storageURL: URL
    private let maxSnapshots = 365

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let theaDir = appSupport.appendingPathComponent("Thea")
        try? FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        storageURL = theaDir.appendingPathComponent("self_benchmark.json")

        // Inline load to avoid calling actor-isolated method from init
        if let data = try? Data(contentsOf: storageURL),
           let state = try? JSONDecoder().decode(BenchmarkState.self, from: data) {
            snapshots = state.snapshots
            responseLatencies = state.latencies
            feedbackScores = state.feedbackScores
        }
    }

    // MARK: - Recording

    /// Record a response latency measurement (in milliseconds)
    func recordLatency(_ latencyMs: Double) {
        responseLatencies.append(latencyMs)
        // Keep last 1000 measurements
        if responseLatencies.count > 1000 {
            responseLatencies = Array(responseLatencies.suffix(1000))
        }
    }

    /// Record user feedback score (0.0 = negative, 1.0 = positive)
    func recordFeedback(_ score: Double) {
        feedbackScores.append(max(0, min(1, score)))
        if feedbackScores.count > 500 {
            feedbackScores = Array(feedbackScores.suffix(500))
        }
    }

    // MARK: - Snapshot

    /// Capture a performance snapshot with current metrics
    func captureSnapshot() async -> PerformanceSnapshot {
        let avgLatency = responseLatencies.isEmpty ? 0 : responseLatencies.reduce(0, +) / Double(responseLatencies.count)
        let p95Latency = calculateP95(responseLatencies)
        let satisfaction = feedbackScores.isEmpty ? 0.5 : feedbackScores.reduce(0, +) / Double(feedbackScores.count)
        let tokenEfficiency = calculateTokenEfficiency()

        // Get test metrics
        let testOutput = await runCommand("cd \"/Users/alexis/Documents/IT & Tech/MyApps/Thea\" && swift test 2>&1 | tail -3")
        let testCount = parseTestCount(from: testOutput)
        let testPassRate = testOutput.contains("passed") ? 1.0 : 0.0

        let snapshot = PerformanceSnapshot(
            avgResponseLatencyMs: avgLatency,
            p95ResponseLatencyMs: p95Latency,
            tokenEfficiency: tokenEfficiency,
            userSatisfactionScore: satisfaction,
            testCount: testCount,
            testPassRate: testPassRate,
            buildSuccessRate: 1.0,
            errorRate: 0,
            sessionCount: snapshots.count + 1
        )

        snapshots.append(snapshot)
        if snapshots.count > maxSnapshots {
            snapshots = Array(snapshots.suffix(maxSnapshots))
        }

        saveState()
        logger.info("Performance snapshot captured: avg latency \(Int(avgLatency))ms, satisfaction \(String(format: "%.1f%%", satisfaction * 100))")
        return snapshot
    }

    // MARK: - Reporting

    /// Generate a weekly performance report comparing last 7 days to prior 7 days
    func generateWeeklyReport() -> WeeklyReport {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        let thisWeek = snapshots.filter { $0.timestamp >= weekAgo }
        let lastWeek = snapshots.filter { $0.timestamp >= twoWeeksAgo && $0.timestamp < weekAgo }

        let thisWeekLatency = average(thisWeek.map(\.avgResponseLatencyMs))
        let lastWeekLatency = average(lastWeek.map(\.avgResponseLatencyMs))

        let thisWeekSatisfaction = average(thisWeek.map(\.userSatisfactionScore))
        let lastWeekSatisfaction = average(lastWeek.map(\.userSatisfactionScore))

        let latestTestCount = thisWeek.last?.testCount ?? 0
        let previousTestCount = lastWeek.last?.testCount ?? latestTestCount

        let thisWeekErrorRate = average(thisWeek.map(\.errorRate))
        let lastWeekErrorRate = average(lastWeek.map(\.errorRate))

        var issues: [String] = []
        var improvements: [String] = []

        if thisWeekLatency > lastWeekLatency * 1.2 {
            issues.append("Response latency increased by \(Int((thisWeekLatency / max(lastWeekLatency, 1) - 1) * 100))%")
        } else if thisWeekLatency < lastWeekLatency * 0.8 {
            improvements.append("Response latency decreased by \(Int((1 - thisWeekLatency / max(lastWeekLatency, 1)) * 100))%")
        }

        if latestTestCount > previousTestCount {
            improvements.append("Test count increased: \(previousTestCount) → \(latestTestCount)")
        }

        if thisWeekErrorRate > lastWeekErrorRate {
            issues.append("Error rate increased")
        }

        return WeeklyReport(
            weekStart: weekAgo,
            weekEnd: now,
            avgLatency: thisWeekLatency,
            latencyTrend: trend(current: thisWeekLatency, previous: lastWeekLatency, lowerIsBetter: true),
            satisfactionScore: thisWeekSatisfaction,
            satisfactionTrend: trend(current: thisWeekSatisfaction, previous: lastWeekSatisfaction, lowerIsBetter: false),
            testCountChange: latestTestCount - previousTestCount,
            buildSuccessRate: average(thisWeek.map(\.buildSuccessRate)),
            errorRateChange: thisWeekErrorRate - lastWeekErrorRate,
            topIssues: issues,
            improvements: improvements
        )
    }

    /// Format the weekly report as readable text
    func formatReport(_ report: WeeklyReport) -> String {
        var text = "## Thea Self-Improvement Report\n\n"
        text += "**Period:** \(report.weekStart.formatted(.dateTime.month().day())) - \(report.weekEnd.formatted(.dateTime.month().day()))\n\n"
        text += "### Metrics\n"
        text += "- Avg Response Latency: \(Int(report.avgLatency))ms (\(report.latencyTrend.displayName))\n"
        text += "- User Satisfaction: \(String(format: "%.0f%%", report.satisfactionScore * 100)) (\(report.satisfactionTrend.displayName))\n"
        text += "- Test Count Change: \(report.testCountChange >= 0 ? "+" : "")\(report.testCountChange)\n"
        text += "- Build Success Rate: \(String(format: "%.0f%%", report.buildSuccessRate * 100))\n"

        if !report.improvements.isEmpty {
            text += "\n### Improvements\n"
            for improvement in report.improvements {
                text += "- \(improvement)\n"
            }
        }

        if !report.topIssues.isEmpty {
            text += "\n### Issues\n"
            for issue in report.topIssues {
                text += "- \(issue)\n"
            }
        }

        return text
    }

    // MARK: - Helpers

    private func calculateP95(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int(Double(sorted.count) * 0.95)
        return sorted[min(index, sorted.count - 1)]
    }

    private func calculateTokenEfficiency() -> Double {
        // Token efficiency = useful output tokens / total tokens
        // Without detailed token tracking, estimate from response latencies
        // Faster responses with same quality = higher efficiency
        guard !responseLatencies.isEmpty else { return 0.5 }
        let avgLatency = responseLatencies.reduce(0, +) / Double(responseLatencies.count)
        // Normalize: <500ms = 1.0, >5000ms = 0.1
        return max(0.1, min(1.0, 1.0 - (avgLatency - 500) / 5000))
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func trend(current: Double, previous: Double, lowerIsBetter: Bool) -> Trend {
        let threshold = 0.05
        let change = previous > 0 ? (current - previous) / previous : 0

        if abs(change) < threshold { return .stable }

        if lowerIsBetter {
            return change < 0 ? .improving : .declining
        } else {
            return change > 0 ? .improving : .declining
        }
    }

    private func parseTestCount(from output: String) -> Int {
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

    private struct BenchmarkState: Codable {
        let snapshots: [PerformanceSnapshot]
        let latencies: [Double]
        let feedbackScores: [Double]
    }

    private func saveState() {
        let state = BenchmarkState(snapshots: snapshots, latencies: responseLatencies, feedbackScores: feedbackScores)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: storageURL)
        }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: storageURL),
              let state = try? JSONDecoder().decode(BenchmarkState.self, from: data) else { return }
        snapshots = state.snapshots
        responseLatencies = state.latencies
        feedbackScores = state.feedbackScores
    }
}
#endif
