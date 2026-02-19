import Foundation
import OSLog
#if os(macOS)
import MLXLMCommon
#endif

// MARK: - Local Model Support

// Run AI models locally using Ollama, MLX, or GGUF

@MainActor
@Observable
final class LocalModelManager {
    static let shared = LocalModelManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "LocalModelManager")

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

    // periphery:ignore - Reserved: addCustomModelPath(_:) instance method — reserved for future feature activation
    func addCustomModelPath(_ path: URL) {
        guard !customModelPaths.contains(path) else { return }
        customModelPaths.append(path)
        saveCustomPaths()
        Task {
            // periphery:ignore - Reserved: addCustomModelPath(_:) instance method reserved for future feature activation
            await discoverModels()
        }
    }

    // periphery:ignore - Reserved: removeCustomModelPath(_:) instance method — reserved for future feature activation
    func removeCustomModelPath(_ path: URL) {
        customModelPaths.removeAll { $0 == path }
        saveCustomPaths()
        Task {
            // periphery:ignore - Reserved: removeCustomModelPath(_:) instance method reserved for future feature activation
            await discoverModels()
        }
    }

    private func loadCustomPaths() {
        if let data = UserDefaults.standard.data(forKey: "LocalModelManager.customPaths") {
            do {
                customModelPaths = try JSONDecoder().decode([URL].self, from: data)
            } catch {
                logger.debug("Could not decode custom model paths: \(error.localizedDescription)")
            }
        }
        if customModelPaths.isEmpty {
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

    // periphery:ignore - Reserved: saveCustomPaths() instance method — reserved for future feature activation
    private func saveCustomPaths() {
        do {
            let data = try JSONEncoder().encode(customModelPaths)
            // periphery:ignore - Reserved: saveCustomPaths() instance method reserved for future feature activation
            UserDefaults.standard.set(data, forKey: "LocalModelManager.customPaths")
        } catch {
            logger.error("Failed to save custom model paths: \(error.localizedDescription)")
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
                        let caps = Self.detectModelCapabilities(name: modelName)
                        let model = LocalModel(
                            id: UUID(),
                            name: modelName,
                            path: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ollama/\(modelName)"),
                            type: .ollama,
                            format: "GGUF",
                            sizeInBytes: nil,
                            runtime: .ollama,
                            size: 0,
                            parameters: caps.parameters ?? config.defaultParameters,
                            quantization: caps.quantization ?? config.defaultQuantization
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
            let mlxPaths = buildMLXSearchPaths()

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
                    discoverHubModels(at: mlxPath)
                    try discoverDirectModels(at: mlxPath)
                } catch {
                    print("Failed to discover MLX models in \(mlxPath.path): \(error)")
                }
            }
        #else
            // iOS: MLX requires macOS - not available on iOS
        #endif
    }

    #if os(macOS)
    private func buildMLXSearchPaths() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let hfHome = ProcessInfo.processInfo.environment["HF_HOME"]
            .map { URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent(".cache/huggingface")

        return [
            hfHome,
            home.appendingPathComponent(config.sharedLLMsDirectory)
                .appendingPathComponent("models-mlx"),
            home.appendingPathComponent(config.mlxModelsDirectory)
        ]
    }

    private func discoverHubModels(at mlxPath: URL) {
        let hubPath = mlxPath.appendingPathComponent("hub")
        guard FileManager.default.fileExists(atPath: hubPath.path) else { return }

        let modelDirs: [URL]
        do {
            modelDirs = try FileManager.default.contentsOfDirectory(
                at: hubPath, includingPropertiesForKeys: [.isDirectoryKey]
            )
        } catch {
            logger.debug("Could not list hub model directories: \(error.localizedDescription)")
            return
        }

        for modelDir in modelDirs {
            guard !modelDir.lastPathComponent.hasPrefix(".") else { continue }

            let snapshotsPath = modelDir.appendingPathComponent("snapshots")
            guard FileManager.default.fileExists(atPath: snapshotsPath.path) else { continue }
            let snapshotDir: URL
            do {
                let snapshots = try FileManager.default.contentsOfDirectory(
                    at: snapshotsPath, includingPropertiesForKeys: [.isDirectoryKey]
                )
                guard let first = snapshots.first else { continue }
                snapshotDir = first
            } catch {
                logger.debug("Could not list snapshots for \(modelDir.lastPathComponent): \(error.localizedDescription)")
                continue
            }

            guard isValidMLXModelDirectory(snapshotDir) else { continue }

            let modelName = extractModelName(from: modelDir.lastPathComponent)
            let size = calculateDirectorySize(snapshotDir)

            let model = LocalModel(
                id: UUID(), name: modelName, path: snapshotDir,
                type: .mlx, format: "MLX", sizeInBytes: Int(size),
                runtime: .mlx, size: size,
                parameters: extractParameters(from: modelName),
                quantization: extractQuantization(from: modelName)
            )

            availableModels.append(model)
            print("✅ Discovered MLX model: \(modelName)")
        }
    }

    private func discoverDirectModels(at mlxPath: URL) throws {
        let directModels = try FileManager.default.contentsOfDirectory(
            at: mlxPath, includingPropertiesForKeys: [.isDirectoryKey]
        )
        for modelDir in directModels {
            guard !modelDir.lastPathComponent.hasPrefix("."),
                  modelDir.lastPathComponent != "hub" else { continue }

            let configPath = modelDir.appendingPathComponent("config.json")
            guard FileManager.default.fileExists(atPath: configPath.path) else { continue }

            let modelName = modelDir.lastPathComponent
            let size = calculateDirectorySize(modelDir)

            let model = LocalModel(
                id: UUID(), name: modelName, path: modelDir,
                type: .mlx, format: "MLX", sizeInBytes: Int(size),
                runtime: .mlx, size: size,
                parameters: extractParameters(from: modelName),
                quantization: extractQuantization(from: modelName)
            )

            availableModels.append(model)
            print("✅ Discovered MLX model: \(modelName)")
        }
    }

    private func isValidMLXModelDirectory(_ dir: URL) -> Bool {
        let configPath = dir.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configPath.path) else { return false }

        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("weights.safetensors").path) ||
            FileManager.default.fileExists(atPath: dir.appendingPathComponent("model.safetensors").path) ||
            FileManager.default.fileExists(atPath: dir.appendingPathComponent("tokenizer.json").path)
    }
    #endif

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
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                if let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
                   let range = Range(match.range(at: 1), in: name)
                {
                    return String(name[range]) + "B"
                }
            } catch {
                logger.debug("Failed to compile parameter regex: \(error.localizedDescription)")
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

}

