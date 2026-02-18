//
//  LocalModelRecommendationEngine+Scanning.swift
//  Thea
//
//  Model scanning and discovery for local models
//  Extracted from LocalModelRecommendationEngine.swift for better code organization
//

import Foundation
import OSLog

private let scanningLogger = Logger(subsystem: "ai.thea.app", category: "LocalModelRecommendationEngine")

// MARK: - Scanning & Discovery

extension LocalModelRecommendationEngine {
    /// Perform initial scan of installed and available models
    func initialScan() async {
        await scanInstalledModels()
        await discoverAvailableModels()
        await generateRecommendations()
    }

    /// Scan locally installed models (MLX, Ollama, etc.)
    func scanInstalledModels() async {
        isScanning = true
        defer { isScanning = false }

        var models: [InstalledLocalModel] = []

        // Scan MLX models
        let mlxModels = await scanMLXModels()
        models.append(contentsOf: mlxModels)

        // Scan Ollama models
        let ollamaModels = await scanOllamaModels()
        models.append(contentsOf: ollamaModels)

        installedModels = models
        lastScanDate = Date()
        saveLastScanDate()
    }

    func scanMLXModels() async -> [InstalledLocalModel] {
        var models: [InstalledLocalModel] = []

        // Get MLX model directories from settings
        let mlxPath = SettingsManager.shared.mlxModelsPath
        guard !mlxPath.isEmpty else { return [] }

        let url = URL(fileURLWithPath: mlxPath)
        let fileManager = FileManager.default

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            scanningLogger.error("Failed to scan MLX models directory at \(url.path): \(error.localizedDescription)")
            return []
        }

        for itemURL in contents {
            var isDirectory = false
            do {
                isDirectory = (try itemURL.resourceValues(forKeys: [.isDirectoryKey])).isDirectory ?? false
            } catch {
                scanningLogger.debug("Failed to read resource values for \(itemURL.lastPathComponent): \(error.localizedDescription)")
            }
            if isDirectory {
                // Check for MLX model files
                let configPath = itemURL.appendingPathComponent("config.json")
                if fileManager.fileExists(atPath: configPath.path) {
                    let model = InstalledLocalModel(
                        id: UUID(),
                        name: itemURL.lastPathComponent,
                        source: .mlx,
                        path: itemURL.path,
                        sizeBytes: calculateDirectorySize(url: itemURL),
                        quantization: detectQuantization(itemURL),
                        capabilities: detectCapabilities(itemURL),
                        installedDate: {
                            do {
                                return (try fileManager.attributesOfItem(atPath: itemURL.path)[.creationDate] as? Date) ?? Date()
                            } catch {
                                scanningLogger.debug("Failed to read creation date for \(itemURL.lastPathComponent): \(error.localizedDescription)")
                                return Date()
                            }
                        }()
                    )
                    models.append(model)
                }
            }
        }

        return models
    }

    func scanOllamaModels() async -> [InstalledLocalModel] {
        guard SettingsManager.shared.ollamaEnabled else { return [] }

        let ollamaURL = SettingsManager.shared.ollamaURL.isEmpty
            ? "http://localhost:11434"
            : SettingsManager.shared.ollamaURL

        guard let url = URL(string: "\(ollamaURL)/api/tags") else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)

            return response.models.map { model in
                InstalledLocalModel(
                    id: UUID(),
                    name: model.name,
                    source: .ollama,
                    path: "ollama://\(model.name)",
                    sizeBytes: model.size,
                    quantization: model.details?.quantizationLevel,
                    capabilities: parseOllamaCapabilities(model),
                    installedDate: ISO8601DateFormatter().date(from: model.modifiedAt) ?? Date()
                )
            }
        } catch {
            print("Failed to scan Ollama models: \(error)")
            return []
        }
    }
}

// MARK: - Model Discovery

extension LocalModelRecommendationEngine {
    /// Discover available models from HuggingFace and other sources
    func discoverAvailableModels() async {
        isScanning = true
        defer { isScanning = false }

        var discovered: [DiscoveredModel] = []

        // Discover from HuggingFace MLX Community
        let hfModels = await discoverHuggingFaceModels()
        discovered.append(contentsOf: hfModels)

        // Discover from Ollama library
        let ollamaModels = await discoverOllamaLibraryModels()
        discovered.append(contentsOf: ollamaModels)

        availableModels = discovered
    }

