#if os(macOS)
import Foundation
import Observation
@preconcurrency import SwiftData

// MARK: - Error Knowledge Base Manager
// Manages SwiftData context lifecycle for error learning system
// Bridges between SwiftData models and the ErrorKnowledgeBase actor

@MainActor
@Observable
public final class ErrorKnowledgeBaseManager {
    public static let shared = ErrorKnowledgeBaseManager()

    private var modelContext: ModelContext?
    private let errorKnowledgeBase = ErrorKnowledgeBase.shared

    private init() {}

    // MARK: - Initialization

    public func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Error Recording

    /// Records a Swift compilation error for learning
    public func recordSwiftError(
        _ error: SwiftError,
        inCode code: String,
        fixedWith fix: String = ""
    ) async {
        guard let context = modelContext else { return }

        // Create or update CodeErrorRecord in SwiftData
        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<CodeErrorRecord>()

        do {
            let allRecords = try context.fetch(descriptor)
            if let existing = allRecords.first(where: { $0.errorMessage == error.message }) {
                // Update existing record
                existing.occurrenceCount += 1
                existing.lastOccurrence = Date()
                if !fix.isEmpty {
                    existing.solution = fix
                }
            } else {
                // Create new record
                let record = CodeErrorRecord(
                    errorMessage: error.message,
                    errorPattern: extractPattern(from: error.message),
                    codeContext: code,
                    solution: fix,
                    language: "swift"
                )
                context.insert(record)
            }
            try context.save()
        } catch {
            print("Error recording Swift error: \(error)")
        }
    }

    /// Records multiple errors from a validation result
    public func recordValidationErrors(
        _ errors: [SwiftError],
        inCode code: String,
        fixedCode: String? = nil
    ) async {
        for error in errors {
            await recordSwiftError(error, inCode: code, fixedWith: fixedCode ?? "")
        }
    }

    /// Records a successful code correction
    public func recordSuccessfulCorrection(
        originalCode: String,
        correctedCode: String,
        forError errorID: UUID,
        usingModel model: String
    ) async {
        guard let context = modelContext else { return }

        let correction = CodeCorrection(
            originalCode: originalCode,
            correctedCode: correctedCode,
            errorID: errorID,
            wasSuccessful: true,
            modelUsed: model
        )

        context.insert(correction)
        try? context.save()

        // Update error record success rate
        await updateSuccessRate(for: errorID, successful: true)
    }

    // MARK: - Error Prevention

    /// Gets prevention guidance for code generation
    public func getPreventionGuidance(forCode code: String) async -> [String] {
        guard let context = modelContext else { return [] }

        // Fetch all and filter/sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<CodeErrorRecord>()

        do {
            let allRecords = try context.fetch(descriptor)
            let filteredRecords = allRecords
                .filter { !$0.preventionRule.isEmpty }
                .sorted { $0.occurrenceCount > $1.occurrenceCount }
            return filteredRecords.prefix(5).map { $0.preventionRule }
        } catch {
            return []
        }
    }

    /// Enhances a prompt with error prevention rules
    public func enhancePromptWithErrorPrevention(
        prompt: String,
        forCode code: String = ""
    ) async -> String {
        let guidance = await getPreventionGuidance(forCode: code)

        if guidance.isEmpty {
            return prompt
        }

        var enhancedPrompt = prompt
        enhancedPrompt += "\n\n⚠️ ERROR PREVENTION (from learned patterns):\n"
        for (index, rule) in guidance.enumerated() {
            enhancedPrompt += "\(index + 1). \(rule)\n"
        }

        return enhancedPrompt
    }

    // MARK: - Error Analysis Using ErrorKnowledgeBase Actor

    /// Finds a fix for an error using the ErrorKnowledgeBase
    public func findFix(for error: ErrorParser.ParsedError) async -> ErrorKnowledgeBase.KnownFix? {
        await errorKnowledgeBase.findFix(for: error)
    }

    /// Finds a fix by message and category
    public func findFix(
        forMessage message: String,
        category: ErrorParser.ErrorCategory
    ) async -> ErrorKnowledgeBase.KnownFix? {
        await errorKnowledgeBase.findFix(forMessage: message, category: category)
    }

    /// Records the result of applying a fix
    public func recordFixResult(fix: ErrorKnowledgeBase.KnownFix, success: Bool) async {
        await errorKnowledgeBase.recordResult(fix: fix, success: success)
    }

    /// Adds a new fix to the knowledge base
    public func addFix(_ fix: ErrorKnowledgeBase.KnownFix) async {
        await errorKnowledgeBase.addFix(fix)
    }

    // MARK: - SwiftData Error Analysis

    /// Gets errors by pattern
    public func getErrors(byPattern pattern: String) async -> [CodeErrorRecord] {
        guard let context = modelContext else { return [] }

        // Fetch all and filter/sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<CodeErrorRecord>()
        let allRecords = (try? context.fetch(descriptor)) ?? []
        return allRecords
            .filter { $0.errorPattern.contains(pattern) }
            .sorted { $0.occurrenceCount > $1.occurrenceCount }
    }

    /// Gets top recurring errors
    public func getTopRecurringErrors(limit: Int = 10) async -> [CodeErrorRecord] {
        guard let context = modelContext else { return [] }

        // Fetch all and sort in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<CodeErrorRecord>()
        let allRecords = (try? context.fetch(descriptor)) ?? []
        return Array(allRecords.sorted { $0.occurrenceCount > $1.occurrenceCount }.prefix(limit))
    }

