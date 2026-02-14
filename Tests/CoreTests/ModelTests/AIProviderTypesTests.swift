import Foundation
import XCTest

/// Standalone tests for AI Provider types:
/// AnthropicError, AnthropicChatOptions, ProviderInfo, ChatResponse,
/// provider model definitions, and request formatting logic.
/// Mirrors types from AI/Providers/*.swift and Core/Managers/ProviderRegistry.swift.
final class AIProviderTypesTests: XCTestCase {

    // MARK: - AnthropicError (mirror AnthropicProvider.swift)

    enum AnthropicError: Error, LocalizedError {
        case invalidResponse
        case invalidResponseDetails(String)
        case noResponse
        case serverError(status: Int, message: String?)
        case fileTooLarge(bytes: Int, maxBytes: Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                "Invalid response from Anthropic API"
            case .invalidResponseDetails(let details):
                "Invalid response: \(details)"
            case .noResponse:
                "No response received from Anthropic API"
            case .serverError(let status, let message):
                if let msg = message {
                    "Server error (\(status)): \(msg)"
                } else {
                    "Server error (\(status))"
                }
            case .fileTooLarge(let bytes, let maxBytes):
                "File too large: \(bytes) bytes exceeds limit of \(maxBytes) bytes"
            }
        }
    }

    func testAnthropicErrorDescriptions() {
        XCTAssertEqual(AnthropicError.invalidResponse.errorDescription,
                       "Invalid response from Anthropic API")
        XCTAssertEqual(AnthropicError.noResponse.errorDescription,
                       "No response received from Anthropic API")
    }

    func testAnthropicErrorDetailsMessage() {
        let error = AnthropicError.invalidResponseDetails("Missing content block")
        XCTAssertTrue(error.errorDescription?.contains("Missing content block") ?? false)
    }

    func testAnthropicErrorServerErrorWithMessage() {
        let error = AnthropicError.serverError(status: 500, message: "Internal server error")
        XCTAssertTrue(error.errorDescription?.contains("500") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("Internal server error") ?? false)
    }

    func testAnthropicErrorServerErrorWithoutMessage() {
        let error = AnthropicError.serverError(status: 503, message: nil)
        XCTAssertTrue(error.errorDescription?.contains("503") ?? false)
    }

    func testAnthropicErrorFileTooLarge() {
        let error = AnthropicError.fileTooLarge(bytes: 50_000_000, maxBytes: 32_000_000)
        XCTAssertTrue(error.errorDescription?.contains("50000000") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("32000000") ?? false)
    }

    func testAnthropicErrorConformsToError() {
        let error: Error = AnthropicError.invalidResponse
        XCTAssertNotNil(error.localizedDescription)
    }

    // MARK: - HTTP Status Code Classification

    func classifyHTTPError(statusCode: Int) -> String {
        switch statusCode {
        case 400: return "invalidRequest"
        case 401: return "unauthorized"
        case 403: return "forbidden"
        case 404: return "notFound"
        case 429: return "rateLimited"
        case 500...599: return "serverError"
        default: return "unknown"
        }
    }

    func testHTTPErrorClassification() {
        XCTAssertEqual(classifyHTTPError(statusCode: 400), "invalidRequest")
        XCTAssertEqual(classifyHTTPError(statusCode: 401), "unauthorized")
        XCTAssertEqual(classifyHTTPError(statusCode: 403), "forbidden")
        XCTAssertEqual(classifyHTTPError(statusCode: 404), "notFound")
        XCTAssertEqual(classifyHTTPError(statusCode: 429), "rateLimited")
        XCTAssertEqual(classifyHTTPError(statusCode: 500), "serverError")
        XCTAssertEqual(classifyHTTPError(statusCode: 502), "serverError")
        XCTAssertEqual(classifyHTTPError(statusCode: 503), "serverError")
        XCTAssertEqual(classifyHTTPError(statusCode: 200), "unknown")
    }

    // MARK: - Retryable Status Codes

    func isRetryableStatusCode(_ code: Int) -> Bool {
        [408, 429, 500, 502, 503, 504].contains(code)
    }

    func testRetryableStatusCodes() {
        XCTAssertTrue(isRetryableStatusCode(408), "Timeout should be retryable")
        XCTAssertTrue(isRetryableStatusCode(429), "Rate limit should be retryable")
        XCTAssertTrue(isRetryableStatusCode(500), "Internal error should be retryable")
        XCTAssertTrue(isRetryableStatusCode(502), "Bad gateway should be retryable")
        XCTAssertTrue(isRetryableStatusCode(503), "Unavailable should be retryable")
        XCTAssertTrue(isRetryableStatusCode(504), "Gateway timeout should be retryable")
    }

    func testNonRetryableStatusCodes() {
        XCTAssertFalse(isRetryableStatusCode(400), "Bad request should NOT be retryable")
        XCTAssertFalse(isRetryableStatusCode(401), "Unauthorized should NOT be retryable")
        XCTAssertFalse(isRetryableStatusCode(403), "Forbidden should NOT be retryable")
        XCTAssertFalse(isRetryableStatusCode(404), "Not found should NOT be retryable")
    }

    // MARK: - ProviderInfo (mirror ProviderRegistry.swift)

    struct ProviderInfo: Identifiable {
        let id: String
        let name: String
        let displayName: String
        let requiresAPIKey: Bool
        let isConfigured: Bool
    }

    func testProviderInfoCreation() {
        let provider = ProviderInfo(
            id: "anthropic", name: "anthropic",
            displayName: "Anthropic", requiresAPIKey: true,
            isConfigured: true
        )
        XCTAssertEqual(provider.id, "anthropic")
        XCTAssertEqual(provider.displayName, "Anthropic")
        XCTAssertTrue(provider.requiresAPIKey)
        XCTAssertTrue(provider.isConfigured)
    }

    func testProviderInfoUnconfigured() {
        let provider = ProviderInfo(
            id: "groq", name: "groq",
            displayName: "Groq", requiresAPIKey: true,
            isConfigured: false
        )
        XCTAssertFalse(provider.isConfigured)
    }

    func testAllBuiltInProviderIDs() {
        let expectedIDs = ["openai", "anthropic", "google", "perplexity", "openrouter", "groq"]
        for id in expectedIDs {
            let provider = ProviderInfo(id: id, name: id, displayName: id.capitalized,
                                        requiresAPIKey: true, isConfigured: false)
            XCTAssertEqual(provider.id, id)
        }
    }

    func testProviderIDsUnique() {
        let ids = ["openai", "anthropic", "google", "perplexity", "openrouter", "groq"]
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "All provider IDs should be unique")
    }

    // MARK: - Provider Model Definitions (mirror AnthropicProvider.swift)

    struct ProviderAIModel: Sendable {
        let id: String
        let name: String
        let contextWindow: Int
        let maxOutputTokens: Int
        let supportsVision: Bool
        let supportsFunctionCalling: Bool
    }

    func testClaudeOpus45Model() {
        let opus = ProviderAIModel(
            id: "claude-opus-4-5-20250929", name: "Claude Opus 4.5",
            contextWindow: 200_000, maxOutputTokens: 32_000,
            supportsVision: true, supportsFunctionCalling: true
        )
        XCTAssertEqual(opus.contextWindow, 200_000)
        XCTAssertEqual(opus.maxOutputTokens, 32_000)
        XCTAssertTrue(opus.supportsVision)
        XCTAssertTrue(opus.supportsFunctionCalling)
    }

    func testClaudeSonnet45Model() {
        let sonnet = ProviderAIModel(
            id: "claude-sonnet-4-5-20250929", name: "Claude Sonnet 4.5",
            contextWindow: 200_000, maxOutputTokens: 32_000,
            supportsVision: true, supportsFunctionCalling: true
        )
        XCTAssertEqual(sonnet.contextWindow, 200_000)
    }

    func testClaudeHaiku45Model() {
        let haiku = ProviderAIModel(
            id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5",
            contextWindow: 200_000, maxOutputTokens: 32_000,
            supportsVision: true, supportsFunctionCalling: true
        )
        XCTAssertTrue(haiku.supportsVision)
    }

    func testClaude35SonnetModel() {
        let sonnet35 = ProviderAIModel(
            id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet",
            contextWindow: 200_000, maxOutputTokens: 8_000,
            supportsVision: true, supportsFunctionCalling: true
        )
        XCTAssertEqual(sonnet35.maxOutputTokens, 8_000)
    }

    // MARK: - ChatResponse Stream Types (mirror AnthropicProvider.swift)

    enum ChatResponse {
        case delta(String)
        case complete(String)
        case error(Error)
    }

    func testChatResponseDelta() {
        let response = ChatResponse.delta("Hello")
        if case .delta(let text) = response {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected delta")
        }
    }

    func testChatResponseComplete() {
        let response = ChatResponse.complete("Full response")
        if case .complete(let text) = response {
            XCTAssertEqual(text, "Full response")
        } else {
            XCTFail("Expected complete")
        }
    }

    func testChatResponseError() {
        let response = ChatResponse.error(AnthropicError.noResponse)
        if case .error(let error) = response {
            XCTAssertTrue(error is AnthropicError)
        } else {
            XCTFail("Expected error")
        }
    }

    // MARK: - Provider Selection Logic (mirror ProviderRegistry.swift)

    enum LocalModelPreference: String {
        case always
        case prefer
        case balanced
        case cloudFirst
    }

    enum QueryComplexity: String {
        case simple
        case moderate
        case complex
    }

    func selectProvider(preference: LocalModelPreference, complexity: QueryComplexity,
                        hasLocal: Bool, hasCloud: Bool) -> String {
        switch (preference, complexity) {
        case (.always, _):
            return hasLocal ? "local" : "none"
        case (.prefer, _):
            return hasLocal ? "local" : (hasCloud ? "cloud" : "none")
        case (.balanced, .simple):
            return hasLocal ? "local" : (hasCloud ? "cloud" : "none")
        case (.balanced, .moderate), (.balanced, .complex):
            return hasCloud ? "cloud" : (hasLocal ? "local" : "none")
        case (.cloudFirst, _):
            return hasCloud ? "cloud" : (hasLocal ? "local" : "none")
        }
    }

    func testProviderSelectionAlwaysLocal() {
        XCTAssertEqual(selectProvider(preference: .always, complexity: .complex,
                                       hasLocal: true, hasCloud: true), "local")
        XCTAssertEqual(selectProvider(preference: .always, complexity: .simple,
                                       hasLocal: false, hasCloud: true), "none")
    }

    func testProviderSelectionPreferLocal() {
        XCTAssertEqual(selectProvider(preference: .prefer, complexity: .complex,
                                       hasLocal: true, hasCloud: true), "local")
        XCTAssertEqual(selectProvider(preference: .prefer, complexity: .complex,
                                       hasLocal: false, hasCloud: true), "cloud")
    }

    func testProviderSelectionBalancedSimple() {
        XCTAssertEqual(selectProvider(preference: .balanced, complexity: .simple,
                                       hasLocal: true, hasCloud: true), "local")
    }

    func testProviderSelectionBalancedComplex() {
        XCTAssertEqual(selectProvider(preference: .balanced, complexity: .complex,
                                       hasLocal: true, hasCloud: true), "cloud")
        XCTAssertEqual(selectProvider(preference: .balanced, complexity: .moderate,
                                       hasLocal: true, hasCloud: true), "cloud")
    }

    func testProviderSelectionCloudFirst() {
        XCTAssertEqual(selectProvider(preference: .cloudFirst, complexity: .simple,
                                       hasLocal: true, hasCloud: true), "cloud")
        XCTAssertEqual(selectProvider(preference: .cloudFirst, complexity: .simple,
                                       hasLocal: true, hasCloud: false), "local")
    }

    func testProviderSelectionNoProviders() {
        XCTAssertEqual(selectProvider(preference: .balanced, complexity: .simple,
                                       hasLocal: false, hasCloud: false), "none")
    }

    // MARK: - Cloud Provider Fallback Order (mirror ProviderRegistry.swift)

    func getCloudProviderFallback(defaultProvider: String?,
                                  available: Set<String>) -> String? {
        let fallbackOrder = [defaultProvider, "openrouter", "openai", "anthropic"]
            .compactMap { $0 }

        for provider in fallbackOrder {
            if available.contains(provider) { return provider }
        }
        return available.first
    }

    func testCloudProviderFallbackUsesDefault() {
        let result = getCloudProviderFallback(
            defaultProvider: "groq",
            available: ["groq", "openai", "anthropic"]
        )
        XCTAssertEqual(result, "groq")
    }

    func testCloudProviderFallbackToOpenRouter() {
        let result = getCloudProviderFallback(
            defaultProvider: nil,
            available: ["openrouter", "openai"]
        )
        XCTAssertEqual(result, "openrouter")
    }

    func testCloudProviderFallbackToOpenAI() {
        let result = getCloudProviderFallback(
            defaultProvider: nil,
            available: ["openai", "google"]
        )
        XCTAssertEqual(result, "openai")
    }

    func testCloudProviderFallbackToAnthropic() {
        let result = getCloudProviderFallback(
            defaultProvider: nil,
            available: ["anthropic", "perplexity"]
        )
        XCTAssertEqual(result, "anthropic")
    }

    func testCloudProviderFallbackToAnyAvailable() {
        let result = getCloudProviderFallback(
            defaultProvider: nil,
            available: ["perplexity"]
        )
        XCTAssertEqual(result, "perplexity")
    }

    func testCloudProviderFallbackNoneAvailable() {
        let result = getCloudProviderFallback(
            defaultProvider: nil,
            available: []
        )
        XCTAssertNil(result)
    }
}
