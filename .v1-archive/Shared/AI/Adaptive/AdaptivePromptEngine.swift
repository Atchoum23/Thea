// AdaptivePromptEngine.swift
// AI-powered adaptive prompt interpretation that learns user's style and anticipates intent
// Creates compounding intelligence through pattern recognition and prediction

import Foundation

// MARK: - Adaptive Prompt Engine

/// AI-powered engine that learns user's prompting style and anticipates intent
/// Implements progressive learning for increasingly accurate interpretation
@MainActor
@Observable
final class AdaptivePromptEngine {
    static let shared = AdaptivePromptEngine()

    // MARK: - State

    private(set) var userPromptProfile = UserPromptProfile()
    private(set) var intentPredictions: [IntentPrediction] = []
    private(set) var suggestedCompletions: [PromptCompletion] = []
    private(set) var workflowPatterns: [WorkflowPattern] = []
    private(set) var isAnalyzing = false

    // Configuration
    private(set) var configuration = Configuration()

    struct Configuration: Codable, Sendable {
        var enableAdaptiveLearning = true
        var enableIntentPrediction = true
        var enableWorkflowSuggestions = true
        var enablePreemptiveActions = true
        var learningRate: Double = 0.1 // How quickly to update patterns
        var confidenceThreshold: Double = 0.7 // Minimum confidence to act
        var maxPatternsStored: Int = 500
        var enableMoodDetection = true
    }

    // MARK: - Initialization

    private init() {
        loadProfile()
        loadConfiguration()
    }

    // MARK: - Prompt Analysis

    /// Analyze a prompt and return enhanced interpretation
    func analyzePrompt(_ prompt: String) async -> PromptAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let analysis = PromptAnalysis(
            originalPrompt: prompt,
            detectedIntent: detectIntent(prompt),
            anticipatedNeeds: anticipateNeeds(prompt),
            suggestedEnhancements: suggestEnhancements(prompt),
            moodIndicators: detectMood(prompt),
            workflowContext: getWorkflowContext(),
            confidenceScore: calculateConfidence(prompt)
        )

        // Learn from this prompt
        await learnFromPrompt(prompt, analysis: analysis)

