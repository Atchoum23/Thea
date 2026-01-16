import Foundation
import UniformTypeIdentifiers

// MARK: - HD Knowledge Scanner
// Index all documents on system for AI context

@MainActor
@Observable
final class HDKnowledgeScanner {
    static let shared = HDKnowledgeScanner()

    private(set) var indexedFiles: [ScannedFile] = []
    private(set) var isIndexing = false
    private(set) var indexingProgress: Double = 0
    private(set) var totalFilesIndexed = 0

    private(set) var scanPaths: [URL] = []
    private var excludedPaths: Set<URL> = []
    private var fileWatchers: [FileWatcher] = []

    // Configuration reference
    private var config: KnowledgeScannerConfiguration {
        AppConfiguration.shared.knowledgeScannerConfig
    }

    // Computed supported extensions from config
    private var supportedExtensions: Set<String> {
        Set(config.allSupportedExtensions)
    }

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration

    func configureScanPaths(_ paths: [URL]) {
        scanPaths = paths
        saveConfiguration()
    }

    func addExcludedPath(_ path: URL) {
        excludedPaths.insert(path)
        saveConfiguration()
    }

    func removeExcludedPath(_ path: URL) {
        excludedPaths.remove(path)
        saveConfiguration()
    }

    private func loadConfiguration() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "HDKnowledgeScanner.scanPaths"),
           let paths = try? JSONDecoder().decode([URL].self, from: data) {
            scanPaths = paths
        }

        if let data = UserDefaults.standard.data(forKey: "HDKnowledgeScanner.excludedPaths"),
           let paths = try? JSONDecoder().decode([URL].self, from: data) {
            excludedPaths = Set(paths)
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(scanPaths) {
            UserDefaults.standard.set(data, forKey: "HDKnowledgeScanner.scanPaths")
        }

        if let data = try? JSONEncoder().encode(Array(excludedPaths)) {
            UserDefaults.standard.set(data, forKey: "HDKnowledgeScanner.excludedPaths")
        }
    }

    // MARK: - Indexing

    func startIndexing() async throws {
        guard !isIndexing else { return }

        isIndexing = true
        indexingProgress = 0
        totalFilesIndexed = 0

        do {
            for path in scanPaths {
                try await scanDirectory(path)
            }

            isIndexing = false
            indexingProgress = 1.0

            // Start file watching if enabled
            if config.enableFileWatching {
                startFileWatching()
            }
        } catch {
            isIndexing = false
            throw error
        }
    }

    func stopIndexing() {
        isIndexing = false
        stopFileWatching()
    }

    private func scanDirectory(_ url: URL) async throws {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            throw KnowledgeError.pathNotFound(url.path)
        }

        // Check if path is excluded
        if excludedPaths.contains(url) {
            return
        }

        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .fileSizeKey,
                .contentModificationDateKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var filesToIndex: [URL] = []
        let batchSize = config.indexingBatchSize

        while let fileURL = enumerator?.nextObject() as? URL {
            // Check if should index
            guard shouldIndex(fileURL) else { continue }

            filesToIndex.append(fileURL)

            // Process in batches
            if filesToIndex.count >= batchSize {
                try await indexBatch(filesToIndex)
                filesToIndex.removeAll()
            }
        }

        // Index remaining files
        if !filesToIndex.isEmpty {
            try await indexBatch(filesToIndex)
        }
    }

    private func indexBatch(_ files: [URL]) async throws {
        await withTaskGroup(of: ScannedFile?.self) { group in
            for fileURL in files {
                group.addTask {
                    try? await self.indexFile(fileURL)
                }
            }

            for await indexedFile in group {
                if let file = indexedFile {
                    indexedFiles.append(file)
                    totalFilesIndexed += 1
                }
            }
        }
    }

    private func indexFile(_ url: URL) async throws -> ScannedFile {
        // Read file content
        let content = try String(contentsOf: url, encoding: .utf8)

        // Generate embedding
        let embedding = try await generateEmbedding(content)

        // Extract metadata
        let resourceValues = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .contentTypeKey
        ])

        let file = ScannedFile(
            id: UUID(),
            url: url,
            filename: url.lastPathComponent,
            content: content,
            embedding: embedding,
            fileType: detectFileType(url),
            size: Int64(resourceValues.fileSize ?? 0),
            lastModified: resourceValues.contentModificationDate ?? Date(),
            indexedAt: Date()
        )

        return file
    }

    private func shouldIndex(_ url: URL) -> Bool {
        // Check excluded paths
        if excludedPaths.contains(where: { url.path.hasPrefix($0.path) }) {
            return false
        }

        // Check file extension
        let ext = url.pathExtension.lowercased()
        if !supportedExtensions.contains(ext) {
            return false
        }

        // Check file size
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > config.maxFileSizeBytes {
            return false
        }

        return true
    }

    private func detectFileType(_ url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()

        if config.codeExtensions.contains(ext) {
            return .code
        } else if ext == "md" || ext == "txt" {
            return .markdown
        } else if ext == "pdf" {
            return .pdf
        } else if config.dataExtensions.contains(ext) {
            return .data
        } else {
            return .text
        }
    }

    // MARK: - Embedding Generation

    private func generateEmbedding(_ text: String) async throws -> [Float] {
        // Use default AI provider for embeddings
        guard let _ = ProviderRegistry.shared.getProvider(id: SettingsManager.shared.defaultProvider) else {
            throw KnowledgeError.noProvider
        }

        // For now, generate simple hash-based embedding
        // In production, use actual embedding API
        return generateSimpleEmbedding(text)
    }

    private func generateSimpleEmbedding(_ text: String) -> [Float] {
        let dimension = config.embeddingDimension
        var embedding = [Float](repeating: 0, count: dimension)

        // Simple hash-based embedding
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)

        for (index, word) in words.prefix(dimension).enumerated() {
            let hash = abs(word.hashValue)
            embedding[index] = Float(hash % 1_000) / 1_000.0
        }

        // Normalize
        let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            embedding = embedding.map { $0 / magnitude }
        }

        return embedding
    }

    // MARK: - Search

    func semanticSearch(_ query: String, topK: Int? = nil) async throws -> [SearchResult] {
        let searchTopK = topK ?? config.defaultSearchTopK
        let queryEmbedding = try await generateEmbedding(query)

        return indexedFiles
            .map { file in
                SearchResult(
                    file: file,
                    similarity: cosineSimilarity(queryEmbedding, file.embedding),
                    relevanceScore: calculateRelevance(file, query: query)
                )
            }
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(searchTopK)
            .map { $0 }
    }

    func fullTextSearch(_ query: String, topK: Int? = nil) -> [ScannedFile] {
        let searchTopK = topK ?? config.fullTextSearchTopK
        let lowercaseQuery = query.lowercased()

        return indexedFiles
            .filter { $0.content.lowercased().contains(lowercaseQuery) }
            .prefix(searchTopK)
            .map { $0 }
    }

    private func cosineSimilarity(_ vectorA: [Float], _ vectorB: [Float]) -> Float {
        guard vectorA.count == vectorB.count else { return 0 }

        let dotProduct = zip(vectorA, vectorB).reduce(0.0) { $0 + $1.0 * $1.1 }
        let magnitudeA = sqrt(vectorA.reduce(0.0) { $0 + $1 * $1 })
        let magnitudeB = sqrt(vectorB.reduce(0.0) { $0 + $1 * $1 })

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }

    private func calculateRelevance(_ file: ScannedFile, query: String) -> Float {
        let lowercaseQuery = query.lowercased()
        let lowercaseContent = file.content.lowercased()
        let lowercaseFilename = file.filename.lowercased()

        var score: Float = 0

        // Filename match bonus
        if lowercaseFilename.contains(lowercaseQuery) {
            score += config.filenameMatchBonus
        }

        // Content match bonus
        let matches = lowercaseContent.components(separatedBy: lowercaseQuery).count - 1
        score += Float(min(matches, config.maxContentMatchBonus)) * config.contentMatchBonus

        // Recency bonus (files modified recently)
        let daysSinceModified = Date().timeIntervalSince(file.lastModified) / (24 * 3_600)
        if daysSinceModified < config.recentFileDaysThreshold {
            score += config.recentFileBonus
        } else if daysSinceModified < config.moderateRecentFileDaysThreshold {
            score += config.moderateRecentFileBonus
        }

        return score
    }

    // MARK: - File Watching

    private func startFileWatching() {
        stopFileWatching()

        for path in scanPaths {
            let watcher = FileWatcher(path: path) { [weak self] changedURL in
                Task { @MainActor [weak self] in
                    await self?.handleFileChange(changedURL)
                }
            }

            fileWatchers.append(watcher)
            watcher.start()
        }
    }

    private func stopFileWatching() {
        fileWatchers.forEach { $0.stop() }
        fileWatchers.removeAll()
    }

    private func handleFileChange(_ url: URL) async {
        // Remove old index entry
        indexedFiles.removeAll { $0.url == url }

        // Re-index file
        if shouldIndex(url) {
            if let newFile = try? await indexFile(url) {
                indexedFiles.append(newFile)
            }
        }
    }

    // MARK: - Statistics

    func getStatistics() -> KnowledgeStatistics {
        let totalSize = indexedFiles.reduce(0) { $0 + $1.size }

        var typeCounts: [FileType: Int] = [:]
        for file in indexedFiles {
            typeCounts[file.fileType, default: 0] += 1
        }

        return KnowledgeStatistics(
            totalFiles: indexedFiles.count,
            totalSize: totalSize,
            fileTypeDistribution: typeCounts,
            oldestFile: indexedFiles.min { $0.lastModified < $1.lastModified },
            newestFile: indexedFiles.max { $0.lastModified < $1.lastModified }
        )
    }
}

