// PersonalKnowledgeGraphTests.swift
// Tests for PersonalKnowledgeGraph service logic: hybrid search (BM25), deduplication,
// statistics, entity extraction, and natural language query.

import Testing
import Foundation

// MARK: - Test Doubles (mirrors Shared/Memory/PersonalKnowledgeGraph.swift)

private enum PKGEntityType: String, Sendable, CaseIterable, Codable {
    case person, place, habit, goal, healthMetric, project, event, topic, skill, preference
}

private struct PKGEntity: Identifiable, Sendable, Codable {
    let id: String
    var name: String
    var type: PKGEntityType
    var attributes: [String: String]
    var createdAt: Date
    var lastUpdatedAt: Date
    var referenceCount: Int

    init(name: String, type: PKGEntityType, attributes: [String: String] = [:]) {
        self.id = "\(type.rawValue):\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
        self.name = name
        self.type = type
        self.attributes = attributes
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
        self.referenceCount = 1
    }
}

private struct PKGEdge: Sendable, Codable {
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
}

private struct PKGQueryResult: Sendable {
    let entities: [PKGEntity]
    let edges: [PKGEdge]
    let explanation: String
}

private struct PKGStatistics: Sendable {
    let entityCount: Int
    let edgeCount: Int
    let typeDistribution: [PKGEntityType: Int]
    let averageConnections: Double
}

private struct PKGSearchResult: Sendable {
    let entity: PKGEntity
    let score: Double
    let matchType: PKGMatchType
}

private enum PKGMatchType: String, Sendable {
    case keyword, semantic, hybrid
}

// MARK: - Graph Implementation (mirrors production logic)

private final class TestPersonalKnowledgeGraph: @unchecked Sendable {
    var entities: [String: PKGEntity] = [:]
    var edges: [PKGEdge] = []

    func addEntity(_ entity: PKGEntity) {
        entities[entity.id] = entity
    }

    func getEntity(_ id: String) -> PKGEntity? {
        entities[id]
    }

    func searchEntities(query: String, type: PKGEntityType? = nil) -> [PKGEntity] {
        let lower = query.lowercased()
        return entities.values.filter { entity in
            let nameMatch = entity.name.lowercased().contains(lower)
            let typeMatch = type == nil || entity.type == type
            return nameMatch && typeMatch
        }
    }

    func entities(ofType type: PKGEntityType) -> [PKGEntity] {
        entities.values.filter { $0.type == type }
    }

    func addRelationship(from sourceID: String, to targetID: String, relationship: String, confidence: Double = 1.0) {
        guard entities[sourceID] != nil, entities[targetID] != nil else { return }
        if edges.contains(where: { $0.sourceID == sourceID && $0.targetID == targetID && $0.relationship == relationship }) {
            return
        }
        edges.append(PKGEdge(sourceID: sourceID, targetID: targetID, relationship: relationship, confidence: confidence))
    }

    func relationships(for entityID: String) -> [PKGEdge] {
        edges.filter { $0.sourceID == entityID || $0.targetID == entityID }
    }

