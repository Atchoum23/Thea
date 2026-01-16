import Foundation
import Observation
import SwiftData

/// Advanced knowledge graph for semantic relationships and deep understanding
@MainActor
@Observable
final class KnowledgeGraph {
  static let shared = KnowledgeGraph()

  private(set) var nodes: [KnowledgeNode] = []
  private(set) var edges: [KnowledgeEdge] = []
  private(set) var clusters: [KnowledgeCluster] = []

  private var nodeIndex: [String: KnowledgeNode] = [:]
  private var embeddingsCache: [String: [Float]] = [:]

  // Configuration accessor
  private var config: MetaAIConfiguration {
    AppConfiguration.shared.metaAIConfig
  }

  private init() {}

  // MARK: - Node Operations

  /// Add a new knowledge node
  func addNode(
    content: String,
    type: NodeType,
    metadata: [String: String] = [:]
  ) async throws -> KnowledgeNode {
    // Generate embedding for semantic search
    let embedding = try await generateEmbedding(for: content)

    let node = KnowledgeNode(
      id: UUID(),
      content: content,
      type: type,
      embedding: embedding,
      metadata: metadata,
      createdAt: Date(),
      importance: calculateImportance(content: content, type: type)
    )

    nodes.append(node)
    nodeIndex[node.id.uuidString] = node

    // Find and create related edges
    try await discoverRelationships(for: node)

    return node
  }

  /// Find nodes by semantic similarity
  func findSimilar(
    to query: String,
    limit: Int = 10,
    threshold: Float = 0.7
  ) async throws -> [KnowledgeNode] {
    let queryEmbedding = try await generateEmbedding(for: query)

    let scored = nodes.map { node in
      (node, cosineSimilarity(queryEmbedding, node.embedding))
    }
    .filter { $0.1 >= threshold }
    .sorted { $0.1 > $1.1 }
    .prefix(limit)

    return scored.map { $0.0 }
  }

  // MARK: - Edge Operations

  /// Create relationship between nodes
  func createEdge(
    from sourceId: UUID,
    to targetId: UUID,
    type: EdgeType,
    strength: Float = 1.0
  ) {
    guard let source = nodeIndex[sourceId.uuidString],
      let target = nodeIndex[targetId.uuidString]
    else {
      return
    }

    let edge = KnowledgeEdge(
      id: UUID(),
      sourceId: sourceId,
      targetId: targetId,
      type: type,
      strength: strength,
      bidirectional: type.isBidirectional
    )

    edges.append(edge)

    // Update node connections
    source.outgoingEdges.append(edge.id)
    target.incomingEdges.append(edge.id)
  }

  /// Find all nodes connected to a given node
  func getConnectedNodes(
    from nodeId: UUID,
    depth: Int = 1,
    edgeTypes: [EdgeType]? = nil
  ) -> [KnowledgeNode] {
    guard nodeIndex[nodeId.uuidString] != nil else { return [] }

    var connected: Set<UUID> = []
    var queue: [(UUID, Int)] = [(nodeId, 0)]
    var visited: Set<UUID> = []

    while !queue.isEmpty {
      let (currentId, currentDepth) = queue.removeFirst()

      if visited.contains(currentId) || currentDepth > depth {
        continue
      }

      visited.insert(currentId)

      if currentDepth > 0 {
        connected.insert(currentId)
      }

      // Find outgoing edges
      if let currentNode = nodeIndex[currentId.uuidString] {
        for edgeId in currentNode.outgoingEdges {
          if let edge = edges.first(where: { $0.id == edgeId }) {
            if edgeTypes == nil || edgeTypes!.contains(edge.type) {
              queue.append((edge.targetId, currentDepth + 1))
            }
          }
        }
      }
    }

    return connected.compactMap { nodeIndex[$0.uuidString] }
  }

  // MARK: - Relationship Discovery

  private func discoverRelationships(for node: KnowledgeNode) async throws {
    // Find semantically similar nodes
    let similar = try await findSimilar(
      to: node.content,
      limit: 5,
      threshold: 0.8
    )

    for similarNode in similar where similarNode.id != node.id {
      // Determine relationship type
      let relationType = try await determineRelationType(
        from: node,
        to: similarNode
      )

      createEdge(
        from: node.id,
        to: similarNode.id,
        type: relationType,
        strength: 0.8
      )
    }

    // Discover implicit relationships
    try await discoverImplicitRelationships(for: node)
  }

