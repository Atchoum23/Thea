// LiveActivityManager.swift
// Live Activities support for Dynamic Island and Lock Screen

import Foundation
import OSLog
import Combine

#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Live Activity Manager

/// Manages Live Activities for ongoing AI tasks
@MainActor
public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "LiveActivity")

    // MARK: - Published State

    @Published public private(set) var activeActivities: [String: Any] = [:]
    @Published public private(set) var isSupported = false

    // MARK: - Initialization

    private init() {
        checkSupport()
    }

    private func checkSupport() {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
    }

    // MARK: - Activity Management

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    /// Start a Live Activity for an AI task
    public func startTaskActivity(
        taskId: String,
        title: String,
        description: String,
        progress: Double = 0
    ) async throws -> String {
        guard isSupported else {
            throw LiveActivityError.notSupported
        }

        let attributes = TheaTaskAttributes(
            taskId: taskId,
            title: title
        )

        let contentState = TheaTaskAttributes.ContentState(
            status: .processing,
            progress: progress,
            description: description,
            startTime: Date()
        )

        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )

            activeActivities[taskId] = activity
            logger.info("Started Live Activity for task: \(taskId)")

            return activity.id
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
            throw error
        }
    }

    @available(iOS 16.1, *)
    /// Update a Live Activity
    public func updateActivity(
        taskId: String,
        status: TaskStatus,
        progress: Double,
        description: String
    ) async {
        guard let activity = activeActivities[taskId] as? Activity<TheaTaskAttributes> else {
            logger.warning("No active Live Activity found for task: \(taskId)")
            return
        }

        let contentState = TheaTaskAttributes.ContentState(
            status: status,
            progress: progress,
            description: description,
            startTime: activity.content.state.startTime
        )

        let activityContent = ActivityContent(
            state: contentState,
            staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
        )

        await activity.update(activityContent)
        logger.debug("Updated Live Activity for task: \(taskId)")
    }

    @available(iOS 16.1, *)
    /// End a Live Activity
    public func endActivity(
        taskId: String,
        status: TaskStatus,
        finalMessage: String
    ) async {
        guard let activity = activeActivities[taskId] as? Activity<TheaTaskAttributes> else {
            return
        }

        let finalContent = TheaTaskAttributes.ContentState(
            status: status,
            progress: status == .completed ? 1.0 : activity.content.state.progress,
            description: finalMessage,
            startTime: activity.content.state.startTime
        )

        let activityContent = ActivityContent(
            state: finalContent,
            staleDate: nil
        )

        await activity.end(activityContent, dismissalPolicy: .after(.now + 300)) // Dismiss after 5 mins
        activeActivities.removeValue(forKey: taskId)

        logger.info("Ended Live Activity for task: \(taskId)")
    }

    @available(iOS 16.1, *)
    /// End all Live Activities
    public func endAllActivities() async {
        for (taskId, _) in activeActivities {
            if let activity = activeActivities[taskId] as? Activity<TheaTaskAttributes> {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        activeActivities.removeAll()
        logger.info("Ended all Live Activities")
    }
    #endif

    // MARK: - Convenience Methods

    /// Start activity for conversation generation
    public func startConversationActivity(
        conversationId: String,
        prompt: String
    ) async throws -> String {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return try await startTaskActivity(
                taskId: conversationId,
                title: "Generating Response",
                description: prompt.prefix(50) + (prompt.count > 50 ? "..." : ""),
                progress: 0
            )
        }
        #endif
        throw LiveActivityError.notSupported
    }

    /// Start activity for agent task
    public func startAgentActivity(
        agentId: String,
        agentName: String,
        task: String
    ) async throws -> String {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return try await startTaskActivity(
                taskId: agentId,
                title: "\(agentName) Working",
                description: task,
                progress: 0
            )
        }
        #endif
        throw LiveActivityError.notSupported
    }

    /// Start activity for file processing
    public func startFileProcessingActivity(
        fileId: String,
        fileName: String
    ) async throws -> String {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return try await startTaskActivity(
                taskId: fileId,
                title: "Processing File",
                description: fileName,
                progress: 0
            )
        }
        #endif
        throw LiveActivityError.notSupported
    }
}

// MARK: - Activity Attributes

#if canImport(ActivityKit)
@available(iOS 16.1, *)
public struct TheaTaskAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let status: TaskStatus
        public let progress: Double
        public let description: String
        public let startTime: Date
    }

    public let taskId: String
    public let title: String
}
#endif

// MARK: - Types

public enum TaskStatus: String, Codable {
    case queued
    case processing
    case completed
    case failed
    case cancelled
}

public enum LiveActivityError: Error, LocalizedError {
    case notSupported
    case activityNotFound
    case startFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Live Activities are not supported on this device"
        case .activityNotFound:
            return "Live Activity not found"
        case .startFailed(let reason):
            return "Failed to start Live Activity: \(reason)"
        }
    }
}

// MARK: - SwiftUI Live Activity Views

import SwiftUI

#if canImport(ActivityKit) && canImport(WidgetKit)
import WidgetKit

@available(iOS 16.1, *)
public struct TheaLiveActivityWidget: Widget {
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: TheaTaskAttributes.self) { context in
            // Lock Screen presentation
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded presentation
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(.linear)

                        Text(context.state.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            } compactLeading: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2)
            } minimal: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
            }
        }
    }
}

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TheaTaskAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)

                Text(context.attributes.title)
                    .font(.headline)

                Spacer()

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            ProgressView(value: context.state.progress)
                .progressViewStyle(.linear)

            HStack {
                Text(context.state.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                Text(elapsedTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.8))
    }

    private var statusText: String {
        switch context.state.status {
        case .queued: return "Queued"
        case .processing: return "Processing"
        case .completed: return "Complete"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private var statusColor: Color {
        switch context.state.status {
        case .queued: return .secondary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }

    private var elapsedTime: String {
        let elapsed = Date().timeIntervalSince(context.state.startTime)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: elapsed) ?? ""
    }
}
#endif