    func findConnection(from sourceID: String, to targetID: String) -> [PKGEdge]? {
        guard entities[sourceID] != nil, entities[targetID] != nil else { return nil }
        if sourceID == targetID { return [] }

        var visited: Set<String> = [sourceID]
        var queue: [(entityID: String, path: [PKGEdge])] = [(sourceID, [])]

        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()
            if path.count >= 4 { continue }

            let currentEdges = edges.filter { $0.sourceID == current || $0.targetID == current }
            for edge in currentEdges {
                let neighbor = edge.sourceID == current ? edge.targetID : edge.sourceID
                if neighbor == targetID { return path + [edge] }
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append((neighbor, path + [edge]))
                }
            }
        }
        return nil
    }

    func relatedEntities(to entityID: String, limit: Int = 10) -> [(entity: PKGEntity, edgeCount: Int)] {
        let related = relationships(for: entityID)
        var neighborCounts: [String: Int] = [:]
        for edge in related {
            let neighborID = edge.sourceID == entityID ? edge.targetID : edge.sourceID
            neighborCounts[neighborID, default: 0] += 1
        }
        return neighborCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { id, count in
                guard let entity = entities[id] else { return nil }
                return (entity: entity, edgeCount: count)
            }
    }

    func recentEntities(limit: Int = 20) -> [PKGEntity] {
        Array(entities.values.sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }.prefix(limit))
    }

    func query(_ naturalLanguageQuery: String) -> PKGQueryResult {
        let lower = naturalLanguageQuery.lowercased()
        let matchingEntities = entities.values.filter { lower.contains($0.name.lowercased()) }

        if matchingEntities.count >= 2 {
            let first = matchingEntities[0]
            let second = matchingEntities[1]
            if let path = findConnection(from: first.id, to: second.id) {
                return PKGQueryResult(
                    entities: Array(matchingEntities),
                    edges: path,
                    explanation: "Connection found: \(first.name) → \(second.name) via \(path.count) relationship(s)"
                )
            }
        }

        let relevantEdges = matchingEntities.flatMap { relationships(for: $0.id) }
        return PKGQueryResult(
            entities: Array(matchingEntities),
            edges: relevantEdges,
            explanation: matchingEntities.isEmpty
                ? "No matching entities found"
                : "Found \(matchingEntities.count) entity(ies) with \(relevantEdges.count) relationship(s)"
        )
    }

    func extractAndStore(from text: String) {
        let words = text.components(separatedBy: .whitespaces)
        for word in words where word.count > 2 {
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
            if let first = trimmed.first, first.isUppercase, trimmed.count > 2 {
                if let existing = entities.values.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
                    var updated = existing
                    updated.lastUpdatedAt = Date()
                    updated.referenceCount += 1
                    entities[updated.id] = updated
                }
            }
        }
    }

    // MARK: - Hybrid Search (BM25 + Graph)

    func hybridSearch(query: String, limit: Int = 10) -> [PKGSearchResult] {
        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty else { return [] }

        let k1 = 1.2
        let b = 0.75
        let allEntities = Array(entities.values)
        let avgDocLen = allEntities.isEmpty ? 1.0 : Double(allEntities.reduce(0) { $0 + documentLength($1) }) / Double(allEntities.count)
        let totalDocs = Double(allEntities.count)

        var results: [PKGSearchResult] = []

        for entity in allEntities {
            let docTerms = tokenize(entity.name + " " + entity.attributes.values.joined(separator: " "))
            let docLen = Double(docTerms.count)

            var bm25Score = 0.0
            for term in queryTerms {
                let tf = Double(docTerms.filter { $0 == term }.count)
                let docsContaining = Double(allEntities.filter { e in
                    tokenize(e.name + " " + e.attributes.values.joined(separator: " ")).contains(term)
                }.count)
                let idf = log((totalDocs - docsContaining + 0.5) / (docsContaining + 0.5) + 1.0)
                let tfNorm = (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (docLen / avgDocLen)))
                bm25Score += idf * tfNorm
            }

            let connectionCount = Double(relationships(for: entity.id).count)
            let connectivityScore = min(connectionCount / 10.0, 1.0)
            let daysSinceUpdate = Date().timeIntervalSince(entity.lastUpdatedAt) / 86400
            let recencyBoost = max(0, 1.0 - (daysSinceUpdate / 365.0))

            let combinedScore = bm25Score * 0.6 + connectivityScore * 0.2 + recencyBoost * 0.2

            if bm25Score > 0 || query.lowercased().contains(entity.name.lowercased()) {
                results.append(PKGSearchResult(
                    entity: entity,
                    score: combinedScore,
                    matchType: bm25Score > 0 ? .keyword : .semantic
                ))
            }
        }

        return Array(results.sorted { $0.score > $1.score }.prefix(limit))
    }

    // MARK: - Deduplication

    func deduplicateEntities(similarityThreshold: Double = 0.85) {
        let allEntities = Array(entities.values)
        var merged: Set<String> = []

        for outer in allEntities {
            guard !merged.contains(outer.id) else { continue }
            for inner in allEntities where outer.id != inner.id && !merged.contains(inner.id) {
                let similarity = jaccardSimilarity(
                    Set(tokenize(outer.name.lowercased())),
                    Set(tokenize(inner.name.lowercased()))
                )
                if similarity >= similarityThreshold && outer.type == inner.type {
                    let (keep, remove) = outer.referenceCount >= inner.referenceCount ? (outer, inner) : (inner, outer)
                    var updated = keep
                    updated.referenceCount += remove.referenceCount
                    for (key, value) in remove.attributes where updated.attributes[key] == nil {
                        updated.attributes[key] = value
                    }
                    entities[updated.id] = updated
                    entities.removeValue(forKey: remove.id)

                    edges = edges.map { edge in
                        var e = edge
                        if e.sourceID == remove.id {
                            e = PKGEdge(sourceID: keep.id, targetID: e.targetID, relationship: e.relationship, confidence: e.confidence)
                        }
                        if e.targetID == remove.id {
                            e = PKGEdge(sourceID: e.sourceID, targetID: keep.id, relationship: e.relationship, confidence: e.confidence)
                        }
                        return e
                    }
                    merged.insert(remove.id)
                }
            }
        }
    }

    // MARK: - Statistics

    func statistics() -> PKGStatistics {
        let typeDistribution = Dictionary(grouping: entities.values) { $0.type }.mapValues { $0.count }
        return PKGStatistics(
            entityCount: entities.count,
            edgeCount: edges.count,
            typeDistribution: typeDistribution,
            averageConnections: entities.isEmpty ? 0 : Double(edges.count * 2) / Double(entities.count)
        )
    }

    // MARK: - Helpers

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 }
    }

    private func documentLength(_ entity: PKGEntity) -> Int {
        tokenize(entity.name + " " + entity.attributes.values.joined(separator: " ")).count
    }

    private func jaccardSimilarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }
}

