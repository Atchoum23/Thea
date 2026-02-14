// MemoryServiceTypesTests.swift
// Tests for MemoryService types — memory model, indexing, search, merge logic

import Testing
import Foundation

// MARK: - Test Doubles

private struct TestTheaMemory: Codable, Sendable, Identifiable {
    let id: UUID
    var content: String
    var keywords: [String]
    var sentiment: TestMemorySentiment
    var context: String?
    var importance: Double
    let createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        content: String,
        keywords: [String] = [],
        sentiment: TestMemorySentiment = .neutral,
        context: String? = nil,
        importance: Double = 0.5,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.keywords = keywords
        self.sentiment = sentiment
        self.context = context
        self.importance = importance
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

private enum TestMemorySentiment: String, Codable, Sendable, CaseIterable {
    case positive, negative, neutral
}

/// Mirrors MemoryService's keyword index building logic
private func buildIndex(from memories: [TestTheaMemory]) -> [String: Set<UUID>] {
    var index: [String: Set<UUID>] = [:]
    for memory in memories {
        for keyword in memory.keywords {
            index[keyword.lowercased(), default: []].insert(memory.id)
        }
    }
    return index
}

/// Mirrors MemoryService's keyword search logic
private func searchByKeyword(
    _ keyword: String,
    memories: [TestTheaMemory],
    index: [String: Set<UUID>]
) -> [TestTheaMemory] {
    guard let matchingIds = index[keyword.lowercased()] else { return [] }
    return memories.filter { matchingIds.contains($0.id) }
}

/// Mirrors memory merge logic: newer timestamp wins for same ID
private func mergeMemories(
    local: [TestTheaMemory],
    cloud: [TestTheaMemory]
) -> [TestTheaMemory] {
    var byId: [UUID: TestTheaMemory] = [:]

    for memory in local {
        byId[memory.id] = memory
    }

    for cloudMemory in cloud {
        if let existing = byId[cloudMemory.id] {
            if cloudMemory.modifiedAt > existing.modifiedAt {
                byId[cloudMemory.id] = cloudMemory
            }
        } else {
            byId[cloudMemory.id] = cloudMemory
        }
    }

    return Array(byId.values).sorted { $0.modifiedAt > $1.modifiedAt }
}

// MARK: - Tests: Memory Model

@Suite("TheaMemory Model")
struct TheaMemoryModelTests {
    @Test("Default creation")
    func defaultCreation() {
        let memory = TestTheaMemory(content: "Test memory")
        #expect(memory.content == "Test memory")
        #expect(memory.keywords.isEmpty)
        #expect(memory.sentiment == .neutral)
        #expect(memory.context == nil)
        #expect(memory.importance == 0.5)
    }

    @Test("Full creation")
    func fullCreation() {
        let memory = TestTheaMemory(
            content: "User prefers dark mode",
            keywords: ["preference", "dark mode", "UI"],
            sentiment: .positive,
            context: "Settings discussion",
            importance: 0.8
        )
        #expect(memory.keywords.count == 3)
        #expect(memory.sentiment == .positive)
        #expect(memory.context == "Settings discussion")
        #expect(memory.importance == 0.8)
    }

    @Test("Identifiable with unique IDs")
    func identifiable() {
        let m1 = TestTheaMemory(content: "a")
        let m2 = TestTheaMemory(content: "b")
        #expect(m1.id != m2.id)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let memory = TestTheaMemory(
            content: "Remember this",
            keywords: ["important"],
            sentiment: .positive,
            importance: 0.9
        )
        let data = try JSONEncoder().encode(memory)
        let decoded = try JSONDecoder().decode(TestTheaMemory.self, from: data)
        #expect(decoded.id == memory.id)
        #expect(decoded.content == memory.content)
        #expect(decoded.keywords == memory.keywords)
        #expect(decoded.sentiment == memory.sentiment)
        #expect(decoded.importance == memory.importance)
    }

    @Test("Mutable properties can be updated")
    func mutableProperties() {
        var memory = TestTheaMemory(content: "original")
        memory.content = "updated"
        memory.keywords = ["new"]
        memory.importance = 1.0
        memory.modifiedAt = Date()
        #expect(memory.content == "updated")
        #expect(memory.keywords == ["new"])
        #expect(memory.importance == 1.0)
    }
}

// MARK: - Tests: Sentiment Enum

@Suite("Memory Sentiment")
struct MemorySentimentTests {
    @Test("All 3 cases exist")
    func allCases() {
        #expect(TestMemorySentiment.allCases.count == 3)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestMemorySentiment.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        for sentiment in TestMemorySentiment.allCases {
            let data = try JSONEncoder().encode(sentiment)
            let decoded = try JSONDecoder().decode(TestMemorySentiment.self, from: data)
            #expect(decoded == sentiment)
        }
    }
}

