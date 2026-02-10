import Foundation
#if os(macOS)
import MLXLMCommon
#endif

// MARK: - Local Model Support

// Run AI models locally using Ollama, MLX, or GGUF

@MainActor
@Observable
final class LocalModelManager {
    static let shared = LocalModelManager()

    private(set) var availableModels: [LocalModel] = []
    private(set) var runningModels: [String: LocalModelInstance] = [:]
    private(set) var isOllamaInstalled = false
    private(set) var isMLXInstalled = false
    private(set) var customModelPaths: [URL] = []

    // Configuration accessor
    private var config: LocalModelConfiguration {
        AppConfiguration.shared.localModelConfig
    }

    private var discoveryTask: Task<Void, Never>?
    private(set) var isDiscoveryComplete = false

    private init() {
        loadCustomPaths()
        discoveryTask = Task {
            await detectRuntimes()
            await discoverModels()
            isDiscoveryComplete = true
        }
    }

    /// Wait for initial model discovery to complete
    func waitForDiscovery() async {
        await discoveryTask?.value
    }

    // MARK: - Custom Paths Management

    func addCustomModelPath(_ path: URL) {
        guard !customModelPaths.contains(path) else { return }
        customModelPaths.append(path)
        saveCustomPaths()
        Task {
            await discoverModels()
        }
    }

    func removeCustomModelPath(_ path: URL) {
        customModelPaths.removeAll { $0 == path }
        saveCustomPaths()
        Task {
            await discoverModels()
        }
    }

