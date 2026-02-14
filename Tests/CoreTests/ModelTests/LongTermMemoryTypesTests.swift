import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Memory/LongTermMemoryManager.swift)

private enum TestMemorySource: String, Sendable, CaseIterable, Codable {
    case conversation
    case extraction
    case userInput

    var displayName: String {
        switch self {
        case .conversation: return "Conversation"
        case .extraction: return "Extraction"
        case .userInput: return "User Input"
        }
    }
}

private struct TestMemoryConfig: Sendable {
    var baseDecayRate: Double = 0.1
    var minimumStrength: Double = 0.1
    var reinforcementFactor: Double = 0.2
    var maxReinforcement: Double = 0.5
    var decayInterval: TimeInterval = 3600
    var maxMemories: Int = 5000
    var autoPruneEnabled: Bool = true
}

private struct TestLongTermMemory: Identifiable, Sendable, Equatable {
    let id: UUID
    let content: String
    let category: String
    var strength: Double
    let keywords: [String]
    let source: TestMemorySource
    var lastReinforcedAt: Date?
    var reinforcementCount: Int
    let createdAt: Date
    var lastUpdatedAt: Date

    init(
        content: String,
        category: String,
        strength: Double = 0.8,
        keywords: [String] = [],
        source: TestMemorySource = .conversation
    ) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.strength = strength
        self.keywords = keywords
        self.source = source
        self.lastReinforcedAt = nil
        self.reinforcementCount = 0
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
    }

    static func == (lhs: TestLongTermMemory, rhs: TestLongTermMemory) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Memory Store Logic (standalone, testable)

private final class TestMemoryStore: @unchecked Sendable {
    private var memories: [UUID: TestLongTermMemory] = [:]
    private var categoryIndex: [String: Set<UUID>] = [:]
    private var keywordIndex: [String: Set<UUID>] = [:]
    var configuration = TestMemoryConfig()

    @discardableResult
    func storeFact(
        _ content: String,
        category: String,
        initialStrength: Double = 0.8,
        keywords: [String] = [],
        source: TestMemorySource = .conversation
    ) -> UUID {
        let memory = TestLongTermMemory(
            content: content,
            category: category,
            strength: min(1.0, max(0.0, initialStrength)),
            keywords: keywords,
            source: source
        )
        memories[memory.id] = memory
        categoryIndex[category, default: []].insert(memory.id)
        for keyword in keywords {
            keywordIndex[keyword.lowercased(), default: []].insert(memory.id)
        }
        if configuration.autoPruneEnabled {
            enforceMemoryLimit()
        }
        return memory.id
    }

    func reinforceFact(_ factId: UUID) {
        guard var memory = memories[factId] else { return }
        let boost = min(configuration.maxReinforcement,
                       configuration.reinforcementFactor * (1.0 - memory.strength))
        memory.strength = min(1.0, memory.strength + boost)
        memory.reinforcementCount += 1
        memory.lastReinforcedAt = Date()
        memory.lastUpdatedAt = Date()
        memories[factId] = memory
    }

    func applyDecay(elapsedIntervals: Int = 1) {
        for (id, var memory) in memories {
            let decayAmount = configuration.baseDecayRate * Double(elapsedIntervals)
            memory.strength = max(configuration.minimumStrength, memory.strength - decayAmount)
            memory.lastUpdatedAt = Date()
            memories[id] = memory
        }
    }

    func getActiveMemories(
        minStrength: Double = 0.3,
        category: String? = nil,
        limit: Int? = nil
    ) -> [TestLongTermMemory] {
        var result: [TestLongTermMemory]
        if let category {
            let ids = categoryIndex[category] ?? []
            result = ids.compactMap { memories[$0] }.filter { $0.strength >= minStrength }
        } else {
            result = memories.values.filter { $0.strength >= minStrength }
        }
        result.sort { $0.strength > $1.strength }
        if let limit {
            return Array(result.prefix(limit))
        }
        return result
    }

    func search(keywords: [String], minStrength: Double = 0.2, limit: Int = 20) -> [TestLongTermMemory] {
        var matchingIDs = Set<UUID>()
        for keyword in keywords {
            if let ids = keywordIndex[keyword.lowercased()] {
                matchingIDs.formUnion(ids)
            }
        }
        return matchingIDs
            .compactMap { memories[$0] }
            .filter { $0.strength >= minStrength }
            .sorted { $0.strength > $1.strength }
            .prefix(limit)
            .map { $0 }
    }

