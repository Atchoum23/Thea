// ExtensionSyncBridge+MessageHandlers.swift
// Message handler methods extracted from ExtensionSyncBridge

import Foundation
import Network

extension ExtensionSyncBridge {

    // MARK: - Message Handlers

    func handleIdentify(_ message: SyncMessage, from connection: NWConnection) {
        guard let extensionType = message.data["type"]?.value as? String,
              let version = message.data["version"]?.value as? String
        else {
            return
        }

        let extensionConnection = ExtensionConnection(
            connectionId: ObjectIdentifier(connection).debugDescription,
            type: ExtensionType(rawValue: extensionType) ?? .chrome,
            version: version,
            connectedAt: Date(),
            lastHeartbeat: Date()
        )

        // Remove existing connection of same type
        connectedExtensions.removeAll { $0.type == extensionConnection.type }
        connectedExtensions.append(extensionConnection)

        logger.info("Extension identified: \(extensionType) v\(version)")

        // Send acknowledgment with current state
        sendCurrentState(to: connection)
    }

    func handleSync(_ message: SyncMessage, from connection: NWConnection) {
        // Merge state from extension
        if let extensionState = message.data["state"]?.value as? [String: Any] {
            mergeExtensionState(extensionState)
        }

        lastSyncTime = Date()

        // Send updated state back
        sendCurrentState(to: connection)
    }

    func handleStateUpdate(_ message: SyncMessage, from _: NWConnection) {
        if let extensionState = message.data["state"]?.value as? [String: Any] {
            mergeExtensionState(extensionState)
        }
    }

    func handleFeatureToggle(_ message: SyncMessage) {
        guard let feature = message.data["feature"]?.value as? String,
              let enabled = message.data["enabled"]?.value as? Bool
        else {
            return
        }

        // Update feature state locally
        switch feature {
        case "adBlocker":
            adBlockerEnabled = enabled
        case "darkMode":
            darkModeEnabled = enabled
        case "privacyProtection":
            privacyProtectionEnabled = enabled
        case "passwordManager":
            passwordManagerLocked = !enabled
        case "emailProtection":
            emailProtectionAutoRemoveTrackers = enabled
        default:
            break
        }

        // Broadcast to all extensions
        let updateMessage = SyncMessage(
            type: .featureToggle,
            data: [
                "feature": AnyCodable(feature),
                "enabled": AnyCodable(enabled)
            ]
        )
        broadcast(updateMessage)
    }

    func handleCredentialRequest(_ message: SyncMessage, from connection: NWConnection) {
        guard let domain = message.data["domain"]?.value as? String else { return }

        // Credential requests are handled via notification to the app
        // The app layer should respond with the actual credentials
        let response = SyncMessage(
            type: .credentialResponse,
            data: [
                "domain": AnyCodable(domain),
                "hasCredentials": AnyCodable(false),
                "count": AnyCodable(0)
            ]
        )
        send(response, to: connection)

        // Post notification for app to handle
        NotificationCenter.default.post(
            name: .extensionCredentialRequest,
            object: nil,
            userInfo: ["domain": domain, "connection": connection]
        )
    }

    func handleAliasRequest(_ message: SyncMessage, from connection: NWConnection) {
        guard let domain = message.data["domain"]?.value as? String else { return }

        // Alias generation is handled via notification to the app
        // Post notification for app to handle
        NotificationCenter.default.post(
            name: .extensionAliasRequest,
            object: nil,
            userInfo: ["domain": domain, "connection": connection]
        )
    }

    func handleStatsUpdate(_ message: SyncMessage) {
        if let statsData = message.data["stats"]?.value as? [String: Any] {
            // Update local stats
            if let adsBlocked = statsData["adsBlocked"] as? Int {
                stats.adsBlocked += adsBlocked
            }
            if let trackersBlocked = statsData["trackersBlocked"] as? Int {
                stats.trackersBlocked += trackersBlocked
            }
        }
    }

    func updateConnectionHeartbeat(_ connection: NWConnection) {
        let connectionId = ObjectIdentifier(connection).debugDescription
        if let index = connectedExtensions.firstIndex(where: { $0.connectionId == connectionId }) {
            connectedExtensions[index].lastHeartbeat = Date()
        }
    }
}
