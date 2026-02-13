import Foundation
#if os(macOS)
import MLXLMCommon
#endif

// MARK: - Local Model Manager

// Run AI models locally using Ollama, MLX, or GGUF
// Discovery methods in LocalModelManager+Discovery.swift
// Runtime/loading/install methods in LocalModelManager+RuntimeSetup.swift

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
    var config: LocalModelConfiguration {
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
}

// MARK: - Local Model Provider

// Chat implementation in LocalModelProvider+Chat.swift

final class LocalModelProvider: AIProvider, @unchecked Sendable {
    let modelName: String
    let instance: LocalModelInstance

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
}
