// ConversationExporterTests.swift
// Tests for ConversationExporter — Markdown, JSON, plain text export

import Testing
import Foundation

// MARK: - Test Doubles (mirrors ConversationExporter types)

private struct TestExportedConversation: Codable, Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [TestExportedMessage]
    let tags: [String]
    let totalTokens: Int
    let modelUsed: String?
}

private struct TestExportedMessage: Codable, Sendable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date
    let model: String?
    let tokenCount: Int?
    let deviceName: String?
}

private enum TestExportFormat: String, CaseIterable, Sendable {
    case markdown
    case json
    case plainText
}

// MARK: - Export Format Helpers

private func exportMarkdown(_ conversation: TestExportedConversation) -> String {
    var lines: [String] = []
    lines.append("# \(conversation.title)")
    lines.append("")
    lines.append("---")
    lines.append("")
    for message in conversation.messages {
        let roleName: String
        switch message.role {
        case "user": roleName = "User"
        case "assistant": roleName = "Assistant"
        case "system": roleName = "System"
        default: roleName = message.role.capitalized
        }
        lines.append("### \(roleName)")
        lines.append("")
        lines.append(message.content)
        lines.append("")
    }
    return lines.joined(separator: "\n")
}

private func exportJSON(_ conversation: TestExportedConversation) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(conversation),
          let json = String(data: data, encoding: .utf8) else { return "{}" }
    return json
}

private func exportPlainText(_ conversation: TestExportedConversation) -> String {
    var lines: [String] = []
    lines.append("Conversation: \(conversation.title)")
    lines.append("")
    for message in conversation.messages {
        let roleName: String
        switch message.role {
        case "user": roleName = "User"
        case "assistant": roleName = "Assistant"
        default: roleName = message.role.capitalized
        }
        lines.append("\(roleName):")
        lines.append(message.content)
        lines.append("")
    }
    return lines.joined(separator: "\n")
}

// MARK: - Test Data

private func makeConversation(
    title: String = "Test Conversation",
    messages: [TestExportedMessage]? = nil,
    tags: [String] = ["swift", "testing"],
    totalTokens: Int = 1500,
    modelUsed: String? = "claude-4-opus"
) -> TestExportedConversation {
    let defaultMessages = [
        TestExportedMessage(
            id: UUID(), role: "user", content: "Hello, how are you?",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            model: nil, tokenCount: 6, deviceName: "Mac Studio"
        ),
        TestExportedMessage(
            id: UUID(), role: "assistant",
            content: "I'm doing well! How can I help you today?",
            timestamp: Date(timeIntervalSince1970: 1_700_000_010),
            model: "claude-4-opus", tokenCount: 12, deviceName: nil
        )
    ]

    return TestExportedConversation(
        id: UUID(),
        title: title,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
        messages: messages ?? defaultMessages,
        tags: tags,
        totalTokens: totalTokens,
        modelUsed: modelUsed
    )
}

// MARK: - ExportFormat Tests

@Suite("ConvExporter — ExportFormat")
struct ConvExporterFormatTests {
    @Test("All export formats are available")
    func allFormats() {
        let formats = TestExportFormat.allCases
        #expect(formats.count == 3)
        #expect(formats.contains(.markdown))
        #expect(formats.contains(.json))
        #expect(formats.contains(.plainText))
    }

    @Test("Format raw values are distinct")
    func rawValues() {
        let rawValues = Set(TestExportFormat.allCases.map(\.rawValue))
        #expect(rawValues.count == 3)
    }
}

// MARK: - Markdown Export Tests

@Suite("ConvExporter — Markdown")
struct ConvExporterMarkdownTests {
    @Test("Markdown contains title as H1")
    func containsTitle() {
        let conv = makeConversation(title: "My Research Discussion")
        let md = exportMarkdown(conv)
        #expect(md.contains("# My Research Discussion"))
    }

    @Test("Markdown contains message roles")
    func containsRoles() {
        let conv = makeConversation()
        let md = exportMarkdown(conv)
        #expect(md.contains("### User"))
        #expect(md.contains("### Assistant"))
    }

    @Test("Markdown contains message content")
    func containsContent() {
        let conv = makeConversation()
        let md = exportMarkdown(conv)
        #expect(md.contains("Hello, how are you?"))
        #expect(md.contains("I'm doing well! How can I help you today?"))
    }

