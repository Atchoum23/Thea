// PersonalKnowledgeGraphTests.swift
// Tests for PersonalKnowledgeGraph — actor-based entity-relationship graph
//
// Tests cover: KGEntity init, KGEntityType, KGEdge, KGStatistics,
// addEntity/getEntity, search, relationships, BFS path finding,
// deduplication (addOrMergeEntity), decay, and query.

@testable import TheaCore
import XCTest

// MARK: - KGEntity Tests (pure value type)

final class KGEntityTests: XCTestCase {

    func testEntityInitSetsAllFields() {
        let entity = KGEntity(name: "Alice", type: .person)
        XCTAssertFalse(entity.id.isEmpty)
        XCTAssertEqual(entity.name, "Alice")
        XCTAssertEqual(entity.type, .person)
        XCTAssertEqual(entity.referenceCount, 1)
        XCTAssertTrue(entity.attributes.isEmpty)
    }

    func testEntityIDIncludesTypeAndName() {
        let entity = KGEntity(name: "Swift", type: .skill)
        // ID format: "{type}:{name_lowercased_with_underscores}"
        XCTAssertTrue(entity.id.hasPrefix("skill:"))
        XCTAssertTrue(entity.id.contains("swift"))
    }

    func testEntityIDNormalizesSpaces() {
        let entity = KGEntity(name: "Machine Learning", type: .skill)
        XCTAssertEqual(entity.id, "skill:machine_learning")
    }

    func testEntityWithAttributes() {
        let entity = KGEntity(name: "Bob", type: .person, attributes: ["role": "developer"])
        XCTAssertEqual(entity.attributes["role"], "developer")
    }

    func testEntityCodableRoundTrip() throws {
        let entity = KGEntity(name: "Paris", type: .place, attributes: ["country": "France"])
        let data = try JSONEncoder().encode(entity)
        let decoded = try JSONDecoder().decode(KGEntity.self, from: data)
        XCTAssertEqual(decoded.id, entity.id)
        XCTAssertEqual(decoded.name, entity.name)
        XCTAssertEqual(decoded.type, entity.type)
        XCTAssertEqual(decoded.attributes["country"], "France")
    }
}

// MARK: - KGEntityType Tests

final class KGEntityTypeTests: XCTestCase {

    func testAllTypesHaveRawValues() {
        for type_ in KGEntityType.allCases {
            XCTAssertFalse(type_.rawValue.isEmpty)
        }
    }

    func testKGEntityTypeCodable() throws {
        for type_ in KGEntityType.allCases {
            let data = try JSONEncoder().encode(type_)
            let decoded = try JSONDecoder().decode(KGEntityType.self, from: data)
            XCTAssertEqual(decoded, type_)
        }
    }
}

// MARK: - KGEdge Tests

final class KGEdgeTests: XCTestCase {

    func testKGEdgeInitFields() {
        let edge = KGEdge(
            sourceID: "person:alice",
            targetID: "project:thea",
            relationship: "works_on",
            confidence: 0.9,
            createdAt: Date(),
            lastReferencedAt: Date()
        )
        XCTAssertEqual(edge.sourceID, "person:alice")
        XCTAssertEqual(edge.targetID, "project:thea")
        XCTAssertEqual(edge.relationship, "works_on")
        XCTAssertEqual(edge.confidence, 0.9, accuracy: 0.001)
    }

    func testKGEdgeCodableRoundTrip() throws {
        let now = Date()
        let edge = KGEdge(
            sourceID: "person:alice",
            targetID: "project:thea",
            relationship: "works_on",
            confidence: 1.0,
            createdAt: now,
            lastReferencedAt: now
        )
        let data = try JSONEncoder().encode(edge)
        let decoded = try JSONDecoder().decode(KGEdge.self, from: data)
        XCTAssertEqual(decoded.sourceID, edge.sourceID)
        XCTAssertEqual(decoded.relationship, edge.relationship)
        XCTAssertEqual(decoded.confidence, edge.confidence, accuracy: 0.001)
    }
}

// MARK: - KGStatistics Tests

final class KGStatisticsTests: XCTestCase {

    func testStatisticsInit() {
        let stats = KGStatistics(
            entityCount: 10,
            edgeCount: 5,
            typeDistribution: [.person: 3, .project: 7],
            averageConnections: 1.0
        )
        XCTAssertEqual(stats.entityCount, 10)
        XCTAssertEqual(stats.edgeCount, 5)
        XCTAssertEqual(stats.typeDistribution[.person], 3)
        XCTAssertEqual(stats.averageConnections, 1.0, accuracy: 0.001)
    }

