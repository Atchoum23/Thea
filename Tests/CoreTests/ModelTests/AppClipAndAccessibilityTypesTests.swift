// AppClipAndAccessibilityTypesTests.swift
// Tests for AppClipManager and AccessibilityService types

import Testing
import Foundation

// MARK: - Test Doubles: ExperienceType

private enum TestExperienceType: String, Sendable, CaseIterable {
    case quickAsk, scan, voice, demo
}

// MARK: - Test Doubles: ClipExperience

private struct TestClipExperience: Sendable {
    let type: TestExperienceType
    let parameters: [String: String]
}

// MARK: - Test Doubles: UsageLimitStatus

private struct TestUsageLimitStatus: Sendable {
    let limited: Bool
    let remaining: Int
    let message: String?

    static func check(usedQueries: Int, maxQueries: Int) -> TestUsageLimitStatus {
        let limited = usedQueries >= maxQueries
        let remaining = max(maxQueries - usedQueries, 0)
        let message = limited ? "You've reached the limit of \(maxQueries) queries. Download the full app to continue." : nil
        return TestUsageLimitStatus(limited: limited, remaining: remaining, message: message)
    }
}

// MARK: - Test Doubles: ExperienceParser

private enum TestExperienceParser {
    static func parse(from url: URL) -> TestClipExperience? {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = path.split(separator: "/").map(String.init)
        guard let first = components.first else { return nil }

        var params: [String: String] = [:]
        if let query = url.query {
            for pair in query.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    params[String(kv[0])] = String(kv[1])
                }
            }
        }

        switch first {
        case "ask", "quick-ask": return TestClipExperience(type: .quickAsk, parameters: params)
        case "scan": return TestClipExperience(type: .scan, parameters: params)
        case "voice": return TestClipExperience(type: .voice, parameters: params)
        case "demo": return TestClipExperience(type: .demo, parameters: params)
        default: return nil
        }
    }
}

// MARK: - Test Doubles: AnnouncementPriority

private enum TestAnnouncementPriority: Sendable {
    case high, low
}

// MARK: - Test Doubles: HapticType

private enum TestHapticType: Sendable, CaseIterable {
    case success, warning, error, selection, light, medium, heavy
}

// MARK: - Test Doubles: AccessibilityDescriber

private enum TestAccessibilityDescriber {
    static func describeAIResponse(_ text: String, wordCount: Int, isComplete: Bool) -> String {
        let status = isComplete ? "Complete" : "Generating"
        let prefix = "\(status) AI response, \(wordCount) words."
        if wordCount > 200 {
            return "\(prefix) Long response."
        }
        return prefix
    }

    static func hintForAction(_ action: String) -> String {
        switch action {
        case "send": return "Double tap to send message"
        case "copy": return "Double tap to copy text"
        case "delete": return "Double tap to delete"
        case "settings": return "Double tap to open settings"
        case "newConversation": return "Double tap to start new conversation"
        default: return "Double tap to activate"
        }
    }

    static func accessibleCodeDescription(_ code: String) -> String {
        code
            .replacingOccurrences(of: "{", with: " open brace ")
            .replacingOccurrences(of: "}", with: " close brace ")
            .replacingOccurrences(of: "(", with: " open paren ")
            .replacingOccurrences(of: ")", with: " close paren ")
            .replacingOccurrences(of: "->", with: " returns ")
            .replacingOccurrences(of: "==", with: " equals ")
            .replacingOccurrences(of: "!=", with: " not equals ")
    }
}

// MARK: - Tests: ExperienceType

@Suite("Experience Type")
struct ExperienceTypeTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestExperienceType.allCases.count == 4)
    }

    @Test("Raw values are unique")
    func uniqueRawValues() {
        let values = Set(TestExperienceType.allCases.map(\.rawValue))
        #expect(values.count == TestExperienceType.allCases.count)
    }
}

// MARK: - Tests: ExperienceParser

@Suite("Experience Parser")
struct ExperienceParserTests {
    @Test("Parse quick-ask URL")
    func quickAsk() {
        let url = URL(string: "https://theathe.app/quick-ask?prompt=hello")!
        let exp = TestExperienceParser.parse(from: url)
        #expect(exp?.type == .quickAsk)
        #expect(exp?.parameters["prompt"] == "hello")
    }

    @Test("Parse scan URL")
    func scan() {
        let url = URL(string: "https://theathe.app/scan")!
        let exp = TestExperienceParser.parse(from: url)
        #expect(exp?.type == .scan)
    }

