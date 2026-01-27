import SwiftUI

struct MemoryInspectorView: View {
    @State private var memorySystem = MemorySystem.shared
    @State private var selectedTier: MemoryTier = .shortTerm
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Tier selector
            Picker("Memory Tier", selection: $selectedTier) {
                Text("Short-Term").tag(MemoryTier.shortTerm)
                Text("Long-Term").tag(MemoryTier.longTerm)
            }
            .pickerStyle(.segmented)
            .padding()

            // Stats
            MemoryStatsView(memorySystem: memorySystem)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search memories", text: $searchText)
            }
            .padding(8)
            .background(.quaternary)
            .cornerRadius(8)
            .padding(.horizontal)

            // Memory list
            MemoryListView(
                memories: filteredMemories,
                tier: selectedTier
            )
        }
        .navigationTitle("Memory Inspector")
    }

    private var filteredMemories: [Memory] {
        let tierMemories: [Memory] = switch selectedTier {
        case .shortTerm:
            memorySystem.shortTermMemory
        case .longTerm:
            memorySystem.longTermMemory
        }

        if searchText.isEmpty {
            return tierMemories
        }

        return tierMemories.filter {
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Memory Stats

struct MemoryStatsView: View {
    let memorySystem: MemorySystem

    var body: some View {
        HStack(spacing: 20) {
            MemoryStatCard(
                title: "Short-Term",
                value: "\(memorySystem.shortTermMemory.count)",
                color: .blue
            )

            MemoryStatCard(
                title: "Long-Term",
                value: "\(memorySystem.longTermMemory.count)",
                color: .purple
            )

            MemoryStatCard(
                title: "Episodic",
                value: "\(memorySystem.episodicMemory.count)",
                color: .green
            )

            MemoryStatCard(
                title: "Semantic",
                value: "\(memorySystem.semanticMemory.count)",
                color: .orange
            )
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct MemoryStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Memory List

struct MemoryListView: View {
    let memories: [Memory]
    let tier: MemoryTier

    var body: some View {
        if memories.isEmpty {
            ContentUnavailableView(
                "No Memories",
                systemImage: "brain",
                description: Text("No memories stored in \(tier.rawValue)")
            )
        } else {
            List(memories) { memory in
                MemoryRow(memory: memory)
            }
            .listStyle(.plain)
        }
    }
}

struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type and importance
            HStack {
                Label(memory.type.rawValue, systemImage: iconForType(memory.type))
                    .font(.caption)
                    .foregroundStyle(colorForType(memory.type))

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0 ..< Int(memory.importance * 5), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }

            // Content
            Text(memory.content)
                .font(.body)
                .lineLimit(3)

            // Metadata
            HStack {
                Text(memory.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if memory.accessCount > 0 {
                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("\(memory.accessCount) accesses")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func iconForType(_ type: MemoryType) -> String {
        switch type {
        case .episodic: "clock"
        case .semantic: "book"
        case .procedural: "gearshape"
        case .factual: "doc.text"
        case .contextual: "context.menu"
        }
    }

    private func colorForType(_ type: MemoryType) -> Color {
        switch type {
        case .episodic: .blue
        case .semantic: .green
        case .procedural: .orange
        case .factual: .purple
        case .contextual: .pink
        }
    }
}

#Preview {
    MemoryInspectorView()
}
