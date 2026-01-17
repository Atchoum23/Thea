import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Knowledge Graph Viewer
// Interactive visualization of the knowledge graph with nodes and relationships

struct KnowledgeGraphViewer: View {
    @State private var knowledgeGraph = KnowledgeGraph.shared
    @State private var selectedNode: KnowledgeNode?
    @State private var searchText = ""
    @State private var filterType: NodeType?
    @State private var showNodeDetails = false

    private var filteredNodes: [KnowledgeNode] {
        var nodes = knowledgeGraph.nodes

        // Filter by search
        if !searchText.isEmpty {
            nodes = nodes.filter { node in
                node.content.lowercased().contains(searchText.lowercased()) ||
                node.metadata.values.contains { value in
                    String(describing: value).lowercased().contains(searchText.lowercased())
                }
            }
        }

        // Filter by type
        if let type = filterType {
            nodes = nodes.filter { $0.type == type }
        }

        return nodes
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar - Node list
            VStack(spacing: 0) {
                searchAndFilterBar
                nodeList
            }
            .navigationTitle("Knowledge Graph")
        } detail: {
            // Main content - Graph visualization or node details
            if let node = selectedNode {
                NodeDetailView(node: node, knowledgeGraph: knowledgeGraph)
            } else {
                GraphOverviewView(nodes: filteredNodes) { node in
                    selectedNode = node
                }
            }
        }
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search knowledge...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.controlBackground)
            .cornerRadius(8)

            // Type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: filterType == nil
                    )                        { filterType = nil }

                    FilterChip(
                        title: "Concepts",
                        icon: "brain",
                        isSelected: filterType == .concept
                    )                        { filterType = .concept }

                    FilterChip(
                        title: "Facts",
                        icon: "doc.text",
                        isSelected: filterType == .fact
                    )                        { filterType = .fact }

                    FilterChip(
                        title: "Insights",
                        icon: "lightbulb",
                        isSelected: filterType == .insight
                    )                        { filterType = .insight }

                    FilterChip(
                        title: "References",
                        icon: "link",
                        isSelected: filterType == .reference
                    )                        { filterType = .reference }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color.windowBackground)
    }

    private var nodeList: some View {
        List(filteredNodes, selection: $selectedNode) { node in
            NodeRow(node: node)
                .tag(node)
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Node Row

struct NodeRow: View {
    let node: KnowledgeNode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconForNodeType(node.type))
                    .foregroundStyle(colorForNodeType(node.type))
                    .font(.caption)

                Text(node.content)
                    .font(.body)
                    .lineLimit(2)
            }

            if !node.metadata.isEmpty {
                Text(metadataPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var metadataPreview: String {
        node.metadata.keys.prefix(2).joined(separator: ", ")
    }

    private func iconForNodeType(_ type: NodeType) -> String {
        switch type {
        case .concept: return "brain"
        case .fact: return "doc.text"
        case .insight: return "lightbulb"
        case .reference: return "link"
        }
    }

    private func colorForNodeType(_ type: NodeType) -> Color {
        switch type {
        case .concept: return .purple
        case .fact: return .blue
        case .insight: return .orange
        case .reference: return .green
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.controlBackground)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Node Detail View

struct NodeDetailView: View {
    let node: KnowledgeNode
    let knowledgeGraph: KnowledgeGraph

    @State private var relatedNodes: [KnowledgeNode] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: iconForType(node.type))
                            .font(.title2)
                            .foregroundStyle(colorForType(node.type))

                        Text(typeLabel(node.type))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }

                    Text(node.content)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Created: \(node.createdAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Metadata
                if !node.metadata.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metadata")
                            .font(.headline)

                        ForEach(Array(node.metadata.keys.sorted()), id: \.self) { key in
                            HStack(alignment: .top) {
                                Text(key)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .leading)

                                Text(String(describing: node.metadata[key] ?? ""))
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Divider()
                }

                // Connections
                VStack(alignment: .leading, spacing: 12) {
                    Text("Related Nodes (\(relatedNodes.count))")
                        .font(.headline)

                    if relatedNodes.isEmpty {
                        Text("No related nodes found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(relatedNodes) { relatedNode in
                            RelatedNodeCard(node: relatedNode)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Node Details")
        .task {
            await loadRelatedNodes()
        }
    }

    private func loadRelatedNodes() async {
        // Get nodes connected to this node via the relationship graph
        let connected = knowledgeGraph.getConnectedNodes(from: node.id, depth: 2)
        relatedNodes = Array(connected.prefix(10))
    }

    private func iconForType(_ type: NodeType) -> String {
        switch type {
        case .concept: return "brain"
        case .fact: return "doc.text"
        case .insight: return "lightbulb"
        case .reference: return "link"
        }
    }

    private func colorForType(_ type: NodeType) -> Color {
        switch type {
        case .concept: return .purple
        case .fact: return .blue
        case .insight: return .orange
        case .reference: return .green
        }
    }

    private func typeLabel(_ type: NodeType) -> String {
        switch type {
        case .concept: return "Concept"
        case .fact: return "Fact"
        case .insight: return "Insight"
        case .reference: return "Reference"
        }
    }
}

// MARK: - Related Node Card

struct RelatedNodeCard: View {
    let node: KnowledgeNode

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForType(node.type))
                .foregroundStyle(colorForType(node.type))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.content)
                    .font(.caption)
                    .lineLimit(2)

                Text(typeLabel(node.type))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.controlBackground)
        .cornerRadius(8)
    }

    private func iconForType(_ type: NodeType) -> String {
        switch type {
        case .concept: return "brain"
        case .fact: return "doc.text"
        case .insight: return "lightbulb"
        case .reference: return "link"
        }
    }

    private func colorForType(_ type: NodeType) -> Color {
        switch type {
        case .concept: return .purple
        case .fact: return .blue
        case .insight: return .orange
        case .reference: return .green
        }
    }

    private func typeLabel(_ type: NodeType) -> String {
        switch type {
        case .concept: return "Concept"
        case .fact: return "Fact"
        case .insight: return "Insight"
        case .reference: return "Reference"
        }
    }
}

// MARK: - Graph Overview

struct GraphOverviewView: View {
    let nodes: [KnowledgeNode]
    let onNodeTap: (KnowledgeNode) -> Void

    private var statistics: GraphStatistics {
        GraphStatistics(
            totalNodes: nodes.count,
            concepts: nodes.filter { $0.type == .concept }.count,
            facts: nodes.filter { $0.type == .fact }.count,
            insights: nodes.filter { $0.type == .insight }.count,
            references: nodes.filter { $0.type == .reference }.count
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("Knowledge Graph")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("\(statistics.totalNodes) nodes across the knowledge base")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Statistics
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    KnowledgeStatCard(
                        title: "Concepts",
                        count: statistics.concepts,
                        icon: "brain",
                        color: .purple
                    )

                    KnowledgeStatCard(
                        title: "Facts",
                        count: statistics.facts,
                        icon: "doc.text",
                        color: .blue
                    )

                    KnowledgeStatCard(
                        title: "Insights",
                        count: statistics.insights,
                        icon: "lightbulb",
                        color: .orange
                    )

                    KnowledgeStatCard(
                        title: "References",
                        count: statistics.references,
                        icon: "link",
                        color: .green
                    )
                }

                // Recent nodes
                if !nodes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Nodes")
                            .font(.headline)

                        ForEach(nodes.sorted { $0.createdAt > $1.createdAt }.prefix(5)) { node in
                            Button(action: { onNodeTap(node) }) {
                                NodeRow(node: node)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}

struct KnowledgeStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.controlBackground)
        .cornerRadius(12)
    }
}

struct GraphStatistics {
    let totalNodes: Int
    let concepts: Int
    let facts: Int
    let insights: Int
    let references: Int
}

// MARK: - Preview

#Preview {
    KnowledgeGraphViewer()
}
