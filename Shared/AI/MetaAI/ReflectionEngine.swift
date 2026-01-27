import Foundation
import Observation

/// Self-improvement system that analyzes and learns from AI outputs
@MainActor
@Observable
final class ReflectionEngine {
    static let shared = ReflectionEngine()

    private(set) var reflectionHistory: [Reflection] = []
    private(set) var improvements: [Improvement] = []
    private(set) var learnings: [Learning] = []

    // Configuration accessor
    private var config: MetaAIConfiguration {
        AppConfiguration.shared.metaAIConfig
    }

    private init() {}

    // MARK: - Reflection Process

    /// Analyze an AI output and identify improvements
    func reflect(
        on output: String,
        task: String,
        context _: [String: Any] = [:]
    ) async throws -> Reflection {
        // Step 1: Self-critique
        let critique = try await selfCritique(output: output, task: task)

        // Step 2: Identify weaknesses
        let weaknesses = try await identifyWeaknesses(output: output, critique: critique)

        // Step 3: Generate improvements
        let suggestions = try await generateImprovements(
            output: output,
            weaknesses: weaknesses
        )

        // Step 4: Apply improvements
        let improved = try await applyImprovements(
            original: output,
            suggestions: suggestions
        )

        // Step 5: Extract learnings
        let learning = try await extractLearnings(
            original: output,
            improved: improved,
            weaknesses: weaknesses
        )

        let reflection = Reflection(
            id: UUID(),
            originalOutput: output,
            task: task,
            critique: critique,
            weaknesses: weaknesses,
            improvements: suggestions,
            improvedOutput: improved,
            learning: learning,
            timestamp: Date()
        )

        reflectionHistory.append(reflection)
        learnings.append(learning)

        return reflection
    }

    // MARK: - Apply Historical Learnings

    func applyHistoricalLearnings(to prompt: String) -> String {
        guard !learnings.isEmpty else { return prompt }

        let recentLearnings = learnings.suffix(5)
        let learningsSummary = recentLearnings.map(\.insight).joined(separator: "\n")

        return """
        \(prompt)

        [Previous learnings to apply:]
        \(learningsSummary)
        """
    }

    // MARK: - Private Helper Methods

    private func selfCritique(output: String, task: String) async throws -> Critique {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw ReflectionError.providerNotAvailable
        }

        let prompt = """
        You are a highly critical AI evaluator. Analyze this output objectively.

        Task: \(task)
        Output: \(output)

        Evaluate:
        1. Accuracy (0-10)
        2. Completeness (0-10)
        3. Clarity (0-10)
        4. Efficiency (0-10)
        5. Creativity (0-10)

        Identify specific flaws, gaps, and areas for improvement.
        Be brutally honest. Don't hold back criticism.

        Format as JSON with scores and detailed feedback.
        """

        let critiqueText = try await streamProviderResponse(provider: provider, prompt: prompt, model: config.reflectionModel)

        return Critique(
            accuracy: 7.0,
            completeness: 7.0,
            clarity: 7.0,
            efficiency: 7.0,
            creativity: 7.0,
            overallScore: 7.0,
            feedback: critiqueText
        )
    }

    private func identifyWeaknesses(output: String, critique: Critique) async throws -> [Weakness] {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw ReflectionError.providerNotAvailable
        }

        let prompt = """
        Based on this critique:
        \(critique.feedback)

        For this output:
        \(output)

        List the specific weaknesses. For each, specify:
        - What is wrong
        - Why it matters
        - Severity (low/medium/high)

        Format as JSON array.
        """

        let weaknessesText = try await streamProviderResponse(provider: provider, prompt: prompt, model: config.reflectionModel)

        return [
            Weakness(
                description: "Identified from critique",
                impact: weaknessesText,
                severity: .medium
            )
        ]
    }

    private func generateImprovements(output: String, weaknesses: [Weakness]) async throws -> [Improvement] {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw ReflectionError.providerNotAvailable
        }

        let weaknessDescriptions = weaknesses.map(\.description).joined(separator: "\n")

        let prompt = """
        Original output:
        \(output)

        Identified weaknesses:
        \(weaknessDescriptions)

        For each weakness, provide:
        1. A specific improvement suggestion
        2. Expected impact
        3. Implementation steps

        Format as JSON array.
        """

        let improvementsText = try await streamProviderResponse(provider: provider, prompt: prompt, model: config.reflectionModel)

        return [
            Improvement(
                suggestion: improvementsText,
                expectedImpact: "Better output quality",
                priority: .high
            )
        ]
    }

    private func applyImprovements(original: String, suggestions: [Improvement]) async throws -> String {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw ReflectionError.providerNotAvailable
        }

        let suggestionList = suggestions.map(\.suggestion).joined(separator: "\n")

        let prompt = """
        Original output:
        \(original)

        Apply these improvements:
        \(suggestionList)

        Provide the improved version incorporating all suggestions.
        """

        return try await streamProviderResponse(provider: provider, prompt: prompt, model: config.reflectionModel)
    }

    private func extractLearnings(original: String, improved: String, weaknesses _: [Weakness]) async throws -> Learning {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw ReflectionError.providerNotAvailable
        }

        let prompt = """
        Original: \(original)
        Improved: \(improved)

        What general lesson can we learn from this improvement?
        What should we remember for future tasks?

        Provide a concise, actionable insight.
        """

        let insight = try await streamProviderResponse(provider: provider, prompt: prompt, model: "gpt-4o-mini")

        return Learning(
            insight: insight,
            context: "Reflection on improvements",
            applicability: ["general"],
            timestamp: Date()
        )
    }

    // Helper to stream provider response into a single string
    private func streamProviderResponse(provider: AIProvider, prompt: String, model: String) async throws -> String {
        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: model
        )

        var result = ""
        let stream = try await provider.chat(messages: [message], model: model, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                result += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return result
    }
}

// MARK: - Models

struct Reflection: Identifiable, Codable, Sendable {
    let id: UUID
    let originalOutput: String
    let task: String
    let critique: Critique
    let weaknesses: [Weakness]
    let improvements: [Improvement]
    let improvedOutput: String
    let learning: Learning
    let timestamp: Date
}

struct Critique: Codable, Sendable {
    let accuracy: Float
    let completeness: Float
    let clarity: Float
    let efficiency: Float
    let creativity: Float
    let overallScore: Float
    let feedback: String
}

struct Weakness: Codable, Sendable {
    let description: String
    let impact: String
    let severity: WeaknessSeverity

    enum WeaknessSeverity: String, Codable, Sendable {
        case low, medium, high
    }
}

struct Improvement: Codable, Sendable {
    let suggestion: String
    let expectedImpact: String
    let priority: ImprovementPriority

    enum ImprovementPriority: String, Codable, Sendable {
        case low, medium, high
    }
}

struct Learning: Codable, Sendable {
    let insight: String
    let context: String
    let applicability: [String]
    let timestamp: Date
}

enum ReflectionError: LocalizedError {
    case providerNotAvailable

    var errorDescription: String? {
        switch self {
        case .providerNotAvailable:
            "AI provider not available for reflection"
        }
    }
}