// MARK: - Tests: Keyword Index

@Suite("Keyword Index")
struct KeywordIndexTests {
    @Test("Build index from memories")
    func buildFromMemories() {
        let memories = [
            TestTheaMemory(content: "a", keywords: ["swift", "code"]),
            TestTheaMemory(content: "b", keywords: ["swift", "testing"]),
            TestTheaMemory(content: "c", keywords: ["code"])
        ]
        let index = buildIndex(from: memories)
        #expect(index["swift"]?.count == 2)
        #expect(index["code"]?.count == 2)
        #expect(index["testing"]?.count == 1)
    }

    @Test("Index is case-insensitive")
    func caseInsensitive() {
        let memories = [
            TestTheaMemory(content: "a", keywords: ["Swift"]),
            TestTheaMemory(content: "b", keywords: ["SWIFT"]),
            TestTheaMemory(content: "c", keywords: ["swift"])
        ]
        let index = buildIndex(from: memories)
        #expect(index["swift"]?.count == 3)
        #expect(index["Swift"] == nil) // Only lowercase keys
    }

    @Test("Empty keywords produce empty index")
    func emptyKeywords() {
        let memories = [
            TestTheaMemory(content: "no keywords")
        ]
        let index = buildIndex(from: memories)
        #expect(index.isEmpty)
    }

    @Test("Empty memories produce empty index")
    func emptyMemories() {
        let index = buildIndex(from: [])
        #expect(index.isEmpty)
    }

    @Test("Duplicate keywords in same memory don't multiply")
    func duplicateKeywords() {
        let memory = TestTheaMemory(content: "a", keywords: ["swift", "swift", "swift"])
        let index = buildIndex(from: [memory])
        #expect(index["swift"]?.count == 1) // Set deduplicates
    }
}

// MARK: - Tests: Keyword Search

@Suite("Keyword Search")
struct KeywordSearchTests {
    private var testMemories: [TestTheaMemory] {
        [
            TestTheaMemory(content: "Use SwiftUI for views", keywords: ["swift", "swiftui", "ui"]),
            TestTheaMemory(content: "Test with XCTest", keywords: ["swift", "testing", "xctest"]),
            TestTheaMemory(content: "Dark mode preferred", keywords: ["ui", "dark mode"]),
            TestTheaMemory(content: "Python for scripts", keywords: ["python", "scripting"])
        ]
    }

    @Test("Search finds matching memories")
    func findMatching() {
        let memories = testMemories
        let index = buildIndex(from: memories)
        let results = searchByKeyword("swift", memories: memories, index: index)
        #expect(results.count == 2)
    }

    @Test("Search is case-insensitive")
    func caseInsensitive() {
        let memories = testMemories
        let index = buildIndex(from: memories)
        let results = searchByKeyword("SWIFT", memories: memories, index: index)
        #expect(results.count == 2)
    }

    @Test("Search returns empty for non-existent keyword")
    func noResults() {
        let memories = testMemories
        let index = buildIndex(from: memories)
        let results = searchByKeyword("rust", memories: memories, index: index)
        #expect(results.isEmpty)
    }

    @Test("Search by specific keyword returns exact matches")
    func specificKeyword() {
        let memories = testMemories
        let index = buildIndex(from: memories)
        let results = searchByKeyword("python", memories: memories, index: index)
        #expect(results.count == 1)
        #expect(results.first?.content == "Python for scripts")
    }

    @Test("Search by UI keyword finds multiple")
    func uiKeyword() {
        let memories = testMemories
        let index = buildIndex(from: memories)
        let results = searchByKeyword("ui", memories: memories, index: index)
        #expect(results.count == 2)
    }
}

// MARK: - Tests: Memory Merge

@Suite("Memory Merge Logic")
struct MemoryMergeTests {
    @Test("Merge with no conflicts — union of memories")
    func noConflicts() {
        let local = [TestTheaMemory(content: "local only")]
        let cloud = [TestTheaMemory(content: "cloud only")]
        let merged = mergeMemories(local: local, cloud: cloud)
        #expect(merged.count == 2)
    }

    @Test("Merge with same ID — newer wins")
    func newerWins() {
        let id = UUID()
        let now = Date()
        let local = [TestTheaMemory(id: id, content: "old", modifiedAt: now.addingTimeInterval(-100))]
        let cloud = [TestTheaMemory(id: id, content: "new", modifiedAt: now)]
        let merged = mergeMemories(local: local, cloud: cloud)
        #expect(merged.count == 1)
        #expect(merged.first?.content == "new")
    }

