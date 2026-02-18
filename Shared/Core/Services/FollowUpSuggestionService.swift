import Foundation
import OSLog
#if canImport(TheaModels)
import TheaModels
#endif

// MARK: - Follow-Up Suggestion Service

/// Generates contextually relevant follow-up prompts after every AI response.
/// Uses heuristic analysis of the response + task type to suggest 2-4 follow-ups.
/// Learns from user selections via BehavioralFingerprint integration.
@MainActor
final class FollowUpSuggestionService: ObservableObject {
    static let shared = FollowUpSuggestionService()
    private let logger = Logger(subsystem: "com.thea.app", category: "FollowUpSuggestionService")

    @Published var latestSuggestions: [FollowUpSuggestion] = []

    /// Track how often each suggestion pattern is selected (for learning)
    private var selectionCounts: [String: Int] = [:]
    private var totalSelections: Int = 0
    private var totalDismissals: Int = 0

    /// Auto-prompt threshold: after N consecutive acceptances of same pattern, auto-execute
    private var consecutiveAutoAccepts: [String: Int] = [:]
    private let autoPromptThreshold = 5
    var isAutoPromptEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "followUp.autoPrompt") }
        set { UserDefaults.standard.set(newValue, forKey: "followUp.autoPrompt") }
    }

    private init() {
        loadState()
    }

    // MARK: - Generation

    /// Generate follow-up suggestions based on AI response content and task type.
    func generate(
        response: String,
        query: String,
        taskType: String?,
        modelName: String? = nil
    ) -> [FollowUpSuggestion] {
        var suggestions: [FollowUpSuggestion] = []

        let responseLength = response.count
        let hasCode = response.contains("```")
        let hasList = response.contains("\n- ") || response.contains("\n1.")
        let hasQuestion = response.contains("?")
        let taskCategory = taskType ?? "general"

        // Code-related follow-ups
        if hasCode {
            suggestions.append(FollowUpSuggestion(
                text: "Explain this code step by step",
                icon: "text.magnifyingglass"
            ))
            suggestions.append(FollowUpSuggestion(
                text: "Add error handling and edge cases",
                icon: "exclamationmark.shield"
            ))
            suggestions.append(FollowUpSuggestion(
                text: "Write tests for this code",
                icon: "checkmark.circle"
            ))
        }

        // List-based follow-ups
        if hasList {
            suggestions.append(FollowUpSuggestion(
                text: "Elaborate on each point",
                icon: "list.bullet.indent"
            ))
            suggestions.append(FollowUpSuggestion(
                text: "Which of these should I prioritize?",
                icon: "star"
            ))
        }

        // Long response follow-ups
        if responseLength > 2000 {
            suggestions.append(FollowUpSuggestion(
                text: "Summarize the key takeaways",
                icon: "text.redaction"
            ))
        }

        // Task-type specific suggestions
        switch taskCategory {
        case "research", "factual":
            suggestions.append(FollowUpSuggestion(
                text: "What are the sources for this?",
                icon: "book"
            ))
            suggestions.append(FollowUpSuggestion(
                text: "What are the counterarguments?",
                icon: "arrow.left.arrow.right"
            ))
        case "analysis", "reasoning":
            suggestions.append(FollowUpSuggestion(
                text: "What assumptions does this analysis make?",
                icon: "questionmark.circle"
            ))
        case "creative", "writing":
            suggestions.append(FollowUpSuggestion(
                text: "Make it more concise",
                icon: "scissors"
            ))
            suggestions.append(FollowUpSuggestion(
                text: "Adjust the tone to be more formal",
                icon: "textformat"
            ))
        case "codeGeneration", "debugging", "codeReview":
            if !hasCode {
                suggestions.append(FollowUpSuggestion(
                    text: "Show me the implementation",
                    icon: "chevron.left.forwardslash.chevron.right"
                ))
            }
        case "planning":
            suggestions.append(FollowUpSuggestion(
                text: "Create a timeline for this plan",
                icon: "calendar"
            ))
            suggestions.append(FollowUpSuggestion(
                text: "What could go wrong?",
                icon: "exclamationmark.triangle"
            ))
        default:
            break
        }

        // If response posed a question, suggest answering it
        if hasQuestion && !hasCode {
            suggestions.append(FollowUpSuggestion(
                text: "Yes, please continue",
                icon: "arrow.right.circle"
            ))
        }

        // Universal fallback: dive deeper
        if suggestions.count < 2 {
            suggestions.append(FollowUpSuggestion(
                text: "Tell me more about this",
                icon: "plus.magnifyingglass"
            ))
            suggestions.append(FollowUpSuggestion(
                text: "How does this compare to alternatives?",
                icon: "arrow.triangle.branch"
            ))
        }

        // Rank by learned preference and limit to 4
        let ranked = rankByPreference(suggestions)
        let result = Array(ranked.prefix(4))
        latestSuggestions = result
        return result
    }

    // MARK: - Learning

    /// Record that the user selected a follow-up suggestion.
    func recordSelection(_ suggestion: FollowUpSuggestion) {
        let pattern = patternKey(for: suggestion)
        selectionCounts[pattern, default: 0] += 1
        totalSelections += 1
        consecutiveAutoAccepts[pattern, default: 0] += 1

        // Reset other patterns' consecutive counts
        for key in consecutiveAutoAccepts.keys where key != pattern {
            consecutiveAutoAccepts[key] = 0
        }

        saveState()
    }

    /// Record that the user dismissed/ignored suggestions.
    func recordDismissal() {
        totalDismissals += 1
        for key in consecutiveAutoAccepts.keys {
            consecutiveAutoAccepts[key] = 0
        }
        saveState()
    }

    /// Check if a suggestion pattern should auto-execute (user always picks it).
    func shouldAutoPrompt(_ suggestion: FollowUpSuggestion) -> Bool {
        guard isAutoPromptEnabled else { return false }
        let pattern = patternKey(for: suggestion)
        return (consecutiveAutoAccepts[pattern] ?? 0) >= autoPromptThreshold
    }

    /// Acceptance rate (0.0-1.0).
    var acceptanceRate: Double {
        let total = totalSelections + totalDismissals
        guard total > 0 else { return 0 }
        return Double(totalSelections) / Double(total)
    }

    // MARK: - Private

    private func patternKey(for suggestion: FollowUpSuggestion) -> String {
        // Normalize to a category key for learning
        suggestion.text.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .prefix(40)
            .description
    }

    private func rankByPreference(_ suggestions: [FollowUpSuggestion]) -> [FollowUpSuggestion] {
        suggestions.sorted { a, b in
            let countA = selectionCounts[patternKey(for: a)] ?? 0
            let countB = selectionCounts[patternKey(for: b)] ?? 0
            return countA > countB
        }
    }

    // MARK: - Persistence

    private var stateURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            logger.debug("Could not create Thea app support directory: \(error.localizedDescription)")
        }
        return dir.appendingPathComponent("followup_suggestions.json")
    }

    private struct PersistentState: Codable {
        var selectionCounts: [String: Int]
        var totalSelections: Int
        var totalDismissals: Int
        var consecutiveAutoAccepts: [String: Int]
    }

    private func saveState() {
        let state = PersistentState(
            selectionCounts: selectionCounts,
            totalSelections: totalSelections,
            totalDismissals: totalDismissals,
            consecutiveAutoAccepts: consecutiveAutoAccepts
        )
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateURL)
        } catch {
            logger.debug("Could not save follow-up suggestion state: \(error.localizedDescription)")
        }
    }

    private func loadState() {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return }
        do {
            let data = try Data(contentsOf: stateURL)
            let state = try JSONDecoder().decode(PersistentState.self, from: data)
            selectionCounts = state.selectionCounts
            totalSelections = state.totalSelections
            totalDismissals = state.totalDismissals
            consecutiveAutoAccepts = state.consecutiveAutoAccepts
        } catch {
            logger.debug("Could not load follow-up suggestion state: \(error.localizedDescription)")
        }
    }
}
