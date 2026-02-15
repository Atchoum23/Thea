//
//  NotificationIntelligenceService.swift
//  Thea
//
//  G2: Cross-Device Notification Intelligence
//  Reads, classifies, acts on, and syncs notifications across all devices.
//
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Combine
import Foundation
import OSLog
#if canImport(UserNotifications)
    import UserNotifications
#endif

// MARK: - Notification Intelligence Service

/// Central intelligence layer for notification comprehension, action triggering,
/// and cross-device sync of notification state.
@MainActor
public final class NotificationIntelligenceService: ObservableObject {
    public static let shared = NotificationIntelligenceService()

    private let logger = Logger(subsystem: "app.thea", category: "NotificationIntelligence")

    // MARK: - Published State

    @Published public private(set) var isEnabled = false
    @Published public private(set) var classifiedNotifications: [ClassifiedNotification] = []
    @Published public private(set) var pendingActions: [IntelNotifAction] = []
    @Published public private(set) var syncedClearances: [NotificationClearance] = []

    // MARK: - Settings

    @Published public var autoActionEnabled: Bool {
        didSet { UserDefaults.standard.set(autoActionEnabled, forKey: "thea.notif.autoAction") }
    }
    @Published public var autoActionConfidenceThreshold: Double {
        didSet { UserDefaults.standard.set(autoActionConfidenceThreshold, forKey: "thea.notif.confidenceThreshold") }
    }
    @Published public var syncNotificationState: Bool {
        didSet { UserDefaults.standard.set(syncNotificationState, forKey: "thea.notif.syncState") }
    }
    @Published public var perAppSettings: [String: AppNotificationSettings] {
        didSet { savePerAppSettings() }
    }

    // MARK: - Internal State

    private var classificationCache: [String: NotificationUrgency] = [:]
    private let maxClassified = 200
    private let cloudContainer = CKContainer(identifier: "iCloud.app.theathe")

    // MARK: - Init

    private init() {
        self.autoActionEnabled = UserDefaults.standard.bool(forKey: "thea.notif.autoAction")
        let savedThreshold = UserDefaults.standard.double(forKey: "thea.notif.confidenceThreshold")
        self.autoActionConfidenceThreshold = savedThreshold > 0 ? savedThreshold : 0.8
        self.syncNotificationState = UserDefaults.standard.bool(forKey: "thea.notif.syncState")
        self.perAppSettings = Self.loadPerAppSettings()
    }

    // MARK: - Lifecycle

    /// Enable notification intelligence
    public func enable() async {
        guard !isEnabled else { return }
        isEnabled = true

        // Start listening for notifications from NotificationMonitor
        await NotificationMonitor.shared.start()

        if syncNotificationState {
            await fetchSyncedClearances()
        }

        logger.info("Notification intelligence enabled")
    }

    /// Disable notification intelligence
    public func disable() {
        isEnabled = false
        logger.info("Notification intelligence disabled")
    }

    // MARK: - Classification

    /// Classify a notification by urgency and type using heuristic analysis
    public func classify(_ record: NotificationRecord) -> ClassifiedNotification {
        let urgency = determineUrgency(record)
        let category = determineCategory(record)
        let suggestedActions = determineSuggestedActions(record, urgency: urgency, category: category)

        let classified = ClassifiedNotification(
            id: record.id,
            appIdentifier: record.appIdentifier,
            title: record.title,
            body: record.body,
            timestamp: record.timestamp,
            urgency: urgency,
            category: category,
            suggestedActions: suggestedActions,
            isCleared: false,
            clearedBy: nil,
            clearedAt: nil
        )

        // Cache classification
        classificationCache[record.appIdentifier] = urgency

        // Add to classified list (cap size)
        classifiedNotifications.append(classified)
        if classifiedNotifications.count > maxClassified {
            classifiedNotifications.removeFirst()
        }

        // Check for auto-action
        if autoActionEnabled {
            evaluateAutoActions(classified)
        }

        return classified
    }

    /// Process a batch of delivered notifications
    public func processDeliveredNotifications() async {
        #if canImport(UserNotifications)
            let center = UNUserNotificationCenter.current()
            let delivered = await center.deliveredNotifications()

            for notification in delivered {
                let content = notification.request.content
                let record = NotificationRecord(
                    appIdentifier: content.threadIdentifier.isEmpty
                        ? notification.request.identifier
                        : content.threadIdentifier,
                    title: content.title.isEmpty ? nil : content.title,
                    body: content.body.isEmpty ? nil : content.body,
                    category: content.categoryIdentifier.isEmpty ? nil : content.categoryIdentifier,
                    timestamp: notification.date,
                    interacted: false,
                    interactionType: nil
                )

                // Only classify if not already classified
                let alreadyClassified = classifiedNotifications.contains { $0.id == record.id }
                if !alreadyClassified {
                    _ = classify(record)
                }
            }
        #endif
    }