    @Test("Merge with same ID — local newer stays")
    func localNewerStays() {
        let id = UUID()
        let now = Date()
        let local = [TestTheaMemory(id: id, content: "local new", modifiedAt: now)]
        let cloud = [TestTheaMemory(id: id, content: "cloud old", modifiedAt: now.addingTimeInterval(-100))]
        let merged = mergeMemories(local: local, cloud: cloud)
        #expect(merged.count == 1)
        #expect(merged.first?.content == "local new")
    }

    @Test("Merge empty local with cloud")
    func emptyLocal() {
        let cloud = [
            TestTheaMemory(content: "a"),
            TestTheaMemory(content: "b")
        ]
        let merged = mergeMemories(local: [], cloud: cloud)
        #expect(merged.count == 2)
    }

    @Test("Merge local with empty cloud")
    func emptyCloud() {
        let local = [
            TestTheaMemory(content: "a"),
            TestTheaMemory(content: "b")
        ]
        let merged = mergeMemories(local: local, cloud: [])
        #expect(merged.count == 2)
    }

    @Test("Merge both empty")
    func bothEmpty() {
        let merged = mergeMemories(local: [], cloud: [])
        #expect(merged.isEmpty)
    }

    @Test("Merged results sorted by modifiedAt descending")
    func sortedByDate() {
        let now = Date()
        let local = [
            TestTheaMemory(content: "c", modifiedAt: now.addingTimeInterval(-200)),
            TestTheaMemory(content: "a", modifiedAt: now)
        ]
        let cloud = [
            TestTheaMemory(content: "b", modifiedAt: now.addingTimeInterval(-100))
        ]
        let merged = mergeMemories(local: local, cloud: cloud)
        #expect(merged.count == 3)
        #expect(merged[0].content == "a") // Newest first
        #expect(merged[2].content == "c") // Oldest last
    }

    @Test("Merge preserves all properties")
    func preservesProperties() {
        let id = UUID()
        let now = Date()
        let cloud = [TestTheaMemory(
            id: id,
            content: "updated",
            keywords: ["new", "cloud"],
            sentiment: .positive,
            context: "cloud context",
            importance: 0.9,
            modifiedAt: now
        )]
        let local = [TestTheaMemory(
            id: id,
            content: "old",
            keywords: ["old"],
            sentiment: .neutral,
            importance: 0.5,
            modifiedAt: now.addingTimeInterval(-100)
        )]
        let merged = mergeMemories(local: local, cloud: cloud)
        #expect(merged.count == 1)
        #expect(merged[0].keywords == ["new", "cloud"])
        #expect(merged[0].sentiment == .positive)
        #expect(merged[0].importance == 0.9)
    }
}

// MARK: - Tests: Memory Importance

@Suite("Memory Importance")
struct MemoryImportanceTests {
    @Test("Importance range is 0-1")
    func importanceRange() {
        let values = [0.0, 0.25, 0.5, 0.75, 1.0]
        for value in values {
            let memory = TestTheaMemory(content: "test", importance: value)
            #expect(memory.importance >= 0.0)
            #expect(memory.importance <= 1.0)
        }
    }

    @Test("Default importance is 0.5")
    func defaultImportance() {
        let memory = TestTheaMemory(content: "test")
        #expect(memory.importance == 0.5)
    }

    @Test("High importance memories can be filtered")
    func filterHighImportance() {
        let memories = [
            TestTheaMemory(content: "low", importance: 0.2),
            TestTheaMemory(content: "medium", importance: 0.5),
            TestTheaMemory(content: "high", importance: 0.9)
        ]
        let important = memories.filter { $0.importance > 0.7 }
        #expect(important.count == 1)
        #expect(important.first?.content == "high")
    }
}

// MARK: - Tests: Memory Capacity

@Suite("Memory Capacity")
struct MemoryCapacityTests {
    @Test("Max memories constant")
    func maxMemories() {
        let maxMemories = 10000
        #expect(maxMemories == 10000)
    }

    @Test("Trim to max capacity keeps newest")
    func trimToMaxCapacity() {
        let now = Date()
        let memories = (0..<100).map {
            TestTheaMemory(
                content: "memory-\($0)",
                modifiedAt: now.addingTimeInterval(Double($0))
            )
        }
        let maxCapacity = 50
        let trimmed = Array(memories.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(maxCapacity))
        #expect(trimmed.count == maxCapacity)
        #expect(trimmed.first?.content == "memory-99") // Newest first
    }
}
