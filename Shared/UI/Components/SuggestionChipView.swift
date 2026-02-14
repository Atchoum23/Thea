import SwiftUI

// MARK: - Suggestion Item Model

struct SuggestionItem: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let prompt: String

    init(icon: String, text: String, prompt: String? = nil) {
        self.icon = icon
        self.text = text
        self.prompt = prompt ?? text
    }
}

// MARK: - Default Suggestions

extension SuggestionItem {
    static let defaults: [SuggestionItem] = [
        SuggestionItem(icon: "text.bubble", text: "Help me write an email"),
        SuggestionItem(icon: "lightbulb", text: "Brainstorm project ideas"),
        SuggestionItem(icon: "doc.text.magnifyingglass", text: "Summarize a document"),
        SuggestionItem(icon: "ladybug", text: "Debug my Swift code"),
        SuggestionItem(icon: "chart.bar", text: "Analyze this data"),
        SuggestionItem(icon: "globe", text: "Explain a concept to me")
    ]
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let item: SuggestionItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TheaSpacing.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: TheaSize.iconSmall))
                    .foregroundStyle(.secondary)
                Text(item.text)
                    .font(.callout)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, TheaSpacing.lg)
            .padding(.vertical, TheaSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: TheaCornerRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.text)
        .accessibilityHint("Sends this suggestion as a message")
    }
}

// MARK: - Suggestion Chip Grid

struct SuggestionChipGrid: View {
    let suggestions: [SuggestionItem]
    let onSelect: (SuggestionItem) -> Void

    init(
        suggestions: [SuggestionItem] = SuggestionItem.defaults,
        onSelect: @escaping (SuggestionItem) -> Void
    ) {
        self.suggestions = suggestions
        self.onSelect = onSelect
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: TheaSpacing.md),
                GridItem(.flexible(), spacing: TheaSpacing.md)
            ],
            spacing: TheaSpacing.md
        ) {
            ForEach(suggestions) { suggestion in
                SuggestionChip(item: suggestion) {
                    onSelect(suggestion)
                }
            }
        }
        .accessibilityLabel("Suggestions")
        .accessibilityHint("Choose a suggestion to start a conversation")
    }
}

#Preview {
    SuggestionChipGrid { item in
        print(item.text)
    }
    .padding()
}
