// ExportAndErrorHandlingTests.swift
// Tests for ConversationExporter logic and error handling patterns
// Standalone test doubles — no dependency on actual implementations

import Testing
import Foundation

// MARK: - Export Test Doubles

/// Mirrors ExportFormat from ConversationExporter
private enum TestExportFormat: String, CaseIterable, Sendable {
    case markdown
    case json
    case plainText

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .json: return "json"
        case .plainText: return "txt"
        }
    }

    var mimeType: String {
        switch self {
        case .markdown: return "text/markdown"
        case .json: return "application/json"
        case .plainText: return "text/plain"
        }
    }
}

/// Mirrors export message structure
// swiftlint:disable:next private_over_fileprivate
fileprivate struct TestExportMessage: Sendable {
    let role: String // "user" or "assistant"
    let content: String
    let timestamp: Date
    let deviceName: String?
}

/// Mirrors markdown export formatting
private func exportAsMarkdown(
    title: String,
    messages: [TestExportMessage],
    includeTimestamps: Bool
) -> String {
    var lines: [String] = []
    lines.append("# \(title)")
    lines.append("")

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short

    for msg in messages {
        let prefix = msg.role == "user" ? "**User**" : "**Assistant**"
        if includeTimestamps {
            lines.append("\(prefix) — \(formatter.string(from: msg.timestamp))")
        } else {
            lines.append(prefix)
        }
        lines.append("")
        lines.append(msg.content)
        lines.append("")
        lines.append("---")
        lines.append("")
    }

    return lines.joined(separator: "\n")
}

/// Mirrors plaintext export formatting
private func exportAsPlainText(
    title: String,
    messages: [TestExportMessage]
) -> String {
    var lines: [String] = []
    lines.append(title)
    lines.append(String(repeating: "=", count: title.count))
    lines.append("")

    for msg in messages {
        let prefix = msg.role == "user" ? "You" : "Thea"
        lines.append("[\(prefix)]")
        lines.append(msg.content)
        lines.append("")
    }

    return lines.joined(separator: "\n")
}

/// Mirrors JSON export structure
private struct TestExportConversation: Codable, Sendable {
    let title: String
    let exportedAt: Date
    let messageCount: Int
    let messages: [TestExportMessageJSON]
}

private struct TestExportMessageJSON: Codable, Sendable {
    let role: String
    let content: String
    let timestamp: Date
    let deviceName: String?
}

// MARK: - Error Handling Test Doubles

/// Mirrors ErrorBannerType from ErrorBannerView
private enum TestErrorBannerType: Sendable {
    case rateLimited(retryAfter: TimeInterval?)
    case authError(provider: String)
    case networkError
    case serverError(statusCode: Int)
    case unknown(message: String)

    var title: String {
        switch self {
        case .rateLimited: return "Rate Limited"
        case .authError: return "Authentication Error"
        case .networkError: return "Network Unavailable"
        case .serverError: return "Server Error"
        case .unknown: return "Error"
        }
    }

    var message: String {
        switch self {
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Please wait \(Int(seconds)) seconds before trying again."
            }
            return "Please wait before trying again."
        case .authError(let provider):
            return "Check your \(provider) API key in Settings."
        case .networkError:
            return "Check your internet connection and try again."
        case .serverError(let code):
            return "The server returned error \(code). Please try again later."
        case .unknown(let msg):
            return msg
        }
    }

    var icon: String {
        switch self {
        case .rateLimited: return "clock.badge.exclamationmark"
        case .authError: return "key"
        case .networkError: return "wifi.slash"
        case .serverError: return "exclamationmark.icloud"
        case .unknown: return "exclamationmark.triangle"
        }
    }

    var showRetry: Bool {
        switch self {
        case .rateLimited, .networkError, .serverError:
            return true
        case .authError, .unknown:
            return false
        }
    }

    var showSettings: Bool {
        if case .authError = self { return true }
        return false
    }
}

/// Mirrors settings validation from SettingsManager
private struct TestSettingsValidator {
    static func validateFontSize(_ value: Double) -> Double {
        min(max(value, 0.5), 2.0)
    }

    static func validateProvider(_ provider: String, registered: [String]) -> String {
        registered.contains(provider) ? provider : "openrouter"
    }

