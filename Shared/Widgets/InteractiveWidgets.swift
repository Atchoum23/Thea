//
//  InteractiveWidgets.swift
//  Thea
//
//  Created by Thea
//  iOS 17+ Interactive Widgets and StandBy Mode support
//

#if canImport(WidgetKit)
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Interactive Widget Intents (iOS 17+)

/// Intent for toggling focus mode from widget
@available(iOS 17.0, macOS 14.0, *)
public struct ToggleFocusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Focus"
    public static let description = IntentDescription("Toggle Thea focus mode")

    public init() {}

    public func perform() async throws -> some IntentResult {
        // Toggle focus state in shared container
        let defaults = UserDefaults(suiteName: "group.app.theathe")
        let currentState = defaults?.bool(forKey: "widget.focusActive") ?? false
        defaults?.set(!currentState, forKey: "widget.focusActive")

        // Reload timeline
        WidgetCenter.shared.reloadTimelines(ofKind: "app.thea.widget")

        return .result()
    }
}

/// Intent for quick actions from widget
@available(iOS 17.0, macOS 14.0, *)
public struct QuickActionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Quick Action"
    public static let description = IntentDescription("Perform a quick Thea action")

    @Parameter(title: "Action")
    public var actionName: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Perform \(\.$actionName)")
    }

    public init() {}

    public init(actionName: String) {
        self.actionName = actionName
    }

    public func perform() async throws -> some IntentResult & OpensIntent {
        // Open the app with the specified action
        .result(opensIntent: OpenTheaWithActionIntent(action: actionName))
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct OpenTheaWithActionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Thea"
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Action")
    public var action: String

    public init() {
        action = "default"
    }

    public init(action: String) {
        self.action = action
    }

    public func perform() async throws -> some IntentResult {
        // The app will handle the action via URL scheme or notification
        NotificationCenter.default.post(
            name: Notification.Name("theaWidgetAction"),
            object: nil,
            userInfo: ["action": action]
        )
        return .result()
    }
}

/// Intent for sending a quick message from widget
@available(iOS 17.0, macOS 14.0, *)
public struct SendQuickMessageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Send Quick Message"
    public static let description = IntentDescription("Send a quick message to Thea")

    @Parameter(title: "Message")
    public var message: String?

    public init() {}

    public func perform() async throws -> some IntentResult & OpensIntent {
        let msg = message ?? ""
        return .result(opensIntent: OpenTheaWithMessageIntent(message: msg))
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct OpenTheaWithMessageIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Thea with Message"
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Message")
    public var message: String

    public init() {
        message = ""
    }

    public init(message: String) {
        self.message = message
    }

    public func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: Notification.Name("theaQuickMessage"),
            object: nil,
            userInfo: ["message": message]
        )
        return .result()
    }
}

// MARK: - StandBy Mode Optimized Widget

/// Widget entry optimized for StandBy Mode
struct StandByWidgetEntry: TimelineEntry {
    let date: Date
    let isStandBy: Bool
    let status: StandByStatus
    let recentActivity: String?
    let suggestedAction: String?
}

enum StandByStatus: String {
    case ready = "Ready"
    case processing = "Processing"
    case hasNotification = "New Message"

    var color: Color {
        switch self {
        case .ready: .green
        case .processing: .blue
        case .hasNotification: .orange
        }
    }

    var icon: String {
        switch self {
        case .ready: "checkmark.circle.fill"
        case .processing: "arrow.clockwise"
        case .hasNotification: "bell.badge.fill"
        }
    }
}

struct StandByWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> StandByWidgetEntry {
        StandByWidgetEntry(
            date: Date(),
            isStandBy: false /* iOS 17.4+ */,
            status: .ready,
            recentActivity: nil,
            suggestedAction: nil
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (StandByWidgetEntry) -> Void) {
        let entry = StandByWidgetEntry(
            date: Date(),
            isStandBy: false /* iOS 17.4+ */,
            status: .ready,
            recentActivity: "Last: Summarized document",
            suggestedAction: "Ask Thea"
        )
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<StandByWidgetEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.app.theathe")

        let status: StandByStatus = if defaults?.bool(forKey: "widget.hasNotification") == true {
            .hasNotification
        } else if defaults?.bool(forKey: "widget.isProcessing") == true {
            .processing
        } else {
            .ready
        }

        let entry = StandByWidgetEntry(
            date: Date(),
            isStandBy: false, // false /* iOS 17.4+ */ is iOS 17.4+
            status: status,
            recentActivity: defaults?.string(forKey: "widget.lastActivity"),
            suggestedAction: defaults?.string(forKey: "widget.suggestedAction")
        )

        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

// MARK: - StandBy Widget Views

/// StandBy Mode optimized widget view
struct StandByWidgetView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.showsWidgetContainerBackground) var showsBackground
    let entry: StandByWidgetEntry

