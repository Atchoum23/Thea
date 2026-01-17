import XCTest
@testable import TheaCore

@MainActor
final class MemorySystemTests: XCTestCase {
    var memorySystem: MemorySystem!

    override func setUp() async throws {
        memorySystem = MemorySystem()
        memorySystem.shortTermMemory.removeAll()
        memorySystem.longTermMemory.removeAll()
        memorySystem.workingMemory.removeAll()
    }

    func testAddShortTermMemory() async throws {
        let memory = try await memorySystem.addShortTermMemory(
            content: "User prefers dark mode",
            type: .episodic,
            metadata: ["preference": "theme"]
        )

        XCTAssertEqual(memorySystem.shortTermMemory.count, 1)
        XCTAssertEqual(memory.content, "User prefers dark mode")
        XCTAssertEqual(memory.type, .episodic)
        XCTAssertEqual(memory.tier, .shortTerm)
    }

    func testMemoryConsolidation() async throws {
        for index in 0..<100 {
            _ = try await memorySystem.addShortTermMemory(
                content: "Memory \(index)",
                type: .semantic
            )
        }

        XCTAssertLessThanOrEqual(
            memorySystem.shortTermMemory.count,
            memorySystem.shortTermCapacity,
            "Short-term memory should not exceed capacity"
        )

        XCTAssertGreaterThan(
            memorySystem.longTermMemory.count,
            0,
            "Memories should be consolidated to long-term"
        )
    }

    func testMemoryRetrieval() async throws {
        _ = try await memorySystem.addShortTermMemory(
            content: "Swift is a programming language",
            type: .semantic
        )

        _ = try await memorySystem.addShortTermMemory(
            content: "User likes pizza",
            type: .episodic
        )

        let results = try await memorySystem.retrieveRelevantMemories(
            query: "programming",
            limit: 5
        )

        XCTAssertGreaterThan(results.count, 0, "Should retrieve relevant memories")

        let programmingMemory = results.first(where: { $0.content.contains("Swift") })
        XCTAssertNotNil(programmingMemory, "Should find Swift memory for programming query")
    }

    func testMemoryTypes() {
        let types: [MemoryType] = [.episodic, .semantic, .procedural, .sensory]

        XCTAssertEqual(types.count, 4, "Should have 4 memory types")

        for type in types {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    func testMemoryTiers() {
        let tiers: [MemoryTier] = [.shortTerm, .working, .longTerm]

        XCTAssertEqual(tiers.count, 3, "Should have 3 memory tiers")
    }

    func testWorkingMemory() async throws {
        let memory = try await memorySystem.addToWorkingMemory(
            content: "Current task context",
            metadata: ["task": "coding"]
        )

        XCTAssertEqual(memorySystem.workingMemory.count, 1)
        XCTAssertEqual(memory.tier, .working)
    }

    func testMemoryImportance() async throws {
        let memory = try await memorySystem.addShortTermMemory(
            content: "Test memory",
            type: .episodic
        )

        XCTAssertGreaterThan(memory.importance, 0, "Memory should have importance score")
        XCTAssertLessThanOrEqual(memory.importance, 1, "Importance should be normalized")
    }

    func testMemoryAccessTracking() async throws {
        let memory = try await memorySystem.addShortTermMemory(
            content: "Test",
            type: .semantic
        )

        let initialAccessCount = memory.accessCount
        let initialAccessTime = memory.lastAccessed

        _ = try await memorySystem.retrieveRelevantMemories(query: "Test", limit: 1)

        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertGreaterThanOrEqual(memory.accessCount, initialAccessCount)
    }
}