    func discoverHuggingFaceModels() async -> [DiscoveredModel] {
        // HuggingFace API for MLX models
        guard let url = URL(string: "https://huggingface.co/api/models?library=mlx&sort=downloads&limit=50") else {
            return []
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let models = try JSONDecoder().decode([HuggingFaceModel].self, from: data)

            return models.compactMap { hfModel -> DiscoveredModel? in
                guard let modelId = hfModel.modelId else { return nil }

                return DiscoveredModel(
                    id: modelId,
                    name: extractModelName(from: modelId),
                    source: .huggingFace,
                    author: hfModel.author ?? "unknown",
                    description: hfModel.description,
                    downloads: hfModel.downloads ?? 0,
                    likes: hfModel.likes ?? 0,
                    estimatedSizeGB: estimateModelSize(hfModel),
                    quantization: detectQuantizationFromName(modelId),
                    capabilities: detectCapabilitiesFromTags(hfModel.tags ?? []),
                    benchmarks: nil,
                    lastUpdated: ISO8601DateFormatter().date(from: hfModel.lastModified ?? "") ?? Date(),
                    downloadURL: "https://huggingface.co/\(modelId)"
                )
            }
        } catch {
            print("Failed to discover HuggingFace models: \(error)")
            return []
        }
    }

    func discoverOllamaLibraryModels() async -> [DiscoveredModel] {
        // Popular Ollama models (static list since Ollama doesn't have a public discovery API)
        [
            DiscoveredModel(
                id: "llama3.2:latest",
                name: "Llama 3.2",
                source: .ollamaLibrary,
                author: "Meta",
                description: "Latest Llama model optimized for chat and code",
                downloads: 100000,
                likes: 5000,
                estimatedSizeGB: 4.7,
                quantization: "Q4_K_M",
                capabilities: [.chat, .code, .reasoning],
                benchmarks: ModelBenchmarks(mmlu: 75.2, humanEval: 68.0, gsm8k: 82.1),
                lastUpdated: Date(),
                downloadURL: "ollama://llama3.2"
            ),
            DiscoveredModel(
                id: "qwen2.5:7b",
                name: "Qwen 2.5 7B",
                source: .ollamaLibrary,
                author: "Alibaba",
                description: "Excellent multilingual and coding capabilities",
                downloads: 80000,
                likes: 4200,
                estimatedSizeGB: 4.4,
                quantization: "Q4_K_M",
                capabilities: [.chat, .code, .multilingual],
                benchmarks: ModelBenchmarks(mmlu: 74.8, humanEval: 71.2, gsm8k: 79.5),
                lastUpdated: Date(),
                downloadURL: "ollama://qwen2.5:7b"
            ),
            DiscoveredModel(
                id: "deepseek-coder-v2:16b",
                name: "DeepSeek Coder V2 16B",
                source: .ollamaLibrary,
                author: "DeepSeek",
                description: "State-of-the-art coding model with MoE architecture",
                downloads: 60000,
                likes: 3800,
                estimatedSizeGB: 8.5,
                quantization: "Q4_K_M",
                capabilities: [.code, .reasoning],
                benchmarks: ModelBenchmarks(mmlu: 72.0, humanEval: 82.5, gsm8k: 75.0),
                lastUpdated: Date(),
                downloadURL: "ollama://deepseek-coder-v2:16b"
            ),
            DiscoveredModel(
                id: "mistral:7b",
                name: "Mistral 7B",
                source: .ollamaLibrary,
                author: "Mistral AI",
                description: "Fast and efficient general-purpose model",
                downloads: 150000,
                likes: 6000,
                estimatedSizeGB: 4.1,
                quantization: "Q4_K_M",
                capabilities: [.chat, .reasoning],
                benchmarks: ModelBenchmarks(mmlu: 70.5, humanEval: 52.0, gsm8k: 68.0),
                lastUpdated: Date(),
                downloadURL: "ollama://mistral:7b"
            ),
            DiscoveredModel(
                id: "codellama:7b",
                name: "Code Llama 7B",
                source: .ollamaLibrary,
                author: "Meta",
                description: "Specialized for code generation and understanding",
                downloads: 120000,
                likes: 5500,
                estimatedSizeGB: 3.8,
                quantization: "Q4_K_M",
                capabilities: [.code],
                benchmarks: ModelBenchmarks(mmlu: 45.0, humanEval: 75.0, gsm8k: 35.0),
                lastUpdated: Date(),
                downloadURL: "ollama://codellama:7b"
            )
        ]
    }
}
