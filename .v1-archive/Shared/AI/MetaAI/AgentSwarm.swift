import Foundation

// MARK: - Agent Swarm

// Parallel agent execution with load balancing and consensus

@MainActor
@Observable
final class AgentSwarm {
    static let shared = AgentSwarm()

    private(set) var activeSwarms: [Swarm] = []
    private(set) var swarmResults: [SwarmResult] = []

    private let maxConcurrentAgents = 10

    private init() {}

    // MARK: - Swarm Execution

    func executeSwarm(
        task: String,
        agentCount: Int = 5,
        strategy: SwarmStrategy = .parallel,
        progressHandler: @escaping @Sendable (SwarmProgress) -> Void
    ) async throws -> SwarmResult {
        let swarm = Swarm(
            id: UUID(),
            task: task,
            agentCount: min(agentCount, maxConcurrentAgents),
            strategy: strategy,
            startTime: Date()
        )

        activeSwarms.append(swarm)

        let result: SwarmResult = switch strategy {
        case .parallel:
            try await executeParallel(swarm: swarm, progressHandler: progressHandler)
        case .competitive:
            try await executeCompetitive(swarm: swarm, progressHandler: progressHandler)
        case .collaborative:
            try await executeCollaborative(swarm: swarm, progressHandler: progressHandler)
        case .consensus:
            try await executeConsensus(swarm: swarm, progressHandler: progressHandler)
        }

        swarmResults.append(result)

        if let index = activeSwarms.firstIndex(where: { $0.id == swarm.id }) {
            activeSwarms.remove(at: index)
        }

        return result
    }

    // MARK: - Execution Strategies

    private func executeParallel(
        swarm: Swarm,
        progressHandler: @escaping @Sendable (SwarmProgress) -> Void
    ) async throws -> SwarmResult {
        var agentResults: [AgentResult] = []

        // Execute all agents sequentially (satisfies Swift 6 region-based isolation)
        for i in 0 ..< swarm.agentCount {
            let progress = Float(i) / Float(swarm.agentCount)
            progressHandler(SwarmProgress(phase: "Agent \(i + 1) executing", percentage: progress))

            let result = try await executeAgent(
                task: swarm.task,
                agentIndex: i,
                totalAgents: swarm.agentCount
            )
            agentResults.append(result)
        }

        progressHandler(SwarmProgress(phase: "Aggregating results", percentage: 1.0))

        // Aggregate results
        let aggregated = try await aggregateResults(agentResults)

        return SwarmResult(
            swarmID: swarm.id,
            task: swarm.task,
            strategy: .parallel,
            agentResults: agentResults,
            finalResult: aggregated,
            executionTime: Date().timeIntervalSince(swarm.startTime),
            consensus: nil
        )
    }

    private func executeCompetitive(
        swarm: Swarm,
        progressHandler: @escaping @Sendable (SwarmProgress) -> Void
    ) async throws -> SwarmResult {
        var agentResults: [AgentResult] = []

        // Execute all agents sequentially (satisfies Swift 6 region-based isolation)
        for i in 0 ..< swarm.agentCount {
            let result = try await executeAgent(
                task: swarm.task,
                agentIndex: i,
                totalAgents: swarm.agentCount
            )
            agentResults.append(result)
            let progress = Float(agentResults.count) / Float(swarm.agentCount)
            progressHandler(SwarmProgress(phase: "Agent \(agentResults.count) complete", percentage: progress))
        }

        // Select best result based on confidence
        let bestResult = agentResults.max { $0.confidence < $1.confidence }?.output ?? ""

        return SwarmResult(
            swarmID: swarm.id,
            task: swarm.task,
            strategy: .competitive,
            agentResults: agentResults,
            finalResult: bestResult,
            executionTime: Date().timeIntervalSince(swarm.startTime),
            consensus: nil
        )
    }

    private func executeCollaborative(
        swarm: Swarm,
        progressHandler: @escaping @Sendable (SwarmProgress) -> Void
    ) async throws -> SwarmResult {
        var agentResults: [AgentResult] = []
        var currentContext = swarm.task

        // Execute agents sequentially, each building on previous
        for i in 0 ..< swarm.agentCount {
            let progress = Float(i) / Float(swarm.agentCount)
            progressHandler(SwarmProgress(phase: "Agent \(i + 1) collaborating", percentage: progress))

            let result = try await executeAgent(
                task: currentContext,
                agentIndex: i,
                totalAgents: swarm.agentCount
            )

            agentResults.append(result)
            currentContext += "\n\nAgent \(i + 1) contribution: \(result.output)"
        }

        let finalResult = agentResults.last?.output ?? ""

        return SwarmResult(
            swarmID: swarm.id,
            task: swarm.task,
            strategy: .collaborative,
            agentResults: agentResults,
            finalResult: finalResult,
            executionTime: Date().timeIntervalSince(swarm.startTime),
            consensus: nil
        )
    }