    func enforceMemoryLimit() {
        guard memories.count > configuration.maxMemories else { return }
        let sorted = memories.values.sorted { $0.strength < $1.strength }
        let toRemove = sorted.prefix(memories.count - configuration.maxMemories)
        for memory in toRemove {
            memories.removeValue(forKey: memory.id)
            categoryIndex[memory.category]?.remove(memory.id)
            for keyword in memory.keywords {
                keywordIndex[keyword.lowercased()]?.remove(memory.id)
            }
        }
    }

    func getMemory(_ id: UUID) -> TestLongTermMemory? { memories[id] }
    var count: Int { memories.count }
    var allMemories: [TestLongTermMemory] { Array(memories.values) }
}

// MARK: - Tests

@Suite("MemorySource Enum")
struct MemorySourceTests {
    @Test("All 3 sources exist")
    func allCases() {
        #expect(TestMemorySource.allCases.count == 3)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestMemorySource.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("Display names non-empty")
    func displayNames() {
        for source in TestMemorySource.allCases {
            #expect(!source.displayName.isEmpty)
        }
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for source in TestMemorySource.allCases {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(TestMemorySource.self, from: data)
            #expect(decoded == source)
        }
    }
}

@Suite("MemoryConfig Struct")
struct MemoryConfigTests {
    @Test("Default values")
    func defaults() {
        let config = TestMemoryConfig()
        #expect(config.baseDecayRate == 0.1)
        #expect(config.minimumStrength == 0.1)
        #expect(config.reinforcementFactor == 0.2)
        #expect(config.maxReinforcement == 0.5)
        #expect(config.decayInterval == 3600)
        #expect(config.maxMemories == 5000)
        #expect(config.autoPruneEnabled)
    }

    @Test("Custom config")
    func custom() {
        var config = TestMemoryConfig()
        config.maxMemories = 100
        config.baseDecayRate = 0.05
        #expect(config.maxMemories == 100)
        #expect(config.baseDecayRate == 0.05)
    }
}

@Suite("LongTermMemory Struct")
struct LongTermMemoryTests {
    @Test("Creation with defaults")
    func creation() {
        let memory = TestLongTermMemory(content: "Swift is fast", category: "programming")
        #expect(memory.content == "Swift is fast")
        #expect(memory.category == "programming")
        #expect(memory.strength == 0.8)
        #expect(memory.keywords.isEmpty)
        #expect(memory.source == .conversation)
        #expect(memory.reinforcementCount == 0)
        #expect(memory.lastReinforcedAt == nil)
    }

    @Test("Creation with all parameters")
    func fullCreation() {
        let memory = TestLongTermMemory(
            content: "User prefers dark mode",
            category: "preferences",
            strength: 0.9,
            keywords: ["dark", "mode", "ui"],
            source: .userInput
        )
        #expect(memory.keywords.count == 3)
        #expect(memory.source == .userInput)
        #expect(memory.strength == 0.9)
    }

    @Test("Identifiable")
    func identifiable() {
        let m1 = TestLongTermMemory(content: "A", category: "test")
        let m2 = TestLongTermMemory(content: "A", category: "test")
        #expect(m1.id != m2.id)
    }
}

@Suite("Memory Store — Storage")
struct MemoryStoreStorageTests {
    @Test("Store and retrieve")
    func storeAndRetrieve() {
        let store = TestMemoryStore()
        let id = store.storeFact("Swift is great", category: "programming")
        let memory = store.getMemory(id)
        #expect(memory != nil)
        #expect(memory?.content == "Swift is great")
    }

    @Test("Multiple stores")
    func multipleStores() {
        let store = TestMemoryStore()
        store.storeFact("Fact 1", category: "a")
        store.storeFact("Fact 2", category: "a")
        store.storeFact("Fact 3", category: "b")
        #expect(store.count == 3)
    }