// MARK: - Tests: Entity ID Generation

@Suite("PersonalKnowledgeGraph — Entity ID Generation")
struct PKGEntityIDTests {
    @Test("Entity ID is deterministic from name and type")
    func deterministicID() {
        let e1 = PKGEntity(name: "Swift Programming", type: .skill)
        let e2 = PKGEntity(name: "Swift Programming", type: .skill)
        #expect(e1.id == e2.id)
    }

    @Test("Entity ID encodes type and normalized name")
    func idFormat() {
        let entity = PKGEntity(name: "Morning Run", type: .habit)
        #expect(entity.id == "habit:morning_run")
    }

    @Test("Different types produce different IDs for same name")
    func typeInID() {
        let skill = PKGEntity(name: "Swift", type: .skill)
        let topic = PKGEntity(name: "Swift", type: .topic)
        #expect(skill.id != topic.id)
    }
}

// MARK: - Tests: Natural Language Query

@Suite("PersonalKnowledgeGraph — Natural Language Query")
struct PKGNaturalLanguageQueryTests {
    @Test("Query finds entities mentioned by name")
    func findsByName() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Swift", type: .skill))
        graph.addEntity(PKGEntity(name: "Python", type: .skill))

        let result = graph.query("I want to learn Swift")
        #expect(result.entities.count == 1)
        #expect(result.entities[0].name == "Swift")
    }

    @Test("Query with no matching entities returns explanatory message")
    func noMatches() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Swift", type: .skill))

        let result = graph.query("Tell me about Rust")
        #expect(result.entities.isEmpty)
        #expect(result.explanation.contains("No matching"))
    }

    @Test("Query with two entities finds connection between them")
    func findsConnection() {
        let graph = TestPersonalKnowledgeGraph()
        let swift = PKGEntity(name: "Swift", type: .skill)
        let xcode = PKGEntity(name: "Xcode", type: .topic)
        graph.addEntity(swift)
        graph.addEntity(xcode)
        graph.addRelationship(from: swift.id, to: xcode.id, relationship: "used_in")

        let result = graph.query("How does Swift relate to Xcode?")
        #expect(result.explanation.contains("Connection found"))
        #expect(!result.edges.isEmpty)
    }

    @Test("Query with two unconnected entities returns both with no path")
    func unconnectedEntities() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Swift", type: .skill))
        graph.addEntity(PKGEntity(name: "Python", type: .skill))

        let result = graph.query("Compare Swift and Python")
        #expect(result.entities.count == 2)
        #expect(result.edges.isEmpty)
    }
}