    static func validateMaxConcurrent(_ value: Int) -> Int {
        min(max(value, 1), 16)
    }
}

// MARK: - Export Format Tests

@Suite("ExportFormat")
struct ExportFormatTests {
    @Test("All 3 formats exist")
    func allFormats() {
        #expect(TestExportFormat.allCases.count == 3)
    }

    @Test("File extensions are correct")
    func fileExtensions() {
        #expect(TestExportFormat.markdown.fileExtension == "md")
        #expect(TestExportFormat.json.fileExtension == "json")
        #expect(TestExportFormat.plainText.fileExtension == "txt")
    }

    @Test("MIME types are correct")
    func mimeTypes() {
        #expect(TestExportFormat.markdown.mimeType == "text/markdown")
        #expect(TestExportFormat.json.mimeType == "application/json")
        #expect(TestExportFormat.plainText.mimeType == "text/plain")
    }

    @Test("File extensions are unique")
    func uniqueExtensions() {
        let exts = TestExportFormat.allCases.map(\.fileExtension)
        #expect(Set(exts).count == exts.count)
    }
}

@Suite("Markdown Export")
struct MarkdownExportTests {
    private var messages: [TestExportMessage] {
        [
            TestExportMessage(role: "user", content: "Hello!", timestamp: Date(), deviceName: "msm3u"),
            TestExportMessage(role: "assistant", content: "Hi there!", timestamp: Date(), deviceName: nil)
        ]
    }

    @Test("Export includes title as H1")
    func titleAsH1() {
        let result = exportAsMarkdown(title: "Test Chat", messages: messages, includeTimestamps: false)
        #expect(result.hasPrefix("# Test Chat"))
    }

    @Test("Export includes user label")
    func userLabel() {
        let result = exportAsMarkdown(title: "Chat", messages: messages, includeTimestamps: false)
        #expect(result.contains("**User**"))
    }

    @Test("Export includes assistant label")
    func assistantLabel() {
        let result = exportAsMarkdown(title: "Chat", messages: messages, includeTimestamps: false)
        #expect(result.contains("**Assistant**"))
    }

    @Test("Export includes message content")
    func messageContent() {
        let result = exportAsMarkdown(title: "Chat", messages: messages, includeTimestamps: false)
        #expect(result.contains("Hello!"))
        #expect(result.contains("Hi there!"))
    }

    @Test("Export includes dividers")
    func dividers() {
        let result = exportAsMarkdown(title: "Chat", messages: messages, includeTimestamps: false)
        #expect(result.contains("---"))
    }

    @Test("Empty messages produces title only")
    func emptyMessages() {
        let result = exportAsMarkdown(title: "Empty Chat", messages: [], includeTimestamps: false)
        #expect(result.contains("# Empty Chat"))
        #expect(!result.contains("**User**"))
    }
}

@Suite("PlainText Export")
struct PlainTextExportTests {
    private var messages: [TestExportMessage] {
        [
            TestExportMessage(role: "user", content: "Question", timestamp: Date(), deviceName: nil),
            TestExportMessage(role: "assistant", content: "Answer", timestamp: Date(), deviceName: nil)
        ]
    }

    @Test("Export includes title with underline")
    func titleWithUnderline() {
        let result = exportAsPlainText(title: "My Chat", messages: messages)
        #expect(result.contains("My Chat"))
        #expect(result.contains("======="))
    }

    @Test("User shown as 'You'")
    func userAsYou() {
        let result = exportAsPlainText(title: "Chat", messages: messages)
        #expect(result.contains("[You]"))
    }

    @Test("Assistant shown as 'Thea'")
    func assistantAsThea() {
        let result = exportAsPlainText(title: "Chat", messages: messages)
        #expect(result.contains("[Thea]"))
    }
}

@Suite("JSON Export")
struct JSONExportTests {
    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let original = TestExportConversation(
            title: "Test",
            exportedAt: Date(),
            messageCount: 2,
            messages: [
                TestExportMessageJSON(role: "user", content: "Hi", timestamp: Date(), deviceName: "msm3u"),
                TestExportMessageJSON(role: "assistant", content: "Hello", timestamp: Date(), deviceName: nil)
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestExportConversation.self, from: data)
        #expect(decoded.title == original.title)
        #expect(decoded.messageCount == original.messageCount)
        #expect(decoded.messages.count == 2)
    }
}

