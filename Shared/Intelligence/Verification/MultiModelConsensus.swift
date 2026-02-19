// MultiModelConsensus.swift
// Thea
//
// AI-powered multi-model consensus system for validating responses
// Queries multiple AI models and calculates agreement for legitimate confidence

import Foundation
import OSLog

// MARK: - Multi-Model Consensus

/// Validates responses by querying multiple AI models and measuring agreement
@MainActor
public final class MultiModelConsensus {
    private let logger = Logger(subsystem: "com.thea.ai", category: "MultiModelConsensus")

    // Configuration
    public var minModelsForConsensus: Int = 2
    public var maxModelsToQuery: Int = 3
    public var consensusThreshold: Double = 0.7  // 70% agreement = consensus
    public var timeout: TimeInterval = 15.0

    // Model preferences by task type
    private let modelPreferences: [TaskType: [String]] = [
        .codeGeneration: ["anthropic/claude-sonnet-4-6", "openai/gpt-4o", "google/gemini-pro"],
        .debugging: ["anthropic/claude-sonnet-4-6", "openai/gpt-4o", "openai/o1"],
        .analysis: ["anthropic/claude-opus-4-6", "openai/o1", "google/gemini-pro"],
        .factual: ["openai/gpt-4o", "anthropic/claude-sonnet-4-6", "perplexity/sonar"],
        .conversation: ["openai/gpt-4o-mini", "anthropic/claude-haiku", "google/gemini-flash"]
    ]

    // MARK: - Validation

    /// Validate a response using multi-model consensus
    public func validate(
        query: String,
        response: String,
        taskType: TaskType
    ) async -> ConsensusResult {
        logger.info("Starting multi-model consensus for \(taskType.rawValue)")

        let models = selectModels(for: taskType)
        var modelResponses: [ModelResponse] = []

        // Query each model for validation
        await withTaskGroup(of: ModelResponse?.self) { group in
            for modelId in models.prefix(maxModelsToQuery) {
                group.addTask { [weak self] in
                    await self?.queryModelForValidation(
                        modelId: modelId,
                        query: query,
                        originalResponse: response
                    )
                }
            }

            for await result in group {
                if let response = result {
                    modelResponses.append(response)
                }
            }
        }

        // Calculate consensus
        return calculateConsensus(
            originalResponse: response,
            modelResponses: modelResponses,
            taskType: taskType
        )
    }

    // MARK: - Model Selection

    private func selectModels(for taskType: TaskType) -> [String] {
        // Get preferred models for this task type
        var models = modelPreferences[taskType] ?? ["anthropic/claude-sonnet-4-6", "openai/gpt-4o"]

        // Filter to only available models
        let availableProviders = ProviderRegistry.shared.availableProviders.filter { $0.isConfigured }
        let availableIds = Set(availableProviders.map { $0.id })

        models = models.filter { modelId in
            let provider = modelId.split(separator: "/").first.map(String.init) ?? ""
            return availableIds.contains(provider) || availableIds.contains("openrouter")
        }

        // Ensure we have at least some models
        if models.count < minModelsForConsensus {
            // Add any available model
            for provider in availableProviders {
                if !models.contains(where: { $0.contains(provider.id) }) {
                    models.append("\(provider.id)/default")
                }
                if models.count >= minModelsForConsensus {
                    break
                }
            }
        }

        return models
    }

    // MARK: - Model Query

