// UserModelBuilder+Core.swift
// Thea
//
// UserModelBuilder class implementation.

import Foundation
import Observation
import os.log

private let userModelLogger = Logger(subsystem: "ai.thea.app", category: "UserModelBuilder")

// MARK: - User Model Builder

@MainActor
@Observable
public final class UserModelBuilder {
    public static let shared = UserModelBuilder()

    // MARK: - State

    private(set) var userProfile: UserProfile
    private(set) var observations: [ObservationRecord] = []
    private(set) var isLearning = true
    private(set) var lastProfileUpdate: Date?

    // MARK: - Configuration

    private let observationWindowDays = 30
    private let minObservationsForConfidence = 5
    private let learningRate: Double = 0.1
    private let decayRate: Double = 0.95

    // MARK: - Initialization

    private init() {
        self.userProfile = UserProfile()
        userModelLogger.info("👤 UserModelBuilder initializing...")
        startPeriodicAnalysis()
    }

    // MARK: - Public API

    /// Observe a user query
    public func observeQuery(_ query: String, taskType: String?) async {
        let queryLength = Double(query.count)

        // Update average query length
        userProfile.communicationStyle.averageQueryLength =
            (userProfile.communicationStyle.averageQueryLength * 0.9) + (queryLength * 0.1)

        // Detect questioning style
        let style = detectQuestioningStyle(query)
        if style != userProfile.communicationStyle.questioningStyle {
            addObservation(type: .queryPattern, value: style.rawValue, confidence: 0.6)
        }

        // Detect code usage
        if query.contains("```") || query.contains("func ") || query.contains("class ") {
            userProfile.communicationStyle.usesCodeBlocks = true
        }

        // Update technical level based on query complexity
        // periphery:ignore - Reserved: wasAccepted parameter — kept for API compatibility
        let technicalLevel = assessQueryTechnicalLevel(query)
        updateTechnicalLevel(technicalLevel)

        // Track task type interest
        if let taskType = taskType {
            userProfile.preferences.topicInterests[taskType, default: 0] += 0.1
        }

        userProfile.lastUpdated = Date()
    }

    /// Observe user response to AI output
    public func observeResponseReaction(
        wasHelpful: Bool,
        wasAccepted: Bool,
        // periphery:ignore - Reserved: wasAccepted parameter kept for API compatibility
        followUpQuery: String?,
        // periphery:ignore - Reserved: responseLength parameter kept for API compatibility
        responseLength: Int
    ) async {
        // Adjust verbosity preference based on follow-up
        if let followUp = followUpQuery {
            if followUp.lowercased().contains("more detail") ||
               followUp.lowercased().contains("explain more") {
                userProfile.communicationStyle.verbosityPreference =
                    min(1.0, userProfile.communicationStyle.verbosityPreference + 0.1)
                addObservation(type: .responseReaction, value: "wants_more_detail", confidence: 0.7)
            } else if followUp.lowercased().contains("shorter") ||
                      followUp.lowercased().contains("too long") ||
                      followUp.lowercased().contains("tldr") {
                userProfile.communicationStyle.verbosityPreference =
                    max(0.0, userProfile.communicationStyle.verbosityPreference - 0.1)
                addObservation(type: .responseReaction, value: "wants_shorter", confidence: 0.7)
            }
        }

        // Track feedback style
        if wasHelpful || !wasHelpful {
            userProfile.communicationStyle.feedbackStyle = .explicit
            addObservation(type: .responseReaction, value: wasHelpful ? "positive" : "negative", confidence: 0.8)
        }

        userProfile.lastUpdated = Date()
    }

    /// Observe error occurrence and response
    public func observeError(errorMessage: String, userResponse: String?) async {
        addObservation(type: .errorResponse, value: errorMessage.prefix(100).description, confidence: 0.6)

        if let response = userResponse {
            // Check if user debugged themselves or needed help
            if response.lowercased().contains("fixed it") ||
               response.lowercased().contains("figured it out") {
                userProfile.technicalProfile.debuggingSkill =
                    min(1.0, userProfile.technicalProfile.debuggingSkill + 0.05)
            }
        }

        // Update stress level
        userProfile.stressIndicators.currentStressLevel =
            min(1.0, userProfile.stressIndicators.currentStressLevel + 0.1)

        userProfile.lastUpdated = Date()
    }

