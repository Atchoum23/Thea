//
//  QuerySuggestionOverlay.swift
//  Thea
//
//  Displays AI-powered query suggestions below the input field.
//  Integrates with ProactivityEngine and MemoryService for context-aware suggestions.
//
//  CREATED: February 6, 2026
//

import SwiftUI

// MARK: - Query Suggestion Overlay

/// Overlay view showing suggested queries based on context and predictions
public struct QuerySuggestionOverlay: View {
    /// Callback when user selects a suggestion
    public let onSuggestionSelected: (String) -> Void

    /// Current conversation ID for context
    public let conversationId: UUID?

    /// Whether the overlay is visible
    @Binding public var isVisible: Bool

    @State private var suggestions: [QuerySuggestion] = []
    @State private var isLoading: Bool = false

    public init(
        conversationId: UUID?,
        isVisible: Binding<Bool>,
        onSuggestionSelected: @escaping (String) -> Void
    ) {
        self.conversationId = conversationId
        self._isVisible = isVisible
        self.onSuggestionSelected = onSuggestionSelected
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading suggestions...")
                        .font(.theaCaption1)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else if !suggestions.isEmpty {
                ForEach(suggestions) { suggestion in
                    SuggestionRow(suggestion: suggestion) {
                        onSuggestionSelected(suggestion.text)
                        isVisible = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(suggestionBackground)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .opacity(isVisible && !suggestions.isEmpty ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
        .task {
            await fetchSuggestions()
        }
        .onChange(of: conversationId) { _, _ in
            Task { await fetchSuggestions() }
        }
    }

    private var suggestionBackground: some View {
        Color.controlBackground
    }

    @MainActor
    private func fetchSuggestions() async {
        isLoading = true
        defer { isLoading = false }

        var allSuggestions: [QuerySuggestion] = []

        // 1. Get predictions from ProactivityEngine
        if let intentPrediction = await fetchIntentPrediction() {
            allSuggestions.append(QuerySuggestion(
                text: intentPrediction,
                source: .intentPrediction,
                confidence: 0.8
            ))
        }

        // 2. Get context-based suggestions
        if let conversationId {
            let contextSuggestions = await fetchContextSuggestions(for: conversationId)
            allSuggestions.append(contentsOf: contextSuggestions)
        }

        // 3. Get memory-based suggestions
        let memorySuggestions = await fetchMemorySuggestions()
        allSuggestions.append(contentsOf: memorySuggestions)

        // Sort by confidence and deduplicate
        let unique = removeDuplicates(allSuggestions)
        suggestions = Array(unique.sorted { $0.confidence > $1.confidence }.prefix(5))
    }

    @MainActor
    private func fetchIntentPrediction() async -> String? {
        // Use BehavioralFingerprint for time-based intent prediction
        let hour = Calendar.current.component(.hour, from: Date())
        let weekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
        let fingerprint = BehavioralFingerprint.shared
        let slots = fingerprint.timeSlots
        guard weekday < slots.count, hour < slots[weekday].count else { return nil }
        let slot = slots[weekday][hour]
        let totalActivity = slot.activityCounts.values.reduce(0, +)

        // Suggest based on time-of-day activity patterns
        if totalActivity > 5 && slot.dominantActivity != .idle {
            return "Continue where you left off"
        }
        return nil
    }

    @MainActor
    private func fetchContextSuggestions(for conversationId: UUID) async -> [QuerySuggestion] {
        // Pull the last few messages from the conversation to derive context
        guard let conversation = ChatManager.shared.conversations.first(where: { $0.id == conversationId }) else {
            return []
        }

        let recentMessages = conversation.messages.suffix(5)
        guard let lastAssistant = recentMessages.last(where: { $0.role == "assistant" }) else {
            return []
        }

        // Generate follow-up suggestions from the last assistant message
        var contextSuggestions: [QuerySuggestion] = []

        let content = lastAssistant.content.textValue
        if content.contains("```") {
            contextSuggestions.append(QuerySuggestion(
                text: "Explain this code in more detail",
                source: .contextBased,
                confidence: 0.75
            ))
        }
        if content.count > 500 {
            contextSuggestions.append(QuerySuggestion(
                text: "Summarize the key points",
                source: .contextBased,
                confidence: 0.7
            ))
        }
        if recentMessages.count >= 3 {
            contextSuggestions.append(QuerySuggestion(
                text: "What are the next steps?",
                source: .contextBased,
                confidence: 0.65
            ))
        }

        return contextSuggestions
    }

    @MainActor
    private func fetchMemorySuggestions() async -> [QuerySuggestion] {
        // Get recent entities from PersonalKnowledgeGraph as topic suggestions
        let recentEntities = await PersonalKnowledgeGraph.shared.searchEntities(query: "")
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
            .prefix(3)

        return recentEntities.map { entity in
            QuerySuggestion(
                text: "Tell me more about \(entity.name)",
                source: .memoryBased,
                confidence: 0.6
            )
        }
    }

    private func removeDuplicates(_ suggestions: [QuerySuggestion]) -> [QuerySuggestion] {
        var seen = Set<String>()
        return suggestions.filter { suggestion in
            let normalized = suggestion.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.contains(normalized) {
                return false
            }
            seen.insert(normalized)
            return true
        }
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    let suggestion: QuerySuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: suggestion.source.icon)
                    .font(.theaCaption1)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)

                Text(suggestion.text)
                    .font(.theaSubhead)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Spacer()

                if suggestion.confidence >= 0.8 {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hoverBackground)
    }

    private var hoverBackground: some View {
        #if os(macOS)
        Color.clear
            .contentShape(Rectangle())
        #else
        Color.clear
        #endif
    }
}

// MARK: - Query Suggestion Model

/// A suggested query
public struct QuerySuggestion: Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let source: SuggestionSource
    public let confidence: Double

    public init(
        id: UUID = UUID(),
        text: String,
        source: SuggestionSource,
        confidence: Double
    ) {
        self.id = id
        self.text = text
        self.source = source
        self.confidence = confidence
    }
}

/// Source of the suggestion
public enum SuggestionSource: String, Sendable {
    case intentPrediction = "intent"
    case contextBased = "context"
    case memoryBased = "memory"
    case patternBased = "pattern"
    case timeBased = "time"

    var icon: String {
        switch self {
        case .intentPrediction: return "brain"
        case .contextBased: return "bubble.left.and.bubble.right"
        case .memoryBased: return "memories"
        case .patternBased: return "chart.line.uptrend.xyaxis"
        case .timeBased: return "clock"
        }
    }

    // periphery:ignore - Reserved: label property reserved for future feature activation
    var label: String {
        switch self {
        case .intentPrediction: return "Predicted"
        case .contextBased: return "Based on context"
        case .memoryBased: return "From memory"
        case .patternBased: return "Common pattern"
        case .timeBased: return "Usually at this time"
        }
    }
}

// MARK: - View Modifier for Easy Integration

public extension View {
    /// Add query suggestion overlay below this view
    func withQuerySuggestions(
        conversationId: UUID?,
        isVisible: Binding<Bool>,
        onSuggestionSelected: @escaping (String) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            self

            QuerySuggestionOverlay(
                conversationId: conversationId,
                isVisible: isVisible,
                onSuggestionSelected: onSuggestionSelected
            )
        }
    }
}
