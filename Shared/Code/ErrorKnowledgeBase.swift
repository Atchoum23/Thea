import Foundation
import SwiftData
import Observation

// MARK: - Error Knowledge Base
// Learns from errors to prevent repetition and improve code generation

@MainActor
@Observable
final class ErrorKnowledgeBase {
    static let shared = ErrorKnowledgeBase()

    private var modelContext: ModelContext?
    private var errorCache: [String: [CodeErrorRecord]] = [:]
    private var preventionRulesCache: [String] = []

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        Task {
            await loadErrorCache()
        }
    }

    // MARK: - Error Recording

    /// Records a code error for learning
    func recordError(
        _ error: SwiftError,
        code: String,
        fix: String,
        language: String = "swift"
    ) async {
        guard let context = modelContext else { return }

        let errorPattern = createErrorPattern(from: error.message)

        // Check if similar error exists
        let similar = await findSimilarErrors(error)

        if let existingError = similar.first(where: { $0.errorPattern == errorPattern }) {
            // Update existing error
            existingError.occurrenceCount += 1
            existingError.lastOccurrence = Date()

            if !fix.isEmpty {
                existingError.solution = fix
            }

            // Update success rate if fix worked
            if !fix.isEmpty {
                let newSuccessRate = (existingError.successRate * Float(existingError.occurrenceCount - 1) + 1.0) / Float(existingError.occurrenceCount)
                existingError.successRate = newSuccessRate
            }
        } else {
            // Create new error entry
            let codeError = CodeErrorRecord(
                errorMessage: error.message,
                errorPattern: errorPattern,
                codeContext: code,
                solution: fix,
                language: language,
                occurrenceCount: 1,
                lastOccurrence: Date(),
                preventionRule: generatePreventionRule(for: error),
                successRate: fix.isEmpty ? 0 : 1.0,
                relatedErrorIDs: similar.map { $0.id }
            )
            context.insert(codeError)
        }

        try? context.save()
        await loadErrorCache()
    }

    /// Records a successful fix
    func recordSuccessfulFix(errorID: UUID, correction: CodeCorrection) async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<CodeErrorRecord>(
            predicate: #Predicate { $0.id == errorID }
        )

        if let error = try? context.fetch(descriptor).first {
            error.solution = correction.correctedCode
            error.successRate = min(1.0, error.successRate + 0.2)
            try? context.save()
        }
    }

    /// Updates success rate for an error fix
    func updateSuccessRate(for errorID: UUID, successful: Bool) async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<CodeErrorRecord>(
            predicate: #Predicate { $0.id == errorID }
        )

        if let error = try? context.fetch(descriptor).first {
            if successful {
                error.successRate = min(1.0, error.successRate + 0.1)
            } else {
                error.successRate = max(0.0, error.successRate - 0.1)
            }
            try? context.save()
        }
    }

    // MARK: - Error Search

    /// Finds similar errors based on pattern matching
    func findSimilarErrors(_ error: SwiftError) async -> [CodeErrorRecord] {
        guard let context = modelContext else { return [] }

        let errorPattern = createErrorPattern(from: error.message)

        let descriptor = FetchDescriptor<CodeErrorRecord>(
            sortBy: [SortDescriptor(\.occurrenceCount, order: .reverse)]
        )

        do {
            let allErrors = try context.fetch(descriptor)

            // Find errors with similar patterns
            let similar = allErrors.filter { codeError in
                let similarity = calculateSimilarity(errorPattern, codeError.errorPattern)
                return similarity > 0.7
            }

            return similar
        } catch {
            print("Error finding similar errors: \(error)")
            return []
        }
    }

    /// Gets errors for a specific error category
    func getErrors(for category: SwiftError.ErrorCategory) async -> [CodeErrorRecord] {
        let categoryString = String(describing: category)

        if let cached = errorCache[categoryString] {
            return cached
        }

        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<CodeErrorRecord>(
            sortBy: [SortDescriptor(\.occurrenceCount, order: .reverse)]
        )

        do {
            let allErrors = try context.fetch(descriptor)

            // Filter by category based on error message
            let filtered = allErrors.filter { error in
                error.errorMessage.lowercased().contains(categoryString.lowercased())
            }

            errorCache[categoryString] = filtered
            return filtered
        } catch {
            print("Error fetching errors for category: \(error)")
            return []
        }
    }

    // MARK: - Prevention Guidance

    /// Gets prevention guidance for upcoming code generation
    func getPreventionGuidance(for code: String) async -> [String] {
        guard let context = modelContext else { return [] }

        var guidance: [String] = []

        // Get recent errors (last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        let descriptor = FetchDescriptor<CodeErrorRecord>(
            predicate: #Predicate { $0.lastOccurrence > thirtyDaysAgo },
            sortBy: [SortDescriptor(\.occurrenceCount, order: .reverse)]
        )

        do {
            let recentErrors = try context.fetch(descriptor)

            // Add prevention rules from frequent errors
            for error in recentErrors.prefix(10) {
                if !error.preventionRule.isEmpty {
                    guidance.append(error.preventionRule)
                }
            }

            // Add category-specific guidance based on code content
            if code.contains("@MainActor") || code.contains("Task {") {
                let concurrencyErrors = recentErrors.filter {
                    $0.errorMessage.lowercased().contains("concurrency") ||
                    $0.errorMessage.lowercased().contains("sendable") ||
                    $0.errorMessage.lowercased().contains("actor")
                }

                for error in concurrencyErrors.prefix(3) {
                    if !error.preventionRule.isEmpty && !guidance.contains(error.preventionRule) {
                        guidance.append(error.preventionRule)
                    }
                }
            }

            preventionRulesCache = guidance
            return guidance
        } catch {
            print("Error getting prevention guidance: \(error)")
            return []
        }
    }

    /// Enhances a prompt with error prevention guidance
    func enhancePromptWithLearnings(for task: String, code: String) async -> String {
        let guidance = await getPreventionGuidance(for: code)

        if guidance.isEmpty {
            return task
        }

        var enhanced = task
        enhanced += "\n\n🛡️ ERROR PREVENTION (learned from previous mistakes):\n"

        for (index, rule) in guidance.enumerated() {
            enhanced += "\(index + 1). \(rule)\n"
        }

        enhanced += "\nEnsure your code follows these prevention rules.\n"

        return enhanced
    }

    // MARK: - Pattern Matching

    private func createErrorPattern(from message: String) -> String {
        return message
    }

    private func calculateSimilarity(_ pattern1: String, _ pattern2: String) -> Double {
        // Simple Levenshtein-based similarity
        let distance = levenshteinDistance(pattern1, pattern2)
        let maxLength = max(pattern1.count, pattern2.count)

        return maxLength > 0 ? 1.0 - (Double(distance) / Double(maxLength)) : 0
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let len1 = s1.count
        let len2 = s2.count

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: len2 + 1), count: len1 + 1)

        for i in 0...len1 {
            matrix[i][0] = i
        }

        for j in 0...len2 {
            matrix[0][j] = j
        }

        for (i, char1) in s1.enumerated() {
            for (j, char2) in s2.enumerated() {
                if char1 == char2 {
                    matrix[i + 1][j + 1] = matrix[i][j]
                } else {
                    matrix[i + 1][j + 1] = min(
                        matrix[i][j + 1] + 1,
                        matrix[i + 1][j] + 1,
                        matrix[i][j] + 1
                    )
                }
            }
        }

        return matrix[len1][len2]
    }

    // MARK: - Prevention Rule Generation

    private func generatePreventionRule(for error: SwiftError) -> String {
        let message = error.message.lowercased()

        // Concurrency errors
        if message.contains("@mainactor") {
            return "Always use @MainActor for UI-related code and properties"
        }

        if message.contains("sendable") || message.contains("non-sendable") {
            return "Ensure all types used across actor boundaries conform to Sendable"
        }

        if message.contains("await") && message.contains("missing") {
            return "Add 'await' keyword when calling async functions"
        }

        // Type errors
        if message.contains("cannot convert") {
            return "Verify type compatibility and add explicit conversions when needed"
        }

        if message.contains("type mismatch") || message.contains("incompatible") {
            return "Check that all types match exactly, including Optional vs non-Optional"
        }

        // Syntax errors
        if message.contains("expected '}'") || message.contains("expected ')'") {
            return "Always balance opening and closing brackets/parentheses/braces"
        }

        // Access control
        if message.contains("private") && message.contains("inaccessible") {
            return "Ensure properties/methods are accessible (not private) when used outside their scope"
        }

        // Observable/State errors
        if message.contains("@observable") || message.contains("@state") {
            return "Don't use @State with @Observable classes; use the object directly"
        }

        // Default rule
        return "Review error carefully and ensure similar patterns are avoided"
    }

    // MARK: - Cache Management

    private func loadErrorCache() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<CodeErrorRecord>(
            sortBy: [SortDescriptor(\.lastOccurrence, order: .reverse)]
        )

        do {
            let errors = try context.fetch(descriptor)

            errorCache.removeAll()
            for error in errors {
                let category = categorizeErrorByMessage(error.errorMessage)
                errorCache[category, default: []].append(error)
            }
        } catch {
            print("Error loading error cache: \(error)")
        }
    }

    private func categorizeErrorByMessage(_ message: String) -> String {
        let lowercased = message.lowercased()

        if lowercased.contains("concurrency") || lowercased.contains("sendable") || lowercased.contains("actor") {
            return "concurrency"
        }

        if lowercased.contains("type") {
            return "type"
        }

        if lowercased.contains("syntax") {
            return "syntax"
        }

        if lowercased.contains("undeclared") || lowercased.contains("unresolved") {
            return "undeclared"
        }

        return "other"
    }

    // MARK: - Analytics

    /// Gets error statistics
    func getErrorStats() async -> ErrorStats {
        guard let context = modelContext else {
            return ErrorStats(
                totalErrors: 0,
                totalOccurrences: 0,
                mostFrequentError: nil,
                errorsByCategory: [:],
                averageSuccessRate: 0
            )
        }

        let descriptor = FetchDescriptor<CodeErrorRecord>()

        do {
            let errors = try context.fetch(descriptor)

            let totalOccurrences = errors.reduce(0) { $0 + $1.occurrenceCount }
            let mostFrequent = errors.max { a, b in a.occurrenceCount < b.occurrenceCount }

            var categoryCount: [String: Int] = [:]
            for error in errors {
                let category = categorizeErrorByMessage(error.errorMessage)
                categoryCount[category, default: 0] += error.occurrenceCount
            }

            let avgSuccessRate = errors.isEmpty ? 0 : errors.map { $0.successRate }.reduce(0, +) / Float(errors.count)

            return ErrorStats(
                totalErrors: errors.count,
                totalOccurrences: totalOccurrences,
                mostFrequentError: mostFrequent,
                errorsByCategory: categoryCount,
                averageSuccessRate: avgSuccessRate
            )
        } catch {
            print("Error getting error stats: \(error)")
            return ErrorStats(
                totalErrors: 0,
                totalOccurrences: 0,
                mostFrequentError: nil,
                errorsByCategory: [:],
                averageSuccessRate: 0
            )
        }
    }

    /// Gets top recurring errors
    func getTopRecurringErrors(limit: Int = 10) async -> [CodeErrorRecord] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<CodeErrorRecord>(
            sortBy: [SortDescriptor(\.occurrenceCount, order: .reverse)]
        )

        do {
            let errors = try context.fetch(descriptor)
            return Array(errors.prefix(limit))
        } catch {
            print("Error getting top recurring errors: \(error)")
            return []
        }
    }
}

// MARK: - Supporting Structures

struct ErrorStats {
    let totalErrors: Int
    let totalOccurrences: Int
    let mostFrequentError: CodeErrorRecord?
    let errorsByCategory: [String: Int]
    let averageSuccessRate: Float
}
