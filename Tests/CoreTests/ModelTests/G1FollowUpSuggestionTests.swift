import Testing
import Foundation

// MARK: - Test Doubles (mirror production types)

/// Mirrors FollowUpSuggestion from Shared/Core/Models/Message.swift
private struct TestFollowUpSuggestion: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let icon: String
    let source: TestSuggestionSource

    init(text: String, icon: String = "arrow.turn.down.right", source: TestSuggestionSource = .heuristic) {
        self.id = UUID()
        self.text = text
        self.icon = icon
        self.source = source
    }
}

private enum TestSuggestionSource: String, Codable, Sendable {
    case heuristic
    case ai
    case learnedPattern
}

// MARK: - Suggestion Generator (mirrors FollowUpSuggestionService.generate logic)

private struct TestSuggestionGenerator {

    static func generate(
        response: String,
        query: String,
        taskType: String?,
        selectionCounts: [String: Int] = [:]
    ) -> [TestFollowUpSuggestion] {
        var suggestions: [TestFollowUpSuggestion] = []

        let responseLength = response.count
        let hasCode = response.contains("```")
        let hasList = response.contains("\n- ") || response.contains("\n1.")
        let hasQuestion = response.contains("?")
        let taskCategory = taskType ?? "general"

        // Code-related follow-ups
        if hasCode {
            suggestions.append(TestFollowUpSuggestion(
                text: "Explain this code step by step",
                icon: "text.magnifyingglass"
            ))
            suggestions.append(TestFollowUpSuggestion(
                text: "Add error handling and edge cases",
                icon: "exclamationmark.shield"
            ))
            suggestions.append(TestFollowUpSuggestion(
                text: "Write tests for this code",
                icon: "checkmark.circle"
            ))
        }

        // List-based follow-ups
        if hasList {
            suggestions.append(TestFollowUpSuggestion(
                text: "Elaborate on each point",
                icon: "list.bullet.indent"
            ))
            suggestions.append(TestFollowUpSuggestion(
                text: "Which of these should I prioritize?",
                icon: "star"
            ))
        }

        // Long response follow-ups
        if responseLength > 2000 {
            suggestions.append(TestFollowUpSuggestion(
                text: "Summarize the key takeaways",
                icon: "text.redaction"
            ))
        }

        // Task-type specific suggestions
        switch taskCategory {
        case "research", "factual":
            suggestions.append(TestFollowUpSuggestion(
                text: "What are the sources for this?",
                icon: "book"
            ))
            suggestions.append(TestFollowUpSuggestion(
                text: "What are the counterarguments?",
                icon: "arrow.left.arrow.right"
            ))
        case "analysis", "reasoning":
            suggestions.append(TestFollowUpSuggestion(
                text: "What assumptions does this analysis make?",
                icon: "questionmark.circle"
            ))
        case "creative", "writing":
            suggestions.append(TestFollowUpSuggestion(
                text: "Make it more concise",
                icon: "scissors"
            ))
            suggestions.append(TestFollowUpSuggestion(
                text: "Adjust the tone to be more formal",
                icon: "textformat"
            ))
        case "codeGeneration", "debugging", "codeReview":
            if !hasCode {
                suggestions.append(TestFollowUpSuggestion(
                    text: "Show me the implementation",
                    icon: "chevron.left.forwardslash.chevron.right"
                ))
            }
        case "planning":
            suggestions.append(TestFollowUpSuggestion(
                text: "Create a timeline for this plan",
                icon: "calendar"
            ))
            suggestions.append(TestFollowUpSuggestion(
                text: "What could go wrong?",
                icon: "exclamationmark.triangle"
            ))
        default:
            break
        }

        // If response posed a question, suggest answering it
        if hasQuestion && !hasCode {
            suggestions.append(TestFollowUpSuggestion(
                text: "Yes, please continue",
                icon: "arrow.right.circle"
            ))
        }

        // Universal fallback: dive deeper
        if suggestions.count < 2 {
            suggestions.append(TestFollowUpSuggestion(
                text: "Tell me more about this",
                icon: "plus.magnifyingglass"
            ))
            suggestions.append(TestFollowUpSuggestion(
                text: "How does this compare to alternatives?",
                icon: "arrow.triangle.branch"
            ))
        }

        // Rank by learned preference and limit to 4
        let ranked = rankByPreference(suggestions, selectionCounts: selectionCounts)
        return Array(ranked.prefix(4))
    }

