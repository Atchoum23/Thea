// QueryDecomposer.swift
import Foundation

/// Decomposes complex queries into sub-queries for parallel or sequential execution.
/// Implements intelligent aggregation of sub-query results.
@MainActor
@Observable
public final class QueryDecomposer {
    public static let shared = QueryDecomposer()

    private let config = OrchestratorConfiguration.load()
    private let classifier = TaskClassifier.shared
    private let router = ModelRouter.shared
    private let providerRegistry = ProviderRegistry.shared

    private init() {}

    // MARK: - Public API

    /// Decompose a query into executable sub-queries
    public func decompose(_ query: String) async throws -> QueryDecomposition {
        // 1. Assess complexity
        let complexity = classifier.assessComplexity(query)

        if complexity == .simple {
            // Simple queries don't need decomposition
            let classification = try await classifier.classify(query)
            return QueryDecomposition(
                originalQuery: query,
                complexity: complexity,
                subQueries: [
                    SubQuery(
                        query: query,
                        taskType: classification.primaryType,
                        dependencies: [],
                        priority: 1
                    )
                ],
                executionPlan: .sequential
            )
        }

        // 2. Use AI to decompose complex queries
        let decomposition = try await decomposeWithAI(query, complexity: complexity)

        if config.showDecompositionDetails {
            print("[QueryDecomposer] Decomposed into \(decomposition.subQueries.count) sub-queries")
            print("[QueryDecomposer] Execution plan: \(decomposition.executionPlan)")
        }

        return decomposition
    }

    /// Aggregate results from multiple sub-queries
    public func aggregate(
        _ results: [SubQueryResult],
        originalQuery: String
    ) async throws -> String {
        guard !results.isEmpty else {
            throw QueryDecompositionError.noResultsToAggregate
        }

        // Single result needs no aggregation
        if results.count == 1 {
            return results[0].response
        }

        // Multiple results need intelligent aggregation
        return try await aggregateWithAI(results, originalQuery: originalQuery)
    }

    // MARK: - AI-Based Decomposition

    private func decomposeWithAI(
        _ query: String,
        complexity: QueryComplexity
    ) async throws -> QueryDecomposition {
        // Get a provider for decomposition
        guard let provider = getDecompositionProvider() else {
            // Fallback to simple decomposition
            return try await createSimpleDecomposition(query, complexity: complexity)
        }

        let prompt = createDecompositionPrompt(query: query, complexity: complexity)

        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "decomposer"
            )

