import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Memory/PersonalKnowledgeGraph.swift)

private enum TestKGEntityType: String, Sendable, CaseIterable {
    case person
    case place
    case organization
    case concept
    case event
    case document
    case project
    case skill
    case tool
    case preference

    var icon: String {
        switch self {
        case .person: return "person.fill"
        case .place: return "mappin.circle.fill"
        case .organization: return "building.2.fill"
        case .concept: return "lightbulb.fill"
        case .event: return "calendar"
        case .document: return "doc.fill"
        case .project: return "folder.fill"
        case .skill: return "star.fill"
        case .tool: return "wrench.fill"
        case .preference: return "heart.fill"
        }
    }
}

private struct TestKGEntity: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let type: TestKGEntityType
    var metadata: [String: String]
    var lastUpdatedAt: Date

    init(id: String = UUID().uuidString, name: String, type: TestKGEntityType, metadata: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.type = type
        self.metadata = metadata
        self.lastUpdatedAt = Date()
    }

    static func == (lhs: TestKGEntity, rhs: TestKGEntity) -> Bool {
        lhs.id == rhs.id
    }
}

private struct TestKGEdge: Sendable, Equatable {
    let sourceID: String
    let targetID: String
    let relationship: String
    let confidence: Double
    let createdAt: Date
    var lastReferencedAt: Date

    init(sourceID: String, targetID: String, relationship: String, confidence: Double = 1.0) {
        self.sourceID = sourceID
        self.targetID = targetID
        self.relationship = relationship
        self.confidence = confidence
        self.createdAt = Date()
        self.lastReferencedAt = Date()
    }

    static func == (lhs: TestKGEdge, rhs: TestKGEdge) -> Bool {
        lhs.sourceID == rhs.sourceID && lhs.targetID == rhs.targetID && lhs.relationship == rhs.relationship
    }
}

// MARK: - Graph Logic (standalone, testable)

private final class TestKnowledgeGraph: @unchecked Sendable {
    private var entities: [String: TestKGEntity] = [:]
    private var edges: [TestKGEdge] = []

    func addEntity(_ entity: TestKGEntity) {
        entities[entity.id] = entity
    }

    func getEntity(_ id: String) -> TestKGEntity? {
        entities[id]
    }

    func allEntities() -> [TestKGEntity] {
        Array(entities.values)
    }

    func entities(ofType type: TestKGEntityType) -> [TestKGEntity] {
        entities.values.filter { $0.type == type }
    }

    func searchEntities(query: String) -> [TestKGEntity] {
        let q = query.lowercased()
        return entities.values.filter { $0.name.lowercased().contains(q) }
    }

    func addRelationship(from sourceID: String, to targetID: String, relationship: String, confidence: Double = 1.0) {
        guard entities[sourceID] != nil, entities[targetID] != nil else { return }
        let edge = TestKGEdge(sourceID: sourceID, targetID: targetID, relationship: relationship, confidence: confidence)
        edges.append(edge)
    }

    func relationships(for entityID: String) -> [TestKGEdge] {
        edges.filter { $0.sourceID == entityID || $0.targetID == entityID }
    }

    func outgoingRelationships(for entityID: String) -> [TestKGEdge] {
        edges.filter { $0.sourceID == entityID }
    }

    func incomingRelationships(for entityID: String) -> [TestKGEdge] {
        edges.filter { $0.targetID == entityID }
    }

    // BFS pathfinding (mirrors production)
    func findConnection(from sourceID: String, to targetID: String, maxDepth: Int = 4) -> [TestKGEdge]? {
        guard entities[sourceID] != nil, entities[targetID] != nil else { return nil }
        if sourceID == targetID { return [] }

        var visited = Set<String>()
        var queue: [(String, [TestKGEdge])] = [(sourceID, [])]
        visited.insert(sourceID)

        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()
            if path.count >= maxDepth { continue }

            for edge in edges where edge.sourceID == current {
                if edge.targetID == targetID {
                    return path + [edge]
                }
                if !visited.contains(edge.targetID) {
                    visited.insert(edge.targetID)
                    queue.append((edge.targetID, path + [edge]))
                }
            }

            for edge in edges where edge.targetID == current {
                if edge.sourceID == targetID {
                    return path + [edge]
                }
                if !visited.contains(edge.sourceID) {
                    visited.insert(edge.sourceID)
                    queue.append((edge.sourceID, path + [edge]))
                }
            }
        }

