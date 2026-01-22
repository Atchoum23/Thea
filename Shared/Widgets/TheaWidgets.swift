//
//  TheaWidgets.swift
//  Thea
//
//  Enhanced Widget support for all platforms
//  iOS, iPadOS, macOS, watchOS, tvOS
//

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Widget Entry

struct TheaWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: TheaWidgetConfiguration
    let data: WidgetData
}

struct TheaWidgetConfiguration {
    var showAIStatus: Bool = true
    var showQuickActions: Bool = true
    var selectedConversation: String?
}

struct WidgetData {
    var aiStatus: AIStatus = .ready
    var unreadMessages: Int = 0
    var activeTasks: Int = 0
    var focusTimeToday: TimeInterval = 0
    var lastConversationPreview: String?
    var healthScore: Int?
    var quickSuggestions: [String] = []

    enum AIStatus: String {
        case ready = "Ready"
        case processing = "Processing"
        case offline = "Offline"

        var icon: String {
            switch self {
            case .ready: return "checkmark.circle.fill"
            case .processing: return "arrow.clockwise"
            case .offline: return "wifi.slash"
            }
        }

        var color: Color {
            switch self {
            case .ready: return .green
            case .processing: return .blue
            case .offline: return .gray
            }
        }
    }
}

// MARK: - Timeline Provider

struct TheaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TheaWidgetEntry {
        TheaWidgetEntry(
            date: Date(),
            configuration: TheaWidgetConfiguration(),
            data: WidgetData()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TheaWidgetEntry) -> Void) {
        let entry = TheaWidgetEntry(
            date: Date(),
            configuration: TheaWidgetConfiguration(),
            data: WidgetData(
                aiStatus: .ready,
                unreadMessages: 3,
                activeTasks: 5,
                focusTimeToday: 7200,
                lastConversationPreview: "How can I help you today?",
                healthScore: 85,
                quickSuggestions: ["Write code", "Summarize", "Translate"]
            )
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TheaWidgetEntry>) -> Void) {
        // Fetch actual data from shared container
        let data = loadWidgetData()
        let entry = TheaWidgetEntry(
            date: Date(),
            configuration: TheaWidgetConfiguration(),
            data: data
        )

        // Refresh every 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func loadWidgetData() -> WidgetData {
        // Load from UserDefaults shared with app group
        let defaults = UserDefaults(suiteName: "group.app.theathe")
        return WidgetData(
            aiStatus: .ready,
            unreadMessages: defaults?.integer(forKey: "widget.unreadMessages") ?? 0,
            activeTasks: defaults?.integer(forKey: "widget.activeTasks") ?? 0,
            focusTimeToday: defaults?.double(forKey: "widget.focusTimeToday") ?? 0,
            lastConversationPreview: defaults?.string(forKey: "widget.lastConversation"),
            healthScore: defaults?.integer(forKey: "widget.healthScore"),
            quickSuggestions: defaults?.stringArray(forKey: "widget.suggestions") ?? []
        )
    }
}

// MARK: - Main Widget

struct TheaWidget: Widget {
    let kind: String = "app.thea.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TheaWidgetProvider()) { entry in
            TheaWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Thea")
        .description("Quick access to Thea AI assistant")
        .supportedFamilies(supportedFamilies)
        #if os(watchOS)
        .supplementalActivityFamilies([.small, .medium])
        #endif
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(watchOS)
        return [.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner]
        #elseif os(iOS)
        return [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #elseif os(macOS)
        return [.systemSmall, .systemMedium, .systemLarge]
        #else
        return [.systemSmall, .systemMedium]
        #endif
    }
}

// MARK: - Widget Views

