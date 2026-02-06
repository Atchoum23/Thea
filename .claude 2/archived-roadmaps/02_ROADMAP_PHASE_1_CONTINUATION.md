
### Core API Implementation

```swift
// MARK: - File: Sources/NexusCore/SemanticMemorySearchEngine.swift

import Foundation
import CryptoKit
import Combine

@MainActor
public final class SemanticMemorySearchEngine: ObservableObject {
    // MARK: - Singleton
    public static let shared = SemanticMemorySearchEngine()

    // MARK: - Published Properties
    @Published public private(set) var isIndexing: Bool = false
    @Published public private(set) var indexProgress: IndexingProgress?
    @Published public private(set) var totalEmbeddings: Int = 0
    @Published public private(set) var lastError: SemanticSearchError?

    // MARK: - Dependencies
    private let chromaClient: ChromaDBClient
    private let embeddingProvider: EmbeddingProvider
    private let memoryManager: MemoryManager
    private let collectionName = "nexus_memories_semantic_v1"

    // MARK: - Cache
    private var embeddingCache: [UUID: MemoryEmbedding] = [:]
    private let cacheLimit = 1000

    // MARK: - Initialization
    private init() {
        self.chromaClient = ChromaDBClient.shared
        self.embeddingProvider = OpenAIEmbeddingProvider()
        self.memoryManager = MemoryManager.shared

        Task {
            await ensureCollectionExists()
            await loadEmbeddingCount()
        }

        // Listen for memory changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(memoryDidChange),
            name: .memoryDidChange,
            object: nil
        )
    }

    // MARK: - Indexing

    /// Index all memories for semantic search
    public func indexAllMemories(force: Bool = false) async throws {
        isIndexing = true
        defer { isIndexing = false }

        let memories = memoryManager.memories
        let total = memories.count
        var completed = 0

        for memory in memories {
            // Check if embedding exists and is current
            if !force, await hasValidEmbedding(for: memory) {
                completed += 1
                continue
            }

            // Generate embedding
            do {
                try await generateEmbedding(for: memory)
                completed += 1

                // Update progress
                indexProgress = IndexingProgress(
                    total: total,
                    completed: completed,
                    currentMemory: memory.title,
                    estimatedTimeRemaining: estimateTimeRemaining(completed: completed, total: total)
                )
            } catch {
                print("Error generating embedding for memory \(memory.id?.uuidString ?? "unknown"): \(error)")
                lastError = .embeddingGenerationFailed(error)
            }
        }

        // Update total count
        totalEmbeddings = try await chromaClient.count(collection: collectionName)
        indexProgress = nil
    }

    /// Generate embedding for a single memory
    public func generateEmbedding(for memory: Memory) async throws {
        guard let memoryID = memory.id else {
            throw SemanticSearchError.invalidMemory
        }

        guard let content = memory.content, !content.isEmpty else {
            throw SemanticSearchError.emptyContent
        }

        // Build embedding text (content + metadata)
        let embeddingText = buildEmbeddingText(for: memory)

        // Generate embedding
        let embedding = try await embeddingProvider.generateEmbedding(
            text: embeddingText,
            model: "text-embedding-3-small"
        )

        // Calculate content hash
        let contentHash = content.sha256()

        // Create embedding object
        let memoryEmbedding = MemoryEmbedding(
            memoryID: memoryID,
            embedding: embedding,
            contentHash: contentHash,
            tokenCount: embeddingText.split(separator: " ").count
        )

        // Store in ChromaDB
        try await chromaClient.add(
            collection: collectionName,
            embeddings: [embedding],
            documents: [embeddingText],
            metadata: [[
                "memory_id": memoryID.uuidString,
                "memory_type": memory.type ?? "",
                "memory_tier": memory.tier ?? "",
                "content_hash": contentHash,
                "created_at": memory.createdAt?.timeIntervalSince1970 ?? 0,
                "updated_at": memory.updatedAt?.timeIntervalSince1970 ?? 0,
                "tags": memory.tagsArray ?? []
            ]],
            ids: [memoryEmbedding.id.uuidString]
        )

        // Cache embedding
        embeddingCache[memoryID] = memoryEmbedding
        if embeddingCache.count > cacheLimit {
            // Remove oldest entries
            let sortedKeys = embeddingCache.keys.sorted { k1, k2 in
                (embeddingCache[k1]?.generatedAt ?? Date.distantPast) <
                (embeddingCache[k2]?.generatedAt ?? Date.distantPast)
            }
            for key in sortedKeys.prefix(embeddingCache.count - cacheLimit) {
                embeddingCache.removeValue(forKey: key)
            }
        }
    }

    // MARK: - Search

    /// Perform semantic search
    public func search(
        query: String,
        filter: SemanticSearchFilter = SemanticSearchFilter()
    ) async throws -> [SemanticSearchResult] {
        guard !query.isEmpty else {
            throw SemanticSearchError.emptyQuery
        }

        // Generate query embedding
        let queryEmbedding = try await embeddingProvider.generateEmbedding(
            text: query,
            model: "text-embedding-3-small"
        )

        // Build where clause for filters
        var whereClause: [String: Any] = [:]

        if let types = filter.memoryTypes, !types.isEmpty {
            whereClause["memory_type"] = ["$in": types.map { $0.rawValue }]
        }

        if let tiers = filter.memoryTiers, !tiers.isEmpty {
            whereClause["memory_tier"] = ["$in": tiers.map { $0.rawValue }]
        }

        // Perform vector similarity search
        let chromaResults = try await chromaClient.query(
            collection: collectionName,
            queryEmbeddings: [queryEmbedding],
            nResults: filter.maxResults * 2,
            whereDocument: whereClause.isEmpty ? nil : whereClause
        )

        // Convert to SemanticSearchResult
        var results: [SemanticSearchResult] = []

        for (index, embeddingID) in chromaResults.ids[0].enumerated() {
            // Cosine similarity (ChromaDB returns distances, convert to similarity)
            let distance = Float(chromaResults.distances[0][index])
            let similarity = 1.0 - distance

            // Apply similarity threshold
            guard similarity >= filter.minSimilarity else { continue }

            // Get metadata
            guard let metadata = chromaResults.metadata[0][index] as? [String: Any],
                  let memoryIDString = metadata["memory_id"] as? String,
                  let memoryID = UUID(uuidString: memoryIDString) else {
                continue
            }

            // Find corresponding memory
            guard let memory = memoryManager.memories.first(where: { $0.id == memoryID }) else {
                continue
            }

            // Apply date filter
            if let dateRange = filter.dateRange {
                if let createdAt = memory.createdAt {
                    guard createdAt >= dateRange.start && createdAt <= dateRange.end else {
                        continue
                    }
                }
            }

            // Apply tag filter
            if let filterTags = filter.tags, !filterTags.isEmpty {
                let memoryTags = memory.tagsArray ?? []
                guard !Set(filterTags).isDisjoint(with: Set(memoryTags)) else {
                    continue
                }
            }

            // Extract relevant snippets
            let snippets = extractRelevantSnippets(
                from: memory.content ?? "",
                query: query,
                maxSnippets: 3
            )

            // Create result
            let searchMetadata = SemanticSearchResult.SearchMetadata(
                matchType: .semantic,
                keywordMatches: [],
                semanticDistance: distance,
                contextRelevance: calculateContextRelevance(similarity: similarity, memory: memory)
            )

            let result = SemanticSearchResult(
                memory: memory,
                similarityScore: similarity,
                relevantSnippets: snippets,
                metadata: searchMetadata
            )

            results.append(result)
        }

        // Hybrid search if enabled
        if filter.includeKeywordSearch {
            results = try await mergeWithKeywordResults(
                semanticResults: results,
                query: query,
                filter: filter
            )
        }

        // Sort results
        results = sortResults(results, by: filter.sortBy)

        // Apply max results limit
        return Array(results.prefix(filter.maxResults))
    }

    /// Find similar memories to a given memory
    public func findSimilar(
        to memory: Memory,
        limit: Int = 5,
        minSimilarity: Float = 0.7
    ) async throws -> [SemanticSearchResult] {
        guard let content = memory.content, !content.isEmpty else {
            throw SemanticSearchError.emptyContent
        }

        return try await search(
            query: content,
            filter: SemanticSearchFilter(
                minSimilarity: minSimilarity,
                maxResults: limit + 1,
                includeKeywordSearch: false
            )
        ).filter { $0.memory.id != memory.id }
    }

    // MARK: - Private Helpers

    private func buildEmbeddingText(for memory: Memory) -> String {
        var components: [String] = []

        if let title = memory.title, !title.isEmpty {
            components.append("Title: \(title)")
        }

        if let content = memory.content, !content.isEmpty {
            components.append(content)
        }

        if let tags = memory.tagsArray, !tags.isEmpty {
            components.append("Tags: \(tags.joined(separator: ", "))")
        }

        if let type = memory.type {
            components.append("Type: \(type)")
        }

        return components.joined(separator: "\n")
    }

    private func hasValidEmbedding(for memory: Memory) async -> Bool {
        guard let memoryID = memory.id,
              let content = memory.content else {
            return false
        }

        // Check cache first
        if let cached = embeddingCache[memoryID] {
            return cached.contentHash == content.sha256()
        }

        // Check ChromaDB
        do {
            let results = try await chromaClient.get(
                collection: collectionName,
                ids: nil,
                where: ["memory_id": memoryID.uuidString]
            )

            if let metadata = results.metadata.first,
               let storedHash = metadata["content_hash"] as? String {
                return storedHash == content.sha256()
            }

            return !results.ids.isEmpty
        } catch {
            return false
        }
    }

    private func extractRelevantSnippets(
        from text: String,
        query: String,
        maxSnippets: Int
    ) -> [SemanticSearchResult.Snippet] {
        let sentences = text.components(separatedBy: ". ")
        let queryWords = Set(query.lowercased().components(separatedBy: " ").filter { $0.count > 2 })

        let scoredSentences = sentences.compactMap { sentence -> (sentence: String, score: Float)? in
            guard !sentence.isEmpty else { return nil }
            let sentenceWords = Set(sentence.lowercased().components(separatedBy: " "))
            let matchCount = queryWords.intersection(sentenceWords).count
            let score = Float(matchCount) / Float(max(queryWords.count, 1))
            return (sentence, score)
        }

        return scoredSentences
            .sorted { $0.score > $1.score }
            .prefix(maxSnippets)
            .map { SemanticSearchResult.Snippet(text: $0.sentence, relevanceScore: $0.score) }
    }

    private func calculateContextRelevance(similarity: Float, memory: Memory) -> Float {
        var relevance = similarity

        // Boost recent memories
        if let createdAt = memory.createdAt {
            let daysSinceCreation = Date().timeIntervalSince(createdAt) / 86400
            if daysSinceCreation < 7 {
                relevance *= 1.2
            }
        }

        // Boost frequently accessed memories
        if memory.accessCount > 5 {
            relevance *= 1.1
        }

        return min(relevance, 1.0)
    }

    private func mergeWithKeywordResults(
        semanticResults: [SemanticSearchResult],
        query: String,
        filter: SemanticSearchFilter
    ) async throws -> [SemanticSearchResult] {
        let keywordMemories = memoryManager.searchMemories(
            query: query,
            type: filter.memoryTypes?.first
        )

        var merged = semanticResults
        let semanticIDs = Set(semanticResults.map { $0.memory.id })

        for keywordMemory in keywordMemories {
            guard !semanticIDs.contains(keywordMemory.id) else {
                // Update existing result to hybrid
                if let index = merged.firstIndex(where: { $0.memory.id == keywordMemory.id }) {
                    var updated = merged[index]
                    updated = SemanticSearchResult(
                        id: updated.id,
                        memory: updated.memory,
                        similarityScore: min(updated.similarityScore * 1.3, 1.0),
                        relevantSnippets: updated.relevantSnippets,
                        metadata: SemanticSearchResult.SearchMetadata(
                            matchType: .hybrid,
                            keywordMatches: extractKeywords(from: query),
                            semanticDistance: updated.metadata.semanticDistance,
                            contextRelevance: updated.metadata.contextRelevance
                        )
                    )
                    merged[index] = updated
                }
                continue
            }

            // Add keyword-only result
            let result = SemanticSearchResult(
                memory: keywordMemory,
                similarityScore: 0.6,
                relevantSnippets: extractRelevantSnippets(
                    from: keywordMemory.content ?? "",
                    query: query,
                    maxSnippets: 2
                ),
                metadata: SemanticSearchResult.SearchMetadata(
                    matchType: .keyword,
                    keywordMatches: extractKeywords(from: query),
                    semanticDistance: 0.4,
                    contextRelevance: 0.6
                )
            )

            merged.append(result)
        }

        return merged
    }

    private func extractKeywords(from query: String) -> [String] {
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with"])
        return query.lowercased()
            .components(separatedBy: " ")
            .filter { !stopWords.contains($0) && $0.count > 2 }
    }

    private func sortResults(
        _ results: [SemanticSearchResult],
        by sortOption: SemanticSearchFilter.SortOption
    ) -> [SemanticSearchResult] {
        switch sortOption {
        case .similarity:
            return results.sorted { $0.similarityScore > $1.similarityScore }

        case .recency:
            return results.sorted { (r1, r2) in
                (r1.memory.updatedAt ?? Date.distantPast) > (r2.memory.updatedAt ?? Date.distantPast)
            }

        case .relevance:
            return results.sorted { $0.metadata.contextRelevance > $1.metadata.contextRelevance }
        }
    }

    private func estimateTimeRemaining(completed: Int, total: Int) -> TimeInterval? {
        guard completed > 0 else { return nil }
        // Rough estimate: 100ms per embedding
        let remaining = total - completed
        return TimeInterval(remaining) * 0.1
    }

    private func ensureCollectionExists() async {
        do {
            try await chromaClient.createCollection(
                name: collectionName,
                metadata: [
                    "description": "Nexus semantic memory search",
                    "model": "text-embedding-3-small",
                    "dimensions": 1536
                ]
            )
        } catch {
            // Collection exists
        }
    }

    private func loadEmbeddingCount() async {
        do {
            totalEmbeddings = try await chromaClient.count(collection: collectionName)
        } catch {
            totalEmbeddings = 0
        }
    }

    @objc private func memoryDidChange(_ notification: Notification) {
        guard let memory = notification.object as? Memory else { return }

        Task {
            do {
                try await generateEmbedding(for: memory)
            } catch {
                print("Failed to update embedding: \(error)")
            }
        }
    }
}

// MARK: - Embedding Provider Protocol

protocol EmbeddingProvider {
    func generateEmbedding(text: String, model: String) async throws -> [Float]
}

class OpenAIEmbeddingProvider: EmbeddingProvider {
    private let apiKeys = APIKeys.shared

    func generateEmbedding(text: String, model: String) async throws -> [Float] {
        guard let apiKey = apiKeys.getKey(for: "openai") else {
            throw SemanticSearchError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/embeddings")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": text,
            "model": model,
            "encoding_format": "float"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SemanticSearchError.apiError
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]],
              let embedding = dataArray.first?["embedding"] as? [Double] else {
            throw SemanticSearchError.invalidResponse
        }

        return embedding.map { Float($0) }
    }
}

// MARK: - Errors

public enum SemanticSearchError: LocalizedError {
    case invalidMemory
    case emptyContent
    case emptyQuery
    case missingAPIKey
    case apiError
    case invalidResponse
    case embeddingGenerationFailed(Error)
    case chromaDBError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidMemory:
            return "Memory is invalid or missing ID"
        case .emptyContent:
            return "Memory content is empty"
        case .emptyQuery:
            return "Search query is empty"
        case .missingAPIKey:
            return "OpenAI API key not found"
        case .apiError:
            return "OpenAI API returned an error"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .embeddingGenerationFailed(let error):
            return "Failed to generate embedding: \(error.localizedDescription)"
        case .chromaDBError(let error):
            return "ChromaDB error: \(error.localizedDescription)"
        }
    }
}

// MARK: - String Extension

extension String {
    func sha256() -> String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Notification

extension Notification.Name {
    static let memoryDidChange = Notification.Name("memoryDidChange")
}
```

