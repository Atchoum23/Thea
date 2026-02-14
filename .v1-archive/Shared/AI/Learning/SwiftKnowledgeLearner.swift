import Foundation
import SwiftData

// MARK: - Swift Knowledge Learner
// Continuously learns from coding sessions, extracts patterns, and builds a knowledge base
// for optimal Swift code generation

@MainActor
@Observable
final class SwiftKnowledgeLearner {
    static let shared = SwiftKnowledgeLearner()

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
        var minConfidenceForStorage: Double = 0.7
        var maxPatternsPerCategory: Int = 100
        var patternDecayDays: Int = 90
    }

    private(set) var configuration = Configuration()

    private init() {
        loadConfiguration()
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        Task {
            await loadStoredKnowledge()
        }
    }

    // MARK: - Knowledge Extraction from Conversations

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

        // 3. Learn from successful patterns
        if wasSuccessful || userFeedback == .positive {
            for code in codeBlocks {
                await learnFromSuccessfulCode(code, context: userMessage)
            }
        }

        // 4. Learn from errors/corrections
        if let feedback = userFeedback, feedback == .negative || feedback == .correction {
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

    private func extractCodeBlocks(from text: String) -> [String] {
        var blocks: [String] = []
        let pattern = "```(?:swift)?\\n?([\\s\\S]*?)```"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return blocks
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            if let range = Range(match.range(at: 1), in: text) {
                blocks.append(String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        return blocks
    }

    // MARK: - Learning Methods

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

        await persistKnowledge()
    }

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
    }

    // MARK: - Pattern Extraction Helpers

    private struct ExtractedPattern {
        let category: String
        let signature: String
    }

    private func extractPatterns(from code: String) -> [ExtractedPattern] {
        var patterns: [ExtractedPattern] = []

        // Actor pattern
        if code.contains("actor ") {
            patterns.append(ExtractedPattern(category: "concurrency", signature: "actor_definition"))
        }

        // Async/await pattern
        if code.contains("async ") && code.contains("await ") {
            patterns.append(ExtractedPattern(category: "concurrency", signature: "async_await"))
        }

        // Task pattern
        if code.contains("Task {") || code.contains("Task.detached") {
            patterns.append(ExtractedPattern(category: "concurrency", signature: "task_creation"))
        }

        // MVVM pattern
        if code.contains("@Observable") || code.contains("@StateObject") {
            patterns.append(ExtractedPattern(category: "architecture", signature: "mvvm_observable"))
        }

        // SwiftUI view pattern
        if code.contains("struct") && code.contains(": View") {
            patterns.append(ExtractedPattern(category: "swiftui", signature: "view_definition"))
        }

        // Error handling
        if code.contains("do {") && code.contains("catch") {
            patterns.append(ExtractedPattern(category: "error_handling", signature: "try_catch"))
        }

        // Result type
        if code.contains("Result<") {
            patterns.append(ExtractedPattern(category: "error_handling", signature: "result_type"))
        }

        // Protocol-oriented
        if code.contains("protocol ") && code.contains("extension ") {
            patterns.append(ExtractedPattern(category: "architecture", signature: "protocol_oriented"))
        }

        // Dependency injection
        if code.contains("init(") && code.range(of: ":\\s*\\w+Protocol", options: .regularExpression) != nil {
            patterns.append(ExtractedPattern(category: "architecture", signature: "dependency_injection"))
        }

        return patterns
    }

    private func isHighQualityCode(_ code: String) -> Bool {
        // Quality indicators
        var score = 0

        // Has documentation
        if code.contains("///") || code.contains("/**") {
            score += 2
        }

        // Uses modern Swift features
        if code.contains("async") || code.contains("await") || code.contains("actor") {
            score += 1
        }

        // Has proper error handling
        if code.contains("throws") || code.contains("do {") {
            score += 1
        }

        // Uses access control
        if code.contains("private ") || code.contains("public ") || code.contains("internal ") {
            score += 1
        }

        // Uses type annotations
        if code.range(of: ":\\s*[A-Z]\\w+", options: .regularExpression) != nil {
            score += 1
        }

        return score >= 3
    }

    private func calculateQualityScore(_ code: String) -> Double {
        var score = 0.5

        // Positive factors
        if code.contains("///") { score += 0.1 }
        if code.contains("async") { score += 0.05 }
        if code.contains("private ") { score += 0.05 }
        if code.contains("guard ") { score += 0.05 }
        if code.contains("throws") { score += 0.05 }

        // Negative factors
        if code.contains("force unwrap") || code.contains("!") && code.count(of: "!") > 3 {
            score -= 0.1
        }
        if code.contains("// TODO") || code.contains("// FIXME") {
            score -= 0.05
        }

        return min(1.0, max(0.0, score))
    }

    private func inferPurpose(from context: String) -> String {
        let lowercased = context.lowercased()

        if lowercased.contains("network") || lowercased.contains("api") || lowercased.contains("fetch") {
            return "Networking"
        }
        if lowercased.contains("ui") || lowercased.contains("view") || lowercased.contains("swiftui") {
            return "UI Component"
        }
        if lowercased.contains("data") || lowercased.contains("model") || lowercased.contains("persist") {
            return "Data Model"
        }
        if lowercased.contains("test") {
            return "Testing"
        }
        if lowercased.contains("error") || lowercased.contains("handle") {
            return "Error Handling"
        }

        return "General"
    }

    private func extractTags(from code: String) -> [String] {
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

    private struct DetectedError {
        let pattern: String
        let type: String
        let resolution: String
        let preventionRule: String
    }

    private func detectErrorPatterns(in original: String, correction: String) -> [DetectedError] {
        var errors: [DetectedError] = []

        // Detect common error patterns by comparing original and correction context
        let lowerCorrection = correction.lowercased()

        if lowerCorrection.contains("sendable") {
            errors.append(DetectedError(
                pattern: "non_sendable_type",
                type: "Concurrency",
                resolution: "Add @Sendable or @unchecked Sendable conformance",
                preventionRule: "Always check Sendable conformance for types used across concurrency boundaries"
            ))
        }

        if lowerCorrection.contains("mainactor") {
            errors.append(DetectedError(
                pattern: "missing_mainactor",
                type: "Concurrency",
                resolution: "Add @MainActor annotation to UI-related code",
                preventionRule: "UI code should always be annotated with @MainActor"
            ))
        }

        if lowerCorrection.contains("deprecated") {
            errors.append(DetectedError(
                pattern: "deprecated_api",
                type: "API",
                resolution: "Use the suggested modern replacement",
                preventionRule: "Check API availability and prefer non-deprecated alternatives"
            ))
        }

        if lowerCorrection.contains("optional") || lowerCorrection.contains("nil") {
            errors.append(DetectedError(
                pattern: "optional_handling",
                type: "Safety",
                resolution: "Use guard let, if let, or optional chaining",
                preventionRule: "Handle optionals safely, avoid force unwrapping"
            ))
        }

        return errors
    }

    private struct DetectedBestPractice {
        let id: String
        let category: String
        let title: String
        let description: String
        let example: String
    }

    private func detectBestPracticesInCode(_ code: String) -> [DetectedBestPractice] {
        var practices: [DetectedBestPractice] = []

        // Actor isolation
        if code.contains("actor ") && code.contains("isolated") {
            practices.append(DetectedBestPractice(
                id: "actor_isolation",
                category: "Concurrency",
                title: "Proper Actor Isolation",
                description: "Using actors with proper isolation boundaries for thread safety",
                example: code
            ))
        }

        // Structured concurrency
        if code.contains("TaskGroup") || code.contains("withTaskGroup") {
            practices.append(DetectedBestPractice(
                id: "structured_concurrency",
                category: "Concurrency",
                title: "Structured Concurrency",
                description: "Using TaskGroup for managing concurrent operations",
                example: code
            ))
        }

        // Guard early return
        if code.contains("guard ") && code.contains("else { return") {
            practices.append(DetectedBestPractice(
                id: "guard_early_return",
                category: "Code Style",
                title: "Guard Early Return",
                description: "Using guard statements for early returns and cleaner code flow",
                example: code
            ))
        }

        return practices
    }

    // MARK: - Knowledge Retrieval

    /// Get relevant patterns for a given coding task
    func getRelevantPatterns(for query: String, limit: Int = 5) -> [SwiftLearnedPattern] {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))

        return learnedPatterns
            .map { pattern -> (pattern: SwiftLearnedPattern, score: Double) in
                let contextWords = Set(pattern.context.lowercased().split(separator: " ").map(String.init))
                let overlap = Double(queryWords.intersection(contextWords).count)
                let score = (overlap / max(1, Double(queryWords.count))) * pattern.confidence
                return (pattern, score)
            }
            .filter { $0.score > 0.1 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.pattern)
    }

    /// Get code snippets relevant to a task
    func getRelevantSnippets(for purpose: String, tags: [String] = [], limit: Int = 3) -> [CodeSnippet] {
        codeSnippets
            .filter { snippet in
                let purposeMatch = snippet.purpose.lowercased().contains(purpose.lowercased())
                let snippetTags = Set(snippet.tags)
                let searchTags = Set(tags)
                let tagMatch = tags.isEmpty || !snippetTags.isDisjoint(with: searchTags)
                return purposeMatch || tagMatch
            }
            .sorted { $0.qualityScore > $1.qualityScore }
            .prefix(limit)
            .map { $0 }
    }

    /// Get error prevention rules
    func getErrorPreventionRules(for errorType: String) -> [String] {
        errorResolutions
            .filter { $0.errorType.lowercased().contains(errorType.lowercased()) }
            .sorted { $0.occurrenceCount > $1.occurrenceCount }
            .map(\.preventionRule)
    }

    /// Get best practices for a category
    func getBestPractices(for category: String) -> [BestPractice] {
        bestPractices.filter { $0.category.lowercased() == category.lowercased() }
    }

    // MARK: - Persistence

    private func persistKnowledge() async {
        // Enforce limits
        if learnedPatterns.count > configuration.maxPatternsPerCategory * 10 {
            // Remove old, low-confidence patterns
            learnedPatterns = learnedPatterns
                .sorted { $0.confidence * Double($0.occurrenceCount) > $1.confidence * Double($1.occurrenceCount) }
                .prefix(configuration.maxPatternsPerCategory * 10)
                .map { $0 }
        }

        // Save to UserDefaults (could be SwiftData in production)
        let encoder = JSONEncoder()

        if let patternsData = try? encoder.encode(learnedPatterns.map(SwiftLearnedPatternDTO.init)) {
            UserDefaults.standard.set(patternsData, forKey: "SwiftKnowledgeLearner.patterns")
        }

        if let snippetsData = try? encoder.encode(codeSnippets.map(CodeSnippetDTO.init)) {
            UserDefaults.standard.set(snippetsData, forKey: "SwiftKnowledgeLearner.snippets")
        }

        if let errorsData = try? encoder.encode(errorResolutions.map(ErrorResolutionDTO.init)) {
            UserDefaults.standard.set(errorsData, forKey: "SwiftKnowledgeLearner.errors")
        }

        UserDefaults.standard.set(totalSessionsAnalyzed, forKey: "SwiftKnowledgeLearner.sessions")
        UserDefaults.standard.set(totalPatternsLearned, forKey: "SwiftKnowledgeLearner.patternsCount")
    }

    private func loadStoredKnowledge() async {
        let decoder = JSONDecoder()

        if let data = UserDefaults.standard.data(forKey: "SwiftKnowledgeLearner.patterns"),
           let dtos = try? decoder.decode([SwiftLearnedPatternDTO].self, from: data)
        {
            learnedPatterns = dtos.map(SwiftLearnedPattern.init)
        }

        if let data = UserDefaults.standard.data(forKey: "SwiftKnowledgeLearner.snippets"),
           let dtos = try? decoder.decode([CodeSnippetDTO].self, from: data)
        {
            codeSnippets = dtos.map(CodeSnippet.init)
        }

        if let data = UserDefaults.standard.data(forKey: "SwiftKnowledgeLearner.errors"),
           let dtos = try? decoder.decode([ErrorResolutionDTO].self, from: data)
        {
            errorResolutions = dtos.map(ErrorResolution.init)
        }

        totalSessionsAnalyzed = UserDefaults.standard.integer(forKey: "SwiftKnowledgeLearner.sessions")
        totalPatternsLearned = UserDefaults.standard.integer(forKey: "SwiftKnowledgeLearner.patternsCount")
    }

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "SwiftKnowledgeLearner.config"),
           let config = try? JSONDecoder().decode(Configuration.self, from: data)
        {
            configuration = config
        }
    }

    func updateConfiguration(_ config: Configuration) {
        configuration = config
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "SwiftKnowledgeLearner.config")
        }
    }

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

