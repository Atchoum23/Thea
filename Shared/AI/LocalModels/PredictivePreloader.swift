//
//  PredictivePreloader.swift
//  Thea
//
//  Predicts upcoming model needs using learned Markov chains of user behavior
//  Enables proactive model loading before user requests
//
//  ALGORITHM:
//  1. Tracks task type transitions (what task follows what)
//  2. Builds probability matrix of task sequences
//  3. Uses time-of-day patterns for contextual prediction
//  4. Applies Exponential Moving Average for recency weighting
//
//  CREATED: February 5, 2026
//

import Foundation
import OSLog

// MARK: - Predictive Preloader

/// Predicts upcoming model needs using learned behavior patterns
final class PredictivePreloader: @unchecked Sendable {
    private let logger = Logger(subsystem: "ai.thea.app", category: "PredictivePreloader")

    // MARK: - State

    /// Markov chain transition matrix: [fromTask][toTask] = probability
    private var transitionMatrix: [TaskType: [TaskType: Double]] = [:]

    /// Time-of-day task distribution
    private var timeOfDayPatterns: [Int: [TaskType: Double]] = [:] // Hour -> TaskType -> Probability

    /// Recent task history (for recency weighting)
    private var recentTasks: [TaskTypeTimestamp] = []

    /// EMA alpha for recency weighting (higher = more weight to recent)
    private let emaAlpha: Double = 0.3

    /// Maximum history size
    private let maxHistorySize = 500

    /// Persistence keys
    private let transitionMatrixKey = "PredictivePreloader.transitionMatrix"
    private let timeOfDayPatternsKey = "PredictivePreloader.timeOfDayPatterns"
    private let recentTasksKey = "PredictivePreloader.recentTasks"

    // MARK: - Initialization

    init() {
        loadPersistedState()
    }

    // MARK: - Recording

    /// Record a task request for learning
    func recordTaskRequest(_ taskType: TaskType) {
        let timestamp = Date()
        let hour = Calendar.current.component(.hour, from: timestamp)

        // Record in history
        let record = TaskTypeTimestamp(taskType: taskType, timestamp: timestamp)
        recentTasks.append(record)

        // Trim history if needed
        if recentTasks.count > maxHistorySize {
            recentTasks.removeFirst(recentTasks.count - maxHistorySize)
        }

        // Update transition matrix with previous task
        if recentTasks.count >= 2 {
            let previousTask = recentTasks[recentTasks.count - 2].taskType
            updateTransitionMatrix(from: previousTask, to: taskType)
        }

        // Update time-of-day patterns
        updateTimeOfDayPattern(hour: hour, taskType: taskType)

        // Persist periodically
        if recentTasks.count % 10 == 0 {
            persistState()
        }

        logger.debug("Recorded task: \(taskType.rawValue) at hour \(hour)")
    }

    /// Update transition matrix with new observation
    private func updateTransitionMatrix(from: TaskType, to: TaskType) {
        // Initialize if needed
        if transitionMatrix[from] == nil {
            transitionMatrix[from] = [:]
        }

        // Get current count (we store counts, then normalize for probability)
        let currentCount = transitionMatrix[from]?[to] ?? 0

        // Apply EMA update: new_value = alpha * 1.0 + (1 - alpha) * old_value
        // Since we're counting occurrences, we increment and apply decay to others
        transitionMatrix[from]?[to] = currentCount + 1.0

        // Apply decay to other transitions from this state
        for otherTask in TaskType.allCases where otherTask != to {
            if let count = transitionMatrix[from]?[otherTask], count > 0 {
                transitionMatrix[from]?[otherTask] = count * (1 - emaAlpha * 0.1)
            }
        }
    }

    /// Update time-of-day patterns
    private func updateTimeOfDayPattern(hour: Int, taskType: TaskType) {
        if timeOfDayPatterns[hour] == nil {
            timeOfDayPatterns[hour] = [:]
        }

        let currentCount = timeOfDayPatterns[hour]?[taskType] ?? 0
        timeOfDayPatterns[hour]?[taskType] = currentCount + 1.0
    }

