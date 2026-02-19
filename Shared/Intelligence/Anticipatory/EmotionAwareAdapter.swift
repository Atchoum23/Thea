// EmotionAwareAdapter.swift
// Thea V2 - Emotion-Aware Response Adaptation
//
// Detects user emotional state and adapts responses accordingly
// Creates more empathetic and contextually appropriate interactions

import Foundation
import OSLog

// MARK: - Emotion-Aware Adapter

/// Adapts AI responses based on detected user emotional state
@MainActor
@Observable
public final class EmotionAwareAdapter {

    // periphery:ignore - Reserved: logger property reserved for future feature activation
    private let logger = Logger(subsystem: "app.thea.anticipatory", category: "EmotionAdapter")

    // MARK: - State

    /// Current detected emotional state
    public private(set) var currentEmotionalState: EmotionalState = .neutral

    /// Recent emotional signals
    public private(set) var emotionalHistory: [EmotionalSignal] = []

    /// Adaptation recommendations
    public private(set) var currentAdaptations: [ResponseAdaptation] = []

    // MARK: - Configuration

    public var configuration = EmotionConfiguration()

    // MARK: - Callbacks

    /// Called when emotional state changes significantly
    public var onEmotionalStateChange: ((EmotionalState, EmotionalState) -> Void)?

    // MARK: - Initialization

    public init() {}

    // MARK: - Public API

    /// Analyze text for emotional signals
    public func analyzeText(_ text: String) -> EmotionalAnalysis {
        let signals = extractEmotionalSignals(from: text)

        // Update history
        for signal in signals {
            emotionalHistory.append(signal)
        }

        // Keep history manageable
        if emotionalHistory.count > 100 {
            emotionalHistory.removeFirst(emotionalHistory.count - 100)
        }

        // Determine overall state
        let previousState = currentEmotionalState
        currentEmotionalState = computeEmotionalState(from: emotionalHistory)

        // Notify if state changed significantly
        if previousState != currentEmotionalState {
            onEmotionalStateChange?(previousState, currentEmotionalState)
        }

        // Generate adaptations
        currentAdaptations = generateAdaptations(for: currentEmotionalState)

        return EmotionalAnalysis(
            detectedState: currentEmotionalState,
            signals: signals,
            confidence: calculateConfidence(),
            recommendedAdaptations: currentAdaptations
        )
    }

    /// Get response modifications based on current emotional state
    public func getResponseModifications() -> ResponseModifications {
        switch currentEmotionalState {
        case .frustrated:
            return ResponseModifications(
                toneAdjustment: .supportive,
                verbosityAdjustment: .concise,
                shouldAcknowledgeEmotion: true,
                suggestedOpening: "I understand this might be frustrating. Let me help you with that.",
                additionalContext: "Keep responses focused and solution-oriented"
            )

        case .confused:
            return ResponseModifications(
                toneAdjustment: .patient,
                verbosityAdjustment: .detailed,
                shouldAcknowledgeEmotion: true,
                suggestedOpening: "Let me break this down step by step.",
                additionalContext: "Use simpler language and more examples"
            )

        case .rushed:
            return ResponseModifications(
                toneAdjustment: .efficient,
                verbosityAdjustment: .minimal,
                shouldAcknowledgeEmotion: false,
                suggestedOpening: nil,
                additionalContext: "Prioritize actionable information"
            )

        case .curious:
            return ResponseModifications(
                toneAdjustment: .engaging,
                verbosityAdjustment: .detailed,
                shouldAcknowledgeEmotion: false,
                suggestedOpening: nil,
                additionalContext: "Include interesting details and connections"
            )

        case .stressed:
            return ResponseModifications(
                toneAdjustment: .calming,
                verbosityAdjustment: .balanced,
                shouldAcknowledgeEmotion: true,
                suggestedOpening: "Let's take this one step at a time.",
                additionalContext: "Avoid adding complexity, prioritize clarity"
            )

        case .satisfied:
            return ResponseModifications(
                toneAdjustment: .encouraging,
                verbosityAdjustment: .balanced,
                shouldAcknowledgeEmotion: false,
                suggestedOpening: nil,
                additionalContext: "Maintain positive momentum"
            )

        case .neutral:
            return ResponseModifications(
                toneAdjustment: .neutral,
                verbosityAdjustment: .balanced,
                shouldAcknowledgeEmotion: false,
                suggestedOpening: nil,
                additionalContext: nil
            )
        }
    }