        return analysis
    }

    /// Predict user's intent from partial prompt (for real-time suggestions)
    func predictIntentFromPartial(_ partialPrompt: String) -> [IntentPrediction] {
        guard configuration.enableIntentPrediction,
              partialPrompt.count >= 3 else { return [] }

        var predictions: [IntentPrediction] = []

        // Match against learned patterns
        for pattern in userPromptProfile.commonPatterns {
            if pattern.prefix.lowercased().hasPrefix(partialPrompt.lowercased()) ||
               partialPrompt.lowercased().contains(pattern.prefix.lowercased()) {
                predictions.append(IntentPrediction(
                    intent: pattern.intent,
                    confidence: pattern.frequency * 0.8,
                    suggestedCompletion: pattern.typicalCompletion,
                    expectedResponse: pattern.expectedResponseType
                ))
            }
        }

        // Add general intent detection
        let generalIntents = detectGeneralIntents(partialPrompt)
        predictions.append(contentsOf: generalIntents)

        intentPredictions = predictions.sorted { $0.confidence > $1.confidence }.prefix(5).map { $0 }
        return intentPredictions
    }

    /// Get suggested completions for current prompt
    func getSuggestedCompletions(for prompt: String) -> [PromptCompletion] {
        let predictions = predictIntentFromPartial(prompt)

        suggestedCompletions = predictions.compactMap { prediction in
            guard let completion = prediction.suggestedCompletion else { return nil }
            return PromptCompletion(
                completion: completion,
                fullPrompt: prompt + " " + completion,
                intent: prediction.intent,
                confidence: prediction.confidence
            )
        }

        return suggestedCompletions
    }

    /// Get proactive suggestions based on context and workflow
    func getProactiveSuggestions() -> [AdaptiveSuggestion] {
        guard configuration.enablePreemptiveActions else { return [] }

        var suggestions: [AdaptiveSuggestion] = []

        // Check workflow patterns for next likely action
        if let currentWorkflow = identifyCurrentWorkflow() {
            if let nextStep = currentWorkflow.predictNextStep() {
                suggestions.append(AdaptiveSuggestion(
                    type: .workflowNext,
                    title: "Continue workflow",
                    description: nextStep.description,
                    suggestedPrompt: nextStep.suggestedPrompt,
                    confidence: currentWorkflow.confidence
                ))
            }
        }

        // Check for time-based suggestions
        let hour = Calendar.current.component(.hour, from: Date())
        if let timePattern = userPromptProfile.timePatterns.first(where: { $0.hour == hour }) {
            suggestions.append(AdaptiveSuggestion(
                type: .timeBased,
                title: timePattern.activityName,
                description: "You often \(timePattern.activityName.lowercased()) at this time",
                suggestedPrompt: timePattern.typicalPrompt,
                confidence: timePattern.frequency
            ))
        }

        // Check for follow-up suggestions based on recent interactions
        if let lastInteraction = userPromptProfile.recentInteractions.last {
            let followUps = suggestFollowUps(for: lastInteraction)
            suggestions.append(contentsOf: followUps)
        }

        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Intent Detection

    private func detectIntent(_ prompt: String) -> PromptIntent {
        let lower = prompt.lowercased()

        // Code-related intents
        if containsCodeKeywords(lower) {
            if lower.contains("fix") || lower.contains("bug") || lower.contains("error") {
                return .debugging
            }
            if lower.contains("create") || lower.contains("write") || lower.contains("implement") {
                return .codeGeneration
            }
            if lower.contains("refactor") || lower.contains("improve") || lower.contains("optimize") {
                return .codeImprovement
            }
            if lower.contains("explain") || lower.contains("how") || lower.contains("what") {
                return .codeExplanation
            }
            return .codingGeneral
        }

        // Analysis intents
        if lower.contains("analyze") || lower.contains("review") || lower.contains("evaluate") {
            return .analysis
        }

        // Creative intents
        if lower.contains("write") || lower.contains("draft") || lower.contains("compose") {
            return .creative
        }

        // Research intents
        if lower.contains("research") || lower.contains("find") || lower.contains("search") {
            return .research
        }

        // Question intents
        if lower.hasPrefix("what") || lower.hasPrefix("how") || lower.hasPrefix("why") ||
           lower.hasPrefix("when") || lower.hasPrefix("where") || lower.contains("?") {
            return .question
        }

        // Task/action intents
        if lower.contains("help") || lower.contains("assist") {
            return .taskAssistance
        }

        return .general
    }

    private func containsCodeKeywords(_ text: String) -> Bool {
        let keywords = ["code", "function", "class", "method", "api", "bug", "error",
                       "swift", "python", "javascript", "typescript", "compile", "run"]
        return keywords.contains { text.contains($0) }
    }

    private func detectGeneralIntents(_ prompt: String) -> [IntentPrediction] {
        var predictions: [IntentPrediction] = []
        let lower = prompt.lowercased()

        // Pattern-based detection with learned weights
        let patterns: [(String, PromptIntent, Double)] = [
            ("help me", .taskAssistance, 0.8),
            ("can you", .taskAssistance, 0.7),
            ("please", .taskAssistance, 0.6),
            ("create", .codeGeneration, 0.8),
            ("write", .creative, 0.7),
            ("fix", .debugging, 0.9),
            ("explain", .codeExplanation, 0.85),
            ("analyze", .analysis, 0.85),
            ("summarize", .analysis, 0.8)
        ]

        for (pattern, intent, baseConfidence) in patterns {
            if lower.contains(pattern) {
                let adjustedConfidence = adjustConfidenceFromHistory(baseConfidence, for: intent)
                predictions.append(IntentPrediction(
                    intent: intent,
                    confidence: adjustedConfidence,
                    suggestedCompletion: nil,
                    expectedResponse: nil
                ))
            }
        }

        return predictions
    }

    // MARK: - Anticipation & Suggestions

    private func anticipateNeeds(_ prompt: String) -> [AnticipatedNeed] {
        var needs: [AnticipatedNeed] = []
        let intent = detectIntent(prompt)

        switch intent {
        case .codeGeneration:
            needs.append(AnticipatedNeed(
                type: .testing,
                description: "You might want unit tests for this code",
                likelihood: 0.8
            ))
            needs.append(AnticipatedNeed(
                type: .documentation,
                description: "Documentation comments may be helpful",
                likelihood: 0.6
            ))

        case .debugging:
            needs.append(AnticipatedNeed(
                type: .explanation,
                description: "Understanding why the bug occurred",
                likelihood: 0.7
            ))
            needs.append(AnticipatedNeed(
                type: .prevention,
                description: "How to prevent similar issues",
                likelihood: 0.5
            ))

        case .analysis:
            needs.append(AnticipatedNeed(
                type: .visualization,
                description: "A visual representation of the analysis",
                likelihood: 0.6
            ))
            needs.append(AnticipatedNeed(
                type: .summary,
                description: "A concise summary of findings",
                likelihood: 0.8
            ))

        default:
            break
        }

        // Add personalized needs based on history
        let historicalNeeds = getHistoricalNeeds(for: intent)
        needs.append(contentsOf: historicalNeeds)

        return needs
    }

    private func suggestEnhancements(_ prompt: String) -> [PromptEnhancement] {
        var enhancements: [PromptEnhancement] = []

        // Check prompt length - too short might need context
        if prompt.count < 20 {
            enhancements.append(PromptEnhancement(
                type: .addContext,
                suggestion: "Adding more context could improve the response",
                example: nil
            ))
        }

        // Check for vague language
        let vagueTerms = ["thing", "stuff", "it", "that", "something"]
        let lower = prompt.lowercased()
        for term in vagueTerms where lower.contains(term) {
            enhancements.append(PromptEnhancement(
                type: .beSpecific,
                suggestion: "Being more specific about '\(term)' could help",
                example: nil
            ))
        }

        // Suggest format specifications based on user preference
        if let preferredFormat = userPromptProfile.preferredResponseFormat {
            enhancements.append(PromptEnhancement(
                type: .formatPreference,
                suggestion: "You typically prefer \(preferredFormat.rawValue) responses",
                example: "Add: \"in \(preferredFormat.rawValue) format\""
            ))
        }

        return enhancements
    }

    // MARK: - Mood Detection

    private func detectMood(_ prompt: String) -> MoodIndicators {
        let lower = prompt.lowercased()

        // Urgency detection
        let urgencyKeywords = ["asap", "urgent", "quickly", "now", "immediately", "hurry", "deadline"]
        let urgencyLevel = urgencyKeywords.reduce(0.0) { result, keyword in
            lower.contains(keyword) ? result + 0.2 : result
        }

        // Frustration detection
        let frustrationKeywords = ["still", "again", "why won't", "not working", "broken", "hate", "annoying"]
        let frustrationLevel = frustrationKeywords.reduce(0.0) { result, keyword in
            lower.contains(keyword) ? result + 0.15 : result
        }

        // Exploration detection
        let explorationKeywords = ["curious", "wondering", "what if", "explore", "try", "experiment"]
        let explorationLevel = explorationKeywords.reduce(0.0) { result, keyword in
            lower.contains(keyword) ? result + 0.2 : result
        }

        // Formality detection
        let formalKeywords = ["please", "kindly", "would you", "could you", "i would appreciate"]
        let formalityLevel = formalKeywords.reduce(0.0) { result, keyword in
            lower.contains(keyword) ? result + 0.15 : result
        }

        return MoodIndicators(
            urgency: min(1.0, urgencyLevel),
            frustration: min(1.0, frustrationLevel),
            exploration: min(1.0, explorationLevel),
            formality: min(1.0, formalityLevel)
        )
    }

    // MARK: - Workflow Management

    private func getWorkflowContext() -> WorkflowContext? {
        guard let currentWorkflow = identifyCurrentWorkflow() else { return nil }

        return WorkflowContext(
            workflowType: currentWorkflow.type,
            currentStep: currentWorkflow.currentStepIndex,
            totalSteps: currentWorkflow.steps.count,
            completedSteps: currentWorkflow.completedSteps,
            estimatedRemaining: currentWorkflow.estimateRemainingSteps()
        )
    }

    private func identifyCurrentWorkflow() -> WorkflowPattern? {
        guard !workflowPatterns.isEmpty else { return nil }

        // Check recent interactions to identify active workflow
        let recentIntents = userPromptProfile.recentInteractions.suffix(5).map { $0.intent }

        for pattern in workflowPatterns {
            let matchScore = pattern.matchScore(for: recentIntents)
            if matchScore > configuration.confidenceThreshold {
                return pattern
            }
        }

        return nil
    }

    // MARK: - Learning

    private func learnFromPrompt(_ prompt: String, analysis: PromptAnalysis) async {
        guard configuration.enableAdaptiveLearning else { return }

        // Update prompt patterns
        let pattern = PromptPattern(
            prefix: String(prompt.prefix(20)),
            intent: analysis.detectedIntent,
            frequency: 1.0,
            typicalCompletion: nil,
            expectedResponseType: nil
        )

        if let existingIndex = userPromptProfile.commonPatterns.firstIndex(where: {
            $0.prefix.lowercased() == pattern.prefix.lowercased()
        }) {
            // Update existing pattern
            userPromptProfile.commonPatterns[existingIndex].frequency += configuration.learningRate
        } else {
            // Add new pattern
            userPromptProfile.commonPatterns.append(pattern)
        }

        // Record interaction
        userPromptProfile.recentInteractions.append(PromptInteraction(
            timestamp: Date(),
            prompt: prompt,
            intent: analysis.detectedIntent,
            mood: analysis.moodIndicators
        ))

        // Trim old interactions
        if userPromptProfile.recentInteractions.count > 100 {
            userPromptProfile.recentInteractions = Array(userPromptProfile.recentInteractions.suffix(100))
        }

        // Update time patterns
        let hour = Calendar.current.component(.hour, from: Date())
        if let existingTimePattern = userPromptProfile.timePatterns.firstIndex(where: { $0.hour == hour }) {
            userPromptProfile.timePatterns[existingTimePattern].frequency += configuration.learningRate
        } else {
            userPromptProfile.timePatterns.append(TimePattern(
                hour: hour,
                activityName: analysis.detectedIntent.displayName,
                typicalPrompt: prompt,
                frequency: 1.0
            ))
        }

        saveProfile()
    }

    /// Learn from response feedback (was response helpful?)
    func recordFeedback(wasHelpful: Bool, forInteraction interaction: PromptInteraction) {
        // Adjust pattern weights based on feedback
        let adjustment = wasHelpful ? configuration.learningRate : -configuration.learningRate

        if let patternIndex = userPromptProfile.commonPatterns.firstIndex(where: {
            $0.intent == interaction.intent
        }) {
            userPromptProfile.commonPatterns[patternIndex].frequency += adjustment
        }

        saveProfile()
    }

    // MARK: - Helper Methods

    private func adjustConfidenceFromHistory(_ base: Double, for intent: PromptIntent) -> Double {
        let matchingPatterns = userPromptProfile.commonPatterns.filter { $0.intent == intent }
        let historicalWeight = matchingPatterns.reduce(0.0) { $0 + $1.frequency }
        return min(1.0, base + (historicalWeight * 0.1))
    }

    private func getHistoricalNeeds(for intent: PromptIntent) -> [AnticipatedNeed] {
        // Return needs based on what user typically asked for after this intent
        // This would be populated over time through learning
        []
    }

    private func suggestFollowUps(for interaction: PromptInteraction) -> [AdaptiveSuggestion] {
        var suggestions: [AdaptiveSuggestion] = []

        switch interaction.intent {
        case .codeGeneration:
            suggestions.append(AdaptiveSuggestion(
                type: .followUp,
                title: "Add tests?",
                description: "Generate unit tests for the code",
                suggestedPrompt: "Write unit tests for the code you just created",
                confidence: 0.7
            ))

        case .debugging:
            suggestions.append(AdaptiveSuggestion(
                type: .followUp,
                title: "Prevent recurrence?",
                description: "Learn how to prevent similar bugs",
                suggestedPrompt: "How can I prevent this type of bug in the future?",
                confidence: 0.6
            ))

        default:
            break
        }

        return suggestions
    }

    private func calculateConfidence(_ prompt: String) -> Double {
        // Calculate overall confidence in analysis based on:
        // - Pattern match strength
        // - Prompt clarity
        // - Historical accuracy

        var confidence = 0.5 // Base confidence

        // Boost for matching known patterns
        for pattern in userPromptProfile.commonPatterns {
            if prompt.lowercased().contains(pattern.prefix.lowercased()) {
                confidence += 0.1 * pattern.frequency
            }
        }

        // Boost for clear, detailed prompts
        if prompt.count > 50 { confidence += 0.1 }
        if prompt.count > 100 { confidence += 0.1 }

        return min(1.0, confidence)
    }

    // MARK: - Persistence

    private func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: "AdaptivePrompt.profile"),
           let profile = try? JSONDecoder().decode(UserPromptProfile.self, from: data) {
            userPromptProfile = profile
        }
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(userPromptProfile) {
            UserDefaults.standard.set(data, forKey: "AdaptivePrompt.profile")
        }
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "AdaptivePrompt.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data) {
            configuration = config
        }
    }

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "AdaptivePrompt.config")
        }
    }

    func clearLearningData() {
        userPromptProfile = UserPromptProfile()
        workflowPatterns.removeAll()
        saveProfile()
    }
}