    private static func patternKey(for suggestion: TestFollowUpSuggestion) -> String {
        suggestion.text.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .prefix(40)
            .description
    }

    private static func rankByPreference(
        _ suggestions: [TestFollowUpSuggestion],
        selectionCounts: [String: Int]
    ) -> [TestFollowUpSuggestion] {
        suggestions.sorted { a, b in
            let countA = selectionCounts[patternKey(for: a)] ?? 0
            let countB = selectionCounts[patternKey(for: b)] ?? 0
            return countA > countB
        }
    }
}

// MARK: - Learning Logic (mirrors FollowUpSuggestionService state management)

private class TestSuggestionLearner {
    var selectionCounts: [String: Int] = [:]
    var totalSelections = 0
    var totalDismissals = 0
    var consecutiveAutoAccepts: [String: Int] = [:]
    let autoPromptThreshold = 5
    var isAutoPromptEnabled = false

    func patternKey(for text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .prefix(40)
            .description
    }

    func recordSelection(_ text: String) {
        let pattern = patternKey(for: text)
        selectionCounts[pattern, default: 0] += 1
        totalSelections += 1
        consecutiveAutoAccepts[pattern, default: 0] += 1

        for key in consecutiveAutoAccepts.keys where key != pattern {
            consecutiveAutoAccepts[key] = 0
        }
    }

    func recordDismissal() {
        totalDismissals += 1
        for key in consecutiveAutoAccepts.keys {
            consecutiveAutoAccepts[key] = 0
        }
    }

    func shouldAutoPrompt(_ text: String) -> Bool {
        guard isAutoPromptEnabled else { return false }
        let pattern = patternKey(for: text)
        return (consecutiveAutoAccepts[pattern] ?? 0) >= autoPromptThreshold
    }

    var acceptanceRate: Double {
        let total = totalSelections + totalDismissals
        guard total > 0 else { return 0 }
        return Double(totalSelections) / Double(total)
    }
}

// MARK: - Number Selection Logic (mirrors ChatView+Extensions sendMessage)

private func resolveNumberSelection(
    input: String,
    suggestions: [TestFollowUpSuggestion]
) -> String {
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if !suggestions.isEmpty, let num = Int(text), num >= 1, num <= suggestions.count {
        return suggestions[num - 1].text
    }
    return text
}

// MARK: - Tests

@Suite("G1 Follow-Up — Suggestion Type")
struct G1SuggestionTypeTests {

    @Test("FollowUpSuggestion is Identifiable with unique ID")
    func identifiable() {
        let s1 = TestFollowUpSuggestion(text: "Hello")
        let s2 = TestFollowUpSuggestion(text: "Hello")
        #expect(s1.id != s2.id)
    }

    @Test("Default icon and source")
    func defaults() {
        let s = TestFollowUpSuggestion(text: "Test")
        #expect(s.icon == "arrow.turn.down.right")
        #expect(s.source == .heuristic)
    }

    @Test("Custom icon and source")
    func custom() {
        let s = TestFollowUpSuggestion(text: "Test", icon: "star", source: .ai)
        #expect(s.icon == "star")
        #expect(s.source == .ai)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let original = TestFollowUpSuggestion(text: "Test", icon: "star", source: .learnedPattern)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestFollowUpSuggestion.self, from: data)
        #expect(decoded.text == original.text)
        #expect(decoded.icon == original.icon)
        #expect(decoded.source == original.source)
    }

    @Test("SuggestionSource all cases")
    func sourceAllCases() {
        let cases: [TestSuggestionSource] = [.heuristic, .ai, .learnedPattern]
        let rawValues = cases.map(\.rawValue)
        #expect(Set(rawValues).count == 3) // All unique
    }
}

@Suite("G1 Follow-Up — Generation Logic")
struct G1GenerationTests {

