import Foundation
import OSLog
import SwiftData

// MARK: - Swift Knowledge Learner
// Continuously learns from coding sessions, extracts patterns, and builds a knowledge base
// for optimal Swift code generation
//
// Supporting types (UserFeedback, SwiftLearnedPattern, CodeSnippet, DTOs, etc.)
// are in SwiftKnowledgeLearnerTypes.swift

@MainActor
@Observable
final class SwiftKnowledgeLearner {
    // periphery:ignore - Reserved: shared static property — reserved for future feature activation
    static let shared = SwiftKnowledgeLearner()

    private let logger = Logger(subsystem: "ai.thea.app", category: "SwiftKnowledgeLearner")

    /// Last persistence error, observable by UI for user feedback
    private(set) var lastPersistenceError: String?

    private var modelContext: ModelContext?

    // Knowledge Categories
    private(set) var learnedPatterns: [SwiftLearnedPattern] = []
    private(set) var codeSnippets: [CodeSnippet] = []
    private(set) var errorResolutions: [ErrorResolution] = []
    private(set) var bestPractices: [BestPractice] = []

    // Learning Statistics
    private(set) var totalSessionsAnalyzed = 0
    private(set) var totalPatternsLearned = 0
    private(set) var lastLearningUpdate: Date?

    // Configuration
    struct Configuration: Codable, Sendable {
        var enableContinuousLearning: Bool = true
        var enablePatternExtraction: Bool = true
        var enableErrorLearning: Bool = true
        var enableBestPracticeDetection: Bool = true
        // periphery:ignore - Reserved: shared static property reserved for future feature activation
        var minConfidenceForStorage: Double = 0.7
        var maxPatternsPerCategory: Int = 100
        var patternDecayDays: Int = 90
    }

    private(set) var configuration = Configuration()

    private init() {
        loadConfiguration()
    }

    // periphery:ignore - Reserved: setModelContext(_:) instance method — reserved for future feature activation
    func setModelContext(_ context: ModelContext) {
        modelContext = context
        Task {
            await loadStoredKnowledge()
        }
    }

    // MARK: - Knowledge Extraction from Conversations

    // periphery:ignore - Reserved: analyzeConversationTurn(userMessage:assistantResponse:wasSuccessful:userFeedback:) instance method — reserved for future feature activation
    /// Analyzes a conversation turn and extracts learnable knowledge
    func analyzeConversationTurn(
        userMessage: String,
        assistantResponse: String,
        wasSuccessful: Bool,
        userFeedback: UserFeedback? = nil
    ) async {
        guard configuration.enableContinuousLearning else { return }

        // 1. Detect if this is a coding conversation
        let isCodingSession = detectCodingContext(userMessage, assistantResponse)
        guard isCodingSession else { return }

        // 2. Extract code blocks
        let codeBlocks = extractCodeBlocks(from: assistantResponse)

        // periphery:ignore - Reserved: setModelContext(_:) instance method reserved for future feature activation
        // 3. Learn from successful patterns
        if wasSuccessful || userFeedback == .positive {
            for code in codeBlocks {
                await learnFromSuccessfulCode(code, context: userMessage)
            }
        }

        // 4. Learn from errors/corrections
        if let feedback = userFeedback, feedback == .negative || feedback == .correction {
            // periphery:ignore - Reserved: analyzeConversationTurn(userMessage:assistantResponse:wasSuccessful:userFeedback:) instance method reserved for future feature activation
            await learnFromCorrection(
                original: assistantResponse,
                correctedContext: userMessage
            )
        }

        // 5. Extract best practices
        if configuration.enableBestPracticeDetection {
            await extractBestPractices(from: codeBlocks, context: userMessage)
        }

        totalSessionsAnalyzed += 1
        lastLearningUpdate = Date()
    }

    // periphery:ignore - Reserved: analyzeHistoricalData(conversations:) instance method — reserved for future feature activation
    /// Bulk analyze historical conversation data
    func analyzeHistoricalData(conversations: [ConversationData]) async -> LearningReport {
        var report = LearningReport()

        for conversation in conversations {
            for turn in conversation.turns {
                await analyzeConversationTurn(
                    userMessage: turn.userMessage,
                    assistantResponse: turn.assistantResponse,
                    wasSuccessful: turn.wasSuccessful,
                    userFeedback: turn.feedback
                )

                report.turnsAnalyzed += 1
            }
        }

        report.patternsExtracted = totalPatternsLearned
        report.completedAt = Date()

        return report
    }