    // MARK: - Prediction

    /// Predict next likely tasks based on current state
    func predictNextTasks() -> [TaskPrediction] {
        let currentHour = Calendar.current.component(.hour, from: Date())
        var predictions: [TaskPrediction] = []

        // Get last task for Markov prediction
        let lastTask = recentTasks.last?.taskType

        // 1. Markov chain predictions (60% weight)
        var markovPredictions: [TaskType: Double] = [:]
        if let lastTask = lastTask, let transitions = transitionMatrix[lastTask] {
            let totalCount = transitions.values.reduce(0, +)
            if totalCount > 0 {
                for (task, count) in transitions {
                    markovPredictions[task] = count / totalCount
                }
            }
        }

        // 2. Time-of-day predictions (40% weight)
        var todPredictions: [TaskType: Double] = [:]
        if let hourPatterns = timeOfDayPatterns[currentHour] {
            let totalCount = hourPatterns.values.reduce(0, +)
            if totalCount > 0 {
                for (task, count) in hourPatterns {
                    todPredictions[task] = count / totalCount
                }
            }
        }

        // Combine predictions
        var combinedScores: [TaskType: Double] = [:]
        for task in TaskType.allCases {
            let markovScore = markovPredictions[task] ?? 0.0
            let todScore = todPredictions[task] ?? 0.0
            combinedScores[task] = (markovScore * 0.6) + (todScore * 0.4)
        }

        // Apply recency boost for recently used task types
        let recentTaskTypes = Set(recentTasks.suffix(5).map { $0.taskType })
        for task in recentTaskTypes {
            combinedScores[task] = (combinedScores[task] ?? 0) * 1.1
        }

        // Convert to predictions array
        for (task, score) in combinedScores where score > 0.05 {
            predictions.append(TaskPrediction(
                taskType: task,
                probability: min(1.0, score),
                source: determineSource(markov: markovPredictions[task], tod: todPredictions[task])
            ))
        }

        // Sort by probability
        predictions.sort { $0.probability > $1.probability }

        return predictions
    }

    /// Determine prediction source
    private func determineSource(markov: Double?, tod: Double?) -> PredictionSource {
        let m = markov ?? 0
        let t = tod ?? 0

        if m > t * 1.5 {
            return .markovChain
        } else if t > m * 1.5 {
            return .timeOfDay
        }
        return .combined
    }

    /// Get transition probability between two tasks
    func getTransitionProbability(from: TaskType, to: TaskType) -> Double {
        guard let transitions = transitionMatrix[from] else { return 0.0 }
        let totalCount = transitions.values.reduce(0, +)
        guard totalCount > 0 else { return 0.0 }
        return (transitions[to] ?? 0) / totalCount
    }

    /// Get most likely next task after a given task
    func getMostLikelyNextTask(after task: TaskType) -> TaskType? {
        guard let transitions = transitionMatrix[task] else { return nil }
        return transitions.max { $0.value < $1.value }?.key
    }

    // MARK: - Sequence Analysis

    /// Detect common task sequences
    func detectCommonSequences(minLength: Int = 2, maxLength: Int = 4) -> [TaskSequence] {
        guard recentTasks.count >= minLength else { return [] }

        var sequences: [String: Int] = [:] // sequence_key -> count

        // Sliding window to find sequences
        for length in minLength...maxLength {
            for i in 0...(recentTasks.count - length) {
                let sequence = Array(recentTasks[i..<(i + length)]).map { $0.taskType }
                let key = sequence.map { $0.rawValue }.joined(separator: "->")
                sequences[key, default: 0] += 1
            }
        }

        // Filter for sequences that occur multiple times
        var result: [TaskSequence] = []
        for (key, count) in sequences where count >= 3 {
            let taskNames = key.split(separator: "->").map(String.init)
            let tasks = taskNames.compactMap { TaskType(rawValue: $0) }
            if tasks.count == taskNames.count {
                result.append(TaskSequence(
                    tasks: tasks,
                    occurrences: count,
                    probability: Double(count) / Double(recentTasks.count - tasks.count + 1)
                ))
            }
        }

        result.sort { $0.occurrences > $1.occurrences }
        return result
    }

