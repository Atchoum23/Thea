//
//  NotificationService.swift
//  Thea
//
//  Comprehensive notification management with rich notifications
//

import Combine
import Foundation
import UserNotifications

#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif

// MARK: - Notification Service

@MainActor
public class NotificationService: ObservableObject {
    public static let shared = NotificationService()

    // MARK: - Published State

    @Published public private(set) var isAuthorized = false
    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public private(set) var pendingNotifications: [UNNotificationRequest] = []
    @Published public private(set) var deliveredNotifications: [UNNotification] = []

    // MARK: - Notification Categories

    public enum Category: String {
        case aiResponse = "AI_RESPONSE"
        case reminder = "REMINDER"
        case focusSession = "FOCUS_SESSION"
        case syncComplete = "SYNC_COMPLETE"
        case codeGeneration = "CODE_GENERATION"
        case healthInsight = "HEALTH_INSIGHT"
        case projectUpdate = "PROJECT_UPDATE"
        case sharePlay = "SHAREPLAY"
    }

    // MARK: - Notification Actions

    public enum Action: String {
        case reply = "REPLY_ACTION"
        case view = "VIEW_ACTION"
        case dismiss = "DISMISS_ACTION"
        case snooze = "SNOOZE_ACTION"
        case copy = "COPY_ACTION"
        case share = "SHARE_ACTION"
        case startFocus = "START_FOCUS_ACTION"
        case stopFocus = "STOP_FOCUS_ACTION"
    }

    // MARK: - Initialization

    private init() {
        Task {
            await checkAuthorization()
            await registerCategories()
        }
    }

    // MARK: - Authorization

    public func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()

        let granted = try await center.requestAuthorization(options: [
            .alert,
            .sound,
            .badge,
            .criticalAlert,
            .providesAppNotificationSettings,
            .provisional
        ])

