// SemanticCodeIndexer+Core.swift
// Thea V2
//
// SemanticCodeIndexer class implementation.

import Foundation
import OSLog

// MARK: - Semantic Code Indexer

/// Main indexer actor - manages in-memory codebase index
/// Optimized for M3 Ultra 256GB with full in-memory storage
@MainActor
public final class SemanticCodeIndexer: ObservableObject {

    // MARK: - Singleton

    public static let shared = SemanticCodeIndexer()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.thea.v2", category: "SemanticCodeIndexer")

    /// All indexed chunks (in-memory for instant access)
    private var chunks: [UUID: CodeChunk] = [:]

    /// File path to chunk IDs mapping
    private var fileIndex: [String: Set<UUID>] = [:]

    /// Symbol name to chunk IDs mapping
    private var symbolIndex: [String: Set<UUID>] = [:]

    /// Language to chunk IDs mapping
    private var languageIndex: [ProgrammingLanguage: Set<UUID>] = [:]

    /// Embeddings matrix (dense storage for SIMD operations)
    private var embeddings: [[Float]] = []

    /// Chunk ID to embedding index mapping
    private var embeddingIndex: [UUID: Int] = [:]

    /// File modification times for incremental indexing
    private var fileModificationTimes: [String: Date] = [:]

    /// Current configuration
    private var configuration: IndexerConfiguration

    /// Indexing state
    @Published public private(set) var isIndexing: Bool = false
    @Published public private(set) var indexProgress: Double = 0.0
    @Published public private(set) var lastError: Error?
    @Published public private(set) var statistics: IndexStatistics?

    /// Root paths being indexed
    private var indexedRoots: Set<String> = []

    // MARK: - Initialization

    private init(configuration: IndexerConfiguration = IndexerConfiguration()) {
        self.configuration = configuration

        // Set default persistence directory
        if configuration.persistenceDirectory == nil {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.configuration.persistenceDirectory = appSupport.appendingPathComponent("Thea/CodebaseIndex")
        }

        logger.info("SemanticCodeIndexer initialized")
    }

    // MARK: - Public API

