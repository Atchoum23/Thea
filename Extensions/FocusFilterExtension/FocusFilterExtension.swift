//
//  FocusFilterExtension.swift
//  TheaFocusFilterExtension
//
//  Created by Thea
//

import AppIntents
import os.log

// MARK: - Focus Filter Intent

/// Allows Thea to respond to Focus mode changes
@available(iOS 16.0, *)
struct TheaFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Thea Focus Mode"
    static let description: IntentDescription? = IntentDescription("Configure Thea's behavior during Focus modes")

    // MARK: - Filter Parameters

    @Parameter(title: "AI Assistance Level", default: .adaptive)
    var assistanceLevel: AssistanceLevel

    @Parameter(title: "Notification Filtering", default: .smart)
    var notificationFilter: NotificationFilterMode

    @Parameter(title: "Context Awareness", default: true)
    var enableContextAwareness: Bool

    @Parameter(title: "Quiet Hours", default: false)
    var enableQuietHours: Bool

    @Parameter(title: "Auto-summarize Missed Content", default: true)
    var autoSummarize: Bool

    // MARK: - Display Representation

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Thea Focus Settings",
            subtitle: "Assistance: \(assistanceLevel.displayTitle)"
        )
    }

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        let logger = Logger(subsystem: "app.thea.focusfilter", category: "FocusFilter")

        logger.info("Focus filter activated: \(assistanceLevel.rawValue)")

        // Save settings to app group
        let settings = FocusFilterSettings(
            assistanceLevel: assistanceLevel,
            notificationFilter: notificationFilter,
            enableContextAwareness: enableContextAwareness,
            enableQuietHours: enableQuietHours,
            autoSummarize: autoSummarize
        )

        saveFocusSettings(settings)

        // Notify main app
        notifyMainApp(settings: settings)

        return .result()
    }

    private func saveFocusSettings(_ settings: FocusFilterSettings) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.theathe"
        ) else { return }

        let settingsPath = containerURL.appendingPathComponent("focus_settings.json")

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(settings) {
            try? data.write(to: settingsPath)
        }
    }

    private func notifyMainApp(settings _: FocusFilterSettings) {
        let notificationName = CFNotificationName("app.thea.FocusModeChanged" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
    }
}

// MARK: - Assistance Level

@available(iOS 16.0, *)
enum AssistanceLevel: String, AppEnum {
    case minimal
    case adaptive
    case full
    case silent

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Assistance Level"

    static let caseDisplayRepresentations: [AssistanceLevel: DisplayRepresentation] = [
        .minimal: DisplayRepresentation(title: "Minimal", subtitle: "Only critical assistance"),
        .adaptive: DisplayRepresentation(title: "Adaptive", subtitle: "Adjusts based on context"),
        .full: DisplayRepresentation(title: "Full", subtitle: "Full AI assistance"),
        .silent: DisplayRepresentation(title: "Silent", subtitle: "No interruptions")
    ]

    var displayTitle: String {
        switch self {
        case .minimal: "Minimal"
        case .adaptive: "Adaptive"
        case .full: "Full"
        case .silent: "Silent"
        }
    }
}

// MARK: - Notification Filter Mode

@available(iOS 16.0, *)
enum NotificationFilterMode: String, AppEnum {
    case all
    case smart
    case priority
    case none

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Notification Filter"

    static let caseDisplayRepresentations: [NotificationFilterMode: DisplayRepresentation] = [
        .all: DisplayRepresentation(title: "All", subtitle: "Show all notifications"),
        .smart: DisplayRepresentation(title: "Smart", subtitle: "AI-prioritized notifications"),
        .priority: DisplayRepresentation(title: "Priority Only", subtitle: "Only urgent notifications"),
        .none: DisplayRepresentation(title: "None", subtitle: "Block all notifications")
    ]
}

// MARK: - Focus Filter Settings

struct FocusFilterSettings: Codable {
    let assistanceLevel: String
    let notificationFilter: String
    let enableContextAwareness: Bool
    let enableQuietHours: Bool
    let autoSummarize: Bool
    let timestamp: Date

    @available(iOS 16.0, *)
    init(
        assistanceLevel: AssistanceLevel,
        notificationFilter: NotificationFilterMode,
        enableContextAwareness: Bool,
        enableQuietHours: Bool,
        autoSummarize: Bool
    ) {
        self.assistanceLevel = assistanceLevel.rawValue
        self.notificationFilter = notificationFilter.rawValue
        self.enableContextAwareness = enableContextAwareness
        self.enableQuietHours = enableQuietHours
        self.autoSummarize = autoSummarize
        timestamp = Date()
    }
}

// MARK: - Focus Filter App Intent Provider

@available(iOS 16.0, *)
struct TheaFocusFilterAppIntentProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TheaFocusFilter(),
            phrases: [
                "Set \(.applicationName) focus mode",
                "Configure \(.applicationName) for focus",
                "Adjust \(.applicationName) notifications"
            ],
            shortTitle: "Focus Mode",
            systemImageName: "moon.fill"
        )
    }
}
