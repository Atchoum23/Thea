// HandoffManager.swift
// Continuity Handoff support for seamless device transitions

import Foundation
import OSLog
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Handoff Manager

/// Manages Handoff activities for cross-device continuity
@MainActor
public final class HandoffManager: ObservableObject {
    public static let shared = HandoffManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Handoff")

    // MARK: - Activity Types

    public enum ActivityType: String {
        case conversation = "com.thea.app.conversation"
        case browsing = "com.thea.app.browsing"
        case composing = "com.thea.app.composing"
        case agent = "com.thea.app.agent"
        case settings = "com.thea.app.settings"
    }

    // MARK: - Published State

    @Published public private(set) var currentActivity: NSUserActivity?
    @Published public private(set) var isHandoffAvailable = false

    // MARK: - Private Properties

    private var activeActivities: [ActivityType: NSUserActivity] = [:]

    // MARK: - Initialization

    private init() {
        checkHandoffAvailability()
    }

    private func checkHandoffAvailability() {
        // Handoff requires Bluetooth and is available on compatible devices
        #if os(iOS)
        isHandoffAvailable = true
        #elseif os(macOS)
        isHandoffAvailable = true
        #else
        isHandoffAvailable = false
        #endif
    }

    // MARK: - Activity Management

    /// Start a Handoff activity for a conversation
    public func startConversationActivity(
        conversationId: String,
        title: String,
        preview: String?
    ) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.conversation.rawValue)

        activity.title = title
        activity.userInfo = [
            "conversationId": conversationId,
            "preview": preview ?? ""
        ]

        // Enable Handoff
        activity.isEligibleForHandoff = true

        // Enable Search
        activity.isEligibleForSearch = true
        activity.keywords = Set(["thea", "conversation", "ai", title])

        // Enable predictions
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = "conversation-\(conversationId)"
        activity.suggestedInvocationPhrase = "Continue \(title)"

        // Web fallback (if you have a web version)
        // activity.webpageURL = URL(string: "https://thea.app/c/\(conversationId)")

        // Become current
        activity.becomeCurrent()

        activeActivities[.conversation] = activity
        currentActivity = activity

        logger.info("Started Handoff activity for conversation: \(conversationId)")

        return activity
    }

    /// Start a composing activity
    public func startComposingActivity(draftText: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.composing.rawValue)

        activity.title = "Composing in Thea"
        activity.userInfo = [
            "draftText": draftText
        ]

        activity.isEligibleForHandoff = true
        activity.needsSave = true // Enable state restoration

        activity.becomeCurrent()

        activeActivities[.composing] = activity
        currentActivity = activity

        logger.info("Started composing Handoff activity")

        return activity
    }

    /// Start an agent activity
    public func startAgentActivity(
        agentId: String,
        agentName: String,
        taskDescription: String
    ) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.agent.rawValue)

        activity.title = "Working with \(agentName)"
        activity.userInfo = [
            "agentId": agentId,
            "agentName": agentName,
            "taskDescription": taskDescription
        ]

        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.keywords = Set(["thea", "agent", agentName])

        activity.becomeCurrent()

        activeActivities[.agent] = activity
        currentActivity = activity

        logger.info("Started agent Handoff activity: \(agentName)")

        return activity
    }

    /// Update activity state
    public func updateActivityState(_ type: ActivityType, userInfo: [AnyHashable: Any]) {
        guard let activity = activeActivities[type] else { return }

        var updatedInfo = activity.userInfo ?? [:]
        for (key, value) in userInfo {
            updatedInfo[key] = value
        }
        activity.userInfo = updatedInfo
        activity.needsSave = true

        logger.debug("Updated \(type.rawValue) activity state")
    }

    /// Stop an activity
    public func stopActivity(_ type: ActivityType) {
        guard let activity = activeActivities[type] else { return }

        activity.invalidate()
        activeActivities.removeValue(forKey: type)

        if currentActivity == activity {
            currentActivity = activeActivities.values.first
        }

        logger.info("Stopped Handoff activity: \(type.rawValue)")
    }

    /// Stop all activities
    public func stopAllActivities() {
        for (_, activity) in activeActivities {
            activity.invalidate()
        }
        activeActivities.removeAll()
        currentActivity = nil

        logger.info("Stopped all Handoff activities")
    }

    // MARK: - Receiving Handoff

    /// Handle incoming Handoff activity
    public func handleIncomingActivity(_ activity: NSUserActivity) -> HandoffResult? {
        logger.info("Received Handoff activity: \(activity.activityType)")

        switch activity.activityType {
        case ActivityType.conversation.rawValue:
            return handleConversationHandoff(activity)

        case ActivityType.composing.rawValue:
            return handleComposingHandoff(activity)

        case ActivityType.agent.rawValue:
            return handleAgentHandoff(activity)

        default:
            logger.warning("Unknown Handoff activity type: \(activity.activityType)")
            return nil
        }
    }

    private func handleConversationHandoff(_ activity: NSUserActivity) -> HandoffResult? {
        guard let conversationId = activity.userInfo?["conversationId"] as? String else {
            return nil
        }

        return HandoffResult(
            type: .conversation,
            data: [
                "conversationId": conversationId,
                "preview": activity.userInfo?["preview"] as? String ?? ""
            ]
        )
    }

    private func handleComposingHandoff(_ activity: NSUserActivity) -> HandoffResult? {
        guard let draftText = activity.userInfo?["draftText"] as? String else {
            return nil
        }

        return HandoffResult(
            type: .composing,
            data: ["draftText": draftText]
        )
    }

    private func handleAgentHandoff(_ activity: NSUserActivity) -> HandoffResult? {
        guard let agentId = activity.userInfo?["agentId"] as? String else {
            return nil
        }

        return HandoffResult(
            type: .agent,
            data: [
                "agentId": agentId,
                "agentName": activity.userInfo?["agentName"] as? String ?? "",
                "taskDescription": activity.userInfo?["taskDescription"] as? String ?? ""
            ]
        )
    }

    // MARK: - State Restoration

    /// Save state for continuation
    public func saveState(for activity: NSUserActivity, completion: @escaping () -> Void) {
        // Save any additional state needed for restoration
        switch activity.activityType {
        case ActivityType.composing.rawValue:
            // Get current draft text from the app
            // activity.userInfo?["draftText"] = getCurrentDraftText()
            break

        default:
            break
        }

        completion()
    }

    /// Restore state from activity
    public func restoreState(from activity: NSUserActivity) {
        // Handle state restoration based on activity type
        guard let result = handleIncomingActivity(activity) else { return }

        // Notify app to restore state
        NotificationCenter.default.post(
            name: .handoffStateRestored,
            object: nil,
            userInfo: ["result": result]
        )
    }
}

