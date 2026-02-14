// ProviderRequestFormattingTests.swift
// Tests for AI provider request formatting, role conversion, and response parsing
// Standalone test doubles — no dependency on actual providers or URLSession

import Testing
import Foundation

// MARK: - Test Doubles

/// Mirrors MessageRole used across providers
private enum TestMessageRole: String, Sendable {
    case user
    case assistant
    case system
}

/// Mirrors role conversion logic from OpenRouter/Groq/Perplexity
private func convertRoleStandard(_ role: TestMessageRole) -> String {
    switch role {
    case .user: return "user"
    case .assistant: return "assistant"
    case .system: return "system"
    }
}

/// Mirrors role conversion for Google (uses "model" for assistant)
private func convertRoleGoogle(_ role: TestMessageRole) -> String {
    switch role {
    case .user: return "user"
    case .assistant: return "model"
    case .system: return "system"
    }
}

/// Mirrors provider metadata
private struct TestProviderMetadata: Sendable {
    let name: String
    let displayName: String
    let maxContextTokens: Int
    let maxOutputTokens: Int
    let supportsStreaming: Bool
    let supportsVision: Bool
    let supportsFunctionCalling: Bool
    let supportsWebSearch: Bool
}

/// All provider metadata for verification
private let providerMetadata: [TestProviderMetadata] = [
    TestProviderMetadata(
        name: "anthropic", displayName: "Anthropic",
        maxContextTokens: 200_000, maxOutputTokens: 32_000,
        supportsStreaming: true, supportsVision: true,
        supportsFunctionCalling: true, supportsWebSearch: false
    ),
    TestProviderMetadata(
        name: "openrouter", displayName: "OpenRouter",
        maxContextTokens: 200_000, maxOutputTokens: 16_000,
        supportsStreaming: true, supportsVision: true,
        supportsFunctionCalling: true, supportsWebSearch: false
    ),
    TestProviderMetadata(
        name: "groq", displayName: "Groq",
        maxContextTokens: 32_000, maxOutputTokens: 8_000,
        supportsStreaming: true, supportsVision: false,
        supportsFunctionCalling: true, supportsWebSearch: false
    ),
    TestProviderMetadata(
        name: "google", displayName: "Google (Gemini)",
        maxContextTokens: 1_000_000, maxOutputTokens: 8_000,
        supportsStreaming: true, supportsVision: true,
        supportsFunctionCalling: true, supportsWebSearch: false
    ),
    TestProviderMetadata(
        name: "perplexity", displayName: "Perplexity",
        maxContextTokens: 127_000, maxOutputTokens: 4_000,
        supportsStreaming: true, supportsVision: false,
        supportsFunctionCalling: false, supportsWebSearch: true
    )
]

/// Mirrors OpenRouter Claude model detection
private func isClaudeModel(_ model: String) -> Bool {
    model.contains("claude") || model.contains("anthropic")
}

/// Mirrors streaming response line parsing (OpenAI-format)
private func parseStreamLine(_ line: String) -> String? {
    guard line.hasPrefix("data: ") else { return nil }
    let jsonStr = String(line.dropFirst(6))
    if jsonStr == "[DONE]" { return nil }
    guard let data = jsonStr.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let choices = json["choices"] as? [[String: Any]],
          let delta = choices.first?["delta"] as? [String: Any],
          let content = delta["content"] as? String else {
        return nil
    }
    return content
}

/// Mirrors Anthropic streaming response parsing
private func parseAnthropicStreamLine(_ line: String) -> String? {
    guard line.hasPrefix("data: ") else { return nil }
    let jsonStr = String(line.dropFirst(6))
    guard let data = jsonStr.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = json["type"] as? String,
          type == "content_block_delta",
          let delta = json["delta"] as? [String: Any],
          let text = delta["text"] as? String else {
        return nil
    }
    return text
}