struct TheaWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TheaWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .systemExtraLarge:
            ExtraLargeWidgetView(entry: entry)
        case .accessoryCircular:
            CircularAccessoryView(entry: entry)
        case .accessoryRectangular:
            RectangularAccessoryView(entry: entry)
        case .accessoryInline:
            InlineAccessoryView(entry: entry)
        #if os(watchOS)
        case .accessoryCorner:
            CornerAccessoryView(entry: entry)
        #endif
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Spacer()

                Image(systemName: entry.data.aiStatus.icon)
                    .foregroundStyle(entry.data.aiStatus.color)
            }

            Spacer()

            Text("Thea")
                .font(.headline)

            Text(entry.data.lastConversationPreview ?? "Tap to start chatting")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Status
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    Text("Thea")
                        .font(.headline)
                }

                Spacer()

                StatusRow(icon: "message.fill", value: "\(entry.data.unreadMessages)", label: "Messages")
                StatusRow(icon: "checkmark.circle.fill", value: "\(entry.data.activeTasks)", label: "Tasks")
                StatusRow(icon: "timer", value: formatTime(entry.data.focusTimeToday), label: "Focus")
            }

            Divider()

            // Right side - Quick Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(entry.data.quickSuggestions.prefix(3), id: \.self) { suggestion in
                    Link(destination: URL(string: "thea://ask?q=\(suggestion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                            Text(suggestion)
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                }

                Spacer()
            }
        }
        .padding()
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .font(.title)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text("Thea")
                        .font(.headline)
                    Text(entry.data.aiStatus.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let score = entry.data.healthScore {
                    VStack {
                        Text("\(score)")
                            .font(.title2.bold())
                        Text("Health")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(icon: "message.fill", value: "\(entry.data.unreadMessages)", label: "Messages", color: .blue)
                StatCard(icon: "checkmark.circle.fill", value: "\(entry.data.activeTasks)", label: "Active Tasks", color: .green)
                StatCard(icon: "timer", value: formatTime(entry.data.focusTimeToday), label: "Focus Today", color: .orange)
                StatCard(icon: "brain", value: entry.data.aiStatus.rawValue, label: "AI Status", color: entry.data.aiStatus.color)
            }

            Divider()

            // Quick Actions
            Text("Quick Actions")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                QuickActionButton(icon: "bubble.left.fill", label: "Ask")
                QuickActionButton(icon: "doc.text", label: "Summarize")
                QuickActionButton(icon: "globe", label: "Translate")
                QuickActionButton(icon: "timer", label: "Focus")
            }
        }
        .padding()
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Extra Large Widget (iPad)

struct ExtraLargeWidgetView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        HStack(spacing: 20) {
            // Left Column
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading) {
                        Text("Thea AI Assistant")
                            .font(.title2.bold())
                        Text("Status: \(entry.data.aiStatus.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Conversation Preview
                if let preview = entry.data.lastConversationPreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Conversation")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Text(preview)
                            .font(.body)
                            .lineLimit(4)
                    }
                }

                Spacer()
            }

            Divider()

            // Right Column - Stats & Actions
            VStack(spacing: 16) {
                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(icon: "message.fill", value: "\(entry.data.unreadMessages)", label: "Messages", color: .blue)
                    StatCard(icon: "checkmark.circle.fill", value: "\(entry.data.activeTasks)", label: "Tasks", color: .green)
                }

                Divider()

                // Quick Actions Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    QuickActionButton(icon: "bubble.left.fill", label: "Ask")
                    QuickActionButton(icon: "doc.text", label: "Summarize")
                    QuickActionButton(icon: "globe", label: "Translate")
                    QuickActionButton(icon: "timer", label: "Focus")
                    QuickActionButton(icon: "house.fill", label: "Home")
                    QuickActionButton(icon: "heart.fill", label: "Health")
                }
            }
        }
        .padding()
    }
}

// MARK: - Accessory Views (Lock Screen / Watch)

struct CircularAccessoryView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "brain")
                .font(.title2)
        }
    }
}

struct RectangularAccessoryView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        HStack {
            Image(systemName: "brain")
                .font(.title3)

            VStack(alignment: .leading) {
                Text("Thea")
                    .font(.headline)
                Text("\(entry.data.unreadMessages) messages")
                    .font(.caption)
            }
        }
    }
}

struct InlineAccessoryView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        HStack {
            Image(systemName: "brain")
            Text("Thea • \(entry.data.unreadMessages) messages")
        }
    }
}

#if os(watchOS)
struct CornerAccessoryView: View {
    let entry: TheaWidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "brain")
                .font(.title3)
        }
        .widgetLabel {
            Text("\(entry.data.unreadMessages)")
        }
    }
}
#endif

// MARK: - Helper Views

struct StatusRow: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.bold())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String

    var body: some View {
        Link(destination: URL(string: "thea://action/\(label.lowercased())")!) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Widget Bundle

@main
struct TheaWidgetBundle: WidgetBundle {
    var body: some Widget {
        TheaWidget()

        #if os(iOS)
        if #available(iOS 16.1, *) {
            TheaLiveActivityWidget()
        }
        #endif

        #if os(iOS) && swift(>=5.9)
        if #available(iOS 18.0, *) {
            TheaControlWidgetBundle()
        }
        #endif
    }
}
