import Foundation

// MARK: - Runtime Detection, Model Loading & Installation

extension LocalModelManager {

    // MARK: - Runtime Detection

    func detectRuntimes() async {
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
        case .coreML:
            CoreMLModelInstance(model: model)
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