    private func loadCustomPaths() {
        if let data = UserDefaults.standard.data(forKey: "LocalModelManager.customPaths"),
           let paths = try? JSONDecoder().decode([URL].self, from: data)
        {
            customModelPaths = paths
        } else {
            // Default to SharedLLMs from configuration
            #if os(macOS)
                let sharedLLMs = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(config.sharedLLMsDirectory)
                if FileManager.default.fileExists(atPath: sharedLLMs.path) {
                    customModelPaths = [sharedLLMs]
                }
            #else
                // iOS: Use app's documents directory for local models
                if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let modelsPath = documentsPath.appendingPathComponent("LocalModels")
                    if FileManager.default.fileExists(atPath: modelsPath.path) {
                        customModelPaths = [modelsPath]
                    }
                }
            #endif
        }
    }

    private func saveCustomPaths() {
        if let data = try? JSONEncoder().encode(customModelPaths) {
            UserDefaults.standard.set(data, forKey: "LocalModelManager.customPaths")
        }
    }

    // MARK: - Runtime Detection

    private func detectRuntimes() async {
        isOllamaInstalled = await checkOllamaInstallation()
        isMLXInstalled = await checkMLXInstallation()
    }

    private func checkOllamaInstallation() async -> Bool {
        #if os(macOS)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: config.whichExecutablePath)
            process.arguments = ["ollama"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                return process.terminationStatus == 0
            } catch {
                return false
            }
        #else
            // iOS: Ollama requires macOS - not available on iOS
            return false
        #endif
    }

    private func checkMLXInstallation() async -> Bool {
        #if os(macOS)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: config.whichExecutablePath)
            process.arguments = ["mlx"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                return process.terminationStatus == 0
            } catch {
                return false
            }
        #else
            // iOS: MLX requires macOS - not available on iOS
            return false
        #endif
    }

    // MARK: - Model Discovery

    func discoverModels() async {
        availableModels.removeAll()

        if isOllamaInstalled {
            await discoverOllamaModels()
        }

        // Always discover MLX models from SharedLLMs (don't require mlx CLI)
        await discoverMLXModels()

        // Discover GGUF models in standard locations
        await discoverGGUFModels()

        print("📊 LocalModelManager discovered \(availableModels.count) models")
    }

    private func discoverOllamaModels() async {
        #if os(macOS)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: config.ollamaExecutablePath)
            process.arguments = ["list"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                // Parse ollama list output
                for line in output.split(separator: "\n").dropFirst() {
                    let parts = line.split(separator: "\t").map(String.init)
                    if let modelName = parts.first {
                        let model = LocalModel(
                            id: UUID(),
                            name: modelName,
                            path: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ollama/\(modelName)"),
                            type: .ollama,
                            format: "GGUF",
                            sizeInBytes: nil,
                            runtime: .ollama,
                            size: 0,
                            parameters: config.defaultParameters,
                            quantization: config.defaultQuantization
                        )

                        availableModels.append(model)
                    }
                }
            } catch {
                print("Failed to discover Ollama models: \(error)")
            }
        #else
            // iOS: Ollama requires macOS - not available on iOS
        #endif
    }

    private func discoverMLXModels() async {
        #if os(macOS)
            let home = FileManager.default.homeDirectoryForCurrentUser

            // HuggingFace cache: check HF_HOME env, then standard default
            let hfHome = ProcessInfo.processInfo.environment["HF_HOME"]
                .map { URL(fileURLWithPath: $0) }
                ?? home.appendingPathComponent(".cache/huggingface")

            // Check multiple locations for MLX models
            // The scanner expects a "hub" subdirectory with HF Hub structure (models--org--name/snapshots/hash/)
            let mlxPaths = [
                // Standard HuggingFace cache (contains hub/ with models--org--name/ dirs)
                hfHome,
                // SharedLLMs models-mlx (primary location with HuggingFace Hub structure)
                home.appendingPathComponent(config.sharedLLMsDirectory)
                    .appendingPathComponent("models-mlx"),
                // Legacy mlx-models directory
                home.appendingPathComponent(config.mlxModelsDirectory)
            ]

            print("🔍 Searching for MLX models in paths:")
            for path in mlxPaths {
                print("  📁 \(path.path) - exists: \(FileManager.default.fileExists(atPath: path.path))")
            }

            for mlxPath in mlxPaths {
                guard FileManager.default.fileExists(atPath: mlxPath.path) else {
                    print("⚠️ Path does not exist: \(mlxPath.path)")
                    continue
                }
                print("✅ Scanning path: \(mlxPath.path)")

                do {
                    // Handle HuggingFace Hub structure: models-mlx/hub/models--org--name/snapshots/hash/
                    let hubPath = mlxPath.appendingPathComponent("hub")
                    if FileManager.default.fileExists(atPath: hubPath.path) {
                        let modelDirs = try FileManager.default.contentsOfDirectory(at: hubPath, includingPropertiesForKeys: [.isDirectoryKey])

                        for modelDir in modelDirs {
                            // Skip hidden files
                            guard !modelDir.lastPathComponent.hasPrefix(".") else { continue }

                            // Find the snapshot directory
                            let snapshotsPath = modelDir.appendingPathComponent("snapshots")
                            guard FileManager.default.fileExists(atPath: snapshotsPath.path) else { continue }

                            let snapshots = try FileManager.default.contentsOfDirectory(at: snapshotsPath, includingPropertiesForKeys: [.isDirectoryKey])

                            // Use the first (typically only) snapshot
                            guard let snapshotDir = snapshots.first else { continue }

                            // Verify it's a valid MLX model directory
                            let configPath = snapshotDir.appendingPathComponent("config.json")
                            guard FileManager.default.fileExists(atPath: configPath.path) else { continue }

                            // Check for weights file
                            let hasWeights = FileManager.default.fileExists(atPath: snapshotDir.appendingPathComponent("weights.safetensors").path) ||
                                FileManager.default.fileExists(atPath: snapshotDir.appendingPathComponent("model.safetensors").path) ||
                                FileManager.default.fileExists(atPath: snapshotDir.appendingPathComponent("tokenizer.json").path)

                            guard hasWeights else { continue }

                            // Extract friendly name from "models--mlx-community--ModelName-8bit"
                            let dirName = modelDir.lastPathComponent
                            let modelName = extractModelName(from: dirName)

                            // Calculate directory size
                            let size = calculateDirectorySize(snapshotDir)

                            let model = LocalModel(
                                id: UUID(),
                                name: modelName,
                                path: snapshotDir,
                                type: .mlx,
                                format: "MLX",
                                sizeInBytes: Int(size),
                                runtime: .mlx,
                                size: size,
                                parameters: extractParameters(from: modelName),
                                quantization: extractQuantization(from: modelName)
                            )

                            availableModels.append(model)
                            print("✅ Discovered MLX model: \(modelName)")
                        }
                    }

                    // Also check for direct model directories (non-Hub structure)
                    let directModels = try FileManager.default.contentsOfDirectory(at: mlxPath, includingPropertiesForKeys: [.isDirectoryKey])
                    for modelDir in directModels {
                        guard !modelDir.lastPathComponent.hasPrefix("."),
                              modelDir.lastPathComponent != "hub" else { continue }

                        let configPath = modelDir.appendingPathComponent("config.json")
                        guard FileManager.default.fileExists(atPath: configPath.path) else { continue }

                        let modelName = modelDir.lastPathComponent
                        let size = calculateDirectorySize(modelDir)

                        let model = LocalModel(
                            id: UUID(),
                            name: modelName,
                            path: modelDir,
                            type: .mlx,
                            format: "MLX",
                            sizeInBytes: Int(size),
                            runtime: .mlx,
                            size: size,
                            parameters: extractParameters(from: modelName),
                            quantization: extractQuantization(from: modelName)
                        )

                        availableModels.append(model)
                        print("✅ Discovered MLX model: \(modelName)")
                    }
                } catch {
                    print("Failed to discover MLX models in \(mlxPath.path): \(error)")
                }
            }
        #else
            // iOS: MLX requires macOS - not available on iOS
        #endif
    }

    /// Extract friendly model name from HuggingFace Hub directory name
    private func extractModelName(from dirName: String) -> String {
        // "models--mlx-community--Qwen2.5-72B-Instruct-8bit" -> "Qwen2.5-72B-Instruct-8bit"
        let parts = dirName.split(separator: "--")
        if parts.count >= 3 {
            return String(parts.dropFirst(2).joined(separator: "--"))
        }
        return dirName
    }

    /// Extract parameter size from model name (e.g., "7B", "70B")
    private func extractParameters(from name: String) -> String {
        let patterns = ["(\\d+\\.?\\d*)B", "(\\d+)b"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
               let range = Range(match.range(at: 1), in: name)
            {
                return String(name[range]) + "B"
            }
        }
        return config.defaultParameters
    }

    /// Extract quantization from model name (e.g., "4bit", "8bit", "bf16")
    private func extractQuantization(from name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("4bit") || lowercased.contains("4-bit") || lowercased.contains("q4") {
            return "4bit"
        }
        if lowercased.contains("8bit") || lowercased.contains("8-bit") || lowercased.contains("q8") {
            return "8bit"
        }
        if lowercased.contains("bf16") || lowercased.contains("bfloat16") {
            return "bf16"
        }
        if lowercased.contains("fp16") || lowercased.contains("float16") {
            return "fp16"
        }
        if lowercased.contains("fp32") || lowercased.contains("float32") {
            return "fp32"
        }
        return config.defaultQuantization
    }

    /// Calculate total size of a directory
    private func calculateDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    private func discoverGGUFModels() async {
        // Check custom paths first, then common GGUF locations
        var ggufPaths = customModelPaths

        #if os(macOS)
            ggufPaths.append(contentsOf: [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(config.ggufModelsDirectory),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(config.lmStudioCachePath)
            ])
        #endif

        for path in ggufPaths {
            guard FileManager.default.fileExists(atPath: path.path) else { continue }

            do {
                let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: [.fileSizeKey])

                while let fileURL = enumerator?.nextObject() as? URL {
                    if fileURL.pathExtension.lowercased() == "gguf" {
                        let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0

                        let model = LocalModel(
                            id: UUID(),
                            name: fileURL.deletingPathExtension().lastPathComponent,
                            path: fileURL,
                            type: .gguf,
                            format: "GGUF",
                            sizeInBytes: size,
                            runtime: .gguf,
                            size: Int64(size),
                            parameters: config.defaultParameters,
                            quantization: config.defaultQuantization
                        )

                        availableModels.append(model)
                    }
                }
            } catch {
                print("Failed to discover GGUF models: \(error)")
            }
        }
    }

    // MARK: - Model Loading

    func loadModel(_ model: LocalModel) async throws -> LocalModelInstance {
        // Check if already loaded
        if let instance = runningModels[model.name] {
            return instance
        }

        let instance: LocalModelInstance = switch model.runtime {
        case .ollama:
            try await loadOllamaModel(model)
        case .mlx:
            try await loadMLXModel(model)
        case .gguf:
            try await loadGGUFModel(model)
        }

        runningModels[model.name] = instance

        return instance
    }

    private func loadOllamaModel(_ model: LocalModel) async throws -> LocalModelInstance {
        // Ollama models are loaded on-demand
        OllamaModelInstance(model: model)
    }

    private func loadMLXModel(_ model: LocalModel) async throws -> LocalModelInstance {
        MLXModelInstance(model: model)
    }

    private func loadGGUFModel(_ model: LocalModel) async throws -> LocalModelInstance {
        GGUFModelInstance(model: model)
    }

    func unloadModel(_ modelName: String) {
        runningModels.removeValue(forKey: modelName)
    }

    // MARK: - Model Installation

    func installOllamaModel(_ modelName: String) async throws {
        guard isOllamaInstalled else {
            throw LocalModelError.runtimeNotInstalled("Ollama")
        }

        #if os(macOS)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: config.ollamaExecutablePath)
            process.arguments = ["pull", modelName]

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw LocalModelError.installationFailed
            }

            // Refresh model list
            await discoverModels()
        #else
            // iOS: Ollama requires macOS - not available on iOS
            throw LocalModelError.runtimeNotInstalled("Ollama")
        #endif
    }

    func downloadGGUFModel(from url: URL, name: String) async throws {
        #if os(macOS)
            let destinationPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(config.ggufModelsDirectory)
                .appendingPathComponent("\(name).gguf")

            // Create directory if needed
            try FileManager.default.createDirectory(
                at: destinationPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Download file
            let (localURL, _) = try await URLSession.shared.download(from: url)
            try FileManager.default.moveItem(at: localURL, to: destinationPath)

            // Refresh model list
            await discoverModels()
        #else
            // iOS: Home directory access not available on iOS
            throw LocalModelError.notImplemented
        #endif
    }
}

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

