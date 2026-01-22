//
//  TheaLiveActivity.swift
//  Thea
//
//  Live Activities for Dynamic Island and Lock Screen
//

import Foundation
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Attributes

/// Attributes for Thea Live Activities
public struct TheaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state
        public var status: ActivityStatus
        public var progress: Double
        public var message: String
        public var elapsedTime: TimeInterval
        public var remainingTime: TimeInterval?

        public init(
            status: ActivityStatus = .active,
            progress: Double = 0,
            message: String = "",
            elapsedTime: TimeInterval = 0,
            remainingTime: TimeInterval? = nil
        ) {
            self.status = status
            self.progress = progress
            self.message = message
            self.elapsedTime = elapsedTime
            self.remainingTime = remainingTime
        }
    }

    // Static attributes
    public var activityType: ActivityType
    public var title: String
    public var startTime: Date

    public init(activityType: ActivityType, title: String, startTime: Date = Date()) {
        self.activityType = activityType
        self.title = title
        self.startTime = startTime
    }
}

// MARK: - Activity Types

public enum ActivityType: String, Codable, Sendable {
    case aiProcessing = "ai_processing"
    case focusSession = "focus_session"
    case fileTransfer = "file_transfer"
    case codeGeneration = "code_generation"
    case healthTracking = "health_tracking"
    case reminder = "reminder"
}

public enum ActivityStatus: String, Codable, Sendable {
    case active
    case paused
    case completed
    case failed
}

// MARK: - Live Activity Manager

@MainActor
public class TheaLiveActivityManager: ObservableObject {
    public static let shared = TheaLiveActivityManager()

    @Published public private(set) var activeActivities: [String: Activity<TheaActivityAttributes>] = [:]

    private init() {}

    // MARK: - Start Activity

    /// Start a new Live Activity
    public func startActivity(
        type: ActivityType,
        title: String,
        initialMessage: String = ""
    ) async throws -> String {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notEnabled
        }

        let attributes = TheaActivityAttributes(
            activityType: type,
            title: title
        )

        let initialState = TheaActivityAttributes.ContentState(
            status: .active,
            progress: 0,
            message: initialMessage,
            elapsedTime: 0
        )

        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil),
            pushType: nil
        )

        activeActivities[activity.id] = activity
        return activity.id
    }

    // MARK: - Update Activity

    /// Update an existing Live Activity
    public func updateActivity(
        id: String,
        status: ActivityStatus? = nil,
        progress: Double? = nil,
        message: String? = nil,
        elapsedTime: TimeInterval? = nil,
        remainingTime: TimeInterval? = nil
    ) async {
        guard let activity = activeActivities[id] else { return }

        let currentState = activity.content.state
        let newState = TheaActivityAttributes.ContentState(
            status: status ?? currentState.status,
            progress: progress ?? currentState.progress,
            message: message ?? currentState.message,
            elapsedTime: elapsedTime ?? currentState.elapsedTime,
            remainingTime: remainingTime ?? currentState.remainingTime
        )

        await activity.update(
            ActivityContent(state: newState, staleDate: nil)
        )
    }

    // MARK: - End Activity

    /// End a Live Activity
    public func endActivity(
        id: String,
        finalStatus: ActivityStatus = .completed,
        finalMessage: String? = nil
    ) async {
        guard let activity = activeActivities[id] else { return }

        let finalState = TheaActivityAttributes.ContentState(
            status: finalStatus,
            progress: finalStatus == .completed ? 1.0 : activity.content.state.progress,
            message: finalMessage ?? activity.content.state.message,
            elapsedTime: activity.content.state.elapsedTime
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .default
        )

        activeActivities.removeValue(forKey: id)
    }

    // MARK: - Convenience Methods

    /// Start an AI processing activity
    public func startAIProcessing(task: String) async throws -> String {
        try await startActivity(
            type: .aiProcessing,
            title: "AI Processing",
            initialMessage: task
        )
    }

    /// Start a focus session activity
    public func startFocusSession(duration: TimeInterval, task: String?) async throws -> String {
        try await startActivity(
            type: .focusSession,
            title: task ?? "Focus Session",
            initialMessage: "Time remaining: \(Int(duration / 60)) min"
        )
    }

    /// Start a code generation activity
    public func startCodeGeneration(description: String) async throws -> String {
        try await startActivity(
            type: .codeGeneration,
            title: "Code Generation",
            initialMessage: description
        )
    }

    // MARK: - Query Activities

    /// Get all active activities
    public func getAllActivities() -> [Activity<TheaActivityAttributes>] {
        Activity<TheaActivityAttributes>.activities
    }

    /// Check if any activities are running
    public var hasActiveActivities: Bool {
        !activeActivities.isEmpty
    }
}

// MARK: - Errors

public enum LiveActivityError: Error, LocalizedError {
    case notEnabled
    case notSupported
    case startFailed
    case activityNotFound

    public var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "Live Activities are not enabled. Enable them in Settings > Thea"
        case .notSupported:
            return "Live Activities are not supported on this device"
        case .startFailed:
            return "Failed to start Live Activity"
        case .activityNotFound:
            return "Activity not found"
        }
    }
}

// MARK: - Live Activity Widget

@available(iOS 16.1, *)
public struct TheaLiveActivityWidget: Widget {
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: TheaActivityAttributes.self) { context in
            // Lock Screen / Banner presentation
            TheaLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded presentation
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.activityType.icon, systemImage: context.attributes.activityType.iconName)
                        .font(.caption)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        ProgressView(value: context.state.progress)
                            .tint(context.state.status.color)

                        if let remaining = context.state.remainingTime {
                            Text(formatTime(remaining))
                                .font(.caption2.monospacedDigit())
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.activityType.iconName)
                    .foregroundStyle(context.state.status.color)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: context.attributes.activityType.iconName)
                    .foregroundStyle(context.state.status.color)
            }
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Live Activity View

struct TheaLiveActivityView: View {
    let context: ActivityViewContext<TheaActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: context.attributes.activityType.iconName)
                .font(.title2)
                .foregroundStyle(context.state.status.color)
                .frame(width: 44)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)

                Text(context.state.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: context.state.progress)
                    .tint(context.state.status.color)
            }

            Spacer()

            // Status
            VStack(alignment: .trailing) {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.title3.monospacedDigit().bold())

                if let remaining = context.state.remainingTime {
                    Text(formatTime(remaining))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Extensions

extension ActivityType {
    var icon: String {
        switch self {
        case .aiProcessing: return "🤖"
        case .focusSession: return "🎯"
        case .fileTransfer: return "📁"
        case .codeGeneration: return "💻"
        case .healthTracking: return "❤️"
        case .reminder: return "🔔"
        }
    }

    var iconName: String {
        switch self {
        case .aiProcessing: return "brain"
        case .focusSession: return "timer"
        case .fileTransfer: return "arrow.up.arrow.down"
        case .codeGeneration: return "chevron.left.forwardslash.chevron.right"
        case .healthTracking: return "heart.fill"
        case .reminder: return "bell.fill"
        }
    }
}

extension ActivityStatus {
    var color: Color {
        switch self {
        case .active: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}
