// MessagingPatternsTests.swift
// Tests for ChatManager messaging patterns, @agent commands, device annotations
// Split from ToolCatalogAndMessagingTests for SwiftLint file_length compliance

import Testing
import Foundation

// MARK: - Test Doubles

/// Mirrors @agent command parsing from ChatManager
private func parseAgentCommand(_ text: String) -> (isAgentCommand: Bool, taskDescription: String?) {
    guard text.hasPrefix("@agent ") else {
        return (false, nil)
    }
    let task = String(text.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
    return (true, task.isEmpty ? nil : task)
}

/// Mirrors device origin annotation for cross-device messages
private func annotateForCrossDevice(
    content: String,
    senderDevice: String?,
    currentDevice: String
) -> String {
    guard let sender = senderDevice, sender != currentDevice else {
        return content
    }
    return "[Sent from \(sender)] \(content)"
}

/// Mirrors message role-based system prompt injection
private struct TestSystemPromptBuilder {
    let deviceName: String
    let capabilities: [String]

    func buildDeviceContext() -> String {
        var parts: [String] = []
        parts.append("You are running on \(deviceName).")
        if !capabilities.isEmpty {
            parts.append("Capabilities: \(capabilities.joined(separator: ", ")).")
        }
        return parts.joined(separator: " ")
    }
}

/// Mirrors file size validation for uploads
private let maxFileSizeBytes: Int = 500 * 1024 * 1024 // 500 MB

private func validateFileSize(_ bytes: Int) -> Bool {
    bytes <= maxFileSizeBytes
}

// MARK: - Tests

@Suite("@agent Command Parsing — Messaging")
struct AgentCommandParsingMessagingTests {
    @Test("Valid @agent command")
    func validCommand() {
        let result = parseAgentCommand("@agent research Swift concurrency")
        #expect(result.isAgentCommand)
        #expect(result.taskDescription == "research Swift concurrency")
    }

    @Test("Non-command text")
    func nonCommand() {
        let result = parseAgentCommand("Hello world")
        #expect(!result.isAgentCommand)
        #expect(result.taskDescription == nil)
    }

    @Test("@agent prefix only (no task)")
    func prefixOnly() {
        let result = parseAgentCommand("@agent ")
        #expect(result.isAgentCommand)
        #expect(result.taskDescription == nil)
    }

    @Test("@agent with extra spaces")
    func extraSpaces() {
        let result = parseAgentCommand("@agent   do something   ")
        #expect(result.isAgentCommand)
        #expect(result.taskDescription == "do something")
    }

    @Test("@agent in middle is not a command")
    func middleNotCommand() {
        let result = parseAgentCommand("Please @agent do this")
        #expect(!result.isAgentCommand)
    }

    @Test("Case sensitive — @Agent not matched")
    func caseSensitive() {
        let result = parseAgentCommand("@Agent do this")
        #expect(!result.isAgentCommand)
    }

    @Test("@agent without space is not matched")
    func noSpace() {
        let result = parseAgentCommand("@agentdo this")
        #expect(!result.isAgentCommand)
    }
}

@Suite("Cross-Device Message Annotation — Messaging")
struct CrossDeviceAnnotationMessagingTests {
    @Test("Same device — no annotation")
    func sameDevice() {
        let result = annotateForCrossDevice(content: "Hello", senderDevice: "msm3u", currentDevice: "msm3u")
        #expect(result == "Hello")
    }

    @Test("Different device — annotated")
    func differentDevice() {
        let result = annotateForCrossDevice(content: "Hello", senderDevice: "mbam2", currentDevice: "msm3u")
        #expect(result == "[Sent from mbam2] Hello")
    }

    @Test("No sender device — no annotation")
    func noSender() {
        let result = annotateForCrossDevice(content: "Hello", senderDevice: nil, currentDevice: "msm3u")
        #expect(result == "Hello")
    }

    @Test("Annotation preserves original content")
    func preservesContent() {
        let content = "Multi\nline\nmessage"
        let result = annotateForCrossDevice(content: content, senderDevice: "mbam2", currentDevice: "msm3u")
        #expect(result.contains(content))
    }
}

@Suite("Device Context System Prompt — Messaging")
struct DeviceContextMessagingTests {
    @Test("Basic device context")
    func basicContext() {
        let builder = TestSystemPromptBuilder(deviceName: "Mac Studio M3 Ultra", capabilities: ["ML inference", "on-device models"])
        let prompt = builder.buildDeviceContext()
        #expect(prompt.contains("Mac Studio M3 Ultra"))
        #expect(prompt.contains("ML inference"))
    }

    @Test("No capabilities")
    func noCapabilities() {
        let builder = TestSystemPromptBuilder(deviceName: "MacBook Air M2", capabilities: [])
        let prompt = builder.buildDeviceContext()
        #expect(prompt.contains("MacBook Air M2"))
        #expect(!prompt.contains("Capabilities"))
    }
}

@Suite("File Size Validation — Messaging")
struct FileSizeValidationMessagingTests {
    @Test("Under 500MB is valid")
    func underLimit() {
        #expect(validateFileSize(100 * 1024 * 1024))
    }

    @Test("Exactly 500MB is valid")
    func exactLimit() {
        #expect(validateFileSize(500 * 1024 * 1024))
    }

    @Test("Over 500MB is invalid")
    func overLimit() {
        #expect(!validateFileSize(500 * 1024 * 1024 + 1))
    }

    @Test("Zero bytes is valid")
    func zeroBytes() {
        #expect(validateFileSize(0))
    }

    @Test("1 byte is valid")
    func oneByte() {
        #expect(validateFileSize(1))
    }
}
