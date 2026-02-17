// PredictiveLifeEngine+CyclePredictions.swift
// Thea V2 - Prediction Cycle & Generators
//
// The scheduled prediction cycle and its three generators:
// time-based, context-based, and AI-powered predictions.
// Split from PredictiveLifeEngine.swift for single-responsibility clarity.

import Foundation

// MARK: - Prediction Cycle

extension PredictiveLifeEngine {

    /// Runs a full prediction cycle: cleanup, generate, sort, and trim.
    ///
    /// Called periodically by the background loop started in ``start()``,
    /// or manually via ``triggerPredictions()``.
    func runPredictionCycle() async {
        guard !isProcessing else { return }
        isProcessing = true

        logger.debug("Running prediction cycle")

        // Remove expired predictions
        cleanupExpiredPredictions()

        // Generate time-based predictions
        await generateTimeBasedPredictions()

        // Generate context-based predictions
        await generateContextBasedPredictions()

        // Use AI for complex predictions if configured
        if configuration.useAIForComplexPredictions {
            await generateAIPredictions()
        }

        // Sort predictions by relevance
        activePredictions.sort { $0.relevance * $0.confidence > $1.relevance * $1.confidence }

        // Keep only top predictions
        if activePredictions.count > configuration.maxActivePredictions {
            activePredictions = Array(activePredictions.prefix(configuration.maxActivePredictions))
        }

        lastPredictionRun = Date()
        isProcessing = false
    }
}

// MARK: - Time-Based Predictions

extension PredictiveLifeEngine {

    /// Generates predictions based on the current time of day.
    ///
    /// Produces contextual suggestions for:
    /// - **Morning (6-9)**: Peak focus time approaching
    /// - **Midday (11-13)**: Lunch / break reminder
    /// - **Evening (20-22)**: Sleep hygiene wind-down
    func generateTimeBasedPredictions() async {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Morning predictions
        if hour >= 6 && hour <= 9 {
            if !hasPrediction(ofType: .optimalTime, within: 3600) {
                let prediction = LifePrediction(
                    type: .optimalTime,
                    title: "Peak Focus Time Approaching",
                    description: "Based on your patterns, the next 2-3 hours are typically your most productive. Plan important work now.",
                    confidence: 0.65,
                    timeframe: .shortTerm,
                    relevance: 0.7,
                    basedOn: ["Time of day: Morning", "Historical productivity patterns"]
                )
                addOrUpdatePrediction(prediction)
            }
        }

        // Lunch time
        if hour >= 11 && hour <= 13 {
            if !hasPrediction(ofType: .nutritionReminder, within: 7200) {
                let prediction = LifePrediction(
                    type: .nutritionReminder,
                    title: "Lunch Time",
                    description: "It's around your typical lunch time. Taking a proper break can improve afternoon productivity.",
                    confidence: 0.6,
                    timeframe: .shortTerm,
                    relevance: 0.5,
                    basedOn: ["Time of day: Midday"]
                )
                addOrUpdatePrediction(prediction)
            }
        }

        // Evening wind-down
        if hour >= 20 && hour <= 22 {
            if !hasPrediction(ofType: .sleepImpact, within: 7200) {
                let prediction = LifePrediction(
                    type: .sleepImpact,
                    title: "Evening Wind-Down",
                    description: "Consider reducing screen brightness and avoiding intense work to prepare for sleep.",
                    confidence: 0.7,
                    timeframe: .mediumTerm,
                    relevance: 0.6,
                    suggestedActions: [
                        PredictedAction(
                            title: "Enable Night Shift",
                            description: "Reduce blue light to improve sleep quality",
                            type: .automate,
                            automatable: true,
                            impact: 0.2,
                            effort: "minimal"
                        )
                    ],
                    basedOn: ["Time of day: Evening", "Sleep hygiene best practices"]
                )
                addOrUpdatePrediction(prediction)
            }
        }
    }
}

// MARK: - Context-Based Predictions

extension PredictiveLifeEngine {

    /// Generates predictions by analyzing the recent context window.
    ///
    /// Requires at least 10 context snapshots. Currently detects
    /// declining focus via app-switch rate and activity variance.
    func generateContextBasedPredictions() async {
        // Analyze recent context for patterns
        guard contextWindow.count >= 10 else { return }

        // Check for productivity patterns
        let productivityContext = analyzeProductivityContext()

        if productivityContext.focusLevel < 0.5 && !hasPrediction(ofType: .focusBreak, within: 1800) {
            let prediction = LifePrediction(
                type: .focusBreak,
                title: "Focus Declining",
                description: "Your recent activity suggests declining focus. A short break or change of task might help.",
                confidence: productivityContext.confidence,
                timeframe: .immediate,
                relevance: 0.85,
                suggestedActions: [
                    PredictedAction(
                        title: "Quick walk",
                        description: "Even a 2-minute walk can reset your focus",
                        type: .doNow,
                        impact: 0.3,
                        effort: "minimal"
                    )
                ],
                basedOn: productivityContext.factors
            )
            addOrUpdatePrediction(prediction)
        }
    }

