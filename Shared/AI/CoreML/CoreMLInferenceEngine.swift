import CoreML
import Foundation

// MARK: - CoreML Inference Engine
// Enables on-device LLM inference via CoreML on all Apple platforms
// Primary use: Gemma 3 models on iOS without API keys

@MainActor
@Observable
final class CoreMLInferenceEngine {
    static let shared = CoreMLInferenceEngine()

    // MARK: - State

    private(set) var loadedModel: MLModel?
    private(set) var loadedModelID: String?
    private(set) var isLoading = false
    private(set) var lastError: Error?

    private init() {}

    // MARK: - Model Discovery

    /// Discover available CoreML LLM models (bundled + downloaded)
    func discoverLLMModels() -> [DiscoveredCoreMLModel] {
        var models: [DiscoveredCoreMLModel] = []

        // Check app bundle
        if let bundlePath = Bundle.main.resourcePath {
            let bundleURL = URL(fileURLWithPath: bundlePath)
            models += scanForModels(in: bundleURL, source: .bundled)
        }

        // Check application support
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let modelsDir = appSupportURL.appendingPathComponent("Thea").appendingPathComponent("Models")
            models += scanForModels(in: modelsDir, source: .downloaded)
        }

        // Check documents (iOS user-provided)
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let localModelsDir = documentsURL.appendingPathComponent("LocalModels")
            models += scanForModels(in: localModelsDir, source: .downloaded)
        }

        return models
    }

    private func scanForModels(in directory: URL, source: ModelSource) -> [DiscoveredCoreMLModel] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { item in
            let ext = item.pathExtension
            guard ext == "mlmodelc" || ext == "mlpackage" else { return nil }
            let name = item.deletingPathExtension().lastPathComponent
            let size = (try? item.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize) ?? 0
            return DiscoveredCoreMLModel(id: name, name: name, path: item, source: source, sizeBytes: Int64(size))
        }
    }

    // MARK: - Model Loading

    func loadModel(at path: URL, id modelID: String) async throws {
        if loadedModelID == modelID, loadedModel != nil { return }

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // CPU + GPU + ANE

            let model = try await MLModel.load(contentsOf: path, configuration: config)
            loadedModel = model
            loadedModelID = modelID
            print("CoreMLInferenceEngine: Loaded \(modelID)")
        } catch {
            lastError = error
            print("CoreMLInferenceEngine: Failed to load \(modelID): \(error)")
            throw error
        }
    }

    func loadBundledModel(name: String) async throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
            throw CoreMLInferenceError.modelNotFound(name)
        }
        try await loadModel(at: url, id: name)
    }

    func unloadModel() {
        loadedModel = nil
        loadedModelID = nil
    }

    // MARK: - Generation

    func generate(prompt: String, maxTokens: Int = 512) async throws -> AsyncThrowingStream<String, Error> {
        guard let model = loadedModel else {
            throw CoreMLInferenceError.noModelLoaded
        }

        // Run inference synchronously on MainActor, then yield result
        let result = try runInference(model: model, prompt: prompt, maxTokens: maxTokens)
        return AsyncThrowingStream { continuation in
            continuation.yield(result)
            continuation.finish()
        }
    }

    private func runInference(model: MLModel, prompt: String, maxTokens _: Int) throws -> String {
        let description = model.modelDescription

        // Text-in/text-out pattern
        if description.inputDescriptionsByName["input_text"] != nil {
            let input = try MLDictionaryFeatureProvider(dictionary: ["input_text": prompt as NSString])
            let output = try model.prediction(from: input)
            if let text = output.featureValue(for: "output_text")?.stringValue {
                return text
            }
        }

        // Token-based pattern (requires tokenizer integration)
        if description.inputDescriptionsByName["input_ids"] != nil {
            throw CoreMLInferenceError.tokenizationRequired
        }

        throw CoreMLInferenceError.unsupportedModelSchema
    }
}

// MARK: - Types

/// Lightweight discovery result (separate from CoreMLService's CoreMLModelInfo)
struct DiscoveredCoreMLModel: Identifiable, Sendable {
    let id: String
    let name: String
    let path: URL
    let source: ModelSource
    let sizeBytes: Int64
}

// MARK: - Errors

enum CoreMLInferenceError: Error, LocalizedError {
    case noModelLoaded
    case modelNotFound(String)
    case tokenizationRequired
    case unsupportedModelSchema
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .noModelLoaded:
            "No CoreML model loaded."
        case let .modelNotFound(name):
            "CoreML model not found: \(name)"
        case .tokenizationRequired:
            "Model requires token-based input. Install a compatible tokenizer."
        case .unsupportedModelSchema:
            "Model input/output schema not supported."
        case let .generationFailed(reason):
            "CoreML generation failed: \(reason)"
        }
    }
}
