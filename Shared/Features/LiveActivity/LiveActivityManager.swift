// LiveActivityManager.swift
// Live Activities support for Dynamic Island and Lock Screen

import Combine
import Foundation
import OSLog

#if os(iOS)
    import ActivityKit
#endif

// MARK: - Live Activity Manager

/// Manages Live Activities for ongoing AI tasks
@MainActor
public final class LiveActivityManager: ObservableObject {
    public static let shared = LiveActivityManager()

    // periphery:ignore - Reserved: logger property reserved for future feature activation
    private let logger = Logger(subsystem: "com.thea.app", category: "LiveActivity")

    // MARK: - Published State

    @Published public private(set) var activeActivities: [String: Any] = [:]
    @Published public private(set) var isSupported = false

    // MARK: - Initialization

    private init() {
        checkSupport()
    }

    private func checkSupport() {
        #if os(iOS)
            if #available(iOS 16.1, *) {
                isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
            }
        #endif
    }

    // MARK: - Activity Management

    #if os(iOS)
        /// Start a Live Activity for an AI task
        @available(iOS 16.1, *)
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

        /// Update a Live Activity
        @available(iOS 16.1, *)
        public func updateActivity(
            taskId: String,
            status: LiveActivityTaskStatus,
            progress: Double,
            description: String
        ) async {
            guard let activity = activeActivities[taskId] as? Activity<TheaTaskAttributes> else {
                logger.warning("No active Live Activity found for task: \(taskId)")
                return
            }

            // Capture state before async operation
            let startTime = activity.content.state.startTime
            let contentState = TheaTaskAttributes.ContentState(
                status: status,
                progress: progress,
                description: description,
                startTime: startTime
            )

            let activityContent = ActivityContent(
                state: contentState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            )

            // Use Task to perform async update
            let activityToUpdate = activity
            Task { @MainActor in
                await activityToUpdate.update(activityContent)
            }
            logger.debug("Updated Live Activity for task: \(taskId)")
        }

        /// End a Live Activity
        @available(iOS 16.1, *)
        public func endActivity(
            taskId: String,
            status: LiveActivityTaskStatus,
            finalMessage: String
        ) async {
            guard let activity = activeActivities[taskId] as? Activity<TheaTaskAttributes> else {
                return
            }

            // Capture state before async operation
            let currentProgress = activity.content.state.progress
            let startTime = activity.content.state.startTime
            let finalContent = TheaTaskAttributes.ContentState(
                status: status,
                progress: status == .completed ? 1.0 : currentProgress,
                description: finalMessage,
                startTime: startTime
            )

            let activityContent = ActivityContent(
                state: finalContent,
                staleDate: nil
            )

            // Use Task to perform async end
            let activityToEnd = activity
            Task { @MainActor in
                await activityToEnd.end(activityContent, dismissalPolicy: .after(.now + 300)) // Dismiss after 5 mins
            }
            activeActivities.removeValue(forKey: taskId)

            logger.info("Ended Live Activity for task: \(taskId)")
        }

        /// End all Live Activities
        @available(iOS 16.1, *)
        public func endAllActivities() async {
            for (taskId, _) in activeActivities {
                if let activity = activeActivities[taskId] as? Activity<TheaTaskAttributes> {
                    let activityToEnd = activity
                    Task { @MainActor in
                        await activityToEnd.end(nil, dismissalPolicy: .immediate)
                    }
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
        #if os(iOS)
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
        #if os(iOS)
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
        #if os(iOS)
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

#if os(iOS)
    @available(iOS 16.1, *)
    public struct TheaTaskAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            public let status: LiveActivityTaskStatus
            public let progress: Double
            public let description: String
            public let startTime: Date
        }

        public let taskId: String
        public let title: String
    }
#endif

// MARK: - Types

public enum LiveActivityTaskStatus: String, Codable, Sendable {
    case queued
    case processing
    case completed
    case failed
    case cancelled
}

// MARK: - Errors

/// Errors for Live Activity operations
public enum LiveActivityError: Error, LocalizedError {
    case notEnabled
    case notSupported
    case startFailed
    case activityNotFound

    public var errorDescription: String? {
        switch self {
        case .notEnabled:
            "Live Activities are not enabled. Enable them in Settings > Thea"
        case .notSupported:
            "Live Activities are not supported on this device or platform"
        case .startFailed:
            "Failed to start Live Activity"
        case .activityNotFound:
            "Activity not found"
        }
    }
}

// Note: TheaLiveActivityWidget and LockScreenLiveActivityView are defined in TheaLiveActivity.swift