    // MARK: - Pattern Detection

// periphery:ignore - Reserved: analyzeHistoricalData(conversations:) instance method reserved for future feature activation

    private func detectCodingContext(_ userMessage: String, _ response: String) -> Bool {
        let codingKeywords = [
            "swift", "code", "function", "class", "struct", "protocol",
            "implement", "fix", "error", "compile", "xcode", "ios", "macos",
            "swiftui", "uikit", "async", "await", "actor", "@main", "import"
        ]

        let combined = (userMessage + " " + response).lowercased()
        let keywordMatches = codingKeywords.filter { combined.contains($0) }.count

        // Also check for code blocks
        let hasCodeBlocks = response.contains("```")

        return keywordMatches >= 2 || hasCodeBlocks
    }

    // periphery:ignore - Reserved: extractCodeBlocks(from:) instance method — reserved for future feature activation
    private func extractCodeBlocks(from text: String) -> [String] {
        var blocks: [String] = []
        let pattern = "```(?:swift)?\\n?([\\s\\S]*?)```"

        let regex: NSRegularExpression
        do {
            // periphery:ignore - Reserved: detectCodingContext(_:_:) instance method reserved for future feature activation
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            logger.error("Failed to compile code block regex: \(error.localizedDescription)")
            return blocks
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                blocks.append(String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return blocks
    // periphery:ignore - Reserved: extractCodeBlocks(from:) instance method reserved for future feature activation
    }

    // MARK: - Learning Methods

    // periphery:ignore - Reserved: learnFromSuccessfulCode(_:context:) instance method — reserved for future feature activation
    private func learnFromSuccessfulCode(_ code: String, context: String) async {
        guard configuration.enablePatternExtraction else { return }

        // Extract patterns from the code
        let patterns = extractPatterns(from: code)

        for pattern in patterns {
            // Check if we already know this pattern
            if let existing = learnedPatterns.first(where: { $0.patternSignature == pattern.signature }) {
                // Reinforce existing pattern
                existing.occurrenceCount += 1
                existing.confidence = min(1.0, existing.confidence + 0.05)
                existing.lastSeen = Date()
            } else {
                // Learn new pattern
                let newPattern = SwiftLearnedPattern(
                    category: pattern.category,
                    patternSignature: pattern.signature,
                    exampleCode: code,
                    context: context,
                    // periphery:ignore - Reserved: learnFromSuccessfulCode(_:context:) instance method reserved for future feature activation
                    confidence: configuration.minConfidenceForStorage
                )
                learnedPatterns.append(newPattern)
                totalPatternsLearned += 1
            }
        }

        // Store code snippet if high quality
        if isHighQualityCode(code) {
            let snippet = CodeSnippet(
                code: code,
                language: "swift",
                purpose: inferPurpose(from: context),
                tags: extractTags(from: code),
                qualityScore: calculateQualityScore(code)
            )
            codeSnippets.append(snippet)
        }

        await persistKnowledge()
    }

    // periphery:ignore - Reserved: learnFromCorrection(original:correctedContext:) instance method — reserved for future feature activation
    private func learnFromCorrection(original: String, correctedContext: String) async {
        guard configuration.enableErrorLearning else { return }

        // Extract what went wrong
        let errorPatterns = detectErrorPatterns(in: original, correction: correctedContext)

        for error in errorPatterns {
            if let existing = errorResolutions.first(where: { $0.errorPattern == error.pattern }) {
                existing.occurrenceCount += 1
            } else {
                let resolution = ErrorResolution(
                    errorPattern: error.pattern,
                    errorType: error.type,
                    resolution: error.resolution,
                    preventionRule: error.preventionRule
                )
                errorResolutions.append(resolution)
            }
        }

// periphery:ignore - Reserved: learnFromCorrection(original:correctedContext:) instance method reserved for future feature activation

        await persistKnowledge()
    }

    // periphery:ignore - Reserved: extractBestPractices(from:context:) instance method — reserved for future feature activation
    private func extractBestPractices(from codeBlocks: [String], context: String) async {
        for code in codeBlocks {
            let practices = detectBestPracticesInCode(code)

            for practice in practices {
                if !bestPractices.contains(where: { $0.practiceId == practice.id }) {
                    let bp = BestPractice(
                        practiceId: practice.id,
                        category: practice.category,
                        title: practice.title,
                        description: practice.description,
                        exampleCode: practice.example,
                        context: context
                    )
                    bestPractices.append(bp)
                }
            }
        }
    // periphery:ignore - Reserved: extractBestPractices(from:context:) instance method reserved for future feature activation
    }

}

// MARK: - Pattern Extraction Helpers

extension SwiftKnowledgeLearner {
    // periphery:ignore - Reserved: ExtractedPattern type — reserved for future feature activation
    struct ExtractedPattern {
        let category: String
        let signature: String
    }

    // periphery:ignore - Reserved: extractPatterns(from:) instance method — reserved for future feature activation
    func extractPatterns(from code: String) -> [ExtractedPattern] {
        var patterns: [ExtractedPattern] = []

        if code.contains("actor ") {
            patterns.append(ExtractedPattern(category: "concurrency", signature: "actor_definition"))
        }
        if code.contains("async ") && code.contains("await ") {
            patterns.append(ExtractedPattern(category: "concurrency", signature: "async_await"))
        }
        if code.contains("Task {") || code.contains("Task.detached") {
            patterns.append(ExtractedPattern(category: "concurrency", signature: "task_creation"))
        }
        // periphery:ignore - Reserved: ExtractedPattern type reserved for future feature activation
        if code.contains("@Observable") || code.contains("@StateObject") {
            patterns.append(ExtractedPattern(category: "architecture", signature: "mvvm_observable"))
        }
        if code.contains("struct") && code.contains(": View") {
            // periphery:ignore - Reserved: extractPatterns(from:) instance method reserved for future feature activation
            patterns.append(ExtractedPattern(category: "swiftui", signature: "view_definition"))
        }
        if code.contains("do {") && code.contains("catch") {
            patterns.append(ExtractedPattern(category: "error_handling", signature: "try_catch"))
        }
        if code.contains("Result<") {
            patterns.append(ExtractedPattern(category: "error_handling", signature: "result_type"))
        }
        if code.contains("protocol ") && code.contains("extension ") {
            patterns.append(ExtractedPattern(category: "architecture", signature: "protocol_oriented"))
        }
        if code.contains("init(") && code.range(of: ":\\s*\\w+Protocol", options: .regularExpression) != nil {
            patterns.append(ExtractedPattern(category: "architecture", signature: "dependency_injection"))
        }

        return patterns
    }

    // periphery:ignore - Reserved: isHighQualityCode(_:) instance method — reserved for future feature activation
    func isHighQualityCode(_ code: String) -> Bool {
        var score = 0
        if code.contains("///") || code.contains("/**") { score += 2 }
        if code.contains("async") || code.contains("await") || code.contains("actor") { score += 1 }
        if code.contains("throws") || code.contains("do {") { score += 1 }
        if code.contains("private ") || code.contains("public ") || code.contains("internal ") { score += 1 }
        if code.range(of: ":\\s*[A-Z]\\w+", options: .regularExpression) != nil { score += 1 }
        return score >= 3
    }

    // periphery:ignore - Reserved: calculateQualityScore(_:) instance method — reserved for future feature activation
    func calculateQualityScore(_ code: String) -> Double {
        var score = 0.5
        if code.contains("///") { score += 0.1 }
        if code.contains("async") { score += 0.05 }
        if code.contains("private ") { score += 0.05 }
        // periphery:ignore - Reserved: isHighQualityCode(_:) instance method reserved for future feature activation
        if code.contains("guard ") { score += 0.05 }
        if code.contains("throws") { score += 0.05 }
        if code.contains("force unwrap") || code.contains("!") && code.count(of: "!") > 3 { score -= 0.1 }
        if code.contains("// TODO") || code.contains("// FIXME") { score -= 0.05 }
        return min(1.0, max(0.0, score))
    }

    // periphery:ignore - Reserved: inferPurpose(from:) instance method — reserved for future feature activation
    func inferPurpose(from context: String) -> String {
        let lowercased = context.lowercased()
        // periphery:ignore - Reserved: calculateQualityScore(_:) instance method reserved for future feature activation
        if lowercased.contains("network") || lowercased.contains("api") || lowercased.contains("fetch") {
            return "Networking"
        }
        if lowercased.contains("ui") || lowercased.contains("view") || lowercased.contains("swiftui") {
            return "UI Component"
        }
        if lowercased.contains("data") || lowercased.contains("model") || lowercased.contains("persist") {
            return "Data Model"
        }
        if lowercased.contains("test") { return "Testing" }
        if lowercased.contains("error") || lowercased.contains("handle") { return "Error Handling" }
        // periphery:ignore - Reserved: inferPurpose(from:) instance method reserved for future feature activation
        return "General"
    }

    // periphery:ignore - Reserved: extractTags(from:) instance method — reserved for future feature activation
    func extractTags(from code: String) -> [String] {
        var tags: [String] = []
        if code.contains("@MainActor") { tags.append("MainActor") }
        if code.contains("@Observable") { tags.append("Observable") }
        if code.contains("SwiftUI") { tags.append("SwiftUI") }
        if code.contains("Combine") { tags.append("Combine") }
        if code.contains("async") { tags.append("Async") }
        if code.contains("actor ") { tags.append("Actor") }
        if code.contains("protocol ") { tags.append("Protocol") }
        if code.contains("extension ") { tags.append("Extension") }
        return tags
    }
// periphery:ignore - Reserved: extractTags(from:) instance method reserved for future feature activation
}

// MARK: - Error Detection & Best Practices

extension SwiftKnowledgeLearner {
    // periphery:ignore - Reserved: DetectedError type — reserved for future feature activation
    struct DetectedError {
        let pattern: String
        let type: String
        let resolution: String
        let preventionRule: String
    }

    // periphery:ignore - Reserved: detectErrorPatterns(in:correction:) instance method — reserved for future feature activation
    func detectErrorPatterns(in original: String, correction: String) -> [DetectedError] {
        var errors: [DetectedError] = []
        let lowerCorrection = correction.lowercased()

        // periphery:ignore - Reserved: DetectedError type reserved for future feature activation
        if lowerCorrection.contains("sendable") {
            errors.append(DetectedError(
                pattern: "non_sendable_type", type: "Concurrency",
                resolution: "Add @Sendable or @unchecked Sendable conformance",
                preventionRule: "Always check Sendable conformance for types used across concurrency boundaries"
            ))
        // periphery:ignore - Reserved: detectErrorPatterns(in:correction:) instance method reserved for future feature activation
        }
        if lowerCorrection.contains("mainactor") {
            errors.append(DetectedError(
                pattern: "missing_mainactor", type: "Concurrency",
                resolution: "Add @MainActor annotation to UI-related code",
                preventionRule: "UI code should always be annotated with @MainActor"
            ))
        }
        if lowerCorrection.contains("deprecated") {
            errors.append(DetectedError(
                pattern: "deprecated_api", type: "API",
                resolution: "Use the suggested modern replacement",
                preventionRule: "Check API availability and prefer non-deprecated alternatives"
            ))
        }
        if lowerCorrection.contains("optional") || lowerCorrection.contains("nil") {
            errors.append(DetectedError(
                pattern: "optional_handling", type: "Safety",
                resolution: "Use guard let, if let, or optional chaining",
                preventionRule: "Handle optionals safely, avoid force unwrapping"
            ))
        }

        return errors
    }

    // periphery:ignore - Reserved: DetectedBestPractice type — reserved for future feature activation
    struct DetectedBestPractice {
        let id: String
        let category: String
        let title: String
        let description: String
        let example: String
    }

    // periphery:ignore - Reserved: detectBestPracticesInCode(_:) instance method — reserved for future feature activation
    func detectBestPracticesInCode(_ code: String) -> [DetectedBestPractice] {
        // periphery:ignore - Reserved: DetectedBestPractice type reserved for future feature activation
        var practices: [DetectedBestPractice] = []

        if code.contains("actor ") && code.contains("isolated") {
            practices.append(DetectedBestPractice(
                id: "actor_isolation", category: "Concurrency",
                title: "Proper Actor Isolation",
                description: "Using actors with proper isolation boundaries for thread safety",
                // periphery:ignore - Reserved: detectBestPracticesInCode(_:) instance method reserved for future feature activation
                example: code
            ))
        }
        if code.contains("TaskGroup") || code.contains("withTaskGroup") {
            practices.append(DetectedBestPractice(
                id: "structured_concurrency", category: "Concurrency",
                title: "Structured Concurrency",
                description: "Using TaskGroup for managing concurrent operations",
                example: code
            ))
        }
        if code.contains("guard ") && code.contains("else { return") {
            practices.append(DetectedBestPractice(
                id: "guard_early_return", category: "Code Style",
                title: "Guard Early Return",
                description: "Using guard statements for early returns and cleaner code flow",
                example: code
            ))
        }

        return practices
    }
}

// MARK: - Knowledge Retrieval

extension SwiftKnowledgeLearner {
    // periphery:ignore - Reserved: getRelevantPatterns(for:limit:) instance method — reserved for future feature activation
    /// Get relevant patterns for a given coding task
    func getRelevantPatterns(for query: String, limit: Int = 5) -> [SwiftLearnedPattern] {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))

        return learnedPatterns
            .map { pattern -> (pattern: SwiftLearnedPattern, score: Double) in
                let contextWords = Set(pattern.context.lowercased().split(separator: " ").map(String.init))
                let overlap = Double(queryWords.intersection(contextWords).count)
                // periphery:ignore - Reserved: getRelevantPatterns(for:limit:) instance method reserved for future feature activation
                let score = (overlap / max(1, Double(queryWords.count))) * pattern.confidence
                return (pattern, score)
            }
            .filter { $0.score > 0.1 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.pattern)
    }