    /// Modify a response based on emotional context
    public func adaptResponse(_ response: String) -> String {
        let modifications = getResponseModifications()

        var adaptedResponse = response

        // Add acknowledgment if needed
        if modifications.shouldAcknowledgeEmotion, let opening = modifications.suggestedOpening {
            adaptedResponse = opening + "\n\n" + adaptedResponse
        }

        return adaptedResponse
    }

    // MARK: - Private Methods

    private func extractEmotionalSignals(from text: String) -> [EmotionalSignal] {
        var signals: [EmotionalSignal] = []
        let lowercased = text.lowercased()

        // Frustration indicators
        let frustrationWords = ["doesn't work", "not working", "broken", "error", "fail", "wrong", "stuck", "help", "can't", "won't", "ugh", "again"]
        for word in frustrationWords where lowercased.contains(word) {
            signals.append(EmotionalSignal(
                type: .frustration,
                intensity: 0.7,
                trigger: word,
                timestamp: Date()
            ))
        }

        // Confusion indicators
        let confusionWords = ["confused", "don't understand", "what does", "how do", "why is", "makes no sense", "lost", "unclear"]
        for word in confusionWords where lowercased.contains(word) {
            signals.append(EmotionalSignal(
                type: .confusion,
                intensity: 0.6,
                trigger: word,
                timestamp: Date()
            ))
        }

        // Urgency/Rush indicators
        let urgencyWords = ["asap", "urgent", "quickly", "hurry", "deadline", "immediately", "now", "fast"]
        for word in urgencyWords where lowercased.contains(word) {
            signals.append(EmotionalSignal(
                type: .urgency,
                intensity: 0.8,
                trigger: word,
                timestamp: Date()
            ))
        }

        // Curiosity indicators
        let curiosityWords = ["interesting", "curious", "wonder", "tell me more", "how does", "why does", "explain"]
        for word in curiosityWords where lowercased.contains(word) {
            signals.append(EmotionalSignal(
                type: .curiosity,
                intensity: 0.5,
                trigger: word,
                timestamp: Date()
            ))
        }

        // Stress indicators
        let stressWords = ["stressed", "overwhelmed", "too much", "can't handle", "anxious", "worried"]
        for word in stressWords where lowercased.contains(word) {
            signals.append(EmotionalSignal(
                type: .stress,
                intensity: 0.8,
                trigger: word,
                timestamp: Date()
            ))
        }

        // Positive indicators
        let positiveWords = ["thanks", "great", "perfect", "awesome", "excellent", "love", "amazing", "helpful"]
        for word in positiveWords where lowercased.contains(word) {
            signals.append(EmotionalSignal(
                type: .satisfaction,
                intensity: 0.6,
                trigger: word,
                timestamp: Date()
            ))
        }

        // Typing pattern analysis
        if text.contains("!!!") || text.contains("???") {
            signals.append(EmotionalSignal(
                type: .intensity,
                intensity: 0.7,
                trigger: "multiple punctuation",
                timestamp: Date()
            ))
        }

        if text == text.uppercased() && text.count > 10 {
            signals.append(EmotionalSignal(
                type: .intensity,
                intensity: 0.8,
                trigger: "all caps",
                timestamp: Date()
            ))
        }

        return signals
    }

    private func computeEmotionalState(from signals: [EmotionalSignal]) -> EmotionalState {
        let recentSignals = signals.filter {
            Date().timeIntervalSince($0.timestamp) < 300 // Last 5 minutes
        }

        guard !recentSignals.isEmpty else { return .neutral }

        // Count signal types
        var typeCounts: [EmotionalSignalType: Double] = [:]
        for signal in recentSignals {
            typeCounts[signal.type, default: 0] += signal.intensity
        }

        // Find dominant emotion
        guard let dominant = typeCounts.max(by: { $0.value < $1.value }) else {
            return .neutral
        }

        switch dominant.key {
        case .frustration:
            return .frustrated
        case .confusion:
            return .confused
        case .urgency:
            return .rushed
        case .curiosity:
            return .curious
        case .stress:
            return .stressed
        case .satisfaction:
            return .satisfied
        case .intensity:
            // Intensity amplifies other emotions
            let secondHighest = typeCounts
                .filter { $0.key != .intensity }
                .max { $0.value < $1.value }
            if let second = secondHighest {
                return computeStateFromType(second.key)
            }
            return .neutral
        }
    }