// MARK: - Tests: Hybrid Search (BM25)

@Suite("PersonalKnowledgeGraph — Hybrid Search")
struct PKGHybridSearchTests {
    @Test("Empty query returns no results")
    func emptyQuery() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Swift", type: .skill))
        let results = graph.hybridSearch(query: "")
        #expect(results.isEmpty)
    }

    @Test("Search finds entity by keyword match")
    func keywordMatch() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Swift Programming", type: .skill, attributes: ["level": "advanced"]))
        graph.addEntity(PKGEntity(name: "Python Scripting", type: .skill))

        let results = graph.hybridSearch(query: "swift")
        #expect(!results.isEmpty)
        #expect(results[0].entity.name == "Swift Programming")
        #expect(results[0].matchType == .keyword)
    }

    @Test("Search ranks by BM25 relevance")
    func bm25Ranking() {
        let graph = TestPersonalKnowledgeGraph()
        // Entity with "swift" in both name and attributes should rank higher
        graph.addEntity(PKGEntity(name: "Swift", type: .skill, attributes: ["description": "Swift programming language"]))
        graph.addEntity(PKGEntity(name: "SwiftUI", type: .skill, attributes: ["description": "UI framework"]))

        let results = graph.hybridSearch(query: "swift")
        #expect(results.count == 2)
        // "Swift" should rank higher because it has "swift" in name AND attributes
        #expect(results[0].entity.name == "Swift")
    }

    @Test("Search respects limit parameter")
    func limitRespected() {
        let graph = TestPersonalKnowledgeGraph()
        for i in 0..<20 {
            graph.addEntity(PKGEntity(name: "Topic \(i)", type: .topic))
        }
        let results = graph.hybridSearch(query: "topic", limit: 5)
        #expect(results.count == 5)
    }

    @Test("Connected entities get connectivity boost")
    func connectivityBoost() {
        let graph = TestPersonalKnowledgeGraph()
        let connected = PKGEntity(name: "Hub Topic", type: .topic)
        let isolated = PKGEntity(name: "Hub Concept", type: .topic)
        graph.addEntity(connected)
        graph.addEntity(isolated)

        // Add many connections to first entity
        for i in 0..<10 {
            let neighbor = PKGEntity(name: "Related \(i)", type: .topic)
            graph.addEntity(neighbor)
            graph.addRelationship(from: connected.id, to: neighbor.id, relationship: "related")
        }

        let results = graph.hybridSearch(query: "hub")
        #expect(results.count == 2)
        // The highly-connected entity should rank higher
        #expect(results[0].entity.name == "Hub Topic")
    }

    @Test("Search matches attributes not just name")
    func attributeMatch() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Morning Habit", type: .habit, attributes: ["trigger": "coffee"]))

        let results = graph.hybridSearch(query: "coffee")
        #expect(!results.isEmpty)
        #expect(results[0].entity.name == "Morning Habit")
    }
}

// MARK: - Tests: Deduplication