### UI Components

```swift
// MARK: - File: Sources/NexusUI/SemanticSearchView.swift

import SwiftUI

struct SemanticSearchView: View {
    @StateObject private var searchEngine = SemanticMemorySearchEngine.shared
    @State private var searchQuery: String = ""
    @State private var searchResults: [SemanticSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var filter = SemanticSearchFilter()
    @State private var showFilterSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            Divider()

            // Results
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchQuery.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try adjusting your search or filters")
                )
            } else if !searchResults.isEmpty {
                searchResultsList
            } else {
                ContentUnavailableView(
                    "Semantic Search",
                    systemImage: "brain.head.profile",
                    description: Text("Search memories by meaning, not just keywords")
                )
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search memories by meaning...", text: $searchQuery)
                .textFieldStyle(.plain)
                .onSubmit {
                    performSearch()
                }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: filter.isFiltered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundColor(filter.isFiltered ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .help("Filter results")
        }
        .padding()
        .sheet(isPresented: $showFilterSheet) {
            SearchFilterSheet(filter: $filter)
        }
    }

    private var searchResultsList: some View {
        List {
            ForEach(searchResults) { result in
                SearchResultRow(result: result)
            }
        }
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }

        isSearching = true

        Task {
            do {
                let results = try await searchEngine.search(
                    query: searchQuery,
                    filter: filter
                )

                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                print("Search error: \(error)")
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SemanticSearchResult
    @StateObject private var conversationManager = ConversationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = result.memory.title {
                        Text(title)
                            .font(.headline)
                    }

                    HStack(spacing: 8) {
                        Label("\(Int(result.similarityScore * 100))% match",
                              systemImage: "sparkles")
                            .font(.caption)
                            .foregroundColor(.blue)

                        matchTypeBadge

                        if let type = result.memory.type {
                            Text(type.capitalized)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                if let updatedAt = result.memory.updatedAt {
                    Text(updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Snippets
            if !result.relevantSnippets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(result.relevantSnippets) { snippet in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(snippet.text)
                                .font(.body)
                                .lineLimit(2)

                            Spacer()
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }

            // Tags
            if let tags = result.memory.tagsArray, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            // Navigate to memory detail
        }
    }

    @ViewBuilder
    private var matchTypeBadge: some View {
        switch result.metadata.matchType {
        case .semantic:
            Label("Semantic", systemImage: "brain")
                .font(.caption2)
                .foregroundColor(.purple)
        case .keyword:
            Label("Keyword", systemImage: "text.magnifyingglass")
                .font(.caption2)
                .foregroundColor(.orange)
        case .hybrid:
            Label("Hybrid", systemImage: "sparkle.magnifyingglass")
                .font(.caption2)
                .foregroundColor(.green)
        }
    }
}

// MARK: - Filter Sheet

struct SearchFilterSheet: View {
    @Binding var filter: SemanticSearchFilter
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Similarity") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Similarity: \(Int(filter.minSimilarity * 100))%")
                            .font(.subheadline)

                        Slider(value: $filter.minSimilarity, in: 0.5...1.0, step: 0.05)
                    }
                }

                Section("Memory Type") {
                    ForEach(MemoryManager.MemoryType.allCases, id: \.self) { type in
                        Toggle(type.rawValue.capitalized, isOn: Binding(
                            get: { filter.memoryTypes?.contains(type) ?? false },
                            set: { isOn in
                                if isOn {
                                    if filter.memoryTypes == nil {
                                        filter.memoryTypes = [type]
                                    } else {
                                        filter.memoryTypes?.append(type)
                                    }
                                } else {
                                    filter.memoryTypes?.removeAll { $0 == type }
                                    if filter.memoryTypes?.isEmpty == true {
                                        filter.memoryTypes = nil
                                    }
                                }
                            }
                        ))
                    }
                }

                Section("Options") {
                    Toggle("Include Keyword Search", isOn: $filter.includeKeywordSearch)

                    Picker("Sort By", selection: $filter.sortBy) {
                        Text("Similarity").tag(SemanticSearchFilter.SortOption.similarity)
                        Text("Recency").tag(SemanticSearchFilter.SortOption.recency)
                        Text("Relevance").tag(SemanticSearchFilter.SortOption.relevance)
                    }

                    Stepper("Max Results: \(filter.maxResults)", value: $filter.maxResults, in: 5...50, step: 5)
                }
            }
            .navigationTitle("Search Filters")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        filter = SemanticSearchFilter()
                    }
                }
            }
        }
    }
}

extension SemanticSearchFilter {
    var isFiltered: Bool {
        memoryTypes != nil || memoryTiers != nil || dateRange != nil || tags != nil ||
        minSimilarity != 0.7 || maxResults != 10 || !includeKeywordSearch
    }
}
```

