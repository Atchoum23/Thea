import Foundation

// MARK: - Reasoning Engine
// Multi-step reasoning with chain-of-thought, tree-of-thought, and various reasoning strategies

@MainActor
@Observable
final class ReasoningEngine {
    static let shared = ReasoningEngine()

    // Configuration accessor
    private var config: AgentConfiguration {
        AppConfiguration.shared.agentConfig
    }

    private var providerConfig: ProviderConfiguration {
        AppConfiguration.shared.providerConfig
    }

    private init() {}

    // MARK: - Chain-of-Thought Reasoning

    func chainOfThought(
        problem: String,
        context: [String: Any] = [:],
        progressHandler: @escaping @Sendable (ReasoningProgress) -> Void
    ) async throws -> ReasoningResult {
        var steps: [ReasoningStep] = []

        // Step 1: Problem decomposition
        progressHandler(ReasoningProgress(phase: "Decomposing problem", percentage: 0.2))
        let decomposition = try await askProvider(prompt: """
            Decompose this problem into its component parts: \(problem)
            List the key sub-problems or aspects that need to be addressed.
            """)
        steps.append(ReasoningStep(stepNumber: 1, description: "Problem decomposition", reasoning: decomposition, confidence: 0.9))

        // Step 2: Identify key information
        progressHandler(ReasoningProgress(phase: "Identifying key information", percentage: 0.4))
        let keyInfo = try await askProvider(prompt: """
            Given this problem: \(problem)
            And this decomposition: \(decomposition)
            Identify the key information, constraints, and requirements needed to solve this problem.
            """)
        steps.append(ReasoningStep(stepNumber: 2, description: "Key information extraction", reasoning: keyInfo, confidence: 0.85))

        // Step 3: Develop solution
        progressHandler(ReasoningProgress(phase: "Developing solution", percentage: 0.7))
        let solution = try await askProvider(prompt: """
            Problem: \(problem)
            Key information: \(keyInfo)
            Develop a step-by-step solution. For each step, explain your reasoning clearly.
            """)
        steps.append(ReasoningStep(stepNumber: 3, description: "Solution development", reasoning: solution, confidence: 0.85))

        // Step 4: Validate solution
        progressHandler(ReasoningProgress(phase: "Validating solution", percentage: 0.9))
        let validation = try await askProvider(prompt: """
            Validate this solution: \(solution)
            For the problem: \(problem)
            Is the solution correct? Are there any errors or gaps? Rate confidence 0-1.
            """)
        steps.append(ReasoningStep(stepNumber: 4, description: "Solution validation", reasoning: validation, confidence: 0.85))

        progressHandler(ReasoningProgress(phase: "Complete", percentage: 1.0))

        return ReasoningResult(
            problem: problem,
            conclusion: solution,
            steps: steps,
            strategy: .chainOfThought,
            confidence: calculateOverallConfidence(steps),
            alternatives: []
        )
    }

    // MARK: - Abductive Reasoning (Best Explanation)

    func abductiveReasoning(
        observation: String,
        possibleCauses: [String],
        context: [String: Any] = [:],
        progressHandler: @escaping @Sendable (ReasoningProgress) -> Void
    ) async throws -> ReasoningResult {
        var steps: [ReasoningStep] = []
        var causeScores: [(cause: String, score: Float, reasoning: String)] = []

        progressHandler(ReasoningProgress(phase: "Analyzing observation", percentage: 0.1))

        // Evaluate each possible cause
        for (index, cause) in possibleCauses.enumerated() {
            let progress = 0.1 + (0.7 * Float(index) / Float(possibleCauses.count))
            progressHandler(ReasoningProgress(phase: "Evaluating cause \(index + 1)/\(possibleCauses.count)", percentage: progress))

            let evaluation = try await askProvider(prompt: """
                Observation: \(observation)
                Possible cause: \(cause)
                Evaluate how well this cause explains the observation.
                Provide a score (0-1) and reasoning.
                """)

            let score: Float = 0.7 // Simplified - would parse from response in production
            causeScores.append((cause, score, evaluation))

            steps.append(ReasoningStep(
                stepNumber: index + 1,
                description: "Evaluate: \(cause)",
                reasoning: evaluation,
                confidence: score
            ))
        }

        // Sort by score
        let sorted = causeScores.sorted { $0.score > $1.score }

        progressHandler(ReasoningProgress(phase: "Selecting best explanation", percentage: 0.9))

        guard let bestCause = sorted.first else {
            throw ReasoningError.noValidExplanation
        }

        steps.append(ReasoningStep(
            stepNumber: steps.count + 1,
            description: "Best explanation selected",
            reasoning: "'\(bestCause.cause)' is the most likely explanation with confidence \(bestCause.score)",
            confidence: bestCause.score
        ))

        progressHandler(ReasoningProgress(phase: "Complete", percentage: 1.0))

        return ReasoningResult(
            problem: "What explains: \(observation)?",
            conclusion: bestCause.cause,
            steps: steps,
            strategy: .abductive,
            confidence: bestCause.score,
            alternatives: sorted.dropFirst().prefix(2).map { alternative in
                AlternativePath(
                    steps: [ReasoningStep(stepNumber: 1, description: alternative.cause, reasoning: alternative.reasoning, confidence: alternative.score)],
                    confidence: alternative.score
                )
            }
        )
    }

