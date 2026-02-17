import CoreImage
import Foundation

#if os(macOS)
import MLX
import MLXNN
import MLXVLM
import MLXLMCommon

// MARK: - MLX Vision Engine
// Native on-device vision-language model inference using MLXVLM
// Enables private image understanding without API calls

/// Manages VLM (Vision Language Model) loading and inference for local image analysis
@MainActor
@Observable
final class MLXVisionEngine {
    static let shared = MLXVisionEngine()

    // MARK: - State

    private(set) var loadedModel: ModelContainer?
    private(set) var loadedModelID: String?
    private(set) var isLoading = false
    private(set) var loadingProgress: Double = 0.0
    private(set) var lastError: Error?

    private let modelFactory = VLMModelFactory.shared
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        setupMemoryPressureHandler()
    }

    private func setupMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self, !self.isLoading else { return }
                print("⚠️ MLXVisionEngine: Memory pressure detected, unloading model")
                self.unloadModel()
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    // MARK: - Model Loading

    /// Load a VLM from HuggingFace Hub
    func loadModel(id modelID: String) async throws -> ModelContainer {
        if loadedModelID == modelID, let model = loadedModel {
            return model
        }

        isLoading = true
        loadingProgress = 0.0
        lastError = nil

        defer { isLoading = false }

        do {
            let configuration = ModelConfiguration(id: modelID)

            let container = try await modelFactory.loadContainer(
                configuration: configuration
            ) { progress in
                Task { @MainActor in
                    self.loadingProgress = progress.fractionCompleted
                }
            }

            loadedModel = container
            loadedModelID = modelID

            print("✅ MLXVisionEngine: Loaded VLM \(modelID)")
            return container
        } catch {
            lastError = error
            print("❌ MLXVisionEngine: Failed to load VLM \(modelID): \(error)")
            throw error
        }
    }

    /// Load a VLM from a local directory
    func loadLocalModel(path: URL) async throws -> ModelContainer {
        let modelID = path.path
        if loadedModelID == modelID, let model = loadedModel {
            return model
        }

        isLoading = true
        loadingProgress = 0.0
        lastError = nil

        defer { isLoading = false }

        do {
            let configuration = ModelConfiguration(directory: path)

            let container = try await modelFactory.loadContainer(
                configuration: configuration
            ) { progress in
                Task { @MainActor in
                    self.loadingProgress = progress.fractionCompleted
                }
            }

            loadedModel = container
            loadedModelID = modelID

            print("✅ MLXVisionEngine: Loaded local VLM from \(path.lastPathComponent)")
            return container
        } catch {
            lastError = error
            print("❌ MLXVisionEngine: Failed to load local VLM: \(error)")
            throw error
        }
    }

    func unloadModel() {
        loadedModel = nil
        loadedModelID = nil
        loadingProgress = 0.0
        print("📦 MLXVisionEngine: VLM unloaded")
    }

    // MARK: - Image Analysis

    /// Analyze an image with a text prompt using the loaded VLM
    func analyzeImage(
        imageData: Data,
        prompt: String,
        parameters: GenerateParameters = GenerateParameters()
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let model = loadedModel else {
            throw MLXVisionError.noModelLoaded
        }

        guard let ciImage = CIImage(data: imageData) else {
            throw MLXVisionError.invalidImageData
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await model.perform { context in
                        let userInput = UserInput(
                            prompt: prompt,
                            images: [.ciImage(ciImage)]
                        )

                        let input = try await context.processor.prepare(input: userInput)

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

    /// Analyze an image from a URL
    func analyzeImage(
        imageURL: URL,
        prompt: String,
        parameters: GenerateParameters = GenerateParameters()
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let model = loadedModel else {
            throw MLXVisionError.noModelLoaded
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try await model.perform { context in
                        let userInput = UserInput(
                            prompt: prompt,
                            images: [.url(imageURL)]
                        )

                        let input = try await context.processor.prepare(input: userInput)

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
}

// MARK: - VLM Errors

enum MLXVisionError: Error, LocalizedError {
    case noModelLoaded
    case invalidImageData
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noModelLoaded:
            "No vision-language model is loaded. Load a VLM first."
        case .invalidImageData:
            "The provided image data is invalid or corrupt."
        case .generationFailed(let reason):
            "VLM generation failed: \(reason)"
        }
    }
}

#endif