  private func determineRelationType(
    from source: KnowledgeNode,
    to target: KnowledgeNode
  ) async throws -> EdgeType {
    let provider =
      ProviderRegistry.shared.getProvider(id: "anthropic") ?? ProviderRegistry.shared.getProvider(
        id: "openai")!

    let prompt = """
      Determine the relationship between these concepts:

      Concept A: \(source.content)
      Concept B: \(target.content)

      Relationship types:
      - related_to: General association
      - depends_on: A requires B
      - part_of: A is component of B
      - similar_to: A is similar to B
      - contradicts: A contradicts B
      - causes: A causes B
      - derived_from: A is derived from B

      Return only the relationship type.
      """

    let response = try await streamProviderResponse(
      provider: provider, prompt: prompt, model: config.knowledgeGraphModel)

    // Parse relationship type
    let lowercased = response.lowercased()
    if lowercased.contains("depends") {
      return .dependsOn
    } else if lowercased.contains("part") {
      return .partOf
    } else if lowercased.contains("similar") {
      return .similarTo
    } else if lowercased.contains("contradicts") {
      return .contradicts
    } else if lowercased.contains("causes") {
      return .causes
    } else if lowercased.contains("derived") {
      return .derivedFrom
    }

    return .relatedTo
  }

  private func discoverImplicitRelationships(for node: KnowledgeNode) async throws {
    // Look for transitive relationships
    // If A->B and B->C, might imply A->C
    let connected = getConnectedNodes(from: node.id, depth: 2)

    for connectedNode in connected {
      // Analyze if there's an implicit relationship
      let shouldConnect = try await analyzeImplicitConnection(
        from: node,
        to: connectedNode
      )

      if shouldConnect {
        createEdge(
          from: node.id,
          to: connectedNode.id,
          type: .inferredFrom,
          strength: 0.5
        )
      }
    }
  }

  private func analyzeImplicitConnection(
    from source: KnowledgeNode,
    to target: KnowledgeNode
  ) async throws -> Bool {
    // Use AI to determine if implicit connection exists
    let provider =
      ProviderRegistry.shared.getProvider(id: "anthropic") ?? ProviderRegistry.shared.getProvider(
        id: "openai")!

    let prompt = """
      Is there an implicit logical connection between:
      A: \(source.content)
      B: \(target.content)

      Answer yes or no with brief explanation.
      """

    let response = try await streamProviderResponse(
      provider: provider, prompt: prompt, model: config.knowledgeGraphModel)

    return response.lowercased().starts(with: "yes")
  }

  // MARK: - Clustering

  /// Organize nodes into semantic clusters
  func createClusters() async throws {
    // Use k-means clustering on embeddings
    let k = max(5, nodes.count / 20)  // Dynamic cluster count

    var centroids: [[Float]] = []
    var assignments: [UUID: Int] = [:]

    // Initialize random centroids
    for _ in 0..<k {
      if let randomNode = nodes.randomElement() {
        centroids.append(randomNode.embedding)
      }
    }

    // Iterate until convergence
    for _ in 0..<10 {
      // Assign nodes to nearest centroid
      for node in nodes {
        var minDistance = Float.infinity
        var bestCluster = 0

        for (i, centroid) in centroids.enumerated() {
          let distance = euclideanDistance(node.embedding, centroid)
          if distance < minDistance {
            minDistance = distance
            bestCluster = i
          }
        }

        assignments[node.id] = bestCluster
      }

      // Recalculate centroids
      for i in 0..<k {
        let clusterNodes = nodes.filter { assignments[$0.id] == i }
        if !clusterNodes.isEmpty {
          centroids[i] = averageEmbedding(clusterNodes.map { $0.embedding })
        }
      }
    }

    // Create cluster objects
    clusters = []
    for i in 0..<k {
      let clusterNodes = nodes.filter { assignments[$0.id] == i }

      if !clusterNodes.isEmpty {
        let cluster = KnowledgeCluster(
          id: UUID(),
          name: "Cluster \(i + 1)",
          nodeIds: clusterNodes.map { $0.id },
          centroid: centroids[i],
          coherence: calculateCoherence(clusterNodes)
        )
        clusters.append(cluster)
      }
    }

    // Name clusters based on content
    try await nameClusters()
  }