    private func queryModelForValidation(
        modelId: String,
        query: String,
        originalResponse: String
    ) async -> ModelResponse? {
        let validationPrompt = buildValidationPrompt(
            query: query,
            response: originalResponse
        )

        do {
            // Get provider
            let providerName = modelId.split(separator: "/").first.map(String.init) ?? "openrouter"
            guard let provider = ProviderRegistry.shared.getProvider(id: providerName)
                ?? ProviderRegistry.shared.getProvider(id: "openrouter") else {
                logger.warning("No provider available for \(modelId)")
                return nil
            }

            let message = AIMessage(
                id: UUID(), conversationID: UUID(), role: .user,
                content: .text(validationPrompt),
                timestamp: Date(), model: modelId
            )

            var responseText = ""
            let stream = try await provider.chat(
                messages: [message],
                model: modelId,
                stream: false
            )

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text):
                    responseText += text
                case let .complete(msg):
                    responseText = msg.content.textValue
                case .error:
                    break
                }
            }

            return parseValidationResponse(responseText, modelId: modelId)

        } catch {
            logger.warning("Failed to query \(modelId): \(error.localizedDescription)")
            return nil
        }
    }

    private func buildValidationPrompt(query: String, response: String) -> String {
        """
        Evaluate this AI response for accuracy and completeness.

        Original Query: "\(query.prefix(500))"

        Response to Evaluate:
        \(response.prefix(2000))

        Provide your assessment as JSON:
        {
            "accuracy": 0.0-1.0,
            "completeness": 0.0-1.0,
            "factualErrors": ["list of any factual errors found"],
            "missingInfo": ["list of important missing information"],
            "overallQuality": 0.0-1.0,
            "agreesWithResponse": true/false,
            "reasoning": "brief explanation"
        }
        """
    }

    private func parseValidationResponse(_ response: String, modelId: String) -> ModelResponse? {
        // Extract JSON
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            return ModelResponse(
                modelId: modelId,
                agrees: true,
                accuracy: 0.5,
                completeness: 0.5,
                quality: 0.5,
                factualErrors: [],
                reasoning: "Could not parse validation response"
            )
        }

        let jsonStr = String(response[jsonStart...jsonEnd])
        guard let data = jsonStr.data(using: .utf8) else {
            return ModelResponse(
                modelId: modelId,
                agrees: true,
                accuracy: 0.5,
                completeness: 0.5,
                quality: 0.5,
                factualErrors: [],
                reasoning: "JSON parse failed"
            )
        }
        let json: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return ModelResponse(
                    modelId: modelId,
                    agrees: true,
                    accuracy: 0.5,
                    completeness: 0.5,
                    quality: 0.5,
                    factualErrors: [],
                    reasoning: "JSON parse failed"
                )
            }
            json = parsed
        } catch {
            logger.error("Failed to parse model response JSON: \(error.localizedDescription)")
            return ModelResponse(
                modelId: modelId,
                agrees: true,
                accuracy: 0.5,
                completeness: 0.5,
                quality: 0.5,
                factualErrors: [],
                reasoning: "JSON parse failed"
            )
        }

        return ModelResponse(
            modelId: modelId,
            agrees: json["agreesWithResponse"] as? Bool ?? true,
            accuracy: json["accuracy"] as? Double ?? 0.5,
            completeness: json["completeness"] as? Double ?? 0.5,
            quality: json["overallQuality"] as? Double ?? 0.5,
            factualErrors: json["factualErrors"] as? [String] ?? [],
            reasoning: json["reasoning"] as? String ?? ""
        )
    }

    // MARK: - Consensus Calculation

    private func calculateConsensus(
        originalResponse: String,
        // periphery:ignore - Reserved: originalResponse parameter kept for API compatibility
        modelResponses: [ModelResponse],
        // periphery:ignore - Reserved: taskType parameter kept for API compatibility
        taskType: TaskType
    ) -> ConsensusResult {
        guard !modelResponses.isEmpty else {
            return ConsensusResult(
                source: ConfidenceSource(
                    type: .modelConsensus,
                    name: "Multi-Model Consensus",
                    confidence: 0.0,
                    weight: 0.35,
                    details: "No models responded",
                    verified: false
                ),
                factors: [],
                conflicts: []
            )
        }

        // Calculate agreement
        let agreementCount = modelResponses.filter { $0.agrees }.count
        let agreementRate = Double(agreementCount) / Double(modelResponses.count)

        // Calculate average quality scores
        let avgAccuracy = modelResponses.map(\.accuracy).reduce(0, +) / Double(modelResponses.count)
        _ = modelResponses.map(\.completeness).reduce(0, +) / Double(modelResponses.count)  // Completeness tracked for future use
        let avgQuality = modelResponses.map(\.quality).reduce(0, +) / Double(modelResponses.count)

        // Overall confidence from consensus
        let consensusConfidence = (agreementRate * 0.4 + avgAccuracy * 0.3 + avgQuality * 0.3)

        // Identify conflicts
        var conflicts: [ConfidenceDecomposition.ConflictInfo] = []
        let disagreeing = modelResponses.filter { !$0.agrees }
        for disagree in disagreeing {
            if let agreeing = modelResponses.first(where: { $0.agrees }) {
                conflicts.append(ConfidenceDecomposition.ConflictInfo(
                    source1: agreeing.modelId,
                    source2: disagree.modelId,
                    description: disagree.reasoning,
                    severity: agreementRate < 0.5 ? .major : .moderate
                ))
            }
        }

        // Collect all factual errors
        let allErrors = modelResponses.flatMap(\.factualErrors)
        let uniqueErrors = Array(Set(allErrors))

        // Build factors
        var factors: [ConfidenceDecomposition.DecompositionFactor] = []

        factors.append(ConfidenceDecomposition.DecompositionFactor(
            name: "Model Agreement",
            contribution: (agreementRate - 0.5) * 2,  // -1 to 1 scale
            explanation: "\(agreementCount)/\(modelResponses.count) models agree"
        ))

        factors.append(ConfidenceDecomposition.DecompositionFactor(
            name: "Average Accuracy",
            contribution: (avgAccuracy - 0.5) * 2,
            explanation: "Models rated accuracy at \(String(format: "%.0f%%", avgAccuracy * 100))"
        ))

        if !uniqueErrors.isEmpty {
            factors.append(ConfidenceDecomposition.DecompositionFactor(
                name: "Factual Errors",
                contribution: -0.3 * Double(uniqueErrors.count),
                explanation: "\(uniqueErrors.count) potential factual errors identified"
            ))
        }

        let details = """
            \(modelResponses.count) models queried, \(agreementCount) agree.
            Accuracy: \(String(format: "%.0f%%", avgAccuracy * 100)), \
            Quality: \(String(format: "%.0f%%", avgQuality * 100))
            \(uniqueErrors.isEmpty ? "" : "Errors found: \(uniqueErrors.joined(separator: "; "))")
            """

        return ConsensusResult(
            source: ConfidenceSource(
                type: .modelConsensus,
                name: "Multi-Model Consensus",
                confidence: consensusConfidence,
                weight: 0.35,
                details: details,
                verified: agreementRate >= consensusThreshold
            ),
            factors: factors,
            conflicts: conflicts
        )
    }
}

// MARK: - Supporting Types

struct ModelResponse: Sendable {
    let modelId: String
    let agrees: Bool
    let accuracy: Double
    let completeness: Double
    let quality: Double
    let factualErrors: [String]
    let reasoning: String
}

public struct ConsensusResult: Sendable {
    public let source: ConfidenceSource
    public let factors: [ConfidenceDecomposition.DecompositionFactor]
    public let conflicts: [ConfidenceDecomposition.ConflictInfo]
}
