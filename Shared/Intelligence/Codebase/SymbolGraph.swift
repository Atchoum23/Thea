// SymbolGraph.swift
// Thea V2
//
// Code relationship graph for understanding dependencies and references
// Enables Cursor-level "find all references" and dependency tracking

import Foundation
import OSLog

// MARK: - Symbol Node

/// A node in the symbol graph representing a code symbol
public struct SymbolNode: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let fullyQualifiedName: String
    public let kind: SymbolKind
    public let filePath: String
    public let line: Int
    public let column: Int
    public let language: ProgrammingLanguage
    public var documentation: String?
    public var signature: String?
    public var visibility: SymbolVisibility
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        fullyQualifiedName: String,
        kind: SymbolKind,
        filePath: String,
        line: Int,
        column: Int = 0,
        language: ProgrammingLanguage,
        documentation: String? = nil,
        signature: String? = nil,
        visibility: SymbolVisibility = .internal_,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fullyQualifiedName = fullyQualifiedName
        self.kind = kind
        self.filePath = filePath
        self.line = line
        self.column = column
        self.language = language
        self.documentation = documentation
        self.signature = signature
        self.visibility = visibility
        self.createdAt = createdAt
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: SymbolNode, rhs: SymbolNode) -> Bool {
        lhs.id == rhs.id
    }
}

/// Kind of symbol in the graph
public enum SymbolKind: String, Codable, Sendable, CaseIterable {
    case module
    case namespace
    case package
    case class_
    case struct_
    case enum_
    case protocol_
    case interface
    case trait
    case extension_
    case function
    case method
    case property
    case variable
    case constant
    case parameter
    case typeAlias
    case genericParameter
    case import_
    case file
    case unknown

    public var displayName: String {
        switch self {
        case .class_: return "Class"
        case .struct_: return "Struct"
        case .enum_: return "Enum"
        case .protocol_: return "Protocol"
        case .extension_: return "Extension"
        case .import_: return "Import"
        default: return rawValue.capitalized
        }
    }

    public var icon: String {
        switch self {
        case .class_: return "c.square"
        case .struct_: return "s.square"
        case .enum_: return "e.square"
        case .protocol_: return "p.square"
        case .function, .method: return "f.square"
        case .property, .variable: return "v.square"
        case .constant: return "k.square"
        default: return "doc.text"
        }
    }
}

/// Visibility of a symbol
public enum SymbolVisibility: String, Codable, Sendable {
    case public_
    case internal_
    case fileprivate_
    case private_
    case open_
    case unknown

    public var displayName: String {
        switch self {
        case .public_: return "public"
        case .internal_: return "internal"
        case .fileprivate_: return "fileprivate"
        case .private_: return "private"
        case .open_: return "open"
        case .unknown: return "unknown"
        }
    }
}

// MARK: - Symbol Edge

/// An edge in the symbol graph representing a relationship
public struct SymbolEdge: Identifiable, Codable, Sendable {
    public let id: UUID
    public let sourceId: UUID
    public let targetId: UUID
    public let kind: EdgeKind
    public let filePath: String?
    public let line: Int?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sourceId: UUID,
        targetId: UUID,
        kind: EdgeKind,
        filePath: String? = nil,
        line: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.kind = kind
        self.filePath = filePath
        self.line = line
        self.createdAt = createdAt
    }
}

/// Kind of relationship between symbols
public enum EdgeKind: String, Codable, Sendable, CaseIterable {
    case inherits          // class A: B
    case implements        // class A: Protocol
    case conforms          // struct A: Protocol
    case extends           // extension A
    case contains          // class contains method
    case calls             // function calls another
    case references        // uses a type
    case imports           // imports module
    case overrides         // overrides parent method
    case returns           // function returns type
    case parameterType     // function parameter type
    case propertyType      // property type
    case genericConstraint // generic where clause
    case associatedType    // protocol associated type

    public var displayName: String {
        switch self {
        case .inherits: return "inherits from"
        case .implements: return "implements"
        case .conforms: return "conforms to"
        case .extends: return "extends"
        case .contains: return "contains"
        case .calls: return "calls"
        case .references: return "references"
        case .imports: return "imports"
        case .overrides: return "overrides"
        case .returns: return "returns"
        case .parameterType: return "has parameter of type"
        case .propertyType: return "has property of type"
        case .genericConstraint: return "constrained to"
        case .associatedType: return "has associated type"
        }
    }
}

// MARK: - Graph Statistics

/// Statistics about the symbol graph
public struct GraphStatistics: Sendable {
    public let totalNodes: Int
    public let totalEdges: Int
    public let nodesByKind: [SymbolKind: Int]
    public let edgesByKind: [EdgeKind: Int]
    public let averageConnections: Double
    public let maxConnections: Int
    public let isolatedNodes: Int
}