    func testStatisticsEmptyGraph() {
        let stats = KGStatistics(
            entityCount: 0,
            edgeCount: 0,
            typeDistribution: [:],
            averageConnections: 0.0
        )
        XCTAssertEqual(stats.entityCount, 0)
        XCTAssertEqual(stats.averageConnections, 0.0)
    }
}

// MARK: - PersonalKnowledgeGraph (actor) Tests

final class PersonalKnowledgeGraphTests: XCTestCase {

    // We create a fresh graph-like environment by testing via the shared singleton
    // using a unique name prefix to avoid cross-test contamination.

    private let graph = PersonalKnowledgeGraph.shared

    // MARK: - Entity CRUD

    func testAddAndGetEntity() async {
        let entity = KGEntity(name: "TestAddGetEntity_Alice", type: .person)
        await graph.addEntity(entity)
        let retrieved = await graph.getEntity(entity.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, entity.name)
    }

    func testGetEntityReturnsNilForMissingID() async {
        let result = await graph.getEntity("nonexistent:does_not_exist_xyz")
        XCTAssertNil(result)
    }

    func testAddEntityOverwritesExistingByID() async {
        var entity = KGEntity(name: "TestOverwrite_Bob", type: .person)
        await graph.addEntity(entity)

        entity.name = "TestOverwrite_Bobby"
        await graph.addEntity(entity)

        let retrieved = await graph.getEntity(entity.id)
        XCTAssertEqual(retrieved?.name, "TestOverwrite_Bobby")
    }

    // MARK: - Search

    func testSearchEntitiesByName() async {
        let entity = KGEntity(name: "TestSearch_UniqueProjectXYZ", type: .project)
        await graph.addEntity(entity)

        let results = await graph.searchEntities(query: "TestSearch_UniqueProjectXYZ")
        XCTAssertTrue(results.contains { $0.id == entity.id })
    }

    func testSearchEntitiesCaseInsensitive() async {
        let entity = KGEntity(name: "TestCaseInsensitive_SwiftLang", type: .skill)
        await graph.addEntity(entity)

        let results = await graph.searchEntities(query: "testcaseinsensitive_swiftlang")
        XCTAssertTrue(results.contains { $0.id == entity.id })
    }

    func testSearchEntitiesFilterByType() async {
        let personEntity = KGEntity(name: "TestTypeFilter_Charlie", type: .person)
        let skillEntity  = KGEntity(name: "TestTypeFilter_Charlie", type: .skill)
        await graph.addEntity(personEntity)
        await graph.addEntity(skillEntity)

        let personResults = await graph.searchEntities(query: "TestTypeFilter_Charlie", type: .person)
        XCTAssertTrue(personResults.allSatisfy { $0.type == .person })

        let skillResults = await graph.searchEntities(query: "TestTypeFilter_Charlie", type: .skill)
        XCTAssertTrue(skillResults.allSatisfy { $0.type == .skill })
    }

