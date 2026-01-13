import Foundation

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

    private init() {
        loadCustomPaths()
        Task {
            await detectRuntimes()
            await discoverModels()
        }
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
           let paths = try? JSONDecoder().decode([URL].self, from: data) {
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

        if isMLXInstalled {
            await discoverMLXModels()
        }

        // Discover GGUF models in standard locations
        await discoverGGUFModels()
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
                        path: URL(fileURLWithPath: "/tmp/ollama/\(modelName)"),
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
        // MLX models are typically in ~/mlx-models
        let mlxPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(config.mlxModelsDirectory)

        guard FileManager.default.fileExists(atPath: mlxPath.path) else { return }

        do {
            let models = try FileManager.default.contentsOfDirectory(at: mlxPath, includingPropertiesForKeys: [.isDirectoryKey])

            for modelDir in models {
                let modelName = modelDir.lastPathComponent

                let model = LocalModel(
                    id: UUID(),
                    name: modelName,
                    path: modelDir,
                    type: .mlx,
                    format: "MLX",
                    sizeInBytes: nil,
                    runtime: .mlx,
                    size: 0,
                    parameters: config.defaultParameters,
                    quantization: "4bit"
                )

                availableModels.append(model)
            }
        } catch {
            print("Failed to discover MLX models: \(error)")
        }
        #else
        // iOS: MLX requires macOS - not available on iOS
        #endif
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

        let instance: LocalModelInstance

        switch model.runtime {
        case .ollama:
            instance = try await loadOllamaModel(model)
        case .mlx:
            instance = try await loadMLXModel(model)
        case .gguf:
            instance = try await loadGGUFModel(model)
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
    let ollamaURL: String

    init(model: LocalModel) {
        self.model = model
        // Capture config value at init time for Sendable compliance
        self.ollamaURL = LocalModelConfiguration().ollamaBaseURL + LocalModelConfiguration().ollamaAPIEndpoint
    }

    func generate(prompt: String, maxTokens: Int) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Call Ollama API
                    guard let url = URL(string: ollamaURL) else {
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
                           let response = json["response"] as? String {
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
}

struct MLXModelInstance: LocalModelInstance {
    let model: LocalModel
    let mlxPath: String

    init(model: LocalModel) {
        self.model = model
        // Capture config value at init time for Sendable compliance
        self.mlxPath = LocalModelConfiguration().mlxExecutablePath
    }

    func generate(prompt: String, maxTokens: Int) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    #if os(macOS)
                    // Call MLX generation
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: mlxPath)
                    process.arguments = [
                        "generate",
                        "--model", model.name,
                        "--prompt", prompt,
                        "--max-tokens", String(maxTokens)
                    ]

                    let pipe = Pipe()
                    process.standardOutput = pipe

                    try process.run()

                    for try await line in pipe.fileHandleForReading.bytes.lines {
                        continuation.yield(line)
                    }

                    process.waitUntilExit()
                    continuation.finish()
                    #else
                    // iOS: MLX requires macOS - not available on iOS
                    throw LocalModelError.notImplemented
                    #endif

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

struct GGUFModelInstance: LocalModelInstance {
    let model: LocalModel

    func generate(prompt: String, maxTokens: Int) async throws -> AsyncThrowingStream<String, Error> {
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

    func validateAPIKey(_ key: String) async throws -> ValidationResult {
        // Local models don't need API keys
        return .success()
    }

    func listModels() async throws -> [AIModel] {
        [AIModel(
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
        stream: Bool = false
    ) async throws -> AsyncThrowingStream<ChatResponse, Error> {
        // Convert messages to prompt
        let prompt = messages.map { message in
            "\(message.role.rawValue.capitalized): \(message.content.textValue)"
        }.joined(separator: "\n\n")

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = try await instance.generate(prompt: prompt, maxTokens: 2048)

                    var fullText = ""
                    for try await text in stream {
                        fullText += text
                        continuation.yield(.delta(text))
                    }

                    // Send complete message
                    let completeMessage = AIMessage(
                        id: UUID(),
                        conversationID: messages.first?.conversationID ?? UUID(),
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
        case .runtimeNotInstalled(let runtime):
            return "\(runtime) is not installed"
        case .modelNotFound:
            return "Model not found"
        case .installationFailed:
            return "Model installation failed"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}