    // periphery:ignore - Reserved: getRelevantSnippets(for:tags:limit:) instance method — reserved for future feature activation
    /// Get code snippets relevant to a task
    func getRelevantSnippets(for purpose: String, tags: [String] = [], limit: Int = 3) -> [CodeSnippet] {
        codeSnippets
            .filter { snippet in
                let purposeMatch = snippet.purpose.lowercased().contains(purpose.lowercased())
                let snippetTags = Set(snippet.tags)
                let searchTags = Set(tags)
                // periphery:ignore - Reserved: getRelevantSnippets(for:tags:limit:) instance method reserved for future feature activation
                let tagMatch = tags.isEmpty || !snippetTags.isDisjoint(with: searchTags)
                return purposeMatch || tagMatch
            }
            .sorted { $0.qualityScore > $1.qualityScore }
            .prefix(limit)
            .map { $0 }
    }

    // periphery:ignore - Reserved: getErrorPreventionRules(for:) instance method — reserved for future feature activation
    /// Get error prevention rules
    func getErrorPreventionRules(for errorType: String) -> [String] {
        errorResolutions
            .filter { $0.errorType.lowercased().contains(errorType.lowercased()) }
            .sorted { $0.occurrenceCount > $1.occurrenceCount }
            .map(\.preventionRule)
    // periphery:ignore - Reserved: getErrorPreventionRules(for:) instance method reserved for future feature activation
    }

