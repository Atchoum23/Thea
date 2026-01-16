import Foundation
import Observation
import SwiftData

// MARK: - Error Knowledge Base Manager
// Manages SwiftData context lifecycle for error learning system

@MainActor
@Observable
final class ErrorKnowledgeBaseManager {
  static let shared = ErrorKnowledgeBaseManager()

  private var modelContext: ModelContext?
  private var errorKnowledgeBase = ErrorKnowledgeBase.shared

  private init() {}

  // MARK: - Initialization

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
    errorKnowledgeBase.setModelContext(context)
  }

  // MARK: - Error Recording

  /// Records a Swift compilation error for learning
  func recordSwiftError(
    _ error: SwiftError,
    inCode code: String,
    fixedWith fix: String = ""
  ) async {
    await errorKnowledgeBase.recordError(error, code: code, fix: fix, language: "swift")
  }

  /// Records multiple errors from a validation result
  func recordValidationErrors(
    _ errors: [SwiftError],
    inCode code: String,
    fixedCode: String? = nil
  ) async {
    for error in errors {
      await recordSwiftError(error, inCode: code, fixedWith: fixedCode ?? "")
    }
  }

  /// Records a successful code correction
  func recordSuccessfulCorrection(
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

    await errorKnowledgeBase.recordSuccessfulFix(errorID: errorID, correction: correction)
  }

  // MARK: - Error Prevention

  /// Gets prevention guidance for code generation
  func getPreventionGuidance(forCode code: String) async -> [String] {
    return await errorKnowledgeBase.getPreventionGuidance(for: code)
  }

  /// Enhances a prompt with error prevention rules
  func enhancePromptWithErrorPrevention(
    prompt: String,
    forCode code: String = ""
  ) async -> String {
    return await errorKnowledgeBase.enhancePromptWithLearnings(for: prompt, code: code)
  }

  // MARK: - Error Analysis

  /// Finds similar errors to help with fixing
  func findSimilarErrors(to error: SwiftError) async -> [CodeErrorRecord] {
    return await errorKnowledgeBase.findSimilarErrors(error)
  }

  /// Gets errors by category
  func getErrors(forCategory category: SwiftError.ErrorCategory) async -> [CodeErrorRecord] {
    return await errorKnowledgeBase.getErrors(for: category)
  }

  /// Gets statistics about learned errors
  func getErrorStatistics() async -> ErrorStats {
    return await errorKnowledgeBase.getErrorStats()
  }

  /// Gets top recurring errors
  func getTopRecurringErrors(limit: Int = 10) async -> [CodeErrorRecord] {
    return await errorKnowledgeBase.getTopRecurringErrors(limit: limit)
  }

  // MARK: - Success Rate Tracking

  /// Updates success rate when a fix works or fails
  func updateFixSuccessRate(errorID: UUID, wasSuccessful: Bool) async {
    await errorKnowledgeBase.updateSuccessRate(for: errorID, successful: wasSuccessful)
  }

  // MARK: - Data Management

  /// Deletes old error records
  func deleteOldErrors(olderThan days: Int) async {
    guard let context = modelContext else { return }

    let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

    let descriptor = FetchDescriptor<CodeErrorRecord>(
      predicate: #Predicate { $0.lastOccurrence < cutoffDate }
    )

    do {
      let oldErrors = try context.fetch(descriptor)
      for error in oldErrors {
        context.delete(error)
      }
      try context.save()
    } catch {
      print("Error deleting old errors: \(error)")
    }
  }

  /// Exports error data for analysis
  func exportErrorData() async -> Data? {
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
          "preventionRule": error.preventionRule,
        ]
      }

      return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    } catch {
      print("Error exporting error data: \(error)")
      return nil
    }
  }

  /// Imports error data from backup
  func importErrorData(_ data: Data) async {
    guard let context = modelContext else { return }

    do {
      if let errorArray = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
        for errorDict in errorArray {
          guard let message = errorDict["message"],
            let pattern = errorDict["pattern"],
            let solution = errorDict["solution"],
            let preventionRule = errorDict["preventionRule"]
          else {
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
}
