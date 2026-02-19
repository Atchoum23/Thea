// PersonalKnowledgeGraph.swift
// Thea — Graph-Based Personal Knowledge Layer
//
// Stores entity-relationship triples alongside the flat memory system.
// Enables reasoning about connections: "How does X relate to Y?"
// Fully on-device with SQLite-backed persistence.

import Foundation
import OSLog

// MARK: - Personal Knowledge Graph

actor PersonalKnowledgeGraph {
    static let shared = PersonalKnowledgeGraph()

    private let logger = Logger(subsystem: "com.thea.app", category: "KnowledgeGraph")

    /// In-memory graph (persisted to file periodically)
    private var entities: [String: KGEntity] = [:]
    private var edges: [KGEdge] = []
    private var isDirty = false

    private let storageURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea", isDirectory: true)
            .appendingPathComponent("KnowledgeGraph", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Logger(subsystem: "ai.thea.app", category: "PersonalKnowledgeGraph").error("Failed to create KG directory: \(error.localizedDescription)")
        }
        return dir.appendingPathComponent("graph.json")
    }()

    private init() {
        Task { await loadFromDisk() }
    }

    // MARK: - Entity Management

    /// Add or update an entity in the graph
    func addEntity(_ entity: KGEntity) {
        entities[entity.id] = entity
        isDirty = true
    }

    /// Get an entity by ID
    func getEntity(_ id: String) -> KGEntity? {
        entities[id]
    }

    /// Search entities by name (case-insensitive)
    func searchEntities(query: String, type: KGEntityType? = nil) -> [KGEntity] {
        let lower = query.lowercased()
        return entities.values.filter { entity in
            let nameMatch = entity.name.lowercased().contains(lower)
            let typeMatch = type == nil || entity.type == type
            return nameMatch && typeMatch
        }
    }

    /// Get all entities of a specific type
    // periphery:ignore - Reserved: entities(ofType:) instance method — reserved for future feature activation
    func entities(ofType type: KGEntityType) -> [KGEntity] {
        entities.values.filter { $0.type == type }
    }

    // MARK: - Relationship Management

    /// Add a relationship between two entities
    // periphery:ignore - Reserved: addRelationship(from:to:relationship:confidence:) instance method — reserved for future feature activation
    func addRelationship(from sourceID: String, to targetID: String, relationship: String, confidence: Double = 1.0) {
        // Ensure both entities exist
        // periphery:ignore - Reserved: entities(ofType:) instance method reserved for future feature activation
        guard entities[sourceID] != nil, entities[targetID] != nil else {
            logger.warning("Cannot add relationship: entity not found")
            return
        }

        // Check for duplicate
        // periphery:ignore - Reserved: addRelationship(from:to:relationship:confidence:) instance method reserved for future feature activation
        if edges.contains(where: { $0.sourceID == sourceID && $0.targetID == targetID && $0.relationship == relationship }) {
            return
        }

        let edge = KGEdge(
            sourceID: sourceID,
            targetID: targetID,
            relationship: relationship,
            confidence: confidence,
            createdAt: Date(),
            lastReferencedAt: Date()
        )
        edges.append(edge)
        isDirty = true
    }

    /// Get all relationships for an entity
    func relationships(for entityID: String) -> [KGEdge] {
        edges.filter { $0.sourceID == entityID || $0.targetID == entityID }
    }

    /// Find the path between two entities (BFS, max depth 4)
    func findConnection(from sourceID: String, to targetID: String) -> [KGEdge]? {
        guard entities[sourceID] != nil, entities[targetID] != nil else { return nil }

        var visited: Set<String> = [sourceID]
        var queue: [(entityID: String, path: [KGEdge])] = [(sourceID, [])]

        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()

            if path.count >= 4 { continue } // Max depth

            let currentEdges = edges.filter { $0.sourceID == current || $0.targetID == current }

            for edge in currentEdges {
                let neighbor = edge.sourceID == current ? edge.targetID : edge.sourceID

                if neighbor == targetID {
                    return path + [edge]
                }

                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append((neighbor, path + [edge]))
                }
            }
        }

        return nil
    }

    // MARK: - Querying

    /// Get entities most connected to a given entity
    // periphery:ignore - Reserved: relatedEntities(to:limit:) instance method — reserved for future feature activation
    func relatedEntities(to entityID: String, limit: Int = 10) -> [(entity: KGEntity, edgeCount: Int)] {
        let related = relationships(for: entityID)
        var neighborCounts: [String: Int] = [:]

        for edge in related {
            let neighborID = edge.sourceID == entityID ? edge.targetID : edge.sourceID
            neighborCounts[neighborID, default: 0] += 1
        // periphery:ignore - Reserved: relatedEntities(to:limit:) instance method reserved for future feature activation
        }

        return neighborCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { id, count in
                guard let entity = entities[id] else { return nil }
                return (entity: entity, edgeCount: count)
            }
    }

    /// Get the most recent entities
    func recentEntities(limit: Int = 20) -> [KGEntity] {
        Array(
            entities.values
                .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
                .prefix(limit)
        )
    }

    /// Natural language query: extract entities and relationships
    func query(_ naturalLanguageQuery: String) -> KGQueryResult {
        let lower = naturalLanguageQuery.lowercased()

        // Simple entity extraction from query
        let matchingEntities = entities.values.filter { entity in
            lower.contains(entity.name.lowercased())
        }

        // If we found two entities, look for connections
        if matchingEntities.count >= 2 {
            let first = matchingEntities[0]
            let second = matchingEntities[1]
            if let path = findConnection(from: first.id, to: second.id) {
                return KGQueryResult(
                    entities: Array(matchingEntities),
                    edges: path,
                    explanation: "Connection found: \(first.name) → \(second.name) via \(path.count) relationship(s)"
                )
            }
        }

        // Return matching entities with their relationships
        let relevantEdges = matchingEntities.flatMap { relationships(for: $0.id) }
        return KGQueryResult(
            entities: Array(matchingEntities),
            edges: relevantEdges,
            explanation: matchingEntities.isEmpty
                ? "No matching entities found"
                : "Found \(matchingEntities.count) entity(ies) with \(relevantEdges.count) relationship(s)"
        )
    }

    // MARK: - Extraction from Conversations

    /// Extract entities and relationships from a conversation message
    // periphery:ignore - Reserved: extractAndStore(from:context:) instance method — reserved for future feature activation
    func extractAndStore(from text: String, context: String = "") {
        // Simple NER: look for capitalized words as potential entity names
        let words = text.components(separatedBy: .whitespaces)
        var potentialEntities: [String] = []

        for word in words where word.count > 2 {
            // periphery:ignore - Reserved: extractAndStore(from:context:) instance method reserved for future feature activation
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
            if let first = trimmed.first, first.isUppercase, trimmed.count > 2 {
                potentialEntities.append(trimmed)
            }
        }

        // Match against existing entities and update lastReferenced
        for name in potentialEntities {
            if let existing = entities.values.first(where: { $0.name.lowercased() == name.lowercased() }) {
                var updated = existing
                updated.lastUpdatedAt = Date()
                updated.referenceCount += 1
                entities[updated.id] = updated
                isDirty = true
            }
        }
    }

    // MARK: - Entity Deduplication

    /// Find an existing entity that is sufficiently similar to avoid duplicates.
    /// Returns the existing entity's ID if found, otherwise nil.
    // periphery:ignore - Reserved: findSimilarEntity(name:type:) instance method — reserved for future feature activation
    func findSimilarEntity(name: String, type: KGEntityType) -> KGEntity? {
        let normalizedNew = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return entities.values.first { existing in
            guard existing.type == type else { return false }
            let normalizedExisting = existing.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            // periphery:ignore - Reserved: findSimilarEntity(name:type:) instance method reserved for future feature activation
            // Exact match after normalization
            if normalizedExisting == normalizedNew { return true }
            // Substring match for longer names (handles "John" vs "John Smith")
            if normalizedNew.count > 3 && normalizedExisting.hasPrefix(normalizedNew) { return true }
            if normalizedExisting.count > 3 && normalizedNew.hasPrefix(normalizedExisting) { return true }
            return false
        }
    }

    /// Add entity with deduplication: if a similar entity exists, update it instead of creating duplicate.
    /// Returns the entity ID (existing or new).
    // periphery:ignore - Reserved: addOrMergeEntity(_:) instance method — reserved for future feature activation
    @discardableResult
    func addOrMergeEntity(_ entity: KGEntity) -> String {
        if let existing = findSimilarEntity(name: entity.name, type: entity.type) {
            // Merge: update lastUpdated and increment referenceCount
            var merged = existing
            // periphery:ignore - Reserved: addOrMergeEntity(_:) instance method reserved for future feature activation
            merged.lastUpdatedAt = Date()
            merged.referenceCount += 1
            for (key, value) in entity.attributes {
                merged.attributes[key] = value
            }
            entities[merged.id] = merged
            isDirty = true
            return merged.id
        } else {
            addEntity(entity)
            return entity.id
        }
    }

    // MARK: - Importance Decay (P3)

    /// Decay importance of entities older than 90 days with no recent activity.
    /// Entities with referenceCount < 2 and lastUpdated > 90 days are pruned.
    // periphery:ignore - Reserved: decayStaleEntities(daysThreshold:minimumReferenceCount:) instance method — reserved for future feature activation
    func decayStaleEntities(daysThreshold: Int = 90, minimumReferenceCount: Int = 2) {
        let cutoffDate = Date().addingTimeInterval(-Double(daysThreshold) * 86400)
        var removedIDs: Set<String> = []

// periphery:ignore - Reserved: decayStaleEntities(daysThreshold:minimumReferenceCount:) instance method reserved for future feature activation

        for (id, entity) in entities {
            if entity.lastUpdatedAt < cutoffDate && entity.referenceCount < minimumReferenceCount {
                removedIDs.insert(id)
                logger.debug("Decaying stale entity: \(entity.name) (last updated: \(entity.lastUpdatedAt))")
            }
        }

        if !removedIDs.isEmpty {
            removedIDs.forEach { entities.removeValue(forKey: $0) }
            edges.removeAll { removedIDs.contains($0.sourceID) || removedIDs.contains($0.targetID) }
            isDirty = true
            logger.info("Decayed \(removedIDs.count) stale entities (inactive >\(daysThreshold) days, <\(minimumReferenceCount) references)")
        }
    }

    // MARK: - Statistics

    // periphery:ignore - Reserved: entityCount property — reserved for future feature activation
    var entityCount: Int { entities.count }
    // periphery:ignore - Reserved: edgeCount property — reserved for future feature activation
    var edgeCount: Int { edges.count }