// MARK: - Supporting Types

struct PromptAnalysis: Sendable {
    let originalPrompt: String
    let detectedIntent: PromptIntent
    let anticipatedNeeds: [AnticipatedNeed]
    let suggestedEnhancements: [PromptEnhancement]
    let moodIndicators: MoodIndicators
    let workflowContext: WorkflowContext?
    let confidenceScore: Double
}

enum PromptIntent: String, Codable, Sendable, CaseIterable {
    case codeGeneration
    case codeImprovement
    case codeExplanation
    case debugging
    case codingGeneral
    case analysis
    case creative
    case research
    case question
    case taskAssistance
    case general

    var displayName: String {
        switch self {
        case .codeGeneration: "Code Generation"
        case .codeImprovement: "Code Improvement"
        case .codeExplanation: "Code Explanation"
        case .debugging: "Debugging"
        case .codingGeneral: "General Coding"
        case .analysis: "Analysis"
        case .creative: "Creative Writing"
        case .research: "Research"
        case .question: "Question"
        case .taskAssistance: "Task Assistance"
        case .general: "General"
        }
    }
}

struct IntentPrediction: Sendable {
    let intent: PromptIntent
    let confidence: Double
    let suggestedCompletion: String?
    let expectedResponse: ResponseType?
}

struct PromptCompletion: Sendable, Identifiable {
    let id = UUID()
    let completion: String
    let fullPrompt: String
    let intent: PromptIntent
    let confidence: Double
}