    /// Check if current context matches a known sequence
    func matchesSequenceStart() -> TaskSequence? {
        let sequences = detectCommonSequences()
        let recentTaskTypes = recentTasks.suffix(3).map { $0.taskType }

        for sequence in sequences {
            if sequence.tasks.count > recentTaskTypes.count {
                let prefix = Array(sequence.tasks.prefix(recentTaskTypes.count))
                if prefix == recentTaskTypes {
                    return sequence
                }
            }
        }
        return nil
    }

    // MARK: - Statistics

    /// Get prediction accuracy statistics
    func getPredictionStats() -> PredictionStats {
        var taskCounts: [TaskType: Int] = [:]
        for record in recentTasks {
            taskCounts[record.taskType, default: 0] += 1
        }

        let totalTasks = recentTasks.count
        let uniqueTransitions = transitionMatrix.values.reduce(0) { $0 + $1.count }
        let hoursWithData = timeOfDayPatterns.count

        // Calculate entropy (uncertainty measure)
        var entropy: Double = 0
        if totalTasks > 0 {
            for (_, count) in taskCounts {
                let p = Double(count) / Double(totalTasks)
                if p > 0 {
                    entropy -= p * log2(p)
                }
            }
        }

        return PredictionStats(
            totalTasksRecorded: totalTasks,
            uniqueTaskTypes: taskCounts.count,
            uniqueTransitions: uniqueTransitions,
            hoursWithData: hoursWithData,
            entropy: entropy,
            mostFrequentTask: taskCounts.max { $0.value < $1.value }?.key
        )
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        // Load transition matrix
        if let data = UserDefaults.standard.data(forKey: transitionMatrixKey),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            // Convert string keys back to TaskType
            for (fromKey, toDict) in decoded {
                if let fromTask = TaskType(rawValue: fromKey) {
                    transitionMatrix[fromTask] = [:]
                    for (toKey, value) in toDict {
                        if let toTask = TaskType(rawValue: toKey) {
                            transitionMatrix[fromTask]?[toTask] = value
                        }
                    }
                }
            }
        }

        // Load time-of-day patterns
        if let data = UserDefaults.standard.data(forKey: timeOfDayPatternsKey),
           let decoded = try? JSONDecoder().decode([Int: [String: Double]].self, from: data) {
            for (hour, taskDict) in decoded {
                timeOfDayPatterns[hour] = [:]
                for (taskKey, value) in taskDict {
                    if let task = TaskType(rawValue: taskKey) {
                        timeOfDayPatterns[hour]?[task] = value
                    }
                }
            }
        }

        // Load recent tasks
        if let data = UserDefaults.standard.data(forKey: recentTasksKey),
           let decoded = try? JSONDecoder().decode([TaskTypeTimestamp].self, from: data) {
            recentTasks = decoded
        }

