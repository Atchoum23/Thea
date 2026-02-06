// ReflexionEngine.swift
// Thea V2
//
// Self-reflection and improvement system
// Implements Generate → Critique → Improve loop for higher quality outputs

import Foundation
import OSLog

// MARK: - Reflexion Cycle

/// A complete reflexion cycle with original, critique, and improved output
public struct ReflexionCycle: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let taskDescription: String
    public let originalOutput: String
    public let selfCritique: SelfCritique
    public let improvedOutput: String?
    public let confidenceScore: Float  // 0.0 - 1.0
    public let iterationCount: Int
    public let totalDuration: TimeInterval
    public let wasSuccessful: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        taskDescription: String,
        originalOutput: String,
        selfCritique: SelfCritique,
        improvedOutput: String? = nil,
        confidenceScore: Float,
        iterationCount: Int = 1,
        totalDuration: TimeInterval,
        wasSuccessful: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskDescription = taskDescription
        self.originalOutput = originalOutput
        self.selfCritique = selfCritique
        self.improvedOutput = improvedOutput
        self.confidenceScore = confidenceScore
        self.iterationCount = iterationCount
        self.totalDuration = totalDuration
        self.wasSuccessful = wasSuccessful
    }
}

// MARK: - Self Critique

/// Self-critique analysis of an output
public struct SelfCritique: Sendable {
    public let overallQuality: QualityLevel
    public let strengths: [String]
    public let weaknesses: [String]
    public let suggestions: [String]
    public let factualAccuracy: Float  // 0.0 - 1.0
    public let completeness: Float     // 0.0 - 1.0
    public let clarity: Float          // 0.0 - 1.0
    public let relevance: Float        // 0.0 - 1.0
    public let shouldImprove: Bool
    public let reasoning: String

    public init(
        overallQuality: QualityLevel,
        strengths: [String] = [],
        weaknesses: [String] = [],
        suggestions: [String] = [],
        factualAccuracy: Float = 0.5,
        completeness: Float = 0.5,
        clarity: Float = 0.5,
        relevance: Float = 0.5,
        shouldImprove: Bool = false,
        reasoning: String = ""
    ) {
        self.overallQuality = overallQuality
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.suggestions = suggestions
        self.factualAccuracy = factualAccuracy
        self.completeness = completeness
        self.clarity = clarity
        self.relevance = relevance
        self.shouldImprove = shouldImprove
        self.reasoning = reasoning
    }

    public var averageScore: Float {
        (factualAccuracy + completeness + clarity + relevance) / 4.0
    }
}

public enum QualityLevel: String, Codable, Sendable {
    case excellent
    case good
    case acceptable
    case needsImprovement
    case poor
}

// MARK: - Failure Analysis

/// Analysis of a failed task
public struct FailureAnalysis: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let taskDescription: String
    public let errorType: FailureType
    public let errorMessage: String
    public let rootCause: String
    public let contributingFactors: [String]
    public let suggestedFixes: [String]
    public let preventionStrategies: [String]
    public let severity: FailureSeverity
    public let isRecurring: Bool
    public let relatedFailures: [UUID]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        taskDescription: String,
        errorType: FailureType,
        errorMessage: String,
        rootCause: String,
        contributingFactors: [String] = [],
        suggestedFixes: [String] = [],
        preventionStrategies: [String] = [],
        severity: FailureSeverity = .medium,
        isRecurring: Bool = false,
        relatedFailures: [UUID] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskDescription = taskDescription
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.rootCause = rootCause
        self.contributingFactors = contributingFactors
        self.suggestedFixes = suggestedFixes
        self.preventionStrategies = preventionStrategies
        self.severity = severity
        self.isRecurring = isRecurring
        self.relatedFailures = relatedFailures
    }
}

public enum FailureType: String, Codable, Sendable {
    case misunderstanding     // Misunderstood the request
    case incompleteContext    // Missing necessary context
    case technicalError       // Code/execution error
    case hallucination        // Generated incorrect information
    case timeout              // Task took too long
    case resourceLimit        // Hit token/memory limits
    case toolFailure          // External tool failed
    case validationFailure    // Output didn't meet requirements
    case userRejection        // User rejected the output
    case unknown
}

