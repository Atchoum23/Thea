//
//  ArtifactManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import Foundation
import CloudKit
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
    
    private let container = CKContainer(identifier: "iCloud.app.thea.artifacts")
    private lazy var privateDatabase = container.privateCloudDatabase
    
    // MARK: - Storage
    
    private let storageKey = "ArtifactManager.artifacts"
    private let artifactsDirectory: URL
    
    // MARK: - Initialization
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        artifactsDirectory = documentsPath.appendingPathComponent("Artifacts", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)
        
        loadArtifacts()
    }
    
    // MARK: - Load/Save
    
    private func loadArtifacts() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Artifact].self, from: data) {
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
        if let title = title { updated.title = title }
        if let description = description { updated.description = description }
        if let tags = tags { updated.tags = tags }
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
        return artifacts.filter { $0.conversationId == conversationId }
    }
    
    /// Get artifacts by type
    public func getArtifacts(ofType type: ArtifactType) -> [Artifact] {
        return artifacts.filter { $0.type.category == type.category }
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
        return """
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
                if case .success(let record) = result,
                   let artifact = Artifact(from: record) {
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

// MARK: - Artifact Model

public struct Artifact: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public let type: ArtifactType
    public var content: String
    public var description: String?
    public var tags: [String]
    public var conversationId: String?
    public let createdAt: Date
    public var modifiedAt: Date
    public var version: Int
    public var contentPath: String?
    
    public init(
        id: UUID = UUID(),
        title: String,
        type: ArtifactType,
        content: String,
        description: String? = nil,
        tags: [String] = [],
        conversationId: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        version: Int = 1,
        contentPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.content = content
        self.description = description
        self.tags = tags
        self.conversationId = conversationId
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.version = version
        self.contentPath = contentPath
    }
    
    init?(from record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = record["title"] as? String,
              let typeString = record["type"] as? String,
              let type = ArtifactType(rawValue: typeString),
              let content = record["content"] as? String else {
            return nil
        }
        
        self.id = id
        self.title = title
        self.type = type
        self.content = content
        self.description = record["description"] as? String
        self.tags = record["tags"] as? [String] ?? []
        self.conversationId = record["conversationId"] as? String
        self.createdAt = record["createdAt"] as? Date ?? Date()
        self.modifiedAt = record["modifiedAt"] as? Date ?? Date()
        self.version = record["version"] as? Int ?? 1
        self.contentPath = nil
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "Artifact", recordID: recordID)
        
        record["id"] = id.uuidString
        record["title"] = title
        record["type"] = type.rawValue
        record["content"] = content
        record["description"] = description
        record["tags"] = tags
        record["conversationId"] = conversationId
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        record["version"] = version
        
        return record
    }
}

// MARK: - Artifact Types

public enum ArtifactType: Codable, Sendable, Hashable {
    case code(language: CodeLanguage)
    case document(format: DocumentFormat)
    case visualization(type: VisualizationType)
    case interactive
    case data(format: DataFormat)
    
    public var category: String {
        switch self {
        case .code: return "code"
        case .document: return "document"
        case .visualization: return "visualization"
        case .interactive: return "interactive"
        case .data: return "data"
        }
    }
    
    public var displayName: String {
        switch self {
        case .code(let language): return "Code (\(language.displayName))"
        case .document(let format): return "Document (\(format.displayName))"
        case .visualization(let type): return "Visualization (\(type.displayName))"
        case .interactive: return "Interactive"
        case .data(let format): return "Data (\(format.displayName))"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .code(let language): return language.fileExtension
        case .document(let format): return format.fileExtension
        case .visualization: return "svg"
        case .interactive: return "html"
        case .data(let format): return format.fileExtension
        }
    }
    
    public var rawValue: String {
        switch self {
        case .code(let language): return "code:\(language.rawValue)"
        case .document(let format): return "document:\(format.rawValue)"
        case .visualization(let type): return "visualization:\(type.rawValue)"
        case .interactive: return "interactive"
        case .data(let format): return "data:\(format.rawValue)"
        }
    }
    
    public init?(rawValue: String) {
        let parts = rawValue.split(separator: ":")
        guard let category = parts.first else { return nil }
        
        switch category {
        case "code":
            guard parts.count > 1,
                  let language = CodeLanguage(rawValue: String(parts[1])) else { return nil }
            self = .code(language: language)
        case "document":
            guard parts.count > 1,
                  let format = DocumentFormat(rawValue: String(parts[1])) else { return nil }
            self = .document(format: format)
        case "visualization":
            guard parts.count > 1,
                  let type = VisualizationType(rawValue: String(parts[1])) else { return nil }
            self = .visualization(type: type)
        case "interactive":
            self = .interactive
        case "data":
            guard parts.count > 1,
                  let format = DataFormat(rawValue: String(parts[1])) else { return nil }
            self = .data(format: format)
        default:
            return nil
        }
    }
}

public enum CodeLanguage: String, Codable, Sendable, CaseIterable {
    case swift, python, javascript, typescript, java, kotlin, rust, go, cpp, csharp
    case html, css, sql, bash, ruby, php, scala, haskell, elixir, clojure
    
    public var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .rust: return "Rust"
        case .go: return "Go"
        case .cpp: return "C++"
        case .csharp: return "C#"
        case .html: return "HTML"
        case .css: return "CSS"
        case .sql: return "SQL"
        case .bash: return "Bash"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        case .scala: return "Scala"
        case .haskell: return "Haskell"
        case .elixir: return "Elixir"
        case .clojure: return "Clojure"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .swift: return "swift"
        case .python: return "py"
        case .javascript: return "js"
        case .typescript: return "ts"
        case .java: return "java"
        case .kotlin: return "kt"
        case .rust: return "rs"
        case .go: return "go"
        case .cpp: return "cpp"
        case .csharp: return "cs"
        case .html: return "html"
        case .css: return "css"
        case .sql: return "sql"
        case .bash: return "sh"
        case .ruby: return "rb"
        case .php: return "php"
        case .scala: return "scala"
        case .haskell: return "hs"
        case .elixir: return "ex"
        case .clojure: return "clj"
        }
    }
}

public enum DocumentFormat: String, Codable, Sendable, CaseIterable {
    case markdown, plainText, html, latex, rst
    
    public var displayName: String {
        switch self {
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        case .html: return "HTML"
        case .latex: return "LaTeX"
        case .rst: return "reStructuredText"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .html: return "html"
        case .latex: return "tex"
        case .rst: return "rst"
        }
    }
}

public enum VisualizationType: String, Codable, Sendable, CaseIterable {
    case svg, chart, diagram, flowchart, mindmap
    
    public var displayName: String {
        switch self {
        case .svg: return "SVG"
        case .chart: return "Chart"
        case .diagram: return "Diagram"
        case .flowchart: return "Flowchart"
        case .mindmap: return "Mind Map"
        }
    }
}

public enum DataFormat: String, Codable, Sendable, CaseIterable {
    case json, csv, yaml, xml, toml
    
    public var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .yaml: return "YAML"
        case .xml: return "XML"
        case .toml: return "TOML"
        }
    }
    
    public var fileExtension: String {
        rawValue
    }
}

// MARK: - Artifact Error

public enum ArtifactError: Error, LocalizedError, Sendable {
    case notFound
    case saveFailed(String)
    case invalidContent
    case exportFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Artifact not found"
        case .saveFailed(let reason):
            return "Failed to save artifact: \(reason)"
        case .invalidContent:
            return "Invalid artifact content"
        case .exportFailed(let reason):
            return "Failed to export artifact: \(reason)"
        }
    }
}
