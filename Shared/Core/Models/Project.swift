import Foundation
@preconcurrency import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var title: String
    var customInstructions: String
    var projectDescription: String
    var iconName: String
    var colorHex: String
    var parentProjectID: UUID?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify)
    var conversations: [Conversation]

    @Transient var files = [ProjectFile]()
    @Transient var settings = ProjectSettings()

    init(
        id: UUID = UUID(),
        title: String,
        customInstructions: String = "",
        projectDescription: String = "",
        iconName: String = "folder",
        colorHex: String = "#007AFF",
        parentProjectID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        conversations: [Conversation] = [],
        files: [ProjectFile] = [],
        settings: ProjectSettings = ProjectSettings()
    ) {
        self.id = id
        self.title = title
        self.customInstructions = customInstructions
        self.projectDescription = projectDescription
        self.iconName = iconName
        self.colorHex = colorHex
        self.parentProjectID = parentProjectID
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

    // periphery:ignore - Reserved: init(id:name:path:size:addedAt:) initializer reserved for future feature activation
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