### Success Metrics & Rollout Plan

**Success Metrics:**
| Metric | Baseline | Target | Timeline |
|--------|----------|--------|----------|
| Search Relevance | 60% (keyword only) | 90% | Week 4 |
| User Adoption | 0% | 40% daily searches use semantic | Month 2 |
| Query Performance | N/A | < 500ms average | Week 3 |
| Indexing Coverage | 0% | 95% of memories | Week 2 |

**Rollout Plan:**
1. Week 1: Backend implementation + indexing
2. Week 2: UI components + testing
3. Week 3: Beta testing with power users
4. Week 4: General availability + documentation

---

## 1.3 Conversation Templates

**Status:** ✅ **IMPLEMENTED** - November 18, 2025

### Executive Summary

**Business Value:**
- **Problem:** Users repeatedly create similar conversation patterns
- **Solution:** Pre-built templates for common workflows
- **Impact:** 50% reduction in setup time, consistent patterns

**Implementation Effort:** 2 weeks
**Priority:** MEDIUM
**Dependencies:** None
**Risk Level:** LOW

### Data Models

```swift
// MARK: - File: Sources/NexusCore/ConversationTemplateTypes.swift

import Foundation

public struct ConversationTemplate: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let category: TemplateCategory
    public let icon: String
    public let initialMessages: [TemplateMessage]
    public let suggestedModel: String?
    public let systemPrompt: String?
    public let variables: [TemplateVariable]
    public let metadata: TemplateMetadata

    public struct TemplateMessage: Identifiable, Codable, Sendable {
        public let id: UUID
        public let role: String
        public let content: String
        public let order: Int

        public init(id: UUID = UUID(), role: String, content: String, order: Int) {
            self.id = id
            self.role = role
            self.content = content
            self.order = order
        }
    }

    public struct TemplateVariable: Identifiable, Codable, Sendable {
        public let id: UUID
        public let name: String
        public let placeholder: String
        public let defaultValue: String?
        public let required: Bool
        public let type: VariableType

        public enum VariableType: String, Codable, Sendable {
            case text
            case number
            case date
            case choice  // Multiple choice
        }

        public init(
            id: UUID = UUID(),
            name: String,
            placeholder: String,
            defaultValue: String? = nil,
            required: Bool = true,
            type: VariableType = .text
        ) {
            self.id = id
            self.name = name
            self.placeholder = placeholder
            self.defaultValue = defaultValue
            self.required = required
            self.type = type
        }
    }

    public struct TemplateMetadata: Codable, Sendable {
        public let author: String?
        public let createdAt: Date
        public let updatedAt: Date
        public let version: String
        public let usageCount: Int
        public let tags: [String]
        public let isPublic: Bool
        public let rating: Double?

        public init(
            author: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            version: String = "1.0",
            usageCount: Int = 0,
            tags: [String] = [],
            isPublic: Bool = false,
            rating: Double? = nil
        ) {
            self.author = author
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.version = version
            self.usageCount = usageCount
            self.tags = tags
            self.isPublic = isPublic
            self.rating = rating
        }
    }
}

public enum TemplateCategory: String, Codable, CaseIterable, Sendable {
    case coding = "Coding & Development"
    case writing = "Writing & Content"
    case learning = "Learning & Education"
    case research = "Research & Analysis"
    case planning = "Planning & Strategy"
    case brainstorming = "Brainstorming"
    case debugging = "Debugging & Troubleshooting"
    case review = "Review & Feedback"
    case general = "General"
}
```