// MARK: - Supporting Types

enum UserFeedback: String, Codable, Sendable {
    case positive
    case negative
    case correction
    case none
}

struct ConversationData: Sendable {
    let id: UUID
    let turns: [ConversationTurn]
}

struct ConversationTurn: Sendable {
    let userMessage: String
    let assistantResponse: String
    let wasSuccessful: Bool
    let feedback: UserFeedback?
}

struct LearningReport: Sendable {
    var turnsAnalyzed: Int = 0
    var patternsExtracted: Int = 0
    var completedAt: Date?
}

@Observable
final class SwiftLearnedPattern: Identifiable {
    let id = UUID()
    let category: String
    let patternSignature: String
    let exampleCode: String
    let context: String
    var confidence: Double
    var occurrenceCount = 1
    var lastSeen = Date()

    init(category: String, patternSignature: String, exampleCode: String, context: String, confidence: Double) {
        self.category = category
        self.patternSignature = patternSignature
        self.exampleCode = exampleCode
        self.context = context
        self.confidence = confidence
    }

    init(from dto: SwiftLearnedPatternDTO) {
        category = dto.category
        patternSignature = dto.patternSignature
        exampleCode = dto.exampleCode
        context = dto.context
        confidence = dto.confidence
        occurrenceCount = dto.occurrenceCount
        lastSeen = dto.lastSeen
    }
}