    @Test("Code response generates code-specific suggestions")
    func codeResponse() {
        let response = "Here's the solution:\n```swift\nfunc hello() { }\n```"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "write a function", taskType: nil
        )
        #expect(suggestions.count >= 2)
        #expect(suggestions.count <= 4)
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Explain this code step by step"))
    }

    @Test("List response generates list-specific suggestions")
    func listResponse() {
        let response = "Here are the options:\n- Option A\n- Option B\n- Option C"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "what are my options?", taskType: nil
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Elaborate on each point") || texts.contains("Which of these should I prioritize?"))
    }

    @Test("Numbered list generates list suggestions")
    func numberedListResponse() {
        let response = "Steps:\n1. First step\n2. Second step\n3. Third step"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "how do I do this?", taskType: nil
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Elaborate on each point") || texts.contains("Which of these should I prioritize?"))
    }

    @Test("Long response gets summarize suggestion")
    func longResponse() {
        let response = String(repeating: "word ", count: 500) // ~2500 chars
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "explain everything", taskType: nil
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Summarize the key takeaways"))
    }

    @Test("Research task type generates source/counterargument suggestions")
    func researchTask() {
        let response = "According to studies, X is better than Y."
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "compare X and Y", taskType: "research"
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("What are the sources for this?") || texts.contains("What are the counterarguments?"))
    }

    @Test("Analysis task type generates assumption question")
    func analysisTask() {
        let response = "The analysis shows a clear trend."
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "analyze the data", taskType: "analysis"
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("What assumptions does this analysis make?"))
    }

    @Test("Creative task type generates tone/concise suggestions")
    func creativeTask() {
        let response = "Here's a poem about the ocean:\nWaves crash upon the shore..."
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "write a poem", taskType: "creative"
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Make it more concise") || texts.contains("Adjust the tone to be more formal"))
    }

    @Test("Planning task type generates timeline/risk suggestions")
    func planningTask() {
        let response = "Here's the plan: Phase 1, Phase 2, Phase 3."
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "plan the project", taskType: "planning"
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Create a timeline for this plan") || texts.contains("What could go wrong?"))
    }

    @Test("Question in response gets 'continue' suggestion")
    func questionResponse() {
        let response = "Would you like me to elaborate on this point?"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "explain X", taskType: nil
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Yes, please continue"))
    }

    @Test("Question in code response does NOT get 'continue' suggestion")
    func questionInCodeResponse() {
        let response = "```swift\n// What does this do?\nfunc foo() { }\n```"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "write code", taskType: nil
        )
        let texts = suggestions.map(\.text)
        #expect(!texts.contains("Yes, please continue"))
    }

    @Test("Minimal response gets fallback suggestions")
    func minimalResponse() {
        let response = "OK."
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "do it", taskType: nil
        )
        #expect(suggestions.count >= 2)
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Tell me more about this") || texts.contains("How does this compare to alternatives?"))
    }

    @Test("Max 4 suggestions returned")
    func maxFour() {
        // Code + list + long + question = many potential suggestions
        let response = "```swift\ncode\n```\n\n- Item\n\n" + String(repeating: "w ", count: 1100) + "?"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "what?", taskType: "research"
        )
        #expect(suggestions.count <= 4)
    }

    @Test("CodeGeneration without code suggests implementation")
    func codeGenWithoutCode() {
        let response = "You should use a recursive approach with memoization."
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "solve this", taskType: "codeGeneration"
        )
        let texts = suggestions.map(\.text)
        #expect(texts.contains("Show me the implementation"))
    }

    @Test("CodeGeneration with code does NOT suggest implementation")
    func codeGenWithCode() {
        let response = "```python\ndef solve(): pass\n```"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "solve this", taskType: "codeGeneration"
        )
        let texts = suggestions.map(\.text)
        #expect(!texts.contains("Show me the implementation"))
    }
}

@Suite("G1 Follow-Up — Learning")
struct G1LearningTests {

    @Test("Selection increments count")
    func selectionIncrementsCount() {
        let learner = TestSuggestionLearner()
        learner.recordSelection("Explain this code step by step")
        #expect(learner.totalSelections == 1)
        #expect(learner.selectionCounts.values.first == 1)
    }