            var response = ""
            let stream = try await provider.chat(
                messages: [message],
                model: getDecompositionModelID(for: provider),
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    response += text
                }
            }

            // Parse the AI response
            return try parseDecompositionResponse(response, originalQuery: query, complexity: complexity)

        } catch {
            print("⚠️ AI decomposition failed: \(error), using simple decomposition")
            return try await createSimpleDecomposition(query, complexity: complexity)
        }
    }

    private func getDecompositionProvider() -> AIProvider? {
        // Prefer a capable model for decomposition (needs reasoning)
        if let openRouter = providerRegistry.getProvider(id: "openrouter") {
            return openRouter
        }
        if let anthropic = providerRegistry.getProvider(id: "anthropic") {
            return anthropic
        }
        if let openAI = providerRegistry.getProvider(id: "openai") {
            return openAI
        }
        // Local model as last resort
        return providerRegistry.getLocalProvider()
    }

    private func getDecompositionModelID(for provider: AIProvider) -> String {
        if provider.metadata.name.lowercased().contains("local") {
            return provider.metadata.name
        }
        // Use a fast, capable model for decomposition
        return "anthropic/claude-3-haiku"
    }

    private func createSimpleDecomposition(_ query: String, complexity: QueryComplexity) async throws -> QueryDecomposition {
        let classification = try await classifier.classify(query)

        return QueryDecomposition(
            originalQuery: query,
            complexity: complexity,
            subQueries: [
                SubQuery(
                    query: query,
                    taskType: classification.primaryType,
                    dependencies: [],
                    priority: 1
                )
            ],
            executionPlan: .sequential
        )
    }

    private func createDecompositionPrompt(query: String, complexity: QueryComplexity) -> String {
        """
        You are a query decomposition expert. Break down the following query into sub-queries that can be executed independently.

        Original Query: "\(query)"
        Complexity: \(complexity.rawValue)

        Instructions:
        1. Identify distinct tasks within the query
        2. For each task, create a focused sub-query
        3. Determine dependencies between sub-queries (if any)
        4. Assign priority (1 = highest, 5 = lowest)
        5. Classify each sub-query's type (code, reasoning, factual, etc.)

        Respond in JSON format:
        {
          "subQueries": [
            {
              "query": "The focused sub-query",
              "taskType": "codeGeneration|complexReasoning|simpleQA|etc",
              "dependencies": [], // Array of indices of sub-queries this depends on
              "priority": 1
            }
          ],
          "executionPlan": "sequential|parallel|mixed"
        }

        Important:
        - Keep sub-queries focused and actionable
        - Minimize dependencies for better parallelization
        - Use sequential plan only when tasks must be done in order
        """
    }

    private func parseDecompositionResponse(
        _ response: String,
        originalQuery: String,
        complexity: QueryComplexity
    ) throws -> QueryDecomposition {
        // Extract JSON from response (may be wrapped in markdown)
        let jsonString = extractJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw QueryDecompositionError.invalidDecompositionResponse
        }

        let decoder = JSONDecoder()
        let decompositionResponse = try decoder.decode(DecompositionResponse.self, from: data)

        // Convert to SubQuery objects
        var subQueries: [SubQuery] = []
        for (_, item) in decompositionResponse.subQueries.enumerated() {
            let taskType = TaskType(rawValue: item.taskType) ?? .simpleQA

            // Resolve dependencies (convert indices to UUIDs)
            let dependencies: [UUID] = item.dependencies.compactMap { depIndex in
                guard depIndex < subQueries.count else { return nil }
                return subQueries[depIndex].id
            }

            let subQuery = SubQuery(
                query: item.query,
                taskType: taskType,
                dependencies: dependencies,
                priority: item.priority
            )
            subQueries.append(subQuery)
        }

        // Determine execution plan
        let executionPlan: SubQueryExecutionStrategy = switch decompositionResponse.executionPlan {
        case "sequential":
            .sequential
        case "parallel":
            .parallel
        case "mixed":
            .mixed
        default:
            // Default to sequential for safety
            .sequential
        }

        return QueryDecomposition(
            originalQuery: originalQuery,
            complexity: complexity,
            subQueries: subQueries,
            executionPlan: executionPlan
        )
    }

    private func extractJSON(from response: String) -> String {
        // Try to find JSON in markdown code blocks
        if let startIndex = response.range(of: "```json")?.upperBound,
           let endIndex = response.range(of: "```", range: startIndex ..< response.endIndex)?.lowerBound
        {
            return String(response[startIndex ..< endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to find JSON object
        if let startIndex = response.range(of: "{")?.lowerBound,
           let endIndex = response.range(of: "}", options: .backwards)?.upperBound
        {
            return String(response[startIndex ..< endIndex])
        }

        // Return as-is and hope for the best
        return response
    }

    // MARK: - Result Aggregation

    private func aggregateWithAI(
        _ results: [SubQueryResult],
        originalQuery: String
    ) async throws -> String {
        // Get a provider for aggregation (needs reasoning capability)
        guard let provider = getDecompositionProvider() else {
            // Fallback to simple concatenation if no provider available
            return simpleConcatenation(results, originalQuery: originalQuery)
        }

        let prompt = createAggregationPrompt(results: results, originalQuery: originalQuery)

        do {
            let message = AIMessage(
                id: UUID(),
                conversationID: UUID(),
                role: .user,
                content: .text(prompt),
                timestamp: Date(),
                model: "aggregator"
            )

            var response = ""
            let stream = try await provider.chat(
                messages: [message],
                model: getDecompositionModelID(for: provider),
                stream: false
            )

            for try await chunk in stream {
                if case .delta(let text) = chunk.type {
                    response += text
                }
            }

            return response.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            print("⚠️ AI aggregation failed: \(error), using simple concatenation")
            return simpleConcatenation(results, originalQuery: originalQuery)
        }
    }

    private func simpleConcatenation(
        _ results: [SubQueryResult],
        originalQuery: String
    ) -> String {
        var aggregated = "Query: \(originalQuery)\n\n"

        for (index, result) in results.enumerated() {
            aggregated += "Result \(index + 1):\n\(result.response)\n\n"
        }

        return aggregated.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createAggregationPrompt(
        results: [SubQueryResult],
        originalQuery: String
    ) -> String {
        var prompt = """
        You are a result aggregation expert. Synthesize the following sub-query results into a coherent, comprehensive answer.

        Original Query: "\(originalQuery)"

        Sub-Query Results:

        """

        for (index, result) in results.enumerated() {
            prompt += """

            \(index + 1). Sub-Query: "\(result.subQuery.query)"
               Task Type: \(result.subQuery.taskType.displayName)
               Success: \(result.success)
               Response:
               \(result.response)

            """
        }

        prompt += """

        Instructions:
        1. Synthesize all results into a single, coherent response
        2. Resolve any conflicts between results
        3. Ensure the answer directly addresses the original query
        4. Maintain clarity and conciseness
        5. Preserve important details from individual results

        Provide a well-structured, complete answer:
        """

        return prompt
    }
}

// MARK: - Supporting Types

/// Decomposition of a complex query
public struct QueryDecomposition: Sendable {
    public let originalQuery: String
    public let complexity: QueryComplexity
    public let subQueries: [SubQuery]
    public let executionPlan: SubQueryExecutionStrategy

    public init(
        originalQuery: String,
        complexity: QueryComplexity,
        subQueries: [SubQuery],
        executionPlan: SubQueryExecutionStrategy
    ) {
        self.originalQuery = originalQuery
        self.complexity = complexity
        self.subQueries = subQueries
        self.executionPlan = executionPlan
    }

    /// Get sub-queries that can be executed in parallel (no dependencies)
    public var parallelizableQueries: [SubQuery] {
        subQueries.filter(\.dependencies.isEmpty)
    }

    /// Get sub-queries sorted by priority
    public var prioritizedQueries: [SubQuery] {
        subQueries.sorted { $0.priority < $1.priority }
    }
}

/// Individual sub-query within a decomposition
public struct SubQuery: Identifiable, Sendable {
    public let id: UUID
    public let query: String
    public let taskType: TaskType
    public let dependencies: [UUID] // IDs of sub-queries this depends on
    public let priority: Int // 1 = highest, 5 = lowest

    public init(
        id: UUID = UUID(),
        query: String,
        taskType: TaskType,
        dependencies: [UUID],
        priority: Int
    ) {
        self.id = id
        self.query = query
        self.taskType = taskType
        self.dependencies = dependencies
        self.priority = priority
    }

    /// Check if this sub-query can be executed (all dependencies resolved)
    public func canExecute(completed: Set<UUID>) -> Bool {
        dependencies.allSatisfy { completed.contains($0) }
    }
}

/// Result of executing a sub-query
public struct SubQueryResult: Sendable {
    public let subQuery: SubQuery
    public let response: String
    public let success: Bool
    public let executionTime: TimeInterval
    public let modelUsed: String

    public init(
        subQuery: SubQuery,
        response: String,
        success: Bool,
        executionTime: TimeInterval,
        modelUsed: String
    ) {
        self.subQuery = subQuery
        self.response = response
        self.success = success
        self.executionTime = executionTime
        self.modelUsed = modelUsed
    }
}

/// Execution strategies for sub-queries
public enum SubQueryExecutionStrategy: String, Codable, Sendable {
    case sequential // Execute one at a time in order
    case parallel // Execute all at once
    case mixed // Some parallel, some sequential based on dependencies
}

// MARK: - Errors

public enum QueryDecompositionError: Error, LocalizedError {
    case invalidDecompositionResponse
    case noResultsToAggregate
    case providerNotAvailable(providerID: String)
    case decompositionFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidDecompositionResponse:
            "Failed to parse decomposition response"
        case .noResultsToAggregate:
            "No results available for aggregation"
        case let .providerNotAvailable(providerID):
            "Provider not available: \(providerID)"
        case let .decompositionFailed(reason):
            "Decomposition failed: \(reason)"
        }
    }
}

// MARK: - Internal Types for JSON Decoding

private struct DecompositionResponse: Codable {
    let subQueries: [DecompositionSubQuery]
    let executionPlan: String
}

private struct DecompositionSubQuery: Codable {
    let query: String
    let taskType: String
    let dependencies: [Int]
    let priority: Int
}