    // periphery:ignore - Reserved: getBestPractices(for:) instance method — reserved for future feature activation
    /// Get best practices for a category
    func getBestPractices(for category: String) -> [BestPractice] {
        bestPractices.filter { $0.category.lowercased() == category.lowercased() }
    }
}

// periphery:ignore - Reserved: getBestPractices(for:) instance method reserved for future feature activation

// MARK: - Persistence & Configuration

extension SwiftKnowledgeLearner {
    func persistKnowledge() async {
        if learnedPatterns.count > configuration.maxPatternsPerCategory * 10 {
            learnedPatterns = learnedPatterns
                // periphery:ignore - Reserved: persistKnowledge() instance method reserved for future feature activation
                .sorted { $0.confidence * Double($0.occurrenceCount) > $1.confidence * Double($1.occurrenceCount) }
                .prefix(configuration.maxPatternsPerCategory * 10)
                .map { $0 }
        }

        let encoder = JSONEncoder()
        lastPersistenceError = nil

        do {
            let patternsData = try encoder.encode(learnedPatterns.map(SwiftLearnedPatternDTO.init))
            UserDefaults.standard.set(patternsData, forKey: "SwiftKnowledgeLearner.patterns")
        } catch {
            logger.error("Failed to encode learned patterns: \(error.localizedDescription)")
            lastPersistenceError = "Failed to save learned patterns: \(error.localizedDescription)"
        }

        do {
            let snippetsData = try encoder.encode(codeSnippets.map(CodeSnippetDTO.init))
            UserDefaults.standard.set(snippetsData, forKey: "SwiftKnowledgeLearner.snippets")
        } catch {
            logger.error("Failed to encode code snippets: \(error.localizedDescription)")
            lastPersistenceError = "Failed to save code snippets: \(error.localizedDescription)"
        }

        do {
            let errorsData = try encoder.encode(errorResolutions.map(ErrorResolutionDTO.init))
            UserDefaults.standard.set(errorsData, forKey: "SwiftKnowledgeLearner.errors")
        } catch {
            logger.error("Failed to encode error resolutions: \(error.localizedDescription)")
            lastPersistenceError = "Failed to save error resolutions: \(error.localizedDescription)"
        }

        UserDefaults.standard.set(totalSessionsAnalyzed, forKey: "SwiftKnowledgeLearner.sessions")
        UserDefaults.standard.set(totalPatternsLearned, forKey: "SwiftKnowledgeLearner.patternsCount")
    }