    /// Observe work timing patterns
    public func observeWorkSession(startTime: Date, duration: TimeInterval, tasksCompleted: Int) async {
        let hour = Calendar.current.component(.hour, from: startTime)

        // Track productivity hours
        if tasksCompleted > 0 && duration > 1800 {
            if !userProfile.workHabits.peakProductivityHours.contains(hour) {
                userProfile.workHabits.peakProductivityHours.append(hour)
                // Keep only top 5 hours
                if userProfile.workHabits.peakProductivityHours.count > 5 {
                    userProfile.workHabits.peakProductivityHours.removeFirst()
                }
            }
        }

        // Update average session duration
        userProfile.workHabits.averageSessionDuration =
            (userProfile.workHabits.averageSessionDuration * 0.9) + (duration * 0.1)

        addObservation(
            type: .workTiming,
            value: "session_\(hour)h_\(Int(duration/60))min",
            confidence: 0.7
        )

        userProfile.lastUpdated = Date()
    }

    /// Observe language/framework usage
    public func observeCodeUsage(language: String, framework: String?) async {
        // Track language preference
        userProfile.preferences.codeLanguagePreferences[language, default: 0] += 0.1

        // Add to preferred languages if high usage
        if (userProfile.preferences.codeLanguagePreferences[language] ?? 0) > 0.3 {
            if !userProfile.technicalProfile.preferredLanguages.contains(language) {
                userProfile.technicalProfile.preferredLanguages.append(language)
            }
        }

        // Track framework if provided
        if let framework = framework {
            if !userProfile.technicalProfile.preferredFrameworks.contains(framework) {
                userProfile.technicalProfile.preferredFrameworks.append(framework)
            }
        }

        addObservation(type: .codeStyle, value: language, confidence: 0.8)

        userProfile.lastUpdated = Date()
    }

    /// Observe frustration signal
    public func observeFrustration(indicator: String, severity: Double) async {
        userProfile.stressIndicators.currentStressLevel =
            min(1.0, userProfile.stressIndicators.currentStressLevel + (severity * 0.2))
        userProfile.stressIndicators.lastStressEvent = Date()

        if !userProfile.stressIndicators.frustrationPatterns.contains(indicator) {
            userProfile.stressIndicators.frustrationPatterns.append(indicator)
        }

        addObservation(type: .frustrationSignal, value: indicator, confidence: severity)

        // Notify hub
        await UnifiedIntelligenceHub.shared.processEvent(.userModelUpdated(aspect: .errorHandling))

        userProfile.lastUpdated = Date()
    }

    /// Observe explicit preference expression
    public func observePreference(category: String, value: String) async {
        addObservation(
            type: .preferenceExpressed,
            value: "\(category): \(value)",
            confidence: 0.9
        )

        // Apply known preferences
        switch category.lowercased() {
        case "verbosity":
            if value.lowercased().contains("brief") || value.lowercased().contains("short") {
                userProfile.communicationStyle.verbosityPreference = 0.2
            } else if value.lowercased().contains("detailed") || value.lowercased().contains("comprehensive") {
                userProfile.communicationStyle.verbosityPreference = 0.8
            }

        case "format":
            if value.lowercased().contains("code") {
                userProfile.preferences.preferredResponseFormat = .codeFirst
            } else if value.lowercased().contains("structured") {
                userProfile.preferences.preferredResponseFormat = .structured
            }

        case "proactivity":
            if value.lowercased().contains("proactive") {
                userProfile.preferences.proactivityLevel = 0.8
            } else if value.lowercased().contains("ask first") {
                userProfile.preferences.proactivityLevel = 0.3
            }

        default:
            break
        }

        userProfile.lastUpdated = Date()
    }

    /// Get personalization recommendations for current context
    public func getPersonalizationHints() -> PersonalizationHints {
        PersonalizationHints(
            suggestedVerbosity: userProfile.communicationStyle.verbosityPreference,
            suggestedTechnicalLevel: userProfile.communicationStyle.technicalDepth,
            useExamples: userProfile.communicationStyle.examplePreference > 0.5,
            useStructuredFormat: userProfile.communicationStyle.prefersStructuredResponses,
            currentStressLevel: userProfile.stressIndicators.currentStressLevel,
            isInPeakHours: isCurrentlyPeakHours(),
            preferredLanguages: userProfile.technicalProfile.preferredLanguages,
            proactivityLevel: userProfile.preferences.proactivityLevel
        )
    }

    /// Get the full user profile
    public func getProfile() -> UserProfile {
        userProfile
    }

    /// Reset learning (for privacy)
    public func resetProfile() {
        userProfile = UserProfile()
        observations.removeAll()
        userModelLogger.info("🔄 User profile reset")
    }

    // MARK: - Private Methods

    private func addObservation(type: ObservationRecord.ObservationType, value: String, confidence: Double) {
        let observation = ObservationRecord(
            type: type,
            value: value,
            confidence: confidence
        )
        observations.append(observation)

        // Trim old observations
        let cutoff = Date().addingTimeInterval(-Double(observationWindowDays) * 86400)
        observations = observations.filter { $0.timestamp > cutoff }
    }