// periphery:ignore - Reserved: entityCount property reserved for future feature activation

// periphery:ignore - Reserved: edgeCount property reserved for future feature activation

    func statistics() -> KGStatistics {
        let typeDistribution = Dictionary(grouping: entities.values) { $0.type }
            .mapValues { $0.count }

        return KGStatistics(
            entityCount: entities.count,
            edgeCount: edges.count,
            typeDistribution: typeDistribution,
            averageConnections: entities.isEmpty ? 0 : Double(edges.count * 2) / Double(entities.count)
        )
    }

    // MARK: - Persistence

    func save() {
        guard isDirty else { return }

        let data = KGSerializedGraph(
            entities: Array(entities.values),
            edges: edges
        )

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: storageURL, options: .atomic)
            isDirty = false
            logger.debug("Knowledge graph saved: \(self.entities.count) entities, \(self.edges.count) edges")
        } catch {
            logger.error("Failed to save knowledge graph: \(error.localizedDescription)")
        }
    }

    /// Load persisted graph from disk (called by orchestrator on startup)
    // periphery:ignore - Reserved: load() instance method reserved for future feature activation
    func load() {
        loadFromDisk()
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let data = try Data(contentsOf: storageURL)
            let graph = try JSONDecoder().decode(KGSerializedGraph.self, from: data)
            for entity in graph.entities {
                entities[entity.id] = entity
            }
            edges = graph.edges
            logger.info("Knowledge graph loaded: \(self.entities.count) entities, \(self.edges.count) edges")
        } catch {
            logger.error("Failed to load knowledge graph: \(error.localizedDescription)")
        }
    }
}

// MARK: - Types

struct KGEntity: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    var type: KGEntityType
    var attributes: [String: String]
    var createdAt: Date
    var lastUpdatedAt: Date
    var referenceCount: Int

    init(name: String, type: KGEntityType, attributes: [String: String] = [:]) {
        self.id = "\(type.rawValue):\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
        self.name = name
        self.type = type
        self.attributes = attributes
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
        self.referenceCount = 1
    }
}

enum KGEntityType: String, Codable, Sendable, CaseIterable {
    case person
    case place
    case habit
    case goal
    case healthMetric
    case project
    case event
    case topic
    case skill
    case preference
}

struct KGEdge: Codable, Sendable {
    let sourceID: String
    let targetID: String
    let relationship: String
    let confidence: Double
    let createdAt: Date
    var lastReferencedAt: Date
}

struct KGQueryResult: Sendable {
    let entities: [KGEntity]
    let edges: [KGEdge]
    let explanation: String
}

struct KGStatistics: Sendable {
    let entityCount: Int
    let edgeCount: Int
    let typeDistribution: [KGEntityType: Int]
    let averageConnections: Double
}

private struct KGSerializedGraph: Codable {
    let entities: [KGEntity]
    let edges: [KGEdge]
}
