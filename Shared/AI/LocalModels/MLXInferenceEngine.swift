import Foundation

#if os(macOS)
import MLX
import MLXNN
import MLXLLM
import MLXLMCommon

// MARK: - MLX Inference Engine
// Native Swift MLX inference following macOS 26 / WWDC25 best practices
// Uses mlx-swift-lm for optimal performance with unified memory and Metal acceleration

/// Manages MLX model loading and inference with KV cache support for multi-turn conversations
@MainActor
@Observable
final class MLXInferenceEngine {
    static let shared = MLXInferenceEngine()

    // MARK: - State

    /// Currently loaded model container
    private(set) var loadedModel: ModelContainer?

    /// Current model ID (HuggingFace format or local path)
    private(set) var loadedModelID: String?

    /// Loading state for UI feedback
    private(set) var isLoading = false

    /// Loading progress (0.0 - 1.0)
    private(set) var loadingProgress: Double = 0.0

    /// Last error encountered
    private(set) var lastError: Error?

    /// Active chat sessions with KV cache for multi-turn conversations (LRU eviction at maxCachedSessions)
    private var chatSessions: [UUID: ChatSession] = [:]

    /// Tracks session access order for LRU eviction
    private var sessionAccessOrder: [UUID] = []

    /// Maximum cached chat sessions before LRU eviction
    private let maxCachedSessions = 20

