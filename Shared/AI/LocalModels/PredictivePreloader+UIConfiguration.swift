//
//  PredictivePreloader+UIConfiguration.swift
//  Thea
//
//  Time-based UI configuration, mode determination, recommendations,
//  quick actions, theme preferences, and time-block productivity analysis.
//
//  Split from PredictivePreloader.swift for single-responsibility clarity.
//

import Foundation

// MARK: - Time-Based UI Configuration

extension PredictivePreloader {

    /// Generate a UI configuration snapshot based on current time-of-day patterns.
    ///
    /// Combines learned task distributions for the current hour with contextual
    /// factors (day of week) to produce actionable UI recommendations, quick-action
    /// suggestions, and theme preferences.
    ///
    /// - Returns: A ``TimeBasedUIConfiguration`` reflecting the recommended UI state.
    func getTimeBasedUIConfiguration() -> TimeBasedUIConfiguration {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())

        // Get dominant task types for current hour
        let hourPatterns = timeOfDayPatterns[currentHour] ?? [:]
        let totalCount = hourPatterns.values.reduce(0, +)

// periphery:ignore - Reserved: getTimeBasedUIConfiguration() instance method reserved for future feature activation

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

    /// Determine the primary UI mode based on task distribution and time of day.
    ///
    /// If a single task category dominates (> 40% of the distribution), the mode
    /// is set accordingly. Otherwise, falls back to time-based defaults (morning,
    /// afternoon productivity, evening wind-down, etc.).
    ///
    /// - Parameters:
    ///   - distribution: Task type to probability mapping for the current hour.
    ///   - hour: The current hour (0-23).
    /// - Returns: The recommended ``UIMode``.
    func determinePrimaryMode(from distribution: [TaskType: Double], hour: Int) -> UIMode {
        // Check for dominant task type
        if let dominant = distribution.max(by: { $0.value < $1.value }),
           dominant.value > 0.4 {
            switch dominant.key {
            case .codeGeneration, .codeAnalysis, .debugging:
                // periphery:ignore - Reserved: determinePrimaryMode(from:hour:) instance method reserved for future feature activation
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

    /// Generate specific UI recommendations for a given mode and context.
    ///
    /// - Parameters:
    ///   - primaryMode: The dominant UI mode for the current context.
    ///   - taskDistribution: Task type probability distribution for the current hour.
    ///   - hour: The current hour (0-23).
    ///   - dayOfWeek: The current day of week (1=Sunday, 7=Saturday).
    /// - Returns: An array of ``UIRecommendation`` values to apply.
    func generateUIRecommendations(
        primaryMode: UIMode,
        taskDistribution: [TaskType: Double],
        hour: Int,
        dayOfWeek: Int
    // periphery:ignore - Reserved: generateUIRecommendations(primaryMode:taskDistribution:hour:dayOfWeek:) instance method reserved for future feature activation
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

    /// Suggest quick-action buttons based on the highest-probability predicted tasks.
    ///
    /// Returns up to 4 actions for tasks with probability > 10%.
    ///
    /// - Parameter taskDistribution: Task type to probability mapping.
    /// - Returns: An array of ``PredictedQuickAction`` for the UI.
    func getSuggestedPredictedQuickActions(taskDistribution: [TaskType: Double]) -> [PredictedQuickAction] {
        var actions: [PredictedQuickAction] = []

        // Sort task types by probability
        // periphery:ignore - Reserved: getSuggestedPredictedQuickActions(taskDistribution:) instance method reserved for future feature activation
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

    /// Determine the recommended color theme based on the current hour.
    ///
    /// - Parameter hour: The current hour (0-23).
    /// - Returns: The recommended ``ThemePreference``.
    func getThemePreference(hour: Int) -> ThemePreference {
        switch hour {
        case 6..<8:
            // periphery:ignore - Reserved: getThemePreference(hour:) instance method reserved for future feature activation
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

    /// Calculate confidence in the UI configuration based on available data.
    ///
    /// Combines data volume (more samples = higher confidence) with concentration
    /// (a dominant pattern = higher confidence).
    ///
    /// - Parameter hourPatterns: Task type to count mapping for the relevant hour.
    /// - Returns: A confidence score in the range `0.0...1.0`.
    func calculateConfidence(hourPatterns: [TaskType: Double]) -> Double {
        let totalCount = hourPatterns.values.reduce(0, +)

// periphery:ignore - Reserved: calculateConfidence(hourPatterns:) instance method reserved for future feature activation

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
}

// MARK: - Time Block Analysis

extension PredictivePreloader {

    /// Analyze productivity patterns across predefined time blocks.
    ///
    /// Divides the day into 7 named blocks (Early Morning, Morning, Midday,
    /// Afternoon, Evening, Night, Late Night) and aggregates task data within
    /// each to produce dominant task types and weighted productivity scores.
    ///
    /// - Returns: An array of ``TimeBlockAnalysis`` for each time block.
    func analyzeTimeBlocks() -> [TimeBlockAnalysis] {
        // periphery:ignore - Reserved: analyzeTimeBlocks() instance method reserved for future feature activation
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

    /// Calculate a weighted productivity score for a set of task counts.
    ///
    /// Different task types receive different productivity weights (e.g. code generation
    /// scores 1.0, conversation scores 0.5). The result is a weighted average.
    ///
    /// - Parameter taskCounts: Task type to count mapping.
    /// - Returns: A productivity score in the range `0.0...1.0`.
    // periphery:ignore - Reserved: calculateProductivityScore(taskCounts:) instance method reserved for future feature activation
    func calculateProductivityScore(taskCounts: [TaskType: Double]) -> Double {
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
