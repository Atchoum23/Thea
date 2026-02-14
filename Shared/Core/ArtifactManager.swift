//
//  ArtifactManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import CloudKit
import Foundation
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

// MARK: - Artifact Manager

/// Manages AI-generated artifacts similar to Claude Artifacts
/// Supports code, documents, visualizations, and interactive content
@MainActor
public class ArtifactManager: ObservableObject {
    public static let shared = ArtifactManager()

    // MARK: - Published State

    @Published public private(set) var artifacts: [Artifact] = []
    @Published public private(set) var currentArtifact: Artifact?
    @Published public private(set) var isLoading = false

    // MARK: - CloudKit

    private let container = CKContainer(identifier: "iCloud.app.theathe")
    private lazy var privateDatabase = container.privateCloudDatabase

    // MARK: - Storage

    private let storageKey = "ArtifactManager.artifacts"
    private let artifactsDirectory: URL

    // MARK: - Initialization

    private init() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory
            artifactsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("Artifacts")
            loadArtifacts()
            return
        }
        artifactsDirectory = documentsPath.appendingPathComponent("Artifacts", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)

        loadArtifacts()
    }

    // MARK: - Load/Save

    private func loadArtifacts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Artifact].self, from: data)
        {
            artifacts = decoded
        }

        // Sync with cloud in background
        Task {
            await syncWithCloud()
        }
    }

    private func saveArtifacts() {
        if let data = try? JSONEncoder().encode(artifacts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Create Artifacts

    /// Create a new code artifact
    public func createCodeArtifact(
        title: String,
        language: CodeLanguage,
        code: String,
        description: String? = nil,
        conversationId: String? = nil
    ) async throws -> Artifact {
        let artifact = Artifact(
            title: title,
            type: .code(language: language),
            content: code,
            description: description,
            conversationId: conversationId
        )

        return try await save(artifact)
    }

    /// Create a document artifact
    public func createDocumentArtifact(
        title: String,
        format: DocumentFormat,
        content: String,
        description: String? = nil,
        conversationId: String? = nil
    ) async throws -> Artifact {
        let artifact = Artifact(
            title: title,
            type: .document(format: format),
            content: content,
            description: description,
            conversationId: conversationId
        )

        return try await save(artifact)
    }

    /// Create a visualization artifact (SVG, charts, diagrams)
    public func createVisualizationArtifact(
        title: String,
        visualizationType: VisualizationType,
        content: String,
        description: String? = nil,
        conversationId: String? = nil
    ) async throws -> Artifact {
        let artifact = Artifact(
            title: title,
            type: .visualization(type: visualizationType),
            content: content,
            description: description,
            conversationId: conversationId
        )

        return try await save(artifact)
    }

    /// Create an interactive HTML/React artifact
    public func createInteractiveArtifact(
        title: String,
        html: String,
        description: String? = nil,
        conversationId: String? = nil
    ) async throws -> Artifact {
        let artifact = Artifact(
            title: title,
            type: .interactive,
            content: html,
            description: description,
            conversationId: conversationId
        )

        return try await save(artifact)
    }

    /// Create a data artifact (JSON, CSV, etc.)
    public func createDataArtifact(
        title: String,
        dataFormat: DataFormat,
        content: String,
        description: String? = nil,
        conversationId: String? = nil
    ) async throws -> Artifact {
        let artifact = Artifact(
            title: title,
            type: .data(format: dataFormat),
            content: content,
            description: description,
            conversationId: conversationId
        )

        return try await save(artifact)
    }

    // MARK: - Save

    private func save(_ artifact: Artifact) async throws -> Artifact {
        isLoading = true
        defer { isLoading = false }

        // Save content to file
        let contentFile = artifactsDirectory.appendingPathComponent("\(artifact.id.uuidString).\(artifact.type.fileExtension)")
        try artifact.content.write(to: contentFile, atomically: true, encoding: .utf8)

        var savedArtifact = artifact
        savedArtifact.contentPath = contentFile.path

        // Add to collection
        artifacts.insert(savedArtifact, at: 0)
        saveArtifacts()

        // Sync to cloud
        Task {
            try? await saveToCloud(savedArtifact)
        }

        return savedArtifact
    }

    // MARK: - Update

    /// Update an artifact's content
    public func update(_ artifact: Artifact, content: String) async throws -> Artifact {
        guard let index = artifacts.firstIndex(where: { $0.id == artifact.id }) else {
            throw ArtifactError.notFound
        }

        var updated = artifacts[index]
        updated.content = content
        updated.modifiedAt = Date()
        updated.version += 1

        // Save new version
        if let contentPath = updated.contentPath {
            try content.write(toFile: contentPath, atomically: true, encoding: .utf8)
        }

        artifacts[index] = updated
        saveArtifacts()

        Task {
            try? await saveToCloud(updated)
        }

        return updated
    }

    /// Update artifact metadata
    public func updateMetadata(
        _ artifact: Artifact,
        title: String? = nil,
        description: String? = nil,
        tags: [String]? = nil
    ) async throws -> Artifact {
        guard let index = artifacts.firstIndex(where: { $0.id == artifact.id }) else {
            throw ArtifactError.notFound
        }

        var updated = artifacts[index]
        if let title { updated.title = title }
        if let description { updated.description = description }
        if let tags { updated.tags = tags }
        updated.modifiedAt = Date()

        artifacts[index] = updated
        saveArtifacts()

        return updated
    }

    // MARK: - Delete

    /// Delete an artifact
    public func delete(_ artifact: Artifact) async throws {
        artifacts.removeAll { $0.id == artifact.id }

        // Delete file
        if let contentPath = artifact.contentPath {
            try? FileManager.default.removeItem(atPath: contentPath)
        }

        saveArtifacts()

        Task {
            try? await deleteFromCloud(artifact)
        }
    }

    // MARK: - Query

    /// Get artifacts for a conversation
    public func getArtifacts(forConversation conversationId: String) -> [Artifact] {
        artifacts.filter { $0.conversationId == conversationId }
    }

    /// Get artifacts by type
    public func getArtifacts(ofType type: ArtifactType) -> [Artifact] {
        artifacts.filter { $0.type.category == type.category }
    }

    /// Search artifacts
    public func search(query: String) -> [Artifact] {
        let lowercasedQuery = query.lowercased()
        return artifacts.filter { artifact in
            artifact.title.lowercased().contains(lowercasedQuery) ||
                artifact.description?.lowercased().contains(lowercasedQuery) == true ||
                artifact.tags.contains { $0.lowercased().contains(lowercasedQuery) } ||
                artifact.content.lowercased().contains(lowercasedQuery)
        }
    }

    // MARK: - Export

    /// Export artifact to file
    public func export(_ artifact: Artifact, to url: URL) throws {
        try artifact.content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Export artifact with rendered preview
    public func exportWithPreview(_ artifact: Artifact, to url: URL) async throws {
        switch artifact.type {
        case .code, .document, .data:
            try artifact.content.write(to: url, atomically: true, encoding: .utf8)
        case .visualization, .interactive:
            // For HTML-based artifacts, save as HTML
            let htmlContent = wrapInHTML(artifact)
            try htmlContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func wrapInHTML(_ artifact: Artifact) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>\(artifact.title)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 20px; }
            </style>
        </head>
        <body>
            \(artifact.content)
        </body>
        </html>
        """
    }

    // MARK: - Cloud Sync

    private func syncWithCloud() async {
        do {
            let status = try await container.accountStatus()
            guard status == .available else { return }

            let query = CKQuery(recordType: "Artifact", predicate: NSPredicate(value: true))
            let results = try await privateDatabase.records(matching: query)

            for (_, result) in results.matchResults {
                if case let .success(record) = result,
                   let artifact = Artifact(from: record)
                {
                    if !artifacts.contains(where: { $0.id == artifact.id }) {
                        artifacts.append(artifact)
                    }
                }
            }

            artifacts.sort { $0.createdAt > $1.createdAt }
            saveArtifacts()
        } catch {
            // Sync failed - continue with local data
        }
    }

    private func saveToCloud(_ artifact: Artifact) async throws {
        let record = artifact.toCKRecord()
        _ = try await privateDatabase.save(record)
    }

    private func deleteFromCloud(_ artifact: Artifact) async throws {
        let recordID = CKRecord.ID(recordName: artifact.id.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Preview

    /// Set current artifact for preview
    public func preview(_ artifact: Artifact) {
        currentArtifact = artifact
    }

    /// Close preview
    public func closePreview() {
        currentArtifact = nil
    }
}

// Types (Artifact, ArtifactType, CodeLanguage, etc.) are in ArtifactManagerTypes.swift