public enum FailureSeverity: String, Codable, Sendable {
    case low      // Minor issue, easy to recover
    case medium   // Moderate impact, requires retry
    case high     // Significant impact, needs attention
    case critical // Major failure, blocks progress
}

// MARK: - Strategy Evolution

/// A learned strategy for handling specific task types
public struct LearnedStrategy: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let taskTypes: [String]
    public let approach: String
    public let steps: [String]
    public let prerequisites: [String]
    public let antiPatterns: [String]  // What NOT to do
    public let successRate: Float
    public let usageCount: Int
    public let lastUsed: Date
    public let createdAt: Date
    public let sourceFailures: [UUID]  // Failures that led to this strategy
    public let sourceSuccesses: [UUID] // Successes that validated it

    public init(
        id: UUID = UUID(),
        name: String,
        taskTypes: [String],
        approach: String,
        steps: [String] = [],
        prerequisites: [String] = [],
        antiPatterns: [String] = [],
        successRate: Float = 0.5,
        usageCount: Int = 0,
        lastUsed: Date = Date(),
        createdAt: Date = Date(),
        sourceFailures: [UUID] = [],
        sourceSuccesses: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.taskTypes = taskTypes
        self.approach = approach
        self.steps = steps
        self.prerequisites = prerequisites
        self.antiPatterns = antiPatterns
        self.successRate = successRate
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.createdAt = createdAt
        self.sourceFailures = sourceFailures
        self.sourceSuccesses = sourceSuccesses
    }
}

// MARK: - Confidence Calibration

/// Tracks prediction accuracy for confidence calibration
public struct ConfidenceCalibration: Codable, Sendable {
    public var totalPredictions: Int
    public var correctPredictions: Int
    public var calibrationBuckets: [ReflexionCalibrationBucket]

    public init() {
        self.totalPredictions = 0
        self.correctPredictions = 0
        self.calibrationBuckets = (0..<10).map { ReflexionCalibrationBucket(rangeStart: Float($0) / 10.0, rangeEnd: Float($0 + 1) / 10.0) }
    }

    public var overallAccuracy: Float {
        guard totalPredictions > 0 else { return 0 }
        return Float(correctPredictions) / Float(totalPredictions)
    }

    public mutating func record(predictedConfidence: Float, wasCorrect: Bool) {
        totalPredictions += 1
        if wasCorrect {
            correctPredictions += 1
        }

        // Update appropriate bucket
        let bucketIndex = min(9, Int(predictedConfidence * 10))
        calibrationBuckets[bucketIndex].record(wasCorrect: wasCorrect)
    }

    /// Returns calibrated confidence (adjusts for over/under confidence)
    public func calibrate(rawConfidence: Float) -> Float {
        let bucketIndex = min(9, Int(rawConfidence * 10))
        let bucket = calibrationBuckets[bucketIndex]

        guard bucket.count > 10 else {
            // Not enough data, return raw
            return rawConfidence
        }

        // Adjust based on actual accuracy in this bucket
        return bucket.actualAccuracy
    }
}

public struct ReflexionCalibrationBucket: Codable, Sendable {
    public let rangeStart: Float
    public let rangeEnd: Float
    public var count: Int
    public var correct: Int

    public init(rangeStart: Float, rangeEnd: Float) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.count = 0
        self.correct = 0
    }

    public var actualAccuracy: Float {
        guard !isEmpty else { return rangeStart + 0.05 }
        return Float(correct) / Float(count)
    }

    public mutating func record(wasCorrect: Bool) {
        count += 1
        if wasCorrect {
            correct += 1
        }
    }
}

// MARK: - Reflexion Engine

/// Main engine for self-reflection and improvement
@MainActor
public final class ReflexionEngine: ObservableObject {
    public static let shared = ReflexionEngine()

    private let logger = Logger(subsystem: "com.thea.reflection", category: "Engine")
    private let storageURL: URL

    @Published public private(set) var recentCycles: [ReflexionCycle] = []
    @Published public private(set) var failureAnalyses: [FailureAnalysis] = []
    @Published public private(set) var strategies: [LearnedStrategy] = []
    @Published public private(set) var calibration = ConfidenceCalibration()
    @Published public private(set) var isReflecting: Bool = false

