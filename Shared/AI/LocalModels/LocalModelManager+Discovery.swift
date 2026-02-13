import Foundation

// MARK: - Model Discovery

extension LocalModelManager {

    // MARK: - Public Discovery

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

    // MARK: - Ollama Discovery

    func discoverOllamaModels() async {
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

    // MARK: - MLX Discovery

    func discoverMLXModels() async {
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
                    discoverMLXHubModels(at: mlxPath)
                    try discoverMLXDirectModels(at: mlxPath)
                } catch {
                    print("Failed to discover MLX models in \(mlxPath.path): \(error)")
                }
            }
        #else
            // iOS: MLX requires macOS - not available on iOS
        #endif
    }

    #if os(macOS)
    /// Build the list of paths to search for MLX models
    private func buildMLXSearchPaths() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser

        // HuggingFace cache: check HF_HOME env, then standard default
        let hfHome = ProcessInfo.processInfo.environment["HF_HOME"]
            .map { URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent(".cache/huggingface")

        return [
            // Standard HuggingFace cache (contains hub/ with models--org--name/ dirs)
            hfHome,
            // SharedLLMs models-mlx (primary location with HuggingFace Hub structure)
            home.appendingPathComponent(config.sharedLLMsDirectory)
                .appendingPathComponent("models-mlx"),
            // Legacy mlx-models directory
            home.appendingPathComponent(config.mlxModelsDirectory)
        ]
    }

    /// Discover MLX models in a HuggingFace Hub directory structure
    private func discoverMLXHubModels(at mlxPath: URL) {
        let hubPath = mlxPath.appendingPathComponent("hub")
        guard FileManager.default.fileExists(atPath: hubPath.path) else { return }

        guard let modelDirs = try? FileManager.default.contentsOfDirectory(
            at: hubPath,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for modelDir in modelDirs {
            guard !modelDir.lastPathComponent.hasPrefix(".") else { continue }
            if let model = buildMLXModelFromHubDir(modelDir) {
                availableModels.append(model)
                print("✅ Discovered MLX model: \(model.name)")
            }
        }
    }

    /// Build a LocalModel from a HuggingFace Hub model directory (models--org--name/snapshots/hash/)
    private func buildMLXModelFromHubDir(_ modelDir: URL) -> LocalModel? {
        let snapshotsPath = modelDir.appendingPathComponent("snapshots")
        guard FileManager.default.fileExists(atPath: snapshotsPath.path) else { return nil }

        guard let snapshots = try? FileManager.default.contentsOfDirectory(
            at: snapshotsPath,
            includingPropertiesForKeys: [.isDirectoryKey]
        ), let snapshotDir = snapshots.first else { return nil }

        // Verify it's a valid MLX model directory
        let configPath = snapshotDir.appendingPathComponent("config.json")
        guard FileManager.default.fileExists(atPath: configPath.path) else { return nil }

        let hasWeights = FileManager.default.fileExists(atPath: snapshotDir.appendingPathComponent("weights.safetensors").path) ||
            FileManager.default.fileExists(atPath: snapshotDir.appendingPathComponent("model.safetensors").path) ||
            FileManager.default.fileExists(atPath: snapshotDir.appendingPathComponent("tokenizer.json").path)

        guard hasWeights else { return nil }

        let dirName = modelDir.lastPathComponent
        let modelName = extractModelName(from: dirName)
        let size = calculateDirectorySize(snapshotDir)

        return LocalModel(
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
    }

    /// Discover MLX models in direct (non-Hub) directory structure
    private func discoverMLXDirectModels(at mlxPath: URL) throws {
        let directModels = try FileManager.default.contentsOfDirectory(
            at: mlxPath,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
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
    }
    #endif

    // MARK: - GGUF Discovery

    func discoverGGUFModels() async {
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

    // MARK: - Model Name / Metadata Extraction

    /// Extract friendly model name from HuggingFace Hub directory name
    func extractModelName(from dirName: String) -> String {
        // "models--mlx-community--Qwen2.5-72B-Instruct-8bit" -> "Qwen2.5-72B-Instruct-8bit"
        let parts = dirName.split(separator: "--")
        if parts.count >= 3 {
            return String(parts.dropFirst(2).joined(separator: "--"))
        }
        return dirName
    }

    /// Extract parameter size from model name (e.g., "7B", "70B")
    func extractParameters(from name: String) -> String {
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
    func extractQuantization(from name: String) -> String {
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

    // MARK: - Model Capability Detection

    /// Detect capabilities from model name for richer metadata
    static func detectModelCapabilities(name: String) -> (
        supportsVision: Bool, supportsFunctionCalling: Bool, contextWindow: Int,
        parameters: String?, quantization: String?
    ) {
        let lower = name.lowercased()

        // GPT-OSS: OpenAI open-weight models with tool use and 128K context
        if lower.contains("gpt-oss") || lower.contains("gpt_oss") {
            let params = lower.contains("120b") ? "120B" : lower.contains("20b") ? "20B" : nil
            return (false, true, 128_000, params, "MXFP4")
        }

        // Qwen VL: Vision-language models
        if lower.contains("qwen") && (lower.contains("-vl") || lower.contains("_vl")) {
            return (true, false, 32_768, nil, nil)
        }

        // Gemma: Google open models with function calling
        if lower.contains("gemma") {
            let hasVision = lower.contains("pali") || lower.contains("vl")
            return (hasVision, true, 128_000, nil, nil)
        }

        // Llama: Meta models
        if lower.contains("llama") {
            return (false, true, 128_000, nil, nil)
        }

        // Default: basic text model
        return (false, false, 4096, nil, nil)
    }

    /// Calculate total size of a directory
    func calculateDirectorySize(_ url: URL) -> Int64 {
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
}