        logger.debug("Loaded prediction state: \(self.recentTasks.count) tasks, \(self.transitionMatrix.count) transition states")
    }

    private func persistState() {
        // Convert transition matrix to string keys for JSON encoding
        var encodableMatrix: [String: [String: Double]] = [:]
        for (fromTask, toDict) in transitionMatrix {
            encodableMatrix[fromTask.rawValue] = [:]
            for (toTask, value) in toDict {
                encodableMatrix[fromTask.rawValue]?[toTask.rawValue] = value
            }
        }
        if let data = try? JSONEncoder().encode(encodableMatrix) {
            UserDefaults.standard.set(data, forKey: transitionMatrixKey)
        }

        // Convert time-of-day patterns
        var encodableToD: [Int: [String: Double]] = [:]
        for (hour, taskDict) in timeOfDayPatterns {
            encodableToD[hour] = [:]
            for (task, value) in taskDict {
                encodableToD[hour]?[task.rawValue] = value
            }
        }
        if let data = try? JSONEncoder().encode(encodableToD) {
            UserDefaults.standard.set(data, forKey: timeOfDayPatternsKey)
        }

        // Save recent tasks
        if let data = try? JSONEncoder().encode(recentTasks) {
            UserDefaults.standard.set(data, forKey: recentTasksKey)
        }
    }

    /// Clear all learned data
    func reset() {
        transitionMatrix.removeAll()
        timeOfDayPatterns.removeAll()
        recentTasks.removeAll()
        persistState()
        logger.info("Prediction data reset")
    }

    // MARK: - Time-Based UI Configuration

    /// Get UI configuration based on time-of-day patterns
    /// Uses learned behavior to pre-configure UI for likely activities
    func getTimeBasedUIConfiguration() -> TimeBasedUIConfiguration {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())

        // Get dominant task types for current hour
        let hourPatterns = timeOfDayPatterns[currentHour] ?? [:]
        let totalCount = hourPatterns.values.reduce(0, +)

        // Calculate task distributions
        var taskDistribution: [TaskType: Double] = [:]
        for (task, count) in hourPatterns {
            taskDistribution[task] = totalCount > 0 ? count / totalCount : 0
        }

        // Determine primary mode based on patterns
        let primaryMode = determinePrimaryMode(from: taskDistribution, hour: currentHour)

        // Generate UI recommendations
        let uiRecommendations = generateUIRecommendations(
            primaryMode: primaryMode,
            taskDistribution: taskDistribution,
            hour: currentHour,
            dayOfWeek: dayOfWeek
        )

        // Get suggested quick actions
        let quickActions = getSuggestedPredictedQuickActions(taskDistribution: taskDistribution)

        // Determine theme preference
        let themePreference = getThemePreference(hour: currentHour)

        return TimeBasedUIConfiguration(
            timestamp: Date(),
            hour: currentHour,
            dayOfWeek: dayOfWeek,
            primaryMode: primaryMode,
            taskDistribution: taskDistribution,
            uiRecommendations: uiRecommendations,
            quickActions: quickActions,
            themePreference: themePreference,
            confidence: calculateConfidence(hourPatterns: hourPatterns)
        )
    }

    /// Determine primary UI mode based on task distribution
    private func determinePrimaryMode(from distribution: [TaskType: Double], hour: Int) -> UIMode {
        // Check for dominant task type
        if let dominant = distribution.max(by: { $0.value < $1.value }),
           dominant.value > 0.4 {
            switch dominant.key {
            case .codeGeneration, .codeAnalysis, .debugging:
                return .coding
            case .creative, .creativeWriting, .contentCreation:
                return .creative
            case .research, .analysis, .factual:
                return .research
            case .conversation:
                return .conversation
            case .math:
                return .productivity
            default:
                break
            }
        }

        // Fall back to time-based defaults
        switch hour {
        case 6..<9:
            return .morning
        case 9..<12:
            return .productivity
        case 12..<14:
            return .casual
        case 14..<18:
            return .productivity
        case 18..<21:
            return .evening
        case 21..<24, 0..<6:
            return .night
        default:
            return .productivity
        }
    }

    /// Generate UI recommendations based on context
    private func generateUIRecommendations(
        primaryMode: UIMode,
        taskDistribution: [TaskType: Double],
        hour: Int,
        dayOfWeek: Int
    ) -> [UIRecommendation] {
        var recommendations: [UIRecommendation] = []

        // Mode-specific recommendations
        switch primaryMode {
        case .coding:
            recommendations.append(.showCodeTools)
            recommendations.append(.enableSyntaxHighlighting)
            recommendations.append(.expandInputField)

        case .creative:
            recommendations.append(.showCreativeTools)
            recommendations.append(.enableMarkdownPreview)
            recommendations.append(.hideCodeTools)

        case .research:
            recommendations.append(.showSourcePanel)
            recommendations.append(.enableCitations)
            recommendations.append(.expandOutputArea)

        case .productivity:
            recommendations.append(.showPredictedQuickActions)
            recommendations.append(.enableTaskTracking)

        case .morning:
            recommendations.append(.showDailyBrief)
            recommendations.append(.enableCalendarIntegration)

        case .evening:
            recommendations.append(.showSummaryView)
            recommendations.append(.reduceBrightness)

        case .night:
            recommendations.append(.enableDarkMode)
            recommendations.append(.reduceBrightness)
            recommendations.append(.minimizeAnimations)

        case .casual, .conversation:
            recommendations.append(.showSimplifiedUI)
        }

        // Weekend-specific adjustments
        if dayOfWeek == 1 || dayOfWeek == 7 {
            recommendations.append(.relaxedMode)
        }

        return recommendations
    }

    /// Get suggested quick actions based on patterns
    private func getSuggestedPredictedQuickActions(taskDistribution: [TaskType: Double]) -> [PredictedQuickAction] {
        var actions: [PredictedQuickAction] = []

        // Sort task types by probability
        let sortedTasks = taskDistribution.sorted { $0.value > $1.value }

        for (task, probability) in sortedTasks.prefix(4) {
            guard probability > 0.1 else { continue }

            switch task {
            case .codeGeneration:
                actions.append(PredictedQuickAction(
                    id: "code_generate",
                    title: "Generate Code",
                    icon: "chevron.left.forwardslash.chevron.right",
                    action: "code_generation"
                ))

            case .debugging:
                actions.append(PredictedQuickAction(
                    id: "debug_help",
                    title: "Debug Issue",
                    icon: "ladybug",
                    action: "debugging"
                ))

            case .creative:
                actions.append(PredictedQuickAction(
                    id: "creative_write",
                    title: "Creative Writing",
                    icon: "pencil.and.outline",
                    action: "creative"
                ))

            case .research:
                actions.append(PredictedQuickAction(
                    id: "research",
                    title: "Research Topic",
                    icon: "magnifyingglass",
                    action: "research"
                ))

            case .summarization:
                actions.append(PredictedQuickAction(
                    id: "summarize",
                    title: "Summarize",
                    icon: "doc.text",
                    action: "summarization"
                ))

            case .math:
                actions.append(PredictedQuickAction(
                    id: "calculate",
                    title: "Calculate",
                    icon: "function",
                    action: "math"
                ))

            default:
                break
            }
        }

        return actions
    }

    /// Get theme preference based on hour
    private func getThemePreference(hour: Int) -> ThemePreference {
        switch hour {
        case 6..<8:
            return .warmLight
        case 8..<18:
            return .system
        case 18..<20:
            return .warmDark
        case 20..<24, 0..<6:
            return .dark
        default:
            return .system
        }
    }

    /// Calculate confidence in the configuration
    private func calculateConfidence(hourPatterns: [TaskType: Double]) -> Double {
        let totalCount = hourPatterns.values.reduce(0, +)

        // More data = higher confidence
        let dataConfidence = min(1.0, totalCount / 50.0)

        // More concentrated patterns = higher confidence
        let concentrationConfidence: Double
        if let maxValue = hourPatterns.values.max(), totalCount > 0 {
            concentrationConfidence = maxValue / totalCount
        } else {
            concentrationConfidence = 0
        }

        return (dataConfidence * 0.6) + (concentrationConfidence * 0.4)
    }

    // MARK: - Time Block Analysis

    /// Analyze productivity patterns by time block
    func analyzeTimeBlocks() -> [TimeBlockAnalysis] {
        var blocks: [TimeBlockAnalysis] = []

        let timeBlockRanges: [(String, ClosedRange<Int>)] = [
            ("Early Morning", 5...7),
            ("Morning", 8...11),
            ("Midday", 12...13),
            ("Afternoon", 14...17),
            ("Evening", 18...20),
            ("Night", 21...23),
            ("Late Night", 0...4)
        ]

        for (name, range) in timeBlockRanges {
            var taskCounts: [TaskType: Double] = [:]
            var totalCount: Double = 0

            for hour in range {
                if let patterns = timeOfDayPatterns[hour] {
                    for (task, count) in patterns {
                        taskCounts[task, default: 0] += count
                        totalCount += count
                    }
                }
            }

            let dominantTask = taskCounts.max { $0.value < $1.value }?.key
            let productivity = calculateProductivityScore(taskCounts: taskCounts)

            blocks.append(TimeBlockAnalysis(
                name: name,
                hourRange: range,
                dominantTaskType: dominantTask,
                taskDistribution: taskCounts,
                totalSamples: Int(totalCount),
                productivityScore: productivity
            ))
        }

        return blocks
    }

    /// Calculate productivity score for a set of task counts
    private func calculateProductivityScore(taskCounts: [TaskType: Double]) -> Double {
        // Weight different task types by "productivity"
        let weights: [TaskType: Double] = [
            .codeGeneration: 1.0,
            .codeAnalysis: 0.9,
            .debugging: 0.9,
            .research: 0.8,
            .analysis: 0.8,
            .planning: 0.8,
            .creativeWriting: 0.7,
            .summarization: 0.7,
            .math: 0.7,
            .creative: 0.6,
            .conversation: 0.5,
            .factual: 0.5
        ]

        var weightedSum: Double = 0
        var totalCount: Double = 0

        for (task, count) in taskCounts {
            let weight = weights[task] ?? 0.5
            weightedSum += weight * count
            totalCount += count
        }

        return totalCount > 0 ? weightedSum / totalCount : 0
    }
}