    /// Index a codebase at the given path
    public func indexCodebase(at rootPath: String) async throws {
        guard !isIndexing else {
            logger.warning("Indexing already in progress")
            return
        }

        isIndexing = true
        indexProgress = 0.0
        lastError = nil

        defer {
            isIndexing = false
            updateStatistics()
        }

        logger.info("Starting indexing at: \(rootPath)")
        let startTime = Date()

        do {
            // Discover files
            let files = try await discoverFiles(at: rootPath)
            logger.info("Discovered \(files.count) files to index")

            // Index files with progress tracking
            for (index, filePath) in files.enumerated() {
                try await indexFile(at: filePath, relativeTo: rootPath)
                indexProgress = Double(index + 1) / Double(files.count)
            }

            indexedRoots.insert(rootPath)

            let duration = Date().timeIntervalSince(startTime)
            logger.info("Indexing completed in \(duration)s - \(self.chunks.count) chunks indexed")

            // Persist to disk in background
            Task.detached { [weak self] in
                do {
                    try await self?.persistToDisk()
                } catch {
                    self?.logger.error("Background persist failed: \(error.localizedDescription)")
                }
            }

        } catch {
            lastError = error
            logger.error("Indexing failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Search for code semantically
    public func search(query: String, limit: Int = 20) async -> [IndexerCodeSearchResult] {
        // Text-based search with keyword matching — functional without embedding model
        // Future enhancement: vector similarity search when embedding model is integrated
        textSearch(query: query, limit: limit)
    }

    /// Search by symbol name
    public func searchSymbol(name: String) -> [CodeChunk] {
        let normalizedName = name.lowercased()

        var results: [CodeChunk] = []

        for (symbolName, chunkIds) in symbolIndex {
            if symbolName.lowercased().contains(normalizedName) {
                for chunkId in chunkIds {
                    if let chunk = chunks[chunkId] {
                        results.append(chunk)
                    }
                }
            }
        }

        return results
    }

    /// Get chunks for a specific file
    public func getChunks(forFile filePath: String) -> [CodeChunk] {
        guard let chunkIds = fileIndex[filePath] else { return [] }
        return chunkIds.compactMap { chunks[$0] }.sorted { $0.startLine < $1.startLine }
    }

    /// Get all chunks for a language
    public func getChunks(forLanguage language: ProgrammingLanguage) -> [CodeChunk] {
        guard let chunkIds = languageIndex[language] else { return [] }
        return chunkIds.compactMap { chunks[$0] }
    }

    /// Update configuration
    public func updateConfiguration(_ config: IndexerConfiguration) {
        self.configuration = config
    }

    /// Clear the index
    public func clearIndex() {
        chunks.removeAll()
        fileIndex.removeAll()
        symbolIndex.removeAll()
        languageIndex.removeAll()
        embeddings.removeAll()
        embeddingIndex.removeAll()
        fileModificationTimes.removeAll()
        indexedRoots.removeAll()
        statistics = nil
        logger.info("Index cleared")
    }

    /// Load index from disk
    public func loadFromDisk() async throws {
        guard let persistDir = configuration.persistenceDirectory else { return }

        let indexFile = persistDir.appendingPathComponent("index.json")
        guard FileManager.default.fileExists(atPath: indexFile.path) else {
            logger.info("No persisted index found")
            return
        }

        let data = try Data(contentsOf: indexFile)
        let persistedIndex = try JSONDecoder().decode(PersistedIndex.self, from: data)

        // Restore in-memory structures
        for chunk in persistedIndex.chunks {
            addChunkToIndices(chunk)
        }

        fileModificationTimes = persistedIndex.fileModificationTimes
        indexedRoots = Set(persistedIndex.indexedRoots)

        updateStatistics()
        logger.info("Loaded \(self.chunks.count) chunks from disk")
    }

    // MARK: - Incremental File Operations

    /// Index a single file (for incremental updates from file watcher)
    /// - Parameters:
    ///   - filePath: Absolute path to the file
    ///   - rootPath: Optional root path for computing relative paths. If nil, uses the first indexed root.
    public func indexFile(at filePath: String, rootPath: String? = nil) async {
        // Determine the root path to use
        let effectiveRoot: String
        if let root = rootPath {
            effectiveRoot = root
        } else if let firstRoot = indexedRoots.first {
            effectiveRoot = firstRoot
        } else {
            // Use the file's directory as a fallback
            effectiveRoot = (filePath as NSString).deletingLastPathComponent
        }

        do {
            try await indexFile(at: filePath, relativeTo: effectiveRoot)
            logger.debug("Incrementally indexed: \(filePath)")
        } catch {
            logger.error("Failed to index file \(filePath): \(error.localizedDescription)")
        }
    }

    /// Remove a file from the index (for incremental updates from file watcher)
    /// - Parameter filePath: Absolute path to the file to remove
    public func removeFile(at filePath: String) async {
        // Remove all chunks for this file
        if let chunkIds = fileIndex[filePath] {
            for chunkId in chunkIds {
                if let chunk = chunks.removeValue(forKey: chunkId) {
                    // Remove from symbol index
                    if let symbolName = chunk.metadata.symbolName {
                        symbolIndex[symbolName]?.remove(chunkId)
                        if symbolIndex[symbolName]?.isEmpty == true {
                            symbolIndex.removeValue(forKey: symbolName)
                        }
                    }
                    // Remove from language index
                    languageIndex[chunk.language]?.remove(chunkId)
                    if languageIndex[chunk.language]?.isEmpty == true {
                        languageIndex.removeValue(forKey: chunk.language)
                    }
                    // Note: Embeddings array is not reindexed for performance
                    // The chunk's embeddingIndex becomes invalid but the chunk is already removed
                }
            }
        }

        // Remove from file index
        fileIndex.removeValue(forKey: filePath)
        fileModificationTimes.removeValue(forKey: filePath)

        logger.debug("Removed from index: \(filePath)")
        updateStatistics()
    }

    /// Re-index a file that was renamed
    /// - Parameters:
    ///   - oldPath: Previous path of the file
    ///   - newPath: New path of the file
    public func handleFileRename(from oldPath: String, to newPath: String) async {
        await removeFile(at: oldPath)
        await indexFile(at: newPath)
    }

}

// MARK: - Private Methods

extension SemanticCodeIndexer {

    // MARK: - Private Methods

    private func discoverFiles(at rootPath: String) async throws -> [String] {
        // Move synchronous file enumeration off the async context
        try await Task.detached(priority: .userInitiated) { [configuration, logger = self.logger] in
            var files: [String] = []
            let fileManager = FileManager.default
            let rootURL = URL(fileURLWithPath: rootPath)

            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw IndexerError.cannotEnumerateDirectory(rootPath)
            }

            while let fileURL = enumerator.nextObject() as? URL {
                let resourceValues: URLResourceValues?
                do {
                    resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                } catch {
                    logger.debug("Failed to read resource values for \(fileURL.path): \(error.localizedDescription)")
                    continue
                }

                guard resourceValues?.isRegularFile == true else { continue }

                let relativePath = fileURL.path.replacingOccurrences(of: rootPath, with: "")

                // Check exclude patterns
                if self.shouldExcludeSync(path: relativePath, patterns: configuration.excludePatterns) { continue }

                // Check include patterns
                if !self.shouldIncludeSync(path: relativePath, patterns: configuration.includePatterns) { continue }

                // Check file size
                if let size = resourceValues?.fileSize, size > configuration.maxFileSizeBytes { continue }

                files.append(fileURL.path)
            }

            return files
        }.value
    }

    // Synchronous helper for file filtering (usable in non-isolated context)
    nonisolated private func shouldExcludeSync(path: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if path.contains(pattern) || matchesGlob(path, pattern: pattern) {
                return true
            }
        }
        return false
    }

    nonisolated private func shouldIncludeSync(path: String, patterns: [String]) -> Bool {
        if patterns.isEmpty { return true }
        for pattern in patterns {
            if matchesGlob(path, pattern: pattern) {
                return true
            }
        }
        return false
    }

    nonisolated private func matchesGlob(_ path: String, pattern: String) -> Bool {
        // Simple glob matching for *.ext patterns
        if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return path.hasSuffix(suffix)
        }
        return path.contains(pattern)
    }

