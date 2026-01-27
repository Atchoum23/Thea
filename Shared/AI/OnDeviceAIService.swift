//
//  OnDeviceAIService.swift
//  Thea
//
//  Apple Foundation Models Framework Integration
//  Provides on-device AI capabilities using Apple's ~3B parameter model
//

import Combine
import Foundation

// MARK: - On-Device AI Service

/// Service for on-device AI inference using Apple's Foundation Models
@MainActor
public class OnDeviceAIService: ObservableObject {
    public static let shared = OnDeviceAIService()

    // MARK: - Published State

    @Published public private(set) var isAvailable = false
    @Published public private(set) var isProcessing = false
    @Published public private(set) var lastError: OnDeviceAIError?

    // MARK: - Configuration

    public var maxTokens: Int = 2048
    public var temperature: Double = 0.7

    // MARK: - Initialization

    private init() {
        Task {
            await checkAvailability()
        }
    }

    // MARK: - Availability Check

    /// Check if on-device AI is available
    public func checkAvailability() async {
        #if canImport(FoundationModels)
            // Foundation Models framework available in iOS 18.4+ / macOS 15.4+
            isAvailable = true
        #else
            isAvailable = false
        #endif
    }

    // MARK: - Text Generation

    /// Generate text using on-device AI
    public func generateText(
        prompt _: String,
        systemPrompt _: String? = nil,
        streaming _: Bool = false
    ) async throws -> String {
        guard isAvailable else {
            throw OnDeviceAIError.notAvailable
        }

        isProcessing = true
        defer { isProcessing = false }

        // Placeholder for Foundation Models integration
        // When iOS 18.4+ / macOS 15.4+ is available:
        // let session = LanguageModelSession()
        // let response = try await session.respond(to: prompt)
        // return response.content

        // For now, return a placeholder indicating the feature
        return "On-device AI response will be available when running on iOS 18.4+ / macOS 15.4+"
    }

    /// Generate streaming text using on-device AI
    public func generateTextStream(
        prompt: String,
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard isAvailable else {
                        throw OnDeviceAIError.notAvailable
                    }

                    // Placeholder for streaming implementation
                    let response = try await generateText(prompt: prompt, systemPrompt: systemPrompt)
                    continuation.yield(response)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Summarization

    /// Summarize text using on-device AI
    public func summarize(
        text: String,
        style: SummarizationStyle = .concise
    ) async throws -> String {
        let prompt = """
        Summarize the following text in a \(style.description) manner:

        \(text)
        """
        return try await generateText(prompt: prompt)
    }

    // MARK: - Entity Extraction

    /// Extract entities from text
    public func extractEntities(from text: String) async throws -> [OnDeviceExtractedEntity] {
        let prompt = """
        Extract all named entities (people, places, organizations, dates, etc.) from the following text.
        Return them in a structured format.

        Text: \(text)
        """

        let response = try await generateText(prompt: prompt)

        // Parse response into entities (simplified)
        return parseEntities(from: response)
    }

    private func parseEntities(from _: String) -> [OnDeviceExtractedEntity] {
        // Simplified entity parsing
        []
    }

    // MARK: - Text Refinement

    /// Refine and improve text
    public func refineText(
        text: String,
        style: RefinementStyle = .professional
    ) async throws -> String {
        let prompt = """
        Refine the following text to make it more \(style.description):

        \(text)
        """
        return try await generateText(prompt: prompt)
    }

    // MARK: - Quick Actions

    /// Fix grammar and spelling
    public func fixGrammar(text: String) async throws -> String {
        let prompt = "Fix any grammar and spelling errors in: \(text)"
        return try await generateText(prompt: prompt)
    }

    /// Make text more concise
    public func makeConcise(text: String) async throws -> String {
        let prompt = "Make this text more concise while keeping the meaning: \(text)"
        return try await generateText(prompt: prompt)
    }

    /// Translate text
    public func translate(text: String, to language: String) async throws -> String {
        let prompt = "Translate to \(language): \(text)"
        return try await generateText(prompt: prompt)
    }

    /// Generate creative variations
    public func generateVariations(
        text: String,
        count: Int = 3
    ) async throws -> [String] {
        let prompt = """
        Generate \(count) creative variations of the following text, each with a different tone or style:

        \(text)
        """
        let response = try await generateText(prompt: prompt)
        return response.components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }
}

// MARK: - Supporting Types

public enum SummarizationStyle: String, Sendable {
    case concise
    case detailed
    case bullets
    case keyPoints

    var description: String {
        switch self {
        case .concise: "concise and brief"
        case .detailed: "detailed and comprehensive"
        case .bullets: "bullet point format"
        case .keyPoints: "key points only"
        }
    }
}

public enum RefinementStyle: String, Sendable {
    case professional
    case casual
    case formal
    case creative
    case technical

    var description: String { rawValue }
}

public struct OnDeviceExtractedEntity: Identifiable, Sendable {
    public let id = UUID()
    public let text: String
    public let type: OnDeviceEntityType
    public let confidence: Double
}

public enum OnDeviceEntityType: String, Sendable {
    case person
    case place
    case organization
    case date
    case money
    case email
    case phone
    case url
    case other
}

// MARK: - Errors

public enum OnDeviceAIError: Error, LocalizedError, Sendable {
    case notAvailable
    case processingFailed(String)
    case quotaExceeded
    case invalidInput
    case modelNotLoaded

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            "On-device AI is not available on this device. Requires iOS 18.4+ or macOS 15.4+"
        case let .processingFailed(reason):
            "Processing failed: \(reason)"
        case .quotaExceeded:
            "On-device AI quota exceeded. Please try again later."
        case .invalidInput:
            "Invalid input provided"
        case .modelNotLoaded:
            "AI model is not loaded"
        }
    }
}
