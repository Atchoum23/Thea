import Foundation
#if os(macOS)
import MLXLMCommon
#endif

// MARK: - Local Model Instances

protocol LocalModelInstance: Sendable {
    var model: LocalModel { get }

    func generate(prompt: String, maxTokens: Int) async throws -> AsyncThrowingStream<String, Error>
}

struct OllamaModelInstance: LocalModelInstance {
    let model: LocalModel
    let ollamaBaseURL: String

    init(model: LocalModel) {
        self.model = model
        // Capture config value at init time for Sendable compliance
        ollamaBaseURL = LocalModelConfiguration().ollamaBaseURL
    }

    func generate(prompt: String, maxTokens _: Int) async throws -> AsyncThrowingStream<String, Error> {
        let generateURL = ollamaBaseURL + "/api/generate"
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: generateURL) else {
                        throw LocalModelError.notImplemented
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "model": model.name,
                        "prompt": prompt,
                        "stream": true
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, _) = try await URLSession.shared.bytes(for: request)

                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let response = json["response"] as? String
                        {
                            continuation.yield(response)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Chat with proper message format using Ollama's /api/chat endpoint.
    /// This ensures the model receives properly formatted chat templates.
    func chat(messages: [AIMessage]) async throws -> AsyncThrowingStream<String, Error> {
        let chatURL = ollamaBaseURL + "/api/chat"
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: chatURL) else {
                        throw LocalModelError.notImplemented
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let formattedMessages = messages.map { msg -> [String: String] in
                        ["role": msg.role.rawValue, "content": msg.content.textValue]
                    }

                    let body: [String: Any] = [
                        "model": model.name,
                        "messages": formattedMessages,
                        "stream": true
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, _) = try await URLSession.shared.bytes(for: request)

                    for try await line in bytes.lines {
                        if let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? [String: Any],
                           let content = message["content"] as? String
                        {
                            continuation.yield(content)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

struct MLXModelInstance: LocalModelInstance {
    let model: LocalModel

    func generate(prompt: String, maxTokens: Int) async throws -> AsyncThrowingStream<String, Error> {
        #if os(macOS)
        // Use native MLX Swift inference engine (macOS 26 best practice)
        // This uses unified memory and Metal acceleration for optimal performance
        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    let engine = MLXInferenceEngine.shared

                    // Load model if not already loaded
                    if !engine.isModelLoaded(model.path.path) {
                        _ = try await engine.loadLocalModel(path: model.path)
                    }

                    // Generate with streaming using GenerateParameters
                    // Parameter order: maxTokens first, then temperature, topP
                    let params = GenerateParameters(
                        maxTokens: maxTokens,
                        temperature: 0.7,
                        topP: 0.9
                    )

                    let stream = try await engine.generate(prompt: prompt, parameters: params)

                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        #else
        // iOS: MLX requires macOS - not available on iOS
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: LocalModelError.notImplemented)
        }
        #endif
    }
}

struct GGUFModelInstance: LocalModelInstance {
    let model: LocalModel

    func generate(prompt _: String, maxTokens _: Int) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // GGUF requires llama.cpp or similar runtime
                continuation.finish(throwing: LocalModelError.notImplemented)
            }
        }
    }
}

// MARK: - Models

struct LocalModel: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let path: URL
    let type: LocalModelType
    let format: String
    let sizeInBytes: Int?
    let runtime: ModelRuntime
    let size: Int64
    let parameters: String
    let quantization: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LocalModel, rhs: LocalModel) -> Bool {
        lhs.id == rhs.id
    }
}

enum LocalModelType: String, Codable {
    case ollama = "Ollama"
    case mlx = "MLX"
    case gguf = "GGUF"
    case coreML = "Core ML"
    case unknown = "Unknown"
}

enum ModelRuntime: String, Codable {
    case ollama = "Ollama"
    case mlx = "MLX"
    case gguf = "GGUF"
}

// MARK: - Errors

