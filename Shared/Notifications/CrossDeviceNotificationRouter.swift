//
//  CrossDeviceNotificationRouter.swift
//  Thea
//
//  Created by Thea
//  Smart notification routing based on active device
//

import CloudKit
import Foundation
import os.log
#if canImport(UserNotifications)
    import UserNotifications
#endif

// MARK: - Cross Device Notification Router

/// Routes notifications intelligently based on active device
@MainActor
public final class CrossDeviceNotificationRouter: ObservableObject {
    public static let shared = CrossDeviceNotificationRouter()

    private let logger = Logger(subsystem: "app.thea.notifications", category: "CrossDeviceRouter")

    // MARK: - CloudKit

    private let container: CKContainer
    private let database: CKDatabase

    // MARK: - State

    @Published public private(set) var activeDevice: DeviceInfo?
    @Published public private(set) var routingMode: RoutingMode = .activeDevice
    @Published public private(set) var devicePresence: [String: Date] = [:]

    // MARK: - Configuration

    public var presenceTimeout: TimeInterval = 300 // 5 minutes
    public var priorityThreshold: CrossDeviceNotificationPriority = .normal

    // MARK: - Initialization

    private init() {
        container = CKContainer(identifier: "iCloud.app.thea")
        database = container.privateCloudDatabase

        updateActiveDevice()
    }

    // MARK: - Routing Mode

    public enum RoutingMode: String, CaseIterable, Codable {
        case activeDevice = "Active Device"
        case allDevices = "All Devices"
        case primaryOnly = "Primary Only"
        case manual = "Manual Selection"

        public var description: String {
            switch self {
            case .activeDevice: "Route to the most recently active device"
            case .allDevices: "Send to all connected devices"
            case .primaryOnly: "Only send to primary device (iPhone)"
            case .manual: "Manually select target device"
            }
        }
    }

    // MARK: - Active Device Detection

    /// Update the active device based on recent presence
    public func updateActiveDevice() {
        let devices = DeviceRegistry.shared.onlineDevices

        // Find the most recently active device
        activeDevice = devices.max { $0.lastSeen < $1.lastSeen }

        // Update presence map
        for device in devices {
            devicePresence[device.id] = device.lastSeen
        }

        logger.debug("Active device: \(self.activeDevice?.name ?? "None")")
    }

    /// Report activity from current device
    public func reportActivity() {
        let currentDevice = DeviceRegistry.shared.currentDevice
        devicePresence[currentDevice.id] = Date()
        DeviceRegistry.shared.updatePresence()

        // Broadcast presence update via CloudKit
        Task {
            await broadcastPresence()
        }
    }

    private func broadcastPresence() async {
        let currentDevice = DeviceRegistry.shared.currentDevice
        let recordId = CKRecord.ID(recordName: "presence_\(currentDevice.id)")
        let record = CKRecord(recordType: "DevicePresence", recordID: recordId)

        record["deviceId"] = currentDevice.id
        record["deviceName"] = currentDevice.name
        record["lastSeen"] = Date()
        record["deviceType"] = currentDevice.type.rawValue

        do {
            _ = try await database.save(record)
        } catch {
            logger.error("Failed to broadcast presence: \(error)")
        }
    }

    // MARK: - Notification Routing

    /// Route a notification to appropriate device(s)
    public func routeNotification(_ notification: TheaNotification) async throws -> [String] {
        let targetDevices = determineTargetDevices(for: notification)

        guard !targetDevices.isEmpty else {
            logger.warning("No target devices for notification")
            return []
        }

        var deliveredTo: [String] = []

        for device in targetDevices {
            if device.id == DeviceRegistry.shared.currentDevice.id {
                // Local delivery
                try await deliverLocally(notification)
                deliveredTo.append(device.id)
            } else {
                // Remote delivery via CloudKit
                try await deliverRemotely(notification, to: device)
                deliveredTo.append(device.id)
            }
        }

        logger.info("Notification routed to \(deliveredTo.count) device(s)")

        return deliveredTo
    }

    /// Determine which devices should receive a notification
    private func determineTargetDevices(for notification: TheaNotification) -> [DeviceInfo] {
        updateActiveDevice()

        let allDevices = DeviceRegistry.shared.onlineDevices

        switch routingMode {
        case .activeDevice:
            // Route to the most recently active device
            if let active = activeDevice {
                return [active]
            }
            // Fallback to current device
            return [DeviceRegistry.shared.currentDevice]

        case .allDevices:
            // Send to all online devices
            return allDevices

        case .primaryOnly:
            // Find primary device (usually iPhone)
            if let primary = allDevices.first(where: { $0.type == .iPhone }) {
                return [primary]
            }
            return [DeviceRegistry.shared.currentDevice]

        case .manual:
            // Would use a pre-configured list
            if let targetId = notification.targetDeviceId,
               let target = allDevices.first(where: { $0.id == targetId })
            {
                return [target]
            }
            return [DeviceRegistry.shared.currentDevice]
        }
    }

    // MARK: - Local Delivery

    #if canImport(UserNotifications)
        private func deliverLocally(_ notification: TheaNotification) async throws {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = notification.sound ? .default : nil

            if let subtitle = notification.subtitle {
                content.subtitle = subtitle
            }

            if let categoryId = notification.categoryIdentifier {
                content.categoryIdentifier = categoryId
            }

            // Add custom data
            content.userInfo = notification.userInfo

            let request = UNNotificationRequest(
                identifier: notification.id,
                content: content,
                trigger: nil // Deliver immediately
            )

            try await UNUserNotificationCenter.current().add(request)

            logger.debug("Delivered notification locally: \(notification.id)")
        }
    #else
        private func deliverLocally(_: TheaNotification) async throws {
            // Platform without UserNotifications
            logger.info("Local notification delivery not available on this platform")
        }
    #endif