        await checkAuthorization()
        return granted
    }

    private func checkAuthorization() async {
        // Extract value in nonisolated context to avoid Sendable issues with UNNotificationSettings
        let status = await { @Sendable in
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }()
        authorizationStatus = status
        isAuthorized = status == .authorized
    }

    // MARK: - Category Registration

    private func registerCategories() async {
        let center = UNUserNotificationCenter.current()

        // AI Response Category
        let aiResponseCategory = UNNotificationCategory(
            identifier: Category.aiResponse.rawValue,
            actions: [
                UNNotificationAction(identifier: Action.view.rawValue, title: "View", options: .foreground),
                UNNotificationAction(identifier: Action.copy.rawValue, title: "Copy Response"),
                UNTextInputNotificationAction(
                    identifier: Action.reply.rawValue,
                    title: "Reply",
                    options: [],
                    textInputButtonTitle: "Send",
                    textInputPlaceholder: "Type a follow-up..."
                )
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Reminder Category
        let reminderCategory = UNNotificationCategory(
            identifier: Category.reminder.rawValue,
            actions: [
                UNNotificationAction(identifier: Action.view.rawValue, title: "View", options: .foreground),
                UNNotificationAction(identifier: Action.snooze.rawValue, title: "Snooze 15 min"),
                UNNotificationAction(identifier: Action.dismiss.rawValue, title: "Dismiss", options: .destructive)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Focus Session Category
        let focusCategory = UNNotificationCategory(
            identifier: Category.focusSession.rawValue,
            actions: [
                UNNotificationAction(identifier: Action.startFocus.rawValue, title: "Start Focus", options: .foreground),
                UNNotificationAction(identifier: Action.stopFocus.rawValue, title: "End Session", options: .destructive)
            ],
            intentIdentifiers: [],
            options: []
        )

        // Code Generation Category
        let codeCategory = UNNotificationCategory(
            identifier: Category.codeGeneration.rawValue,
            actions: [
                UNNotificationAction(identifier: Action.view.rawValue, title: "View Code", options: .foreground),
                UNNotificationAction(identifier: Action.copy.rawValue, title: "Copy to Clipboard"),
                UNNotificationAction(identifier: Action.share.rawValue, title: "Share")
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([
            aiResponseCategory,
            reminderCategory,
            focusCategory,
            codeCategory
        ])
    }

    // MARK: - Schedule Notifications

    /// Schedule a notification for an AI response
    public func notifyAIResponse(
        title: String,
        body: String,
        conversationId: String,
        responsePreview: String
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Category.aiResponse.rawValue
        content.userInfo = [
            "conversationId": conversationId,
            "responsePreview": responsePreview
        ]
        content.interruptionLevel = .active

        // Add attachment if available
        if let imageURL = createNotificationImage() {
            let attachment = try UNNotificationAttachment(identifier: "image", url: imageURL)
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Immediate
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a reminder notification
    public func scheduleReminder(
        title: String,
        body: String,
        at date: Date,
        repeats: Bool = false
    ) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Category.reminder.rawValue
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)

        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
        return identifier
    }

    /// Schedule a focus session notification
    public func scheduleFocusSessionEnd(duration: TimeInterval, title: String) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Your focus session is complete. Great work! 🎉"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("focus_complete.caf"))
        content.categoryIdentifier = Category.focusSession.rawValue
        content.interruptionLevel = .active

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)

        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
        return identifier
    }

    /// Send a code generation complete notification
    public func notifyCodeGeneration(
        language: String,
        filename: String,
        linesOfCode: Int,
        code: String
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Code Generated: \(filename)"
        content.body = "\(linesOfCode) lines of \(language) code ready"
        content.sound = .default
        content.categoryIdentifier = Category.codeGeneration.rawValue
        content.userInfo = [
            "language": language,
            "filename": filename,
            "code": code
        ]
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    /// Send a sync complete notification
    public func notifySyncComplete(itemCount: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Sync Complete"
        content.body = "\(itemCount) items synced across devices"
        content.sound = .default
        content.categoryIdentifier = Category.syncComplete.rawValue
        content.interruptionLevel = .passive

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Notification Management

    nonisolated public func updatePendingNotifications() async {
        // Fetch in nonisolated context, then hop to MainActor for assignment
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        await MainActor.run {
            self.pendingNotifications = requests
        }
    }

    nonisolated public func updateDeliveredNotifications() async {
        // Fetch in nonisolated context, then hop to MainActor for assignment
        let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
        await MainActor.run {
            self.deliveredNotifications = notifications
        }
    }

    public func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    public func clearDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - Badge Management

    #if os(iOS)
        public func setBadgeCount(_ count: Int) async {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }

        public func clearBadge() async {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    #endif

    // MARK: - Action Handling

    public func handleNotificationAction(
        action: Action,
        notification: UNNotification
    ) async -> NotificationActionResult {
        let userInfo = notification.request.content.userInfo

        switch action {
        case .reply:
            return .openConversation(id: userInfo["conversationId"] as? String ?? "")

        case .view:
            return .openContent(identifier: notification.request.identifier)

        case .dismiss:
            return .dismissed

        case .snooze:
            // Reschedule for 15 minutes
            // swiftlint:disable:next force_cast
            let content = notification.request.content.mutableCopy() as! UNMutableNotificationContent
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
            return .snoozed(minutes: 15)

        case .copy:
            let text = userInfo["responsePreview"] as? String ?? notification.request.content.body
            #if os(iOS)
                UIPasteboard.general.string = text
            #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            #endif
            return .copied

        case .share:
            return .showShareSheet(content: notification.request.content.body)

        case .startFocus:
            return .startFocusSession

        case .stopFocus:
            return .endFocusSession
        }
    }

    // MARK: - Helper Methods

    private func createNotificationImage() -> URL? {
        // Create a temporary image for notification attachment
        let tempDir = FileManager.default.temporaryDirectory
        let imageURL = tempDir.appendingPathComponent("notification_image.png")

        #if os(iOS)
            if let image = UIImage(systemName: "brain.fill"),
               let data = image.pngData()
            {
                try? data.write(to: imageURL)
                return imageURL
            }
        #endif

        return nil
    }
}

// MARK: - Notification Action Result

public enum NotificationActionResult: Sendable {
    case none
    case openConversation(id: String)
    case openContent(identifier: String)
    case dismissed
    case snoozed(minutes: Int)
    case copied
    case showShareSheet(content: String)
    case startFocusSession
    case endFocusSession
    case reply(conversationId: String, text: String)
    case openAgent(String)
    case openMission(String)
    case stopAgent(String)
    case stopMission(String)
}

// MARK: - Notification Delegate

public class TheaNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let shared = TheaNotificationDelegate()

    public var onNotificationReceived: ((UNNotification) -> Void)?
    public var onActionSelected: ((UNNotificationResponse) -> Void)?

    override private init() {
        super.init()
    }

    public func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        onNotificationReceived?(notification)

        // Show notification even when app is in foreground
        return [.banner, .sound, .badge, .list]
    }

    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        onActionSelected?(response)
    }

    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        openSettingsFor _: UNNotification?
    ) {
        // Open notification settings in app
        NotificationCenter.default.post(name: .openNotificationSettings, object: nil)
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let openNotificationSettings = Notification.Name("openNotificationSettings")
}