enum LocalModelError: LocalizedError {
    case runtimeNotInstalled(String)
    case modelNotFound
    case installationFailed
    case notImplemented

    var errorDescription: String? {
        switch self {
        case let .runtimeNotInstalled(runtime):
            "\(runtime) is not installed"
        case .modelNotFound:
            "Model not found"
        case .installationFailed:
            "Model installation failed"
        case .notImplemented:
            "Feature not yet implemented"
        }
    }
}

// MARK: - Chat Template Helpers

extension LocalModelProvider {
    /// Build a chat prompt using model-family-aware templates.
    /// Different model families (Llama, Mistral, Qwen, etc.) expect different chat formats.
    static func buildChatPrompt(messages: [AIMessage], modelName: String) -> String {
        let name = modelName.lowercased()

        if name.contains("llama") || name.contains("codellama") {
            return buildLlamaPrompt(messages: messages)
        } else if name.contains("mistral") || name.contains("mixtral") {
            return buildMistralPrompt(messages: messages)
        } else if name.contains("qwen") {
            return buildQwenPrompt(messages: messages)
        } else if name.contains("deepseek") {
            return buildDeepSeekPrompt(messages: messages)
        } else if name.contains("phi") {
            return buildPhiPrompt(messages: messages)
        } else if name.contains("gemma") {
            return buildGemmaPrompt(messages: messages)
        } else {
            return buildChatMLPrompt(messages: messages)
        }
    }

    static func buildLlamaPrompt(messages: [AIMessage]) -> String {
        var prompt = "<|begin_of_text|>"
        for msg in messages {
            let role = msg.role == .user ? "user" : (msg.role == .system ? "system" : "assistant")
            prompt += "<|start_header_id|>\(role)<|end_header_id|>\n\n\(msg.content.textValue)<|eot_id|>"
        }
        prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n"
        return prompt
    }

    static func buildMistralPrompt(messages: [AIMessage]) -> String {
        var prompt = "<s>"
        for msg in messages {
            if msg.role == .user {
                prompt += "[INST] \(msg.content.textValue) [/INST]"
            } else if msg.role == .assistant {
                prompt += " \(msg.content.textValue)</s>"
            }
        }
        return prompt
    }

    static func buildQwenPrompt(messages: [AIMessage]) -> String {
        buildChatMLPrompt(messages: messages)
    }

    static func buildDeepSeekPrompt(messages: [AIMessage]) -> String {
        buildChatMLPrompt(messages: messages)
    }

    static func buildPhiPrompt(messages: [AIMessage]) -> String {
        var prompt = ""
        for msg in messages {
            if msg.role == .user {
                prompt += "<|user|>\n\(msg.content.textValue)<|end|>\n"
            } else if msg.role == .assistant {
                prompt += "<|assistant|>\n\(msg.content.textValue)<|end|>\n"
            } else if msg.role == .system {
                prompt += "<|system|>\n\(msg.content.textValue)<|end|>\n"
            }
        }
        prompt += "<|assistant|>\n"
        return prompt
    }

    static func buildGemmaPrompt(messages: [AIMessage]) -> String {
        var prompt = ""
        for msg in messages {
            if msg.role == .user {
                prompt += "<start_of_turn>user\n\(msg.content.textValue)<end_of_turn>\n"
            } else if msg.role == .assistant {
                prompt += "<start_of_turn>model\n\(msg.content.textValue)<end_of_turn>\n"
            }
        }
        prompt += "<start_of_turn>model\n"
        return prompt
    }

    static func buildChatMLPrompt(messages: [AIMessage]) -> String {
        var prompt = ""
        for msg in messages {
            let role = msg.role == .user ? "user" : (msg.role == .system ? "system" : "assistant")
            prompt += "<|im_start|>\(role)\n\(msg.content.textValue)<|im_end|>\n"
        }
        prompt += "<|im_start|>assistant\n"
        return prompt
    }
}