    // MARK: - Urgency Classification

    private func determineUrgency(_ record: NotificationRecord) -> NotificationUrgency {
        let title = (record.title ?? "").lowercased()
        let body = (record.body ?? "").lowercased()
        let combined = title + " " + body

        // Critical keywords
        let criticalKeywords = ["emergency", "urgent", "critical", "alert", "security",
                                 "breach", "immediate", "warning", "danger", "failed payment"]
        if criticalKeywords.contains(where: { combined.contains($0) }) {
            return .critical
        }

        // High urgency keywords
        let highKeywords = ["important", "action required", "deadline", "overdue",
                            "reminder", "missed call", "voicemail", "payment due",
                            "expiring", "cancellation"]
        if highKeywords.contains(where: { combined.contains($0) }) {
            return .high
        }

        // Medium urgency keywords
        let mediumKeywords = ["message from", "new message", "reply", "mentioned you",
                               "invitation", "meeting", "appointment", "update available",
                               "delivery", "shipped"]
        if mediumKeywords.contains(where: { combined.contains($0) }) {
            return .medium
        }

        // App-based urgency boost
        let appSettings = perAppSettings[record.appIdentifier]
        if let override = appSettings?.urgencyOverride {
            return override
        }

        // Default: low urgency
        return .low
    }

    // MARK: - Category Classification

    private func determineCategory(_ record: NotificationRecord) -> IntelNotifCategory {
        let appId = record.appIdentifier.lowercased()
        let combined = ((record.title ?? "") + " " + (record.body ?? "")).lowercased()

        // Messaging apps
        let messagingApps = ["whatsapp", "telegram", "signal", "messages", "slack",
                              "discord", "imessage", "viber"]
        if messagingApps.contains(where: { appId.contains($0) }) {
            return .messaging
        }

        // Calendar/scheduling
        if appId.contains("calendar") || combined.contains("meeting") ||
           combined.contains("appointment") || combined.contains("event") {
            return .calendar
        }

        // Email
        if appId.contains("mail") || appId.contains("gmail") || appId.contains("outlook") {
            return .email
        }

        // Finance
        let financeKeywords = ["payment", "transaction", "balance", "invoice", "transfer",
                                "bank", "credit", "debit"]
        if financeKeywords.contains(where: { combined.contains($0) }) ||
           appId.contains("bank") || appId.contains("finance") || appId.contains("revolut") ||
           appId.contains("paypal") {
            return .finance
        }

        // Health
        if appId.contains("health") || combined.contains("heart rate") ||
           combined.contains("workout") || combined.contains("medication") {
            return .health
        }

        // Delivery/shipping
        if combined.contains("delivered") || combined.contains("shipped") ||
           combined.contains("tracking") || combined.contains("package") {
            return .delivery
        }

        // Social media
        let socialApps = ["instagram", "facebook", "twitter", "tiktok", "linkedin",
                           "reddit", "mastodon", "threads"]
        if socialApps.contains(where: { appId.contains($0) }) {
            return .social
        }

        // News
        if appId.contains("news") || combined.contains("breaking") {
            return .news
        }

        // System
        if appId.contains("com.apple") {
            return .system
        }

        return .other
    }

    // MARK: - Suggested Actions

    private func determineSuggestedActions(
        _ record: NotificationRecord,
        urgency: NotificationUrgency,
        category: IntelNotifCategory
    ) -> [IntelNotifAction] {
        var actions: [IntelNotifAction] = []

        switch category {
        case .messaging:
            actions.append(IntelNotifAction(
                type: .draftReply,
                description: "Draft a reply",
                confidence: 0.7,
                requiresApproval: true
            ))
        case .calendar:
            actions.append(IntelNotifAction(
                type: .prepareBriefing,
                description: "Prepare meeting briefing",
                confidence: 0.8,
                requiresApproval: false
            ))
        case .email:
            actions.append(IntelNotifAction(
                type: .summarize,
                description: "Summarize email",
                confidence: 0.9,
                requiresApproval: false
            ))
            if urgency == .high || urgency == .critical {
                actions.append(IntelNotifAction(
                    type: .draftReply,
                    description: "Draft urgent reply",
                    confidence: 0.6,
                    requiresApproval: true
                ))
            }
        case .delivery:
            actions.append(IntelNotifAction(
                type: .trackPackage,
                description: "Track package status",
                confidence: 0.9,
                requiresApproval: false
            ))
        case .finance:
            actions.append(IntelNotifAction(
                type: .logTransaction,
                description: "Log transaction",
                confidence: 0.7,
                requiresApproval: true
            ))
        case .health:
            actions.append(IntelNotifAction(
                type: .logHealthData,
                description: "Log health data",
                confidence: 0.8,
                requiresApproval: false
            ))
        default:
            break
        }

        // Always offer dismiss/clear
        actions.append(IntelNotifAction(
            type: .clearNotification,
            description: "Clear notification",
            confidence: 1.0,
            requiresApproval: false
        ))

        return actions
    }