@Suite("PersonalKnowledgeGraph — Deduplication")
struct PKGDeduplicationTests {
    @Test("Identical names of same type are merged")
    func identicalNamesMerged() {
        let graph = TestPersonalKnowledgeGraph()
        var e1 = PKGEntity(name: "Swift", type: .skill)
        e1.referenceCount = 5
        var e2 = PKGEntity(name: "Swift", type: .skill)
        e2.referenceCount = 3
        graph.addEntity(e1)
        graph.addEntity(e2)

        // With threshold 0.85, identical single-word names (Jaccard = 1.0) should merge
        graph.deduplicateEntities(similarityThreshold: 0.85)
        #expect(graph.entities.count == 1)
        // Survivor should have combined reference count
        let survivor = graph.entities.values.first!
        #expect(survivor.referenceCount == 8)
    }

    @Test("Different types are not merged")
    func differentTypesNotMerged() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Swift", type: .skill))
        graph.addEntity(PKGEntity(name: "Swift", type: .topic))

        graph.deduplicateEntities(similarityThreshold: 0.85)
        #expect(graph.entities.count == 2)
    }

    @Test("Dissimilar names are not merged")
    func dissimilarNotMerged() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Machine Learning", type: .skill))
        graph.addEntity(PKGEntity(name: "Web Development", type: .skill))

        graph.deduplicateEntities(similarityThreshold: 0.85)
        #expect(graph.entities.count == 2)
    }

    @Test("Edges are re-pointed after merge")
    func edgesRepointed() {
        let graph = TestPersonalKnowledgeGraph()
        var e1 = PKGEntity(name: "Swift", type: .skill)
        e1.referenceCount = 5
        let e2 = PKGEntity(name: "Swift", type: .skill) // referenceCount = 1
        let other = PKGEntity(name: "Xcode", type: .topic)
        graph.addEntity(e1)
        graph.addEntity(e2)
        graph.addEntity(other)
        graph.addRelationship(from: e2.id, to: other.id, relationship: "used_in")

        graph.deduplicateEntities(similarityThreshold: 0.85)
        // Edge should now point from survivor (e1) to other
        let edges = graph.edges
        #expect(edges.count == 1)
        #expect(edges[0].sourceID == e1.id || edges[0].targetID == e1.id)
    }

    @Test("Attributes are merged from removed entity")
    func attributesMerged() {
        let graph = TestPersonalKnowledgeGraph()
        var e1 = PKGEntity(name: "Swift", type: .skill, attributes: ["level": "advanced"])
        e1.referenceCount = 5
        let e2 = PKGEntity(name: "Swift", type: .skill, attributes: ["platform": "Apple"])
        graph.addEntity(e1)
        graph.addEntity(e2)

        graph.deduplicateEntities(similarityThreshold: 0.85)
        let survivor = graph.entities.values.first!
        #expect(survivor.attributes["level"] == "advanced")
        #expect(survivor.attributes["platform"] == "Apple")
    }
}

// MARK: - Tests: Statistics

@Suite("PersonalKnowledgeGraph — Statistics")
struct PKGStatisticsTests {
    @Test("Empty graph statistics")
    func emptyStats() {
        let graph = TestPersonalKnowledgeGraph()
        let stats = graph.statistics()
        #expect(stats.entityCount == 0)
        #expect(stats.edgeCount == 0)
        #expect(stats.averageConnections == 0)
        #expect(stats.typeDistribution.isEmpty)
    }

    @Test("Statistics reflect graph state")
    func accurateStats() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Swift", type: .skill))
        graph.addEntity(PKGEntity(name: "Python", type: .skill))
        graph.addEntity(PKGEntity(name: "Alexis", type: .person))
        let swift = graph.entities.values.first { $0.name == "Swift" }!
        let python = graph.entities.values.first { $0.name == "Python" }!
        graph.addRelationship(from: swift.id, to: python.id, relationship: "alternative")