struct SwiftLearnedPatternDTO: Codable {
    let category: String
    let patternSignature: String
    let exampleCode: String
    let context: String
    let confidence: Double
    let occurrenceCount: Int
    let lastSeen: Date

    init(_ pattern: SwiftLearnedPattern) {
        category = pattern.category
        patternSignature = pattern.patternSignature
        exampleCode = pattern.exampleCode
        context = pattern.context
        confidence = pattern.confidence
        occurrenceCount = pattern.occurrenceCount
        lastSeen = pattern.lastSeen
    }
}

@Observable
final class CodeSnippet: Identifiable {
    let id = UUID()
    let code: String
    let language: String
    let purpose: String
    let tags: [String]
    let qualityScore: Double
    let createdAt = Date()

    init(code: String, language: String, purpose: String, tags: [String], qualityScore: Double) {
        self.code = code
        self.language = language
        self.purpose = purpose
        self.tags = tags
        self.qualityScore = qualityScore
    }

    init(from dto: CodeSnippetDTO) {
        code = dto.code
        language = dto.language
        purpose = dto.purpose
        tags = dto.tags
        qualityScore = dto.qualityScore
    }
}

struct CodeSnippetDTO: Codable {
    let code: String
    let language: String
    let purpose: String
    let tags: [String]
    let qualityScore: Double