/// Mirrors Google streaming response parsing
private func parseGoogleStreamLine(_ line: String) -> String? {
    guard let data = line.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let candidates = json["candidates"] as? [[String: Any]],
          let content = candidates.first?["content"] as? [String: Any],
          let parts = content["parts"] as? [[String: Any]],
          let text = parts.first?["text"] as? String else {
        return nil
    }
    return text
}

/// Mirrors HTTP status code classification for retry logic
private func isRetryable(_ statusCode: Int) -> Bool {
    [408, 429, 500, 502, 503, 504].contains(statusCode)
}

private func isClientError(_ statusCode: Int) -> Bool {
    [400, 401, 403, 404].contains(statusCode)
}

/// Mirrors AnthropicFileContent block builders
private struct TestFileContent {
    static func fileBlock(fileId: String) -> [String: Any] {
        ["type": "file", "file_id": fileId]
    }

    static func imageFromFile(fileId: String) -> [String: Any] {
        [
            "type": "image",
            "source": ["type": "file", "file_id": fileId] as [String: String]
        ]
    }

    static func documentFromFile(fileId: String) -> [String: Any] {
        [
            "type": "document",
            "source": ["type": "file", "file_id": fileId] as [String: String]
        ]
    }
}

/// Mirrors token counter context fit logic
private struct TestContextFitResult {
    let fits: Bool
    let inputTokens: Int
    let maxOutputTokens: Int
    let remainingCapacity: Int
    let contextLimit: Int

    init(inputTokens: Int, maxOutputTokens: Int, contextLimit: Int) {
        self.inputTokens = inputTokens
        self.maxOutputTokens = maxOutputTokens
        self.contextLimit = contextLimit
        let totalRequired = inputTokens + maxOutputTokens
        self.fits = totalRequired <= contextLimit
        self.remainingCapacity = contextLimit - inputTokens
    }
}

// MARK: - Tests

@Suite("Role Conversion — Standard (OpenAI-compatible)")
struct StandardRoleConversionTests {
    @Test("User role converts to 'user'")
    func userRole() {
        #expect(convertRoleStandard(.user) == "user")
    }

    @Test("Assistant role converts to 'assistant'")
    func assistantRole() {
        #expect(convertRoleStandard(.assistant) == "assistant")
    }

    @Test("System role converts to 'system'")
    func systemRole() {
        #expect(convertRoleStandard(.system) == "system")
    }
}

@Suite("Role Conversion — Google")
struct GoogleRoleConversionTests {
    @Test("User role converts to 'user'")
    func userRole() {
        #expect(convertRoleGoogle(.user) == "user")
    }

    @Test("Assistant role converts to 'model' (not 'assistant')")
    func assistantRole() {
        #expect(convertRoleGoogle(.assistant) == "model")
    }

    @Test("System role converts to 'system'")
    func systemRole() {
        #expect(convertRoleGoogle(.system) == "system")
    }
}

@Suite("Provider Metadata")
struct ProviderMetadataTests {
    @Test("All 5 providers defined")
    func allProviders() {
        #expect(providerMetadata.count == 5)
    }

    @Test("Provider names are unique")
    func uniqueNames() {
        let names = providerMetadata.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("All providers support streaming")
    func allSupportStreaming() {
        for provider in providerMetadata {
            #expect(provider.supportsStreaming, "\(provider.name) should support streaming")
        }
    }

    @Test("Anthropic has 200K context")
    func anthropicContext() {
        let anthropic = providerMetadata.first { $0.name == "anthropic" }!
        #expect(anthropic.maxContextTokens == 200_000)
        #expect(anthropic.maxOutputTokens == 32_000)
    }

    @Test("Google has 1M context")
    func googleContext() {
        let google = providerMetadata.first { $0.name == "google" }!
        #expect(google.maxContextTokens == 1_000_000)
    }

    @Test("Perplexity specializes in web search")
    func perplexityWebSearch() {
        let perplexity = providerMetadata.first { $0.name == "perplexity" }!
        #expect(perplexity.supportsWebSearch)
        #expect(!perplexity.supportsFunctionCalling)
        #expect(!perplexity.supportsVision)
    }

    @Test("Groq does not support vision")
    func groqNoVision() {
        let groq = providerMetadata.first { $0.name == "groq" }!
        #expect(!groq.supportsVision)
    }

    @Test("Output tokens always <= context tokens")
    func outputLteContext() {
        for provider in providerMetadata {
            #expect(provider.maxOutputTokens <= provider.maxContextTokens,
                    "\(provider.name) output should be <= context")
        }
    }

