import Foundation
import Observation
import os.log
@preconcurrency import SwiftData

private let knowledgeLogger = Logger(subsystem: "ai.thea.app", category: "KnowledgeManager")

@MainActor
@Observable
final class KnowledgeManager {
    static let shared = KnowledgeManager()

    private(set) var indexedFiles: [IndexedFile] = []
    private(set) var isIndexing: Bool = false
    private(set) var indexProgress: Double = 0.0

    private var modelContext: ModelContext?

    private init() {}

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadIndexedFiles()
    }

    // periphery:ignore - Reserved: startIndexing(paths:) instance method — reserved for future feature activation
    func startIndexing(paths: [URL]) async throws {
        isIndexing = true
        indexProgress = 0.0

        // periphery:ignore - Reserved: startIndexing(paths:) instance method reserved for future feature activation
        let total = paths.count
        for (index, path) in paths.enumerated() {
            try await indexFile(at: path)
            indexProgress = Double(index + 1) / Double(total)
        }

        isIndexing = false
    }

    // periphery:ignore - Reserved: indexFile(at:) instance method — reserved for future feature activation
    func indexFile(at url: URL) async throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? Int64) ?? 0

// periphery:ignore - Reserved: indexFile(at:) instance method reserved for future feature activation

        let file = IndexedFile(
            id: UUID(),
            path: url.path,
            name: url.lastPathComponent,
            size: size,
            indexedAt: Date()
        )

        modelContext?.insert(file)
        do { try modelContext?.save() } catch { knowledgeLogger.error("Failed to save indexed file: \(error.localizedDescription)") }
        indexedFiles.append(file)
    }

    // periphery:ignore - Reserved: removeFile(_:) instance method — reserved for future feature activation
    func removeFile(_ file: IndexedFile) {
        modelContext?.delete(file)
        // periphery:ignore - Reserved: removeFile(_:) instance method reserved for future feature activation
        do { try modelContext?.save() } catch { knowledgeLogger.error("Failed to save after removing file: \(error.localizedDescription)") }
        indexedFiles.removeAll { $0.id == file.id }
    }

    // periphery:ignore - Reserved: clearAllData() instance method — reserved for future feature activation
    func clearAllData() {
        // periphery:ignore - Reserved: clearAllData() instance method reserved for future feature activation
        guard let context = modelContext else { return }

        for file in indexedFiles {
            context.delete(file)
        }
        do { try context.save() } catch { knowledgeLogger.error("Failed to save after clearing all data: \(error.localizedDescription)") }

        indexedFiles.removeAll()
        isIndexing = false
        indexProgress = 0.0
    }

    // periphery:ignore - Reserved: search(query:) instance method reserved for future feature activation
    func search(query: String) -> [IndexedFile] {
        indexedFiles.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func loadIndexedFiles() {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<IndexedFile>()
        descriptor.sortBy = [SortDescriptor(\.indexedAt, order: .reverse)]
        do {
            indexedFiles = try context.fetch(descriptor)
        } catch {
            knowledgeLogger.error("Failed to fetch indexed files: \(error.localizedDescription)")
            indexedFiles = []
        }
    }
}