    // MARK: - Remote Delivery

    private func deliverRemotely(_ notification: TheaNotification, to device: DeviceInfo) async throws {
        // Store notification in CloudKit for remote device to pick up
        let recordId = CKRecord.ID(recordName: "notif_\(notification.id)_\(device.id)")
        let record = CKRecord(recordType: "RemoteNotification", recordID: recordId)

        record["notificationId"] = notification.id
        record["targetDeviceId"] = device.id
        record["title"] = notification.title
        record["body"] = notification.body
        record["subtitle"] = notification.subtitle
        record["priority"] = notification.priority.rawValue
        record["createdAt"] = Date()
        record["delivered"] = false

        if let userData = try? JSONEncoder().encode(notification.userInfo) {
            record["userInfo"] = userData
        }

        _ = try await database.save(record)

        logger.debug("Queued notification for remote delivery to: \(device.name)")
    }

    /// Check for and deliver pending remote notifications
    public func checkForPendingNotifications() async throws {
        let currentDeviceId = DeviceRegistry.shared.currentDevice.id

        let predicate = NSPredicate(
            format: "targetDeviceId == %@ AND delivered == %@",
            currentDeviceId,
            NSNumber(value: false)
        )
        let query = CKQuery(recordType: "RemoteNotification", predicate: predicate)

        let results = try await database.records(matching: query)

        for (_, result) in results.matchResults {
            if case let .success(record) = result {
                // Deliver the notification
                let notification = TheaNotification(from: record)
                try await deliverLocally(notification)

                // Mark as delivered
                record["delivered"] = true
                _ = try await database.save(record)

                logger.info("Delivered pending remote notification: \(notification.id)")
            }
        }
    }

    // MARK: - Configuration

    /// Set routing mode
    public func setRoutingMode(_ mode: RoutingMode) {
        routingMode = mode
        logger.info("Routing mode set to: \(mode.rawValue)")
    }
}

// MARK: - Thea Notification Model

public struct TheaNotification: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let subtitle: String?
    public let priority: CrossDeviceNotificationPriority
    public let categoryIdentifier: String?
    public let threadIdentifier: String?
    public let targetDeviceId: String?
    public let userInfo: [String: String]
    public let sound: Bool
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        subtitle: String? = nil,
        priority: CrossDeviceNotificationPriority = .normal,
        categoryIdentifier: String? = nil,
        threadIdentifier: String? = nil,
        targetDeviceId: String? = nil,
        userInfo: [String: String] = [:],
        sound: Bool = true
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.subtitle = subtitle
        self.priority = priority
        self.categoryIdentifier = categoryIdentifier
        self.threadIdentifier = threadIdentifier
        self.targetDeviceId = targetDeviceId
        self.userInfo = userInfo
        self.sound = sound
        createdAt = Date()
    }

    init(from record: CKRecord) {
        id = record["notificationId"] as? String ?? record.recordID.recordName
        title = record["title"] as? String ?? ""
        body = record["body"] as? String ?? ""
        subtitle = record["subtitle"] as? String
        priority = CrossDeviceNotificationPriority(rawValue: record["priority"] as? String ?? "normal") ?? .normal
        categoryIdentifier = record["categoryIdentifier"] as? String
        threadIdentifier = record["threadIdentifier"] as? String
        targetDeviceId = record["targetDeviceId"] as? String
        sound = true
        createdAt = record["createdAt"] as? Date ?? Date()

        // Decode userInfo
        if let userData = record["userInfo"] as? Data,
           let decoded = try? JSONDecoder().decode([String: String].self, from: userData)
        {
            userInfo = decoded
        } else {
            userInfo = [:]
        }
    }
}

// MARK: - Notification Priority

public enum CrossDeviceNotificationPriority: String, Codable, Sendable, CaseIterable {
    case low
    case normal
    case high
    case critical

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    public var shouldAlwaysDeliver: Bool {
        switch self {
        case .high, .critical:
            true
        default:
            false
        }
    }
}

// MARK: - Quick Notification Methods

public extension CrossDeviceNotificationRouter {
    /// Send a simple notification
    func sendNotification(title: String, body: String) async throws {
        let notification = TheaNotification(title: title, body: body)
        _ = try await routeNotification(notification)
    }

    /// Send a high priority notification
    func sendUrgentNotification(title: String, body: String) async throws {
        let notification = TheaNotification(title: title, body: body, priority: .high)
        _ = try await routeNotification(notification)
    }

    /// Send a notification to specific device
    func sendNotification(title: String, body: String, to deviceId: String) async throws {
        let notification = TheaNotification(
            title: title,
            body: body,
            targetDeviceId: deviceId
        )
        _ = try await routeNotification(notification)
    }

    /// Send a silent data notification
    func sendDataNotification(data: [String: String], to deviceId: String? = nil) async throws {
        let notification = TheaNotification(
            title: "",
            body: "",
            priority: .low,
            targetDeviceId: deviceId,
            userInfo: data,
            sound: false
        )
        _ = try await routeNotification(notification)
    }
}
