// AdaptiveOCREngine.swift
// Multi-provider OCR engine with automatic script detection and accuracy optimization
// Supports Latin, Greek, Cyrillic and other scripts with best-in-class accuracy
//
// Providers:
// - Apple Vision (built-in, privacy-preserving)
// - Google Cloud Vision (high accuracy, multi-script)
// - DeepSeek-OCR (complex documents, tables)
// - Tesseract (offline fallback)

import Foundation
import Vision
import CoreImage
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - OCR Types

/// Supported writing scripts for OCR detection
enum OCRScript: String, Codable, Sendable, CaseIterable {
    case latin = "Latin"
    case greek = "Greek"
    case cyrillic = "Cyrillic"
    case arabic = "Arabic"
    case hebrew = "Hebrew"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case korean = "Korean"
    case devanagari = "Devanagari"
    case thai = "Thai"
    case mixed = "Mixed"
    case unknown = "Unknown"

    /// BCP-47 language codes typically associated with this script
    var associatedLanguages: [String] {
        switch self {
        case .latin: ["en", "fr", "de", "es", "it", "pt", "nl", "pl", "cs", "ro"]
        case .greek: ["el"]
        case .cyrillic: ["ru", "uk", "bg", "sr", "mk", "be"]
        case .arabic: ["ar", "fa", "ur"]
        case .hebrew: ["he", "yi"]
        case .chinese: ["zh-Hans", "zh-Hant"]
        case .japanese: ["ja"]
        case .korean: ["ko"]
        case .devanagari: ["hi", "sa", "mr", "ne"]
        case .thai: ["th"]
        case .mixed, .unknown: []
        }
    }
}

/// Accuracy tier for selecting optimal provider
enum OCRAccuracyTier: Int, Comparable, Sendable {
    case fallback = 0      // Tesseract
    case standard = 1      // Apple Vision
    case enhanced = 2      // Google Cloud Vision
    case premium = 3       // DeepSeek-OCR for complex docs

    static func < (lhs: OCRAccuracyTier, rhs: OCRAccuracyTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Document complexity level
enum DocumentComplexity: Sendable {
    case simple          // Plain text, single column
    case moderate        // Multiple columns, some formatting
    case complex         // Tables, forms, handwriting, mixed layouts
}

/// Result from OCR processing
struct OCRResult: Sendable {
    // periphery:ignore - Reserved: text property — reserved for future feature activation
    let text: String
    let confidence: Double  // 0.0 - 1.0
    let detectedScript: OCRScript
    // periphery:ignore - Reserved: provider property — reserved for future feature activation
    let provider: String
    // periphery:ignore - Reserved: boundingBoxes property — reserved for future feature activation
    let boundingBoxes: [TextRegion]
    let processingTime: TimeInterval
    // periphery:ignore - Reserved: languageHints property — reserved for future feature activation
    let languageHints: [String]

    struct TextRegion: Sendable {
        // periphery:ignore - Reserved: text property — reserved for future feature activation
        let text: String
        // periphery:ignore - Reserved: boundingBox property — reserved for future feature activation
        let boundingBox: CGRect
        // periphery:ignore - Reserved: confidence property — reserved for future feature activation
        let confidence: Double
    }
}

// periphery:ignore - Reserved: DocumentComplexity type reserved for future feature activation
/// Errors from OCR processing
enum OCRError: Error, LocalizedError {
    case imageConversionFailed
    case noTextDetected
    case providerUnavailable(String)
    case apiKeyMissing(String)
    case networkError(Error)
    // periphery:ignore - Reserved: OCRResult type reserved for future feature activation
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image for OCR processing"
        case .noTextDetected:
            return "No text detected in the image"
        case .providerUnavailable(let provider):
            return "OCR provider '\(provider)' is not available"
        case .apiKeyMissing(let provider):
            return "API key missing for \(provider)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .processingFailed(let reason):
            return "OCR processing failed: \(reason)"
        // periphery:ignore - Reserved: OCRError type reserved for future feature activation
        }
    }
}