    // Configuration
    public var maxIterations: Int = 3
    public var qualityThreshold: Float = 0.7
    public var autoImproveEnabled: Bool = true

    private let maxCycleHistory = 100
    private let maxFailureHistory = 500

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = documentsPath.appendingPathComponent("thea_reflection.json")
        loadState()
    }

    // MARK: - Reflexion Cycle

    /// Perform a reflexion cycle on output
    public func reflect(
        task: String,
        output: String,
        context: String = ""
    ) async -> ReflexionCycle {
        isReflecting = true
        defer { isReflecting = false }

        let startTime = Date()
        var currentOutput = output
        var iteration = 0
        var lastCritique: SelfCritique?

        while iteration < maxIterations {
            iteration += 1

            // Generate self-critique
            let critique = await generateCritique(task: task, output: currentOutput, context: context)
            lastCritique = critique

            // Check if good enough
            if critique.averageScore >= qualityThreshold || !critique.shouldImprove {
                break
            }

            // Improve if auto-improve enabled
            if autoImproveEnabled && critique.shouldImprove {
                if let improved = await improveOutput(
                    task: task,
                    output: currentOutput,
                    critique: critique,
                    context: context
                ) {
                    currentOutput = improved
                } else {
                    break  // Couldn't improve further
                }
            } else {
                break
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let finalCritique = lastCritique ?? generateDefaultCritique()

        let cycle = ReflexionCycle(
            taskDescription: task,
            originalOutput: output,
            selfCritique: finalCritique,
            improvedOutput: currentOutput != output ? currentOutput : nil,
            confidenceScore: finalCritique.averageScore,
            iterationCount: iteration,
            totalDuration: duration,
            wasSuccessful: finalCritique.averageScore >= qualityThreshold
        )

        // Store cycle
        recentCycles.append(cycle)
        if recentCycles.count > maxCycleHistory {
            recentCycles = Array(recentCycles.suffix(maxCycleHistory))
        }

        saveState()
        logger.info("Reflection cycle completed: \(iteration) iterations, confidence: \(finalCritique.averageScore)")

        return cycle
    }

    // MARK: - Critique Generation

    private func generateCritique(task: String, output: String, context: String) async -> SelfCritique {
        // Analyze the output against the task requirements
        var strengths: [String] = []
        var weaknesses: [String] = []
        var suggestions: [String] = []

        // Basic heuristic analysis (in production, this would use an LLM)
        let outputLength = output.count

        // Check completeness
        var completeness: Float = 0.5
        if outputLength > 100 {
            completeness += 0.2
            strengths.append("Provides detailed response")
        }
        if outputLength < 50 {
            completeness -= 0.2
            weaknesses.append("Response may be too brief")
            suggestions.append("Consider expanding with more details")
        }

        // Check for code if task mentions code
        let clarity: Float
        if task.lowercased().contains("code") || task.lowercased().contains("implement") {
            if output.contains("```") || output.contains("func ") || output.contains("class ") {
                clarity = 0.8
                strengths.append("Includes code examples")
            } else {
                clarity = 0.4
                weaknesses.append("Missing code examples for coding task")
                suggestions.append("Add concrete code examples")
            }
        } else {
            clarity = 0.6
        }

        // Check for structure
        if output.contains("\n\n") || output.contains("##") || output.contains("1.") {
            strengths.append("Well-structured response")
        } else if outputLength > 200 {
            weaknesses.append("Could benefit from better structure")
            suggestions.append("Add headings or bullet points for clarity")
        }

        // Determine overall quality
        let averageScore = (completeness + clarity + 0.6 + 0.6) / 4.0
        let quality: QualityLevel
        switch averageScore {
        case 0.8...: quality = .excellent
        case 0.6..<0.8: quality = .good
        case 0.4..<0.6: quality = .acceptable
        case 0.2..<0.4: quality = .needsImprovement
        default: quality = .poor
        }

        let shouldImprove = averageScore < qualityThreshold && !suggestions.isEmpty

        return SelfCritique(
            overallQuality: quality,
            strengths: strengths,
            weaknesses: weaknesses,
            suggestions: suggestions,
            factualAccuracy: 0.6,  // Would need verification
            completeness: completeness,
            clarity: clarity,
            relevance: 0.6,
            shouldImprove: shouldImprove,
            reasoning: "Analysis based on task requirements and output structure"
        )
    }

    private func improveOutput(
        task: String,
        output: String,
        critique: SelfCritique,
        context: String
    ) async -> String? {
        // In production, this would use an LLM to improve
        // For now, return nil to indicate no improvement possible
        logger.debug("Would improve based on: \(critique.suggestions.joined(separator: ", "))")
        return nil
    }

    private func generateDefaultCritique() -> SelfCritique {
        SelfCritique(
            overallQuality: .acceptable,
            factualAccuracy: 0.5,
            completeness: 0.5,
            clarity: 0.5,
            relevance: 0.5
        )
    }

    // MARK: - Failure Analysis

    /// Analyze a failure and extract learnings
    public func analyzeFailure(
        task: String,
        error: String,
        context: String = ""
    ) -> FailureAnalysis {
        // Determine error type
        let errorType = classifyError(error)

        // Find root cause (heuristic)
        let rootCause = inferRootCause(task: task, error: error, errorType: errorType)

        // Generate fixes
        let fixes = suggestFixes(errorType: errorType, error: error)

        // Generate prevention strategies
        let prevention = suggestPrevention(errorType: errorType)

        // Check if recurring
        let isRecurring = failureAnalyses.contains { existing in
            existing.errorType == errorType &&
            existing.errorMessage.lowercased().contains(error.lowercased().prefix(50))
        }

        // Find related failures
        let related = failureAnalyses.filter { existing in
            existing.taskDescription.lowercased().contains(task.lowercased().prefix(30))
        }.map { $0.id }

        let analysis = FailureAnalysis(
            taskDescription: task,
            errorType: errorType,
            errorMessage: error,
            rootCause: rootCause,
            contributingFactors: extractContributingFactors(task: task, error: error),
            suggestedFixes: fixes,
            preventionStrategies: prevention,
            severity: determineSeverity(errorType: errorType, isRecurring: isRecurring),
            isRecurring: isRecurring,
            relatedFailures: related
        )

        // Store analysis
        failureAnalyses.append(analysis)
        if failureAnalyses.count > maxFailureHistory {
            failureAnalyses = Array(failureAnalyses.suffix(maxFailureHistory))
        }

        // Learn from failure
        Task {
            await learnFromFailure(analysis)
        }

        saveState()
        logger.info("Analyzed failure: \(errorType.rawValue) - \(rootCause)")

        return analysis
    }

    private func classifyError(_ error: String) -> FailureType {
        let lowercased = error.lowercased()

        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return .timeout
        }
        if lowercased.contains("token") || lowercased.contains("context length") {
            return .resourceLimit
        }
        if lowercased.contains("api") || lowercased.contains("connection") {
            return .toolFailure
        }
        if lowercased.contains("invalid") || lowercased.contains("validation") {
            return .validationFailure
        }
        if lowercased.contains("didn't understand") || lowercased.contains("unclear") {
            return .misunderstanding
        }
        if lowercased.contains("missing") || lowercased.contains("need more") {
            return .incompleteContext
        }

        return .unknown
    }

    private func inferRootCause(task: String, error: String, errorType: FailureType) -> String {
        switch errorType {
        case .misunderstanding:
            return "Task requirements were ambiguous or misinterpreted"
        case .incompleteContext:
            return "Insufficient information provided to complete the task"
        case .technicalError:
            return "Code execution or syntax error encountered"
        case .hallucination:
            return "Generated information that wasn't grounded in facts"
        case .timeout:
            return "Task complexity exceeded available processing time"
        case .resourceLimit:
            return "Context or token limit exceeded"
        case .toolFailure:
            return "External tool or API failed to respond correctly"
        case .validationFailure:
            return "Output did not meet specified requirements"
        case .userRejection:
            return "Output did not match user expectations"
        case .unknown:
            return "Unable to determine specific root cause"
        }
    }

    private func suggestFixes(errorType: FailureType, error: String) -> [String] {
        switch errorType {
        case .misunderstanding:
            return [
                "Ask clarifying questions before starting",
                "Restate understanding of the task for confirmation",
                "Break down complex requests into smaller parts"
            ]
        case .incompleteContext:
            return [
                "Request additional context or examples",
                "Check for related files or documentation",
                "Use search to find relevant information"
            ]
        case .timeout:
            return [
                "Break task into smaller subtasks",
                "Process data in batches",
                "Increase timeout limits if possible"
            ]
        case .resourceLimit:
            return [
                "Summarize context before processing",
                "Process in chunks with context handoff",
                "Prioritize most relevant information"
            ]
        case .toolFailure:
            return [
                "Retry with exponential backoff",
                "Use alternative tool or approach",
                "Check tool availability before use"
            ]
        default:
            return ["Review task requirements", "Try alternative approach"]
        }
    }

    private func suggestPrevention(errorType: FailureType) -> [String] {
        switch errorType {
        case .misunderstanding:
            return ["Always confirm understanding before executing"]
        case .incompleteContext:
            return ["Proactively gather context before starting"]
        case .timeout:
            return ["Estimate complexity before starting long tasks"]
        case .resourceLimit:
            return ["Monitor token usage throughout task"]
        case .toolFailure:
            return ["Check tool health before critical operations"]
        default:
            return ["Apply learned strategies for this task type"]
        }
    }

    private func extractContributingFactors(task: String, error: String) -> [String] {
        var factors: [String] = []

        if task.count > 500 {
            factors.append("Long/complex task description")
        }
        if !task.contains("?") && task.lowercased().contains("should") {
            factors.append("Ambiguous requirements")
        }

        return factors
    }

    private func determineSeverity(errorType: FailureType, isRecurring: Bool) -> FailureSeverity {
        var baseSeverity: FailureSeverity

        switch errorType {
        case .hallucination, .technicalError:
            baseSeverity = .high
        case .timeout, .resourceLimit, .toolFailure:
            baseSeverity = .medium
        case .misunderstanding, .incompleteContext:
            baseSeverity = .low
        default:
            baseSeverity = .medium
        }

        // Increase severity if recurring
        if isRecurring {
            switch baseSeverity {
            case .low: baseSeverity = .medium
            case .medium: baseSeverity = .high
            case .high: baseSeverity = .critical
            case .critical: break
            }
        }

        return baseSeverity
    }

    // MARK: - Strategy Learning

    private func learnFromFailure(_ analysis: FailureAnalysis) async {
        // Check if we should create or update a strategy
        let relatedFailures = failureAnalyses.filter { $0.errorType == analysis.errorType }

        if relatedFailures.count >= 3 {
            // We have enough data to learn a strategy
            let strategyName = "Avoid \(analysis.errorType.rawValue)"

            // Check if strategy exists
            if let existingIndex = strategies.firstIndex(where: { $0.name == strategyName }) {
                // Update existing strategy
                var strategy = strategies[existingIndex]
                let newAntiPatterns = analysis.contributingFactors.filter { factor in
                    !strategy.antiPatterns.contains(factor)
                }
                let newSteps = analysis.preventionStrategies.filter { step in
                    !strategy.steps.contains(step)
                }

                if !newAntiPatterns.isEmpty || !newSteps.isEmpty {
                    strategy = LearnedStrategy(
                        id: strategy.id,
                        name: strategy.name,
                        taskTypes: strategy.taskTypes,
                        approach: strategy.approach,
                        steps: strategy.steps + newSteps,
                        prerequisites: strategy.prerequisites,
                        antiPatterns: strategy.antiPatterns + newAntiPatterns,
                        successRate: strategy.successRate,
                        usageCount: strategy.usageCount,
                        lastUsed: Date(),
                        createdAt: strategy.createdAt,
                        sourceFailures: strategy.sourceFailures + [analysis.id],
                        sourceSuccesses: strategy.sourceSuccesses
                    )
                    strategies[existingIndex] = strategy
                    logger.info("Updated strategy: \(strategyName)")
                }
            } else {
                // Create new strategy
                let strategy = LearnedStrategy(
                    name: strategyName,
                    taskTypes: [analysis.taskDescription.components(separatedBy: " ").first ?? "general"],
                    approach: "Prevention through awareness and preparation",
                    steps: analysis.preventionStrategies,
                    antiPatterns: analysis.contributingFactors,
                    successRate: 0.5,
                    sourceFailures: [analysis.id]
                )
                strategies.append(strategy)
                logger.info("Created new strategy: \(strategyName)")
            }

            saveState()
        }
    }

    /// Get applicable strategies for a task type
    public func strategiesFor(taskType: String) -> [LearnedStrategy] {
        strategies.filter { strategy in
            strategy.taskTypes.contains { type in
                taskType.lowercased().contains(type.lowercased())
            }
        }.sorted { $0.successRate > $1.successRate }
    }

    /// Record strategy usage and outcome
    public func recordStrategyUsage(strategyId: UUID, wasSuccessful: Bool) {
        guard let index = strategies.firstIndex(where: { $0.id == strategyId }) else { return }

        var strategy = strategies[index]
        let newUsageCount = strategy.usageCount + 1
        let newSuccessRate = (strategy.successRate * Float(strategy.usageCount) + (wasSuccessful ? 1.0 : 0.0)) / Float(newUsageCount)

        strategy = LearnedStrategy(
            id: strategy.id,
            name: strategy.name,
            taskTypes: strategy.taskTypes,
            approach: strategy.approach,
            steps: strategy.steps,
            prerequisites: strategy.prerequisites,
            antiPatterns: strategy.antiPatterns,
            successRate: newSuccessRate,
            usageCount: newUsageCount,
            lastUsed: Date(),
            createdAt: strategy.createdAt,
            sourceFailures: strategy.sourceFailures,
            sourceSuccesses: wasSuccessful ? strategy.sourceSuccesses + [UUID()] : strategy.sourceSuccesses
        )
        strategies[index] = strategy
        saveState()
    }

    // MARK: - Confidence Calibration

    /// Record a prediction for calibration
    public func recordPrediction(confidence: Float, wasCorrect: Bool) {
        calibration.record(predictedConfidence: confidence, wasCorrect: wasCorrect)
        saveState()
    }

    /// Get calibrated confidence
    public func calibratedConfidence(_ rawConfidence: Float) -> Float {
        calibration.calibrate(rawConfidence: rawConfidence)
    }

    // MARK: - Statistics

    public var reflexionStats: ReflexionStats {
        let successfulCycles = recentCycles.filter { $0.wasSuccessful }.count
        let avgIterations = recentCycles.isEmpty ? 0 :
            Float(recentCycles.map { $0.iterationCount }.reduce(0, +)) / Float(recentCycles.count)
        let avgConfidence = recentCycles.isEmpty ? 0 :
            recentCycles.map { $0.confidenceScore }.reduce(0, +) / Float(recentCycles.count)

        return ReflexionStats(
            totalCycles: recentCycles.count,
            successfulCycles: successfulCycles,
            averageIterations: avgIterations,
            averageConfidence: avgConfidence,
            totalFailuresAnalyzed: failureAnalyses.count,
            strategiesLearned: strategies.count,
            calibrationAccuracy: calibration.overallAccuracy
        )
    }

    // MARK: - Persistence

    private func loadState() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let state = try JSONDecoder().decode(ReflexionState.self, from: data)
            self.failureAnalyses = state.failureAnalyses
            self.strategies = state.strategies
            self.calibration = state.calibration
            logger.info("Loaded reflection state: \(self.strategies.count) strategies, \(self.failureAnalyses.count) failures")
        } catch {
            logger.error("Failed to load reflection state: \(error.localizedDescription)")
        }
    }

    private func saveState() {
        do {
            let state = ReflexionState(
                failureAnalyses: failureAnalyses,
                strategies: strategies,
                calibration: calibration
            )
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageURL)
        } catch {
            logger.error("Failed to save reflection state: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

public struct ReflexionStats: Sendable {
    public let totalCycles: Int
    public let successfulCycles: Int
    public let averageIterations: Float
    public let averageConfidence: Float
    public let totalFailuresAnalyzed: Int
    public let strategiesLearned: Int
    public let calibrationAccuracy: Float

    public var successRate: Float {
        guard totalCycles > 0 else { return 0 }
        return Float(successfulCycles) / Float(totalCycles)
    }
}

private struct ReflexionState: Codable {
    let failureAnalyses: [FailureAnalysis]
    let strategies: [LearnedStrategy]
    let calibration: ConfidenceCalibration
}