        return nil
    }

    func relatedEntities(to entityID: String, limit: Int = 10) -> [(entity: TestKGEntity, edgeCount: Int)] {
        var counts: [String: Int] = [:]
        for edge in edges {
            if edge.sourceID == entityID {
                counts[edge.targetID, default: 0] += 1
            } else if edge.targetID == entityID {
                counts[edge.sourceID, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { pair in
                guard let entity = entities[pair.key] else { return nil }
                return (entity: entity, edgeCount: pair.value)
            }
    }

    func removeEntity(_ id: String) {
        entities.removeValue(forKey: id)
        edges.removeAll { $0.sourceID == id || $0.targetID == id }
    }

    var entityCount: Int { entities.count }
    var edgeCount: Int { edges.count }
}

// MARK: - Tests

@Suite("KGEntityType Enum")
struct KGEntityTypeTests {
    @Test("All 10 types exist")
    func allCases() {
        #expect(TestKGEntityType.allCases.count == 10)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = TestKGEntityType.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All have icons")
    func allHaveIcons() {
        for type in TestKGEntityType.allCases {
            #expect(!type.icon.isEmpty)
        }
    }
}

@Suite("KGEntity Struct")
struct KGEntityTests {
    @Test("Creation with defaults")
    func creation() {
        let entity = TestKGEntity(name: "Swift", type: .skill)
        #expect(entity.name == "Swift")
        #expect(entity.type == .skill)
        #expect(entity.metadata.isEmpty)
    }

    @Test("Creation with metadata")
    func withMetadata() {
        let entity = TestKGEntity(name: "Alexis", type: .person, metadata: ["role": "developer"])
        #expect(entity.metadata["role"] == "developer")
    }

    @Test("Identifiable by ID")
    func identifiable() {
        let e1 = TestKGEntity(id: "same", name: "A", type: .concept)
        let e2 = TestKGEntity(id: "same", name: "B", type: .person)
        #expect(e1 == e2) // Same ID
    }

    @Test("Different IDs not equal")
    func notEqual() {
        let e1 = TestKGEntity(name: "A", type: .concept)
        let e2 = TestKGEntity(name: "A", type: .concept)
        #expect(e1 != e2) // Different auto-generated IDs
    }
}

@Suite("KGEdge Struct")
struct KGEdgeTests {
    @Test("Creation")
    func creation() {
        let edge = TestKGEdge(sourceID: "a", targetID: "b", relationship: "knows")
        #expect(edge.sourceID == "a")
        #expect(edge.targetID == "b")
        #expect(edge.relationship == "knows")
        #expect(edge.confidence == 1.0)
    }

    @Test("Custom confidence")
    func customConfidence() {
        let edge = TestKGEdge(sourceID: "a", targetID: "b", relationship: "might_know", confidence: 0.5)
        #expect(edge.confidence == 0.5)
    }

    @Test("Equality by source+target+relationship")
    func equality() {
        let e1 = TestKGEdge(sourceID: "a", targetID: "b", relationship: "knows")
        let e2 = TestKGEdge(sourceID: "a", targetID: "b", relationship: "knows")
        #expect(e1 == e2)
    }

    @Test("Different relationship not equal")
    func notEqual() {
        let e1 = TestKGEdge(sourceID: "a", targetID: "b", relationship: "knows")
        let e2 = TestKGEdge(sourceID: "a", targetID: "b", relationship: "works_with")
        #expect(e1 != e2)
    }
}

@Suite("Knowledge Graph — Entity Operations")
struct KGEntityOperationsTests {
    @Test("Add and retrieve entity")
    func addAndRetrieve() {
        let graph = TestKnowledgeGraph()
        let entity = TestKGEntity(id: "swift", name: "Swift", type: .skill)
        graph.addEntity(entity)
        #expect(graph.getEntity("swift")?.name == "Swift")
    }

    @Test("Get nonexistent entity returns nil")
    func nonexistent() {
        let graph = TestKnowledgeGraph()
        #expect(graph.getEntity("nonexistent") == nil)
    }

    @Test("Filter by type")
    func filterByType() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(name: "Swift", type: .skill))
        graph.addEntity(TestKGEntity(name: "Python", type: .skill))
        graph.addEntity(TestKGEntity(name: "Alexis", type: .person))
        #expect(graph.entities(ofType: .skill).count == 2)
        #expect(graph.entities(ofType: .person).count == 1)
        #expect(graph.entities(ofType: .place).isEmpty)
    }

    @Test("Search entities by name")
    func searchByName() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(name: "SwiftUI", type: .skill))
        graph.addEntity(TestKGEntity(name: "Swift Package Manager", type: .tool))
        graph.addEntity(TestKGEntity(name: "Python", type: .skill))
        let results = graph.searchEntities(query: "swift")
        #expect(results.count == 2)
    }

    @Test("Search is case insensitive")
    func caseInsensitiveSearch() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(name: "SwiftUI", type: .skill))
        #expect(graph.searchEntities(query: "swiftui").count == 1)
        #expect(graph.searchEntities(query: "SWIFTUI").count == 1)
    }

    @Test("Remove entity also removes edges")
    func removeEntity() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .concept))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .concept))
        graph.addRelationship(from: "a", to: "b", relationship: "related")
        #expect(graph.edgeCount == 1)
        graph.removeEntity("a")
        #expect(graph.entityCount == 1)
        #expect(graph.edgeCount == 0)
    }
}