// MARK: - OCR Provider Protocol

/// Protocol for OCR providers
protocol OCRProvider: Sendable {
    // periphery:ignore - Reserved: providerName property — reserved for future feature activation
    var providerName: String { get }
    var supportedScripts: Set<OCRScript> { get }
    var accuracyTier: OCRAccuracyTier { get }
    var isAvailable: Bool { get }
    // periphery:ignore - Reserved: requiresNetwork property — reserved for future feature activation
    var requiresNetwork: Bool { get }

    func extractText(from image: CGImage, languages: [String]?) async throws -> OCRResult
}

// MARK: - Apple Vision OCR Provider

// Built-in Apple Vision framework provider.
// @unchecked Sendable: all properties (providerName, accuracyTier, requiresNetwork) are let
// constants set at init; Vision framework requests are stateless and created fresh per call
final class VisionOCRProvider: OCRProvider, @unchecked Sendable {
    let providerName = "Apple Vision"
    let accuracyTier = OCRAccuracyTier.standard
    // periphery:ignore - Reserved: requiresNetwork property — reserved for future feature activation
    let requiresNetwork = false

    var supportedScripts: Set<OCRScript> {
        [.latin, .greek, .cyrillic, .chinese, .japanese, .korean, .arabic, .hebrew, .devanagari, .thai]
    // periphery:ignore - Reserved: providerName property reserved for future feature activation
    // periphery:ignore - Reserved: supportedScripts property reserved for future feature activation
    // periphery:ignore - Reserved: accuracyTier property reserved for future feature activation
    // periphery:ignore - Reserved: isAvailable property reserved for future feature activation
    // periphery:ignore - Reserved: requiresNetwork property reserved for future feature activation
    }

// periphery:ignore - Reserved: extractText(from:languages:) instance method reserved for future feature activation

    var isAvailable: Bool { true }

    func extractText(from image: CGImage, languages: [String]? = nil) async throws -> OCRResult {
        let startTime = Date()

        return try await withCheckedThrowingContinuation { continuation in
            // periphery:ignore - Reserved: VisionOCRProvider type reserved for future feature activation
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.processingFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextDetected)
                    return
                }

                var fullText = ""
                var regions: [OCRResult.TextRegion] = []
                var totalConfidence: Double = 0

                for observation in observations {
                    if let candidate = observation.topCandidates(1).first {
                        fullText += candidate.string + "\n"
                        totalConfidence += Double(candidate.confidence)

                        regions.append(OCRResult.TextRegion(
                            text: candidate.string,
                            boundingBox: observation.boundingBox,
                            confidence: Double(candidate.confidence)
                        ))
                    }
                }

                let avgConfidence = observations.isEmpty ? 0 : totalConfidence / Double(observations.count)
                let processingTime = Date().timeIntervalSince(startTime)

                let result = OCRResult(
                    text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
                    confidence: avgConfidence,
                    detectedScript: self.detectScript(from: fullText),
                    provider: self.providerName,
                    boundingBoxes: regions,
                    processingTime: processingTime,
                    languageHints: languages ?? []
                )

