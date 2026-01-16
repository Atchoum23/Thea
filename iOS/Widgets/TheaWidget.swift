import SwiftData
import SwiftUI
import WidgetKit

struct TheaWidget: Widget {
    let kind: String = "TheaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TheaWidgetProvider()) { entry in
            TheaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("THEA")
        .description("Quick access to your AI companion")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TheaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TheaWidgetEntry {
        TheaWidgetEntry(
            date: Date(),
            recentConversations: [],
            totalConversations: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TheaWidgetEntry) -> Void) {
        let entry = TheaWidgetEntry(
            date: Date(),
            recentConversations: [],
            totalConversations: 0
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TheaWidgetEntry>) -> Void) {
        Task {
            let entry = await fetchWidgetData()
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3_600)))
            completion(timeline)
        }
    }

    private func fetchWidgetData() async -> TheaWidgetEntry {
        do {
            let schema = Schema([Conversation.self, Message.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<Conversation>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            let conversations = try context.fetch(descriptor)

            let recentConversations = Array(conversations.prefix(3)).map { conversation in
                ConversationSummary(
                    id: conversation.id,
                    title: conversation.title,
                    lastMessage: conversation.messages.last?.content ?? "",
                    updatedAt: conversation.updatedAt
                )
            }

            return TheaWidgetEntry(
                date: Date(),
                recentConversations: recentConversations,
                totalConversations: conversations.count
            )
        } catch {
            return TheaWidgetEntry(
                date: Date(),
                recentConversations: [],
                totalConversations: 0
            )
        }
    }
}

struct TheaWidgetEntry: TimelineEntry {
    let date: Date
    let recentConversations: [ConversationSummary]
    let totalConversations: Int
}

struct ConversationSummary: Identifiable {
    let id: UUID
    let title: String
    let lastMessage: String
    let updatedAt: Date
}

struct TheaWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: TheaWidgetProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundStyle(.theaPrimary)

            Text("THEA")
                .font(.headline)
                .fontWeight(.bold)

            if entry.totalConversations > 0 {
                Text("\(entry.totalConversations)")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.theaPrimary)

                Text(entry.totalConversations == 1 ? "conversation" : "conversations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start chatting")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .widgetURL(URL(string: "thea://new-conversation"))
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(.theaPrimary)

                Text("THEA")
                    .font(.headline)
                    .fontWeight(.bold)

                if entry.totalConversations > 0 {
                    Text("\(entry.totalConversations)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.theaPrimary)
                }
            }
            .frame(maxWidth: 120)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if entry.recentConversations.isEmpty {
                    Text("No conversations yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.recentConversations.prefix(2)) { conversation in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)

                                Text(conversation.lastMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .widgetURL(URL(string: "thea://conversations"))
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundStyle(.theaPrimary)

                Text("THEA")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.totalConversations)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.theaPrimary)

                    Text(entry.totalConversations == 1 ? "conversation" : "conversations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if entry.recentConversations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No conversations yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Tap to start chatting")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Conversations")
                        .font(.headline)

                    ForEach(entry.recentConversations) { conversation in
                        Link(destination: URL(string: "thea://conversation/\(conversation.id.uuidString)")!) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(conversation.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(conversation.updatedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                Text(conversation.lastMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(12)
                            .background(Color(uiColor: .systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }

            Spacer()

            HStack {
                Link(destination: URL(string: "thea://new-conversation")!) {
                    Label("New Chat", systemImage: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.theaPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}