// MARK: - Supporting Types

/// Task with timestamp for history tracking
struct TaskTypeTimestamp: Codable, Sendable {
    let taskType: TaskType
    let timestamp: Date
}

/// Task prediction result
struct TaskPrediction: Sendable {
    let taskType: TaskType
    let probability: Double
    let source: PredictionSource
}

/// Source of prediction
enum PredictionSource: String, Sendable {
    case markovChain = "Markov Chain"
    case timeOfDay = "Time of Day"
    case combined = "Combined"
}

/// Detected task sequence
struct TaskSequence: Sendable {
    let tasks: [TaskType]
    let occurrences: Int
    let probability: Double

    var description: String {
        tasks.map { $0.rawValue }.joined(separator: " → ")
    }
}

/// Prediction statistics
struct PredictionStats: Sendable {
    let totalTasksRecorded: Int
    let uniqueTaskTypes: Int
    let uniqueTransitions: Int
    let hoursWithData: Int
    let entropy: Double
    let mostFrequentTask: TaskType?

    /// Lower entropy = more predictable user behavior
    var predictability: String {
        switch entropy {
        case 0..<1.5: return "Highly Predictable"
        case 1.5..<2.5: return "Moderately Predictable"
        case 2.5..<3.5: return "Somewhat Predictable"
        default: return "Low Predictability"
        }
    }
}

