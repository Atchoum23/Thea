import Foundation

// MARK: - AI Provider Protocol

protocol AIProvider: Sendable {
    var metadata: ProviderMetadata { get }
    var capabilities: ProviderCapabilities { get }

    func validateAPIKey(_ key: String) async throws -> ValidationResult
    func chat(messages: [AIMessage], model: String, stream: Bool) async throws -> AsyncThrowingStream<ChatResponse, Error>
    func listModels() async throws -> [AIModel]
}

// MARK: - Provider Metadata

struct ProviderMetadata: Codable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let logoURL: URL?
    let websiteURL: URL
    let documentationURL: URL

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        logoURL: URL? = nil,
        websiteURL: URL,
        documentationURL: URL
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.logoURL = logoURL
        self.websiteURL = websiteURL
        self.documentationURL = documentationURL
    }
}

// MARK: - Provider Capabilities

struct ProviderCapabilities: Codable, Sendable {
    let supportsStreaming: Bool
    let supportsVision: Bool
    let supportsFunctionCalling: Bool
    let supportsWebSearch: Bool
    let maxContextTokens: Int
    let maxOutputTokens: Int
    let supportedModalities: [Modality]

    enum Modality: String, Codable, Sendable {
        case text
        case image
        case audio
        case video
    }

    init(
        supportsStreaming: Bool = true,
        supportsVision: Bool = false,
        supportsFunctionCalling: Bool = false,
        supportsWebSearch: Bool = false,
        maxContextTokens: Int = 128_000,
        maxOutputTokens: Int = 4096,
        supportedModalities: [Modality] = [.text]
    ) {
        self.supportsStreaming = supportsStreaming
        self.supportsVision = supportsVision
        self.supportsFunctionCalling = supportsFunctionCalling
        self.supportsWebSearch = supportsWebSearch
        self.maxContextTokens = maxContextTokens
        self.maxOutputTokens = maxOutputTokens
        self.supportedModalities = supportedModalities
    }
}

// MARK: - Validation Result

struct ValidationResult: Sendable {
    let isValid: Bool
    let error: String?

    static func success() -> ValidationResult {
        ValidationResult(isValid: true, error: nil)
    }

    static func failure(_ error: String) -> ValidationResult {
        ValidationResult(isValid: false, error: error)
    }
}

// MARK: - Chat Response

struct ChatResponse: Sendable {
    enum ResponseType: Sendable {
        case delta(String) // Streaming chunk
        case complete(AIMessage) // Final message
        case error(Error)
    }

    let type: ResponseType

    static func delta(_ text: String) -> ChatResponse {
        ChatResponse(type: .delta(text))
    }

    static func complete(_ message: AIMessage) -> ChatResponse {
        ChatResponse(type: .complete(message))
    }

    static func error(_ error: Error) -> ChatResponse {
        ChatResponse(type: .error(error))
    }
}

// MARK: - AI Model

struct AIModel: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let contextWindow: Int
    let maxOutputTokens: Int
    let inputPricePerMillion: Decimal
    let outputPricePerMillion: Decimal
    let supportsVision: Bool
    let supportsFunctionCalling: Bool

    init(
        id: String,
        name: String,
        description: String? = nil,
        contextWindow: Int,
        maxOutputTokens: Int,
        inputPricePerMillion: Decimal,
        outputPricePerMillion: Decimal,
        supportsVision: Bool = false,
        supportsFunctionCalling: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.inputPricePerMillion = inputPricePerMillion
        self.outputPricePerMillion = outputPricePerMillion
        self.supportsVision = supportsVision
        self.supportsFunctionCalling = supportsFunctionCalling
    }
}
