//
//  CrossDeviceNotificationService+Delivery.swift
//  Thea
//
//  Receive, display, and haptic feedback for cross-device notifications
//  Copyright 2026. All rights reserved.
//

import CloudKit
import Foundation
import OSLog
@preconcurrency import UserNotifications

#if canImport(UIKit)
    import UIKit
#endif

#if os(watchOS)
    import WatchKit
#endif

// MARK: - Receive Notifications

extension CrossDeviceNotificationService {
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
    func displayLocalNotification(_ payload: CrossDeviceNotificationPayload) async {
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
    func triggerHaptic(_ haptic: CrossDeviceNotificationHaptic) async {
        guard haptic != .none else { return }

        #if os(iOS)
            await MainActor.run {
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

}