    @Test("Multiple selections of same pattern accumulate")
    func multipleSelections() {
        let learner = TestSuggestionLearner()
        learner.recordSelection("Tell me more")
        learner.recordSelection("Tell me more")
        learner.recordSelection("Tell me more")
        let key = learner.patternKey(for: "Tell me more")
        #expect(learner.selectionCounts[key] == 3)
        #expect(learner.totalSelections == 3)
    }

    @Test("Dismissal increments dismissal count")
    func dismissal() {
        let learner = TestSuggestionLearner()
        learner.recordDismissal()
        #expect(learner.totalDismissals == 1)
    }

    @Test("Dismissal resets consecutive auto-accepts")
    func dismissalResetsAutoAccepts() {
        let learner = TestSuggestionLearner()
        learner.recordSelection("A")
        learner.recordSelection("A")
        let key = learner.patternKey(for: "A")
        #expect(learner.consecutiveAutoAccepts[key] == 2)

        learner.recordDismissal()
        #expect(learner.consecutiveAutoAccepts[key] == 0)
    }

    @Test("Selecting different pattern resets other consecutive counts")
    func differentPatternResetsOthers() {
        let learner = TestSuggestionLearner()
        learner.recordSelection("A")
        learner.recordSelection("A")
        learner.recordSelection("A")
        let keyA = learner.patternKey(for: "A")
        #expect(learner.consecutiveAutoAccepts[keyA] == 3)

        learner.recordSelection("B")
        #expect(learner.consecutiveAutoAccepts[keyA] == 0)
        let keyB = learner.patternKey(for: "B")
        #expect(learner.consecutiveAutoAccepts[keyB] == 1)
    }

    @Test("Acceptance rate calculation")
    func acceptanceRate() {
        let learner = TestSuggestionLearner()
        #expect(learner.acceptanceRate == 0) // Zero division safe

        learner.recordSelection("A")
        #expect(learner.acceptanceRate == 1.0)

        learner.recordDismissal()
        #expect(learner.acceptanceRate == 0.5)

        learner.recordDismissal()
        #expect(learner.acceptanceRate == 1.0 / 3.0)
    }

    @Test("Auto-prompt disabled by default")
    func autoPromptDisabledByDefault() {
        let learner = TestSuggestionLearner()
        for _ in 0..<10 {
            learner.recordSelection("A")
        }
        #expect(learner.shouldAutoPrompt("A") == false)
    }

    @Test("Auto-prompt triggers after threshold when enabled")
    func autoPromptAfterThreshold() {
        let learner = TestSuggestionLearner()
        learner.isAutoPromptEnabled = true
        for _ in 0..<4 {
            learner.recordSelection("A")
        }
        #expect(learner.shouldAutoPrompt("A") == false) // Below threshold

        learner.recordSelection("A") // 5th consecutive
        #expect(learner.shouldAutoPrompt("A") == true)
    }

    @Test("Auto-prompt resets after dismissal")
    func autoPromptResetsAfterDismissal() {
        let learner = TestSuggestionLearner()
        learner.isAutoPromptEnabled = true
        for _ in 0..<5 {
            learner.recordSelection("A")
        }
        #expect(learner.shouldAutoPrompt("A") == true)

        learner.recordDismissal()
        #expect(learner.shouldAutoPrompt("A") == false)
    }

    @Test("Pattern key normalization")
    func patternKeyNormalization() {
        let learner = TestSuggestionLearner()
        let key = learner.patternKey(for: "Explain this code step by step")
        #expect(key == "explain_this_code_step_by_step")
        #expect(key.count <= 40)
    }

    @Test("Long text pattern key truncated to 40 chars")
    func patternKeyTruncation() {
        let learner = TestSuggestionLearner()
        let longText = "This is a very long suggestion text that exceeds forty characters easily"
        let key = learner.patternKey(for: longText)
        #expect(key.count <= 40)
    }
}

@Suite("G1 Follow-Up — Number Selection")
struct G1NumberSelectionTests {

    @Test("Number 1 selects first suggestion")
    func numberOneSelectsFirst() {
        let suggestions = [
            TestFollowUpSuggestion(text: "First option"),
            TestFollowUpSuggestion(text: "Second option"),
            TestFollowUpSuggestion(text: "Third option")
        ]
        let result = resolveNumberSelection(input: "1", suggestions: suggestions)
        #expect(result == "First option")
    }