Continue in next response due to length...

### Core Implementation (continued)

```swift
// MARK: - Template Manager

@MainActor
public final class ConversationTemplateManager: ObservableObject {
    public static let shared = ConversationTemplateManager()

    @Published public private(set) var templates: [ConversationTemplate] = []
    @Published public private(set) var categories: [TemplateCategory] = TemplateCategory.allCases

    private let persistenceController: PersistenceController
    private let conversationManager: ConversationManager

    private init() {
        self.persistenceController = PersistenceController.shared
        self.conversationManager = ConversationManager.shared
        loadBuiltInTemplates()
    }

    // MARK: - Template Creation

    public func createConversationFromTemplate(
        _ template: ConversationTemplate,
        variables: [String: String] = [:]
    ) -> Conversation {
        // Validate required variables
        for variable in template.variables where variable.required {
            guard variables[variable.name] != nil else {
                fatalError("Missing required variable: \(variable.name)")
            }
        }

        // Create conversation
        let title = replaceVariables(in: template.name, with: variables)
        let conversation = conversationManager.createConversation(title: title)

        // Add initial messages
        for templateMessage in template.initialMessages.sorted(by: { $0.order < $1.order }) {
            let content = replaceVariables(in: templateMessage.content, with: variables)
            conversationManager.addMessage(
                to: conversation,
                content: content,
                role: templateMessage.role
            )
        }

        // Increment usage count
        incrementUsageCount(for: template)

        return conversation
    }

    public func createCustomTemplate(
        name: String,
        description: String,
        category: TemplateCategory,
        messages: [ConversationTemplate.TemplateMessage],
        variables: [ConversationTemplate.TemplateVariable] = []
    ) -> ConversationTemplate {
        let template = ConversationTemplate(
            id: UUID(),
            name: name,
            description: description,
            category: category,
            icon: categoryIcon(for: category),
            initialMessages: messages,
            suggestedModel: nil,
            systemPrompt: nil,
            variables: variables,
            metadata: ConversationTemplate.TemplateMetadata()
        )

        templates.append(template)
        saveTemplates()

        return template
    }

    // MARK: - Built-in Templates

    private func loadBuiltInTemplates() {
        templates = [
            createCodeReviewTemplate(),
            createBrainstormingTemplate(),
            createResearchAssistantTemplate(),
            createDebuggingPartnerTemplate(),
            createWritingCoachTemplate(),
            createLearningTutorTemplate(),
            createPlanningSessionTemplate(),
            createDocumentationTemplate()
        ]
    }

    private func createCodeReviewTemplate() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(),
            name: "Code Review Session",
            description: "Comprehensive code review with focus on best practices, security, and performance",
            category: .coding,
            icon: "checkmark.seal",
            initialMessages: [
                .init(role: "system", content: """
                You are an expert code reviewer. Focus on:
                - Code quality and maintainability
                - Security vulnerabilities
                - Performance optimizations
                - Best practices for {{language}}
                - Test coverage
                Provide constructive feedback with specific suggestions.
                """, order: 0),
                .init(role: "user", content: """
                Please review the following {{language}} code for best practices, security issues, and performance concerns:
                {{code}}
                """, order: 1)
            ],
            suggestedModel: "gpt-4o",
            systemPrompt: "Expert code reviewer",
            variables: [
                .init(name: "language", placeholder: "Programming language (e.g., Swift, Python)", required: true),
                .init(name: "code", placeholder: "Code to review", required: true)
            ],
            metadata: .init(tags: ["code", "review", "quality"], isPublic: true)
        )
    }

    private func createBrainstormingTemplate() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(),
            name: "Brainstorming Session",
            description: "Structured brainstorming with idea generation and evaluation",
            category: .brainstorming,
            icon: "lightbulb",
            initialMessages: [
                .init(role: "system", content: """
                You are a creative brainstorming partner. Help generate diverse ideas by:
                - Asking clarifying questions
                - Suggesting unconventional approaches
                - Building on existing ideas
                - Identifying potential challenges
                - Encouraging wild ideas without judgment
                """, order: 0),
                .init(role: "user", content: """
                I want to brainstorm ideas for: {{topic}}

                Context: {{context}}

                Goal: {{goal}}
                """, order: 1)
            ],
            suggestedModel: "claude-3-5-sonnet",
            systemPrompt: "Creative brainstorming partner",
            variables: [
                .init(name: "topic", placeholder: "What do you want to brainstorm about?", required: true),
                .init(name: "context", placeholder: "Background information", required: false),
                .init(name: "goal", placeholder: "What you hope to achieve", required: false)
            ],
            metadata: .init(tags: ["brainstorming", "creativity", "ideas"], isPublic: true)
        )
    }

    private func createResearchAssistantTemplate() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(),
            name: "Research Assistant",
            description: "Systematic research with source citation and analysis",
            category: .research,
            icon: "book",
            initialMessages: [
                .init(role: "system", content: """
                You are a research assistant. For each query:
                1. Provide comprehensive, well-sourced information
                2. Cite sources when possible
                3. Present multiple perspectives
                4. Highlight consensus vs. debate
                5. Suggest related topics to explore
                Focus on accuracy and objectivity.
                """, order: 0),
                .init(role: "user", content: """
                Research topic: {{topic}}

                Specific questions:
                {{questions}}

                Depth level: {{depth}}
                """, order: 1)
            ],
            suggestedModel: "perplexity-sonar",
            systemPrompt: "Research assistant with web access",
            variables: [
                .init(name: "topic", placeholder: "Main research topic", required: true),
                .init(name: "questions", placeholder: "Specific questions to answer", required: false),
                .init(name: "depth", placeholder: "Overview / Detailed / Comprehensive", defaultValue: "Detailed", required: false)
            ],
            metadata: .init(tags: ["research", "analysis", "sources"], isPublic: true)
        )
    }

    private func createDebuggingPartnerTemplate() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(),
            name: "Debugging Partner",
            description: "Systematic debugging with root cause analysis",
            category: .debugging,
            icon: "ant",
            initialMessages: [
                .init(role: "system", content: """
                You are a debugging expert. Follow systematic approach:
                1. Understand the expected vs actual behavior
                2. Analyze error messages and stack traces
                3. Identify potential root causes
                4. Suggest debugging steps
                5. Propose fixes with explanations
                Ask clarifying questions to narrow down the issue.
                """, order: 0),
                .init(role: "user", content: """
                I'm debugging an issue in {{language}}.

                Expected behavior: {{expected}}

                Actual behavior: {{actual}}

                Error message: {{error}}

                Relevant code:
                {{code}}
                """, order: 1)
            ],
            suggestedModel: "gpt-4o",
            systemPrompt: "Debugging expert",
            variables: [
                .init(name: "language", placeholder: "Programming language/framework", required: true),
                .init(name: "expected", placeholder: "What should happen?", required: true),
                .init(name: "actual", placeholder: "What actually happens?", required: true),
                .init(name: "error", placeholder: "Error message (if any)", required: false),
                .init(name: "code", placeholder: "Relevant code snippet", required: false)
            ],
            metadata: .init(tags: ["debugging", "troubleshooting", "errors"], isPublic: true)
        )
    }

    private func createWritingCoachTemplate() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(),
            name: "Writing Coach",
            description: "Improve writing with structure, clarity, and style feedback",
            category: .writing,
            icon: "pencil.and.outline",
            initialMessages: [
                .init(role: "system", content: """
                You are a writing coach. Help improve writing by:
                - Analyzing structure and flow
                - Suggesting clarity improvements
                - Enhancing style and tone
                - Identifying weak arguments
                - Recommending stronger word choices
                Provide specific, actionable feedback.
                """, order: 0),
                .init(role: "user", content: """
                Please review and improve this {{type}}:

                Audience: {{audience}}
                Tone: {{tone}}

                Content:
                {{content}}
                """, order: 1)
            ],
            suggestedModel: "claude-3-5-sonnet",
            systemPrompt: "Writing coach",
            variables: [
                .init(name: "type", placeholder: "Type of writing (essay, blog, email, etc.)", required: true),
                .init(name: "audience", placeholder: "Target audience", required: false),
                .init(name: "tone", placeholder: "Desired tone (professional, casual, etc.)", required: false),
                .init(name: "content", placeholder: "Your writing", required: true)
            ],
            metadata: .init(tags: ["writing", "editing", "improvement"], isPublic: true)
        )
    }

    private func createLearningTutorTemplate() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(),
            name: "Learning Tutor",
            description: "Patient tutor with explanations, examples, and practice",
            category: .learning,
            icon: "graduationcap",
            initialMessages: [
                .init(role: "system", content: """
                You are a patient, encouraging tutor. Teaching approach:
                1. Assess current understanding
                2. Explain concepts clearly with examples
                3. Use analogies and visualizations
                4. Check understanding with questions
                5. Provide practice problems
                6. Adapt explanations based on responses
                Focus on building deep understanding, not just memorization.
                """, order: 0),
                .init(role: "user", content: """
                I want to learn about: {{topic}}

                My current level: {{level}}

                Learning goal: {{goal}}
                """, order: 1)
            ],
            suggestedModel: "gpt-4o",
            systemPrompt: "Patient learning tutor",
            variables: [
                .init(name: "topic", placeholder: "What do you want to learn?", required: true),
                .init(name: "level", placeholder: "Beginner / Intermediate / Advanced", defaultValue: "Beginner", required: false),
                .init(name: "goal", placeholder: "What do you want to achieve?", required: false)
            ],
            metadata: .init(tags: ["learning", "education", "tutorial"], isPublic: true)
        )
    }

    private func createPlanningSessionTemplate() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(),
            name: "Planning Session",
            description: "Strategic planning with goals, milestones, and timeline",
            category: .planning,
            icon: "calendar",
            initialMessages: [
                .init(role: "system", content: """
                You are a strategic planning expert. Help create actionable plans by:
                - Clarifying goals and success criteria
                - Breaking down into milestones
                - Identifying dependencies and risks
                - Creating realistic timelines
                - Suggesting resources needed
                Focus on practical, achievable plans.
                """, order: 0),
                .init(role: "user", content: """
                Project: {{project}}

                Goal: {{goal}}

                Timeline: {{timeline}}

                Constraints: {{constraints}}
                """, order: 1)
            ],
            suggestedModel: "claude-3-5-sonnet",
            systemPrompt: "Strategic planning expert",
            variables: [
                .init(name: "project", placeholder: "What are you planning?", required: true),
                .init(name: "goal", placeholder: "What do you want to achieve?", required: true),
                .init(name: "timeline", placeholder: "When do you need to complete this?", required: false),
                .init(name: "constraints", placeholder: "Budget, resources, or other constraints", required: false)
            ],
            metadata: .init(tags: ["planning", "strategy", "project"], isPublic: true)
        )
    }

    private func createDocumentationTemplate() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(),
            name: "Documentation Writer",
            description: "Create clear, comprehensive technical documentation",
            category: .writing,
            icon: "doc.text",
            initialMessages: [
                .init(role: "system", content: """
                You are a technical documentation specialist. Create docs that:
                - Are clear and concise
                - Include examples and use cases
                - Follow documentation best practices
                - Are accessible to the target audience
                - Include troubleshooting sections
                Structure documentation logically with proper sections.
                """, order: 0),
                .init(role: "user", content: """
                Create documentation for: {{item}}

                Type: {{type}}
                Audience: {{audience}}

                Technical details:
                {{details}}
                """, order: 1)
            ],
            suggestedModel: "gpt-4o",
            systemPrompt: "Technical documentation specialist",
            variables: [
                .init(name: "item", placeholder: "What needs documentation? (API, feature, library, etc.)", required: true),
                .init(name: "type", placeholder: "API docs / User guide / Tutorial / Reference", defaultValue: "User guide", required: false),
                .init(name: "audience", placeholder: "Who will read this?", required: false),
                .init(name: "details", placeholder: "Technical specifications, parameters, etc.", required: true)
            ],
            metadata: .init(tags: ["documentation", "technical writing"], isPublic: true)
        )
    }

    // MARK: - Helper Methods

    private func replaceVariables(in text: String, with variables: [String: String]) -> String {
        var result = text
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    private func categoryIcon(for category: TemplateCategory) -> String {
        switch category {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil.and.outline"
        case .learning: return "graduationcap"
        case .research: return "book"
        case .planning: return "calendar"
        case .brainstorming: return "lightbulb"
        case .debugging: return "ant"
        case .review: return "checkmark.seal"
        case .general: return "bubble.left.and.bubble.right"
        }
    }

    private func incrementUsageCount(for template: ConversationTemplate) {
        // Update template usage count
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            var updated = template
            updated = ConversationTemplate(
                id: updated.id,
                name: updated.name,
                description: updated.description,
                category: updated.category,
                icon: updated.icon,
                initialMessages: updated.initialMessages,
                suggestedModel: updated.suggestedModel,
                systemPrompt: updated.systemPrompt,
                variables: updated.variables,
                metadata: ConversationTemplate.TemplateMetadata(
                    author: updated.metadata.author,
                    createdAt: updated.metadata.createdAt,
                    updatedAt: Date(),
                    version: updated.metadata.version,
                    usageCount: updated.metadata.usageCount + 1,
                    tags: updated.metadata.tags,
                    isPublic: updated.metadata.isPublic,
                    rating: updated.metadata.rating
                )
            )
            templates[index] = updated
            saveTemplates()
        }
    }

    private func saveTemplates() {
        // Save custom templates to UserDefaults or file
        let customTemplates = templates.filter { $0.metadata.author != nil }
        if let encoded = try? JSONEncoder().encode(customTemplates) {
            UserDefaults.standard.set(encoded, forKey: "customConversationTemplates")
        }
    }
}
```

**Success Metrics:**
- 60% of users try at least one template within first week
- 40% template usage rate within 2 months
- < 2 minutes average to start conversation with template

---