// MARK: - Time-Based UI Configuration Types

/// UI configuration based on time-of-day patterns
struct TimeBasedUIConfiguration: Sendable {
    let timestamp: Date
    let hour: Int
    let dayOfWeek: Int
    let primaryMode: UIMode
    let taskDistribution: [TaskType: Double]
    let uiRecommendations: [UIRecommendation]
    let quickActions: [PredictedQuickAction]
    let themePreference: ThemePreference
    let confidence: Double

    /// Whether this configuration has high confidence
    var isHighConfidence: Bool {
        confidence >= 0.6
    }

    /// Get the top predicted task type
    var topPredictedTask: TaskType? {
        taskDistribution.max { $0.value < $1.value }?.key
    }
}

/// UI modes for different contexts
enum UIMode: String, Sendable {
    case morning = "Morning"
    case productivity = "Productivity"
    case coding = "Coding"
    case creative = "Creative"
    case research = "Research"
    case conversation = "Conversation"
    case casual = "Casual"
    case evening = "Evening"
    case night = "Night"

    var description: String {
        switch self {
        case .morning: "Ready to start your day"
        case .productivity: "Focused work mode"
        case .coding: "Development environment"
        case .creative: "Creative writing mode"
        case .research: "Research and analysis"
        case .conversation: "Casual conversation"
        case .casual: "Relaxed interaction"
        case .evening: "Winding down"
        case .night: "Night mode"
        }
    }