    @Test("Number 3 selects third suggestion")
    func numberThreeSelectsThird() {
        let suggestions = [
            TestFollowUpSuggestion(text: "First"),
            TestFollowUpSuggestion(text: "Second"),
            TestFollowUpSuggestion(text: "Third")
        ]
        let result = resolveNumberSelection(input: "3", suggestions: suggestions)
        #expect(result == "Third")
    }

    @Test("Number out of range treated as regular text")
    func numberOutOfRange() {
        let suggestions = [
            TestFollowUpSuggestion(text: "Only option")
        ]
        let result = resolveNumberSelection(input: "5", suggestions: suggestions)
        #expect(result == "5")
    }

    @Test("Zero treated as regular text")
    func zeroIsRegularText() {
        let suggestions = [TestFollowUpSuggestion(text: "First")]
        let result = resolveNumberSelection(input: "0", suggestions: suggestions)
        #expect(result == "0")
    }

    @Test("Negative number treated as regular text")
    func negativeNumber() {
        let suggestions = [TestFollowUpSuggestion(text: "First")]
        let result = resolveNumberSelection(input: "-1", suggestions: suggestions)
        #expect(result == "-1")
    }

    @Test("Non-numeric input passed through")
    func nonNumericInput() {
        let suggestions = [TestFollowUpSuggestion(text: "First")]
        let result = resolveNumberSelection(input: "Hello world", suggestions: suggestions)
        #expect(result == "Hello world")
    }

    @Test("Empty suggestions list passes number through")
    func emptySuggestions() {
        let result = resolveNumberSelection(input: "1", suggestions: [])
        #expect(result == "1")
    }

    @Test("Whitespace-trimmed input")
    func whitespaceInput() {
        let suggestions = [TestFollowUpSuggestion(text: "First")]
        let result = resolveNumberSelection(input: "  1  ", suggestions: suggestions)
        #expect(result == "First")
    }

    @Test("Max number selects last")
    func maxNumberSelectsLast() {
        let suggestions = [
            TestFollowUpSuggestion(text: "A"),
            TestFollowUpSuggestion(text: "B"),
            TestFollowUpSuggestion(text: "C"),
            TestFollowUpSuggestion(text: "D")
        ]
        let result = resolveNumberSelection(input: "4", suggestions: suggestions)
        #expect(result == "D")
    }
}

@Suite("G1 Follow-Up — Preference Ranking")
struct G1RankingTests {

    @Test("Previously selected suggestions ranked higher")
    func selectedRankedHigher() {
        let selectionCounts = [
            "write_tests_for_this_code": 10,
            "explain_this_code_step_by_step": 2
        ]
        let response = "```swift\ncode\n```"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "write code", taskType: nil,
            selectionCounts: selectionCounts
        )
        // "Write tests" should be ranked first due to higher count
        #expect(suggestions.first?.text == "Write tests for this code")
    }

    @Test("No selection history preserves original order")
    func noHistoryPreservesOrder() {
        let response = "```swift\ncode\n```"
        let suggestions = TestSuggestionGenerator.generate(
            response: response, query: "code", taskType: nil
        )
        #expect(suggestions.first?.text == "Explain this code step by step")
    }
}

@Suite("G1 Follow-Up — Persistence")
struct G1PersistenceTests {

    @Test("PersistentState is Codable")
    func persistentStateCodable() throws {
        struct PersistentState: Codable {
            var selectionCounts: [String: Int]
            var totalSelections: Int
            var totalDismissals: Int
            var consecutiveAutoAccepts: [String: Int]
        }

        let state = PersistentState(
            selectionCounts: ["explain": 5, "tests": 3],
            totalSelections: 8,
            totalDismissals: 2,
            consecutiveAutoAccepts: ["explain": 2]
        )
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PersistentState.self, from: data)
        #expect(decoded.selectionCounts == state.selectionCounts)
        #expect(decoded.totalSelections == state.totalSelections)
        #expect(decoded.totalDismissals == state.totalDismissals)
        #expect(decoded.consecutiveAutoAccepts == state.consecutiveAutoAccepts)
    }
}