// MARK: - Types

public struct HandoffResult {
    public let type: HandoffManager.ActivityType
    public let data: [String: Any]
}

// MARK: - Notifications

public extension Notification.Name {
    static let handoffStateRestored = Notification.Name("thea.handoff.stateRestored")
}

// MARK: - SwiftUI Integration

import SwiftUI

public struct HandoffActivityModifier: ViewModifier {
    let activityType: HandoffManager.ActivityType
    let userInfo: [String: Any]
    let title: String

    @State private var activity: NSUserActivity?

    public func body(content: Content) -> some View {
        content
            .onAppear {
                startActivity()
            }
            .onDisappear {
                stopActivity()
            }
            .onChange(of: userInfo.description) { _, _ in
                updateActivity()
            }
    }

    private func startActivity() {
        let newActivity = NSUserActivity(activityType: activityType.rawValue)
        newActivity.title = title
        newActivity.userInfo = userInfo
        newActivity.isEligibleForHandoff = true
        newActivity.becomeCurrent()
        activity = newActivity
    }

    private func stopActivity() {
        activity?.invalidate()
        activity = nil
    }

    private func updateActivity() {
        activity?.userInfo = userInfo
        activity?.needsSave = true
    }
}

public extension View {
    func handoffActivity(
        _ type: HandoffManager.ActivityType,
        title: String,
        userInfo: [String: Any]
    ) -> some View {
        modifier(HandoffActivityModifier(
            activityType: type,
            userInfo: userInfo,
            title: title
        ))
    }
}
