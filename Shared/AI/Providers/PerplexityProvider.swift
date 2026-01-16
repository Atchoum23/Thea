import Foundation

final class PerplexityProvider: AIProvider, Sendable {
  let metadata = ProviderMetadata(
    name: "perplexity",
    displayName: "Perplexity",
    logoURL: URL(string: "https://www.perplexity.ai/favicon.ico"),
    websiteURL: URL(string: "https://www.perplexity.ai")!,
    documentationURL: URL(string: "https://docs.perplexity.ai")!
  )

  let capabilities = ProviderCapabilities(
    supportsStreaming: true,
    supportsVision: false,
    supportsFunctionCalling: false,
    supportsWebSearch: true,  // Perplexity's specialty!
    maxContextTokens: 127000,
    maxOutputTokens: 4096,
    supportedModalities: [.text]
  )

  private let apiKey: String
  private let baseURL = "https://api.perplexity.ai"

  init(apiKey: String) {
    self.apiKey = apiKey
  }

  // MARK: - Validation

  func validateAPIKey(_ key: String) async throws -> ValidationResult {
    guard let url = URL(string: "\(baseURL)/chat/completions") else {
      return .failure("Invalid API URL configuration")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Test with minimal request
    let testBody: [String: Any] = [
      "model": "llama-3.1-sonar-small-128k-online",
      "messages": [
        ["role": "user", "content": "Hi"]
      ],
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: testBody)

    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode == 200 {
          return .success()
        } else if httpResponse.statusCode == 401 {
          return .failure("Invalid API key")
        } else {
          return .failure("Unexpected status code: \(httpResponse.statusCode)")
        }
      }
      return .failure("Invalid response")
    } catch {
      return .failure("Network error: \(error.localizedDescription)")
    }
  }

  // MARK: - Chat

  func chat(
    messages: [AIMessage],
    model: String,
    stream: Bool
  ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
    let perplexityMessages = messages.map { msg in
      [
        "role": convertRole(msg.role),
        "content": msg.content.textValue,
      ]
    }

    let requestBody: [String: Any] = [
      "model": model,
      "messages": perplexityMessages,
      "stream": stream,
    ]

    guard let url = URL(string: "\(baseURL)/chat/completions") else {
      throw PerplexityError.invalidResponse
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    if stream {
      let requestCopy = request
      return AsyncThrowingStream { continuation in
        Task { @Sendable in
          do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: requestCopy)

            guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
            else {
              throw PerplexityError.invalidResponse
            }

            var accumulatedText = ""

            for try await line in asyncBytes.lines {
              if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))

                if jsonString == "[DONE]" {
                  let finalMessage = AIMessage(
                    id: UUID(),
                    conversationID: messages.first?.conversationID ?? UUID(),
                    role: .assistant,
                    content: .text(accumulatedText),
                    timestamp: Date(),
                    model: model
                  )
                  continuation.yield(.complete(finalMessage))
                  break
                }

                guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String
                else {
                  continue
                }

                accumulatedText += content
                continuation.yield(.delta(content))
              }
            }

            continuation.finish()
          } catch {
            continuation.yield(.error(error))
            continuation.finish(throwing: error)
          }
        }
      }
    } else {
      // Non-streaming
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse,
        httpResponse.statusCode == 200
      else {
        throw PerplexityError.invalidResponse
      }

      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let choices = json["choices"] as? [[String: Any]],
        let message = choices.first?["message"] as? [String: Any],
        let content = message["content"] as? String
      else {
        throw PerplexityError.noResponse
      }

      let finalMessage = AIMessage(
        id: UUID(),
        conversationID: messages.first?.conversationID ?? UUID(),
        role: .assistant,
        content: .text(content),
        timestamp: Date(),
        model: model
      )

      return AsyncThrowingStream { continuation in
        continuation.yield(.complete(finalMessage))
        continuation.finish()
      }
    }
  }

  // MARK: - Models

  func listModels() async throws -> [AIModel] {
    return [
      AIModel(
        id: "llama-3.1-sonar-large-128k-online",
        name: "Sonar Large (Online)",
        description: "Most capable with web search",
        contextWindow: 127000,
        maxOutputTokens: 4096,
        inputPricePerMillion: 1.00,
        outputPricePerMillion: 1.00,
        supportsVision: false,
        supportsFunctionCalling: false
      ),
      AIModel(
        id: "llama-3.1-sonar-small-128k-online",
        name: "Sonar Small (Online)",
        description: "Fast with web search",
        contextWindow: 127000,
        maxOutputTokens: 4096,
        inputPricePerMillion: 0.20,
        outputPricePerMillion: 0.20,
        supportsVision: false,
        supportsFunctionCalling: false
      ),
      AIModel(
        id: "llama-3.1-8b-instruct",
        name: "Llama 3.1 8B",
        description: "Fast open-source model (no search)",
        contextWindow: 127000,
        maxOutputTokens: 4096,
        inputPricePerMillion: 0.20,
        outputPricePerMillion: 0.20,
        supportsVision: false,
        supportsFunctionCalling: false
      ),
    ]
  }

  // MARK: - Helpers

  private func convertRole(_ role: MessageRole) -> String {
    switch role {
    case .user: return "user"
    case .assistant: return "assistant"
    case .system: return "system"
    }
  }
}

// MARK: - Errors

enum PerplexityError: Error, LocalizedError {
  case invalidResponse
  case noResponse

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "Invalid response from Perplexity"
    case .noResponse:
      return "No response from Perplexity"
    }
  }
}
