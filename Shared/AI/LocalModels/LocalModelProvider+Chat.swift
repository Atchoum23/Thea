import Foundation
#if os(macOS)
import MLXLMCommon
#endif

// MARK: - LocalModelProvider Chat Implementation

extension LocalModelProvider {

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
                    #if os(macOS)
                    if self.instance is MLXModelInstance {
                        try await self.handleMLXChat(
                            userText: userText,
                            conversationID: conversationID,
                            historyMessages: historyMessages,
                            model: model,
                            continuation: continuation
                        )
                        return
                    }
                    #endif

                    if let ollamaInstance = self.instance as? OllamaModelInstance {
                        try await self.handleOllamaChat(
                            ollamaInstance: ollamaInstance,
                            messages: messages,
                            conversationID: conversationID,
                            model: model,
                            continuation: continuation
                        )
                        return
                    }

                    try await self.handleFallbackChat(
                        messages: messages,
                        conversationID: conversationID,
                        model: model,
                        continuation: continuation
                    )
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - MLX Chat Handler

    #if os(macOS)
    @MainActor
    private func handleMLXChat(
        userText: String,
        conversationID: UUID,
        historyMessages: [(role: String, content: String)],
        model: String,
        continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation
    ) async throws {
        let engine = MLXInferenceEngine.shared

        // Ensure model is loaded
        if !engine.isModelLoaded(self.instance.model.path.path) {
            _ = try await engine.loadLocalModel(path: self.instance.model.path)
        }

        let dynamicSystemPrompt = MLXInferenceEngine.systemPrompt(for: nil)

        let history: [MLXInferenceEngine.ChatHistoryMessage] = historyMessages.map {
            MLXInferenceEngine.ChatHistoryMessage(role: $0.role, content: $0.content)
        }

        let stream = try await engine.chat(
            message: userText,
            conversationID: conversationID,
            history: history.isEmpty ? nil : history,
            systemPrompt: dynamicSystemPrompt
        )

        let fullText = try await streamAndCollect(stream: stream, continuation: continuation)
        yieldCompleteMessage(fullText: fullText, conversationID: conversationID, model: model, continuation: continuation)
    }
    #endif

    // MARK: - Ollama Chat Handler

    @MainActor
    private func handleOllamaChat(
        ollamaInstance: OllamaModelInstance,
        messages: [AIMessage],
        conversationID: UUID,
        model: String,
        continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation
    ) async throws {
        let stream = try await ollamaInstance.chat(messages: messages)
        let fullText = try await streamAndCollect(stream: stream, continuation: continuation)
        yieldCompleteMessage(fullText: fullText, conversationID: conversationID, model: model, continuation: continuation)
    }

    // MARK: - Fallback Chat Handler (GGUF / unknown)

    @MainActor
    private func handleFallbackChat(
        messages: [AIMessage],
        conversationID: UUID,
        model: String,
        continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation
    ) async throws {
        let prompt = Self.buildChatPrompt(
            messages: messages,
            modelName: model
        )

        let stream = try await self.instance.generate(prompt: prompt, maxTokens: 2048)
        let fullText = try await streamAndCollect(stream: stream, continuation: continuation)
        yieldCompleteMessage(fullText: fullText, conversationID: conversationID, model: model, continuation: continuation)
    }

    // MARK: - Streaming Helpers

    /// Stream text chunks to a continuation, collecting the full text
    @MainActor
    private func streamAndCollect(
        stream: AsyncThrowingStream<String, Error>,
        continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation
    ) async throws -> String {
        var fullText = ""
        for try await text in stream {
            fullText += text
            continuation.yield(.delta(text))
        }
        return fullText
    }

    /// Yield a complete AIMessage and finish the continuation
    @MainActor
    private func yieldCompleteMessage(
        fullText: String,
        conversationID: UUID,
        model: String,
        continuation: AsyncThrowingStream<ChatResponse, Error>.Continuation
    ) {
        let completeMessage = AIMessage(
            id: UUID(),
            conversationID: conversationID,
            role: .assistant,
            content: .text(fullText),
            timestamp: Date(),
            model: model
        )
        continuation.yield(.complete(completeMessage))
        continuation.finish()
    }
}