    init(_ snippet: CodeSnippet) {
        code = snippet.code
        language = snippet.language
        purpose = snippet.purpose
        tags = snippet.tags
        qualityScore = snippet.qualityScore
    }
}

@Observable
final class ErrorResolution: Identifiable {
    let id = UUID()
    let errorPattern: String
    let errorType: String
    let resolution: String
    let preventionRule: String
    var occurrenceCount: Int = 1

    init(errorPattern: String, errorType: String, resolution: String, preventionRule: String) {
        self.errorPattern = errorPattern
        self.errorType = errorType
        self.resolution = resolution
        self.preventionRule = preventionRule
    }

    init(from dto: ErrorResolutionDTO) {
        errorPattern = dto.errorPattern
        errorType = dto.errorType
        resolution = dto.resolution
        preventionRule = dto.preventionRule
        occurrenceCount = dto.occurrenceCount
    }
}

struct ErrorResolutionDTO: Codable {
    let errorPattern: String
    let errorType: String
    let resolution: String
    let preventionRule: String
    let occurrenceCount: Int

    init(_ resolution: ErrorResolution) {
        errorPattern = resolution.errorPattern
        errorType = resolution.errorType
        self.resolution = resolution.resolution
        preventionRule = resolution.preventionRule
        occurrenceCount = resolution.occurrenceCount
    }
}

@Observable
final class BestPractice: Identifiable {
    let id = UUID()
    let practiceId: String
    let category: String
    let title: String
    let practiceDescription: String
    let exampleCode: String
    let context: String

    init(practiceId: String, category: String, title: String, description: String, exampleCode: String, context: String) {
        self.practiceId = practiceId
        self.category = category
        self.title = title
        practiceDescription = description
        self.exampleCode = exampleCode
        self.context = context
    }
}

// MARK: - String Extension

private extension String {
    func count(of character: Character) -> Int {
        filter { $0 == character }.count
    }
}