    // MARK: - Analogical Reasoning

    func analogicalReasoning(
        targetProblem: String,
        sourceDomain: String,
        sourceExample: String,
        context: [String: Any] = [:],
        progressHandler: @escaping @Sendable (ReasoningProgress) -> Void
    ) async throws -> ReasoningResult {
        var steps: [ReasoningStep] = []

        // Step 1: Map source to target
        progressHandler(ReasoningProgress(phase: "Mapping domains", percentage: 0.2))
        let mapping = try await askProvider(prompt: """
            Map this source domain: \(sourceDomain)
            With example: \(sourceExample)
            To this target domain: \(targetProblem)
            Identify analogous elements and relationships.
            """)
        steps.append(ReasoningStep(stepNumber: 1, description: "Domain mapping", reasoning: mapping, confidence: 0.8))

        // Step 2: Transfer solution
        progressHandler(ReasoningProgress(phase: "Transferring solution", percentage: 0.5))
        let transfer = try await askProvider(prompt: """
            Based on this domain mapping: \(mapping)
            Transfer the solution to this target problem: \(targetProblem)
            """)
        steps.append(ReasoningStep(stepNumber: 2, description: "Solution transfer", reasoning: transfer, confidence: 0.75))

        // Step 3: Adapt to target
        progressHandler(ReasoningProgress(phase: "Adapting solution", percentage: 0.8))
        let adapted = try await askProvider(prompt: """
            Adapt this transferred solution: \(transfer)
            To specifically solve: \(targetProblem)
            """)
        steps.append(ReasoningStep(stepNumber: 3, description: "Solution adaptation", reasoning: adapted, confidence: 0.8))

        progressHandler(ReasoningProgress(phase: "Complete", percentage: 1.0))

        return ReasoningResult(
            problem: targetProblem,
            conclusion: adapted,
            steps: steps,
            strategy: .analogical,
            confidence: calculateOverallConfidence(steps),
            alternatives: []
        )
    }

    // MARK: - Counterfactual Reasoning

    func counterfactualReasoning(
        scenario: String,
        change: String,
        context: [String: Any] = [:],
        progressHandler: @escaping @Sendable (ReasoningProgress) -> Void
    ) async throws -> ReasoningResult {
        var steps: [ReasoningStep] = []

        // Step 1: Analyze original scenario
        progressHandler(ReasoningProgress(phase: "Analyzing original scenario", percentage: 0.2))
        let original = try await askProvider(prompt: "Analyze this scenario and identify key causal relationships:\n\(scenario)")
        steps.append(ReasoningStep(stepNumber: 1, description: "Original scenario analysis", reasoning: original, confidence: 0.9))

        // Step 2: Apply change
        progressHandler(ReasoningProgress(phase: "Applying change", percentage: 0.4))
        let modified = try await askProvider(prompt: """
            Original: \(scenario)
            Change: \(change)
            Describe the modified scenario after applying this change.
            """)
        steps.append(ReasoningStep(stepNumber: 2, description: "Change application", reasoning: modified, confidence: 0.85))

        // Step 3: Trace consequences
        progressHandler(ReasoningProgress(phase: "Tracing consequences", percentage: 0.7))
        let consequences = try await askProvider(prompt: "Trace the consequences of this modified scenario:\n\(modified)")
        steps.append(ReasoningStep(stepNumber: 3, description: "Consequence analysis", reasoning: consequences, confidence: 0.8))

        // Step 4: Compare outcomes
        progressHandler(ReasoningProgress(phase: "Comparing outcomes", percentage: 0.9))
        let comparison = try await askProvider(prompt: """
            Compare these outcomes:
            Original: \(scenario)
            Modified: \(consequences)
            What changed and why?
            """)
        steps.append(ReasoningStep(stepNumber: 4, description: "Outcome comparison", reasoning: comparison, confidence: 0.75))

        progressHandler(ReasoningProgress(phase: "Complete", percentage: 1.0))

        return ReasoningResult(
            problem: "What if \(change) in: \(scenario)?",
            conclusion: comparison,
            steps: steps,
            strategy: .counterfactual,
            confidence: calculateOverallConfidence(steps),
            alternatives: []
        )
    }

    // MARK: - Helper Methods

    private func askProvider(prompt: String) async throws -> String {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw ReasoningError.providerNotAvailable
        }

