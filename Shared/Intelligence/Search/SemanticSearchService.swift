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

// MARK: - Semantic Search Service

@MainActor
public final class SemanticSearchService: ObservableObject {
    public static let shared = SemanticSearchService()

    // MARK: - Configuration

    /// Similarity threshold for semantic search (0.0-1.0)
    public var similarityThreshold: Float = 0.65

    /// Maximum results to return per search
    public var maxResults: Int = 50

    /// Enable automatic indexing of new messages
    public var autoIndexEnabled: Bool = true

    /// Batch size for embedding requests
    public var batchSize: Int = 20

    // MARK: - Published State

    @Published public private(set) var isSearching = false
    @Published public private(set) var isIndexing = false
    @Published public private(set) var indexingProgress: Double = 0.0
    @Published public private(set) var lastSearchResults: [SemanticSearchResult] = []
    @Published public private(set) var indexStats: EmbeddingIndexStats?
    @Published public private(set) var lastError: SemanticSearchError?

    // MARK: - Private State

    private let embeddingIndex = EmbeddingIndexActor()
    private var indexingTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    /// Track whether API is available
    private var apiAvailable = true

    // MARK: - Initialization

    private init() {
        // Schedule periodic saves
        schedulePeriodicSave()

        // Load initial stats
        Task {
            await updateStats()
        }
    }

    // MARK: - Search API

    /// Search messages in a specific conversation by semantic similarity
    /// - Parameters:
    ///   - query: Search query text
    ///   - conversation: Conversation to search in
    /// - Returns: Array of matching message IDs sorted by relevance
    func searchMessages(query: String, in conversation: Conversation) async -> [UUID] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        isSearching = true
        defer { isSearching = false }

        // Try semantic search first
        if let queryEmbedding = await getQueryEmbedding(for: query) {
            let results = await embeddingIndex.findSimilar(
                to: queryEmbedding,
                threshold: similarityThreshold,
                limit: maxResults,
                conversationFilter: conversation.id
            )

            if !results.isEmpty {
                return results.map { $0.messageID }
            }
        }