// MARK: - Symbol Graph

/// In-memory symbol graph for code navigation and understanding
@MainActor
public final class SymbolGraph: ObservableObject {

    // MARK: - Singleton

    public static let shared = SymbolGraph()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.thea.v2", category: "SymbolGraph")

    /// All nodes in the graph
    private var nodes: [UUID: SymbolNode] = [:]

    /// All edges in the graph
    private var edges: [UUID: SymbolEdge] = [:]

    /// Name to node IDs mapping (for fast lookup)
    private var nameIndex: [String: Set<UUID>] = [:]

    /// Fully qualified name to node ID (unique)
    private var fqnIndex: [String: UUID] = [:]

    /// File path to node IDs
    private var fileIndex: [String: Set<UUID>] = [:]

    /// Outgoing edges by source node
    private var outgoingEdges: [UUID: Set<UUID>] = [:]

    /// Incoming edges by target node
    private var incomingEdges: [UUID: Set<UUID>] = [:]

    /// Graph state
    @Published public private(set) var statistics: GraphStatistics?

    // MARK: - Initialization

    private init() {
        logger.info("SymbolGraph initialized")
    }

    // MARK: - Node Operations

    /// Add a symbol node to the graph
    public func addNode(_ node: SymbolNode) {
        nodes[node.id] = node

        // Update name index
        if nameIndex[node.name] == nil {
            nameIndex[node.name] = []
        }
        nameIndex[node.name]?.insert(node.id)

        // Update FQN index
        fqnIndex[node.fullyQualifiedName] = node.id

        // Update file index
        if fileIndex[node.filePath] == nil {
            fileIndex[node.filePath] = []
        }
        fileIndex[node.filePath]?.insert(node.id)
    }

    /// Remove a node and all its edges
    public func removeNode(_ nodeId: UUID) {
        guard let node = nodes[nodeId] else { return }

        // Remove from indices
        nameIndex[node.name]?.remove(nodeId)
        fqnIndex.removeValue(forKey: node.fullyQualifiedName)
        fileIndex[node.filePath]?.remove(nodeId)

        // Remove outgoing edges
        if let outgoing = outgoingEdges[nodeId] {
            for edgeId in outgoing {
                if let edge = edges[edgeId] {
                    incomingEdges[edge.targetId]?.remove(edgeId)
                }
                edges.removeValue(forKey: edgeId)
            }
            outgoingEdges.removeValue(forKey: nodeId)
        }

        // Remove incoming edges
        if let incoming = incomingEdges[nodeId] {
            for edgeId in incoming {
                if let edge = edges[edgeId] {
                    outgoingEdges[edge.sourceId]?.remove(edgeId)
                }
                edges.removeValue(forKey: edgeId)
            }
            incomingEdges.removeValue(forKey: nodeId)
        }

        nodes.removeValue(forKey: nodeId)
    }

    /// Get a node by ID
    public func getNode(_ nodeId: UUID) -> SymbolNode? {
        nodes[nodeId]
    }

    /// Find nodes by name
    public func findNodes(named name: String) -> [SymbolNode] {
        guard let nodeIds = nameIndex[name] else { return [] }
        return nodeIds.compactMap { nodes[$0] }
    }

    /// Find node by fully qualified name
    public func findNode(fqn: String) -> SymbolNode? {
        guard let nodeId = fqnIndex[fqn] else { return nil }
        return nodes[nodeId]
    }

    /// Get all nodes in a file
    public func getNodes(inFile filePath: String) -> [SymbolNode] {
        guard let nodeIds = fileIndex[filePath] else { return [] }
        return nodeIds.compactMap { nodes[$0] }.sorted { $0.line < $1.line }
    }

    /// Search nodes by name pattern
    public func searchNodes(pattern: String, kinds: [SymbolKind]? = nil, limit: Int = 50) -> [SymbolNode] {
        let patternLower = pattern.lowercased()
        var results: [SymbolNode] = []

        for node in nodes.values {
            // Filter by kind if specified
            if let kinds = kinds, !kinds.contains(node.kind) {
                continue
            }

            // Match by name
            if node.name.lowercased().contains(patternLower) ||
               node.fullyQualifiedName.lowercased().contains(patternLower) {
                results.append(node)

                if results.count >= limit {
                    break
                }
            }
        }

        return results.sorted { $0.name < $1.name }
    }

    // MARK: - Edge Operations

