// MemoryContextView.swift
// Thea
//
// UI components for displaying retrieved memory context
// Shows what the AI "remembers" about the user and conversation

import SwiftUI

// MARK: - Memory Context Badge

/// Compact badge showing memory context was used
public struct MemoryContextBadge: View {
    let sourceCount: Int
    let confidence: Double
    @State private var isExpanded = false

    public init(sourceCount: Int, confidence: Double) {
        self.sourceCount = sourceCount
        self.confidence = confidence
    }

    public var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                Text("\(sourceCount) memories")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.purple.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(.purple)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory context")
        .accessibilityValue("\(sourceCount) memories used with \(Int(confidence * 100)) percent confidence")
        .accessibilityHint("Double tap to see memory details")
    }
}

// MARK: - Memory Sources List

/// Detailed view of retrieved memory sources
public struct MemorySourcesView: View {
    let sources: [RetrievalSource]
    @Environment(\.dismiss) private var dismiss

    public init(sources: [RetrievalSource]) {
        self.sources = sources
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory Context")
                            .font(.headline)
                        Text("\(sources.count) sources retrieved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close memory sources")
                }

                Divider()

                // Group by tier
                let groupedSources = Dictionary(grouping: sources) { $0.tier }

                ForEach(Array(groupedSources.keys).sorted { $0.rawValue < $1.rawValue }, id: \.self) { tier in
                    if let tierSources = groupedSources[tier] {
                        MemoryTierSection(tier: tier, sources: tierSources)
                    }
                }
            }
            .padding()
        }
        .background(Color.windowBackground)
    }
}

// MARK: - Memory Tier Section

struct MemoryTierSection: View {
    let tier: MemoryTierType
    let sources: [RetrievalSource]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: tierIcon)
                    .foregroundStyle(tierColor)
                Text(tier.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            ForEach(sources, id: \.content) { source in
                MemorySourceRow(source: source)
            }
        }
    }

    private var tierIcon: String {
        switch tier {
        case .working: return "clock"
        case .longTerm: return "archivebox"
        case .episodic: return "calendar"
        case .semantic: return "brain"
        case .procedural: return "list.bullet.rectangle"
        }
    }

    private var tierColor: Color {
        switch tier {
        case .working: return .blue
        case .longTerm: return .green
        case .episodic: return .orange
        case .semantic: return .purple
        case .procedural: return .pink
        }
    }
}

// MARK: - Memory Source Row

struct MemorySourceRow: View {
    let source: RetrievalSource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(source.type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(typeColor.opacity(0.15))
                    )
                    .foregroundStyle(typeColor)

                Spacer()

                RelevanceIndicator(score: source.relevanceScore)
            }

            Text(source.content)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Text(formatTimestamp(source.timestamp))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var typeColor: Color {
        switch source.type {
        case .memorySystem: return .blue
        case .episodic: return .orange
        case .semantic: return .purple
        case .procedural: return .pink
        case .conversationFact: return .green
        case .conversationSummary: return .teal
        case .userPreference: return .yellow
        case .knowledgeNode: return .indigo
        case .recentError: return .red
        case .learningEvent: return .mint
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Relevance Indicator

struct RelevanceIndicator: View {
    let score: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < filledDots ? dotColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Relevance")
        .accessibilityValue("\(Int(score * 100)) percent")
    }

    private var filledDots: Int {
        switch score {
        case 0.8...1.0: return 3
        case 0.5..<0.8: return 2
        case 0.3..<0.5: return 1
        default: return 0
        }
    }

    private var dotColor: Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
}

// MARK: - Memory Status Indicator

/// Shows whether memory augmentation is active
public struct MemoryStatusIndicator: View {
    let isActive: Bool
    let sourcesUsed: Int

    public init(isActive: Bool, sourcesUsed: Int = 0) {
        self.isActive = isActive
        self.sourcesUsed = sourcesUsed
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isActive ? "brain.head.profile" : "brain")
                .font(.caption)
                .symbolEffect(.pulse, options: .repeating, isActive: isActive && sourcesUsed > 0)

            if isActive && sourcesUsed > 0 {
                Text("\(sourcesUsed)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
        }
        .foregroundStyle(isActive ? .purple : .secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Memory system")
        .accessibilityValue(isActive ? "Active with \(sourcesUsed) sources" : "Inactive")
    }
}

// MARK: - Contextual Suggestions View

/// Shows AI suggestions based on memory
public struct ContextualSuggestionsView: View {
    let suggestions: [ContextualSuggestion]
    let onSelect: (ContextualSuggestion) -> Void

    public init(
        suggestions: [ContextualSuggestion],
        onSelect: @escaping (ContextualSuggestion) -> Void
    ) {
        self.suggestions = suggestions
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    MemorySuggestionChip(suggestion: suggestion) {
                        onSelect(suggestion)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct MemorySuggestionChip: View {
    let suggestion: ContextualSuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: suggestionIcon)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.title)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(suggestion.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var suggestionIcon: String {
        switch suggestion.type {
        case .procedure: return "list.bullet"
        case .relatedFact: return "lightbulb"
        case .previousSolution: return "checkmark.circle"
        case .suggestion: return "sparkles"
        }
    }
}

// MARK: - Preview

#Preview("Memory Context Badge") {
    VStack(spacing: 20) {
        MemoryContextBadge(sourceCount: 5, confidence: 0.85)
        MemoryContextBadge(sourceCount: 2, confidence: 0.55)
        MemoryContextBadge(sourceCount: 0, confidence: 0.0)
    }
    .padding()
}

#Preview("Memory Sources") {
    MemorySourcesView(sources: [
        RetrievalSource(
            type: .userPreference,
            tier: .semantic,
            content: "User prefers Swift 6.0 with strict concurrency",
            relevanceScore: 0.92,
            timestamp: Date().addingTimeInterval(-3600),
            metadata: [:]
        ),
        RetrievalSource(
            type: .conversationFact,
            tier: .longTerm,
            content: "Working on Thea AI assistant app",
            relevanceScore: 0.78,
            timestamp: Date().addingTimeInterval(-86400),
            metadata: ["category": "project"]
        ),
        RetrievalSource(
            type: .procedural,
            tier: .procedural,
            content: "Build SwiftUI app: Create views → Add state → Connect services",
            relevanceScore: 0.65,
            timestamp: Date().addingTimeInterval(-172800),
            metadata: [:]
        )
    ])
    .frame(width: 400, height: 500)
}

#Preview("Memory Status") {
    HStack(spacing: 20) {
        MemoryStatusIndicator(isActive: true, sourcesUsed: 3)
        MemoryStatusIndicator(isActive: true, sourcesUsed: 0)
        MemoryStatusIndicator(isActive: false)
    }
    .padding()
}