    // MARK: - Auto-Action Evaluation

    private func evaluateAutoActions(_ classified: ClassifiedNotification) {
        // Check per-app auto-action setting
        let appSettings = perAppSettings[classified.appIdentifier]
        guard appSettings?.autoActionsEnabled ?? autoActionEnabled else { return }

        for action in classified.suggestedActions {
            if action.confidence >= autoActionConfidenceThreshold && !action.requiresApproval {
                pendingActions.append(action)
                logger.info("Auto-action queued: \(action.description) for \(classified.appIdentifier)")
            }
        }
    }

    // MARK: - Notification Clearing

    /// Clear a notification and sync the clearance across devices
    public func clearNotification(_ classified: ClassifiedNotification) async {
        // Remove from notification center
        #if canImport(UserNotifications)
            let center = UNUserNotificationCenter.current()
            center.removeDeliveredNotifications(withIdentifiers: [classified.id.uuidString])
        #endif

        // Mark as cleared
        if let index = classifiedNotifications.firstIndex(where: { $0.id == classified.id }) {
            classifiedNotifications[index].isCleared = true
            classifiedNotifications[index].clearedBy = DeviceRegistry.shared.currentDevice.name
            classifiedNotifications[index].clearedAt = Date()
        }

        // Sync clearance to CloudKit
        if syncNotificationState {
            await syncClearance(classified)
        }
    }

    // MARK: - CloudKit Sync

    /// Upload a clearance record to CloudKit
    private func syncClearance(_ classified: ClassifiedNotification) async {
        let clearance = NotificationClearance(
            notificationID: classified.id,
            appIdentifier: classified.appIdentifier,
            clearedAt: Date(),
            clearedBy: DeviceRegistry.shared.currentDevice.name,
            deviceID: DeviceRegistry.shared.currentDevice.id
        )

        let record = CKRecord(recordType: "NotificationClearance")
        record["notificationID"] = clearance.notificationID.uuidString
        record["appIdentifier"] = clearance.appIdentifier
        record["clearedAt"] = clearance.clearedAt as CKRecordValue
        record["clearedBy"] = clearance.clearedBy
        record["deviceID"] = clearance.deviceID

        do {
            _ = try await cloudContainer.privateCloudDatabase.save(record)
            syncedClearances.append(clearance)
            logger.info("Synced notification clearance to CloudKit")
        } catch {
            logger.error("Failed to sync clearance: \(error.localizedDescription)")
        }
    }

    /// Fetch clearances from other devices
    public func fetchSyncedClearances() async {
        let query = CKQuery(
            recordType: "NotificationClearance",
            predicate: NSPredicate(value: true)
        )
        query.sortDescriptors = [NSSortDescriptor(key: "clearedAt", ascending: false)]

        do {
            let results = try await cloudContainer.privateCloudDatabase.records(matching: query, resultsLimit: 100)
            var clearances: [NotificationClearance] = []

            for (_, result) in results.matchResults {
                if let record = try? result.get() {
                    let clearance = NotificationClearance(
                        notificationID: UUID(uuidString: record["notificationID"] as? String ?? "") ?? UUID(),
                        appIdentifier: record["appIdentifier"] as? String ?? "",
                        clearedAt: record["clearedAt"] as? Date ?? Date(),
                        clearedBy: record["clearedBy"] as? String ?? "",
                        deviceID: record["deviceID"] as? String ?? ""
                    )
                    clearances.append(clearance)
                }
            }

            syncedClearances = clearances

            // Apply remote clearances to local notifications
            for clearance in clearances {
                #if canImport(UserNotifications)
                    UNUserNotificationCenter.current()
                        .removeDeliveredNotifications(withIdentifiers: [clearance.notificationID.uuidString])
                #endif
            }

            logger.info("Fetched \(clearances.count) clearances from CloudKit")
        } catch {
            logger.error("Failed to fetch clearances: \(error.localizedDescription)")
        }
    }

    // MARK: - Per-App Settings

    /// Get or create app settings
    public func settingsForApp(_ appIdentifier: String) -> AppNotificationSettings {
        perAppSettings[appIdentifier] ?? AppNotificationSettings()
    }

    /// Update app settings
    public func updateAppSettings(_ appIdentifier: String, settings: AppNotificationSettings) {
        perAppSettings[appIdentifier] = settings
    }

    // MARK: - Statistics