    /// Add an edge to the graph
    public func addEdge(_ edge: SymbolEdge) {
        edges[edge.id] = edge

        // Update outgoing edges
        if outgoingEdges[edge.sourceId] == nil {
            outgoingEdges[edge.sourceId] = []
        }
        outgoingEdges[edge.sourceId]?.insert(edge.id)

        // Update incoming edges
        if incomingEdges[edge.targetId] == nil {
            incomingEdges[edge.targetId] = []
        }
        incomingEdges[edge.targetId]?.insert(edge.id)
    }

    /// Create an edge between two nodes
    public func connect(
        source sourceId: UUID,
        target targetId: UUID,
        kind: EdgeKind,
        filePath: String? = nil,
        line: Int? = nil
    ) {
        let edge = SymbolEdge(
            sourceId: sourceId,
            targetId: targetId,
            kind: kind,
            filePath: filePath,
            line: line
        )
        addEdge(edge)
    }

    /// Get outgoing edges from a node
    public func getOutgoingEdges(from nodeId: UUID) -> [SymbolEdge] {
        guard let edgeIds = outgoingEdges[nodeId] else { return [] }
        return edgeIds.compactMap { edges[$0] }
    }

    /// Get incoming edges to a node
    public func getIncomingEdges(to nodeId: UUID) -> [SymbolEdge] {
        guard let edgeIds = incomingEdges[nodeId] else { return [] }
        return edgeIds.compactMap { edges[$0] }
    }

    /// Get all connected nodes (both directions)
    public func getConnectedNodes(for nodeId: UUID) -> [SymbolNode] {
        var connectedIds: Set<UUID> = []

        // Outgoing connections
        for edge in getOutgoingEdges(from: nodeId) {
            connectedIds.insert(edge.targetId)
        }

        // Incoming connections
        for edge in getIncomingEdges(to: nodeId) {
            connectedIds.insert(edge.sourceId)
        }

        return connectedIds.compactMap { nodes[$0] }
    }

    // MARK: - Graph Queries

    /// Find all references to a symbol
    public func findAllReferences(to nodeId: UUID) -> [(SymbolNode, SymbolEdge)] {
        let incoming = getIncomingEdges(to: nodeId)
        return incoming.compactMap { edge in
            guard let sourceNode = nodes[edge.sourceId] else { return nil }
            return (sourceNode, edge)
        }
    }

    /// Find all usages (calls, references) of a symbol
    public func findUsages(of nodeId: UUID) -> [(SymbolNode, SymbolEdge)] {
        let usageKinds: Set<EdgeKind> = [.calls, .references, .parameterType, .propertyType, .returns]
        let incoming = getIncomingEdges(to: nodeId)

        return incoming.compactMap { edge in
            guard usageKinds.contains(edge.kind),
                  let sourceNode = nodes[edge.sourceId] else { return nil }
            return (sourceNode, edge)
        }
    }

    /// Find inheritance hierarchy (parents and children)
    public func findInheritanceHierarchy(for nodeId: UUID) -> (parents: [SymbolNode], children: [SymbolNode]) {
        let inheritanceKinds: Set<EdgeKind> = [.inherits, .conforms, .implements]

        var parents: [SymbolNode] = []
        var children: [SymbolNode] = []

        // Find parents (this node inherits from)
        for edge in getOutgoingEdges(from: nodeId) {
            if inheritanceKinds.contains(edge.kind),
               let parent = nodes[edge.targetId] {
                parents.append(parent)
            }
        }

        // Find children (nodes that inherit from this)
        for edge in getIncomingEdges(to: nodeId) {
            if inheritanceKinds.contains(edge.kind),
               let child = nodes[edge.sourceId] {
                children.append(child)
            }
        }

        return (parents, children)
    }

    /// Find protocol conformances
    public func findConformances(for nodeId: UUID) -> [SymbolNode] {
        getOutgoingEdges(from: nodeId)
            .filter { $0.kind == .conforms || $0.kind == .implements }
            .compactMap { nodes[$0.targetId] }
    }

    /// Find types that conform to a protocol
    public func findConformingTypes(for protocolId: UUID) -> [SymbolNode] {
        getIncomingEdges(to: protocolId)
            .filter { $0.kind == .conforms || $0.kind == .implements }
            .compactMap { nodes[$0.sourceId] }
    }

