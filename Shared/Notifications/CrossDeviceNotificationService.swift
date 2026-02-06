//
//  CrossDeviceNotificationService.swift
//  Thea
//
//  Cross-device notification service using CloudKit and APNs
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Combine
import Foundation
import OSLog
import UserNotifications

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(AppKit)
    import AppKit
#endif

#if os(watchOS)
    import WatchKit
#endif

// MARK: - Cross-Device Notification Service

/// Service for sending notifications across Apple devices using CloudKit relay and APNs
public actor CrossDeviceNotificationService {
    /// Shared instance
    public static let shared = CrossDeviceNotificationService()

    private let logger = Logger(subsystem: "app.thea", category: "CrossDeviceNotification")

    // MARK: - CloudKit Configuration

    private let containerIdentifier = "iCloud.app.theathe"
    private let notificationZoneName = "NotificationZone"
    private var privateDatabase: CKDatabase {
        CKContainer(identifier: containerIdentifier).privateCloudDatabase
    }

    // MARK: - State

    private var currentDeviceRegistration: CrossDeviceRegistration?
    private var registeredDevices: [CrossDeviceRegistration] = []
    private var pendingNotifications: [CrossDeviceNotificationPayload] = []
    private var deliveryTracking: [UUID: [CrossDeviceNotificationDelivery]] = [:]
    private var subscriptionSetup = false

    // MARK: - Change Token

    private var changeToken: CKServerChangeToken? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "thea.notifications.changeToken"),
                  let token = try? NSKeyedUnarchiver.unarchivedObject(
                      ofClass: CKServerChangeToken.self,
                      from: data
                  )
            else { return nil }
            return token
        }
        set {
            if let token = newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: "thea.notifications.changeToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "thea.notifications.changeToken")
            }
        }
    }

    // MARK: - Initialization

    private init() {
        Task {
            await setupNotificationZone()
            await loadCurrentDeviceRegistration()
        }
    }

    // MARK: - Zone Setup

    private func setupNotificationZone() async {
        let zoneID = CKRecordZone.ID(zoneName: notificationZoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            _ = try await privateDatabase.save(zone)
            logger.info("Notification zone created or verified")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists
            logger.debug("Notification zone already exists")
        } catch {
            logger.error("Failed to create notification zone: \(error.localizedDescription)")
        }
    }

    // MARK: - Device Registration

    /// Register the current device for push notifications
    public func registerDevice(deviceToken: Data) async throws -> CrossDeviceRegistration {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        let registration = CrossDeviceRegistration(
            deviceToken: tokenString,
            deviceType: CrossDeviceType.current,
            deviceName: await getDeviceName(),
            modelIdentifier: await getModelIdentifier(),
            osVersion: await getOSVersion(),
            appVersion: getAppVersion()
        )

        // Save to CloudKit
        let record = registration.toRecord()
        do {
            _ = try await privateDatabase.save(record)
            currentDeviceRegistration = registration
            logger.info("Device registered: \(registration.deviceName)")

            // Setup subscriptions after registration
            if !subscriptionSetup {
                await setupCloudKitSubscriptions()
            }

            return registration
        } catch {
            logger.error("Failed to register device: \(error.localizedDescription)")
            throw CrossDeviceNotificationError.registrationFailed(error)
        }
    }

    /// Update device registration (e.g., after token refresh)
    public func updateDeviceToken(_ deviceToken: Data) async throws {
        guard var registration = currentDeviceRegistration else {
            _ = try await registerDevice(deviceToken: deviceToken)
            return
        }

        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        // Update existing registration
        registration = CrossDeviceRegistration(
            id: registration.id,
            deviceToken: tokenString,
            deviceType: registration.deviceType,
            deviceName: registration.deviceName,
            modelIdentifier: registration.modelIdentifier,
            osVersion: await getOSVersion(),
            appVersion: getAppVersion(),
            registeredAt: registration.registeredAt,
            lastSeenAt: Date(),
            pushEnabled: true,
            isActive: true
        )

        let record = registration.toRecord()
        _ = try await privateDatabase.save(record)
        currentDeviceRegistration = registration

        logger.info("Device token updated")
    }

    /// Update device last seen timestamp
    public func updateLastSeen() async {
        guard var registration = currentDeviceRegistration else { return }

        registration = CrossDeviceRegistration(
            id: registration.id,
            deviceToken: registration.deviceToken,
            deviceType: registration.deviceType,
            deviceName: registration.deviceName,
            modelIdentifier: registration.modelIdentifier,
            osVersion: registration.osVersion,
            appVersion: registration.appVersion,
            registeredAt: registration.registeredAt,
            lastSeenAt: Date(),
            pushEnabled: registration.pushEnabled,
            isActive: registration.isActive
        )

        let record = registration.toRecord()
        do {
            _ = try await privateDatabase.save(record)
            currentDeviceRegistration = registration
        } catch {
            logger.warning("Failed to update last seen: \(error.localizedDescription)")
        }
    }

    /// Unregister the current device
    public func unregisterDevice() async throws {
        guard let registration = currentDeviceRegistration else { return }

        let recordID = CKRecord.ID(recordName: registration.recordID)
        try await privateDatabase.deleteRecord(withID: recordID)
        currentDeviceRegistration = nil

        logger.info("Device unregistered")
    }

    /// Fetch all registered devices for the current user
    public func fetchRegisteredDevices() async throws -> [CrossDeviceRegistration] {
        let query = CKQuery(
            recordType: "DeviceRegistration",
            predicate: NSPredicate(format: "isActive == %@", NSNumber(value: true))
        )

        let results = try await privateDatabase.records(matching: query)

        var devices: [CrossDeviceRegistration] = []
        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                devices.append(CrossDeviceRegistration(from: record))
            }
        }

        registeredDevices = devices
        return devices
    }

    /// Get devices excluding the current device
    public func getOtherDevices() async throws -> [CrossDeviceRegistration] {
        let allDevices = try await fetchRegisteredDevices()
        guard let currentId = currentDeviceRegistration?.id else {
            return allDevices
        }
        return allDevices.filter { $0.id != currentId }
    }

    // MARK: - Send Notifications

    /// Send a notification to other devices
    public func sendNotification(_ payload: CrossDeviceNotificationPayload) async throws {
        // Save notification to CloudKit for relay
        let record = payload.toRecord()

        do {
            _ = try await privateDatabase.save(record)
            logger.info("Notification saved for relay: \(payload.id)")

            // Track delivery
            let otherDevices = try await getOtherDevices()
            var deliveries: [CrossDeviceNotificationDelivery] = []

            for device in otherDevices {
                // Check if this device should receive the notification
                if let targetIds = payload.targetDeviceIds, !targetIds.contains(device.id) {
                    continue
                }

                let delivery = CrossDeviceNotificationDelivery(
                    notificationId: payload.id,
                    deviceId: device.id,
                    status: .sent,
                    sentAt: Date()
                )
                deliveries.append(delivery)
            }

            deliveryTracking[payload.id] = deliveries

        } catch {
            logger.error("Failed to send notification: \(error.localizedDescription)")
            throw CrossDeviceNotificationError.sendFailed(error)
        }
    }

    /// Send a notification with convenience parameters
    public func send(
        category: CrossDeviceNotificationCategory,
        title: String,
        body: String,
        subtitle: String? = nil,
        priority: CrossDeviceNotificationPriority? = nil,
        deepLink: URL? = nil,
        userInfo: [String: String] = [:],
        targetDevices: [UUID]? = nil
    ) async throws {
        guard let sourceDevice = currentDeviceRegistration else {
            throw CrossDeviceNotificationError.notRegistered
        }

        let payload = CrossDeviceNotificationPayload(
            category: category,
            priority: priority,
            title: title,
            body: body,
            subtitle: subtitle,
            deepLink: deepLink,
            userInfo: userInfo,
            sourceDeviceId: sourceDevice.id,
            sourceDeviceName: sourceDevice.deviceName,
            targetDeviceIds: targetDevices
        )

        try await sendNotification(payload)
    }

    // MARK: - Convenience Senders

    /// Notify that a task completed on this device
    public func notifyTaskCompletion(
        taskName: String,
        result: String,
        deepLink: URL? = nil
    ) async throws {
        try await send(
            category: .taskCompletion,
            title: "Task Completed",
            body: taskName,
            subtitle: result,
            deepLink: deepLink
        )
    }

    /// Notify that an AI response is ready
    public func notifyAIResponseReady(
        conversationId: String,
        preview: String
    ) async throws {
        let preview = preview.prefix(100)
        try await send(
            category: .aiResponseReady,
            title: "AI Response Ready",
            body: String(preview) + (preview.count >= 100 ? "..." : ""),
            deepLink: URL(string: "thea://conversation/\(conversationId)")
        )
    }

    /// Request password input from user on another device
    public func requestPassword(
        service: String,
        reason: String,
        requestId: String
    ) async throws {
        try await send(
            category: .passwordNeeded,
            title: "Password Needed",
            body: "Enter password for \(service)",
            subtitle: reason,
            priority: .critical,
            userInfo: ["requestId": requestId, "service": service]
        )
    }

    /// Request approval for an action
    public func requestApproval(
        action: String,
        details: String,
        requestId: String
    ) async throws {
        try await send(
            category: .approvalRequired,
            title: "Approval Required",
            body: action,
            subtitle: details,
            priority: .critical,
            userInfo: ["requestId": requestId]
        )
    }

    /// Notify sync completed
    public func notifySyncComplete(
        itemCount: Int,
        syncType: String
    ) async throws {
        try await send(
            category: .syncComplete,
            title: "Sync Complete",
            body: "\(itemCount) \(syncType) synced",
            priority: .low
        )
    }

    /// Notify about an error
    public func notifyError(
        errorTitle: String,
        errorMessage: String,
        errorCode: String? = nil
    ) async throws {
        var userInfo: [String: String] = [:]
        if let errorCode {
            userInfo["errorCode"] = errorCode
        }

        try await send(
            category: .errorAlert,
            title: errorTitle,
            body: errorMessage,
            priority: .high,
            userInfo: userInfo
        )
    }

    /// Notify agent status update
    public func notifyAgentUpdate(
        agentName: String,
        status: String,
        details: String? = nil
    ) async throws {
        try await send(
            category: .agentUpdate,
            title: "\(agentName) Update",
            body: status,
            subtitle: details
        )
    }

    /// Send a reminder to other devices
    public func sendReminder(
        title: String,
        message: String,
        dueDate: Date? = nil
    ) async throws {
        var userInfo: [String: String] = [:]
        if let dueDate {
            userInfo["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
        }

        try await send(
            category: .reminder,
            title: title,
            body: message,
            userInfo: userInfo
        )
    }

    /// Notify file processing is complete
    public func notifyFileReady(
        fileName: String,
        fileType: String,
        fileId: String
    ) async throws {
        try await send(
            category: .fileReady,
            title: "File Ready",
            body: fileName,
            subtitle: fileType,
            deepLink: URL(string: "thea://file/\(fileId)")
        )
    }

    // MARK: - Receive Notifications

    /// Handle incoming CloudKit notification
    public func handleCloudKitNotification(_ userInfo: [AnyHashable: Any]) async {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        guard let queryNotification = notification as? CKQueryNotification,
              queryNotification.subscriptionID == "cross-device-notifications"
        else { return }

        // Fetch the new notification record
        guard let recordID = queryNotification.recordID else { return }

        do {
            let record = try await privateDatabase.record(for: recordID)
            let payload = CrossDeviceNotificationPayload(from: record)

            // Don't process notifications from this device
            if payload.sourceDeviceId == currentDeviceRegistration?.id {
                return
            }

            // Check if notification is expired
            if let expiresAt = payload.expiresAt, expiresAt < Date() {
                logger.debug("Notification expired, ignoring: \(payload.id)")
                return
            }

            // Check preferences
            let preferences = await MainActor.run { CrossDeviceNotificationPreferences.shared }
            let shouldDeliver = await preferences.shouldDeliver(
                category: payload.category,
                priority: payload.priority,
                toDevice: currentDeviceRegistration?.id
            )

            guard shouldDeliver else {
                logger.debug("Notification filtered by preferences: \(payload.id)")
                return
            }

            // Display local notification
            await displayLocalNotification(payload)

            // Track delivery
            if payload.requiresAcknowledgment {
                await saveDeliveryConfirmation(payload.id)
            }

        } catch {
            logger.error("Failed to process CloudKit notification: \(error.localizedDescription)")
        }
    }

    /// Display a local notification from a cross-device payload
    private func displayLocalNotification(_ payload: CrossDeviceNotificationPayload) async {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body

        if let subtitle = payload.subtitle {
            content.subtitle = subtitle
        }

        content.categoryIdentifier = payload.category.identifier
        content.threadIdentifier = payload.threadId ?? payload.category.identifier

        // Sound
        if payload.sound != .none {
            if payload.sound == .default {
                content.sound = .default
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(payload.sound.rawValue))
            }
        }

        // Badge
        if let badge = payload.badge {
            content.badge = NSNumber(value: badge)
        }

        // Interruption level
        if #available(iOS 15.0, macOS 12.0, watchOS 8.0, *) {
            switch payload.priority {
            case .critical:
                content.interruptionLevel = .critical
            case .high:
                content.interruptionLevel = .timeSensitive
            case .normal:
                content.interruptionLevel = .active
            case .low:
                content.interruptionLevel = .passive
            }
        }

        // User info
        var userInfo: [AnyHashable: Any] = [
            "notificationId": payload.id.uuidString,
            "category": payload.category.rawValue,
            "sourceDeviceId": payload.sourceDeviceId.uuidString,
            "sourceDeviceName": payload.sourceDeviceName,
            "haptic": payload.haptic.rawValue
        ]

        if let deepLink = payload.deepLink {
            userInfo["deepLink"] = deepLink.absoluteString
        }

        for (key, value) in payload.userInfo {
            userInfo[key] = value
        }

        content.userInfo = userInfo

        // Create and schedule request
        let request = UNNotificationRequest(
            identifier: payload.id.uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Displayed local notification: \(payload.id)")

            // Trigger haptic feedback
            await triggerHaptic(payload.haptic)

        } catch {
            logger.error("Failed to display notification: \(error.localizedDescription)")
        }
    }

    /// Trigger haptic feedback
    private func triggerHaptic(_ haptic: CrossDeviceNotificationHaptic) async {
        guard haptic != .none else { return }

        #if os(iOS)
            await MainActor.run {
                let generator: UIFeedbackGenerator

                switch haptic {
                case .none:
                    return
                case .light:
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    return
                case .medium:
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    return
                case .heavy:
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                    return
                case .success:
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                    return
                case .warning:
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.warning)
                    return
                case .error:
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                    return
                }
            }
        #elseif os(watchOS)
            await MainActor.run {
                let device = WKInterfaceDevice.current()

                switch haptic {
                case .none:
                    break
                case .light, .medium:
                    device.play(.click)
                case .heavy:
                    device.play(.directionUp)
                case .success:
                    device.play(.success)
                case .warning:
                    device.play(.retry)
                case .error:
                    device.play(.failure)
                }
            }
        #endif
    }

    // MARK: - Acknowledgment

    /// Acknowledge receipt of a notification
    public func acknowledgeNotification(_ notificationId: UUID, action: String? = nil) async throws {
        guard let deviceId = currentDeviceRegistration?.id else {
            throw CrossDeviceNotificationError.notRegistered
        }

        let acknowledgment = CrossDeviceNotificationAcknowledgment(
            notificationId: notificationId,
            deviceId: deviceId,
            action: action
        )

        let record = acknowledgment.toRecord()
        _ = try await privateDatabase.save(record)

        logger.info("Acknowledged notification: \(notificationId)")
    }

    /// Save delivery confirmation
    private func saveDeliveryConfirmation(_ notificationId: UUID) async {
        guard let deviceId = currentDeviceRegistration?.id else { return }

        // Update delivery tracking in CloudKit
        let recordID = CKRecord.ID(recordName: "delivery-\(notificationId)-\(deviceId)")
        let record = CKRecord(recordType: "NotificationDelivery", recordID: recordID)
        record["notificationId"] = notificationId.uuidString as CKRecordValue
        record["deviceId"] = deviceId.uuidString as CKRecordValue
        record["status"] = TheaNotificationDelivery.DeliveryStatus.delivered.rawValue as CKRecordValue
        record["deliveredAt"] = Date() as CKRecordValue

        do {
            _ = try await privateDatabase.save(record)
        } catch {
            logger.warning("Failed to save delivery confirmation: \(error.localizedDescription)")
        }
    }

    // MARK: - CloudKit Subscriptions

    private func setupCloudKitSubscriptions() async {
        // Subscribe to new notifications
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "CrossDeviceNotification",
            predicate: predicate,
            subscriptionID: "cross-device-notifications",
            options: [.firesOnRecordCreation]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = false
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await privateDatabase.save(subscription)
            subscriptionSetup = true
            logger.info("CloudKit subscription setup complete")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription might already exist
            subscriptionSetup = true
            logger.debug("Subscription already exists")
        } catch {
            logger.error("Failed to setup CloudKit subscription: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    /// Clean up expired notifications
    public func cleanupExpiredNotifications() async {
        let predicate = NSPredicate(format: "expiresAt < %@", Date() as NSDate)
        let query = CKQuery(recordType: "CrossDeviceNotification", predicate: predicate)

        do {
            let results = try await privateDatabase.records(matching: query)

            var recordIDsToDelete: [CKRecord.ID] = []
            for (recordID, _) in results.matchResults {
                recordIDsToDelete.append(recordID)
            }

            if !recordIDsToDelete.isEmpty {
                _ = try await privateDatabase.modifyRecords(saving: [], deleting: recordIDsToDelete)
                logger.info("Cleaned up \(recordIDsToDelete.count) expired notifications")
            }
        } catch {
            logger.warning("Failed to cleanup expired notifications: \(error.localizedDescription)")
        }
    }

    /// Clean up old delivery records
    public func cleanupOldDeliveryRecords(olderThan days: Int = 7) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "deliveredAt < %@", cutoffDate as NSDate)
        let query = CKQuery(recordType: "NotificationDelivery", predicate: predicate)

        do {
            let results = try await privateDatabase.records(matching: query)

            var recordIDsToDelete: [CKRecord.ID] = []
            for (recordID, _) in results.matchResults {
                recordIDsToDelete.append(recordID)
            }

            if !recordIDsToDelete.isEmpty {
                _ = try await privateDatabase.modifyRecords(saving: [], deleting: recordIDsToDelete)
                logger.info("Cleaned up \(recordIDsToDelete.count) old delivery records")
            }
        } catch {
            logger.warning("Failed to cleanup old delivery records: \(error.localizedDescription)")
        }
    }

    // MARK: - Device Info Helpers

    private func loadCurrentDeviceRegistration() async {
        // Try to load from UserDefaults first
        if let data = UserDefaults.standard.data(forKey: "thea.notifications.deviceRegistration"),
           let registration = try? JSONDecoder().decode(CrossDeviceRegistration.self, from: data) {
            currentDeviceRegistration = registration
            return
        }

        // Check CloudKit for existing registration with this device name
        let deviceName = await getDeviceName()
        let predicate = NSPredicate(format: "deviceName == %@", deviceName)
        let query = CKQuery(recordType: "DeviceRegistration", predicate: predicate)

        do {
            let results = try await privateDatabase.records(matching: query)

            for (_, result) in results.matchResults {
                if case let .success(record) = result {
                    let registration = CrossDeviceRegistration(from: record)
                    currentDeviceRegistration = registration

                    // Cache locally
                    if let data = try? JSONEncoder().encode(registration) {
                        UserDefaults.standard.set(data, forKey: "thea.notifications.deviceRegistration")
                    }

                    return
                }
            }
        } catch {
            logger.warning("Failed to load device registration: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func getDeviceName() -> String {
        #if os(iOS)
            return UIDevice.current.name
        #elseif os(macOS)
            return Host.current().localizedName ?? "Mac"
        #elseif os(watchOS)
            return WKInterfaceDevice.current().name
        #elseif os(tvOS)
            return UIDevice.current.name
        #else
            return "Unknown Device"
        #endif
    }

    @MainActor
    private func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    @MainActor
    private func getOSVersion() -> String {
        #if os(iOS) || os(tvOS)
            return UIDevice.current.systemVersion
        #elseif os(macOS)
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #elseif os(watchOS)
            return WKInterfaceDevice.current().systemVersion
        #else
            return "Unknown"
        #endif
    }

    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    // MARK: - Status

    /// Get current device registration
    public func getCurrentDevice() -> CrossDeviceRegistration? {
        currentDeviceRegistration
    }

    /// Get cached registered devices
    public func getCachedDevices() -> [CrossDeviceRegistration] {
        registeredDevices
    }

    /// Check if service is ready
    public var isReady: Bool {
        currentDeviceRegistration != nil && subscriptionSetup
    }
}

// MARK: - Errors

/// Errors for cross-device notification operations
public enum CrossDeviceNotificationError: Error, LocalizedError, Sendable {
    case notRegistered
    case registrationFailed(Error)
    case sendFailed(Error)
    case subscriptionFailed(Error)
    case deviceNotFound
    case notificationExpired
    case deliveryFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notRegistered:
            "Device not registered for notifications"
        case .registrationFailed(let error):
            "Failed to register device: \(error.localizedDescription)"
        case .sendFailed(let error):
            "Failed to send notification: \(error.localizedDescription)"
        case .subscriptionFailed(let error):
            "Failed to setup notification subscription: \(error.localizedDescription)"
        case .deviceNotFound:
            "Target device not found"
        case .notificationExpired:
            "Notification has expired"
        case .deliveryFailed(let reason):
            "Notification delivery failed: \(reason)"
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when a cross-device notification is received
    static let theaCrossDeviceNotificationReceived = Notification.Name("theaCrossDeviceNotificationReceived")

    /// Posted when device registration changes
    static let theaDeviceRegistrationChanged = Notification.Name("theaDeviceRegistrationChanged")

    /// Posted when registered devices list updates
    static let theaRegisteredDevicesUpdated = Notification.Name("theaRegisteredDevicesUpdated")
}

// MARK: - UNUserNotificationCenter Extension

public extension UNUserNotificationCenter {
    /// Register notification categories for cross-device notifications
    func registerTheaCrossDeviceCategories() {
        var categories = Set<UNNotificationCategory>()

        for category in CrossDeviceNotificationCategory.allCases {
            let actions = actionsForCategory(category)
            let unCategory = UNNotificationCategory(
                identifier: category.identifier,
                actions: actions,
                intentIdentifiers: [],
                options: optionsForCategory(category)
            )
            categories.insert(unCategory)
        }

        // Merge with existing categories
        getNotificationCategories { existingCategories in
            let allCategories = existingCategories.union(categories)
            self.setNotificationCategories(allCategories)
        }
    }

    private func actionsForCategory(_ category: CrossDeviceNotificationCategory) -> [UNNotificationAction] {
        switch category {
        case .passwordNeeded:
            [
                UNTextInputNotificationAction(
                    identifier: "ENTER_PASSWORD",
                    title: "Enter Password",
                    options: [.authenticationRequired],
                    textInputButtonTitle: "Submit",
                    textInputPlaceholder: "Password"
                ),
                UNNotificationAction(
                    identifier: "CANCEL",
                    title: "Cancel",
                    options: [.destructive]
                )
            ]

        case .approvalRequired:
            [
                UNNotificationAction(
                    identifier: "APPROVE",
                    title: "Approve",
                    options: [.authenticationRequired]
                ),
                UNNotificationAction(
                    identifier: "DENY",
                    title: "Deny",
                    options: [.destructive]
                )
            ]

        case .aiResponseReady, .taskCompletion:
            [
                UNNotificationAction(
                    identifier: "VIEW",
                    title: "View",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: []
                )
            ]

        case .errorAlert:
            [
                UNNotificationAction(
                    identifier: "VIEW_DETAILS",
                    title: "View Details",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "RETRY",
                    title: "Retry",
                    options: []
                )
            ]

        case .reminder:
            [
                UNNotificationAction(
                    identifier: "COMPLETE",
                    title: "Mark Complete",
                    options: []
                ),
                UNNotificationAction(
                    identifier: "SNOOZE",
                    title: "Snooze",
                    options: []
                )
            ]

        default:
            [
                UNNotificationAction(
                    identifier: "VIEW",
                    title: "View",
                    options: [.foreground]
                )
            ]
        }
    }

    private func optionsForCategory(_ category: CrossDeviceNotificationCategory) -> UNNotificationCategoryOptions {
        switch category {
        case .passwordNeeded, .approvalRequired:
            return [.customDismissAction, .hiddenPreviewsShowTitle]
        case .aiResponseReady:
            #if os(iOS)
                return [.allowInCarPlay, .customDismissAction]
            #else
                return [.customDismissAction]
            #endif
        default:
            return []
        }
    }
}