// MARK: - Models

struct ScannedFile: Identifiable, Sendable {
    let id: UUID
    let url: URL
    let filename: String
    let content: String
    let embedding: [Float]
    let fileType: FileType
    let size: Int64
    let lastModified: Date
    let indexedAt: Date
}

enum FileType: String, Codable, Sendable {
    case code = "Code"
    case markdown = "Markdown"
    case pdf = "PDF"
    case data = "Data"
    case text = "Text"
}

struct SearchResult: Identifiable {
    let id = UUID()
    let file: ScannedFile
    let similarity: Float
    let relevanceScore: Float
}

struct KnowledgeStatistics {
    let totalFiles: Int
    let totalSize: Int64
    let fileTypeDistribution: [FileType: Int]
    let oldestFile: ScannedFile?
    let newestFile: ScannedFile?
}

struct ScanProgress {
    let filesProcessed: Int
    let totalFiles: Int
    let percentage: Double
    let currentFile: String?
}

// MARK: - File Watcher

class FileWatcher {
    private let path: URL
    private let onChange: (URL) -> Void
    private var source: DispatchSourceFileSystemObject?

    init(path: URL, onChange: @escaping (URL) -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        let descriptor = open(path.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global()
        )

        source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.onChange(self.path)
        }

        source?.setCancelHandler {
            close(descriptor)
        }

        source?.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}

// MARK: - Errors

enum KnowledgeError: LocalizedError {
    case pathNotFound(String)
    case noProvider

    var errorDescription: String? {
        switch self {
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .noProvider:
            return "No AI provider configured for embeddings"
        }
    }
}
