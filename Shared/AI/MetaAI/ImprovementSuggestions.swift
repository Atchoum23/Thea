import Foundation

// MARK: - Improvement Suggestions Engine
// Generates actionable improvement suggestions based on performance analysis

/// An improvement suggestion
public struct ImprovementSuggestion: Sendable, Codable, Identifiable {
    public let id: UUID
    public let category: SuggestionCategory
    public let priority: Priority
    public let title: String
    public let description: String
    public let rationale: String
    public let impact: ImpactLevel
    public let effort: EffortLevel
    public let actionItems: [String]
    public let relatedMetrics: [MetricType]
    public let createdAt: Date
    public var status: Status

    public enum SuggestionCategory: String, Codable, Sendable, CaseIterable {
        case performance       // Speed and efficiency
        case quality           // Response quality
        case userExperience    // User satisfaction
        case cost              // API cost optimization
        case reliability       // Error reduction
        case capability        // New features/capabilities

        public var icon: String {
            switch self {
            case .performance: return "bolt"
            case .quality: return "star"
            case .userExperience: return "face.smiling"
            case .cost: return "dollarsign.circle"
            case .reliability: return "shield.checkered"
            case .capability: return "plus.circle"
            }
        }
    }

    public enum Priority: Int, Codable, Sendable, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }

        public var color: String {
            switch self {
            case .low: return "gray"
            case .medium: return "blue"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }

    public enum ImpactLevel: String, Codable, Sendable {
        case minimal
        case moderate
        case significant
        case transformative
    }

    public enum EffortLevel: String, Codable, Sendable {
        case trivial       // < 1 hour
        case small         // 1-4 hours
        case medium        // 1-3 days
        case large         // 1-2 weeks
        case massive       // > 2 weeks
    }

    public enum Status: String, Codable, Sendable {
        case proposed
        case inProgress
        case implemented
        case deferred
        case rejected
    }

    public init(
        id: UUID = UUID(),
        category: SuggestionCategory,
        priority: Priority,
        title: String,
        description: String,
        rationale: String,
        impact: ImpactLevel,
        effort: EffortLevel,
        actionItems: [String],
        relatedMetrics: [MetricType] = [],
        createdAt: Date = Date(),
        status: Status = .proposed
    ) {
        self.id = id
        self.category = category
        self.priority = priority
        self.title = title
        self.description = description
        self.rationale = rationale
        self.impact = impact
        self.effort = effort
        self.actionItems = actionItems
        self.relatedMetrics = relatedMetrics
        self.createdAt = createdAt
        self.status = status
    }

    /// ROI score (impact vs effort)
    public var roiScore: Double {
        let impactValue: Double
        switch impact {
        case .minimal: impactValue = 1
        case .moderate: impactValue = 2
        case .significant: impactValue = 3
        case .transformative: impactValue = 4
        }

        let effortValue: Double
        switch effort {
        case .trivial: effortValue = 1
        case .small: effortValue = 2
        case .medium: effortValue = 3
        case .large: effortValue = 4
        case .massive: effortValue = 5
        }

        return impactValue / effortValue
    }
}

/// Improvement Suggestions Engine
@MainActor
@Observable
public final class ImprovementSuggestionsEngine {
    public static let shared = ImprovementSuggestionsEngine()

    private(set) var suggestions: [ImprovementSuggestion] = []
    private(set) var isAnalyzing = false

    private init() {}

    // MARK: - Suggestion Generation

    /// Generate suggestions based on performance metrics
    public func generateSuggestions(from metrics: PerformanceMetricsManager) async -> [ImprovementSuggestion] {
        isAnalyzing = true
        defer { isAnalyzing = false }

        var newSuggestions: [ImprovementSuggestion] = []

        let summaries = metrics.getAllSummaries()

        for summary in summaries {
            if let suggestion = analyzeMetric(summary) {
                newSuggestions.append(suggestion)
            }
        }

        // Add cross-metric suggestions
        newSuggestions.append(contentsOf: generateCrossMetricSuggestions(summaries))

        // Sort by priority then ROI
        newSuggestions.sort { ($0.priority, $0.roiScore) > ($1.priority, $1.roiScore) }

        suggestions.append(contentsOf: newSuggestions)
        return newSuggestions
    }

    /// Generate suggestions from interaction analysis
    public func generateSuggestions(from interactions: [AnalyzedInteraction]) -> [ImprovementSuggestion] {
        var newSuggestions: [ImprovementSuggestion] = []

        // Analyze quality patterns
        let qualities = interactions.map(\.analysis.responseQuality)
        let avgQuality = qualities.map(\.overallScore).reduce(0, +) / max(1, Double(qualities.count))

        if avgQuality < 0.6 {
            newSuggestions.append(ImprovementSuggestion(
                category: .quality,
                priority: .high,
                title: "Improve Response Quality",
                description: "Average response quality is below acceptable threshold",
                rationale: "Quality score of \(String(format: "%.0f%%", avgQuality * 100)) indicates responses need improvement",
                impact: .significant,
                effort: .medium,
                actionItems: [
                    "Review low-quality responses to identify patterns",
                    "Enhance prompt templates",
                    "Consider using more capable models for complex queries"
                ],
                relatedMetrics: [.responseQuality]
            ))
        }

        // Analyze sentiment patterns
        let negativeInteractions = interactions.filter { $0.analysis.sentiment.polarity == .negative }
        let negativeRate = Double(negativeInteractions.count) / max(1, Double(interactions.count))

        if negativeRate > 0.2 {
            newSuggestions.append(ImprovementSuggestion(
                category: .userExperience,
                priority: .high,
                title: "Address User Frustration",
                description: "High rate of negative sentiment detected",
                rationale: "\(String(format: "%.0f%%", negativeRate * 100)) of interactions show negative sentiment",
                impact: .significant,
                effort: .medium,
                actionItems: [
                    "Analyze common frustration triggers",
                    "Improve error messages and recovery",
                    "Add proactive help suggestions"
                ],
                relatedMetrics: [.userSatisfaction]
            ))
        }

        // Analyze complexity handling
        let complexInteractions = interactions.filter {
            $0.analysis.complexity == .complex || $0.analysis.complexity == .veryComplex
        }
        let complexSuccessRate = complexInteractions.filter {
            $0.analysis.responseQuality.overallScore >= 0.6
        }.count

        if complexInteractions.count > 5 && Double(complexSuccessRate) / Double(complexInteractions.count) < 0.7 {
            newSuggestions.append(ImprovementSuggestion(
                category: .capability,
                priority: .medium,
                title: "Enhance Complex Query Handling",
                description: "Complex queries have lower success rates",
                rationale: "Complex interactions show lower quality scores than simple ones",
                impact: .moderate,
                effort: .large,
                actionItems: [
                    "Implement better query decomposition",
                    "Use chain-of-thought reasoning for complex queries",
                    "Add clarification prompts for ambiguous requests"
                ],
                relatedMetrics: [.taskCompletionRate, .reasoningSteps]
            ))
        }

        suggestions.append(contentsOf: newSuggestions)
        return newSuggestions
    }