    @Test("All have positive context and output limits")
    func positiveLimits() {
        for provider in providerMetadata {
            #expect(provider.maxContextTokens > 0)
            #expect(provider.maxOutputTokens > 0)
        }
    }
}

@Suite("Claude Model Detection")
struct ClaudeModelDetectionTests {
    @Test("Claude model IDs detected")
    func claudeDetected() {
        #expect(isClaudeModel("claude-opus-4-5-20250929"))
        #expect(isClaudeModel("claude-sonnet-4-5-20250929"))
        #expect(isClaudeModel("claude-3-5-sonnet-20241022"))
    }

    @Test("Anthropic-prefixed models detected")
    func anthropicDetected() {
        #expect(isClaudeModel("anthropic/claude-opus-4-5"))
    }

    @Test("Non-Claude models not detected")
    func nonClaudeNotDetected() {
        #expect(!isClaudeModel("gpt-4o"))
        #expect(!isClaudeModel("gemini-2.0-flash"))
        #expect(!isClaudeModel("llama-3.3-70b"))
    }

    @Test("Case sensitive detection")
    func caseSensitive() {
        #expect(!isClaudeModel("CLAUDE-4"))
        #expect(!isClaudeModel("Claude-4"))
    }
}

@Suite("Streaming Response Parsing — OpenAI Format")
struct OpenAIStreamParsingTests {
    @Test("Valid content delta parsed")
    func validDelta() {
        let line = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}"
        #expect(parseStreamLine(line) == "Hello")
    }

    @Test("[DONE] marker returns nil")
    func doneMarker() {
        #expect(parseStreamLine("data: [DONE]") == nil)
    }

    @Test("Non-data line returns nil")
    func nonDataLine() {
        #expect(parseStreamLine("event: ping") == nil)
    }

    @Test("Empty content parsed")
    func emptyContent() {
        let line = "data: {\"choices\":[{\"delta\":{\"content\":\"\"}}]}"
        #expect(parseStreamLine(line) == "")
    }

    @Test("Missing content key returns nil")
    func missingContent() {
        let line = "data: {\"choices\":[{\"delta\":{}}]}"
        #expect(parseStreamLine(line) == nil)
    }

    @Test("Empty choices returns nil")
    func emptyChoices() {
        let line = "data: {\"choices\":[]}"
        #expect(parseStreamLine(line) == nil)
    }

    @Test("Malformed JSON returns nil")
    func malformedJSON() {
        #expect(parseStreamLine("data: {invalid}") == nil)
    }
}

@Suite("Streaming Response Parsing — Anthropic Format")
struct AnthropicStreamParsingTests {
    @Test("Content block delta parsed")
    func contentBlockDelta() {
        let line = "data: {\"type\":\"content_block_delta\",\"delta\":{\"text\":\"World\"}}"
        #expect(parseAnthropicStreamLine(line) == "World")
    }

    @Test("Non-delta type returns nil")
    func nonDeltaType() {
        let line = "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_123\"}}"
        #expect(parseAnthropicStreamLine(line) == nil)
    }

    @Test("Missing text in delta returns nil")
    func missingText() {
        let line = "data: {\"type\":\"content_block_delta\",\"delta\":{}}"
        #expect(parseAnthropicStreamLine(line) == nil)
    }
}

@Suite("Streaming Response Parsing — Google Format")
struct GoogleStreamParsingTests {
    @Test("Valid candidate parsed")
    func validCandidate() {
        let json = "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"Hi\"}]}}]}"
        #expect(parseGoogleStreamLine(json) == "Hi")
    }