    private func computeStateFromType(_ type: EmotionalSignalType) -> EmotionalState {
        switch type {
        case .frustration: return .frustrated
        case .confusion: return .confused
        case .urgency: return .rushed
        case .curiosity: return .curious
        case .stress: return .stressed
        case .satisfaction: return .satisfied
        case .intensity: return .neutral
        }
    }

    private func calculateConfidence() -> Double {
        let recentSignals = emotionalHistory.filter {
            Date().timeIntervalSince($0.timestamp) < 300
        }

        guard !recentSignals.isEmpty else { return 0.0 }

        // More consistent signals = higher confidence
        let avgIntensity = recentSignals.map(\.intensity).reduce(0, +) / Double(recentSignals.count)
        let signalCount = min(1.0, Double(recentSignals.count) / 5.0)

        return avgIntensity * 0.6 + signalCount * 0.4
    }

    private func generateAdaptations(for state: EmotionalState) -> [ResponseAdaptation] {
        var adaptations: [ResponseAdaptation] = []

        switch state {
        case .frustrated:
            adaptations.append(ResponseAdaptation(
                type: .tone,
                suggestion: "Use empathetic, solution-focused language",
                priority: .high
            ))
            adaptations.append(ResponseAdaptation(
                type: .structure,
                suggestion: "Lead with the solution, explain after",
                priority: .medium
            ))

        case .confused:
            adaptations.append(ResponseAdaptation(
                type: .structure,
                suggestion: "Use numbered steps and clear headers",
                priority: .high
            ))
            adaptations.append(ResponseAdaptation(
                type: .content,
                suggestion: "Add examples and analogies",
                priority: .medium
            ))

        case .rushed:
            adaptations.append(ResponseAdaptation(
                type: .length,
                suggestion: "Be extremely concise - bullet points only",
                priority: .high
            ))
            adaptations.append(ResponseAdaptation(
                type: .structure,
                suggestion: "Put most important info first",
                priority: .high
            ))

        case .stressed:
            adaptations.append(ResponseAdaptation(
                type: .tone,
                suggestion: "Use calming, reassuring language",
                priority: .high
            ))
            adaptations.append(ResponseAdaptation(
                type: .content,
                suggestion: "Break tasks into small, manageable steps",
                priority: .medium
            ))

        case .curious:
            adaptations.append(ResponseAdaptation(
                type: .content,
                suggestion: "Include interesting background and connections",
                priority: .medium
            ))

        case .satisfied, .neutral:
            break
        }

        return adaptations
    }
}

// MARK: - Supporting Types

public struct EmotionConfiguration: Sendable {
    public var enabled: Bool = true
    public var sensitivityLevel: Double = 0.5
    public var adaptResponsesAutomatically: Bool = true

    public init() {}
}

public enum EmotionalState: String, Sendable {
    case neutral
    case frustrated
    case confused
    case rushed
    case curious
    case stressed
    case satisfied
}

public struct EmotionalSignal: Sendable {
    public let type: EmotionalSignalType
    public let intensity: Double
    public let trigger: String
    public let timestamp: Date
}

public enum EmotionalSignalType: String, Sendable {
    case frustration
    case confusion
    case urgency
    case curiosity
    case stress
    case satisfaction
    case intensity
}

public struct EmotionalAnalysis: Sendable {
    public let detectedState: EmotionalState
    public let signals: [EmotionalSignal]
    public let confidence: Double
    public let recommendedAdaptations: [ResponseAdaptation]
}

public struct ResponseModifications: Sendable {
    public let toneAdjustment: ToneType
    public let verbosityAdjustment: VerbosityLevel
    public let shouldAcknowledgeEmotion: Bool
    public let suggestedOpening: String?
    public let additionalContext: String?

    public enum ToneType: String, Sendable {
        case neutral
        case supportive
        case patient
        case efficient
        case engaging
        case calming
        case encouraging
    }

    public enum VerbosityLevel: String, Sendable {
        case minimal
        case concise
        case balanced
        case detailed
    }
}

public struct ResponseAdaptation: Sendable {
    public let type: AdaptationType
    public let suggestion: String
    public let priority: AdaptationPriority

    public enum AdaptationType: String, Sendable {
        case tone
        case structure
        case content
        case length
    }

    public enum AdaptationPriority: Int, Sendable {
        case low = 0
        case medium = 1
        case high = 2
    }
}