    @Test("Strength clamped to 0-1")
    func strengthClamped() {
        let store = TestMemoryStore()
        let id1 = store.storeFact("Over", category: "test", initialStrength: 1.5)
        let id2 = store.storeFact("Under", category: "test", initialStrength: -0.5)
        #expect(store.getMemory(id1)!.strength == 1.0)
        #expect(store.getMemory(id2)!.strength == 0.0)
    }
}

@Suite("Memory Store — Reinforcement")
struct MemoryStoreReinforcementTests {
    @Test("Reinforcement increases strength")
    func reinforcementIncreases() {
        let store = TestMemoryStore()
        let id = store.storeFact("Important", category: "test", initialStrength: 0.5)
        let before = store.getMemory(id)!.strength
        store.reinforceFact(id)
        let after = store.getMemory(id)!.strength
        #expect(after > before)
    }

    @Test("Reinforcement count increases")
    func reinforcementCount() {
        let store = TestMemoryStore()
        let id = store.storeFact("Test", category: "test")
        store.reinforceFact(id)
        store.reinforceFact(id)
        #expect(store.getMemory(id)!.reinforcementCount == 2)
    }

    @Test("Reinforcement capped at 1.0")
    func reinforcementCapped() {
        let store = TestMemoryStore()
        let id = store.storeFact("Test", category: "test", initialStrength: 0.95)
        for _ in 0..<10 {
            store.reinforceFact(id)
        }
        #expect(store.getMemory(id)!.strength <= 1.0)
    }

    @Test("Reinforcement sets lastReinforcedAt")
    func setsLastReinforced() {
        let store = TestMemoryStore()
        let id = store.storeFact("Test", category: "test")
        #expect(store.getMemory(id)!.lastReinforcedAt == nil)
        store.reinforceFact(id)
        #expect(store.getMemory(id)!.lastReinforcedAt != nil)
    }

    @Test("Reinforcement of nonexistent ID is no-op")
    func nonexistentReinforcement() {
        let store = TestMemoryStore()
        store.reinforceFact(UUID()) // Should not crash
        #expect(store.count == 0)
    }

    @Test("Diminishing returns at high strength")
    func diminishingReturns() {
        let store = TestMemoryStore()
        let id = store.storeFact("Test", category: "test", initialStrength: 0.9)
        store.reinforceFact(id)
        let boost1 = store.getMemory(id)!.strength - 0.9
        // Reset
        let id2 = store.storeFact("Test2", category: "test", initialStrength: 0.3)
        store.reinforceFact(id2)
        let boost2 = store.getMemory(id2)!.strength - 0.3
        #expect(boost2 > boost1) // Lower strength gets bigger boost
    }
}

@Suite("Memory Store — Decay")
struct MemoryStoreDecayTests {
    @Test("Single decay interval")
    func singleDecay() {
        let store = TestMemoryStore()
        let id = store.storeFact("Test", category: "test", initialStrength: 0.8)
        store.applyDecay()
        #expect(store.getMemory(id)!.strength < 0.8)
    }

    @Test("Multiple decay intervals")
    func multipleDecay() {
        let store = TestMemoryStore()
        let id = store.storeFact("Test", category: "test", initialStrength: 0.8)
        store.applyDecay(elapsedIntervals: 3)
        #expect(store.getMemory(id)!.strength <= 0.5)
    }

    @Test("Decay never below minimum")
    func decayFloor() {
        let store = TestMemoryStore()
        let id = store.storeFact("Test", category: "test", initialStrength: 0.2)
        store.applyDecay(elapsedIntervals: 100)
        #expect(store.getMemory(id)!.strength >= store.configuration.minimumStrength)
    }
}

@Suite("Memory Store — Retrieval")
struct MemoryStoreRetrievalTests {
    @Test("Get active memories above threshold")
    func aboveThreshold() {
        let store = TestMemoryStore()
        store.storeFact("Strong", category: "test", initialStrength: 0.9)
        store.storeFact("Weak", category: "test", initialStrength: 0.1)
        let active = store.getActiveMemories(minStrength: 0.5)
        #expect(active.count == 1)
        #expect(active[0].content == "Strong")
    }

    @Test("Filter by category")
    func filterByCategory() {
        let store = TestMemoryStore()
        store.storeFact("Swift fact", category: "programming", initialStrength: 0.8)
        store.storeFact("Recipe", category: "cooking", initialStrength: 0.8)
        let programming = store.getActiveMemories(category: "programming")
        #expect(programming.count == 1)
        #expect(programming[0].content == "Swift fact")
    }