    func testSearchEntitiesNoMatch() async {
        let results = await graph.searchEntities(query: "ZZZ_NonExistentEntity_QWERTY_12345")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Relationships

    func testAddRelationshipRequiresBothEntities() async {
        // Adding relationship when only one entity exists should not create edge
        let entityA = KGEntity(name: "TestRelOneOnly_A", type: .person)
        await graph.addEntity(entityA)

        let edgesBefore = await graph.edgeCount
        await graph.addRelationship(from: entityA.id, to: "nonexistent:xyz", relationship: "knows")
        let edgesAfter = await graph.edgeCount
        // Edge count should be unchanged
        XCTAssertEqual(edgesAfter, edgesBefore)
    }

    func testAddRelationshipBetweenTwoEntities() async {
        let alice = KGEntity(name: "TestRel_Alice2", type: .person)
        let bob   = KGEntity(name: "TestRel_Bob2", type: .person)
        await graph.addEntity(alice)
        await graph.addEntity(bob)

        let edgesBefore = await graph.edgeCount
        await graph.addRelationship(from: alice.id, to: bob.id, relationship: "friends_with")
        let edgesAfter = await graph.edgeCount
        XCTAssertEqual(edgesAfter, edgesBefore + 1)
    }

    func testAddDuplicateRelationshipIsIgnored() async {
        let nodeA = KGEntity(name: "TestDupRel_A", type: .topic)
        let nodeB = KGEntity(name: "TestDupRel_B", type: .topic)
        await graph.addEntity(nodeA)
        await graph.addEntity(nodeB)

        await graph.addRelationship(from: nodeA.id, to: nodeB.id, relationship: "related_to")
        let edgesAfterFirst = await graph.edgeCount
        await graph.addRelationship(from: nodeA.id, to: nodeB.id, relationship: "related_to")
        let edgesAfterSecond = await graph.edgeCount
        // Duplicate should be rejected
        XCTAssertEqual(edgesAfterFirst, edgesAfterSecond)
    }

    func testRelationshipsForEntity() async {
        let src = KGEntity(name: "TestRelFor_Src", type: .project)
        let tgt = KGEntity(name: "TestRelFor_Tgt", type: .goal)
        await graph.addEntity(src)
        await graph.addEntity(tgt)
        await graph.addRelationship(from: src.id, to: tgt.id, relationship: "supports")

        let rels = await graph.relationships(for: src.id)
        XCTAssertTrue(rels.contains { $0.sourceID == src.id && $0.targetID == tgt.id })
    }

    func testRelationshipsForEntityNotFound() async {
        let rels = await graph.relationships(for: "nonexistent:totally_fake_id")
        XCTAssertTrue(rels.isEmpty)
    }

    // MARK: - BFS Path Finding

    func testFindConnectionDirectEdge() async {
        let a = KGEntity(name: "TestBFS_DirectA", type: .person)
        let b = KGEntity(name: "TestBFS_DirectB", type: .person)
        await graph.addEntity(a)
        await graph.addEntity(b)
        await graph.addRelationship(from: a.id, to: b.id, relationship: "knows")

        let path = await graph.findConnection(from: a.id, to: b.id)
        XCTAssertNotNil(path)
        XCTAssertEqual(path?.count, 1)
    }

    func testFindConnectionThroughIntermediary() async {
        let a = KGEntity(name: "TestBFS_A", type: .topic)
        let b = KGEntity(name: "TestBFS_B", type: .topic)
        let c = KGEntity(name: "TestBFS_C", type: .topic)
        await graph.addEntity(a)
        await graph.addEntity(b)
        await graph.addEntity(c)
        await graph.addRelationship(from: a.id, to: b.id, relationship: "links_to")
        await graph.addRelationship(from: b.id, to: c.id, relationship: "links_to")

        let path = await graph.findConnection(from: a.id, to: c.id)
        XCTAssertNotNil(path)
        XCTAssertEqual(path?.count, 2)
    }

    func testFindConnectionNoPath() async {
        let isolated1 = KGEntity(name: "TestBFS_Isolated1", type: .event)
        let isolated2 = KGEntity(name: "TestBFS_Isolated2", type: .event)
        await graph.addEntity(isolated1)
        await graph.addEntity(isolated2)
        // No edge between them
        let path = await graph.findConnection(from: isolated1.id, to: isolated2.id)
        XCTAssertNil(path)
    }

    func testFindConnectionMissingSourceEntity() async {
        let real = KGEntity(name: "TestBFS_Real", type: .topic)
        await graph.addEntity(real)
        let path = await graph.findConnection(from: "nonexistent:x", to: real.id)
        XCTAssertNil(path)
    }

    func testFindConnectionSameEntity() async {
        let entity = KGEntity(name: "TestBFS_Self", type: .habit)
        await graph.addEntity(entity)
        // BFS from X to X — since X is immediately the target neighbor check won't fire,
        // but X is added to visited immediately; the result depends on edges. No self-loop → nil.
        let path = await graph.findConnection(from: entity.id, to: entity.id)
        // Either nil or an empty array — just ensure no crash
        XCTAssertTrue(path == nil || path?.isEmpty == true)
    }

    // MARK: - Deduplication

    func testAddOrMergeEntityReturnsSameIDForDuplicate() async {
        let original = KGEntity(name: "TestMerge_Kotlin", type: .skill)
        await graph.addEntity(original)

        let duplicate = KGEntity(name: "TestMerge_Kotlin", type: .skill)
        let returnedID = await graph.addOrMergeEntity(duplicate)
        XCTAssertEqual(returnedID, original.id)
    }

    func testAddOrMergeEntityCreatesNewForDistinctType() async {
        let skill  = KGEntity(name: "TestMerge_Python", type: .skill)
        let person = KGEntity(name: "TestMerge_Python", type: .person)
        let id1 = await graph.addOrMergeEntity(skill)
        let id2 = await graph.addOrMergeEntity(person)
        XCTAssertNotEqual(id1, id2)
    }

    func testFindSimilarEntityExactMatch() async {
        let entity = KGEntity(name: "TestSimilar_Rust", type: .skill)
        await graph.addEntity(entity)

        let found = await graph.findSimilarEntity(name: "Rust", type: .skill)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, entity.id)
    }

    func testFindSimilarEntityPrefixMatch() async {
        let entity = KGEntity(name: "TestSimilar_John Smith", type: .person)
        await graph.addEntity(entity)

        // "John" is a prefix of "John Smith" — should match
        let found = await graph.findSimilarEntity(name: "TestSimilar_John", type: .person)
        XCTAssertNotNil(found)
    }

    func testFindSimilarEntityNoMatch() async {
        let found = await graph.findSimilarEntity(name: "ZZZ_NonexistentXYZ_999", type: .place)
        XCTAssertNil(found)
    }