    var body: some View {
        Group {
            if entry.isStandBy {
                // StandBy mode - simplified, high contrast view
                standByView
            } else {
                // Normal view
                normalView
            }
        }
    }

    @ViewBuilder
    private var standByView: some View {
        VStack(spacing: 16) {
            // Large status icon
            Image(systemName: entry.status.icon)
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(entry.status.color)

            // Status text
            Text(entry.status.rawValue)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            // Time
            Text(entry.date, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private var normalView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text("Thea")
                    .font(.headline)

                Spacer()

                Image(systemName: entry.status.icon)
                    .foregroundStyle(entry.status.color)
            }

            Spacer()

            // Recent activity
            if let activity = entry.recentActivity {
                Text(activity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Interactive button (iOS 17+)
            if #available(iOS 17.0, macOS 14.0, *) {
                Button(intent: OpenTheaWithActionIntent(action: "quickAsk")) {
                    HStack {
                        Image(systemName: "bubble.left.fill")
                        Text(entry.suggestedAction ?? "Ask Thea")
                    }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

// MARK: - Interactive Large Widget (iOS 17+)

@available(iOS 17.0, macOS 14.0, *)
// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct InteractiveLargeWidgetView: View {
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

                // Focus toggle button
                Button(intent: ToggleFocusIntent()) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .padding(8)
                        .background(.orange.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Stats Grid with interactive elements
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                InteractiveStatCard(
                    icon: "message.fill",
                    value: "\(entry.data.unreadMessages)",
                    label: "Messages",
                    color: .blue,
                    intent: OpenTheaWithActionIntent(action: "messages")
                )

                InteractiveStatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(entry.data.activeTasks)",
                    label: "Tasks",
                    color: .green,
                    intent: OpenTheaWithActionIntent(action: "tasks")
                )
            }

            Divider()

            // Quick action buttons
            Text("Quick Actions")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                InteractiveActionButton(
                    icon: "bubble.left.fill",
                    label: "Ask",
                    color: .blue,
                    intent: OpenTheaWithActionIntent(action: "quickAsk")
                )

                InteractiveActionButton(
                    icon: "doc.text",
                    label: "Summarize",
                    color: .purple,
                    intent: OpenTheaWithActionIntent(action: "summarize")
                )

                InteractiveActionButton(
                    icon: "globe",
                    label: "Translate",
                    color: .orange,
                    intent: OpenTheaWithActionIntent(action: "translate")
                )

                InteractiveActionButton(
                    icon: "mic.fill",
                    label: "Voice",
                    color: .pink,
                    intent: OpenTheaWithActionIntent(action: "voice")
                )
            }
        }
        .padding()
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct InteractiveStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let intent: OpenTheaWithActionIntent

    var body: some View {
        Button(intent: intent) {
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
        .buttonStyle(.plain)
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct InteractiveActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let intent: OpenTheaWithActionIntent

    var body: some View {
        Button(intent: intent) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - StandBy Widget Definition

struct TheaStandByWidget: Widget {
    let kind: String = "app.thea.standby"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StandByWidgetProvider()) { entry in
            StandByWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Thea StandBy")
        .description("Optimized for StandBy Mode")
        .supportedFamilies(supportedFamilies)
        #if os(iOS)
            .disfavoredLocations([.homeScreen], for: supportedFamilies)
        #endif
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
            return [.systemSmall, .systemMedium]
        #else
            return [.systemSmall]
        #endif
    }
}

// MARK: - Enhanced Widget Bundle

/// Extended widget bundle including interactive widgets
@available(iOS 17.0, macOS 14.0, *)
// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct TheaInteractiveWidgetBundle: WidgetBundle {
    var body: some Widget {
        TheaWidget()
        TheaStandByWidget()

        #if os(iOS)
            if #available(iOS 16.1, *) {
                TheaLiveActivityWidget()
            }
        #endif
    }
}
#endif // canImport(WidgetKit)
