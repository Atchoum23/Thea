import Foundation

// MARK: - Performance Metrics
// Tracks and analyzes performance of AI interactions and system operations

/// A performance metric data point
public struct MetricDataPoint: Sendable, Codable, Identifiable {
    public let id: UUID
    public let metricType: MetricType
    public let value: Double
    public let unit: String
    public let timestamp: Date
    public let context: [String: String]

    public init(
        id: UUID = UUID(),
        metricType: MetricType,
        value: Double,
        unit: String = "",
        timestamp: Date = Date(),
        context: [String: String] = [:]
    ) {
        self.id = id
        self.metricType = metricType
        self.value = value
        self.unit = unit
        self.timestamp = timestamp
        self.context = context
    }
}

/// Types of metrics tracked
public enum MetricType: String, Codable, Sendable, CaseIterable {
    // Response metrics
    case responseTime           // Time to first token
    case totalResponseTime      // Total generation time
    case tokensPerSecond        // Generation speed
    case inputTokens            // Tokens in request
    case outputTokens           // Tokens in response

    // Quality metrics
    case responseQuality        // 0-1 quality score
    case userSatisfaction       // Derived from feedback
    case taskCompletionRate     // % of tasks completed
    case errorRate              // % of errors

    // Resource metrics
    case memoryUsage            // RAM usage
    case cpuUsage               // CPU utilization
    case networkLatency         // Network round-trip
    case apiCost                // Cost in dollars

    // Agent metrics
    case reasoningSteps         // Steps in reasoning
    case toolCalls              // Number of tool invocations
    case retryCount             // Number of retries
    case contextWindowUsage     // % of context used

    public var displayName: String {
        switch self {
        case .responseTime: return "Response Time"
        case .totalResponseTime: return "Total Response Time"
        case .tokensPerSecond: return "Tokens/Second"
        case .inputTokens: return "Input Tokens"
        case .outputTokens: return "Output Tokens"
        case .responseQuality: return "Response Quality"
        case .userSatisfaction: return "User Satisfaction"
        case .taskCompletionRate: return "Task Completion"
        case .errorRate: return "Error Rate"
        case .memoryUsage: return "Memory Usage"
        case .cpuUsage: return "CPU Usage"
        case .networkLatency: return "Network Latency"
        case .apiCost: return "API Cost"
        case .reasoningSteps: return "Reasoning Steps"
        case .toolCalls: return "Tool Calls"
        case .retryCount: return "Retries"
        case .contextWindowUsage: return "Context Usage"
        }
    }

    public var unit: String {
        switch self {
        case .responseTime, .totalResponseTime, .networkLatency:
            return "ms"
        case .tokensPerSecond:
            return "tok/s"
        case .inputTokens, .outputTokens, .reasoningSteps, .toolCalls, .retryCount:
            return ""
        case .responseQuality, .userSatisfaction, .taskCompletionRate, .errorRate, .cpuUsage, .contextWindowUsage:
            return "%"
        case .memoryUsage:
            return "MB"
        case .apiCost:
            return "$"
        }
    }
}

/// Statistical summary of metrics
public struct MetricSummary: Sendable {
    public let metricType: MetricType
    public let count: Int
    public let min: Double
    public let max: Double
    public let average: Double
    public let median: Double
    public let standardDeviation: Double
    public let percentile95: Double
    public let trend: Trend

    public enum Trend: String, Sendable {
        case improving
        case stable
        case degrading
        case unknown
    }

    public init(
        metricType: MetricType,
        count: Int,
        min: Double,
        max: Double,
        average: Double,
        median: Double,
        standardDeviation: Double,
        percentile95: Double,
        trend: Trend
    ) {
        self.metricType = metricType
        self.count = count
        self.min = min
        self.max = max
        self.average = average
        self.median = median
        self.standardDeviation = standardDeviation
        self.percentile95 = percentile95
        self.trend = trend
    }
}

/// Performance tracking session
public struct PerformanceSession: Sendable, Codable, Identifiable {
    public let id: UUID
    public let name: String
    public var metrics: [MetricDataPoint]
    public let startTime: Date
    public var endTime: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        metrics: [MetricDataPoint] = [],
        startTime: Date = Date(),
        endTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.metrics = metrics
        self.startTime = startTime
        self.endTime = endTime
    }

    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
}

/// Performance Metrics Manager
@MainActor
@Observable
public final class PerformanceMetricsManager {
    public static let shared = PerformanceMetricsManager()

    private(set) var allMetrics: [MetricDataPoint] = []
    private(set) var activeSessions: [PerformanceSession] = []
    private(set) var summaries: [MetricType: MetricSummary] = [:]
    private(set) var isTracking = false

    // Configuration
    public var retentionPeriod: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    public var maxMetricsCount: Int = 10000

    private init() {}

    // MARK: - Metric Recording

    /// Record a single metric
    public func record(_ metricType: MetricType, value: Double, context: [String: String] = [:]) {
        let dataPoint = MetricDataPoint(
            metricType: metricType,
            value: value,
            unit: metricType.unit,
            context: context
        )

        allMetrics.append(dataPoint)

        // Update active sessions
        for i in activeSessions.indices {
            activeSessions[i].metrics.append(dataPoint)
        }

        // Enforce limits
        trimOldMetrics()

        // Update summary
        updateSummary(for: metricType)
    }

    /// Record response metrics
    public func recordResponse(
        responseTime: Double,
        totalTime: Double,
        inputTokens: Int,
        outputTokens: Int,
        quality: Double? = nil
    ) {
        record(.responseTime, value: responseTime)
        record(.totalResponseTime, value: totalTime)
        record(.inputTokens, value: Double(inputTokens))
        record(.outputTokens, value: Double(outputTokens))

        if totalTime > 0 {
            let tokensPerSecond = Double(outputTokens) / (totalTime / 1000.0)
            record(.tokensPerSecond, value: tokensPerSecond)
        }

        if let quality = quality {
            record(.responseQuality, value: quality * 100)
        }
    }

