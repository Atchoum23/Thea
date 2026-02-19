import Foundation
#if os(macOS)
import MLXLMCommon
#endif

// MARK: - Local Model Provider

// @unchecked Sendable: modelName and instance are let constants set once at init and never mutated;
// LocalModelInstance manages MLX model lifecycle internally with actor-based isolation
final class LocalModelProvider: AIProvider, @unchecked Sendable {
    private let modelName: String
    private let instance: LocalModelInstance

    var metadata: ProviderMetadata {
        ProviderMetadata(
            name: "local",
            displayName: "Local Models",
            websiteURL: URL(string: "https://ollama.ai")!,
            documentationURL: URL(string: "https://ollama.ai/library")!
        )
    }

    // periphery:ignore - Reserved: capabilities property — reserved for future feature activation
    var capabilities: ProviderCapabilities {
        // periphery:ignore - Reserved: capabilities property reserved for future feature activation
        ProviderCapabilities(
            supportsStreaming: true,
            supportsVision: false,
            supportsFunctionCalling: false,
            supportsWebSearch: false,
            maxContextTokens: 4096,
            maxOutputTokens: 2048,
            supportedModalities: [.text]
        )
    }

    init(modelName: String, instance: LocalModelInstance) {
        self.modelName = modelName
        self.instance = instance
    }

    // periphery:ignore - Reserved: validateAPIKey(_:) instance method reserved for future feature activation
    func validateAPIKey(_: String) async throws -> ValidationResult {
        // Local models don't need API keys
        .success()
    }

    func listModels() async throws -> [ProviderAIModel] {
        [ProviderAIModel(
            id: modelName,
            name: modelName,
            description: "Local model",
            contextWindow: 4096,
            maxOutputTokens: 2048,
            inputPricePerMillion: 0,
            outputPricePerMillion: 0,
            supportsVision: false,
            supportsFunctionCalling: false
        )]
    }

    func chat(
        messages: [AIMessage],
        model: String,
        stream _: Bool = false
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let conversationID = messages.first?.conversationID ?? UUID()

        guard let latestUserMessage = messages.last(where: { $0.role == .user }) else {
            throw LocalModelError.modelNotFound
        }

        let userText = latestUserMessage.content.textValue
        let historyMessages = messages.dropLast().map { msg in
            (role: msg.role.rawValue, content: msg.content.textValue)
        }

        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let textStream = try await self.resolveTextStream(
                        userText: userText, conversationID: conversationID,
                        historyMessages: historyMessages, messages: messages, model: model
                    )
                    try await Self.consumeStream(
                        textStream, continuation: continuation,
                        conversationID: conversationID, model: model
                    )
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Resolve which text stream to use based on model instance type.
    @MainActor
    private func resolveTextStream(
        userText: String, conversationID: UUID,
        historyMessages: [(role: String, content: String)],
        messages: [AIMessage], model: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        #if os(macOS)
        if instance is MLXModelInstance {
            let engine = MLXInferenceEngine.shared
            if !engine.isModelLoaded(instance.model.path.path) {
                _ = try await engine.loadLocalModel(path: instance.model.path)
            }
            let dynamicSystemPrompt = MLXInferenceEngine.systemPrompt(for: nil)
            let history: [MLXInferenceEngine.ChatHistoryMessage] = historyMessages.map {
                MLXInferenceEngine.ChatHistoryMessage(role: $0.role, content: $0.content)
            }
            return try await engine.chat(
                message: userText, conversationID: conversationID,
                history: history.isEmpty ? nil : history, systemPrompt: dynamicSystemPrompt
            )
        }
        #endif

        if let ollamaInstance = instance as? OllamaModelInstance {
            return try await ollamaInstance.chat(messages: messages)
        }

        let prompt = Self.buildChatPrompt(messages: messages, modelName: model)
        return try await instance.generate(prompt: prompt, maxTokens: 2048)
    }

    /// Consume a text stream, yielding deltas and completing with a full message.
    private static func consumeStream(
        _ stream: AsyncThrowingStream<String, Error>,
        continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation,
        conversationID: UUID, model: String
    ) async throws {
        var fullText = ""
        for try await text in stream {
            fullText += text
            continuation.yield(.delta(text))
        }
        let completeMessage = AIMessage(
            id: UUID(), conversationID: conversationID,
            role: .assistant, content: .text(fullText),
            timestamp: Date(), model: model
        )
        continuation.yield(.complete(completeMessage))
        continuation.finish()
    }
}
