//
//  TheaWidgetBundle.swift
//  TheaWidgetExtension
//
//  Created by Thea
//

import AppIntents
import SwiftUI
import WidgetKit

@main
struct TheaWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Conversation Widget
        TheaConversationWidget()

        // Quick Actions Widget
        TheaQuickActionsWidget()

        // Memory Widget
        TheaMemoryWidget()

        // Context Widget (shows current awareness)
        TheaContextWidget()

        #if os(iOS)
            // Lock Screen Widgets
            TheaLockScreenWidget()
        #endif
    }
}

// MARK: - Conversation Widget

struct TheaConversationWidget: Widget {
    let kind: String = "TheaConversationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ConversationProvider()) { entry in
            ConversationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Thea Conversations")
        .description("Quick access to recent conversations.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ConversationProvider: TimelineProvider {
    func placeholder(in _: Context) -> ConversationEntry {
        ConversationEntry(date: Date(), conversations: [], relevance: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (ConversationEntry) -> Void) {
        let convos = loadConversations()
        let entry = ConversationEntry(date: Date(), conversations: convos,
                                      relevance: TimelineEntryRelevance(score: convos.isEmpty ? 0.1 : 0.8, duration: 300))
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<ConversationEntry>) -> Void) {
        let convos = loadConversations()
        let entry = ConversationEntry(date: Date(), conversations: convos,
                                      relevance: TimelineEntryRelevance(score: convos.isEmpty ? 0.1 : 0.8, duration: 300))
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }

    private func loadConversations() -> [ConversationSummary] {
        // Load from App Group shared storage
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.theathe") else {
            return []
        }

        let conversationsPath = containerURL.appendingPathComponent("conversations.json")
        guard let data = try? Data(contentsOf: conversationsPath),
              let conversations = try? JSONDecoder().decode([ConversationSummary].self, from: data)
        else {
            return []
        }

        return Array(conversations.prefix(5))
    }
}

struct ConversationEntry: TimelineEntry {
    let date: Date
    let conversations: [ConversationSummary]
    var relevance: TimelineEntryRelevance?
}

struct ConversationSummary: Codable, Identifiable {
    let id: String
    let title: String
    let lastMessage: String
    let timestamp: Date
}

struct ConversationWidgetView: View {
    var entry: ConversationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(.purple)
                Text("Thea")
                    .font(.headline)
            }

            if entry.conversations.isEmpty {
                Text("Start a conversation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.conversations.prefix(3)) { conversation in
                    Link(destination: URL(string: "thea://conversation/\(conversation.id)")!) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conversation.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(conversation.lastMessage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Quick Actions Widget

struct TheaQuickActionsWidget: Widget {
    let kind: String = "TheaQuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Actions")
        .description("Fast access to common Thea actions.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in _: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: Date(), relevance: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: Date(), relevance: TimelineEntryRelevance(score: 0.5, duration: 3600)))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let entry = QuickActionsEntry(date: Date(), relevance: TimelineEntryRelevance(score: 0.5, duration: 3600))
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct QuickActionsEntry: TimelineEntry {
    let date: Date
    var relevance: TimelineEntryRelevance?
}

struct QuickActionsWidgetView: View {
    var entry: QuickActionsEntry

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "mic.fill",
                    title: "Voice",
                    color: .purple,
                    url: "thea://voice"
                )
                QuickActionButton(
                    icon: "camera.fill",
                    title: "Vision",
                    color: .blue,
                    url: "thea://camera"
                )
            }
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "doc.text.fill",
                    title: "Document",
                    color: .orange,
                    url: "thea://document"
                )
                QuickActionButton(
                    icon: "brain.head.profile",
                    title: "Memory",
                    color: .green,
                    url: "thea://memory"
                )
            }
        }
        .padding()
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Memory Widget (AppIntentConfiguration — AAB3-1)

struct TheaMemoryWidget: Widget {
    let kind: String = "TheaMemoryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SearchMemoryIntent.self, provider: MemoryIntentProvider()) { entry in
            MemoryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Thea Memory")
        .description("Recent memories and facts. Configure a topic to filter.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// AppIntentTimelineProvider for TheaMemoryWidget — supports topic filtering via SearchMemoryIntent.
struct MemoryIntentProvider: AppIntentTimelineProvider {
    typealias Entry = MemoryEntry
    typealias Intent = SearchMemoryIntent

    func placeholder(in _: Context) -> MemoryEntry {
        MemoryEntry(date: Date(), memories: [], topic: nil, relevance: nil)
    }

    func snapshot(for intent: SearchMemoryIntent, in _: Context) async -> MemoryEntry {
        let memories = loadMemories(topic: intent.topic)
        return MemoryEntry(date: Date(), memories: memories, topic: intent.topic,
                           relevance: TimelineEntryRelevance(score: memories.isEmpty ? 0.1 : 0.7, duration: 600))
    }

    func timeline(for intent: SearchMemoryIntent, in _: Context) async -> Timeline<MemoryEntry> {
        let memories = loadMemories(topic: intent.topic)
        let entry = MemoryEntry(date: Date(), memories: memories, topic: intent.topic,
                                relevance: TimelineEntryRelevance(score: memories.isEmpty ? 0.1 : 0.7, duration: 600))
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(600)))
    }