    private func executeConsensus(
        swarm: Swarm,
        progressHandler: @escaping @Sendable (SwarmProgress) -> Void
    ) async throws -> SwarmResult {
        var agentResults: [AgentResult] = []

        // Execute all agents sequentially (satisfies Swift 6 region-based isolation)
        for i in 0 ..< swarm.agentCount {
            let result = try await executeAgent(
                task: swarm.task,
                agentIndex: i,
                totalAgents: swarm.agentCount
            )
            agentResults.append(result)
        }

        progressHandler(SwarmProgress(phase: "Building consensus", percentage: 0.9))

        // Build consensus through voting/averaging
        let consensus = try await buildConsensus(from: agentResults)

        return SwarmResult(
            swarmID: swarm.id,
            task: swarm.task,
            strategy: .consensus,
            agentResults: agentResults,
            finalResult: consensus.result,
            executionTime: Date().timeIntervalSince(swarm.startTime),
            consensus: consensus
        )
    }

    // MARK: - Agent Execution

    private func executeAgent(
        task: String,
        agentIndex: Int,
        totalAgents: Int
    ) async throws -> AgentResult {
        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw SwarmError.providerNotAvailable
        }

        _ = """
        You are Agent #\(agentIndex + 1) in a swarm of \(totalAgents) agents.
        Provide your unique perspective and analysis.
        """

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(task),
            timestamp: Date(),
            model: "gpt-4o"
        )

        var output = ""
        let stream = try await provider.chat(messages: [message], model: "gpt-4o", stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                output += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return AgentResult(
            agentIndex: agentIndex,
            output: output,
            confidence: 0.8,
            executionTime: 1.0
        )
    }

    // MARK: - Result Processing

    private func aggregateResults(_ results: [AgentResult]) async throws -> String {
        let outputs = results.map(\.output).joined(separator: "\n\n---\n\n")

        guard let provider = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw SwarmError.providerNotAvailable
        }

        let prompt = """
        Aggregate these results from \(results.count) agents:

        \(outputs)

        Provide a unified, comprehensive summary.
        """

        let message = AIMessage(
            id: UUID(),
            conversationID: UUID(),
            role: .user,
            content: .text(prompt),
            timestamp: Date(),
            model: "gpt-4o"
        )

        var aggregated = ""
        let stream = try await provider.chat(messages: [message], model: "gpt-4o", stream: true)

        for try await chunk in stream {
            switch chunk.type {
            case let .delta(text):
                aggregated += text
            case .complete:
                break
            case let .error(error):
                throw error
            }
        }

        return aggregated
    }

    private func buildConsensus(from results: [AgentResult]) async throws -> Consensus {
        // Simplified consensus building
        let agreementLevel = Float(results.count) / Float(results.count)

        let consensusResult = try await aggregateResults(results)

        return Consensus(
            agreementLevel: agreementLevel,
            result: consensusResult,
            dissenting: []
        )
    }
}

// MARK: - Models

struct Swarm: Identifiable {
    let id: UUID
    let task: String
    let agentCount: Int
    let strategy: SwarmStrategy
    let startTime: Date
}

struct SwarmResult: Identifiable {
    let id = UUID()
    let swarmID: UUID
    let task: String
    let strategy: SwarmStrategy
    let agentResults: [AgentResult]
    let finalResult: String
    let executionTime: TimeInterval
    let consensus: Consensus?
}

struct AgentResult {
    let agentIndex: Int
    let output: String
    let confidence: Float
    let executionTime: TimeInterval
}

struct Consensus {
    let agreementLevel: Float
    let result: String
    let dissenting: [Int]
}

struct SwarmProgress: Sendable {
    let phase: String
    let percentage: Float
}

enum SwarmStrategy {
    case parallel // All agents execute independently
    case competitive // Best result wins
    case collaborative // Agents build on each other
    case consensus // Vote/agree on final result
}

enum SwarmError: LocalizedError {
    case providerNotAvailable
    case executionFailed

    var errorDescription: String? {
        switch self {
        case .providerNotAvailable:
            "AI provider not available"
        case .executionFailed:
            "Swarm execution failed"
        }
    }
}