    /// Gets error statistics from ErrorKnowledgeBase
    public func getKnowledgeBaseStatistics() async -> KnowledgeBaseStatistics {
        await errorKnowledgeBase.getStatistics()
    }

    /// Gets error statistics from SwiftData
    public func getSwiftDataErrorStats() async -> SwiftDataErrorStats {
        guard let context = modelContext else {
            return SwiftDataErrorStats(
                totalErrors: 0,
                totalCorrections: 0,
                averageSuccessRate: 0,
                mostCommonError: nil
            )
        }

        let errorDescriptor = FetchDescriptor<CodeErrorRecord>()
        let correctionDescriptor = FetchDescriptor<CodeCorrection>()

        let errors = (try? context.fetch(errorDescriptor)) ?? []
        let corrections = (try? context.fetch(correctionDescriptor)) ?? []

        let avgSuccessRate = errors.isEmpty ? 0 : errors.map { $0.successRate }.reduce(0, +) / Float(errors.count)
        let mostCommon = errors.max { $0.occurrenceCount < $1.occurrenceCount }

        return SwiftDataErrorStats(
            totalErrors: errors.count,
            totalCorrections: corrections.count,
            averageSuccessRate: avgSuccessRate,
            mostCommonError: mostCommon?.errorMessage
        )
    }

    // MARK: - Success Rate Tracking

    /// Updates success rate for an error record
    private func updateSuccessRate(for errorID: UUID, successful: Bool) async {
        guard let context = modelContext else { return }

        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<CodeErrorRecord>()

        do {
            let allRecords = try context.fetch(descriptor)
            if let record = allRecords.first(where: { $0.id == errorID }) {
                // Simple moving average update
                let weight: Float = 0.1
                let newValue: Float = successful ? 1.0 : 0.0
                record.successRate = (1 - weight) * record.successRate + weight * newValue
                try context.save()
            }
        } catch {
            print("Error updating success rate: \(error)")
        }
    }

    // MARK: - Data Management

    /// Deletes old error records
    public func deleteOldErrors(olderThan days: Int) async {
        guard let context = modelContext else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        // Fetch all and filter in memory to avoid Swift 6 #Predicate Sendable issues
        let descriptor = FetchDescriptor<CodeErrorRecord>()

        do {
            let allErrors = try context.fetch(descriptor)
            let oldErrors = allErrors.filter { $0.lastOccurrence < cutoffDate }
            for error in oldErrors {
                context.delete(error)
            }
            try context.save()
        } catch {
            print("Error deleting old errors: \(error)")
        }
    }

    /// Exports error data for analysis
    public func exportErrorData() async -> Data? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<CodeErrorRecord>()

        do {
            let errors = try context.fetch(descriptor)

            let exportData = errors.map { error in
                [
                    "id": error.id.uuidString,
                    "message": error.errorMessage,
                    "pattern": error.errorPattern,
                    "solution": error.solution,
                    "occurrenceCount": String(error.occurrenceCount),
                    "successRate": String(error.successRate),
                    "preventionRule": error.preventionRule
                ]
            }

            return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        } catch {
            print("Error exporting error data: \(error)")
            return nil
        }
    }

    /// Imports error data from backup
    public func importErrorData(_ data: Data) async {
        guard let context = modelContext else { return }

        do {
            if let errorArray = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                for errorDict in errorArray {
                    guard let message = errorDict["message"],
                          let pattern = errorDict["pattern"],
                          let solution = errorDict["solution"],
                          let preventionRule = errorDict["preventionRule"] else {
                        continue
                    }

                    let error = CodeErrorRecord(
                        errorMessage: message,
                        errorPattern: pattern,
                        codeContext: "",
                        solution: solution,
                        language: "swift",
                        occurrenceCount: Int(errorDict["occurrenceCount"] ?? "1") ?? 1,
                        preventionRule: preventionRule,
                        successRate: Float(errorDict["successRate"] ?? "0") ?? 0
                    )

                    context.insert(error)
                }

                try context.save()
            }
        } catch {
            print("Error importing error data: \(error)")
        }
    }

    /// Resets the error knowledge base
    public func resetKnowledgeBase() async {
        await errorKnowledgeBase.reset()
    }

    // MARK: - Helpers

    private func extractPattern(from message: String) -> String {
        // Extract a generalized pattern from the error message
        var pattern = message

        // Replace specific identifiers with placeholders
        pattern = pattern.replacingOccurrences(
            of: #"'[^']+'"#,
            with: "'<identifier>'",
            options: .regularExpression
        )

        // Replace line/column numbers
        pattern = pattern.replacingOccurrences(
            of: #"line \d+"#,
            with: "line <N>",
            options: .regularExpression
        )

        pattern = pattern.replacingOccurrences(
            of: #":\d+:\d+"#,
            with: ":<line>:<col>",
            options: .regularExpression
        )

        return pattern
    }
}

// MARK: - Supporting Structures

public struct SwiftDataErrorStats: Sendable {
    public let totalErrors: Int
    public let totalCorrections: Int
    public let averageSuccessRate: Float
    public let mostCommonError: String?
}

#endif
