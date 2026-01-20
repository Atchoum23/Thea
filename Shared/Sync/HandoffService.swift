//
//  HandoffService.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Handoff Service

/// Manages Handoff and Continuity features between devices
@MainActor
@Observable
public final class HandoffService {
    public static let shared = HandoffService()

    // MARK: - Activity Types

    public static let conversationActivityType = "app.thea.conversation"
    public static let projectActivityType = "app.thea.project"
    public static let searchActivityType = "app.thea.search"

    // MARK: - State

    /// Current user activity
    public private(set) var currentActivity: NSUserActivity?

    /// Whether Handoff is enabled
    public var isEnabled: Bool = true

    // MARK: - Configuration

    private var configuration: HandoffConfiguration

    // MARK: - Initialization

    private init() {
        self.configuration = HandoffConfiguration.load()
        setupNotifications()
    }

    // MARK: - Setup

    private func setupNotifications() {
        #if os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBecameActive()
        }
        #endif
    }

    private func handleAppBecameActive() {
        // Resume any pending activities
    }

    // MARK: - Start Activities

    /// Start a conversation handoff activity
    public func startConversationActivity(
        conversationId: String,
        title: String,
        messageCount: Int
    ) {
        guard isEnabled else { return }

        let activity = NSUserActivity(activityType: Self.conversationActivityType)
        activity.title = "Continue Conversation: \(title)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true

        activity.userInfo = [
            "conversationId": conversationId,
            "title": title,
            "messageCount": messageCount,
            "timestamp": Date().timeIntervalSince1970
        ]

        #if os(macOS)
        activity.keywords = Set(["thea", "chat", "conversation", title.lowercased()])
        #endif

        activity.needsSave = true
        activity.becomeCurrent()

        currentActivity = activity
    }

    /// Start a project handoff activity
    public func startProjectActivity(
        projectId: String,
        name: String,
        fileCount: Int
    ) {
        guard isEnabled else { return }

        let activity = NSUserActivity(activityType: Self.projectActivityType)
        activity.title = "Continue Project: \(name)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true

        activity.userInfo = [
            "projectId": projectId,
            "name": name,
            "fileCount": fileCount,
            "timestamp": Date().timeIntervalSince1970
        ]

        activity.needsSave = true
        activity.becomeCurrent()

        currentActivity = activity
    }

    /// Start a search handoff activity
    public func startSearchActivity(query: String) {
        guard isEnabled else { return }

        let activity = NSUserActivity(activityType: Self.searchActivityType)
        activity.title = "Continue Search: \(query)"
        activity.isEligibleForHandoff = true

        activity.userInfo = [
            "query": query,
            "timestamp": Date().timeIntervalSince1970
        ]

        activity.becomeCurrent()
        currentActivity = activity
    }

    // MARK: - Stop Activities

    /// Stop the current activity
    public func stopCurrentActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
    }

    // MARK: - Handle Incoming Activities

    /// Handle an incoming handoff activity
    public func handleIncomingActivity(_ activity: NSUserActivity) -> HandoffContext? {
        guard let userInfo = activity.userInfo else { return nil }

        switch activity.activityType {
        case Self.conversationActivityType:
            guard let conversationId = userInfo["conversationId"] as? String,
                  let title = userInfo["title"] as? String else {
                return nil
            }
            return HandoffContext(
                type: .conversation,
                id: conversationId,
                title: title,
                metadata: userInfo
            )

        case Self.projectActivityType:
            guard let projectId = userInfo["projectId"] as? String,
                  let name = userInfo["name"] as? String else {
                return nil
            }
            return HandoffContext(
                type: .project,
                id: projectId,
                title: name,
                metadata: userInfo
            )

        case Self.searchActivityType:
            guard let query = userInfo["query"] as? String else {
                return nil
            }
            return HandoffContext(
                type: .search,
                id: query,
                title: "Search: \(query)",
                metadata: userInfo
            )

        default:
            return nil
        }
    }

    // MARK: - Configuration

    /// Update configuration
    public func updateConfiguration(_ config: HandoffConfiguration) {
        configuration = config
        config.save()
        isEnabled = config.handoffEnabled
    }

    public func getConfiguration() -> HandoffConfiguration {
        configuration
    }
}

// MARK: - Handoff Context

public struct HandoffContext: Sendable {
    public let type: HandoffType
    public let id: String
    public let title: String
    public let metadata: [String: any Sendable]

    public init(
        type: HandoffType,
        id: String,
        title: String,
        metadata: [String: any Sendable]
    ) {
        self.type = type
        self.id = id
        self.title = title
        self.metadata = metadata
    }
}

// MARK: - Handoff Type

public enum HandoffType: String, Codable, Sendable {
    case conversation
    case project
    case search
    case settings

    public var icon: String {
        switch self {
        case .conversation: return "bubble.left.and.bubble.right"
        case .project: return "folder"
        case .search: return "magnifyingglass"
        case .settings: return "gear"
        }
    }
}

// MARK: - Handoff Configuration

public struct HandoffConfiguration: Codable, Sendable {
    public var handoffEnabled: Bool
    public var allowConversationHandoff: Bool
    public var allowProjectHandoff: Bool
    public var allowSearchHandoff: Bool
    public var requireSameNetwork: Bool

    public init(
        handoffEnabled: Bool = true,
        allowConversationHandoff: Bool = true,
        allowProjectHandoff: Bool = true,
        allowSearchHandoff: Bool = true,
        requireSameNetwork: Bool = false
    ) {
        self.handoffEnabled = handoffEnabled
        self.allowConversationHandoff = allowConversationHandoff
        self.allowProjectHandoff = allowProjectHandoff
        self.allowSearchHandoff = allowSearchHandoff
        self.requireSameNetwork = requireSameNetwork
    }

    private static let configKey = "HandoffService.configuration"

    public static func load() -> HandoffConfiguration {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let config = try? JSONDecoder().decode(HandoffConfiguration.self, from: data) {
            return config
        }
        return HandoffConfiguration()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: HandoffConfiguration.configKey)
        }
    }
}

// MARK: - Presence Monitor

/// Monitors device presence for real-time sync
public actor PresenceMonitor {
    public static let shared = PresenceMonitor()

    // MARK: - State

    private var isMonitoring = false
    private var presenceTask: Task<Void, Never>?
    private var onlineDevices: Set<String> = []

    // MARK: - Configuration

    private let updateInterval: TimeInterval = 30 // seconds

    // MARK: - Initialization

    private init() {}

    // MARK: - Monitoring

    /// Start monitoring device presence
    public func startMonitoring() async {
        guard !isMonitoring else { return }
        isMonitoring = true

        presenceTask = Task {
            while !Task.isCancelled && isMonitoring {
                await updatePresence()
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }
        }
    }

    /// Stop monitoring device presence
    public func stopMonitoring() {
        isMonitoring = false
        presenceTask?.cancel()
        presenceTask = nil
    }

    /// Update presence information
    private func updatePresence() async {
        await MainActor.run {
            DeviceRegistry.shared.updatePresence()
        }

        // Check for other online devices
        let devices = await MainActor.run {
            DeviceRegistry.shared.onlineDevices
        }

        let currentDeviceId = await MainActor.run {
            DeviceRegistry.shared.currentDevice.id
        }

        onlineDevices = Set(devices.map(\.id).filter { $0 != currentDeviceId })
    }

    /// Get online devices
    public func getOnlineDevices() -> Set<String> {
        onlineDevices
    }

    /// Check if a specific device is online
    public func isDeviceOnline(_ deviceId: String) -> Bool {
        onlineDevices.contains(deviceId)
    }
}