    // MARK: - Private Analysis Methods

    private func analyzeMetric(_ summary: MetricSummary) -> ImprovementSuggestion? {
        switch summary.metricType {
        case .responseTime:
            if summary.average > 2000 {
                return ImprovementSuggestion(
                    category: .performance,
                    priority: summary.average > 5000 ? .high : .medium,
                    title: "Reduce Response Latency",
                    description: "Average response time is \(String(format: "%.0f", summary.average))ms",
                    rationale: "Users expect responses within 1-2 seconds. Current latency may impact satisfaction.",
                    impact: summary.average > 5000 ? .significant : .moderate,
                    effort: .medium,
                    actionItems: [
                        "Use faster models for simple queries",
                        "Implement response caching",
                        "Optimize prompt length"
                    ],
                    relatedMetrics: [.responseTime, .tokensPerSecond]
                )
            }

        case .errorRate:
            if summary.average > 3 {
                return ImprovementSuggestion(
                    category: .reliability,
                    priority: summary.average > 10 ? .critical : .high,
                    title: "Reduce Error Rate",
                    description: "Error rate is at \(String(format: "%.1f%%", summary.average))",
                    rationale: "High error rates directly impact user trust and satisfaction",
                    impact: .significant,
                    effort: .medium,
                    actionItems: [
                        "Implement better error handling",
                        "Add retry logic with exponential backoff",
                        "Improve input validation"
                    ],
                    relatedMetrics: [.errorRate, .retryCount]
                )
            }

        case .apiCost:
            if summary.trend == .degrading {
                return ImprovementSuggestion(
                    category: .cost,
                    priority: .medium,
                    title: "Optimize API Costs",
                    description: "API costs are trending upward",
                    rationale: "Increasing costs may not be sustainable long-term",
                    impact: .moderate,
                    effort: .small,
                    actionItems: [
                        "Use cheaper models for simple queries",
                        "Implement response caching",
                        "Optimize prompt efficiency"
                    ],
                    relatedMetrics: [.apiCost, .inputTokens, .outputTokens]
                )
            }

        case .contextWindowUsage:
            if summary.average > 80 {
                return ImprovementSuggestion(
                    category: .performance,
                    priority: .medium,
                    title: "Optimize Context Usage",
                    description: "Context window usage is high at \(String(format: "%.0f%%", summary.average))",
                    rationale: "High context usage may lead to truncation and degraded responses",
                    impact: .moderate,
                    effort: .medium,
                    actionItems: [
                        "Implement conversation summarization",
                        "Use sliding window for old messages",
                        "Filter irrelevant context"
                    ],
                    relatedMetrics: [.contextWindowUsage, .inputTokens]
                )
            }

        default:
            break
        }

        return nil
    }

    private func generateCrossMetricSuggestions(_ summaries: [MetricSummary]) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []

        // Check for quality-cost imbalance
        let qualitySummary = summaries.first { $0.metricType == .responseQuality }
        let costSummary = summaries.first { $0.metricType == .apiCost }

        if let quality = qualitySummary, let cost = costSummary {
            if quality.average < 60 && cost.trend == .improving {
                suggestions.append(ImprovementSuggestion(
                    category: .quality,
                    priority: .high,
                    title: "Balance Quality and Cost",
                    description: "Quality is low while costs are being optimized",
                    rationale: "Over-optimization for cost may be hurting response quality",
                    impact: .significant,
                    effort: .small,
                    actionItems: [
                        "Review model selection criteria",
                        "Consider using more capable models for complex tasks",
                        "Implement quality-aware routing"
                    ],
                    relatedMetrics: [.responseQuality, .apiCost]
                ))
            }
        }

        return suggestions
    }

    // MARK: - Suggestion Management

    public func updateStatus(_ suggestionId: UUID, status: ImprovementSuggestion.Status) {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestionId }) else { return }
        suggestions[index].status = status
    }

    public func getSuggestions(
        category: ImprovementSuggestion.SuggestionCategory? = nil,
        minPriority: ImprovementSuggestion.Priority = .low,
        status: ImprovementSuggestion.Status? = nil
    ) -> [ImprovementSuggestion] {
        suggestions.filter { suggestion in
            (category == nil || suggestion.category == category) &&
            suggestion.priority >= minPriority &&
            (status == nil || suggestion.status == status)
        }
    }

    public func clearImplemented() {
        suggestions.removeAll { $0.status == .implemented }
    }
}