    /// Record agent metrics
    public func recordAgentExecution(
        reasoningSteps: Int,
        toolCalls: Int,
        retries: Int,
        contextUsage: Double
    ) {
        record(.reasoningSteps, value: Double(reasoningSteps))
        record(.toolCalls, value: Double(toolCalls))
        record(.retryCount, value: Double(retries))
        record(.contextWindowUsage, value: contextUsage * 100)
    }

    // MARK: - Session Management

    /// Start a performance tracking session
    public func startSession(name: String) -> UUID {
        let session = PerformanceSession(name: name)
        activeSessions.append(session)
        isTracking = true
        return session.id
    }

    /// End a performance tracking session
    public func endSession(_ sessionId: UUID) -> PerformanceSession? {
        guard let index = activeSessions.firstIndex(where: { $0.id == sessionId }) else {
            return nil
        }

        var session = activeSessions.remove(at: index)
        session.endTime = Date()

        if activeSessions.isEmpty {
            isTracking = false
        }

        return session
    }

    // MARK: - Statistics

    /// Get summary for a specific metric type
    public func getSummary(for metricType: MetricType) -> MetricSummary? {
        summaries[metricType]
    }

    /// Get metrics for a time period
    public func getMetrics(
        type: MetricType,
        since: Date
    ) -> [MetricDataPoint] {
        allMetrics.filter { $0.metricType == type && $0.timestamp >= since }
    }

    /// Get all summaries
    public func getAllSummaries() -> [MetricSummary] {
        Array(summaries.values)
    }

    private func updateSummary(for metricType: MetricType) {
        let metrics = allMetrics.filter { $0.metricType == metricType }
        guard !metrics.isEmpty else { return }

        let values = metrics.map(\.value).sorted()
        let count = values.count

        let minValue = values.first ?? 0
        let maxValue = values.last ?? 0
        let average = values.reduce(0, +) / Double(count)
        let median = count % 2 == 0
            ? (values[count/2 - 1] + values[count/2]) / 2
            : values[count/2]

        // Standard deviation
        let variance = values.reduce(0) { $0 + pow($1 - average, 2) } / Double(count)
        let stdDev = sqrt(variance)

        // 95th percentile
        let p95Index = Int(Double(count) * 0.95)
        let percentile95 = values[Swift.min(p95Index, count - 1)]

        // Calculate trend (compare recent vs older values)
        let trend = calculateTrend(metrics)

        summaries[metricType] = MetricSummary(
            metricType: metricType,
            count: count,
            min: minValue,
            max: maxValue,
            average: average,
            median: median,
            standardDeviation: stdDev,
            percentile95: percentile95,
            trend: trend
        )
    }

    private func calculateTrend(_ metrics: [MetricDataPoint]) -> MetricSummary.Trend {
        guard metrics.count >= 10 else { return .unknown }

        let sorted = metrics.sorted { $0.timestamp < $1.timestamp }
        let midpoint = sorted.count / 2

        let olderAvg = sorted[..<midpoint].map(\.value).reduce(0, +) / Double(midpoint)
        let recentAvg = sorted[midpoint...].map(\.value).reduce(0, +) / Double(sorted.count - midpoint)

        let changePercent = (recentAvg - olderAvg) / olderAvg

        // For most metrics, lower is better (except quality/satisfaction)
        let isLowerBetter = ![MetricType.responseQuality, .userSatisfaction, .taskCompletionRate, .tokensPerSecond]
            .contains(metrics.first?.metricType ?? .responseTime)

        if abs(changePercent) < 0.05 {
            return .stable
        } else if (changePercent < 0 && isLowerBetter) || (changePercent > 0 && !isLowerBetter) {
            return .improving
        } else {
            return .degrading
        }
    }

    private func trimOldMetrics() {
        let cutoff = Date().addingTimeInterval(-retentionPeriod)
        allMetrics.removeAll { $0.timestamp < cutoff }

        // Also enforce count limit
        if allMetrics.count > maxMetricsCount {
            allMetrics = Array(allMetrics.suffix(maxMetricsCount))
        }
    }

    // MARK: - Reporting

    /// Generate a performance report
    public func generateReport() -> PerformanceReport {
        let activeSummaries = getAllSummaries()

        let warnings: [String] = activeSummaries.compactMap { summary in
            if summary.trend == .degrading {
                return "\(summary.metricType.displayName) is degrading"
            }
            if summary.metricType == .errorRate && summary.average > 5 {
                return "High error rate: \(String(format: "%.1f", summary.average))%"
            }
            if summary.metricType == .responseTime && summary.average > 3000 {
                return "Slow response time: \(String(format: "%.0f", summary.average))ms"
            }
            return nil
        }

        return PerformanceReport(
            generatedAt: Date(),
            totalMetrics: allMetrics.count,
            summaries: activeSummaries,
            activeSessions: activeSessions.count,
            warnings: warnings
        )
    }
}

/// Performance report structure
public struct PerformanceReport: Sendable {
    public let generatedAt: Date
    public let totalMetrics: Int
    public let summaries: [MetricSummary]
    public let activeSessions: Int
    public let warnings: [String]

    public init(
        generatedAt: Date,
        totalMetrics: Int,
        summaries: [MetricSummary],
        activeSessions: Int,
        warnings: [String]
    ) {
        self.generatedAt = generatedAt
        self.totalMetrics = totalMetrics
        self.summaries = summaries
        self.activeSessions = activeSessions
        self.warnings = warnings
    }
}