    private func loadMemories(topic: String?) -> [MemorySummary] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.theathe") else {
            return []
        }
        let memoriesPath = containerURL.appendingPathComponent("memories.json")
        guard let data = try? Data(contentsOf: memoriesPath),
              let memories = try? JSONDecoder().decode([MemorySummary].self, from: data)
        else { return [] }

        if let topic, !topic.isEmpty {
            return Array(memories.filter { $0.content.localizedCaseInsensitiveContains(topic) }.prefix(5))
        }
        return Array(memories.prefix(5))
    }
}

struct MemoryEntry: TimelineEntry {
    let date: Date
    let memories: [MemorySummary]
    var topic: String?
    var relevance: TimelineEntryRelevance?
}

struct MemorySummary: Codable, Identifiable {
    let id: String
    let content: String
    let type: String
    let timestamp: Date
}

struct MemoryWidgetView: View {
    var entry: MemoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.green)
                Text("Memory")
                    .font(.headline)
            }

            if entry.memories.isEmpty {
                Text("No memories yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.memories) { memory in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: memory.type == "fact" ? "lightbulb.fill" : "heart.fill")
                            .font(.caption)
                            .foregroundStyle(memory.type == "fact" ? .yellow : .pink)

                        Text(memory.content)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Context Widget

struct TheaContextWidget: Widget {
    let kind: String = "TheaContextWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ContextProvider()) { entry in
            ContextWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Thea Context")
        .description("Shows what Thea knows about your current context.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ContextProvider: TimelineProvider {
    func placeholder(in _: Context) -> ContextEntry {
        ContextEntry(date: Date(), contextSummary: "Understanding your context...", relevance: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (ContextEntry) -> Void) {
        let summary = loadContextSummary()
        completion(ContextEntry(date: Date(), contextSummary: summary,
                                relevance: TimelineEntryRelevance(score: 0.6, duration: 60)))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<ContextEntry>) -> Void) {
        let summary = loadContextSummary()
        let entry = ContextEntry(date: Date(), contextSummary: summary,
                                 relevance: TimelineEntryRelevance(score: 0.6, duration: 60))
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        completion(timeline)
    }

    private func loadContextSummary() -> String {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.theathe") else {
            return "Tap to open Thea"
        }
        let contextPath = containerURL.appendingPathComponent("context_summary.txt")
        return (try? String(contentsOf: contextPath, encoding: .utf8)) ?? "Tap to open Thea"
    }
}

struct ContextEntry: TimelineEntry {
    let date: Date
    let contextSummary: String
    var relevance: TimelineEntryRelevance?
}

struct ContextWidgetView: View {
    var entry: ContextEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Context")
                    .font(.headline)
            }

            Text(entry.contextSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(5)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Lock Screen Widget (iOS only)

#if os(iOS)
    struct TheaLockScreenWidget: Widget {
        let kind: String = "TheaLockScreenWidget"

        var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
                LockScreenWidgetView(entry: entry)
            }
            .configurationDisplayName("Thea")
            .description("Quick access to Thea from Lock Screen.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
        }
    }

    struct LockScreenProvider: TimelineProvider {
        func placeholder(in _: Context) -> LockScreenEntry {
            LockScreenEntry(date: Date(), relevance: nil)
        }

        func getSnapshot(in _: Context, completion: @escaping (LockScreenEntry) -> Void) {
            completion(LockScreenEntry(date: Date(), relevance: TimelineEntryRelevance(score: 0.9, duration: 3600)))
        }

        func getTimeline(in _: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
            let entry = LockScreenEntry(date: Date(), relevance: TimelineEntryRelevance(score: 0.9, duration: 3600))
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
        }
    }

    struct LockScreenEntry: TimelineEntry {
        let date: Date
        var relevance: TimelineEntryRelevance?
    }

    struct LockScreenWidgetView: View {
        @Environment(\.widgetFamily) var family
        var entry: LockScreenEntry

        var body: some View {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "sparkles")
                        .font(.title)
                }

            case .accessoryRectangular:
                HStack {
                    Image(systemName: "sparkles")
                    VStack(alignment: .leading) {
                        Text("Thea")
                            .font(.headline)
                        Text("Tap to ask")
                            .font(.caption)
                    }
                }

            case .accessoryInline:
                Label("Ask Thea", systemImage: "sparkles")

            default:
                Text("Thea")
            }
        }
    }
#endif
