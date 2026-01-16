import Foundation
import SwiftData

@Model
final class Project {
  @Attribute(.unique) var id: UUID
  var title: String
  var customInstructions: String
  var createdAt: Date
  var updatedAt: Date

  @Relationship(deleteRule: .nullify)
  var conversations: [Conversation]

  @Attribute(.ephemeral) var files: [ProjectFile]
  @Attribute(.ephemeral) var settings: ProjectSettings

  init(
    id: UUID = UUID(),
    title: String,
    customInstructions: String = "",
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    conversations: [Conversation] = [],
    files: [ProjectFile] = [],
    settings: ProjectSettings = ProjectSettings()
  ) {
    self.id = id
    self.title = title
    self.customInstructions = customInstructions
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.conversations = conversations
    self.files = files
    self.settings = settings
  }
}

// MARK: - Project File

struct ProjectFile: Codable, Identifiable, Sendable {
  let id: UUID
  let name: String
  let path: String
  let size: Int64
  let addedAt: Date

  init(
    id: UUID = UUID(),
    name: String,
    path: String,
    size: Int64,
    addedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.path = path
    self.size = size
    self.addedAt = addedAt
  }
}

// MARK: - Project Settings

struct ProjectSettings: Codable, Sendable {
  var defaultModel: String?
  var defaultProvider: String?
  var temperature: Double
  var maxTokens: Int?

  init(
    defaultModel: String? = nil,
    defaultProvider: String? = nil,
    temperature: Double = 1.0,
    maxTokens: Int? = nil
  ) {
    self.defaultModel = defaultModel
    self.defaultProvider = defaultProvider
    self.temperature = temperature
    self.maxTokens = maxTokens
  }
}

// MARK: - Identifiable

extension Project: Identifiable {}