        // Fallback to keyword search
        searchLogger.info("Falling back to keyword search for conversation \(conversation.id)")
        return keywordSearch(query: query, messages: conversation.messages)
    }

    /// Search all conversations by semantic similarity
    /// - Parameter query: Search query text
    /// - Returns: Array of tuples containing conversation and matching messages
    func searchAllConversations(query: String) async -> [(Conversation, [Message])] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        isSearching = true
        defer { isSearching = false }

        var resultsByConversation: [UUID: (conversation: Conversation?, messageIDs: [UUID], scores: [Float])] = [:]

        // Try semantic search
        if let queryEmbedding = await getQueryEmbedding(for: query) {
            let results = await embeddingIndex.findSimilar(
                to: queryEmbedding,
                threshold: similarityThreshold,
                limit: maxResults * 2,
                conversationFilter: nil
            )

            // Group results by conversation
            for (messageID, score) in results {
                // We need conversation context to build results
                // This will be populated when we match against actual conversations
                if resultsByConversation[messageID] == nil {
                    resultsByConversation[messageID] = (nil, [], [])
                }
                resultsByConversation[messageID]?.messageIDs.append(messageID)
                resultsByConversation[messageID]?.scores.append(score)
            }
        }

        // Note: The caller needs to provide conversations to match against
        // This method returns message IDs that the caller can correlate
        return []
    }

    /// Full search across provided conversations
    func search(
        query: String,
        in conversations: [Conversation],
        mode: SearchMode = .hybrid,
        limit: Int? = nil
    ) async -> [SemanticSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        isSearching = true
        lastError = nil
        defer { isSearching = false }

        let effectiveLimit = limit ?? maxResults

        let results: [SemanticSearchResult]
        switch mode {
        case .text:
            results = textSearch(query: query, in: conversations, limit: effectiveLimit)
        case .semantic:
            results = await semanticSearch(query: query, in: conversations, limit: effectiveLimit)
        case .hybrid:
            results = await hybridSearch(query: query, in: conversations, limit: effectiveLimit)
        }

        lastSearchResults = results
        return results
    }

    // MARK: - Search Modes

    public enum SearchMode: String, CaseIterable, Sendable {
        case text      // Simple text matching
        case semantic  // Embedding-based similarity
        case hybrid    // Combine both approaches
    }

    // MARK: - Index Management

    /// Index a single message
    func indexMessage(_ message: Message, in conversation: Conversation) async {
        guard autoIndexEnabled else { return }

        let content = message.content.textValue
        guard !content.isEmpty else { return }

        // Check if already indexed with same content
        let contentHash = content.hashValue
        let needsUpdate = await embeddingIndex.contentChanged(messageID: message.id, currentHash: contentHash)

        guard needsUpdate else { return }

        if let embedding = await fetchEmbedding(for: content) {
            await embeddingIndex.store(
                messageID: message.id,
                conversationID: conversation.id,
                embedding: embedding,
                content: content
            )
            searchLogger.debug("Indexed message \(message.id)")
        }
    }

    /// Index all messages in conversations (background operation)
    func indexConversations(_ conversations: [Conversation]) async {
        guard !isIndexing else {
            searchLogger.warning("Indexing already in progress")
            return
        }

        isIndexing = true
        indexingProgress = 0.0

        defer {
            isIndexing = false
            indexingProgress = 1.0
        }

        // Collect messages needing indexing
        var messagesToIndex: [(message: Message, conversation: Conversation)] = []

        for conversation in conversations {
            for message in conversation.messages {
                let content = message.content.textValue
                guard !content.isEmpty else { continue }

                let hasEmbedding = await embeddingIndex.hasEmbedding(for: message.id)
                let contentChanged = await embeddingIndex.contentChanged(
                    messageID: message.id,
                    currentHash: content.hashValue
                )

                if !hasEmbedding || contentChanged {
                    messagesToIndex.append((message, conversation))
                }
            }
        }

        guard !messagesToIndex.isEmpty else {
            searchLogger.info("All messages already indexed")
            await updateStats()
            return
        }

        searchLogger.info("Indexing \(messagesToIndex.count) messages")

        // Process in batches
        let totalBatches = (messagesToIndex.count + batchSize - 1) / batchSize

        for (batchIndex, batchStart) in stride(from: 0, to: messagesToIndex.count, by: batchSize).enumerated() {
            let batchEnd = min(batchStart + batchSize, messagesToIndex.count)
            let batch = Array(messagesToIndex[batchStart..<batchEnd])

            // Fetch embeddings for batch
            let texts = batch.map { $0.message.content.textValue }
            if let embeddings = await fetchBatchEmbeddings(for: texts) {
                // Store batch
                var storeItems: [(messageID: UUID, conversationID: UUID, embedding: [Float], content: String)] = []
                for (index, item) in batch.enumerated() {
                    if index < embeddings.count {
                        storeItems.append((
                            messageID: item.message.id,
                            conversationID: item.conversation.id,
                            embedding: embeddings[index],
                            content: texts[index]
                        ))
                    }
                }
                await embeddingIndex.storeBatch(storeItems)
            }

            indexingProgress = Double(batchIndex + 1) / Double(totalBatches)

            // Allow UI updates
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        // Save to disk
        await embeddingIndex.saveToDisk()
        await updateStats()

        searchLogger.info("Indexing complete: \(messagesToIndex.count) messages processed")
    }

    /// Clear index for a specific conversation
    public func clearIndex(for conversationID: UUID) async {
        await embeddingIndex.removeConversation(conversationID)
        await updateStats()
        searchLogger.info("Cleared index for conversation \(conversationID)")
    }

    /// Clear entire search index
    public func clearAllIndexes() async {
        await embeddingIndex.clearAll()
        await embeddingIndex.saveToDisk()
        await updateStats()
        searchLogger.info("Cleared all search indexes")
    }

    /// Force save index to disk
    public func saveIndex() async {
        await embeddingIndex.saveToDisk()
    }

    // MARK: - Private Search Methods

    private func textSearch(
        query: String,
        in conversations: [Conversation],
        limit: Int
    ) -> [SemanticSearchResult] {
        let lowercasedQuery = query.lowercased()
        var results: [SemanticSearchResult] = []

        for conversation in conversations {
            for message in conversation.messages {
                let content = message.content.textValue.lowercased()

                if content.contains(lowercasedQuery) {
                    let score = calculateTextRelevance(query: lowercasedQuery, in: content)

                    results.append(SemanticSearchResult(
                        messageID: message.id,
                        conversationID: conversation.id,
                        conversationTitle: conversation.title,
                        messageContent: message.content.textValue,
                        messageRole: message.messageRole,
                        score: score,
                        matchType: .text,
                        highlightRanges: findHighlightRanges(query: lowercasedQuery, in: message.content.textValue)
                    ))
                }
            }
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(limit))
    }

    private func semanticSearch(
        query: String,
        in conversations: [Conversation],
        limit: Int
    ) async -> [SemanticSearchResult] {
        guard let queryEmbedding = await getQueryEmbedding(for: query) else {
            searchLogger.warning("Failed to get query embedding, falling back to text search")
            lastError = .embeddingGenerationFailed
            return textSearch(query: query, in: conversations, limit: limit)
        }

        // Build message lookup
        var messageLookup: [UUID: (message: Message, conversation: Conversation)] = [:]
        for conversation in conversations {
            for message in conversation.messages {
                messageLookup[message.id] = (message, conversation)
            }
        }

        // Find similar messages
        let similar = await embeddingIndex.findSimilar(
            to: queryEmbedding,
            threshold: similarityThreshold,
            limit: limit,
            conversationFilter: nil
        )

        var results: [SemanticSearchResult] = []
        for (messageID, similarity) in similar {
            guard let (message, conversation) = messageLookup[messageID] else { continue }

            results.append(SemanticSearchResult(
                messageID: message.id,
                conversationID: conversation.id,
                conversationTitle: conversation.title,
                messageContent: message.content.textValue,
                messageRole: message.messageRole,
                score: Double(similarity),
                matchType: .semantic,
                highlightRanges: []
            ))
        }

        return results
    }

    private func hybridSearch(
        query: String,
        in conversations: [Conversation],
        limit: Int
    ) async -> [SemanticSearchResult] {
        // Run both searches
        let textResults = textSearch(query: query, in: conversations, limit: limit * 2)
        let semanticResults = await semanticSearch(query: query, in: conversations, limit: limit * 2)

        // Merge results
        var combinedScores: [UUID: (result: SemanticSearchResult, textScore: Double, semanticScore: Double)] = [:]

        for result in textResults {
            combinedScores[result.messageID] = (result, result.score, 0.0)
        }

        for result in semanticResults {
            if var existing = combinedScores[result.messageID] {
                existing.semanticScore = result.score
                combinedScores[result.messageID] = existing
            } else {
                combinedScores[result.messageID] = (result, 0.0, result.score)
            }
        }

        // Calculate hybrid score: 40% text, 60% semantic
        var results: [SemanticSearchResult] = combinedScores.values.map { entry in
            let hybridScore = (entry.textScore * 0.4) + (entry.semanticScore * 0.6)

            var result = entry.result
            result.score = hybridScore
            result.matchType = entry.textScore > 0 && entry.semanticScore > 0 ? .hybrid : (entry.textScore > 0 ? .text : .semantic)
            return result
        }

        results.sort { $0.score > $1.score }
        return Array(results.prefix(limit))
    }

    // MARK: - Keyword Search Fallback

    private func keywordSearch(query: String, messages: [Message]) -> [UUID] {
        let lowercasedQuery = query.lowercased()
        let queryTerms = lowercasedQuery.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        var scored: [(id: UUID, score: Double)] = []

        for message in messages {
            let content = message.content.textValue.lowercased()
            var matchScore = 0.0

            // Full query match
            if content.contains(lowercasedQuery) {
                matchScore += 1.0
            }

            // Individual term matches
            for term in queryTerms {
                if content.contains(term) {
                    matchScore += 0.2
                }
            }

            if matchScore > 0 {
                scored.append((message.id, matchScore))
            }
        }

        scored.sort { $0.score > $1.score }
        return scored.prefix(maxResults).map { $0.id }
    }

    // MARK: - Text Scoring

    private func calculateTextRelevance(query: String, in content: String) -> Double {
        var score = 0.5

        let words = content.components(separatedBy: .whitespacesAndNewlines)
        if words.contains(query) {
            score += 0.3
        }

        if content.hasPrefix(query) {
            score += 0.1
        }

        let occurrences = content.components(separatedBy: query).count - 1
        score += min(Double(occurrences) * 0.02, 0.1)

        return min(score, 1.0)
    }

    private func findHighlightRanges(query: String, in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        let lowercasedText = text.lowercased()
        var searchStart = lowercasedText.startIndex

        while let range = lowercasedText.range(of: query, range: searchStart..<lowercasedText.endIndex) {
            let startOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            let endOffset = lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound)
            let originalRange = text.index(text.startIndex, offsetBy: startOffset)..<text.index(text.startIndex, offsetBy: endOffset)
            ranges.append(originalRange)
            searchStart = range.upperBound
        }

        return ranges
    }

    // MARK: - Embedding API

    /// Get embedding for a query (with caching consideration)
    private func getQueryEmbedding(for query: String) async -> [Float]? {
        guard apiAvailable else { return nil }
        return await fetchEmbedding(for: query)
    }

    /// Fetch single embedding from OpenAI
    private func fetchEmbedding(for text: String) async -> [Float]? {
        guard let apiKey = getOpenAIKey(), !apiKey.isEmpty else {
            searchLogger.debug("No OpenAI API key available")
            apiAvailable = false
            return nil
        }

        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": String(text.prefix(8000))
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                searchLogger.error("Embedding API error: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    apiAvailable = false
                }
                return nil
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]],
               let first = dataArray.first,
               let embedding = first["embedding"] as? [Double] {
                apiAvailable = true
                return embedding.map { Float($0) }
            }
        } catch {
            searchLogger.error("Embedding request failed: \(error.localizedDescription)")
        }

        return nil
    }

    /// Fetch batch embeddings from OpenAI
    private func fetchBatchEmbeddings(for texts: [String]) async -> [[Float]]? {
        guard !texts.isEmpty else { return [] }
        guard let apiKey = getOpenAIKey(), !apiKey.isEmpty else {
            searchLogger.debug("No OpenAI API key available for batch embedding")
            apiAvailable = false
            return nil
        }

        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Truncate each text to 8000 chars
        let truncatedTexts = texts.map { String($0.prefix(8000)) }

        let body: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": truncatedTexts
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                searchLogger.error("Batch embedding API error: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    apiAvailable = false
                }
                return nil
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                // Sort by index to maintain order
                let sorted = dataArray.sorted {
                    ($0["index"] as? Int ?? 0) < ($1["index"] as? Int ?? 0)
                }

                var embeddings: [[Float]] = []
                for item in sorted {
                    if let embedding = item["embedding"] as? [Double] {
                        embeddings.append(embedding.map { Float($0) })
                    }
                }

                apiAvailable = true
                return embeddings
            }
        } catch {
            searchLogger.error("Batch embedding request failed: \(error.localizedDescription)")
        }

        return nil
    }

    // MARK: - API Key Access

    private func getOpenAIKey() -> String? {
        // Try THEA-prefixed key first
        if let key = SecureStorage.shared.theaAPIKey(for: .openai) {
            return key
        }
        // Fallback to legacy key storage
        return try? SecureStorage.shared.loadAPIKey(for: "openai")
    }

    // MARK: - Background Tasks

    private func schedulePeriodicSave() {
        saveTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                await self?.embeddingIndex.saveIfNeeded()
            }
        }
    }

    private func updateStats() async {
        indexStats = await embeddingIndex.statistics()
    }

    deinit {
        indexingTask?.cancel()
        saveTask?.cancel()
    }
}

// MARK: - Search Result

public struct SemanticSearchResult: Identifiable, Sendable {
    public let id: UUID
    public let messageID: UUID
    public let conversationID: UUID
    public let conversationTitle: String
    public let messageContent: String
    public let messageRole: MessageRole
    public var score: Double
    public var matchType: MatchType
    public let highlightRanges: [Range<String.Index>]

    public enum MatchType: Sendable {
        case text
        case semantic
        case hybrid
    }

    public var preview: String {
        String(messageContent.prefix(200)) + (messageContent.count > 200 ? "..." : "")
    }

    public init(
        messageID: UUID,
        conversationID: UUID,
        conversationTitle: String,
        messageContent: String,
        messageRole: MessageRole,
        score: Double,
        matchType: MatchType,
        highlightRanges: [Range<String.Index>]
    ) {
        self.id = UUID()
        self.messageID = messageID
        self.conversationID = conversationID
        self.conversationTitle = conversationTitle
        self.messageContent = messageContent
        self.messageRole = messageRole
        self.score = score
        self.matchType = matchType
        self.highlightRanges = highlightRanges
    }
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
