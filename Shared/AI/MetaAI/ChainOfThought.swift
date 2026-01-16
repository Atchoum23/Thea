import Foundation

// MARK: - Chain of Thought Reasoning Module
// Implements structured step-by-step reasoning with explicit thought traces

/// Represents a single reasoning step in a chain-of-thought process
public struct ThoughtStep: Sendable, Codable, Identifiable {
    public let id: UUID
    public let stepNumber: Int
    public let thought: String
    public let reasoning: String
    public let confidence: Double
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        stepNumber: Int,
        thought: String,
        reasoning: String,
        confidence: Double = 0.8,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.thought = thought
        self.reasoning = reasoning
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

/// A complete chain of thought representing the full reasoning process
public struct ThoughtChain: Sendable, Codable, Identifiable {
    public let id: UUID
    public let problem: String
    public var steps: [ThoughtStep]
    public var conclusion: String?
    public var overallConfidence: Double
    public let startedAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        problem: String,
        steps: [ThoughtStep] = [],
        conclusion: String? = nil,
        overallConfidence: Double = 0.0,
        startedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.problem = problem
        self.steps = steps
        self.conclusion = conclusion
        self.overallConfidence = overallConfidence
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    public var isComplete: Bool {
        completedAt != nil && conclusion != nil
    }

    public var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }

    public mutating func addStep(_ step: ThoughtStep) {
        steps.append(step)
        updateConfidence()
    }

    public mutating func complete(with conclusion: String) {
        self.conclusion = conclusion
        self.completedAt = Date()
        updateConfidence()
    }

    private mutating func updateConfidence() {
        guard !steps.isEmpty else {
            overallConfidence = 0.0
            return
        }
        overallConfidence = steps.map(\.confidence).reduce(0, +) / Double(steps.count)
    }
}

/// Chain-of-Thought processor for structured reasoning
@MainActor
@Observable
public final class ChainOfThoughtProcessor {
    public static let shared = ChainOfThoughtProcessor()

    private(set) var activeChains: [ThoughtChain] = []
    private(set) var completedChains: [ThoughtChain] = []
    private(set) var isProcessing = false

    private init() {}

    // MARK: - Chain Processing

    /// Start a new chain-of-thought reasoning process
    public func startChain(for problem: String) -> ThoughtChain {
        let chain = ThoughtChain(problem: problem)
        activeChains.append(chain)
        return chain
    }

    /// Add a reasoning step to an active chain
    public func addStep(
        to chainId: UUID,
        thought: String,
        reasoning: String,
        confidence: Double = 0.8
    ) {
        guard let index = activeChains.firstIndex(where: { $0.id == chainId }) else { return }

        let stepNumber = activeChains[index].steps.count + 1
        let step = ThoughtStep(
            stepNumber: stepNumber,
            thought: thought,
            reasoning: reasoning,
            confidence: confidence
        )
        activeChains[index].addStep(step)
    }

    /// Complete a chain with a conclusion
    public func completeChain(_ chainId: UUID, conclusion: String) {
        guard let index = activeChains.firstIndex(where: { $0.id == chainId }) else { return }

        var chain = activeChains.remove(at: index)
        chain.complete(with: conclusion)
        completedChains.append(chain)
    }

    /// Process a problem through complete chain-of-thought reasoning
    public func process(
        problem: String,
        maxSteps: Int = 10,
        progressHandler: (@Sendable (Double, String) -> Void)? = nil
    ) async throws -> ThoughtChain {
        isProcessing = true
        defer { isProcessing = false }

        let chain = startChain(for: problem)

        // Step 1: Problem Understanding
        progressHandler?(0.1, "Understanding the problem")
        let understanding = try await generateThought(
            "First, let me understand what is being asked: \(problem)",
            context: []
        )
        addStep(to: chain.id, thought: "Problem Understanding", reasoning: understanding, confidence: 0.9)

        // Step 2: Break down the problem
        progressHandler?(0.3, "Breaking down the problem")
        let breakdown = try await generateThought(
            "Let me break this down into smaller parts that I need to address",
            context: chain.steps.map(\.reasoning)
        )
        addStep(to: chain.id, thought: "Problem Decomposition", reasoning: breakdown, confidence: 0.85)

        // Step 3: Analyze each component
        progressHandler?(0.5, "Analyzing components")
        let analysis = try await generateThought(
            "Now analyzing each component and how they relate",
            context: chain.steps.map(\.reasoning)
        )
        addStep(to: chain.id, thought: "Component Analysis", reasoning: analysis, confidence: 0.85)

        // Step 4: Develop solution
        progressHandler?(0.7, "Developing solution")
        let solution = try await generateThought(
            "Based on my analysis, here is my approach to solving this",
            context: chain.steps.map(\.reasoning)
        )
        addStep(to: chain.id, thought: "Solution Development", reasoning: solution, confidence: 0.8)

        // Step 5: Verify and conclude
        progressHandler?(0.9, "Verifying solution")
        let verification = try await generateThought(
            "Let me verify this solution addresses all parts of the problem",
            context: chain.steps.map(\.reasoning)
        )
        addStep(to: chain.id, thought: "Solution Verification", reasoning: verification, confidence: 0.85)

        // Generate final conclusion
        progressHandler?(1.0, "Completing")
        let conclusion = try await generateConclusion(from: chain)
        completeChain(chain.id, conclusion: conclusion)

        // Return the completed chain
        return completedChains.first { $0.id == chain.id } ?? chain
    }

    // MARK: - Private Helpers

    private func generateThought(_ prompt: String, context: [String]) async throws -> String {
        // In production, this would call the AI provider
        // For now, return a structured thought
        let contextSummary = context.isEmpty ? "" : "Previous thoughts: \(context.joined(separator: "; "))"
        return "\(prompt). \(contextSummary)"
    }

    private func generateConclusion(from chain: ThoughtChain) async throws -> String {
        let reasoningTrace = chain.steps.map { "Step \($0.stepNumber): \($0.thought) - \($0.reasoning)" }
            .joined(separator: "\n")

        return """
        Based on the chain-of-thought reasoning:

        \(reasoningTrace)

        Conclusion: The analysis of '\(chain.problem)' has been completed through \(chain.steps.count) reasoning steps with an overall confidence of \(String(format: "%.0f%%", chain.overallConfidence * 100)).
        """
    }

    // MARK: - Chain Management

    public func clearCompleted() {
        completedChains.removeAll()
    }

    public func getChain(_ id: UUID) -> ThoughtChain? {
        activeChains.first { $0.id == id } ?? completedChains.first { $0.id == id }
    }
}

// MARK: - Visualization Support

extension ThoughtChain {
    /// Generate a visual representation of the reasoning chain
    public var visualRepresentation: String {
        var lines: [String] = []
        lines.append("═══════════════════════════════════════")
        lines.append("Problem: \(problem)")
        lines.append("═══════════════════════════════════════")

        for step in steps {
            lines.append("│")
            lines.append("├─ Step \(step.stepNumber): \(step.thought)")
            lines.append("│  └─ \(step.reasoning)")
            lines.append("│  └─ Confidence: \(String(format: "%.0f%%", step.confidence * 100))")
        }

        if let conclusion = conclusion {
            lines.append("│")
            lines.append("╰─ CONCLUSION ─────────────────────────")
            lines.append("   \(conclusion)")
        }

        lines.append("═══════════════════════════════════════")
        lines.append("Overall Confidence: \(String(format: "%.0f%%", overallConfidence * 100))")

        return lines.joined(separator: "\n")
    }
}