    /// Find call graph (what this function calls and what calls it)
    public func findCallGraph(for functionId: UUID, depth: Int = 2) -> (callers: [SymbolNode], callees: [SymbolNode]) {
        var callers: Set<UUID> = []
        var callees: Set<UUID> = []

        func findCallersRecursive(_ nodeId: UUID, currentDepth: Int) {
            guard currentDepth > 0 else { return }
            for edge in getIncomingEdges(to: nodeId) {
                if edge.kind == .calls && !callers.contains(edge.sourceId) {
                    callers.insert(edge.sourceId)
                    findCallersRecursive(edge.sourceId, currentDepth: currentDepth - 1)
                }
            }
        }

        func findCalleesRecursive(_ nodeId: UUID, currentDepth: Int) {
            guard currentDepth > 0 else { return }
            for edge in getOutgoingEdges(from: nodeId) {
                if edge.kind == .calls && !callees.contains(edge.targetId) {
                    callees.insert(edge.targetId)
                    findCalleesRecursive(edge.targetId, currentDepth: currentDepth - 1)
                }
            }
        }

        findCallersRecursive(functionId, currentDepth: depth)
        findCalleesRecursive(functionId, currentDepth: depth)

        return (
            callers: callers.compactMap { nodes[$0] },
            callees: callees.compactMap { nodes[$0] }
        )
    }

    /// Get dependency tree for a file
    public func getDependencies(forFile filePath: String) -> [String] {
        guard let nodeIds = fileIndex[filePath] else { return [] }

        var dependencies: Set<String> = []

        for nodeId in nodeIds {
            for edge in getOutgoingEdges(from: nodeId) {
                if edge.kind == .imports || edge.kind == .references,
                   let targetNode = nodes[edge.targetId] {
                    dependencies.insert(targetNode.filePath)
                }
            }
        }

        dependencies.remove(filePath) // Remove self-reference
        return Array(dependencies).sorted()
    }

    /// Get reverse dependencies (files that depend on this file)
    public func getReverseDependencies(forFile filePath: String) -> [String] {
        guard let nodeIds = fileIndex[filePath] else { return [] }

        var dependents: Set<String> = []

        for nodeId in nodeIds {
            for edge in getIncomingEdges(to: nodeId) {
                if edge.kind == .imports || edge.kind == .references,
                   let sourceNode = nodes[edge.sourceId] {
                    dependents.insert(sourceNode.filePath)
                }
            }
        }

        dependents.remove(filePath)
        return Array(dependents).sorted()
    }

    // MARK: - Graph Management

    /// Clear the entire graph
    public func clear() {
        nodes.removeAll()
        edges.removeAll()
        nameIndex.removeAll()
        fqnIndex.removeAll()
        fileIndex.removeAll()
        outgoingEdges.removeAll()
        incomingEdges.removeAll()
        statistics = nil
        logger.info("SymbolGraph cleared")
    }

    /// Remove all nodes and edges for a file
    public func removeFile(_ filePath: String) {
        guard let nodeIds = fileIndex[filePath] else { return }

        for nodeId in nodeIds {
            removeNode(nodeId)
        }

        fileIndex.removeValue(forKey: filePath)
    }

    /// Update statistics
    public func updateStatistics() {
        var nodesByKind: [SymbolKind: Int] = [:]
        var edgesByKind: [EdgeKind: Int] = [:]
        var totalConnections = 0
        var maxConnections = 0
        var isolatedNodes = 0

        for node in nodes.values {
            nodesByKind[node.kind, default: 0] += 1

            let connections = (outgoingEdges[node.id]?.count ?? 0) + (incomingEdges[node.id]?.count ?? 0)
            totalConnections += connections
            maxConnections = max(maxConnections, connections)

            if connections == 0 {
                isolatedNodes += 1
            }
        }

        for edge in edges.values {
            edgesByKind[edge.kind, default: 0] += 1
        }

        let averageConnections = nodes.isEmpty ? 0.0 : Double(totalConnections) / Double(nodes.count)

        statistics = GraphStatistics(
            totalNodes: nodes.count,
            totalEdges: edges.count,
            nodesByKind: nodesByKind,
            edgesByKind: edgesByKind,
            averageConnections: averageConnections,
            maxConnections: maxConnections,
            isolatedNodes: isolatedNodes
        )
    }

    /// Get all nodes of a specific kind
    public func getNodes(ofKind kind: SymbolKind) -> [SymbolNode] {
        nodes.values.filter { $0.kind == kind }
    }

    /// Export graph to JSON for debugging/visualization
    public func exportToJSON() throws -> Data {
        let export = GraphExport(
            nodes: Array(nodes.values),
            edges: Array(edges.values)
        )
        return try JSONEncoder().encode(export)
    }

    /// Import graph from JSON
    public func importFromJSON(_ data: Data) throws {
        let imported = try JSONDecoder().decode(GraphExport.self, from: data)

        clear()

        for node in imported.nodes {
            addNode(node)
        }

        for edge in imported.edges {
            addEdge(edge)
        }

        updateStatistics()
        logger.info("Imported graph with \(self.nodes.count) nodes and \(self.edges.count) edges")
    }
}

// MARK: - Export Model

private struct GraphExport: Codable {
    let nodes: [SymbolNode]
    let edges: [SymbolEdge]
}
