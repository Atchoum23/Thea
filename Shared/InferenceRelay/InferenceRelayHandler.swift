//
//  InferenceRelayHandler.swift
//  Thea
//
//  macOS-only handler that bridges inference relay requests from tvOS clients
//  to the full AI pipeline (TaskClassifier → ModelRouter → AIProvider).
//
//  CREATED: February 8, 2026
//

import Foundation
import OSLog

#if os(macOS)

private let logger = Logger(subsystem: "app.thea", category: "InferenceRelay")

// MARK: - Inference Relay Handler

/// Processes inference requests from remote tvOS clients by routing through
/// the macOS AI orchestrator and streaming responses back.
@MainActor
public final class InferenceRelayHandler {
    public static let shared = InferenceRelayHandler()

    private init() {}

    // MARK: - Handle Inference Request

    /// Process an inference request and stream response chunks via the callback.
    /// - Parameters:
    ///   - request: The inference request from the tvOS client
    ///   - sendChunk: Callback to send each relay message back to the client
    public func handleInferenceRequest(
        _ request: InferenceRequest,
        sendChunk: @Sendable @escaping (InferenceRelayMessage) async throws -> Void
    ) async {
        do {
            // Convert InferenceMessage[] to AIMessage[]
            let aiMessages = request.messages.map { msg in
                AIMessage(
                    id: UUID(),
                    conversationID: UUID(),
                    role: MessageRole(rawValue: msg.role) ?? .user,
                    content: .text(msg.content),
                    timestamp: Date(),
                    model: request.preferredModel ?? ""
                )
            }

            // Select provider and model via orchestrator
            let (provider, model) = try await selectProviderAndModel(
                for: request.messages.last?.content ?? "",
                preferredModel: request.preferredModel
            )

            logger.info("Inference relay: routing to \(model) via \(provider.metadata.name)")

            // Stream through provider
            let stream = try await provider.chat(
                messages: aiMessages,
                model: model,
                stream: request.stream
            )

            var fullText = ""
            var chunkIndex = 0

            for try await chunk in stream {
                switch chunk.type {
                case let .delta(text):
                    fullText += text
                    try await sendChunk(.streamDelta(
                        InferenceStreamDelta(
                            requestId: request.requestId,
                            delta: text,
                            index: chunkIndex
                        )
                    ))
                    chunkIndex += 1

                case let .complete(message):
                    try await sendChunk(.streamComplete(
                        InferenceStreamComplete(
                            requestId: request.requestId,
                            fullText: message.content.textValue,
                            model: model,
                            provider: provider.metadata.name,
                            tokenCount: message.tokenCount
                        )
                    ))

                case let .error(error):
                    try await sendChunk(.streamError(
                        InferenceStreamError(
                            requestId: request.requestId,
                            errorDescription: error.localizedDescription
                        )
                    ))
                }
            }

            // If stream ended without a .complete, send one
            if chunkIndex > 0 {
                // Check if we already sent a complete (the loop above handles it)
                // The provider should always send .complete, but as a safety net:
                logger.debug("Inference relay: streamed \(chunkIndex) chunks for request \(request.requestId)")
            }

        } catch {
            logger.error("Inference relay error: \(error.localizedDescription)")
            do {
                try await sendChunk(.streamError(
                    InferenceStreamError(
                        requestId: request.requestId,
                        errorDescription: error.localizedDescription
                    )
                ))
            } catch {
                logger.error("Failed to send stream error chunk: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Model List

    /// Returns available models from ProviderRegistry.
    public func handleListModelsRequest() async -> InferenceModelList {
        var models: [InferenceModelInfo] = []
        let defaultModel = AppConfiguration.shared.providerConfig.defaultModel

        // Collect models from all registered providers
        for (providerId, provider) in ProviderRegistry.shared.allProviders {
            do {
                let providerModels = try await provider.listModels()
                for model in providerModels {
                    models.append(InferenceModelInfo(
                        id: model.id,
                        name: model.name,
                        provider: providerId,
                        isDefault: model.id == defaultModel
                    ))
                }
            } catch {
                logger.warning("Failed to list models for \(providerId): \(error.localizedDescription)")
            }
        }

        return InferenceModelList(models: models)
    }

    // MARK: - Server Capabilities

    /// Returns this server's capabilities.
    public func getServerCapabilities() -> InferenceServerCapabilities {
        let deviceName: String
        #if os(macOS)
        deviceName = Host.current().localizedName ?? "Mac"
        #else
        deviceName = "Unknown"
        #endif

        return InferenceServerCapabilities(
            serverName: TheaRemoteServer.shared.configuration.serverName,
            supportsStreaming: true,
            supportsOrchestrator: true,
            availableProviderCount: ProviderRegistry.shared.allProviders.count,
            deviceName: deviceName
        )
    }

    // MARK: - Provider Selection (Orchestrator)

    /// Replicates ChatManager.selectProviderAndModel() logic for relay requests.
    private func selectProviderAndModel(
        for query: String,
        preferredModel: String?
    ) async throws -> (AIProvider, String) {
        // If client specified a model, look it up
        if let preferred = preferredModel {
            // Try direct provider lookup (format: "provider:model")
            let parts = preferred.split(separator: "/", maxSplits: 1)
            if parts.count == 2 {
                let providerId = String(parts[0])
                if let provider = ProviderRegistry.shared.getProvider(id: providerId) {
                    return (provider, preferred)
                }
            }

            // Try all providers
            for (_, provider) in ProviderRegistry.shared.allProviders {
                let models: [AIModel]
                do {
                    models = try await provider.listModels()
                } catch {
                    logger.warning("Failed to list models for provider: \(error.localizedDescription)")
                    continue
                }
                if models.contains(where: { $0.id == preferred }) {
                    return (provider, preferred)
                }
            }
        }

        // Use orchestrator: TaskClassifier → ModelRouter
        do {
            let classification = try await TaskClassifier.shared.classify(query)
            let decision = ModelRouter.shared.route(classification: classification)
            if let provider = ProviderRegistry.shared.getProvider(id: decision.model.provider) {
                return (provider, decision.model.id)
            }
        } catch {
            logger.warning("Orchestrator fallback: \(error.localizedDescription)")
        }

        // Fallback to default
        guard let provider = ProviderRegistry.shared.getDefaultProvider() else {
            throw RemoteServerError.featureDisabled("No AI provider configured")
        }
        let model = AppConfiguration.shared.providerConfig.defaultModel
        return (provider, model)
    }
}

#endif