// MARK: - Error Banner Tests

@Suite("ErrorBannerType")
struct ErrorBannerTypeTests {
    @Test("Rate limited with retry time")
    func rateLimitedWithTime() {
        let error = TestErrorBannerType.rateLimited(retryAfter: 30)
        #expect(error.title == "Rate Limited")
        #expect(error.message.contains("30 seconds"))
        #expect(error.showRetry)
        #expect(!error.showSettings)
    }

    @Test("Rate limited without retry time")
    func rateLimitedNoTime() {
        let error = TestErrorBannerType.rateLimited(retryAfter: nil)
        #expect(error.message.contains("wait"))
        #expect(!error.message.contains("seconds"))
    }

    @Test("Auth error shows provider name and settings link")
    func authError() {
        let error = TestErrorBannerType.authError(provider: "Anthropic")
        #expect(error.title == "Authentication Error")
        #expect(error.message.contains("Anthropic"))
        #expect(error.showSettings)
        #expect(!error.showRetry)
    }

    @Test("Network error shows retry")
    func networkError() {
        let error = TestErrorBannerType.networkError
        #expect(error.title == "Network Unavailable")
        #expect(error.showRetry)
        #expect(!error.showSettings)
    }

    @Test("Server error includes status code")
    func serverError() {
        let error = TestErrorBannerType.serverError(statusCode: 503)
        #expect(error.message.contains("503"))
        #expect(error.showRetry)
    }

    @Test("Unknown error shows custom message")
    func unknownError() {
        let error = TestErrorBannerType.unknown(message: "Something broke")
        #expect(error.message == "Something broke")
        #expect(!error.showRetry)
        #expect(!error.showSettings)
    }

    @Test("All error types have icons")
    func allHaveIcons() {
        let errors: [TestErrorBannerType] = [
            .rateLimited(retryAfter: nil), .authError(provider: "X"),
            .networkError, .serverError(statusCode: 500), .unknown(message: "X")
        ]
        for error in errors {
            #expect(!error.icon.isEmpty)
        }
    }

    @Test("All error types have non-empty titles")
    func allHaveTitles() {
        let errors: [TestErrorBannerType] = [
            .rateLimited(retryAfter: nil), .authError(provider: "X"),
            .networkError, .serverError(statusCode: 500), .unknown(message: "X")
        ]
        for error in errors {
            #expect(!error.title.isEmpty)
        }
    }
}

// MARK: - Settings Validation Tests

@Suite("Settings Validation")
struct SettingsValidationTests {
    @Test("Font size clamped to 0.5-2.0")
    func fontSizeClamping() {
        #expect(TestSettingsValidator.validateFontSize(0.1) == 0.5)
        #expect(TestSettingsValidator.validateFontSize(0.5) == 0.5)
        #expect(TestSettingsValidator.validateFontSize(1.0) == 1.0)
        #expect(TestSettingsValidator.validateFontSize(2.0) == 2.0)
        #expect(TestSettingsValidator.validateFontSize(3.0) == 2.0)
    }

    @Test("Provider validated against registered list")
    func providerValidation() {
        let registered = ["anthropic", "openrouter", "groq"]
        #expect(TestSettingsValidator.validateProvider("anthropic", registered: registered) == "anthropic")
        #expect(TestSettingsValidator.validateProvider("unknown", registered: registered) == "openrouter")
    }

    @Test("Max concurrent clamped to 1-16")
    func maxConcurrentClamping() {
        #expect(TestSettingsValidator.validateMaxConcurrent(0) == 1)
        #expect(TestSettingsValidator.validateMaxConcurrent(1) == 1)
        #expect(TestSettingsValidator.validateMaxConcurrent(8) == 8)
        #expect(TestSettingsValidator.validateMaxConcurrent(16) == 16)
        #expect(TestSettingsValidator.validateMaxConcurrent(100) == 16)
    }

    @Test("Negative values clamped to minimum")
    func negativeValues() {
        #expect(TestSettingsValidator.validateFontSize(-1.0) == 0.5)
        #expect(TestSettingsValidator.validateMaxConcurrent(-5) == 1)
    }
}