    /// Analyzes the last 20 context snapshots for productivity signals.
    ///
    /// - Returns: A tuple of focus level [0, 1], confidence [0, 1], and
    ///   human-readable factor descriptions.
    func analyzeProductivityContext() -> (focusLevel: Double, confidence: Double, factors: [String]) {
        let recent = contextWindow.suffix(20)
        var factors: [String] = []

        // Calculate app switch rate
        let switches = recent.filter { $0.eventType == "app_switch" }.count
        let switchRate = Double(switches) / 20.0

        if switchRate > 0.3 {
            factors.append("High app switching rate: \(Int(switchRate * 100))%")
        }

        // Calculate activity variance
        let uniqueTypes = Set(recent.map { $0.eventType }).count
        if uniqueTypes > 8 {
            factors.append("High activity variance: \(uniqueTypes) different activities")
        }

        // Simple focus level calculation
        let focusLevel = max(0, 1.0 - switchRate - Double(uniqueTypes) / 20.0)
        let confidence = min(0.9, Double(recent.count) / 20.0)

        return (focusLevel, confidence, factors)
    }
}

// MARK: - AI-Powered Predictions

extension PredictiveLifeEngine {

    /// Generates complex predictions using an AI provider.
    ///
    /// Sends a structured prompt with the current context and pattern
    /// summaries to an available AI provider (preferring OpenRouter,
    /// then Anthropic, then the user's default). Parses the JSON
    /// response into up to 3 ``LifePrediction`` instances.
    func generateAIPredictions() async {
        guard let provider = ProviderRegistry.shared.getProvider(id: "openrouter")
                          ?? ProviderRegistry.shared.getProvider(id: "anthropic")
                          ?? ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            logger.info("No provider available for AI predictions")
            return
        }

        let contextSummary = buildContextSummary()
        let patternSummary = buildPatternSummary()

        let prompt = """
        Analyze user activity patterns and generate up to 3 actionable predictions. \
        Respond in JSON array format only.

        \(contextSummary)
        \(patternSummary)
        Current time: \(ISO8601DateFormatter().string(from: Date()))

        Each prediction must have:
        {"type": "one of: energy_peak|focus_window|break_needed|task_completion|context_switch|\
        sleep_impact|activity_deficit|nutrition|bottleneck",
        "title": "Short title",
        "description": "1-2 sentence explanation",
        "confidence": 0.0-1.0,
        "timeframe_hours": 0.5-24,
        "action": "Suggested action"}

        Respond with ONLY a JSON array of predictions, no other text.
        """

        let modelId = "openai/gpt-4o-mini"
        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: modelId
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: modelId,
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    responseText += text
                } else if case .complete(let msg) = chunk.type {
                    responseText = msg.content.textValue
                }
            }

            // Parse JSON predictions
            guard let jsonStart = responseText.firstIndex(of: "["),
                  let jsonEnd = responseText.lastIndex(of: "]") else {
                logger.warning("AI predictions response not in expected JSON array format")
                return
            }

            let jsonStr = String(responseText[jsonStart...jsonEnd])
            guard let data = jsonStr.data(using: .utf8) else { return }

            struct AIPrediction: Decodable {
                let type: String
                let title: String
                let description: String
                let confidence: Double
                // swiftlint:disable:next identifier_name
                let timeframe_hours: Double?
                let action: String?
            }

            let aiPredictions = try JSONDecoder().decode([AIPrediction].self, from: data)

            for ai in aiPredictions.prefix(3) {
                let predType = LifePredictionType(rawValue: ai.type) ?? .contextSwitch
                let hours = ai.timeframe_hours ?? 1.0
                let prediction = LifePrediction(
                    type: predType,
                    title: ai.title,
                    description: ai.description,
                    confidence: min(max(ai.confidence, 0.1), 0.95),
                    timeframe: PredictionTimeframe(horizon: hours * 3600),
                    relevance: ai.confidence,
                    actionability: ai.confidence > 0.7 ? .recommended : .informational,
                    suggestedActions: ai.action.map { action in
                        [PredictedAction(
                            title: action,
                            description: action,
                            type: .adjust,
                            automatable: false,
                            impact: ai.confidence,
                            effort: "Low"
                        )]
                    } ?? [],
                    basedOn: ["AI analysis of activity patterns"],
                    createdAt: Date(),
                    expiresAt: Date().addingTimeInterval(hours * 3600)
                )
                addOrUpdatePrediction(prediction)
            }

            logger.info("Generated \(aiPredictions.count) AI predictions")
        } catch {
            logger.warning("AI prediction generation failed: \(error.localizedDescription)")
        }
    }

    /// Builds a human-readable summary of the recent context window.
    ///
    /// Aggregates the last 50 context snapshots by event type
    /// and returns a formatted string with counts, sorted by frequency.
    ///
    /// - Returns: A multi-line summary string.
    func buildContextSummary() -> String {
        let recent = contextWindow.suffix(50)
        var summary = "Recent activity (\(recent.count) events):\n"

        var eventCounts: [String: Int] = [:]
        for event in recent {
            eventCounts[event.eventType, default: 0] += 1
        }

        for (type, count) in eventCounts.sorted(by: { $0.value > $1.value }).prefix(10) {
            summary += "- \(type): \(count) times\n"
        }

        return summary
    }

    /// Builds a human-readable summary of currently detected patterns.
    ///
    /// Lists the top 10 patterns from ``HolisticPatternIntelligence``
    /// with their confidence percentages.
    ///
    /// - Returns: A multi-line summary string.
    func buildPatternSummary() -> String {
        let patterns = HolisticPatternIntelligence.shared.detectedPatterns
        var summary = "Known patterns (\(patterns.count)):\n"

        for pattern in patterns.prefix(10) {
            summary += "- \(pattern.name) (confidence: \(String(format: "%.0f", pattern.confidence * 100))%)\n"
        }

        return summary
    }
}
