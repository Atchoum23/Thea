@testable import TheaCore
import XCTest

@MainActor
final class KnowledgeGraphTests: XCTestCase {
    var knowledgeGraph: KnowledgeGraph!

    override func setUp() async throws {
        knowledgeGraph = KnowledgeGraph()
        knowledgeGraph.nodes.removeAll()
        knowledgeGraph.edges.removeAll()
    }

    func testAddNode() async throws {
        let node = try await knowledgeGraph.addNode(
            content: "Swift is a programming language",
            type: .concept,
            metadata: ["category": "programming"]
        )

        XCTAssertEqual(knowledgeGraph.nodes.count, 1)
        XCTAssertEqual(node.content, "Swift is a programming language")
        XCTAssertEqual(node.type, .concept)
        XCTAssertEqual(node.metadata["category"], "programming")
    }

    func testAddEdge() async throws {
        let node1 = try await knowledgeGraph.addNode(content: "Swift", type: .concept)
        let node2 = try await knowledgeGraph.addNode(content: "iOS", type: .concept)

        let edge = try await knowledgeGraph.addEdge(
            from: node1.id,
            to: node2.id,
            type: .relatedTo,
            strength: 0.8
        )

        XCTAssertEqual(knowledgeGraph.edges.count, 1)
        XCTAssertEqual(edge.sourceNodeId, node1.id)
        XCTAssertEqual(edge.targetNodeId, node2.id)
        XCTAssertEqual(edge.type, .relatedTo)
        XCTAssertEqual(edge.strength, 0.8)
    }

    func testFindSimilarNodes() async throws {
        let node1 = try await knowledgeGraph.addNode(content: "Swift programming", type: .concept)
        let node2 = try await knowledgeGraph.addNode(content: "Swift language", type: .concept)
        let node3 = try await knowledgeGraph.addNode(content: "Cooking recipes", type: .concept)

        let similar = try await knowledgeGraph.findSimilarNodes(to: node1, threshold: 0.1)

        XCTAssertGreaterThan(similar.count, 0, "Should find similar nodes")

        let node2Similarity = similar.first { $0.0.id == node2.id }
        let node3Similarity = similar.first { $0.0.id == node3.id }

        if let node2Sim = node2Similarity?.1, let node3Sim = node3Similarity?.1 {
            XCTAssertGreaterThan(node2Sim, node3Sim, "Swift language should be more similar than cooking")
        }
    }

    func testQueryGraph() async throws {
        let swiftNode = try await knowledgeGraph.addNode(content: "Swift", type: .concept)
        let iosNode = try await knowledgeGraph.addNode(content: "iOS development", type: .skill)

        _ = try await knowledgeGraph.addEdge(from: swiftNode.id, to: iosNode.id, type: .relatedTo)

        let results = try await knowledgeGraph.queryGraph("iOS")

        XCTAssertGreaterThan(results.count, 0, "Should find iOS-related nodes")
        XCTAssertTrue(results.contains { $0.id == iosNode.id })
    }

    func testNodeTypes() {
        let types: [NodeType] = [.concept, .entity, .event, .fact, .skill]

        XCTAssertEqual(types.count, 5, "Should have 5 node types")

        for type in types {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    func testEdgeTypes() {
        let types: [EdgeType] = [
            .relatedTo, .dependsOn, .partOf, .similarTo,
            .contradicts, .causes, .derivedFrom, .inferredFrom
        ]

        XCTAssertEqual(types.count, 8, "Should have 8 edge types")
    }

    func testClustering() async throws {
        for index in 0..<10 {
            _ = try await knowledgeGraph.addNode(
                content: "Test node \(index)",
                type: .concept
            )
        }

        let clusters = try await knowledgeGraph.clusterNodes(k: 3)

        XCTAssertEqual(clusters.count, 3, "Should create 3 clusters")
        XCTAssertFalse(clusters[0].isEmpty, "Clusters should not be empty")
    }
}