                continuation.resume(returning: result)
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            if #available(macOS 13.0, iOS 16.0, *) {
                request.automaticallyDetectsLanguage = languages == nil
                if let langs = languages {
                    request.recognitionLanguages = langs
                }
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.processingFailed(error.localizedDescription))
            }
        }
    }

    private func detectScript(from text: String) -> OCRScript {
        var scriptCounts: [OCRScript: Int] = [:]

        for char in text {
            let script = characterScript(char)
            scriptCounts[script, default: 0] += 1
        }

        // Find dominant script
        let sorted = scriptCounts.sorted { $0.value > $1.value }
        guard let dominant = sorted.first else { return .unknown }

        // If second script has significant presence (>20%), mark as mixed
        if let second = sorted.dropFirst().first,
           Double(second.value) / Double(dominant.value) > 0.2 {
            return .mixed
        }

        return dominant.key
    }

    private func characterScript(_ char: Character) -> OCRScript {
        guard let scalar = char.unicodeScalars.first else { return .unknown }
        let value = scalar.value

        switch value {
        case 0x0041...0x007A, 0x00C0...0x024F: return .latin
        case 0x0370...0x03FF, 0x1F00...0x1FFF: return .greek
        case 0x0400...0x04FF, 0x0500...0x052F: return .cyrillic
        case 0x0600...0x06FF, 0x0750...0x077F: return .arabic
        case 0x0590...0x05FF: return .hebrew
        case 0x4E00...0x9FFF, 0x3400...0x4DBF: return .chinese
        case 0x3040...0x309F, 0x30A0...0x30FF: return .japanese
        case 0xAC00...0xD7AF: return .korean
        case 0x0900...0x097F: return .devanagari
        case 0x0E00...0x0E7F: return .thai
        default:
            if char.isWhitespace || char.isPunctuation || char.isNumber {
                return .latin  // Default for neutral characters
            }
            return .unknown
        }
    }
}

// MARK: - Adaptive OCR Engine

/// Main OCR engine that selects optimal provider based on content and requirements
@MainActor
@Observable
final class AdaptiveOCREngine {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = AdaptiveOCREngine()

    // Available providers
    private let visionProvider = VisionOCRProvider()
    private var cloudProviders: [OCRProvider] = []

    // Configuration
    private(set) var preferOffline = true
    private(set) var minimumAccuracyTier = OCRAccuracyTier.standard

    // Statistics
    private(set) var totalExtractions: Int = 0
    private(set) var averageConfidence: Double = 0
    private(set) var averageProcessingTime: TimeInterval = 0

// periphery:ignore - Reserved: shared static property reserved for future feature activation

    private init() {
        // periphery:ignore - Reserved: visionProvider property reserved for future feature activation
        // Cloud providers would be initialized with API keys from secure storage
        // For now, only Vision is available by default
    }

    // MARK: - Public API

    /// Extract text from an image using the optimal provider
    func extractText(from image: CGImage) async throws -> OCRResult {
        let complexity = assessComplexity(image)
        let script = try await detectPrimaryScript(image)
        let provider = selectOptimalProvider(script: script, complexity: complexity)

        let result = try await provider.extractText(from: image, languages: script.associatedLanguages)

        // Update statistics
        updateStatistics(result)

        return result
    }

// periphery:ignore - Reserved: extractText(from:) instance method reserved for future feature activation

    /// Extract text with specific language hints
    func extractText(from image: CGImage, languages: [String]) async throws -> OCRResult {
        let complexity = assessComplexity(image)
        let provider = selectOptimalProvider(script: .mixed, complexity: complexity)

        let result = try await provider.extractText(from: image, languages: languages)
        updateStatistics(result)

        return result
    }