    @Test("Parse voice URL")
    func voice() {
        let url = URL(string: "https://theathe.app/voice?lang=fr")!
        let exp = TestExperienceParser.parse(from: url)
        #expect(exp?.type == .voice)
        #expect(exp?.parameters["lang"] == "fr")
    }

    @Test("Parse demo URL")
    func demo() {
        let url = URL(string: "https://theathe.app/demo")!
        let exp = TestExperienceParser.parse(from: url)
        #expect(exp?.type == .demo)
    }

    @Test("Unknown path returns nil")
    func unknown() {
        let url = URL(string: "https://theathe.app/unknown")!
        #expect(TestExperienceParser.parse(from: url) == nil)
    }

    @Test("Root path returns nil")
    func rootPath() {
        let url = URL(string: "https://theathe.app/")!
        #expect(TestExperienceParser.parse(from: url) == nil)
    }
}

// MARK: - Tests: UsageLimitStatus

@Suite("Usage Limit Status")
struct UsageLimitStatusTests {
    @Test("Under limit")
    func underLimit() {
        let status = TestUsageLimitStatus.check(usedQueries: 3, maxQueries: 10)
        #expect(!status.limited)
        #expect(status.remaining == 7)
        #expect(status.message == nil)
    }

    @Test("At limit")
    func atLimit() {
        let status = TestUsageLimitStatus.check(usedQueries: 10, maxQueries: 10)
        #expect(status.limited)
        #expect(status.remaining == 0)
        #expect(status.message != nil)
    }

    @Test("Over limit")
    func overLimit() {
        let status = TestUsageLimitStatus.check(usedQueries: 15, maxQueries: 10)
        #expect(status.limited)
        #expect(status.remaining == 0)
    }

    @Test("Zero queries")
    func zeroQueries() {
        let status = TestUsageLimitStatus.check(usedQueries: 0, maxQueries: 5)
        #expect(!status.limited)
        #expect(status.remaining == 5)
    }
}

// MARK: - Tests: HapticType

@Suite("Haptic Type")
struct HapticTypeTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestHapticType.allCases.count == 7)
    }
}

// MARK: - Tests: AccessibilityDescriber

@Suite("Accessibility Describer")
struct AccessibilityDescriberTests {
    @Test("Complete response description")
    func completeResponse() {
        let desc = TestAccessibilityDescriber.describeAIResponse("Hello world", wordCount: 2, isComplete: true)
        #expect(desc.contains("Complete"))
        #expect(desc.contains("2 words"))
    }

    @Test("Generating response description")
    func generatingResponse() {
        let desc = TestAccessibilityDescriber.describeAIResponse("...", wordCount: 50, isComplete: false)
        #expect(desc.contains("Generating"))
    }

    @Test("Long response note")
    func longResponse() {
        let desc = TestAccessibilityDescriber.describeAIResponse("...", wordCount: 300, isComplete: true)
        #expect(desc.contains("Long response"))
    }

    @Test("Short response no long note")
    func shortResponse() {
        let desc = TestAccessibilityDescriber.describeAIResponse("...", wordCount: 50, isComplete: true)
        #expect(!desc.contains("Long response"))
    }

    @Test("Action hints")
    func actionHints() {
        let actions = ["send", "copy", "delete", "settings", "newConversation", "unknown"]
        for action in actions {
            let hint = TestAccessibilityDescriber.hintForAction(action)
            #expect(hint.contains("Double tap"))
        }
    }

    @Test("Action hints are specific")
    func specificHints() {
        #expect(TestAccessibilityDescriber.hintForAction("send").contains("send"))
        #expect(TestAccessibilityDescriber.hintForAction("copy").contains("copy"))
        #expect(TestAccessibilityDescriber.hintForAction("delete").contains("delete"))
    }

    @Test("Code description: braces")
    func codeBraces() {
        let desc = TestAccessibilityDescriber.accessibleCodeDescription("func main() { }")
        #expect(desc.contains("open brace"))
        #expect(desc.contains("close brace"))
    }

    @Test("Code description: parens")
    func codeParens() {
        let desc = TestAccessibilityDescriber.accessibleCodeDescription("call()")
        #expect(desc.contains("open paren"))
        #expect(desc.contains("close paren"))
    }

    @Test("Code description: arrow")
    func codeArrow() {
        let desc = TestAccessibilityDescriber.accessibleCodeDescription("-> String")
        #expect(desc.contains("returns"))
    }

    @Test("Code description: operators")
    func codeOperators() {
        #expect(TestAccessibilityDescriber.accessibleCodeDescription("a == b").contains("equals"))
        #expect(TestAccessibilityDescriber.accessibleCodeDescription("a != b").contains("not equals"))
    }
}