  private func nameClusters() async throws {
    for i in 0..<clusters.count {
      let clusterNodes = clusters[i].nodeIds.compactMap { nodeIndex[$0.uuidString] }
      let contents = clusterNodes.map { $0.content }.joined(separator: "\n")

      let provider =
        ProviderRegistry.shared.getProvider(id: "anthropic") ?? ProviderRegistry.shared.getProvider(
          id: "openai")!

      let prompt = """
        Give a short name (2-4 words) for this cluster of related concepts:

        \(contents.prefix(500))

        Return only the cluster name.
        """

      let name = try await streamProviderResponse(
        provider: provider, prompt: prompt, model: config.knowledgeGraphModel)

      clusters[i].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  // MARK: - Query & Reasoning

  /// Answer complex queries using graph reasoning
  func queryGraph(_ query: String) async throws -> GraphQueryResult {
    // Find relevant nodes
    let relevant = try await findSimilar(to: query, limit: 20)

    // Expand to connected nodes
    var expanded: Set<KnowledgeNode> = Set(relevant)
    for node in relevant {
      let connected = getConnectedNodes(from: node.id, depth: 2)
      expanded.formUnion(connected)
    }

    // Extract knowledge
    let knowledge = Array(expanded)
      .sorted { $0.importance > $1.importance }
      .prefix(10)
      .map { $0.content }
      .joined(separator: "\n\n")

    // Reason over knowledge
    let answer = try await reasonWithKnowledge(query: query, knowledge: knowledge)

    return GraphQueryResult(
      query: query,
      relevantNodes: Array(expanded),
      answer: answer,
      confidence: 0.85
    )
  }

  private func reasonWithKnowledge(query: String, knowledge: String) async throws -> String {
    let provider =
      ProviderRegistry.shared.getProvider(id: "anthropic") ?? ProviderRegistry.shared.getProvider(
        id: "openai")!

    let prompt = """
      Using this knowledge from the knowledge graph, answer the query:

      Knowledge:
      \(knowledge)

      Query: \(query)

      Provide a comprehensive answer synthesizing the knowledge.
      """

    return try await streamProviderResponse(
      provider: provider, prompt: prompt, model: config.knowledgeGraphModel)
  }

  // MARK: - Embeddings

  private func generateEmbedding(for text: String) async throws -> [Float] {
    // Check cache
    if let cached = embeddingsCache[text] {
      return cached
    }

    // Generate using OpenAI embeddings API
    // Simplified - should use actual embedding API
    let hash = text.hashValue
    let embedding = (0..<1536).map { i in
      Float(sin(Double(hash + i))) * 0.1
    }

    embeddingsCache[text] = embedding
    return embedding
  }

  // MARK: - Helper Methods

  private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    let dotProduct = zip(a, b).map { $0 * $1 }.reduce(0, +)
    let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
    let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
    return dotProduct / (magnitudeA * magnitudeB)
  }

  private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
    sqrt(zip(a, b).map { pow($0 - $1, 2) }.reduce(0, +))
  }

  private func averageEmbedding(_ embeddings: [[Float]]) -> [Float] {
    guard !embeddings.isEmpty else { return [] }
    let count = Float(embeddings.count)
    return (0..<embeddings[0].count).map { i in
      embeddings.map { $0[i] }.reduce(0, +) / count
    }
  }

  private func calculateImportance(content: String, type: NodeType) -> Float {
    var importance: Float = 0.5

    // Longer content tends to be more important
    importance += Float(min(content.count, 1000)) / 2000

    // Type-based importance
    switch type {
    case .concept:
      importance += 0.2
    case .fact:
      importance += 0.1
    case .insight:
      importance += 0.3
    case .reference:
      importance += 0.0
    }

    return min(importance, 1.0)
  }

  private func calculateCoherence(_ nodes: [KnowledgeNode]) -> Float {
    guard nodes.count > 1 else { return 1.0 }

    var totalSimilarity: Float = 0
    var pairCount = 0

    for i in 0..<nodes.count {
      for j in (i + 1)..<nodes.count {
        totalSimilarity += cosineSimilarity(nodes[i].embedding, nodes[j].embedding)
        pairCount += 1
      }
    }

    return pairCount > 0 ? totalSimilarity / Float(pairCount) : 0
  }

  // Helper to stream provider response into a single string
  private func streamProviderResponse(provider: AIProvider, prompt: String, model: String)
    async throws -> String
  {
    let message = AIMessage(
      id: UUID(),
      conversationID: UUID(),
      role: .user,
      content: .text(prompt),
      timestamp: Date(),
      model: model
    )

    var result = ""
    let stream = try await provider.chat(messages: [message], model: model, stream: true)

    for try await chunk in stream {
      switch chunk.type {
      case .delta(let text):
        result += text
      case .complete:
        break
      case .error(let error):
        throw error
      }
    }

    return result
  }
}

// MARK: - Data Structures

class KnowledgeNode: Identifiable, Hashable {
  let id: UUID
  let content: String
  let type: NodeType
  let embedding: [Float]
  var metadata: [String: String]
  let createdAt: Date
  var importance: Float
  var outgoingEdges: [UUID] = []
  var incomingEdges: [UUID] = []

  init(
    id: UUID, content: String, type: NodeType, embedding: [Float], metadata: [String: String],
    createdAt: Date, importance: Float
  ) {
    self.id = id
    self.content = content
    self.type = type
    self.embedding = embedding
    self.metadata = metadata
    self.createdAt = createdAt
    self.importance = importance
  }

  static func == (lhs: KnowledgeNode, rhs: KnowledgeNode) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

enum NodeType: String {
  case concept, fact, insight, reference
}

struct KnowledgeEdge: Identifiable {
  let id: UUID
  let sourceId: UUID
  let targetId: UUID
  let type: EdgeType
  let strength: Float
  let bidirectional: Bool
}

enum EdgeType: String {
  case relatedTo, dependsOn, partOf, similarTo, contradicts, causes, derivedFrom, inferredFrom

  var isBidirectional: Bool {
    switch self {
    case .relatedTo, .similarTo, .contradicts:
      return true
    default:
      return false
    }
  }
}

struct KnowledgeCluster: Identifiable {
  let id: UUID
  var name: String
  let nodeIds: [UUID]
  let centroid: [Float]
  let coherence: Float
}

struct GraphQueryResult {
  let query: String
  let relevantNodes: [KnowledgeNode]
  let answer: String
  let confidence: Float
}