// MARK: - Local Model Provider

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

    var capabilities: ProviderCapabilities {
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
        // Get the conversation ID for chat session management
        let conversationID = messages.first?.conversationID ?? UUID()

        // Get only the latest user message - ChatSession maintains history via KV cache
        guard let latestUserMessage = messages.last(where: { $0.role == .user }) else {
            throw LocalModelError.modelNotFound // No user message to respond to
        }

        let userText = latestUserMessage.content.textValue

        // Build history from all messages EXCEPT the current one
        // This is used when the ChatSession doesn't have KV cache (new session or app restart)
        let historyMessages = messages.dropLast().map { msg in
            (role: msg.role.rawValue, content: msg.content.textValue)
        }

        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    #if os(macOS)
                    // For MLX models, use ChatSession with proper chat templates
                    // This prevents hallucination issues from raw prompt formatting
                    if instance is MLXModelInstance {
                        let engine = MLXInferenceEngine.shared

                        // Ensure model is loaded
                        if !engine.isModelLoaded(self.instance.model.path.path) {
                            _ = try await engine.loadLocalModel(path: self.instance.model.path)
                        }

                        // Use default system prompt (TaskClassifier is not available)
                        let dynamicSystemPrompt = MLXInferenceEngine.systemPrompt(for: nil)

                        // Convert history to the format expected by MLXInferenceEngine
                        let history: [MLXInferenceEngine.ChatHistoryMessage] = historyMessages.map {
                            MLXInferenceEngine.ChatHistoryMessage(role: $0.role, content: $0.content)
                        }

                        // Use chat() which uses ChatSession for proper template handling
                        // Pass history for context when session is new (no KV cache)
                        // Pass dynamic system prompt based on task classification
                        let stream = try await engine.chat(
                            message: userText,
                            conversationID: conversationID,
                            history: history.isEmpty ? nil : history,
                            systemPrompt: dynamicSystemPrompt
                        )

                        var fullText = ""
                        for try await text in stream {
                            fullText += text
                            continuation.yield(.delta(text))
                        }

                        // Send complete message
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
                        return
                    }
                    #endif

                    // Fallback for non-MLX models (Ollama, GGUF)
                    // For Ollama: use /api/chat endpoint with proper message format
                    if let ollamaInstance = self.instance as? OllamaModelInstance {
                        let stream = try await ollamaInstance.chat(messages: messages)

                        var fullText = ""
                        for try await text in stream {
                            fullText += text
                            continuation.yield(.delta(text))
                        }

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
                        return
                    }

                    // Final fallback: raw prompt (GGUF or unknown instance type)
                    // Use model-family-aware chat templates for better results
                    let prompt = Self.buildChatPrompt(
                        messages: messages,
                        modelName: model
                    )

                    let stream = try await self.instance.generate(prompt: prompt, maxTokens: 2048)

                    var fullText = ""
                    for try await text in stream {
                        fullText += text
                        continuation.yield(.delta(text))
                    }

                    // Send complete message
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
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Chat Template Helpers

    /// Build a chat prompt using model-family-aware templates.
    /// Different model families (Llama, Mistral, Qwen, etc.) expect different chat formats.
    private static func buildChatPrompt(messages: [AIMessage], modelName: String) -> String {
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

    private static func buildLlamaPrompt(messages: [AIMessage]) -> String {
        var prompt = "<|begin_of_text|>"
        for msg in messages {
            let role = msg.role == .user ? "user" : (msg.role == .system ? "system" : "assistant")
            prompt += "<|start_header_id|>\(role)<|end_header_id|>\n\n\(msg.content.textValue)<|eot_id|>"
        }
        prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n"
        return prompt
    }

    private static func buildMistralPrompt(messages: [AIMessage]) -> String {
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

    private static func buildQwenPrompt(messages: [AIMessage]) -> String {
        buildChatMLPrompt(messages: messages)
    }

    private static func buildDeepSeekPrompt(messages: [AIMessage]) -> String {
        buildChatMLPrompt(messages: messages)
    }

    private static func buildPhiPrompt(messages: [AIMessage]) -> String {
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

    private static func buildGemmaPrompt(messages: [AIMessage]) -> String {
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

    private static func buildChatMLPrompt(messages: [AIMessage]) -> String {
        var prompt = ""
        for msg in messages {
            let role = msg.role == .user ? "user" : (msg.role == .system ? "system" : "assistant")
            prompt += "<|im_start|>\(role)\n\(msg.content.textValue)<|im_end|>\n"
        }
        prompt += "<|im_start|>assistant\n"
        return prompt
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
