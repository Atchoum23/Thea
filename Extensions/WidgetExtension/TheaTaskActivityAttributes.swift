//
//  TheaTaskActivityAttributes.swift
//  TheaWidgetExtension
//
//  AAB3-2: ActivityKit Live Activities — surfaces agent task progress on Lock Screen / Dynamic Island.
//  Wire: AgentOrchestrator.startTask() → Activity<TheaTaskActivityAttributes>.request(...)
//

import ActivityKit
import Foundation

// MARK: - TheaTaskActivityAttributes

/// Attributes for a Thea agent task Live Activity.
/// Static context: sessionId (does not change for the lifetime of the activity).
/// Dynamic content: ContentState (updates as the task progresses).
struct TheaTaskActivityAttributes: ActivityAttributes {
    // MARK: - Dynamic Content

    struct ContentState: Codable, Hashable {
        /// Short task name shown on Lock Screen.
        var taskName: String
        /// Progress 0.0–1.0 (drives progress indicator).
        var progress: Double
        /// Current phase label: "Planning", "Executing", "Verifying", "Done".
        var phase: String
        /// Emoji status icon: ⏳ / ⚙️ / ✅ / ❌
        var statusEmoji: String
        /// Optional short detail message.
        var detail: String?

        static let placeholder = ContentState(
            taskName: "Preparing…",
            progress: 0.0,
            phase: "Planning",
            statusEmoji: "⏳",
            detail: nil
        )
    }

    // MARK: - Static Attributes

    /// Stable session identifier for the agent run.
    var sessionId: String
    /// Human-readable goal description set at session start.
    var goal: String
}

// MARK: - LiveActivityManager

/// Thin wrapper that starts / updates / ends a Thea task Live Activity.
@MainActor
final class TheaTaskLiveActivityManager {
    static let shared = TheaTaskLiveActivityManager()

    private var activity: Activity<TheaTaskActivityAttributes>?

    private init() {}

    // MARK: - Start

    func startActivity(sessionId: String, goal: String, taskName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TheaTaskActivityAttributes(sessionId: sessionId, goal: goal)
        let state = TheaTaskActivityAttributes.ContentState(
            taskName: taskName,
            progress: 0.05,
            phase: "Planning",
            statusEmoji: "⏳",
            detail: nil
        )

        do {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(3600))
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            // Non-fatal: Live Activities may not be available in all contexts
        }
    }

    // MARK: - Update

    func updateActivity(progress: Double, phase: String, statusEmoji: String, detail: String? = nil, taskName: String? = nil) async {
        guard let activity else { return }
        let currentState = activity.content.state
        let newState = TheaTaskActivityAttributes.ContentState(
            taskName: taskName ?? currentState.taskName,
            progress: progress,
            phase: phase,
            statusEmoji: statusEmoji,
            detail: detail
        )
        await activity.update(ActivityContent(state: newState, staleDate: Date().addingTimeInterval(3600)))
    }

    // MARK: - End

    func endActivity(finalStatus: String = "✅", taskName: String? = nil) async {
        guard let activity else { return }
        let currentState = activity.content.state
        let finalState = TheaTaskActivityAttributes.ContentState(
            taskName: taskName ?? currentState.taskName,
            progress: 1.0,
            phase: "Done",
            statusEmoji: finalStatus,
            detail: nil
        )
        await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(30)))
        self.activity = nil
    }

    func cancelActivity() async {
        guard let activity else { return }
        await activity.end(dismissalPolicy: .immediate)
        self.activity = nil
    }
}