    func loadStoredKnowledge() async {
        let decoder = JSONDecoder()

// periphery:ignore - Reserved: loadStoredKnowledge() instance method reserved for future feature activation

        if let data = UserDefaults.standard.data(forKey: "SwiftKnowledgeLearner.patterns") {
            do {
                let dtos = try decoder.decode([SwiftLearnedPatternDTO].self, from: data)
                learnedPatterns = dtos.map(SwiftLearnedPattern.init)
            } catch {
                logger.error("Failed to decode learned patterns: \(error.localizedDescription)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: "SwiftKnowledgeLearner.snippets") {
            do {
                let dtos = try decoder.decode([CodeSnippetDTO].self, from: data)
                codeSnippets = dtos.map(CodeSnippet.init)
            } catch {
                logger.error("Failed to decode code snippets: \(error.localizedDescription)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: "SwiftKnowledgeLearner.errors") {
            do {
                let dtos = try decoder.decode([ErrorResolutionDTO].self, from: data)
                errorResolutions = dtos.map(ErrorResolution.init)
            } catch {
                logger.error("Failed to decode error resolutions: \(error.localizedDescription)")
            }
        }

        totalSessionsAnalyzed = UserDefaults.standard.integer(forKey: "SwiftKnowledgeLearner.sessions")
        totalPatternsLearned = UserDefaults.standard.integer(forKey: "SwiftKnowledgeLearner.patternsCount")
    }

    func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: "SwiftKnowledgeLearner.config") else { return }
        do {
            configuration = try JSONDecoder().decode(Configuration.self, from: data)
        } catch {
            logger.error("Failed to decode learner configuration: \(error.localizedDescription)")
        }
    }

    func updateConfiguration(_ config: Configuration) {
        // periphery:ignore - Reserved: updateConfiguration(_:) instance method reserved for future feature activation
        configuration = config
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: "SwiftKnowledgeLearner.config")
        } catch {
            logger.error("Failed to encode learner configuration: \(error.localizedDescription)")
            lastPersistenceError = "Failed to save configuration: \(error.localizedDescription)"
        }
    }

    // periphery:ignore - Reserved: clearAllKnowledge() instance method reserved for future feature activation
    /// Clear all learned knowledge
    func clearAllKnowledge() async {
        learnedPatterns.removeAll()
        codeSnippets.removeAll()
        errorResolutions.removeAll()
        bestPractices.removeAll()
        totalSessionsAnalyzed = 0
        totalPatternsLearned = 0

        UserDefaults.standard.removeObject(forKey: "SwiftKnowledgeLearner.patterns")
        UserDefaults.standard.removeObject(forKey: "SwiftKnowledgeLearner.snippets")
        UserDefaults.standard.removeObject(forKey: "SwiftKnowledgeLearner.errors")
        UserDefaults.standard.removeObject(forKey: "SwiftKnowledgeLearner.sessions")
        UserDefaults.standard.removeObject(forKey: "SwiftKnowledgeLearner.patternsCount")
    }
}

// Supporting types are in SwiftKnowledgeLearnerTypes.swift