@Suite("Knowledge Graph — Relationships")
struct KGRelationshipTests {
    @Test("Add relationship")
    func addRelationship() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .concept))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .concept))
        graph.addRelationship(from: "a", to: "b", relationship: "related_to")
        #expect(graph.relationships(for: "a").count == 1)
        #expect(graph.relationships(for: "b").count == 1) // bidirectional query
    }

    @Test("Relationship not added for missing entities")
    func missingEntity() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .concept))
        graph.addRelationship(from: "a", to: "missing", relationship: "related")
        #expect(graph.edgeCount == 0)
    }

    @Test("Outgoing vs incoming relationships")
    func directionality() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .person))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .person))
        graph.addRelationship(from: "a", to: "b", relationship: "mentors")
        #expect(graph.outgoingRelationships(for: "a").count == 1)
        #expect(graph.incomingRelationships(for: "a").isEmpty)
        #expect(graph.outgoingRelationships(for: "b").isEmpty)
        #expect(graph.incomingRelationships(for: "b").count == 1)
    }

    @Test("Multiple relationships between same entities")
    func multipleEdges() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .person))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .person))
        graph.addRelationship(from: "a", to: "b", relationship: "knows")
        graph.addRelationship(from: "a", to: "b", relationship: "works_with")
        #expect(graph.relationships(for: "a").count == 2)
    }
}

@Suite("Knowledge Graph — BFS Pathfinding")
struct KGPathfindingTests {
    @Test("Direct connection found")
    func directConnection() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .concept))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .concept))
        graph.addRelationship(from: "a", to: "b", relationship: "related")
        let path = graph.findConnection(from: "a", to: "b")
        #expect(path != nil)
        #expect(path!.count == 1)
    }

    @Test("Two-hop connection found")
    func twoHopConnection() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .concept))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .concept))
        graph.addEntity(TestKGEntity(id: "c", name: "C", type: .concept))
        graph.addRelationship(from: "a", to: "b", relationship: "r1")
        graph.addRelationship(from: "b", to: "c", relationship: "r2")
        let path = graph.findConnection(from: "a", to: "c")
        #expect(path != nil)
        #expect(path!.count == 2)
    }

    @Test("Same entity returns empty path")
    func sameEntity() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .concept))
        let path = graph.findConnection(from: "a", to: "a")
        #expect(path != nil)
        #expect(path!.isEmpty)
    }

    @Test("No connection returns nil")
    func noConnection() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .concept))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .concept))
        let path = graph.findConnection(from: "a", to: "b")
        #expect(path == nil)
    }

    @Test("Missing entity returns nil")
    func missingEntity() {
        let graph = TestKnowledgeGraph()
        #expect(graph.findConnection(from: "a", to: "b") == nil)
    }

    @Test("Max depth respected")
    func maxDepthRespected() {
        let graph = TestKnowledgeGraph()
        // Create chain: a → b → c → d → e → f (5 hops, max is 4)
        for ch in ["a", "b", "c", "d", "e", "f"] {
            graph.addEntity(TestKGEntity(id: ch, name: ch.uppercased(), type: .concept))
        }
        graph.addRelationship(from: "a", to: "b", relationship: "r")
        graph.addRelationship(from: "b", to: "c", relationship: "r")
        graph.addRelationship(from: "c", to: "d", relationship: "r")
        graph.addRelationship(from: "d", to: "e", relationship: "r")
        graph.addRelationship(from: "e", to: "f", relationship: "r")
        let path = graph.findConnection(from: "a", to: "f", maxDepth: 4)
        #expect(path == nil) // 5 hops exceeds maxDepth 4
    }

    @Test("Reverse edge traversal")
    func reverseEdge() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .concept))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .concept))
        graph.addRelationship(from: "b", to: "a", relationship: "r") // Only b→a
        let path = graph.findConnection(from: "a", to: "b") // Query a→b
        #expect(path != nil) // BFS traverses both directions
    }
}

@Suite("Knowledge Graph — Related Entities")
struct KGRelatedEntitiesTests {
    @Test("Related entities sorted by edge count")
    func sortedByEdgeCount() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "a", name: "A", type: .person))
        graph.addEntity(TestKGEntity(id: "b", name: "B", type: .person))
        graph.addEntity(TestKGEntity(id: "c", name: "C", type: .person))
        graph.addRelationship(from: "a", to: "b", relationship: "knows")
        graph.addRelationship(from: "a", to: "b", relationship: "works_with")
        graph.addRelationship(from: "a", to: "c", relationship: "knows")
        let related = graph.relatedEntities(to: "a")
        #expect(related.count == 2)
        #expect(related[0].entity.id == "b") // 2 edges
        #expect(related[1].entity.id == "c") // 1 edge
    }

    @Test("Limit respected")
    func limitRespected() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "center", name: "Center", type: .concept))
        for i in 0..<20 {
            let id = "node\(i)"
            graph.addEntity(TestKGEntity(id: id, name: "Node \(i)", type: .concept))
            graph.addRelationship(from: "center", to: id, relationship: "connected")
        }
        let related = graph.relatedEntities(to: "center", limit: 5)
        #expect(related.count == 5)
    }

    @Test("No relationships returns empty")
    func noRelationships() {
        let graph = TestKnowledgeGraph()
        graph.addEntity(TestKGEntity(id: "lonely", name: "Lonely", type: .concept))
        let related = graph.relatedEntities(to: "lonely")
        #expect(related.isEmpty)
    }
}