    @Test("Empty candidates returns nil")
    func emptyCandidates() {
        #expect(parseGoogleStreamLine("{\"candidates\":[]}") == nil)
    }

    @Test("Missing parts returns nil")
    func missingParts() {
        let json = "{\"candidates\":[{\"content\":{}}]}"
        #expect(parseGoogleStreamLine(json) == nil)
    }
}

@Suite("HTTP Status Code Classification")
struct HTTPStatusCodeTests {
    @Test("Retryable status codes")
    func retryable() {
        #expect(isRetryable(408)) // Timeout
        #expect(isRetryable(429)) // Rate limited
        #expect(isRetryable(500)) // Internal server error
        #expect(isRetryable(502)) // Bad gateway
        #expect(isRetryable(503)) // Service unavailable
        #expect(isRetryable(504)) // Gateway timeout
    }

    @Test("Client errors are not retryable")
    func clientErrors() {
        #expect(!isRetryable(400))
        #expect(!isRetryable(401))
        #expect(!isRetryable(403))
        #expect(!isRetryable(404))
    }

    @Test("Success codes are not retryable")
    func successCodes() {
        #expect(!isRetryable(200))
        #expect(!isRetryable(201))
    }

    @Test("Client error classification")
    func clientErrorClassification() {
        #expect(isClientError(400))
        #expect(isClientError(401))
        #expect(isClientError(403))
        #expect(isClientError(404))
        #expect(!isClientError(500))
        #expect(!isClientError(200))
    }
}

@Suite("File Content Block Builders")
struct FileContentBlockTests {
    @Test("File block structure")
    func fileBlock() {
        let block = TestFileContent.fileBlock(fileId: "file-123")
        #expect(block["type"] as? String == "file")
        #expect(block["file_id"] as? String == "file-123")
    }

    @Test("Image from file structure")
    func imageFromFile() {
        let block = TestFileContent.imageFromFile(fileId: "file-456")
        #expect(block["type"] as? String == "image")
        let source = block["source"] as? [String: String]
        #expect(source?["type"] == "file")
        #expect(source?["file_id"] == "file-456")
    }

    @Test("Document from file structure")
    func documentFromFile() {
        let block = TestFileContent.documentFromFile(fileId: "file-789")
        #expect(block["type"] as? String == "document")
        let source = block["source"] as? [String: String]
        #expect(source?["type"] == "file")
        #expect(source?["file_id"] == "file-789")
    }
}

@Suite("Token Counter — Context Fit")
struct ContextFitTests {
    @Test("Input + output under limit fits")
    func underLimit() {
        let result = TestContextFitResult(inputTokens: 1000, maxOutputTokens: 4000, contextLimit: 200_000)
        #expect(result.fits)
        #expect(result.remainingCapacity == 199_000)
    }

    @Test("Input + output over limit does not fit")
    func overLimit() {
        let result = TestContextFitResult(inputTokens: 198_000, maxOutputTokens: 4000, contextLimit: 200_000)
        #expect(!result.fits)
    }

    @Test("Exactly at limit fits")
    func exactLimit() {
        let result = TestContextFitResult(inputTokens: 196_000, maxOutputTokens: 4000, contextLimit: 200_000)
        #expect(result.fits)
        #expect(result.remainingCapacity == 4000)
    }

    @Test("Zero input tokens")
    func zeroInput() {
        let result = TestContextFitResult(inputTokens: 0, maxOutputTokens: 4000, contextLimit: 200_000)
        #expect(result.fits)
        #expect(result.remainingCapacity == 200_000)
    }

    @Test("Remaining capacity can be negative when over limit")
    func negativeRemaining() {
        let result = TestContextFitResult(inputTokens: 210_000, maxOutputTokens: 4000, contextLimit: 200_000)
        #expect(!result.fits)
        #expect(result.remainingCapacity == -10_000)
    }
}