// MARK: - Model Capability Detection

extension LocalModelManager {
    /// Detect capabilities from model name for richer metadata
    static func detectModelCapabilities(name: String) -> (
        supportsVision: Bool, supportsFunctionCalling: Bool, contextWindow: Int,
        parameters: String?, quantization: String?
    ) {
        let lower = name.lowercased()

        if lower.contains("gpt-oss") || lower.contains("gpt_oss") {
            let params = lower.contains("120b") ? "120B" : lower.contains("20b") ? "20B" : nil
            return (false, true, 128_000, params, "MXFP4")
        }
        if lower.contains("qwen") && (lower.contains("-vl") || lower.contains("_vl")) {
            return (true, false, 32_768, nil, nil)
        }
        if lower.contains("gemma") {
            let hasVision = lower.contains("pali") || lower.contains("vl")
            return (hasVision, true, 128_000, nil, nil)
        }
        if lower.contains("llama") {
            return (false, true, 128_000, nil, nil)
        }
        return (false, false, 4096, nil, nil)
    }

    /// Calculate total size of a directory
    func calculateDirectorySize(_ url: URL) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            do {
                if let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            } catch {
                logger.debug("Could not get file size for \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return totalSize
    }
}

// MARK: - GGUF Discovery & Model Loading

extension LocalModelManager {
    func discoverGGUFModels() async {
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
                            path: fileURL, type: .gguf, format: "GGUF",
                            sizeInBytes: size, runtime: .gguf, size: Int64(size),
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

    func loadModel(_ model: LocalModel) async throws -> LocalModelInstance {
        if let instance = runningModels[model.name] {
            return instance
        }

        let instance: LocalModelInstance = switch model.runtime {
        case .ollama: OllamaModelInstance(model: model)
        case .mlx: MLXModelInstance(model: model)
        case .gguf: GGUFModelInstance(model: model)
        case .coreML: CoreMLModelInstance(model: model)
        }

        runningModels[model.name] = instance
        return instance
    }

    // periphery:ignore - Reserved: unloadModel(_:) instance method — reserved for future feature activation
    func unloadModel(_ modelName: String) {
        runningModels.removeValue(forKey: modelName)
    // periphery:ignore - Reserved: unloadModel(_:) instance method reserved for future feature activation
    }
}

// MARK: - Model Installation

extension LocalModelManager {
    // periphery:ignore - Reserved: installOllamaModel(_:) instance method — reserved for future feature activation
    func installOllamaModel(_ modelName: String) async throws {
        // periphery:ignore - Reserved: installOllamaModel(_:) instance method reserved for future feature activation
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

            await discoverModels()
        #else
            throw LocalModelError.runtimeNotInstalled("Ollama")
        #endif
    }

    // periphery:ignore - Reserved: downloadGGUFModel(from:name:) instance method reserved for future feature activation
    func downloadGGUFModel(from url: URL, name: String) async throws {
        #if os(macOS)
            let destinationPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(config.ggufModelsDirectory)
                .appendingPathComponent("\(name).gguf")

            try FileManager.default.createDirectory(
                at: destinationPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let (localURL, _) = try await URLSession.shared.download(from: url)
            try FileManager.default.moveItem(at: localURL, to: destinationPath)

            await discoverModels()
        #else
            throw LocalModelError.platformNotSupported("Model download requires macOS")
        #endif
    }
}