    var icon: String {
        switch self {
        case .morning: "sunrise"
        case .productivity: "chart.bar"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .creative: "paintbrush"
        case .research: "magnifyingglass"
        case .conversation: "bubble.left.and.bubble.right"
        case .casual: "face.smiling"
        case .evening: "sunset"
        case .night: "moon.stars"
        }
    }
}

/// UI recommendations for configuration
enum UIRecommendation: String, Sendable {
    // Code-related
    case showCodeTools = "show_code_tools"
    case enableSyntaxHighlighting = "enable_syntax_highlighting"
    case hideCodeTools = "hide_code_tools"

    // Creative-related
    case showCreativeTools = "show_creative_tools"
    case enableMarkdownPreview = "enable_markdown_preview"

    // Research-related
    case showSourcePanel = "show_source_panel"
    case enableCitations = "enable_citations"

    // Layout
    case expandInputField = "expand_input_field"
    case expandOutputArea = "expand_output_area"
    case showSimplifiedUI = "show_simplified_ui"

    // Productivity
    case showPredictedQuickActions = "show_quick_actions"
    case enableTaskTracking = "enable_task_tracking"
    case showDailyBrief = "show_daily_brief"
    case enableCalendarIntegration = "enable_calendar_integration"
    case showSummaryView = "show_summary_view"

    // Visual
    case enableDarkMode = "enable_dark_mode"
    case reduceBrightness = "reduce_brightness"
    case minimizeAnimations = "minimize_animations"
    case relaxedMode = "relaxed_mode"

    var displayName: String {
        switch self {
        case .showCodeTools: "Show Code Tools"
        case .enableSyntaxHighlighting: "Enable Syntax Highlighting"
        case .hideCodeTools: "Hide Code Tools"
        case .showCreativeTools: "Show Creative Tools"
        case .enableMarkdownPreview: "Enable Markdown Preview"
        case .showSourcePanel: "Show Source Panel"
        case .enableCitations: "Enable Citations"
        case .expandInputField: "Expand Input Field"
        case .expandOutputArea: "Expand Output Area"
        case .showSimplifiedUI: "Show Simplified UI"
        case .showPredictedQuickActions: "Show Quick Actions"
        case .enableTaskTracking: "Enable Task Tracking"
        case .showDailyBrief: "Show Daily Brief"
        case .enableCalendarIntegration: "Enable Calendar Integration"
        case .showSummaryView: "Show Summary View"
        case .enableDarkMode: "Enable Dark Mode"
        case .reduceBrightness: "Reduce Brightness"
        case .minimizeAnimations: "Minimize Animations"
        case .relaxedMode: "Relaxed Mode"
        }
    }
}

/// Quick action for predicted tasks
struct PredictedQuickAction: Sendable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let action: String
}

/// Theme preferences based on time
enum ThemePreference: String, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    case warmLight = "warm_light"
    case warmDark = "warm_dark"

    var colorTemperature: Double {
        switch self {
        case .system: 0.0
        case .light: 0.0
        case .dark: 0.0
        case .warmLight: 0.3
        case .warmDark: 0.4
        }
    }
}

/// Analysis of a time block
struct TimeBlockAnalysis: Sendable {
    let name: String
    let hourRange: ClosedRange<Int>
    let dominantTaskType: TaskType?
    let taskDistribution: [TaskType: Double]
    let totalSamples: Int
    let productivityScore: Double

    var hasEnoughData: Bool {
        totalSamples >= 10
    }

    var productivityLevel: String {
        switch productivityScore {
        case 0.8...: "High"
        case 0.6..<0.8: "Medium-High"
        case 0.4..<0.6: "Medium"
        case 0.2..<0.4: "Low-Medium"
        default: "Low"
        }
    }
}