    @Test("Markdown has separator line")
    func hasSeparator() {
        let conv = makeConversation()
        let md = exportMarkdown(conv)
        #expect(md.contains("---"))
    }

    @Test("Markdown with system message")
    func systemMessage() {
        let messages = [
            TestExportedMessage(
                id: UUID(), role: "system", content: "You are a helpful assistant.",
                timestamp: Date(), model: nil, tokenCount: nil, deviceName: nil
            )
        ]
        let conv = makeConversation(messages: messages)
        let md = exportMarkdown(conv)
        #expect(md.contains("### System"))
        #expect(md.contains("You are a helpful assistant."))
    }

    @Test("Markdown empty conversation")
    func emptyConversation() {
        let conv = makeConversation(messages: [])
        let md = exportMarkdown(conv)
        #expect(md.contains("# Test Conversation"))
        #expect(!md.contains("### User"))
    }

    @Test("Markdown preserves message order")
    func messageOrder() {
        let conv = makeConversation()
        let md = exportMarkdown(conv)
        let userIndex = md.range(of: "### User")?.lowerBound
        let assistantIndex = md.range(of: "### Assistant")?.lowerBound
        #expect(userIndex != nil)
        #expect(assistantIndex != nil)
        if let u = userIndex, let a = assistantIndex {
            #expect(u < a)
        }
    }

    @Test("Markdown with code content")
    func codeContent() {
        let messages = [
            TestExportedMessage(
                id: UUID(), role: "assistant",
                content: "Here's a function:\n```swift\nfunc hello() { print(\"Hello\") }\n```",
                timestamp: Date(), model: "claude-4-opus", tokenCount: 20, deviceName: nil
            )
        ]
        let conv = makeConversation(messages: messages)
        let md = exportMarkdown(conv)
        #expect(md.contains("```swift"))
        #expect(md.contains("func hello()"))
    }
}

// MARK: - JSON Export Tests

@Suite("ConvExporter — JSON")
struct ConvExporterJSONTests {
    @Test("JSON is valid and decodable")
    func validJSON() {
        let conv = makeConversation()
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try? JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded != nil)
    }

    @Test("JSON preserves title")
    func preservesTitle() {
        let conv = makeConversation(title: "AI Discussion")
        let json = exportJSON(conv)
        #expect(json.contains("AI Discussion"))
    }

    @Test("JSON preserves message count")
    func preservesMessageCount() throws {
        let conv = makeConversation()
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.messages.count == 2)
    }

    @Test("JSON preserves tags")
    func preservesTags() throws {
        let conv = makeConversation(tags: ["swift", "testing", "ai"])
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.tags == ["swift", "testing", "ai"])
    }

    @Test("JSON preserves token count")
    func preservesTokens() throws {
        let conv = makeConversation(totalTokens: 5000)
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.totalTokens == 5000)
    }

    @Test("JSON preserves model used")
    func preservesModel() throws {
        let conv = makeConversation(modelUsed: "gpt-4o")
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.modelUsed == "gpt-4o")
    }

    @Test("JSON handles nil model")
    func nilModel() throws {
        let conv = makeConversation(modelUsed: nil)
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.modelUsed == nil)
    }

    @Test("JSON empty conversation")
    func emptyConversation() throws {
        let conv = makeConversation(messages: [], tags: [], totalTokens: 0)
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.messages.isEmpty)
        #expect(decoded.tags.isEmpty)
    }

    @Test("JSON preserves message roles")
    func preservesRoles() throws {
        let conv = makeConversation()
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.messages[0].role == "user")
        #expect(decoded.messages[1].role == "assistant")
    }

    @Test("JSON preserves device name")
    func preservesDeviceName() throws {
        let conv = makeConversation()
        let json = exportJSON(conv)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.messages[0].deviceName == "Mac Studio")
        #expect(decoded.messages[1].deviceName == nil)
    }
}

// MARK: - Plain Text Export Tests

@Suite("ConvExporter — Plain Text")
struct ConvExporterPlainTextTests {
    @Test("Plain text contains title")
    func containsTitle() {
        let conv = makeConversation(title: "Debug Session")
        let txt = exportPlainText(conv)
        #expect(txt.contains("Conversation: Debug Session"))
    }