    /// Model factory for loading models
    private let modelFactory = LLMModelFactory.shared

    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        setupMemoryPressureHandler()
    }

    private func setupMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self, !self.isLoading else { return }
                print("⚠️ MLXInferenceEngine: Memory pressure detected, unloading model and clearing sessions")
                self.unloadModel()
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    // MARK: - Model Loading

    /// Load a model from HuggingFace Hub
    /// - Parameter modelID: HuggingFace model ID (e.g., "mlx-community/Qwen2.5-3B-4bit")
    /// - Returns: The loaded model container
    func loadModel(id modelID: String) async throws -> ModelContainer {
        // Return cached model if already loaded
        if loadedModelID == modelID, let model = loadedModel {
            return model
        }

        isLoading = true
        loadingProgress = 0.0
        lastError = nil

        defer {
            isLoading = false
        }

        do {
            let configuration = ModelConfiguration(id: modelID)

            // Load model with progress tracking
            let container = try await modelFactory.loadContainer(configuration: configuration) { progress in
                Task { @MainActor in
                    self.loadingProgress = progress.fractionCompleted
                }
            }

            // Cache the loaded model
            loadedModel = container
            loadedModelID = modelID

            // Clear any existing chat sessions when loading a new model
            chatSessions.removeAll()

            print("✅ MLXInferenceEngine: Loaded model \(modelID)")
            return container

        } catch {
            lastError = error
            print("❌ MLXInferenceEngine: Failed to load model \(modelID): \(error)")
            throw error
        }
    }

    /// Load a model from a local directory path (for models in SharedLLMs)
    /// Uses ModelConfiguration(directory:) for local paths per mlx-swift-lm best practices
    /// - Parameter path: Local file path to the model directory containing config.json
    func loadLocalModel(path: URL) async throws -> ModelContainer {
        // Return cached model if already loaded
        let modelID = path.path
        if loadedModelID == modelID, let model = loadedModel {
            return model
        }

        isLoading = true
        loadingProgress = 0.0
        lastError = nil

        defer {
            isLoading = false
        }

        do {
            // For local paths, use ModelConfiguration(directory:) instead of id:
            // This tells MLX to load from the local filesystem instead of HuggingFace Hub
            let configuration = ModelConfiguration(directory: path)

            print("🔄 MLXInferenceEngine: Loading local model from \(path.path)")

            // Load model with progress tracking
            let container = try await modelFactory.loadContainer(configuration: configuration) { progress in
                Task { @MainActor in
                    self.loadingProgress = progress.fractionCompleted
                }
            }

            // Cache the loaded model
            loadedModel = container
            loadedModelID = modelID

            // Clear any existing chat sessions when loading a new model
            chatSessions.removeAll()

            print("✅ MLXInferenceEngine: Loaded local model from \(path.lastPathComponent)")
            return container

        } catch {
            lastError = error
            print("❌ MLXInferenceEngine: Failed to load local model \(path.path): \(error)")
            throw error
        }
    }

    /// Unload the current model to free memory
    func unloadModel() {
        loadedModel = nil
        loadedModelID = nil
        chatSessions.removeAll()
        loadingProgress = 0.0
        print("📦 MLXInferenceEngine: Model unloaded")
    }

    // MARK: - Text Generation

    /// Generate text completion (single turn, no history)
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - parameters: Generation parameters (temperature, topP, maxTokens, etc.)
    /// - Returns: AsyncStream of generated tokens
    func generate(
        prompt: String,
        parameters: GenerateParameters = GenerateParameters()
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let model = loadedModel else {
            throw MLXInferenceError.noModelLoaded
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await model.perform { context in
                        let input = try await context.processor.prepare(
                            input: UserInput(prompt: prompt)
                        )

                        let tokenStream = try MLXLMCommon.generate(
                            input: input,
                            parameters: parameters,
                            context: context
                        )

                        for try await part in tokenStream {
                            if let chunk = part.chunk {
                                continuation.yield(chunk)
                            }
                        }

                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Chat Sessions with KV Cache

    /// Represents a message in chat history
    struct ChatHistoryMessage: Sendable {
        let role: String  // "user" or "assistant"
        let content: String
    }

    /// Default system prompt for chat sessions
    static let defaultSystemPrompt = """
    You are THEA, a helpful AI assistant. You provide accurate, helpful, and concise responses. \
    Be direct and focus on answering the user's question. If you don't know something, say so honestly.
    """

    /// Task-specific system prompts for optimal responses
    enum TaskSpecificPrompt {
        case general
        case code
        case math
        case creative
        case analysis
        case summarization
        case planning
        case factual

        var systemPrompt: String {
            switch self {
            case .general:
                return Self.basePrompt

            case .code:
                return """
                \(Self.basePrompt)

                CODE GENERATION GUIDELINES:
                - Write clean, well-documented, production-ready code
                - Follow language-specific best practices and conventions
                - Include error handling and edge cases
                - Use meaningful variable and function names
                - Add brief comments for complex logic only
                - Prefer modern syntax and patterns
                """

            case .math:
                return """
                \(Self.basePrompt)

                MATHEMATICAL REASONING GUIDELINES:
                - Show your work step-by-step
                - Clearly state any assumptions
                - Verify your answer when possible
                - Use proper mathematical notation
                - Explain the reasoning behind each step
                """

            case .creative:
                return """
                \(Self.basePrompt)

                CREATIVE WRITING GUIDELINES:
                - Be imaginative and engaging
                - Use vivid descriptions and varied sentence structures
                - Maintain consistent tone and style
                - Develop compelling characters and narratives
                - Balance creativity with the user's specific requests
                """

            case .analysis:
                return """
                \(Self.basePrompt)

                ANALYSIS GUIDELINES:
                - Examine the topic from multiple perspectives
                - Identify key factors and relationships
                - Support conclusions with evidence and reasoning
                - Consider potential counterarguments
                - Provide actionable insights when applicable
                """

            case .summarization:
                return """
                \(Self.basePrompt)

                SUMMARIZATION GUIDELINES:
                - Identify and prioritize the most important information
                - Maintain accuracy while being concise
                - Preserve the original meaning and intent
                - Organize information logically
                - Use bullet points for clarity when appropriate
                """

            case .planning:
                return """
                \(Self.basePrompt)

                PLANNING GUIDELINES:
                - Break down complex goals into actionable steps
                - Identify dependencies and prerequisites
                - Consider potential risks and mitigation strategies
                - Provide realistic timelines when relevant
                - Prioritize tasks by importance and urgency
                """

            case .factual:
                return """
                \(Self.basePrompt)

                FACTUAL RESPONSE GUIDELINES:
                - Provide accurate, verifiable information
                - Cite sources or knowledge limitations when appropriate
                - Distinguish between facts and opinions
                - Be concise and direct
                - Acknowledge uncertainty when present
                """
            }
        }

        private static let basePrompt = """
        You are THEA, a helpful AI assistant. You provide accurate, helpful, and concise responses. \
        Be direct and focus on answering the user's question. If you don't know something, say so honestly.
        """

        /// Map TaskType to TaskSpecificPrompt
        static func from(taskType: TaskType?) -> TaskSpecificPrompt {
            guard let taskType else { return .general }

            switch taskType {
            case .codeGeneration, .debugging:
                return .code
            case .mathLogic:
                return .math
            case .creativeWriting:
                return .creative
            case .analysis, .complexReasoning:
                return .analysis
            case .summarization:
                return .summarization
            case .planning:
                return .planning
            case .factual, .simpleQA:
                return .factual
            default:
                return .general
            }
        }
    }

    /// Get appropriate system prompt for a task type
    /// Uses user-configured prompts if available, falls back to built-in defaults
    static func systemPrompt(for taskType: TaskType?) -> String {
        // Try to use user-configured prompts first
        let userConfig = SystemPromptConfiguration.load()
        if userConfig.useDynamicPrompts {
            return userConfig.fullPrompt(for: taskType)
        }

        // Fall back to built-in prompts
        return TaskSpecificPrompt.from(taskType: taskType).systemPrompt
    }

    /// Create or get a chat session for multi-turn conversations
    /// The session maintains KV cache for efficient context handling
    /// - Parameters:
    ///   - conversationID: Unique identifier for the conversation
    ///   - systemPrompt: Optional custom system prompt (uses default if nil)
    func getChatSession(for conversationID: UUID, systemPrompt: String? = nil) async throws -> ChatSession {
        if let session = chatSessions[conversationID] {
            // Update LRU access order
            sessionAccessOrder.removeAll { $0 == conversationID }
            sessionAccessOrder.append(conversationID)
            return session
        }

        guard let model = loadedModel else {
            throw MLXInferenceError.noModelLoaded
        }

        // LRU eviction: remove least recently used session if at capacity
        if chatSessions.count >= maxCachedSessions, let oldest = sessionAccessOrder.first {
            chatSessions.removeValue(forKey: oldest)
            sessionAccessOrder.removeFirst()
            print("♻️ MLXInferenceEngine: Evicted LRU chat session")
        }

        // Create session with system instructions
        let instructions = systemPrompt ?? Self.defaultSystemPrompt
        let session = ChatSession(model, instructions: instructions)
        chatSessions[conversationID] = session
        sessionAccessOrder.append(conversationID)
        return session
    }

    /// Check if a chat session exists and has history
    func hasExistingSession(for conversationID: UUID) -> Bool {
        chatSessions[conversationID] != nil
    }

    /// Send a message in a chat session and get streaming response
    /// - Parameters:
    ///   - message: The user message
    ///   - conversationID: The conversation identifier
    ///   - history: Optional conversation history for context (used when session doesn't have KV cache)
    ///   - systemPrompt: Optional custom system prompt for new sessions
    /// - Returns: AsyncStream of response tokens
    func chat(
        message: String,
        conversationID: UUID,
        history: [ChatHistoryMessage]? = nil,
        systemPrompt: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        // Check if we have an existing session with KV cache
        let hasExisting = hasExistingSession(for: conversationID)
        let session = try await getChatSession(for: conversationID, systemPrompt: systemPrompt)

        // If this is a NEW session (no KV cache) and we have history,
        // format the history as context in the message
        // This ensures multi-turn conversations work even after app restart
        let effectiveMessage: String
        if !hasExisting, let history = history, !history.isEmpty {
            // Format history as context - the ChatSession will apply proper chat templates
            // We include a brief context summary rather than replaying (which would generate new responses)
            var contextParts: [String] = []
            contextParts.append("Previous conversation context:")
            for msg in history {
                let roleLabel = msg.role == "user" ? "User" : "Assistant"
                // Truncate very long messages for context
                let truncatedContent = msg.content.count > 500
                    ? String(msg.content.prefix(500)) + "..."
                    : msg.content
                contextParts.append("\(roleLabel): \(truncatedContent)")
            }
            contextParts.append("")
            contextParts.append("Current message:")
            contextParts.append(message)

            effectiveMessage = contextParts.joined(separator: "\n")
            print("📜 MLXInferenceEngine: Including \(history.count) historical messages as context")
        } else {
            effectiveMessage = message
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Use the ChatSession's streamResponse method for streaming output
                    // ChatSession maintains KV cache automatically for subsequent turns
                    let stream = session.streamResponse(to: effectiveMessage)

                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Clear the chat history for a conversation (resets KV cache)
    func clearChatSession(for conversationID: UUID) {
        chatSessions.removeValue(forKey: conversationID)
        sessionAccessOrder.removeAll { $0 == conversationID }
    }

    /// Clear all chat sessions
    func clearAllChatSessions() {
        chatSessions.removeAll()
        sessionAccessOrder.removeAll()
    }

    // MARK: - Model Information

    /// Get information about available MLX models in SharedLLMs
    func getAvailableModels() -> [LocalModel] {
        LocalModelManager.shared.availableModels.filter { $0.type == .mlx }
    }

    /// Check if a specific model is currently loaded
    func isModelLoaded(_ modelID: String) -> Bool {
        loadedModelID == modelID && loadedModel != nil
    }

    /// Get the current model's context window size
    var contextWindowSize: Int {
        // Default context window - would need model config inspection for accurate value
        8192
    }
}

// MARK: - Errors

enum MLXInferenceError: LocalizedError {
    case noModelLoaded
    case modelLoadFailed(String)
    case generationFailed(String)
    case invalidModelPath

    var errorDescription: String? {
        switch self {
        case .noModelLoaded:
            "No model is currently loaded. Call loadModel() first."
        case .modelLoadFailed(let reason):
            "Failed to load model: \(reason)"
        case .generationFailed(let reason):
            "Text generation failed: \(reason)"
        case .invalidModelPath:
            "Invalid model path"
        }
    }
}

// MARK: - Generation Parameters Extension

extension GenerateParameters {
    /// Create parameters optimized for chat/assistant use
    static var chat: GenerateParameters {
        GenerateParameters(
            maxTokens: 2048,
            temperature: 0.7,
            topP: 0.9
        )
    }

    /// Create parameters for deterministic/factual responses
    static var deterministic: GenerateParameters {
        GenerateParameters(
            maxTokens: 2048,
            temperature: 0.0
        )
    }

    /// Create parameters for creative/diverse responses
    static var creative: GenerateParameters {
        GenerateParameters(
            maxTokens: 4096,
            temperature: 1.0,
            topP: 0.95
        )
    }
}

#endif // os(macOS)
