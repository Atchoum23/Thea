//
//  SemanticSearchService.swift
//  Thea
//
//  Semantic search across conversations using OpenAI embeddings.
//  Provides similarity-based search, automatic indexing, and disk persistence.
//
//  Features:
//  - OpenAI text-embedding-3-small for high-quality embeddings
//  - In-memory cache with disk persistence
//  - Batch embedding for efficiency
//  - Cosine similarity scoring with configurable threshold
//  - Background re-indexing support
//  - Fallback to keyword search when API unavailable
//

import Accelerate
import Foundation
import os.log

private let searchLogger = Logger(subsystem: "ai.thea.app", category: "SemanticSearch")

// MARK: - Embedding Index Actor

/// Thread-safe actor for managing the embedding index
actor EmbeddingIndexActor {
    /// Embedding vector dimension for text-embedding-3-small
    private let embeddingDimension = 1536

    /// In-memory embedding cache: messageID -> embedding vector
    private var embeddings: [UUID: [Float]] = [:]

    /// Conversation membership: conversationID -> Set of messageIDs
    private var conversationIndex: [UUID: Set<UUID>] = [:]

    /// Metadata for each embedding
    private var metadata: [UUID: EmbeddingMetadata] = [:]

    /// Persistence path for embeddings
    private let persistencePath: URL

    /// Flag indicating whether index is dirty (needs saving)
    private var isDirty = false

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let theaDir = appSupport.appendingPathComponent("Thea", isDirectory: true)
        let embeddingsDir = theaDir.appendingPathComponent("embeddings", isDirectory: true)

        try? FileManager.default.createDirectory(at: embeddingsDir, withIntermediateDirectories: true)
        self.persistencePath = embeddingsDir.appendingPathComponent("embedding_index.json")

        // Load persisted data asynchronously
        Task { [weak self] in
            await self?.loadFromDisk()
        }
    }

    /// Async load method wrapper
    private func asyncLoad() async {
        loadFromDisk()
    }

    // MARK: - Index Operations

    /// Store an embedding for a message
    func store(messageID: UUID, conversationID: UUID, embedding: [Float], content: String) {
        embeddings[messageID] = embedding
        metadata[messageID] = EmbeddingMetadata(
            conversationID: conversationID,
            contentHash: content.hashValue,
            createdAt: Date()
        )

        // Update conversation index
        if conversationIndex[conversationID] == nil {
            conversationIndex[conversationID] = []
        }
        conversationIndex[conversationID]?.insert(messageID)
        isDirty = true
    }

    /// Batch store multiple embeddings
    func storeBatch(_ batch: [(messageID: UUID, conversationID: UUID, embedding: [Float], content: String)]) {
        for item in batch {
            embeddings[item.messageID] = item.embedding
            metadata[item.messageID] = EmbeddingMetadata(
                conversationID: item.conversationID,
                contentHash: item.content.hashValue,
                createdAt: Date()
            )

            if conversationIndex[item.conversationID] == nil {
                conversationIndex[item.conversationID] = []
            }
            conversationIndex[item.conversationID]?.insert(item.messageID)
        }
        isDirty = true
    }

    /// Get embedding for a message
    func getEmbedding(for messageID: UUID) -> [Float]? {
        embeddings[messageID]
    }

    /// Check if message is indexed
    func hasEmbedding(for messageID: UUID) -> Bool {
        embeddings[messageID] != nil
    }

    /// Check if content has changed (by hash comparison)
    func contentChanged(messageID: UUID, currentHash: Int) -> Bool {
        guard let meta = metadata[messageID] else { return true }
        return meta.contentHash != currentHash
    }

    /// Get all message IDs in a conversation
    func messageIDs(in conversationID: UUID) -> Set<UUID> {
        conversationIndex[conversationID] ?? []
    }

    /// Get all indexed message IDs
    func allMessageIDs() -> Set<UUID> {
        Set(embeddings.keys)
    }

    /// Remove embedding for a message
    func remove(messageID: UUID) {
        guard let meta = metadata[messageID] else { return }
        embeddings.removeValue(forKey: messageID)
        metadata.removeValue(forKey: messageID)
        conversationIndex[meta.conversationID]?.remove(messageID)
        isDirty = true
    }

    /// Remove all embeddings for a conversation
    func removeConversation(_ conversationID: UUID) {
        guard let messageIDs = conversationIndex[conversationID] else { return }
        for messageID in messageIDs {
            embeddings.removeValue(forKey: messageID)
            metadata.removeValue(forKey: messageID)
        }
        conversationIndex.removeValue(forKey: conversationID)
        isDirty = true
    }

    /// Clear entire index
    func clearAll() {
        embeddings.removeAll()
        metadata.removeAll()
        conversationIndex.removeAll()
        isDirty = true
    }

    /// Get index statistics
    func statistics() -> EmbeddingIndexStats {
        EmbeddingIndexStats(
            totalEmbeddings: embeddings.count,
            totalConversations: conversationIndex.count,
            memoryUsageBytes: embeddings.count * embeddingDimension * MemoryLayout<Float>.size
        )
    }

    // MARK: - Search

    /// Find similar messages using cosine similarity
    func findSimilar(
        to queryEmbedding: [Float],
        threshold: Float,
        limit: Int,
        conversationFilter: UUID? = nil
    ) -> [(messageID: UUID, similarity: Float)] {
        var results: [(UUID, Float)] = []

        let candidateIDs: Set<UUID>
        if let conversationID = conversationFilter {
            candidateIDs = conversationIndex[conversationID] ?? []
        } else {
            candidateIDs = Set(embeddings.keys)
        }

        for messageID in candidateIDs {
            guard let embedding = embeddings[messageID] else { continue }
            let similarity = cosineSimilarity(queryEmbedding, embedding)
            if similarity >= threshold {
                results.append((messageID, similarity))
            }
        }

        // Sort by similarity (descending) and limit
        results.sort { $0.1 > $1.1 }
        return Array(results.prefix(limit))
    }

    // MARK: - Persistence

    /// Save index to disk if dirty
    func saveIfNeeded() {
        guard isDirty else { return }
        saveToDisk()
    }

    /// Force save to disk
    func saveToDisk() {
        let persistenceData = EmbeddingPersistenceData(
            embeddings: embeddings.mapValues { $0 },
            metadata: metadata,
            conversationIndex: conversationIndex.mapValues { Array($0) }
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(persistenceData)
            try data.write(to: persistencePath, options: .atomic)
            isDirty = false
            searchLogger.info("Saved embedding index: \(self.embeddings.count) embeddings")
        } catch {
            searchLogger.error("Failed to save embedding index: \(error.localizedDescription)")
        }
    }

    /// Load index from disk
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: persistencePath.path) else {
            searchLogger.info("No existing embedding index found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: persistencePath)
            let decoder = JSONDecoder()
            let persistenceData = try decoder.decode(EmbeddingPersistenceData.self, from: data)

            embeddings = persistenceData.embeddings
            metadata = persistenceData.metadata
            conversationIndex = persistenceData.conversationIndex.mapValues { Set($0) }

            searchLogger.info("Loaded embedding index: \(self.embeddings.count) embeddings")
        } catch {
            searchLogger.error("Failed to load embedding index: \(error.localizedDescription)")
        }
    }

    // MARK: - Vector Math

    /// Calculate cosine similarity using Accelerate framework
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        // Use Accelerate for SIMD operations
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0
    }
}

// MARK: - Supporting Types

struct EmbeddingMetadata: Codable, Sendable {
    let conversationID: UUID
    let contentHash: Int
    let createdAt: Date
}

public struct EmbeddingIndexStats: Sendable {
    public let totalEmbeddings: Int
    public let totalConversations: Int
    public let memoryUsageBytes: Int

    public var memoryUsageMB: Double {
        Double(memoryUsageBytes) / (1024 * 1024)
    }
}

struct EmbeddingPersistenceData: Codable {
    let embeddings: [UUID: [Float]]
    let metadata: [UUID: EmbeddingMetadata]
    let conversationIndex: [UUID: [UUID]]
}

// MARK: - Errors

public enum SemanticSearchError: Error, LocalizedError, Sendable {
    case embeddingGenerationFailed
    case apiKeyNotFound
    case networkError(String)
    case indexCorrupted

    public var errorDescription: String? {
        switch self {
        case .embeddingGenerationFailed:
            "Failed to generate embedding for search query"
        case .apiKeyNotFound:
            "OpenAI API key not found"
        case .networkError(let message):
            "Network error: \(message)"
        case .indexCorrupted:
            "Search index is corrupted and needs to be rebuilt"
        }
    }
}
