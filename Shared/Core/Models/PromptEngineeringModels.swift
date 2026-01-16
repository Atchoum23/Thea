import Foundation
import SwiftData

// MARK: - User Prompt Preference Model

@Model
final class UserPromptPreference {
  @Attribute(.unique) var id: UUID
  var category: String
  var preferenceKey: String
  var preferenceValue: String
  var confidence: Float
  var lastUpdated: Date

  init(
    id: UUID = UUID(),
    category: String,
    preferenceKey: String,
    preferenceValue: String,
    confidence: Float = 0.5,
    lastUpdated: Date = Date()
  ) {
    self.id = id
    self.category = category
    self.preferenceKey = preferenceKey
    self.preferenceValue = preferenceValue
    self.confidence = confidence
    self.lastUpdated = lastUpdated
  }
}

// MARK: - Code Error Model

@Model
final class CodeErrorRecord {
  @Attribute(.unique) var id: UUID
  var errorMessage: String
  var errorPattern: String
  var codeContext: String
  var solution: String
  var language: String
  var occurrenceCount: Int
  var lastOccurrence: Date
  var preventionRule: String
  var successRate: Float
  var relatedErrorIDs: [UUID]

  init(
    id: UUID = UUID(),
    errorMessage: String,
    errorPattern: String,
    codeContext: String,
    solution: String,
    language: String = "swift",
    occurrenceCount: Int = 1,
    lastOccurrence: Date = Date(),
    preventionRule: String = "",
    successRate: Float = 0,
    relatedErrorIDs: [UUID] = []
  ) {
    self.id = id
    self.errorMessage = errorMessage
    self.errorPattern = errorPattern
    self.codeContext = codeContext
    self.solution = solution
    self.language = language
    self.occurrenceCount = occurrenceCount
    self.lastOccurrence = lastOccurrence
    self.preventionRule = preventionRule
    self.successRate = successRate
    self.relatedErrorIDs = relatedErrorIDs
  }
}

// MARK: - Code Correction Model

@Model
final class CodeCorrection {
  @Attribute(.unique) var id: UUID
  var originalCode: String
  var correctedCode: String
  var errorID: UUID
  var timestamp: Date
  var wasSuccessful: Bool
  var modelUsed: String

  init(
    id: UUID = UUID(),
    originalCode: String,
    correctedCode: String,
    errorID: UUID,
    timestamp: Date = Date(),
    wasSuccessful: Bool = false,
    modelUsed: String
  ) {
    self.id = id
    self.originalCode = originalCode
    self.correctedCode = correctedCode
    self.errorID = errorID
    self.timestamp = timestamp
    self.wasSuccessful = wasSuccessful
    self.modelUsed = modelUsed
  }
}

// MARK: - Prompt Template Model

@Model
final class PromptTemplate {
  @Attribute(.unique) var id: UUID
  var name: String
  var category: String
  var templateText: String
  var version: Int
  var successCount: Int
  var failureCount: Int
  var averageConfidence: Float
  var createdAt: Date
  var lastUsed: Date?
  var isActive: Bool

  init(
    id: UUID = UUID(),
    name: String,
    category: String,
    templateText: String,
    version: Int = 1,
    successCount: Int = 0,
    failureCount: Int = 0,
    averageConfidence: Float = 0,
    createdAt: Date = Date(),
    lastUsed: Date? = nil,
    isActive: Bool = true
  ) {
    self.id = id
    self.name = name
    self.category = category
    self.templateText = templateText
    self.version = version
    self.successCount = successCount
    self.failureCount = failureCount
    self.averageConfidence = averageConfidence
    self.createdAt = createdAt
    self.lastUsed = lastUsed
    self.isActive = isActive
  }

  var successRate: Float {
    let total = successCount + failureCount
    return total > 0 ? Float(successCount) / Float(total) : 0
  }
}

// MARK: - Few-Shot Example Model

@Model
final class CodeFewShotExample {
  @Attribute(.unique) var id: UUID
  var taskType: String
  var inputExample: String
  var outputExample: String
  var quality: Float
  var usageCount: Int
  var createdAt: Date

  init(
    id: UUID = UUID(),
    taskType: String,
    inputExample: String,
    outputExample: String,
    quality: Float = 1.0,
    usageCount: Int = 0,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.taskType = taskType
    self.inputExample = inputExample
    self.outputExample = outputExample
    self.quality = quality
    self.usageCount = usageCount
    self.createdAt = createdAt
  }
}