    // MARK: - Decay

    func testDecayStaleEntitiesRemovesOldLowRefEntities() async {
        // Create an entity with a very old date and low referenceCount
        var stale = KGEntity(name: "TestDecay_Stale", type: .event)
        stale.lastUpdatedAt = Date(timeIntervalSinceNow: -100 * 86400) // 100 days ago
        // referenceCount is 1 by default (< 2 minimum)
        await graph.addEntity(stale)

        let countBefore = await graph.entityCount
        await graph.decayStaleEntities(daysThreshold: 90, minimumReferenceCount: 2)
        let countAfter = await graph.entityCount

        // Stale entity should have been removed
        XCTAssertLessThanOrEqual(countAfter, countBefore)
        let retrieved = await graph.getEntity(stale.id)
        XCTAssertNil(retrieved)
    }

    func testDecayDoesNotRemoveRecentEntities() async {
        let recent = KGEntity(name: "TestDecay_Recent", type: .event)
        // lastUpdatedAt defaults to Date() — very recent
        await graph.addEntity(recent)

        let countBefore = await graph.entityCount
        await graph.decayStaleEntities(daysThreshold: 90, minimumReferenceCount: 2)
        let countAfter = await graph.entityCount

        // Recent entity should still be there
        let retrieved = await graph.getEntity(recent.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(countAfter, countBefore)
    }

    // MARK: - Statistics

    func testStatisticsEntityCountMatchesAdded() async {
        let countBefore = await graph.entityCount

        let e1 = KGEntity(name: "TestStats_E1_\(UUID().uuidString)", type: .topic)
        let e2 = KGEntity(name: "TestStats_E2_\(UUID().uuidString)", type: .topic)
        await graph.addEntity(e1)
        await graph.addEntity(e2)

        let stats = await graph.statistics()
        XCTAssertEqual(stats.entityCount, countBefore + 2)
    }

    func testStatisticsTypeDistribution() async {
        let person = KGEntity(name: "TestStatsDist_Person_\(UUID().uuidString)", type: .person)
        await graph.addEntity(person)

        let stats = await graph.statistics()
        XCTAssertNotNil(stats.typeDistribution[.person])
        XCTAssertGreaterThanOrEqual(stats.typeDistribution[.person]!, 1)
    }

    func testStatisticsAverageConnectionsNonNegative() async {
        let stats = await graph.statistics()
        XCTAssertGreaterThanOrEqual(stats.averageConnections, 0.0)
    }

    // MARK: - recentEntities

    func testRecentEntitiesRespectsLimit() async {
        // Add a few entities to ensure we have at least some
        for i in 0..<5 {
            let e = KGEntity(name: "TestRecent_\(i)_\(UUID().uuidString)", type: .topic)
            await graph.addEntity(e)
        }
        let recent = await graph.recentEntities(limit: 3)
        XCTAssertLessThanOrEqual(recent.count, 3)
    }

    // MARK: - Query

    func testQueryNoMatchReturnsEmptyExplanation() async {
        let result = await graph.query("ZZZ_Nonexistent_XYZ_9999")
        XCTAssertEqual(result.entities.count, 0)
        XCTAssertFalse(result.explanation.isEmpty)
        XCTAssertTrue(result.explanation.contains("No matching entities found"))
    }

    func testQueryWithOneMatchReturnsEntity() async {
        let entity = KGEntity(name: "TestQuery_Thea", type: .project)
        await graph.addEntity(entity)

        let result = await graph.query("TestQuery_Thea")
        XCTAssertTrue(result.entities.contains { $0.id == entity.id })
        XCTAssertFalse(result.explanation.isEmpty)
    }

    // MARK: - extractAndStore

    func testExtractAndStoreUpdatesExistingEntityReferenceCount() async {
        let entity = KGEntity(name: "TestExtract_Alice", type: .person)
        await graph.addEntity(entity)
        let refBefore = await graph.getEntity(entity.id)?.referenceCount ?? 0

        await graph.extractAndStore(from: "TestExtract_Alice was here", context: "test")

        let refAfter = await graph.getEntity(entity.id)?.referenceCount ?? 0
        XCTAssertGreaterThan(refAfter, refBefore)
    }

    // MARK: - Save

    func testSaveDoesNotCrashWhenClean() async {
        // When isDirty is false, save() should return silently without error
        // We can't inspect isDirty directly (private), but calling save() must not throw
        await graph.save()
    }

    func testSavePersistsAfterAddEntity() async {
        let entity = KGEntity(name: "TestSave_\(UUID().uuidString)", type: .preference)
        await graph.addEntity(entity)
        // save() writes to disk; we just verify it doesn't crash
        await graph.save()
    }
}