struct AdaptiveSuggestion: Sendable, Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let suggestedPrompt: String
    let confidence: Double

    enum SuggestionType: String, Codable, Sendable {
        case workflowNext
        case timeBased
        case followUp
        case contextual
    }
}

struct AnticipatedNeed: Sendable {
    let type: NeedType
    let description: String
    let likelihood: Double

    enum NeedType: String, Codable, Sendable {
        case testing
        case documentation
        case explanation
        case prevention
        case visualization
        case summary
    }
}

struct PromptEnhancement: Sendable {
    let type: EnhancementType
    let suggestion: String
    let example: String?

    enum EnhancementType: String, Codable, Sendable {
        case addContext
        case beSpecific
        case formatPreference
        case clarifyScope
    }
}

struct MoodIndicators: Codable, Sendable {
    let urgency: Double      // 0-1
    let frustration: Double  // 0-1
    let exploration: Double  // 0-1
    let formality: Double    // 0-1
}

struct WorkflowContext: Sendable {
    let workflowType: String
    let currentStep: Int
    let totalSteps: Int
    let completedSteps: [String]
    let estimatedRemaining: Int
}

enum ResponseType: String, Codable, Sendable {
    case code
    case explanation
    case list
    case stepByStep
    case summary
    case conversational
}

// MARK: - Profile Types