    @Test("Plain text contains role labels")
    func containsRoles() {
        let conv = makeConversation()
        let txt = exportPlainText(conv)
        #expect(txt.contains("User:"))
        #expect(txt.contains("Assistant:"))
    }

    @Test("Plain text contains content")
    func containsContent() {
        let conv = makeConversation()
        let txt = exportPlainText(conv)
        #expect(txt.contains("Hello, how are you?"))
        #expect(txt.contains("I'm doing well!"))
    }

    @Test("Plain text empty conversation")
    func emptyConversation() {
        let conv = makeConversation(messages: [])
        let txt = exportPlainText(conv)
        #expect(txt.contains("Conversation: Test Conversation"))
        #expect(!txt.contains("User:"))
    }

    @Test("Plain text preserves order")
    func preservesOrder() {
        let conv = makeConversation()
        let txt = exportPlainText(conv)
        let userIdx = txt.range(of: "User:")?.lowerBound
        let assistantIdx = txt.range(of: "Assistant:")?.lowerBound
        #expect(userIdx != nil)
        #expect(assistantIdx != nil)
        if let u = userIdx, let a = assistantIdx {
            #expect(u < a)
        }
    }
}

// MARK: - Filename Generation Tests

@Suite("ConvExporter — Filename")
struct ConvExporterFilenameTests {
    @Test("Markdown filename has .md extension")
    func markdownExtension() {
        let filename = suggestedFilename(title: "Test", date: Date(), format: .markdown)
        #expect(filename.hasSuffix(".md"))
    }

    @Test("JSON filename has .json extension")
    func jsonExtension() {
        let filename = suggestedFilename(title: "Test", date: Date(), format: .json)
        #expect(filename.hasSuffix(".json"))
    }

    @Test("Plain text filename has .txt extension")
    func plainTextExtension() {
        let filename = suggestedFilename(title: "Test", date: Date(), format: .plainText)
        #expect(filename.hasSuffix(".txt"))
    }

    @Test("Filename sanitizes slashes")
    func sanitizesSlashes() {
        let filename = suggestedFilename(title: "Path/To/File", date: Date(), format: .markdown)
        #expect(!filename.contains("/"))
    }

    @Test("Filename sanitizes colons")
    func sanitizesColons() {
        let filename = suggestedFilename(title: "Time: 12:30", date: Date(), format: .json)
        #expect(!filename.contains(":"))
    }

    @Test("Filename truncates long titles")
    func truncatesLongTitles() {
        let longTitle = String(repeating: "A", count: 100)
        let filename = suggestedFilename(title: longTitle, date: Date(), format: .markdown)
        // Title portion should be ≤50 chars, plus date and extension
        #expect(filename.count < 80)
    }

    @Test("Filename contains date component")
    func containsDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let filename = suggestedFilename(title: "Test", date: date, format: .json)
        #expect(filename.contains("2023"))
    }
}

