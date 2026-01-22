//
//  CoreMLService.swift
//  Thea
//
//  Core ML integration for on-device AI models
//

import Foundation
import CoreML
import Combine
import NaturalLanguage

// MARK: - Core ML Service

/// Service for managing Core ML models and on-device inference
@MainActor
public class CoreMLService: ObservableObject {
    public static let shared = CoreMLService()

    // MARK: - Published State

    @Published public private(set) var availableModels: [CoreMLModelInfo] = []
    @Published public private(set) var loadedModels: [String: MLModel] = [:]
    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastInferenceTime: TimeInterval = 0

    // MARK: - Model Configuration

    private let modelDirectory: URL
    private let computeUnits: MLComputeUnits = .all

    // MARK: - NLP Components

    private let sentimentAnalyzer = NLModel()
    private let languageRecognizer = NLLanguageRecognizer()
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .sentimentScore])

    // MARK: - Initialization

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        modelDirectory = appSupport.appendingPathComponent("Thea/Models")

        try? FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        Task {
            await discoverModels()
        }
    }

    // MARK: - Model Discovery

    /// Discover available Core ML models
    public func discoverModels() async {
        var models: [CoreMLModelInfo] = []

        // Bundled models
        if let bundledModels = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) {
            for url in bundledModels {
                if let info = await loadModelInfo(from: url, source: .bundled) {
                    models.append(info)
                }
            }
        }

        // Downloaded models
        let contents = try? FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: nil)
        for url in contents ?? [] where url.pathExtension == "mlmodelc" || url.pathExtension == "mlpackage" {
            if let info = await loadModelInfo(from: url, source: .downloaded) {
                models.append(info)
            }
        }

        availableModels = models
    }

    private func loadModelInfo(from url: URL, source: ModelSource) async -> CoreMLModelInfo? {
        do {
            let compiledURL: URL
            if url.pathExtension == "mlpackage" {
                compiledURL = try await MLModel.compileModel(at: url)
            } else {
                compiledURL = url
            }

            let model = try MLModel(contentsOf: compiledURL)
            let description = model.modelDescription

            return CoreMLModelInfo(
                id: url.deletingPathExtension().lastPathComponent,
                name: description.metadata[MLModelMetadataKey.description] as? String ?? url.lastPathComponent,
                version: description.metadata[MLModelMetadataKey.versionString] as? String ?? "1.0",
                author: description.metadata[MLModelMetadataKey.author] as? String ?? "Unknown",
                source: source,
                url: compiledURL,
                inputDescription: description.inputDescriptionsByName.map { "\($0.key): \($0.value.type)" }.joined(separator: ", "),
                outputDescription: description.outputDescriptionsByName.map { "\($0.key): \($0.value.type)" }.joined(separator: ", "),
                size: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            )
        } catch {
            return nil
        }
    }

    // MARK: - Model Loading

    /// Load a model for inference
    public func loadModel(_ modelId: String) async throws -> MLModel {
        if let cached = loadedModels[modelId] {
            return cached
        }

        guard let info = availableModels.first(where: { $0.id == modelId }) else {
            throw CoreMLError.modelNotFound
        }

        let config = MLModelConfiguration()
        config.computeUnits = computeUnits

        let model = try MLModel(contentsOf: info.url, configuration: config)
        loadedModels[modelId] = model

        return model
    }

    /// Unload a model to free memory
    public func unloadModel(_ modelId: String) {
        loadedModels.removeValue(forKey: modelId)
    }

    // MARK: - Inference

    /// Run inference on a model
    public func predict(modelId: String, inputs: [String: MLFeatureValue]) async throws -> MLFeatureProvider {
        isProcessing = true
        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            isProcessing = false
            lastInferenceTime = CFAbsoluteTimeGetCurrent() - startTime
        }

        let model = try await loadModel(modelId)
        let inputProvider = try MLDictionaryFeatureProvider(dictionary: inputs)

        return try model.prediction(from: inputProvider)
    }

    /// Run batch inference
    public func batchPredict(
        modelId: String,
        batchInputs: [[String: MLFeatureValue]]
    ) async throws -> [MLFeatureProvider] {
        isProcessing = true
        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            isProcessing = false
            lastInferenceTime = CFAbsoluteTimeGetCurrent() - startTime
        }

        let model = try await loadModel(modelId)
        var results: [MLFeatureProvider] = []

        for inputs in batchInputs {
            let inputProvider = try MLDictionaryFeatureProvider(dictionary: inputs)
            let prediction = try model.prediction(from: inputProvider)
            results.append(prediction)
        }

        return results
    }

    // MARK: - Natural Language Processing

    /// Analyze sentiment of text
    public func analyzeSentiment(_ text: String) -> SentimentResult {
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        var scores: [Double] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .sentimentScore) { tag, range in
            if let tag = tag, let score = Double(tag.rawValue) {
                scores.append(score)
            }
            return true
        }

        let averageScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        let sentiment: Sentiment
        if averageScore > 0.3 {
            sentiment = .positive
        } else if averageScore < -0.3 {
            sentiment = .negative
        } else {
            sentiment = .neutral
        }

        return SentimentResult(
            sentiment: sentiment,
            score: averageScore,
            confidence: min(abs(averageScore) * 2, 1.0)
        )
    }

    /// Extract named entities from text
    public func extractEntities(_ text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag, tag != .other {
                let entity = ExtractedEntity(
                    text: String(text[range]),
                    type: EntityType(from: tag),
                    range: range
                )
                entities.append(entity)
            }
            return true
        }

        return entities
    }

    /// Detect the language of text
    public func detectLanguage(_ text: String) -> LanguageDetectionResult {
        languageRecognizer.reset()
        languageRecognizer.processString(text)

        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)

        guard let dominant = languageRecognizer.dominantLanguage else {
            return LanguageDetectionResult(language: nil, confidence: 0, alternatives: [])
        }

        return LanguageDetectionResult(
            language: dominant,
            confidence: hypotheses[dominant] ?? 0,
            alternatives: hypotheses.filter { $0.key != dominant }.map { ($0.key, $0.value) }
        )
    }

    /// Tokenize text
    public func tokenize(_ text: String) -> [String] {
        tokenizer.string = text
        var tokens: [String] = []

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            tokens.append(String(text[range]))
            return true
        }

        return tokens
    }

    /// Get word embeddings using NLEmbedding
    public func getEmbedding(_ text: String, language: NLLanguage = .english) -> [Double]? {
        guard let embedding = NLEmbedding.wordEmbedding(for: language) else {
            return nil
        }

        return embedding.vector(for: text)
    }

    /// Find similar words using embeddings
    public func findSimilarWords(_ word: String, count: Int = 5, language: NLLanguage = .english) -> [(String, Double)] {
        guard let embedding = NLEmbedding.wordEmbedding(for: language) else {
            return []
        }

        var results: [(String, Double)] = []
        embedding.enumerateNeighbors(for: word, maximumCount: count) { neighbor, distance in
            results.append((neighbor, distance))
            return true
        }

        return results
    }

    /// Classify text into parts of speech
    public func tagPartsOfSpeech(_ text: String) -> [PartOfSpeechTag] {
        var tags: [PartOfSpeechTag] = []

        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if let tag = tag {
                tags.append(PartOfSpeechTag(
                    word: String(text[range]),
                    tag: tag,
                    range: range
                ))
            }
            return true
        }

        return tags
    }

    // MARK: - Text Classification

    /// Classify text intent
    public func classifyIntent(_ text: String) async -> IntentClassification {
        // Keyword-based classification as fallback
        let lowercased = text.lowercased()

        if lowercased.contains("how") || lowercased.contains("what") || lowercased.contains("?") {
            return IntentClassification(intent: .question, confidence: 0.8, alternatives: [])
        } else if lowercased.contains("create") || lowercased.contains("make") || lowercased.contains("generate") {
            return IntentClassification(intent: .creation, confidence: 0.8, alternatives: [])
        } else if lowercased.contains("find") || lowercased.contains("search") || lowercased.contains("look") {
            return IntentClassification(intent: .search, confidence: 0.8, alternatives: [])
        } else if lowercased.contains("explain") || lowercased.contains("describe") || lowercased.contains("tell") {
            return IntentClassification(intent: .explanation, confidence: 0.8, alternatives: [])
        } else if lowercased.contains("fix") || lowercased.contains("solve") || lowercased.contains("debug") {
            return IntentClassification(intent: .troubleshooting, confidence: 0.8, alternatives: [])
        }

        return IntentClassification(intent: .general, confidence: 0.5, alternatives: [])
    }

    // MARK: - Model Download

    /// Download a model from a URL
    public func downloadModel(from url: URL, name: String) async throws -> CoreMLModelInfo {
        let destinationURL = modelDirectory.appendingPathComponent(name).appendingPathExtension("mlpackage")

        let (tempURL, _) = try await URLSession.shared.download(from: url)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        // Compile the model
        let compiledURL = try await MLModel.compileModel(at: destinationURL)

        // Move compiled model
        let finalURL = modelDirectory.appendingPathComponent(name).appendingPathExtension("mlmodelc")
        try? FileManager.default.removeItem(at: finalURL)
        try FileManager.default.moveItem(at: compiledURL, to: finalURL)

        // Clean up uncompiled
        try? FileManager.default.removeItem(at: destinationURL)

        await discoverModels()

        guard let info = availableModels.first(where: { $0.id == name }) else {
            throw CoreMLError.compilationFailed
        }

        return info
    }
}

