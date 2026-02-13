import Foundation
import os.log

private let providerLogger = Logger(subsystem: "ai.thea.app", category: "ChatManager+Provider")

// MARK: - Orchestrator Integration & Provider Selection

extension ChatManager {

    /// Select provider and model using TaskClassifier + ModelRouter orchestration (macOS).
    /// Returns the classification result for automatic prompt engineering.
    func selectProviderAndModel(for query: String) async throws -> (AIProvider, String, TaskType?) {
        #if os(macOS)
        do {
            let classification = try await TaskClassifier.shared.classify(query)
            let decision = ModelRouter.shared.route(classification: classification)
            if let provider = ProviderRegistry.shared.getProvider(id: decision.model.provider) {
                return (provider, decision.model.id, classification.taskType)
            }
        } catch {
            providerLogger.debug("Orchestrator fallback: \(error.localizedDescription)")
        }
        #else
        _ = query
        #endif
        let (provider, model) = try getDefaultProviderAndModel()
        return (provider, model, nil)
    }

    /// Fallback: get default provider and model (original behavior)
    func getDefaultProviderAndModel() throws -> (AIProvider, String) {
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw ChatError.providerNotAvailable
        }
        let model = AppConfiguration.shared.providerConfig.defaultModel
        return (provider, model)
    }

    // MARK: - Plan Mode Integration

    /// Detect whether a user message during plan execution is modifying the plan.
    /// Uses keyword heuristics; will be upgraded to AI-based detection.
    func detectPlanModificationIntent(_ text: String) -> Bool {
        let lower = text.lowercased()
        let modifiers = [
            "also ", "additionally ", "add ", "don't forget ",
            "skip ", "remove ", "change ", "update ",
            "instead ", "actually ", "wait ", "hold on",
            "before that", "after that", "and also"
        ]
        return modifiers.contains { lower.contains($0) }
    }
}