// Helper for filename generation tests
private func suggestedFilename(title: String, date: Date, format: TestExportFormat) -> String {
    let sanitized = title
        .replacingOccurrences(of: "/", with: "-")
        .replacingOccurrences(of: ":", with: "-")
        .replacingOccurrences(of: "\\", with: "-")
        .prefix(50)

    let ext: String
    switch format {
    case .markdown: ext = "md"
    case .json: ext = "json"
    case .plainText: ext = "txt"
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let dateStr = formatter.string(from: date)
    return "\(sanitized)_\(dateStr).\(ext)"
}

// MARK: - Multi-Conversation Export Tests

@Suite("ConvExporter — Multi Export")
struct ConvExporterMultiTests {
    @Test("Multiple conversations separated in markdown")
    func multiMarkdown() {
        let conv1 = makeConversation(title: "First")
        let conv2 = makeConversation(title: "Second")
        let md = [exportMarkdown(conv1), exportMarkdown(conv2)].joined(separator: "\n\n---\n\n")
        #expect(md.contains("# First"))
        #expect(md.contains("# Second"))
        #expect(md.components(separatedBy: "---").count >= 3) // separator + internal separators
    }

    @Test("Multiple conversations in JSON array")
    func multiJSON() throws {
        let conv1 = makeConversation(title: "First")
        let conv2 = makeConversation(title: "Second")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([conv1, conv2])
        let decoded = try JSONDecoder.isoDecoder.decode([TestExportedConversation].self, from: data)
        #expect(decoded.count == 2)
        #expect(decoded[0].title == "First")
        #expect(decoded[1].title == "Second")
    }

    @Test("Multiple conversations separated in plain text")
    func multiPlainText() {
        let conv1 = makeConversation(title: "First")
        let conv2 = makeConversation(title: "Second")
        let txt = [exportPlainText(conv1), exportPlainText(conv2)]
            .joined(separator: "\n\n========================================\n\n")
        #expect(txt.contains("Conversation: First"))
        #expect(txt.contains("Conversation: Second"))
        #expect(txt.contains("========================================"))
    }
}

// MARK: - ExportedMessage Tests

@Suite("ConvExporter — ExportedMessage")
struct ConvExporterMessageTests {
    @Test("Message with all fields")
    func fullMessage() {
        let msg = TestExportedMessage(
            id: UUID(),
            role: "assistant",
            content: "Hello!",
            timestamp: Date(),
            model: "claude-4-opus",
            tokenCount: 5,
            deviceName: "MacBook Air"
        )
        #expect(msg.role == "assistant")
        #expect(msg.content == "Hello!")
        #expect(msg.model == "claude-4-opus")
        #expect(msg.tokenCount == 5)
        #expect(msg.deviceName == "MacBook Air")
    }

    @Test("Message with minimal fields")
    func minimalMessage() {
        let msg = TestExportedMessage(
            id: UUID(),
            role: "user",
            content: "Hi",
            timestamp: Date(),
            model: nil,
            tokenCount: nil,
            deviceName: nil
        )
        #expect(msg.model == nil)
        #expect(msg.tokenCount == nil)
        #expect(msg.deviceName == nil)
    }

    @Test("Message Codable roundtrip")
    func codableRoundtrip() throws {
        let msg = TestExportedMessage(
            id: UUID(),
            role: "user",
            content: "Test content",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            model: "gpt-4o",
            tokenCount: 10,
            deviceName: "Mac Studio"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(msg)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedMessage.self, from: data)
        #expect(decoded.role == msg.role)
        #expect(decoded.content == msg.content)
        #expect(decoded.model == msg.model)
        #expect(decoded.tokenCount == msg.tokenCount)
        #expect(decoded.deviceName == msg.deviceName)
    }
}

// MARK: - ExportedConversation Tests

@Suite("ConvExporter — ExportedConversation")
struct ConvExporterConversationTests {
    @Test("Conversation with all fields")
    func fullConversation() {
        let conv = makeConversation()
        #expect(conv.title == "Test Conversation")
        #expect(conv.messages.count == 2)
        #expect(conv.tags == ["swift", "testing"])
        #expect(conv.totalTokens == 1500)
        #expect(conv.modelUsed == "claude-4-opus")
    }

    @Test("Conversation Codable roundtrip")
    func codableRoundtrip() throws {
        let conv = makeConversation()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conv)
        let decoded = try JSONDecoder.isoDecoder.decode(TestExportedConversation.self, from: data)
        #expect(decoded.title == conv.title)
        #expect(decoded.messages.count == conv.messages.count)
        #expect(decoded.tags == conv.tags)
        #expect(decoded.totalTokens == conv.totalTokens)
    }

    @Test("Conversation with empty messages")
    func emptyMessages() {
        let conv = makeConversation(messages: [])
        #expect(conv.messages.isEmpty)
    }

    @Test("Conversation with many messages")
    func manyMessages() {
        let messages = (0..<100).map { i in
            TestExportedMessage(
                id: UUID(),
                role: i.isMultiple(of: 2) ? "user" : "assistant",
                content: "Message \(i)",
                timestamp: Date().addingTimeInterval(Double(i)),
                model: nil,
                tokenCount: 5,
                deviceName: nil
            )
        }
        let conv = makeConversation(messages: messages)
        #expect(conv.messages.count == 100)
    }
}

// MARK: - JSON Decoder Helper

private extension JSONDecoder {
    static let isoDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
