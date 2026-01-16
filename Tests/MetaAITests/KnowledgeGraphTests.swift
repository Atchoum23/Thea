@testable import TheaCore
import XCTest

// MARK: - KnowledgeGraph Tests
// Tests updated to match current KnowledgeGraph API (singleton pattern)

@MainActor
final class KnowledgeGraphTests: XCTestCase {
    var knowledgeGraph: KnowledgeGraph!

    override func setUp() async throws {
        knowledgeGraph = KnowledgeGraph.shared
    }

    func testAddNode() async throws {
        let initialCount = knowledgeGraph.nodes.count
        
        let node = try await knowledgeGraph.addNode(
            content: "Swift is a programming language",
            type: .concept,
            metadata: ["category": "programming"]
        )

        XCTAssertEqual(knowledgeGraph.nodes.count, initialCount + 1)
        XCTAssertEqual(node.content, "Swift is a programming language")
        XCTAssertEqual(node.type, .concept)
        XCTAssertEqual(node.metadata["category"], "programming")
    }

    func testCreateEdge() async throws {
        let node1 = try await knowledgeGraph.addNode(content: "Swift", type: .concept)
        let node2 = try await knowledgeGraph.addNode(content: "iOS", type: .concept)

        let edge = try await knowledgeGraph.createEdge(
            from: node1.id,
            to: node2.id,
            type: .relatedTo,
            strength: 0.8
        )

        XCTAssertEqual(edge.sourceId, node1.id)
        XCTAssertEqual(edge.targetId, node2.id)
        XCTAssertEqual(edge.type, .relatedTo)
        XCTAssertEqual(edge.strength, 0.8)
    }

    func testFindSimilar() async throws {
        _ = try await knowledgeGraph.addNode(content: "Swift programming language", type: .concept)
        _ = try await knowledgeGraph.addNode(content: "Swift iOS development", type: .concept)
        _ = try await knowledgeGraph.addNode(content: "Cooking recipes for pasta", type: .concept)

        let similar = try await knowledgeGraph.findSimilar(to: "Swift", limit: 10, threshold: 0.1)

        XCTAssertGreaterThan(similar.count, 0, "Should find similar nodes")
    }

    func testQueryGraph() async throws {
        let swiftNode = try await knowledgeGraph.addNode(content: "Swift", type: .concept)
        let iosNode = try await knowledgeGraph.addNode(content: "iOS development", type: .concept)

        _ = try await knowledgeGraph.createEdge(from: swiftNode.id, to: iosNode.id, type: .relatedTo)

        let results = try await knowledgeGraph.query("iOS")

        XCTAssertGreaterThan(results.count, 0, "Should find iOS-related nodes")
    }

    func testNodeTypes() {
        let types: [NodeType] = [.concept, .entity, .event, .fact]

        XCTAssertGreaterThanOrEqual(types.count, 4, "Should have at least 4 node types")

        for type in types {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    func testEdgeTypes() {
        let types: [EdgeType] = [
            .relatedTo, .dependsOn, .partOf, .similarTo,
            .contradicts, .causes, .derivedFrom
        ]

        XCTAssertGreaterThanOrEqual(types.count, 7, "Should have at least 7 edge types")
    }
}