struct UserPromptProfile: Codable, Sendable {
    var commonPatterns: [PromptPattern] = []
    var timePatterns: [TimePattern] = []
    var recentInteractions: [PromptInteraction] = []
    var preferredResponseFormat: ResponseType?
    var averagePromptLength: Double = 0
    var domainExpertise: [String: Double] = [:] // domain -> expertise level
}

struct PromptPattern: Codable, Sendable {
    let prefix: String
    let intent: PromptIntent
    var frequency: Double
    var typicalCompletion: String?
    var expectedResponseType: ResponseType?
}

struct TimePattern: Codable, Sendable {
    let hour: Int
    let activityName: String
    let typicalPrompt: String
    var frequency: Double
}

struct PromptInteraction: Codable, Sendable {
    let timestamp: Date
    let prompt: String
    let intent: PromptIntent
    let mood: MoodIndicators
}

struct WorkflowPattern: Sendable {
    let type: String
    let steps: [WorkflowStep]
    var currentStepIndex: Int
    var completedSteps: [String]
    var confidence: Double

    func matchScore(for intents: [PromptIntent]) -> Double {
        // Calculate how well the given intents match this workflow
        guard !steps.isEmpty, !intents.isEmpty else { return 0 }

        var matches = 0
        for (index, intent) in intents.enumerated() {
            if index < steps.count && steps[index].expectedIntent == intent {
                matches += 1
            }
        }

        return Double(matches) / Double(min(steps.count, intents.count))
    }

    func predictNextStep() -> WorkflowStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    func estimateRemainingSteps() -> Int {
        max(0, steps.count - currentStepIndex)
    }
}

struct WorkflowStep: Sendable {
    let description: String
    let expectedIntent: PromptIntent
    let suggestedPrompt: String
}