    /// Get classified notification statistics
    public var statistics: NotificationIntelligenceStats {
        let total = classifiedNotifications.count
        let byUrgency = Dictionary(grouping: classifiedNotifications, by: \.urgency)
            .mapValues(\.count)
        let byCategory = Dictionary(grouping: classifiedNotifications, by: \.category)
            .mapValues(\.count)
        let cleared = classifiedNotifications.filter(\.isCleared).count
        let actioned = pendingActions.count

        return NotificationIntelligenceStats(
            totalClassified: total,
            byUrgency: byUrgency,
            byCategory: byCategory,
            totalCleared: cleared,
            totalActioned: actioned,
            autoActionRate: total > 0 ? Double(actioned) / Double(total) : 0
        )
    }

    // MARK: - Persistence Helpers

    private func savePerAppSettings() {
        if let data = try? JSONEncoder().encode(perAppSettings) {
            UserDefaults.standard.set(data, forKey: "thea.notif.perAppSettings")
        }
    }

    private static func loadPerAppSettings() -> [String: AppNotificationSettings] {
        guard let data = UserDefaults.standard.data(forKey: "thea.notif.perAppSettings"),
              let settings = try? JSONDecoder().decode([String: AppNotificationSettings].self, from: data)
        else { return [:] }
        return settings
    }
}

// MARK: - Supporting Types

/// A notification that has been classified by urgency and category
public struct ClassifiedNotification: Identifiable, Sendable {
    public let id: UUID
    public let appIdentifier: String
    public let title: String?
    public let body: String?
    public let timestamp: Date
    public let urgency: NotificationUrgency
    public let category: IntelNotifCategory
    public let suggestedActions: [IntelNotifAction]
    public var isCleared: Bool
    public var clearedBy: String?
    public var clearedAt: Date?
}

/// Urgency levels for notifications
public enum NotificationUrgency: String, Codable, Sendable, CaseIterable, Comparable {
    case critical
    case high
    case medium
    case low

    public static func < (lhs: NotificationUrgency, rhs: NotificationUrgency) -> Bool {
        let order: [NotificationUrgency] = [.low, .medium, .high, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }

    public var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "bell.fill"
        case .low: return "bell"
        }
    }

    public var displayName: String {
        rawValue.capitalized
    }
}

/// Categories for notification classification
public enum IntelNotifCategory: String, Codable, Sendable, CaseIterable {
    case messaging
    case calendar
    case email
    case finance
    case health
    case delivery
    case social
    case news
    case system
    case other

    public var icon: String {
        switch self {
        case .messaging: return "message.fill"
        case .calendar: return "calendar"
        case .email: return "envelope.fill"
        case .finance: return "creditcard.fill"
        case .health: return "heart.fill"
        case .delivery: return "shippingbox.fill"
        case .social: return "person.2.fill"
        case .news: return "newspaper.fill"
        case .system: return "gear"
        case .other: return "bell.fill"
        }
    }

    public var displayName: String {
        switch self {
        case .other: return "Other"
        default: return rawValue.capitalized
        }
    }
}

/// Actions that Thea can take on notifications
public struct IntelNotifAction: Identifiable, Sendable {
    public let id = UUID()
    public let type: IntelNotifActionType
    public let description: String
    public let confidence: Double
    public let requiresApproval: Bool
}

/// Types of actions Thea can take
public enum IntelNotifActionType: String, Codable, Sendable {
    case draftReply
    case summarize
    case prepareBriefing
    case trackPackage
    case logTransaction
    case logHealthData
    case clearNotification
    case createTask
    case setReminder
}

/// Per-app notification settings
public struct AppNotificationSettings: Codable, Sendable {
    public var enabled: Bool
    public var autoActionsEnabled: Bool
    public var urgencyOverride: NotificationUrgency?
    public var mutedUntil: Date?

    public init(
        enabled: Bool = true,
        autoActionsEnabled: Bool = false,
        urgencyOverride: NotificationUrgency? = nil,
        mutedUntil: Date? = nil
    ) {
        self.enabled = enabled
        self.autoActionsEnabled = autoActionsEnabled
        self.urgencyOverride = urgencyOverride
        self.mutedUntil = mutedUntil
    }
}

/// Record of a notification clearance synced via CloudKit
public struct NotificationClearance: Identifiable, Codable, Sendable {
    public var id: UUID { notificationID }
    public let notificationID: UUID
    public let appIdentifier: String
    public let clearedAt: Date
    public let clearedBy: String
    public let deviceID: String
}

/// Statistics about notification intelligence activity
public struct NotificationIntelligenceStats: Sendable {
    public let totalClassified: Int
    public let byUrgency: [NotificationUrgency: Int]
    public let byCategory: [IntelNotifCategory: Int]
    public let totalCleared: Int
    public let totalActioned: Int
    public let autoActionRate: Double
}