    @Test("Limit respected")
    func limitRespected() {
        let store = TestMemoryStore()
        for i in 0..<10 {
            store.storeFact("Fact \(i)", category: "test", initialStrength: 0.8)
        }
        let limited = store.getActiveMemories(limit: 3)
        #expect(limited.count == 3)
    }

    @Test("Results sorted by strength descending")
    func sortedByStrength() {
        let store = TestMemoryStore()
        store.storeFact("Low", category: "test", initialStrength: 0.3)
        store.storeFact("High", category: "test", initialStrength: 0.9)
        store.storeFact("Mid", category: "test", initialStrength: 0.6)
        let results = store.getActiveMemories(minStrength: 0.1)
        #expect(results[0].content == "High")
        #expect(results[2].content == "Low")
    }
}

@Suite("Memory Store — Keyword Search")
struct MemoryStoreSearchTests {
    @Test("Search by keyword")
    func searchByKeyword() {
        let store = TestMemoryStore()
        store.storeFact("SwiftUI is declarative", category: "dev", keywords: ["swift", "ui", "declarative"])
        store.storeFact("Python is dynamic", category: "dev", keywords: ["python", "dynamic"])
        let results = store.search(keywords: ["swift"])
        #expect(results.count == 1)
        #expect(results[0].content.contains("SwiftUI"))
    }

    @Test("Search is case insensitive")
    func caseInsensitive() {
        let store = TestMemoryStore()
        store.storeFact("Test", category: "test", keywords: ["Swift"])
        let results = store.search(keywords: ["swift"])
        #expect(results.count == 1)
    }

    @Test("Multiple keywords union results")
    func multipleKeywords() {
        let store = TestMemoryStore()
        store.storeFact("A", category: "test", keywords: ["alpha"])
        store.storeFact("B", category: "test", keywords: ["beta"])
        let results = store.search(keywords: ["alpha", "beta"])
        #expect(results.count == 2)
    }

    @Test("Search limit respected")
    func limitRespected() {
        let store = TestMemoryStore()
        for i in 0..<20 {
            store.storeFact("Fact \(i)", category: "test", keywords: ["common"])
        }
        let results = store.search(keywords: ["common"], limit: 5)
        #expect(results.count == 5)
    }

    @Test("Search respects min strength")
    func minStrengthRespected() {
        let store = TestMemoryStore()
        store.storeFact("Strong", category: "test", initialStrength: 0.9, keywords: ["test"])
        store.storeFact("Weak", category: "test", initialStrength: 0.1, keywords: ["test"])
        let results = store.search(keywords: ["test"], minStrength: 0.5)
        #expect(results.count == 1)
    }
}

@Suite("Memory Store — Capacity Management")
struct MemoryStoreCapacityTests {
    @Test("Enforce memory limit removes weakest")
    func enforceLimit() {
        let store = TestMemoryStore()
        store.configuration.maxMemories = 3
        store.storeFact("Strong", category: "test", initialStrength: 0.9)
        store.storeFact("Medium", category: "test", initialStrength: 0.6)
        store.storeFact("Weak", category: "test", initialStrength: 0.3)
        store.storeFact("New", category: "test", initialStrength: 0.7) // Triggers prune
        #expect(store.count <= 3)
        // Weak should be removed
        let active = store.getActiveMemories(minStrength: 0.0)
        let contents = active.map(\.content)
        #expect(!contents.contains("Weak"))
    }

    @Test("Under limit no pruning")
    func underLimit() {
        let store = TestMemoryStore()
        store.configuration.maxMemories = 100
        store.storeFact("A", category: "test")
        store.storeFact("B", category: "test")
        #expect(store.count == 2)
    }

    @Test("Auto prune disabled")
    func autoPruneDisabled() {
        let store = TestMemoryStore()
        store.configuration.maxMemories = 2
        store.configuration.autoPruneEnabled = false
        store.storeFact("A", category: "test")
        store.storeFact("B", category: "test")
        store.storeFact("C", category: "test")
        #expect(store.count == 3) // No pruning
    }
}