// MARK: - Supporting Types

public struct CoreMLModelInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let author: String
    public let source: ModelSource
    public let url: URL
    public let inputDescription: String
    public let outputDescription: String
    public let size: Int64

    public var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public enum ModelSource: String, Sendable {
    case bundled
    case downloaded
    case custom
}

public enum Sentiment: String, Sendable {
    case positive
    case negative
    case neutral
}

public struct SentimentResult: Sendable {
    public let sentiment: Sentiment
    public let score: Double
    public let confidence: Double
}

public struct ExtractedEntity: Sendable {
    public let text: String
    public let type: EntityType
    public let range: Range<String.Index>
}

public enum EntityType: String, Sendable {
    case person
    case place
    case organization
    case other

    init(from tag: NLTag) {
        switch tag {
        case .personalName: self = .person
        case .placeName: self = .place
        case .organizationName: self = .organization
        default: self = .other
        }
    }
}

public struct LanguageDetectionResult: Sendable {
    public let language: NLLanguage?
    public let confidence: Double
    public let alternatives: [(NLLanguage, Double)]
}

public struct PartOfSpeechTag: Sendable {
    public let word: String
    public let tag: NLTag
    public let range: Range<String.Index>
}

public enum UserIntent: String, Sendable {
    case question
    case creation
    case search
    case explanation
    case troubleshooting
    case general
}

public struct IntentClassification: Sendable {
    public let intent: UserIntent
    public let confidence: Double
    public let alternatives: [(UserIntent, Double)]
}

public enum CoreMLError: Error, LocalizedError, Sendable {
    case modelNotFound
    case loadFailed
    case inferenceError
    case invalidInput
    case compilationFailed

    public var errorDescription: String? {
        switch self {
        case .modelNotFound: return "Model not found"
        case .loadFailed: return "Failed to load model"
        case .inferenceError: return "Inference failed"
        case .invalidInput: return "Invalid input format"
        case .compilationFailed: return "Model compilation failed"
        }
    }
}