    private func indexFile(at filePath: String, relativeTo rootPath: String) async throws {
        let fileURL = URL(fileURLWithPath: filePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
        let modificationDate = attributes[.modificationDate] as? Date ?? Date()

        // Check if file needs re-indexing
        if let lastIndexed = fileModificationTimes[filePath], lastIndexed >= modificationDate {
            return  // File hasn't changed
        }

        // Remove old chunks for this file
        if let oldChunkIds = fileIndex[filePath] {
            for chunkId in oldChunkIds {
                removeChunkFromIndices(chunkId)
            }
        }

        // Read and parse file
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let language = ProgrammingLanguage.detect(from: filePath)
        let relativePath = filePath.replacingOccurrences(of: rootPath, with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Parse into chunks
        let newChunks = parseIntoChunks(
            content: content,
            filePath: filePath,
            relativePath: relativePath,
            language: language
        )

        // Add chunks to indices
        for chunk in newChunks {
            addChunkToIndices(chunk)
        }

        fileModificationTimes[filePath] = modificationDate
    }

    private func parseIntoChunks(
        content: String,
        filePath: String,
        relativePath: String,
        language: ProgrammingLanguage
    ) -> [CodeChunk] {
        var parsedChunks: [CodeChunk] = []
        let lines = content.components(separatedBy: .newlines)

        // Line-based chunking — functional and handles all languages uniformly
        // Future enhancement: language-specific AST parsing for struct-aware chunks

        var currentLine = 0
        while currentLine < lines.count {
            let endLine = min(currentLine + configuration.maxChunkLines, lines.count)
            let chunkLines = Array(lines[currentLine..<endLine])
            let chunkContent = chunkLines.joined(separator: "\n")

            // Skip empty chunks
            let trimmed = chunkContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.count < 10 {
                currentLine = endLine
                continue
            }

            // Detect chunk type and extract metadata
            let (chunkType, metadata) = analyzeChunk(content: chunkContent, language: language)

            let chunk = CodeChunk(
                filePath: filePath,
                relativePath: relativePath,
                content: chunkContent,
                startLine: currentLine + 1,
                endLine: endLine,
                chunkType: chunkType,
                language: language,
                metadata: metadata
            )

            parsedChunks.append(chunk)

            // Move to next chunk with overlap
            currentLine = endLine - configuration.chunkOverlap
            if currentLine < 0 { currentLine = 0 }
            if currentLine >= lines.count { break }
        }

        return parsedChunks
    }

    private func analyzeChunk(content: String, language: ProgrammingLanguage) -> (ChunkType, ChunkMetadata) {
        var metadata = ChunkMetadata()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Swift-specific patterns
        let chunkType: ChunkType
        if language == .swift {
            let (swiftType, symbolName) = detectSwiftChunkType(in: trimmed)
            chunkType = swiftType
            metadata.symbolName = symbolName
            metadata.visibility = detectSwiftVisibility(in: trimmed)
        } else {
            chunkType = .block
        }

        // Count lines of actual code
        let codeLines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        metadata.linesOfCode = codeLines.count

        return (chunkType, metadata)
    }

    /// Detects the chunk type and optional symbol name from Swift source text.
    private func detectSwiftChunkType(in trimmed: String) -> (ChunkType, String?) {
        // Keyword-to-type mapping with regex for symbol extraction
        let definitionPatterns: [(keyword: String, type: ChunkType, regex: String?)] = [
            ("func ", .function, #"func\s+(\w+)"#),
            ("class ", .classDefinition, #"class\s+(\w+)"#),
            ("struct ", .structDefinition, #"struct\s+(\w+)"#),
            ("enum ", .enumDefinition, #"enum\s+(\w+)"#),
            ("protocol ", .protocolDefinition, #"protocol\s+(\w+)"#),
            ("extension ", .extensionDefinition, nil)
        ]

        for pattern in definitionPatterns {
            guard trimmed.contains(pattern.keyword) else { continue }
            let symbolName = pattern.regex.flatMap { extractSymbolName(from: trimmed, regex: $0, keyword: pattern.keyword) }
            return (pattern.type, symbolName)
        }

        if trimmed.hasPrefix("import ") { return (.import_, nil) }
        if trimmed.hasPrefix("///") || trimmed.hasPrefix("/**") { return (.documentation, nil) }
        if trimmed.hasPrefix("//") { return (.comment, nil) }

        return (.block, nil)
    }

    /// Extracts a symbol name from source text using the given regex and keyword.
    private func extractSymbolName(from text: String, regex: String, keyword: String) -> String? {
        guard let match = text.range(of: regex, options: .regularExpression) else { return nil }
        return String(text[match])
            .replacingOccurrences(of: keyword, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Detects the visibility modifier in Swift source text.
    private func detectSwiftVisibility(in trimmed: String) -> String? {
        let visibilityKeywords = ["public ", "private ", "internal ", "fileprivate "]
        return visibilityKeywords
            .first { trimmed.contains($0) }?
            .trimmingCharacters(in: .whitespaces)
    }

    private func addChunkToIndices(_ chunk: CodeChunk) {
        // Main chunks dictionary
        chunks[chunk.id] = chunk

        // File index
        if fileIndex[chunk.filePath] == nil {
            fileIndex[chunk.filePath] = []
        }
        fileIndex[chunk.filePath]?.insert(chunk.id)

        // Symbol index
        if let symbolName = chunk.metadata.symbolName {
            if symbolIndex[symbolName] == nil {
                symbolIndex[symbolName] = []
            }
            symbolIndex[symbolName]?.insert(chunk.id)
        }

        // Language index
        if languageIndex[chunk.language] == nil {
            languageIndex[chunk.language] = []
        }
        languageIndex[chunk.language]?.insert(chunk.id)

        // Embedding (if present)
        if let embedding = chunk.embedding {
            let index = embeddings.count
            embeddings.append(embedding)
            embeddingIndex[chunk.id] = index
        }
    }

    private func removeChunkFromIndices(_ chunkId: UUID) {
        guard let chunk = chunks[chunkId] else { return }

        // Remove from file index
        fileIndex[chunk.filePath]?.remove(chunkId)

        // Remove from symbol index
        if let symbolName = chunk.metadata.symbolName {
            symbolIndex[symbolName]?.remove(chunkId)
        }

        // Remove from language index
        languageIndex[chunk.language]?.remove(chunkId)

        // Remove from main dictionary
        chunks.removeValue(forKey: chunkId)

        // Note: We don't remove from embeddings array to avoid reindexing
        // The embeddingIndex will have a stale entry, which is fine
    }

    private func textSearch(query: String, limit: Int) -> [IndexerCodeSearchResult] {
        let queryLower = query.lowercased()
        let queryTerms = queryLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        var results: [(CodeChunk, Float)] = []

        for chunk in chunks.values {
            let contentLower = chunk.content.lowercased()
            let symbolLower = chunk.metadata.symbolName?.lowercased() ?? ""
            let pathLower = chunk.relativePath.lowercased()

            var score: Float = 0.0

            // Check exact query match
            if contentLower.contains(queryLower) {
                score += 10.0
            }

            // Check individual terms
            for term in queryTerms {
                if contentLower.contains(term) {
                    score += 2.0
                }
                if symbolLower.contains(term) {
                    score += 5.0
                }
                if pathLower.contains(term) {
                    score += 3.0
                }
            }

            // Boost for symbol matches
            if !symbolLower.isEmpty && symbolLower.contains(queryLower) {
                score += 15.0
            }

            if score > 0 {
                results.append((chunk, score))
            }
        }

        // Sort by score descending
        results.sort { $0.1 > $1.1 }

        // Take top results
        return results.prefix(limit).map { chunk, score in
            IndexerCodeSearchResult(
                id: UUID(),
                chunk: chunk,
                score: score,
                matchReason: .semanticSimilarity(score: score)
            )
        }
    }

    // periphery:ignore - Reserved: shouldExclude(path:) instance method — reserved for future feature activation
    private func shouldExclude(path: String) -> Bool {
        for pattern in configuration.excludePatterns {
            // periphery:ignore - Reserved: shouldExclude(path:) instance method reserved for future feature activation
            if matchesGlob(path: path, pattern: pattern) {
                return true
            }
        }
        return false
    }

    // periphery:ignore - Reserved: shouldInclude(path:) instance method — reserved for future feature activation
    private func shouldInclude(path: String) -> Bool {
        // periphery:ignore - Reserved: shouldInclude(path:) instance method reserved for future feature activation
        for pattern in configuration.includePatterns {
            if matchesGlob(path: path, pattern: pattern) {
                return true
            }
        }
        return false
    }

    // periphery:ignore - Reserved: matchesGlob(path:pattern:) instance method reserved for future feature activation
    private func matchesGlob(path: String, pattern: String) -> Bool {
        // Simple glob matching
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "**/", with: "(.*/)?")
            .replacingOccurrences(of: "*", with: "[^/]*")

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: "^" + regexPattern + "$", options: [])
        } catch {
            logger.debug("Invalid glob pattern '\(pattern)': \(error.localizedDescription)")
            return false
        }

        let range = NSRange(path.startIndex..., in: path)
        return regex.firstMatch(in: path, options: [], range: range) != nil
    }

    private func updateStatistics() {
        var languageBreakdown: [ProgrammingLanguage: Int] = [:]
        var chunkTypeBreakdown: [ChunkType: Int] = [:]
        var totalLines = 0

        for chunk in chunks.values {
            languageBreakdown[chunk.language, default: 0] += 1
            chunkTypeBreakdown[chunk.chunkType, default: 0] += 1
            totalLines += chunk.endLine - chunk.startLine + 1
        }

        // Estimate memory usage
        let chunkMemory = chunks.count * MemoryLayout<CodeChunk>.size
        let embeddingMemory = embeddings.count * configuration.embeddingDimension * MemoryLayout<Float>.size
        let totalMemory = Double(chunkMemory + embeddingMemory) / 1_000_000.0

        statistics = IndexStatistics(
            totalFiles: fileIndex.count,
            totalChunks: chunks.count,
            totalLines: totalLines,
            languageBreakdown: languageBreakdown,
            chunkTypeBreakdown: chunkTypeBreakdown,
            memoryUsageMB: totalMemory,
            lastIndexedAt: Date(),
            indexingDurationSeconds: nil
        )
    }

    private func persistToDisk() async throws {
        guard let persistDir = configuration.persistenceDirectory else { return }

        try FileManager.default.createDirectory(at: persistDir, withIntermediateDirectories: true)

        let persistedIndex = PersistedIndex(
            chunks: Array(chunks.values),
            fileModificationTimes: fileModificationTimes,
            indexedRoots: Array(indexedRoots)
        )

        let data = try JSONEncoder().encode(persistedIndex)
        let indexFile = persistDir.appendingPathComponent("index.json")
        try data.write(to: indexFile)

        logger.info("Persisted index to disk: \(data.count) bytes")
    }
}

// MARK: - Persistence Model

private struct PersistedIndex: Codable {
    let chunks: [CodeChunk]
    let fileModificationTimes: [String: Date]
    let indexedRoots: [String]
}

// MARK: - Errors

public enum IndexerError: Error, LocalizedError {
    case cannotEnumerateDirectory(String)
    case fileNotFound(String)
    case encodingError(String)
    case embeddingGenerationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .cannotEnumerateDirectory(let path):
            return "Cannot enumerate directory: \(path)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .embeddingGenerationFailed(let message):
            return "Embedding generation failed: \(message)"
        }
    }
}
