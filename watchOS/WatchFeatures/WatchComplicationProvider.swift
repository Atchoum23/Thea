//
//  WatchComplicationProvider.swift
//  Thea watchOS
//
//  Watch complications and Smart Stack integration
//

import ClockKit
import SwiftUI
import WidgetKit

// MARK: - Complication Entry

struct TheaComplicationEntry: TimelineEntry {
    let date: Date
    let data: ComplicationData
}

struct ComplicationData {
    var unreadCount: Int = 0
    var aiStatus: String = "Ready"
    var lastMessage: String?
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    var focusTimeRemaining: TimeInterval?
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    var healthScore: Int?
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    var nextReminder: Date?
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    var quickAction: String = "Ask"
}

// MARK: - Complication Provider

struct TheaComplicationProvider: TimelineProvider {
    func placeholder(in _: Context) -> TheaComplicationEntry {
        TheaComplicationEntry(date: Date(), data: ComplicationData())
    }

    func getSnapshot(in _: Context, completion: @escaping (TheaComplicationEntry) -> Void) {
        let entry = TheaComplicationEntry(
            date: Date(),
            data: ComplicationData(
                unreadCount: 3,
                aiStatus: "Ready",
                lastMessage: "How can I help?",
                healthScore: 85
            )
        )
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<TheaComplicationEntry>) -> Void) {
        let data = loadComplicationData()
        let entry = TheaComplicationEntry(date: Date(), data: data)

        // Refresh every 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func loadComplicationData() -> ComplicationData {
        let defaults = UserDefaults(suiteName: "group.app.theathe")
        return ComplicationData(
            unreadCount: defaults?.integer(forKey: "watch.unreadCount") ?? 0,
            aiStatus: defaults?.string(forKey: "watch.aiStatus") ?? "Ready",
            lastMessage: defaults?.string(forKey: "watch.lastMessage"),
            healthScore: defaults?.integer(forKey: "watch.healthScore")
        )
    }
}

// MARK: - Complication Widget

// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct TheaComplicationWidget: Widget {
    let kind = "app.thea.complication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TheaComplicationProvider()) { entry in
            TheaComplicationView(entry: entry)
        }
        .configurationDisplayName("Thea")
        .description("Quick access to Thea AI")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Complication Views

struct TheaComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: TheaComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

struct CircularComplicationView: View {
    let entry: TheaComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 2) {
                Image(systemName: "brain")
                    .font(.system(size: 18))

                if entry.data.unreadCount > 0 {
                    Text("\(entry.data.unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
    }
}

struct RectangularComplicationView: View {
    let entry: TheaComplicationEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Thea")
                    .font(.headline)

                if let message = entry.data.lastMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(entry.data.aiStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if entry.data.unreadCount > 0 {
                Text("\(entry.data.unreadCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue, in: Capsule())
            }
        }
    }
}

struct InlineComplicationView: View {
    let entry: TheaComplicationEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "brain")

            if entry.data.unreadCount > 0 {
                Text("Thea • \(entry.data.unreadCount) new")
            } else {
                Text("Thea • \(entry.data.aiStatus)")
            }
        }
    }
}

struct CornerComplicationView: View {
    let entry: TheaComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "brain")
                .font(.system(size: 20))
        }
        .widgetLabel {
            if entry.data.unreadCount > 0 {
                Text("\(entry.data.unreadCount)")
            } else {
                Text("Ask")
            }
        }
    }
}

// MARK: - Smart Stack Relevant Context

// Note: RelevantIntent/RelevantContext require AppIntents framework
// and are available in iOS 17+/watchOS 10+. Implementation deferred
// until full App Intents integration is complete.

// MARK: - Double Tap Support

extension View {
    /// Add Double Tap gesture support for primary action
    /// Note: watchOS 10+ supports handGestureShortcut for Double Tap
    @ViewBuilder
    func theaDoubleTapAction(action: @escaping () -> Void) -> some View {
        if #available(watchOS 10.0, *) {
            self.onTapGesture(count: 2, perform: action)
        } else {
            onTapGesture(perform: action)
        }
    }
}

// MARK: - Watch Quick Actions

// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct WatchQuickActionsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                QuickActionButton(
                    title: "Ask Thea",
                    icon: "bubble.left.fill",
                    color: .blue
                ) {
                    // Open ask view
                }
                .theaDoubleTapAction { /* Primary double tap action */ }

                QuickActionButton(
                    title: "Daily Summary",
                    icon: "chart.bar.fill",
                    color: .green
                ) {
                    // Show summary
                }

                QuickActionButton(
                    title: "Focus Mode",
                    icon: "timer",
                    color: .orange
                ) {
                    // Start focus
                }

                QuickActionButton(
                    title: "Health Check",
                    icon: "heart.fill",
                    color: .red
                ) {
                    // Show health
                }
            }
            .padding()
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Text(title)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