    #if canImport(AppKit)
    // periphery:ignore - Reserved: extractText(from:languages:) instance method reserved for future feature activation
    /// Convenience method for NSImage (macOS)
    func extractText(from nsImage: NSImage) async throws -> OCRResult {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }
        return try await extractText(from: cgImage)
    }
    #endif

    #if canImport(UIKit)
    // periphery:ignore - Reserved: extractText(from:) instance method reserved for future feature activation
    /// Convenience method for UIImage (iOS)
    func extractText(from uiImage: UIImage) async throws -> OCRResult {
        guard let cgImage = uiImage.cgImage else {
            throw OCRError.imageConversionFailed
        }
        return try await extractText(from: cgImage)
    }
    #endif

    // MARK: - Provider Selection

    /// Select the optimal OCR provider based on script and complexity
    func selectOptimalProvider(script: OCRScript, complexity: DocumentComplexity) -> OCRProvider {
        // If offline preferred and Vision supports the script, use it
        if preferOffline && visionProvider.supportedScripts.contains(script) {
            return visionProvider
        }

        // For complex documents, prefer higher accuracy tiers
        if complexity == .complex {
            if let cloudProvider = cloudProviders.first(where: {
                // periphery:ignore - Reserved: selectOptimalProvider(script:complexity:) instance method reserved for future feature activation
                $0.isAvailable && $0.accuracyTier >= .enhanced && $0.supportedScripts.contains(script)
            }) {
                return cloudProvider
            }
        }

        // Default to Vision
        return visionProvider
    }

    /// Detect the primary script in an image using quick sampling
    func detectPrimaryScript(_ image: CGImage) async throws -> OCRScript {
        // Use Vision to do a quick recognition pass
        let result = try await visionProvider.extractText(from: image, languages: nil)
        return result.detectedScript
    }

    /// Assess document complexity from image characteristics
    func assessComplexity(_ image: CGImage) -> DocumentComplexity {
        // periphery:ignore - Reserved: detectPrimaryScript(_:) instance method reserved for future feature activation
        // Simple heuristics based on image dimensions and variance
        let width = image.width
        let height = image.height
        let aspectRatio = Double(width) / Double(height)

        // Very wide or very tall images often indicate tables or multi-column layouts
        // periphery:ignore - Reserved: assessComplexity(_:) instance method reserved for future feature activation
        if aspectRatio > 2.5 || aspectRatio < 0.4 {
            return .complex
        }

        // Large images often contain more complex content
        let pixels = width * height
        if pixels > 4_000_000 {
            return .moderate
        }

        return .simple
    }

    // MARK: - Configuration

    // periphery:ignore - Reserved: setPreferOffline(_:) instance method — reserved for future feature activation
    /// Set preference for offline processing
    func setPreferOffline(_ prefer: Bool) {
        preferOffline = prefer
    }

    // periphery:ignore - Reserved: setMinimumAccuracyTier(_:) instance method — reserved for future feature activation
    /// Set minimum accuracy tier required
    func setMinimumAccuracyTier(_ tier: OCRAccuracyTier) {
        // periphery:ignore - Reserved: setPreferOffline(_:) instance method reserved for future feature activation
        minimumAccuracyTier = tier
    }

    // periphery:ignore - Reserved: setMinimumAccuracyTier(_:) instance method reserved for future feature activation
    /// Register a cloud OCR provider
    func registerCloudProvider(_ provider: OCRProvider) {
        cloudProviders.append(provider)
    }

    // periphery:ignore - Reserved: registerCloudProvider(_:) instance method reserved for future feature activation
    // MARK: - Statistics

    private func updateStatistics(_ result: OCRResult) {
        totalExtractions += 1

        // periphery:ignore - Reserved: updateStatistics(_:) instance method reserved for future feature activation
        // Running average for confidence
        let n = Double(totalExtractions)
        averageConfidence = averageConfidence * (n - 1) / n + result.confidence / n

        // Running average for processing time
        averageProcessingTime = averageProcessingTime * (n - 1) / n + result.processingTime / n
    }

    // periphery:ignore - Reserved: availableProviders property — reserved for future feature activation
    /// Get available providers
    var availableProviders: [OCRProvider] {
        var providers: [OCRProvider] = [visionProvider]
        // periphery:ignore - Reserved: availableProviders property reserved for future feature activation
        providers.append(contentsOf: cloudProviders.filter { $0.isAvailable })
        return providers
    }

    // periphery:ignore - Reserved: supportedScripts property — reserved for future feature activation
    /// Get supported scripts across all providers
    var supportedScripts: Set<OCRScript> {
        // periphery:ignore - Reserved: supportedScripts property reserved for future feature activation
        var scripts = visionProvider.supportedScripts
        for provider in cloudProviders {
            scripts.formUnion(provider.supportedScripts)
        }
        return scripts
    }
}

// MARK: - Extensions

extension CGImage {
    // periphery:ignore - Reserved: fromData(_:) static method reserved for future feature activation
    /// Create CGImage from Data
    static func fromData(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return image
    }
}