        let stats = graph.statistics()
        #expect(stats.entityCount == 3)
        #expect(stats.edgeCount == 1)
        #expect(stats.typeDistribution[.skill] == 2)
        #expect(stats.typeDistribution[.person] == 1)
        // averageConnections = (1 * 2) / 3
        #expect(abs(stats.averageConnections - 2.0 / 3.0) < 0.001)
    }
}

// MARK: - Tests: Entity Extraction

@Suite("PersonalKnowledgeGraph — Entity Extraction")
struct PKGEntityExtractionTests {
    @Test("Extract and store updates existing entity reference count")
    func updatesReferenceCount() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "Swift", type: .skill))
        let initialRef = graph.entities.values.first!.referenceCount
        #expect(initialRef == 1)

        graph.extractAndStore(from: "I was working on Swift today")
        let updatedRef = graph.entities.values.first!.referenceCount
        #expect(updatedRef == 2)
    }

    @Test("Extract ignores lowercase words")
    func ignoresLowercase() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "swift", type: .skill))

        // "the" and "is" are short and lowercase — should not match
        graph.extractAndStore(from: "the language is great")
        // "swift" entity won't be matched because words in text that are capitalized are checked
        let ref = graph.entities.values.first!.referenceCount
        #expect(ref == 1) // unchanged
    }

    @Test("Extract ignores very short words")
    func ignoresShortWords() {
        let graph = TestPersonalKnowledgeGraph()
        graph.addEntity(PKGEntity(name: "AI", type: .topic))

        graph.extractAndStore(from: "AI is amazing")
        // "AI" is only 2 chars, trimmed word must be > 2
        let ref = graph.entities.values.first!.referenceCount
        #expect(ref == 1) // unchanged because "AI" is too short
    }
}

// MARK: - Tests: Duplicate Relationship Prevention

@Suite("PersonalKnowledgeGraph — Relationship Dedup")
struct PKGRelationshipDedupTests {
    @Test("Duplicate relationship is not added")
    func noDuplicateEdge() {
        let graph = TestPersonalKnowledgeGraph()
        let a = PKGEntity(name: "Alpha", type: .topic)
        let b = PKGEntity(name: "Beta", type: .topic)
        graph.addEntity(a)
        graph.addEntity(b)

        graph.addRelationship(from: a.id, to: b.id, relationship: "related")
        graph.addRelationship(from: a.id, to: b.id, relationship: "related") // duplicate
        #expect(graph.edges.count == 1)
    }

    @Test("Different relationship types between same entities are allowed")
    func differentRelTypes() {
        let graph = TestPersonalKnowledgeGraph()
        let a = PKGEntity(name: "Alpha", type: .topic)
        let b = PKGEntity(name: "Beta", type: .topic)
        graph.addEntity(a)
        graph.addEntity(b)

        graph.addRelationship(from: a.id, to: b.id, relationship: "related")
        graph.addRelationship(from: a.id, to: b.id, relationship: "similar_to")
        #expect(graph.edges.count == 2)
    }
}

// MARK: - Tests: Recent Entities

@Suite("PersonalKnowledgeGraph — Recent Entities")
struct PKGRecentEntitiesTests {
    @Test("Recent entities are sorted by lastUpdatedAt descending")
    func sortedByRecency() {
        let graph = TestPersonalKnowledgeGraph()
        var old = PKGEntity(name: "Old", type: .topic)
        old.lastUpdatedAt = Date().addingTimeInterval(-3600)
        var recent = PKGEntity(name: "Recent", type: .topic)
        recent.lastUpdatedAt = Date()
        graph.addEntity(old)
        graph.addEntity(recent)

        let results = graph.recentEntities(limit: 10)
        #expect(results.count == 2)
        #expect(results[0].name == "Recent")
    }

    @Test("Recent entities respects limit")
    func limitRespected() {
        let graph = TestPersonalKnowledgeGraph()
        for i in 0..<30 {
            graph.addEntity(PKGEntity(name: "Entity \(i)", type: .topic))
        }
        let results = graph.recentEntities(limit: 5)
        #expect(results.count == 5)
    }
}
