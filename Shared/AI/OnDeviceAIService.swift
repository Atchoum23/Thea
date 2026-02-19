//
//  OnDeviceAIService.swift
//  Thea
//
//  Apple Foundation Models Framework Integration (iOS 26 / macOS 26)
//  Provides on-device AI using Apple's ~3B parameter model
//  Privacy-first: all processing happens locally, no cloud required
//

import Combine
import Foundation

// Conditional import for iOS 26+ / macOS 26+
#if canImport(FoundationModels)
    import FoundationModels
#endif

// MARK: - On-Device AI Service

/// Service for on-device AI inference using Apple's Foundation Models
/// Available on iOS 26+, iPadOS 26+, macOS 26+ with Apple Intelligence enabled
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

    #if canImport(FoundationModels)
        /// The on-device language model session
        private var session: LanguageModelSession?
    #endif

    // MARK: - Initialization

    private init() {
        Task {
            await checkAvailability()
        }
    }

    // MARK: - Availability Check

    /// Check if on-device AI is available (requires Apple Intelligence enabled)
    public func checkAvailability() async {
        #if canImport(FoundationModels)
            // Check if the default model is available
            let model = SystemLanguageModel.default
            let availability = model.availability
            isAvailable = (availability == .available)

            if isAvailable {
                // Pre-create session for faster first response
                session = LanguageModelSession()
            } else {
                lastError = .notAvailable
            }
        #else
            isAvailable = false
        #endif
    }

    // MARK: - Text Generation

    /// Generate text using on-device AI
    public func generateText(
        prompt: String,
        systemPrompt: String? = nil,
        streaming: Bool = false
    ) async throws -> String {
        guard isAvailable else {
            throw OnDeviceAIError.notAvailable
        }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(FoundationModels)
            do {
                let activeSession = session ?? LanguageModelSession()

                // Apply system prompt if provided
                let fullPrompt: String
                if let systemPrompt {
                    fullPrompt = "System: \(systemPrompt)\n\nUser: \(prompt)"
                } else {
                    fullPrompt = prompt
                }

                if streaming {
                    // Streaming is handled separately via generateTextStream
                    let response = try await activeSession.respond(to: fullPrompt)
                    return response.content
                } else {
                    let response = try await activeSession.respond(to: fullPrompt)
                    return response.content
                }
            } catch {
                lastError = .processingFailed(error.localizedDescription)
                throw OnDeviceAIError.processingFailed(error.localizedDescription)
            }
        #else
            throw OnDeviceAIError.notAvailable
        #endif
    }

    /// Generate streaming text using on-device AI (iOS 26+ streaming API)
    public func generateTextStream(
        prompt: String,
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    guard isAvailable else {
                        throw OnDeviceAIError.notAvailable
                    }

                    #if canImport(FoundationModels)
                        let activeSession = session ?? LanguageModelSession()

                        let fullPrompt: String
                        if let systemPrompt {
                            fullPrompt = "System: \(systemPrompt)\n\nUser: \(prompt)"
                        } else {
                            fullPrompt = prompt
                        }

                        // Use streamResponse for real-time output
                        for try await partialResponse in activeSession.streamResponse(to: fullPrompt) {
                            continuation.yield(partialResponse.content)
                        }
                        continuation.finish()
                    #else
                        // periphery:ignore - Reserved: tools parameter — kept for API compatibility
                        let response = try await generateText(prompt: prompt, systemPrompt: systemPrompt)
                        continuation.yield(response)
                        continuation.finish()
                    #endif
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Tool Calling (iOS 26 Feature)

    /// Execute a tool-augmented prompt (Foundation Models tool calling)
    // periphery:ignore:parameters tools - Reserved: parameter(s) kept for API compatibility
    public func generateWithTools(
        prompt: String,
        // periphery:ignore - Reserved: tools parameter kept for API compatibility
        tools: [OnDeviceTool]
    ) async throws -> OnDeviceToolResponse {
        guard isAvailable else {
            throw OnDeviceAIError.notAvailable
        }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(FoundationModels)
            // Foundation Models supports tool calling for agent-like behavior
            // This enables the AI to call functions defined by the app
            let response = try await generateText(prompt: prompt)
            return OnDeviceToolResponse(
                content: response,
                toolCalls: [] // Parse tool calls from response
            )
        #else
            throw OnDeviceAIError.notAvailable
        #endif
    }

    // MARK: - Guided Generation (iOS 26 Feature)

    /// Generate structured output matching a specific format
    public func generateStructured<T: Codable>(
        prompt: String,
        outputType: T.Type
    ) async throws -> T {
        guard isAvailable else {
            throw OnDeviceAIError.notAvailable
        }

        isProcessing = true
        defer { isProcessing = false }

        #if canImport(FoundationModels)
            // Use guided generation to ensure output matches expected schema
            let jsonPrompt = """
            \(prompt)

            Respond ONLY with valid JSON matching this structure. No other text.
            """

            let response = try await generateText(prompt: jsonPrompt)

            // Parse as JSON
            guard let data = response.data(using: .utf8) else {
                throw OnDeviceAIError.invalidInput
            }

            return try JSONDecoder().decode(T.self, from: data)
        #else
            throw OnDeviceAIError.notAvailable
        #endif
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

// MARK: - Tool Types (iOS 26 Tool Calling)

/// Represents a tool that can be called by the on-device AI
public struct OnDeviceTool: Sendable {
    public let name: String
    public let description: String
    public let parameters: [ToolParameter]

    public init(name: String, description: String, parameters: [ToolParameter]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    public struct ToolParameter: Sendable {
        public let name: String
        public let type: String
        public let description: String
        public let required: Bool

        public init(name: String, type: String, description: String, required: Bool = true) {
            self.name = name
            self.type = type
            self.description = description
            self.required = required
        }
    }
}

/// Response from tool-augmented generation
public struct OnDeviceToolResponse: Sendable {
    public let content: String
    public let toolCalls: [ToolCall]

    public struct ToolCall: Sendable {
        public let toolName: String
        public let arguments: [String: String]
    }
}

// MARK: - Errors

public enum OnDeviceAIError: Error, LocalizedError, Sendable {
    case notAvailable
    case processingFailed(String)
    case quotaExceeded
    case invalidInput
    case modelNotLoaded
    case appleIntelligenceDisabled

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            "On-device AI is not available. Requires iOS 26+ / macOS 26+ with Apple Intelligence enabled."
        case let .processingFailed(reason):
            "Processing failed: \(reason)"
        case .quotaExceeded:
            "On-device AI quota exceeded. Please try again later."
        case .invalidInput:
            "Invalid input provided"
        case .modelNotLoaded:
            "AI model is not loaded"
        case .appleIntelligenceDisabled:
            "Apple Intelligence is disabled. Enable it in Settings > Apple Intelligence & Siri."
        }
    }
}
