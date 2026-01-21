import Foundation
import Observation
@preconcurrency import SwiftData

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
        self.modelContext = context
        loadIndexedFiles()
    }

    func startIndexing(paths: [URL]) async throws {
        isIndexing = true
        indexProgress = 0.0

        let total = paths.count
        for (index, path) in paths.enumerated() {
            try await indexFile(at: path)
            indexProgress = Double(index + 1) / Double(total)
        }

        isIndexing = false
    }

    func indexFile(at url: URL) async throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? Int64) ?? 0

        let file = IndexedFile(
            id: UUID(),
            path: url.path,
            name: url.lastPathComponent,
            size: size,
            indexedAt: Date()
        )

        modelContext?.insert(file)
        try? modelContext?.save()
        indexedFiles.append(file)
    }

    func removeFile(_ file: IndexedFile) {
        modelContext?.delete(file)
        try? modelContext?.save()
        indexedFiles.removeAll { $0.id == file.id }
    }

    func clearAllData() {
        guard let context = modelContext else { return }

        for file in indexedFiles {
            context.delete(file)
        }
        try? context.save()

        indexedFiles.removeAll()
        isIndexing = false
        indexProgress = 0.0
    }

    func search(query: String) -> [IndexedFile] {
        indexedFiles.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func loadIndexedFiles() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<IndexedFile>(
            sortBy: [SortDescriptor(\.indexedAt, order: .reverse)]
        )
        indexedFiles = (try? context.fetch(descriptor)) ?? []
    }
}