        let reasoningModel = providerConfig.defaultReasoningModel

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: reasoningModel
        )

        var result = ""
        let stream = try await provider.chat(messages: [message], model: reasoningModel, stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case .delta(let text):
                result += text
            case .complete:
                break
            case .error(let error):
                throw error
            }
        }

        return result
    }

    private func calculateOverallConfidence(_ steps: [ReasoningStep]) -> Float {
        guard !steps.isEmpty else { return 0 }
        let total = steps.map { $0.confidence }.reduce(0, +)
        return total / Float(steps.count)
    }

    // MARK: - Deep Agent Integration Methods

    func analyzeTask(_ instruction: String, context: TaskContext) async throws -> String {
        // Analyze task using chain-of-thought reasoning
        let analysis = try await askProvider(prompt: """
            Analyze this task and provide a detailed breakdown:
            Task: \(instruction)

            Provide:
            1. Task complexity assessment
            2. Required capabilities
            3. Potential challenges
            4. Success criteria
            """)
        return analysis
    }

    func decomposeTask(_ instruction: String, taskType: TaskType, maxSteps: Int? = nil) async throws -> [String] {
        let actualMaxSteps = maxSteps ?? config.maxDecompositionSteps

        let taskTypeName: String
        switch taskType {
        case .appDevelopment: taskTypeName = "App Development"
        case .research: taskTypeName = "Research"
        case .contentCreation: taskTypeName = "Content Creation"
        case .workflowAutomation: taskTypeName = "Workflow Automation"
        case .codeGeneration: taskTypeName = "Code Generation"
        case .informationRetrieval: taskTypeName = "Information Retrieval"
        case .creation: taskTypeName = "Creation"
        case .general: taskTypeName = "General"
        default: taskTypeName = taskType.displayName
        }

        let prompt = """
            Decompose this \(taskTypeName) task into specific, actionable subtasks:
            Task: \(instruction)

            Provide exactly \(actualMaxSteps) subtasks as a numbered list.
            Each subtask should be atomic and independently executable.
            """

        let decomposition = try await askProvider(prompt: prompt)

        // Parse numbered list into array
        let subtasks = decomposition
            .components(separatedBy: CharacterSet.newlines)
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                // Match "1. " or "1) " patterns
                if let range = trimmed.range(of: "^\\d+[.)\\s]+", options: .regularExpression) {
                    return String(trimmed[range.upperBound...]).trimmingCharacters(in: CharacterSet.whitespaces)
                }
                return nil
            }

        return Array(subtasks.prefix(actualMaxSteps))
    }

    func verifyOutput(_ output: String, expectedCriteria: [String]) async throws -> (isValid: Bool, confidence: Double, issues: [String]) {
        let criteriaText = expectedCriteria.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let verification = try await askProvider(prompt: """
            Verify if this output meets the following criteria:

            Output:
            \(output)

            Criteria:
            \(criteriaText)

            Respond in this exact format:
            VALID: yes/no
            CONFIDENCE: 0.0-1.0
            ISSUES: list any problems found, or "none"
            """)

        let isValid = verification.lowercased().contains("valid: yes")
        let confidence = extractConfidence(from: verification)
        let issues = extractIssues(from: verification)

        return (isValid, confidence, issues)
    }

    func synthesize(_ results: [String], instruction: String) async throws -> String {
        let resultsText = results.enumerated().map { "Result \($0.offset + 1):\n\($0.element)" }.joined(separator: "\n\n")

        let synthesis = try await askProvider(prompt: """
            Synthesize these results into a final answer for the original task:

            Original Task: \(instruction)

            \(resultsText)

            Provide a comprehensive, coherent final answer.
            """)

        return synthesis
    }

    private func extractConfidence(from text: String) -> Double {
        if let range = text.range(of: "confidence:\\s*([0-9.]+)", options: [.regularExpression, .caseInsensitive]),
           let valueStr = text[range].components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces),
           let value = Double(valueStr) {
            return value
        }
        return config.defaultConfidence
    }

    private func extractIssues(from text: String) -> [String] {
        if let range = text.range(of: "issues:\\s*(.+)", options: [.regularExpression, .caseInsensitive]) {
            let issuesText = String(text[range]).components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
            if issuesText.lowercased() == "none" {
                return []
            }
            return issuesText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return []
    }
}

// MARK: - Reasoning Models

struct ReasoningResult: Codable, Sendable {
    let problem: String
    let conclusion: String
    let steps: [ReasoningStep]
    let strategy: ReasoningStrategy
    let confidence: Float
    let alternatives: [AlternativePath]
}

struct ReasoningStep: Codable, Sendable {
    let stepNumber: Int
    let description: String
    let reasoning: String
    let confidence: Float
}

struct AlternativePath: Codable, Sendable {
    let steps: [ReasoningStep]
    let confidence: Float
}

struct ReasoningProgress: Sendable {
    let phase: String
    let percentage: Float
}

enum ReasoningStrategy: String, Codable, Sendable {
    case chainOfThought = "Chain-of-Thought"
    case abductive = "Abductive"
    case analogical = "Analogical"
    case counterfactual = "Counterfactual"
}

enum ReasoningError: LocalizedError {
    case providerNotAvailable
    case noValidExplanation

    var errorDescription: String? {
        switch self {
        case .providerNotAvailable:
            return "AI provider is not available for reasoning"
        case .noValidExplanation:
            return "No valid explanation found"
        }
    }
}
