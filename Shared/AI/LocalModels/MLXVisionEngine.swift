import CoreImage
import Foundation

#if os(macOS)
import MLX
import MLXNN
import MLXVLM
import MLXLMCommon

// MARK: - MLX Vision Engine
// Native on-device vision-language model inference using MLXVLM (mlx-swift-lm 2.30.3+).
// Enables private image understanding without API calls.
//
// Recommended models (2026):
//   Qwen3-VL 8B  — "mlx-community/Qwen3-VL-8B-Instruct-4bit"  (default, all Macs)
//   Qwen3-VL 32B — "mlx-community/Qwen3-VL-32B-Instruct-4bit" (MSM3U only, 192GB RAM)
//
// High-throughput path (MSM3U): Set vllmEndpoint to the vllm-mlx OpenAI-compatible server
//   python -m vllm.entrypoints.openai.api_server --model <path> --backend mlx
//   vllmEndpoint = URL(string: "http://localhost:8000")
//   Benchmarks show 400+ tok/s on M3 Ultra for 8B models.
//
// iOS fallback: Use Anthropic vision API when local model unavailable.

/// Manages VLM (Vision Language Model) loading and inference for local image analysis
@MainActor
@Observable
final class MLXVisionEngine {
    static let shared = MLXVisionEngine()

    // MARK: - Model IDs (2026 recommended)

    /// Default VLM — works on all Macs (8B 4-bit quantization)
    static let qwen3VL8B  = "mlx-community/Qwen3-VL-8B-Instruct-4bit"
    // periphery:ignore - Reserved: qwen3VL32B static property — reserved for future feature activation
    /// High-capability VLM — MSM3U only (32B 4-bit quantization, requires ~20GB VRAM)
    static let qwen3VL32B = "mlx-community/Qwen3-VL-32B-Instruct-4bit"

    // MARK: - State

// periphery:ignore - Reserved: qwen3VL32B static property reserved for future feature activation

    private(set) var loadedModel: ModelContainer?
    private(set) var loadedModelID: String?
    private(set) var isLoading = false
    private(set) var loadingProgress: Double = 0.0
    private(set) var lastError: Error?

    /// Optional vllm-mlx endpoint for high-throughput inference on MSM3U.
    /// When set, `analyzeImage()` routes through this OpenAI-compatible HTTP server
    /// instead of the in-process MLXVLM runtime.
    /// Example: URL(string: "http://localhost:8000")
    var vllmEndpoint: URL?

    private let modelFactory = VLMModelFactory.shared

    private init() {}

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

    // periphery:ignore - Reserved: loadLocalModel(path:) instance method — reserved for future feature activation
    /// Load a VLM from a local directory
    func loadLocalModel(path: URL) async throws -> ModelContainer {
        let modelID = path.path
        // periphery:ignore - Reserved: loadLocalModel(path:) instance method reserved for future feature activation
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

    // periphery:ignore - Reserved: unloadModel() instance method — reserved for future feature activation
    func unloadModel() {
        // periphery:ignore - Reserved: unloadModel() instance method reserved for future feature activation
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

    // periphery:ignore - Reserved: analyzeImage(imageURL:prompt:parameters:) instance method reserved for future feature activation
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

    // MARK: - vllm-mlx HTTP Backend (MSM3U high-throughput path)

    /// Analyze an image via vllm-mlx's OpenAI-compatible /v1/chat/completions endpoint.
    /// Requires `vllmEndpoint` to be set and vllm-mlx server running.
    /// Returns the full response text (non-streaming for simplicity in messaging context).
    func analyzeImageViaVllm(imageData: Data, prompt: String) async throws -> String {
        guard let endpoint = vllmEndpoint else {
            throw MLXVisionError.vllmNotConfigured
        }

        let base64Image = imageData.base64EncodedString()
        let url = endpoint.appendingPathComponent("v1/chat/completions")

        let requestBody: [String: Any] = [
            "model": loadedModelID ?? "default",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]],
                        ["type": "text", "text": prompt]
                    ]
                ]
            ],
            "max_tokens": 512,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw MLXVisionError.generationFailed("Invalid vllm response")
        }

        return content
    }

    /// Convenience method: analyze image data and return the full text response.
    /// Routes via vllm-mlx if endpoint is configured, otherwise uses in-process MLXVLM.
    /// iOS path: always uses in-process MLXVLM (vllm endpoint should not be set on iOS).
    func describeImage(imageData: Data, prompt: String = "Describe this image concisely.") async throws -> String {
        // Use vllm-mlx if configured (MSM3U high-throughput path)
        if vllmEndpoint != nil {
            return try await analyzeImageViaVllm(imageData: imageData, prompt: prompt)
        }

        // Use in-process MLXVLM
        let stream = try await analyzeImage(imageData: imageData, prompt: prompt)
        var result = ""
        for try await chunk in stream {
            result += chunk
        }
        guard !result.isEmpty else { throw MLXVisionError.generationFailed("Empty response") }
        return result
    }
}

// MARK: - VLM Errors

enum MLXVisionError: Error, LocalizedError {
    case noModelLoaded
    case invalidImageData
    case generationFailed(String)
    case vllmNotConfigured

    var errorDescription: String? {
        switch self {
        case .noModelLoaded:
            "No vision-language model is loaded. Load a VLM first."
        case .invalidImageData:
            "The provided image data is invalid or corrupt."
        case .generationFailed(let reason):
            "VLM generation failed: \(reason)"
        case .vllmNotConfigured:
            "vllm-mlx endpoint not configured. Set MLXVisionEngine.shared.vllmEndpoint."
        }
    }
}

#endif
