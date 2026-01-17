import Foundation
import OpenAI

final class OpenAIProvider: AIProvider, Sendable {
    let metadata = ProviderMetadata(
        name: "openai",
        displayName: "OpenAI",
        logoURL: URL(string: "https://openai.com/favicon.ico"),
        websiteURL: URL(string: "https://openai.com")!,
        documentationURL: URL(string: "https://platform.openai.com/docs")!
    )

    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsVision: true,
        supportsFunctionCalling: true,
        supportsWebSearch: false,
        maxContextTokens: 128000,
        maxOutputTokens: 16384,
        supportedModalities: [.text, .image]
    )

    private let client: OpenAI

    init(apiKey: String) {
        self.client = OpenAI(apiToken: apiKey)
    }

    // MARK: - Validation

    func validateAPIKey(_ key: String) async throws -> ValidationResult {
        let testClient = OpenAI(apiToken: key)

        do {
            // Test with models list endpoint
            _ = try await testClient.models()
            return .success()
        } catch {
            return .failure("Invalid API key: \(error.localizedDescription)")
        }
    }

    // MARK: - Chat

    func chat(
        messages: [AIMessage],
        model: String,
        stream: Bool
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        let openAIMessages = messages.map { msg in
            ChatQuery.ChatCompletionMessageParam(
                role: convertRole(msg.role),
                content: msg.content.textValue
            )!
        }

        let query = ChatQuery(
            messages: openAIMessages,
            model: model
        )

        if stream {
            return AsyncThrowingStream { continuation in
                Task { @Sendable in
                    do {
                        let stream: AsyncThrowingStream<ChatStreamResult, Error> = client.chatsStream(query: query)
                        var accumulatedText = ""

                        for try await result in stream {
                            if let delta = result.choices.first?.delta.content {
                                accumulatedText += delta
                                continuation.yield(.delta(delta))
                            }
                        }

                        // Final message
                        let finalMessage = AIMessage(
                            id: UUID(),
                            conversationID: messages.first?.conversationID ?? UUID(),
                            role: .assistant,
                            content: .text(accumulatedText),
                            timestamp: Date(),
                            model: model,
                            tokenCount: nil // OpenAI doesn't provide token count in stream
                        )
                        continuation.yield(.complete(finalMessage))
                        continuation.finish()

                    } catch {
                        continuation.yield(.error(error))
                        continuation.finish(throwing: error)
                    }
                }
            }
        } else {
            // Non-streaming
            let result = try await client.chats(query: query)

            guard let choice = result.choices.first,
                  let content = choice.message.content else {
                throw OpenAIError.noResponse
            }

            let finalMessage = AIMessage(
                id: UUID(),
                conversationID: messages.first?.conversationID ?? UUID(),
                role: .assistant,
                content: .text(content),
                timestamp: Date(),
                model: model,
                tokenCount: result.usage?.totalTokens
            )

            return AsyncThrowingStream { continuation in
                continuation.yield(.complete(finalMessage))
                continuation.finish()
            }
        }
    }

    // MARK: - Models

    func listModels() async throws -> [AIModel] {
        // OpenAI doesn't provide pricing/context info via API
        // Return hardcoded list of common models
        return [
            AIModel(
                id: "gpt-4o",
                name: "GPT-4o",
                description: "Most capable GPT-4 model with vision",
                contextWindow: 128000,
                maxOutputTokens: 16384,
                inputPricePerMillion: 2.50,
                outputPricePerMillion: 10.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            AIModel(
                id: "gpt-4-turbo",
                name: "GPT-4 Turbo",
                description: "Fast and capable GPT-4",
                contextWindow: 128000,
                maxOutputTokens: 4096,
                inputPricePerMillion: 10.00,
                outputPricePerMillion: 30.00,
                supportsVision: true,
                supportsFunctionCalling: true
            ),
            AIModel(
                id: "gpt-3.5-turbo",
                name: "GPT-3.5 Turbo",
                description: "Fast and cost-effective",
                contextWindow: 16385,
                maxOutputTokens: 4096,
                inputPricePerMillion: 0.50,
                outputPricePerMillion: 1.50,
                supportsVision: false,
                supportsFunctionCalling: true
            ),
            AIModel(
                id: "o1",
                name: "o1",
                description: "Reasoning model",
                contextWindow: 128000,
                maxOutputTokens: 32768,
                inputPricePerMillion: 15.00,
                outputPricePerMillion: 60.00,
                supportsVision: false,
                supportsFunctionCalling: false
            ),
        ]
    }

    // MARK: - Helpers

    private func convertRole(_ role: MessageRole) -> ChatQuery.ChatCompletionMessageParam.Role {
        switch role {
        case .user:
            return .user
        case .assistant:
            return .assistant
        case .system:
            return .system
        }
    }
}

// MARK: - Errors

enum OpenAIError: Error, LocalizedError {
    case noResponse

    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response from OpenAI"
        }
    }
}