    private func detectQuestioningStyle(_ query: String) -> CommunicationStyle.QuestioningStyle {
        let queryLower = query.lowercased()

        if queryLower.hasPrefix("how do i") || queryLower.hasPrefix("how to") {
            return .direct
        } else if queryLower.contains("trying to") || queryLower.contains("want to") {
            return .contextual
        } else if queryLower.contains("options") || queryLower.contains("alternatives") ||
                  queryLower.contains("what are") || queryLower.contains("which") {
            return .exploratory
        } else if queryLower.contains("error") || queryLower.contains("doesn't work") ||
                  queryLower.contains("not working") || queryLower.contains("bug") {
            return .debugging
        }

        return .direct
    }

    private func assessQueryTechnicalLevel(_ query: String) -> Double {
        var score = 0.5

        // Technical indicators
        let technicalTerms = ["async", "await", "protocol", "generic", "closure",
                              "dependency injection", "concurrency", "mutex",
                              "race condition", "memory leak", "optimization"]

        for term in technicalTerms where query.lowercased().contains(term) {
            score += 0.1
        }

        // Beginner indicators
        let beginnerTerms = ["what is", "explain", "basic", "simple", "beginner",
                             "don't understand", "confused"]

        for term in beginnerTerms where query.lowercased().contains(term) {
            score -= 0.1
        }

        return max(0.0, min(1.0, score))
    }

    private func updateTechnicalLevel(_ observedLevel: Double) {
        let current = userProfile.communicationStyle.technicalDepth
        userProfile.communicationStyle.technicalDepth =
            (current * (1 - learningRate)) + (observedLevel * learningRate)
    }

    private func isCurrentlyPeakHours() -> Bool {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return userProfile.workHabits.peakProductivityHours.contains(currentHour)
    }

    private func startPeriodicAnalysis() {
        Task.detached { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .seconds(300)) // Every 5 minutes
                } catch {
                    break
                }
                await self?.performPeriodicAnalysis()
            }
        }
    }

    private func performPeriodicAnalysis() async {
        // Decay stress level over time
        if userProfile.stressIndicators.currentStressLevel > 0.1 {
            userProfile.stressIndicators.currentStressLevel *= decayRate
        }

        // Analyze observation patterns
        analyzeObservationPatterns()

        lastProfileUpdate = Date()
    }

    private func analyzeObservationPatterns() {
        // Count observation types
        var typeCounts: [ObservationRecord.ObservationType: Int] = [:]
        for observation in observations {
            typeCounts[observation.type, default: 0] += 1
        }

        // Update learning style if enough learning behavior observations
        if (typeCounts[.learningBehavior] ?? 0) >= minObservationsForConfidence {
            // Could analyze learning patterns here
        }

        // Update technical level if enough code observations
        if (typeCounts[.codeStyle] ?? 0) >= minObservationsForConfidence {
            // Aggregate language expertise
            let languageObservations = observations.filter { $0.type == .codeStyle }
            var languageCounts: [String: Int] = [:]
            for observation in languageObservations {
                languageCounts[observation.value, default: 0] += 1
            }

            // Most used language likely indicates higher expertise
            if let topLanguage = languageCounts.max(by: { $0.value < $1.value })?.key {
                userProfile.technicalProfile.domainExpertise[topLanguage] = .advanced
            }
        }
    }
}

// MARK: - Personalization Hints

public struct PersonalizationHints: Sendable {
    public let suggestedVerbosity: Double
    public let suggestedTechnicalLevel: Double
    public let useExamples: Bool
    public let useStructuredFormat: Bool
    public let currentStressLevel: Double
    public let isInPeakHours: Bool
    public let preferredLanguages: [String]
    public let proactivityLevel: Double

    public func formatSystemPromptAdditions() -> String {
        var additions: [String] = []

        if suggestedVerbosity < 0.3 {
            additions.append("Keep responses concise and to the point.")
        } else if suggestedVerbosity > 0.7 {
            additions.append("Provide detailed explanations with context.")
        }

        if suggestedTechnicalLevel > 0.7 {
            additions.append("User has advanced technical knowledge - use appropriate terminology.")
        } else if suggestedTechnicalLevel < 0.3 {
            additions.append("Explain technical concepts in simple terms.")
        }

        if useExamples {
            additions.append("Include concrete examples when explaining concepts.")
        }

        if currentStressLevel > 0.6 {
            additions.append("User may be experiencing difficulty - be extra supportive and clear.")
        }

        if !preferredLanguages.isEmpty {
            additions.append("User prefers: \(preferredLanguages.joined(separator: ", "))")
        }

        return additions.joined(separator: " ")
    }
}
