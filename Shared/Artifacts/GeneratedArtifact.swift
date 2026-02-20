// GeneratedArtifact.swift
// Thea — Structured Artifact Store
//
// Persists generated code, plans, MCP configs, API specs, and other structured
// outputs beyond conversation history. Artifacts are searchable, re-usable, and
// tagged for quick retrieval.

import Foundation
import SwiftData

// MARK: - Artifact Types

enum ArtifactType: String, Codable, CaseIterable, Sendable {
    case code
    case plan
    case mcpServer
    case apiSpec
    case skillDefinition
    case document
    case report

    var displayName: String {
        switch self {
        case .code: "Code"
        case .plan: "Plan"
        case .mcpServer: "MCP Server"
        case .apiSpec: "API Spec"
        case .skillDefinition: "Skill"
        case .document: "Document"
        case .report: "Report"
        }
    }

    var symbolName: String {
        switch self {
        case .code: "chevron.left.forwardslash.chevron.right"
        case .plan: "list.bullet.clipboard"
        case .mcpServer: "server.rack"
        case .apiSpec: "doc.text.magnifyingglass"
        case .skillDefinition: "sparkles"
        case .document: "doc.text"
        case .report: "chart.bar.doc.horizontal"
        }
    }
}

// MARK: - GeneratedArtifact Model

@Model
final class GeneratedArtifact {
    @Attribute(.unique) var id: UUID
    var title: String
    var artifactType: String          // ArtifactType.rawValue
    var content: String
    var language: String              // For .code: "swift", "python", etc.
    var metadata: [String: String]
    var conversationID: UUID?
    var createdAt: Date
    var lastAccessedAt: Date
    var tags: [String]
    var isFavorite: Bool
    var characterCount: Int

    init(
        title: String,
        type: ArtifactType,
        content: String,
        language: String = "",
        metadata: [String: String] = [:],
        conversationID: UUID? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.artifactType = type.rawValue
        self.content = content
        self.language = language
        self.metadata = metadata
        self.conversationID = conversationID
        self.createdAt = Date()
        self.lastAccessedAt = Date()
        self.tags = tags
        self.isFavorite = false
        self.characterCount = content.count
    }

    var type: ArtifactType {
        ArtifactType(rawValue: artifactType) ?? .document
    }

    func touch() {
        lastAccessedAt = Date()
    }
}

// MARK: - ArtifactStore

@MainActor
final class ArtifactStore {
    static let shared = ArtifactStore()

    private init() {}

    /// Create and persist an artifact, returning the new instance.
    func create(
        title: String,
        type: ArtifactType,
        content: String,
        language: String = "",
        conversationID: UUID? = nil,
        tags: [String] = [],
        in context: ModelContext
    ) -> GeneratedArtifact {
        let artifact = GeneratedArtifact(
            title: suggestTitle(title, content: content, type: type),
            type: type,
            content: content,
            language: language,
            conversationID: conversationID,
            tags: tags
        )
        context.insert(artifact)
        return artifact
    }

    /// Suggest a title from content if the provided title is empty.
    private func suggestTitle(_ provided: String, content: String, type: ArtifactType) -> String {
        guard provided.isEmpty else { return provided }
        // Extract first non-comment, non-empty line as a title hint
        let firstLine = content
            .components(separatedBy: "\n")
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty &&
                           !$0.hasPrefix("//") && !$0.hasPrefix("#") })
            ?? content.prefix(60).description
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        let truncated = trimmed.count > 50 ? String(trimmed.prefix(50)) + "…" : trimmed
        return truncated.isEmpty ? "\(type.displayName) Artifact" : truncated
    }
}
