// SemanticCodeIndexer.swift
// Thea V2
//
// Semantic codebase indexing with in-memory storage optimized for M3 Ultra 256GB
// Provides Cursor-level codebase understanding with instant semantic search

import Foundation
import OSLog

// MARK: - Code Chunk

/// A semantic unit of code with its embedding
public struct CodeChunk: Identifiable, Codable, Sendable {
    public let id: UUID
    public let filePath: String
    public let relativePath: String
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public let chunkType: ChunkType
    public let language: ProgrammingLanguage
    public var embedding: [Float]?
    public let metadata: ChunkMetadata
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        filePath: String,
        relativePath: String,
        content: String,
        startLine: Int,
        endLine: Int,
        chunkType: ChunkType,
        language: ProgrammingLanguage,
        embedding: [Float]? = nil,
        metadata: ChunkMetadata = ChunkMetadata(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.filePath = filePath
        self.relativePath = relativePath
        self.content = content
        self.startLine = startLine
        self.endLine = endLine
        self.chunkType = chunkType
        self.language = language
        self.embedding = embedding
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Type of code chunk
public enum ChunkType: String, Codable, Sendable {
    case function
    case method
    case classDefinition
    case structDefinition
    case enumDefinition
    case protocolDefinition
    case extensionDefinition
    case property
    case import_
    case comment
    case documentation
    case fileHeader
    case block
    case unknown
}

/// Supported programming languages
public enum ProgrammingLanguage: String, Codable, Sendable, CaseIterable {
    case swift
    case python
    case javascript
    case typescript
    case rust
    case go
    case java
    case kotlin
    case cpp
    case c
    case ruby
    case php
    case html
    case css
    case json
    case yaml
    case markdown
    case shell
    case sql
    case unknown

    public static func detect(from filePath: String) -> ProgrammingLanguage {
        let ext = (filePath as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .swift
        case "py": return .python
        case "js", "mjs", "cjs": return .javascript
        case "ts", "tsx": return .typescript
        case "rs": return .rust
        case "go": return .go
        case "java": return .java
        case "kt", "kts": return .kotlin
        case "cpp", "cc", "cxx", "hpp": return .cpp
        case "c", "h": return .c
        case "rb": return .ruby
        case "php": return .php
        case "html", "htm": return .html
        case "css", "scss", "sass": return .css
        case "json": return .json
        case "yml", "yaml": return .yaml
        case "md", "markdown": return .markdown
        case "sh", "bash", "zsh": return .shell
        case "sql": return .sql
        default: return .unknown
        }
    }
}

/// Metadata for a code chunk
public struct ChunkMetadata: Codable, Sendable {
    public var symbolName: String?
    public var parentSymbol: String?
    public var visibility: String?
    public var returnType: String?
    public var parameters: [String]?
    public var imports: [String]?
    public var references: [String]?
    public var documentation: String?
    public var complexity: Int?
    public var linesOfCode: Int?

    public init(
        symbolName: String? = nil,
        parentSymbol: String? = nil,
        visibility: String? = nil,
        returnType: String? = nil,
        parameters: [String]? = nil,
        imports: [String]? = nil,
        references: [String]? = nil,
        documentation: String? = nil,
        complexity: Int? = nil,
        linesOfCode: Int? = nil
    ) {
        self.symbolName = symbolName
        self.parentSymbol = parentSymbol
        self.visibility = visibility
        self.returnType = returnType
        self.parameters = parameters
        self.imports = imports
        self.references = references
        self.documentation = documentation
        self.complexity = complexity
        self.linesOfCode = linesOfCode
    }
}

// MARK: - Index Statistics

/// Statistics about the codebase index
public struct IndexStatistics: Sendable {
    public let totalFiles: Int
    public let totalChunks: Int
    public let totalLines: Int
    public let languageBreakdown: [ProgrammingLanguage: Int]
    public let chunkTypeBreakdown: [ChunkType: Int]
    public let memoryUsageMB: Double
    public let lastIndexedAt: Date?
    public let indexingDurationSeconds: Double?
}

// MARK: - Search Result

/// Result from semantic code indexer search
public struct IndexerCodeSearchResult: Identifiable, Sendable {
    public let id: UUID
    public let chunk: CodeChunk
    public let score: Float
    public let matchReason: IndexerMatchReason

    public enum IndexerMatchReason: Sendable {
        case semanticSimilarity(score: Float)
        case exactMatch(term: String)
        case symbolMatch(name: String)
        case filePathMatch(path: String)
    }

    public init(id: UUID, chunk: CodeChunk, score: Float, matchReason: IndexerMatchReason) {
        self.id = id
        self.chunk = chunk
        self.score = score
        self.matchReason = matchReason
    }
}

// MARK: - Indexer Configuration

/// Configuration for the semantic indexer
public struct IndexerConfiguration: Sendable {
    /// Maximum chunk size in lines
    public var maxChunkLines: Int = 100

    /// Minimum chunk size in lines
    public var minChunkLines: Int = 3

    /// Overlap between chunks in lines
    public var chunkOverlap: Int = 5

    /// File patterns to include
    public var includePatterns: [String] = ["**/*.swift", "**/*.py", "**/*.js", "**/*.ts", "**/*.go", "**/*.rs"]

    /// File patterns to exclude
    public var excludePatterns: [String] = ["**/node_modules/**", "**/.git/**", "**/build/**", "**/DerivedData/**", "**/*.generated.*"]

    /// Maximum file size to index (in bytes)
    public var maxFileSizeBytes: Int = 1_000_000  // 1MB

    /// Enable incremental indexing
    public var incrementalIndexing: Bool = true

    /// Persistence directory
    public var persistenceDirectory: URL?

    /// Embedding dimension (depends on model)
    public var embeddingDimension: Int = 384

    public init() {}
}

