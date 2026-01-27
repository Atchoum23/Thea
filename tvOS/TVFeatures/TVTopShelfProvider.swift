//
//  TVTopShelfProvider.swift
//  Thea tvOS
//
//  Top Shelf content and tvOS-specific features
//

import SwiftUI
import TVServices

// MARK: - Top Shelf Content Provider

class TheaTopShelfProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        // Create sectioned content for Top Shelf
        let content = createTopShelfContent()
        completionHandler(content)
    }

    private func createTopShelfContent() -> TVTopShelfContent {
        // Create sectioned content
        let sectionedContent = TVTopShelfSectionedContent(sections: createSections())
        return sectionedContent
    }

    private func createSections() -> [TVTopShelfItemCollection] {
        var sections: [TVTopShelfItemCollection] = []

        // Recent Conversations Section
        let recentSection = TVTopShelfItemCollection(items: createRecentItems())
        recentSection.title = "Recent Conversations"
        sections.append(recentSection)

        // Quick Actions Section
        let actionsSection = TVTopShelfItemCollection(items: createActionItems())
        actionsSection.title = "Quick Actions"
        sections.append(actionsSection)

        // Suggestions Section
        let suggestionsSection = TVTopShelfItemCollection(items: createSuggestionItems())
        suggestionsSection.title = "Suggestions"
        sections.append(suggestionsSection)

        return sections
    }

    private func createRecentItems() -> [TVTopShelfSectionedItem] {
        // Load recent conversations from shared storage
        let defaults = UserDefaults(suiteName: "group.app.theathe")
        let recentTitles = defaults?.stringArray(forKey: "tv.recentConversations") ?? [
            "Code Review Help",
            "Writing Assistant",
            "Research Query"
        ]

        return recentTitles.prefix(5).enumerated().map { index, title in
            let item = TVTopShelfSectionedItem(identifier: "conversation_\(index)")
            item.title = title

            // Create URL for deep linking
            if let url = URL(string: "thea://conversation/\(index)") {
                item.setURL(url, for: .play)
            }

            return item
        }
    }

    private func createActionItems() -> [TVTopShelfSectionedItem] {
        let actions = [
            ("Ask a Question", "bubble.left.fill", "ask"),
            ("Summarize Text", "doc.text", "summarize"),
            ("Translate", "globe", "translate"),
            ("Write Code", "chevron.left.forwardslash.chevron.right", "code"),
            ("Daily Summary", "chart.bar.fill", "summary")
        ]

        return actions.map { title, _, action in
            let item = TVTopShelfSectionedItem(identifier: "action_\(action)")
            item.title = title

            if let url = URL(string: "thea://action/\(action)") {
                item.setURL(url, for: .play)
            }

            return item
        }
    }

    private func createSuggestionItems() -> [TVTopShelfSectionedItem] {
        let suggestions = [
            "What's the weather like?",
            "Set a reminder",
            "Tell me a joke",
            "Explain quantum computing",
            "Help me brainstorm"
        ]

        return suggestions.enumerated().map { index, suggestion in
            let item = TVTopShelfSectionedItem(identifier: "suggestion_\(index)")
            item.title = suggestion

            if let encoded = suggestion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "thea://ask?q=\(encoded)")
            {
                item.setURL(url, for: .play)
            }

            return item
        }
    }
}

// MARK: - tvOS Home View

struct TVHomeView: View {
    @State private var selectedSection = 0
    @State private var focusedItem: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    // Hero Section
                    HeroSection()

                    // Quick Actions
                    QuickActionsSection(focusedItem: $focusedItem)

                    // Recent Conversations
                    RecentConversationsSection()

                    // Suggestions
                    SuggestionsSection()
                }
                .padding(60)
            }
            .navigationTitle("Thea")
        }
    }
}

// MARK: - Hero Section

struct HeroSection: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Thea AI Assistant")
                .font(.largeTitle.bold())

            Text("Your intelligent companion on Apple TV")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Main action button
            NavigationLink(destination: AskView()) {
                HStack {
                    Image(systemName: "bubble.left.fill")
                    Text("Ask Thea")
                }
                .font(.title2.bold())
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.card)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    @Binding var focusedItem: String?

    let actions = [
        ("Ask", "bubble.left.fill", Color.blue),
        ("Summarize", "doc.text", Color.green),
        ("Translate", "globe", Color.orange),
        ("Code", "chevron.left.forwardslash.chevron.right", Color.purple),
        ("Daily", "chart.bar.fill", Color.red)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quick Actions")
                .font(.title2.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    ForEach(actions, id: \.0) { action in
                        TVActionCard(
                            title: action.0,
                            icon: action.1,
                            color: action.2,
                            isFocused: focusedItem == action.0
                        )
                        .focusable()
                        .onFocusChange { focused in
                            if focused {
                                focusedItem = action.0
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Action Card

struct TVActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(color)

            Text(title)
                .font(.headline)
        }
        .frame(width: 200, height: 200)
        .background(isFocused ? color.opacity(0.2) : Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Recent Conversations Section

struct RecentConversationsSection: View {
    let conversations = [
        ("Code Review Help", "Reviewed authentication code", Date()),
        ("Writing Assistant", "Helped write blog post", Date().addingTimeInterval(-3600)),
        ("Research Query", "Quantum computing overview", Date().addingTimeInterval(-7200))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recent Conversations")
                .font(.title2.bold())

            ForEach(conversations, id: \.0) { conv in
                TVConversationRow(
                    title: conv.0,
                    subtitle: conv.1,
                    date: conv.2
                )
            }
        }
    }
}

struct TVConversationRow: View {
    let title: String
    let subtitle: String
    let date: Date
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(date, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(isFocused ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .focusable()
        .focused($isFocused)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Suggestions Section

struct SuggestionsSection: View {
    let suggestions = [
        "What's trending today?",
        "Tell me something interesting",
        "Help me plan my week",
        "Recommend a movie",
        "Explain a concept"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Try Asking")
                .font(.title2.bold())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 20) {
                ForEach(suggestions, id: \.self) { suggestion in
                    TVSuggestionCard(text: suggestion)
                }
            }
        }
    }
}

struct TVSuggestionCard: View {
    let text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        Text(text)
            .font(.body)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isFocused ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isFocused ? 1.03 : 1.0)
            .focusable()
            .focused($isFocused)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Ask View

struct AskView: View {
    @State private var inputText = ""
    @State private var response = ""
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 40) {
            // Input area
            VStack(spacing: 16) {
                Text("Ask Thea")
                    .font(.title.bold())

                TextField("What would you like to know?", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: submitQuestion) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text("Send")
                    }
                    .font(.headline)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.card)
                .disabled(inputText.isEmpty || isProcessing)
            }

            // Response area
            if !response.isEmpty {
                ScrollView {
                    Text(response)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(60)
        .navigationTitle("Ask")
    }

    private func submitQuestion() {
        isProcessing = true
        // Simulate AI response
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            response = "This is a response from Thea AI to your question: '\(inputText)'. The full implementation would connect to the AI backend."
            isProcessing = false
        }
    }
}
