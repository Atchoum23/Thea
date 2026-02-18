// ExtensionSyncBridge+SyncAPI.swift
// State synchronization, App Group sync, and public API methods extracted from ExtensionSyncBridge

import Foundation
import Network

extension ExtensionSyncBridge {

    // MARK: - State Synchronization

    func sendCurrentState(to connection: NWConnection) {
        let state = getCurrentState()
        let message = SyncMessage(
            type: .stateUpdate,
            data: ["state": AnyCodable(state)]
        )
        send(message, to: connection)
    }

    func getCurrentState() -> [String: Any] {
        [
            "adBlockerEnabled": adBlockerEnabled,
            "darkModeEnabled": darkModeEnabled,
            "darkModeTheme": darkModeThemeId,
            "privacyProtectionEnabled": privacyProtectionEnabled,
            "passwordManagerEnabled": !passwordManagerLocked,
            "emailProtectionEnabled": emailProtectionAutoRemoveTrackers,
            "printFriendlyEnabled": printFriendlyAutoDetect,
            "stats": [
                "adsBlocked": stats.adsBlocked,
                "trackersBlocked": stats.trackersBlocked,
                "emailsProtected": stats.emailsProtected,
                "passwordsAutofilled": stats.passwordsAutofilled,
                "pagesDarkened": stats.pagesDarkened
            ]
        ]
    }

    func mergeExtensionState(_ extensionState: [String: Any]) {
        // Merge stats
        if let statsData = extensionState["stats"] as? [String: Int] {
            if let adsBlocked = statsData["adsBlocked"] {
                stats.adsBlocked = max(stats.adsBlocked, adsBlocked)
            }
            if let trackersBlocked = statsData["trackersBlocked"] {
                stats.trackersBlocked = max(stats.trackersBlocked, trackersBlocked)
            }
            if let emailsProtected = statsData["emailsProtected"] {
                stats.emailsProtected = max(stats.emailsProtected, emailsProtected)
            }
            if let passwordsAutofilled = statsData["passwordsAutofilled"] {
                stats.passwordsAutofilled = max(stats.passwordsAutofilled, passwordsAutofilled)
            }
            if let pagesDarkened = statsData["pagesDarkened"] {
                stats.pagesDarkened = max(stats.pagesDarkened, pagesDarkened)
            }
        }
    }

    // MARK: - App Group Sync (Safari)

    func setupAppGroupSync() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.warning("Failed to access app group")
            return
        }

        // Watch for changes from Safari extension
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppGroupChange()
            }
        }
    }

    func handleAppGroupChange() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        // Check for pending messages from Safari extension
        if let messageData = userDefaults.data(forKey: "safari.pendingMessage") {
            do {
                let message = try JSONDecoder().decode(SyncMessage.self, from: messageData)
                handleSafariExtensionMessage(message)
            } catch {
                logger.debug("Could not decode Safari extension message: \(error.localizedDescription)")
            }
            userDefaults.removeObject(forKey: "safari.pendingMessage")
        }
    }

    func handleSafariExtensionMessage(_ message: SyncMessage) {
        switch message.type {
        case .stateUpdate, .featureToggle, .statsUpdate:
            handleMessage(message, from: activeConnections.first ?? NWConnection(host: "localhost", port: 0, using: .tcp))
        default:
            break
        }
    }

    func syncToAppGroup(_ message: SyncMessage) {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        do {
            let data = try JSONEncoder().encode(message)
            userDefaults.set(data, forKey: "app.pendingMessage")
        } catch {
            logger.debug("Could not encode message for app group: \(error.localizedDescription)")
        }

        // Also sync current state
        let state = getCurrentState()
        do {
            let stateData = try JSONSerialization.data(withJSONObject: state)
            userDefaults.set(stateData, forKey: "app.currentState")
        } catch {
            logger.debug("Could not serialize state for app group: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Feature Toggle Methods

    /// Update ad blocker state and broadcast to extensions
    public func setAdBlockerEnabled(_ enabled: Bool) {
        adBlockerEnabled = enabled
        broadcastFeatureChange("adBlocker", enabled: enabled)
    }

    /// Update dark mode state and broadcast to extensions
    public func setDarkModeEnabled(_ enabled: Bool) {
        darkModeEnabled = enabled
        broadcastFeatureChange("darkMode", enabled: enabled)
    }

    /// Update dark mode theme and broadcast to extensions
    public func setDarkModeTheme(_ themeId: String) {
        darkModeThemeId = themeId
        let message = SyncMessage(
            type: .themeChange,
            data: ["theme": AnyCodable(themeId)]
        )
        broadcast(message)
    }

    /// Update privacy protection state and broadcast to extensions
    public func setPrivacyProtectionEnabled(_ enabled: Bool) {
        privacyProtectionEnabled = enabled
        broadcastFeatureChange("privacyProtection", enabled: enabled)
    }

    func broadcastFeatureChange(_ feature: String, enabled: Bool) {
        let message = SyncMessage(
            type: .featureToggle,
            data: [
                "feature": AnyCodable(feature),
                "enabled": AnyCodable(enabled)
            ]
        )
        broadcast(message)
    }

    // MARK: - Public API

    /// Notify extensions of credential update
    public func notifyCredentialUpdate(domain: String) {
        let message = SyncMessage(
            type: .credentialUpdate,
            data: ["domain": AnyCodable(domain)]
        )
        broadcast(message)
    }

    /// Notify extensions of alias creation
    public func notifyAliasCreated(alias: EmailAlias) {
        let message = SyncMessage(
            type: .aliasCreated,
            data: [
                "id": AnyCodable(alias.id),
                "alias": AnyCodable(alias.alias),
                "domain": AnyCodable(alias.domain)
            ]
        )
        broadcast(message)
    }

    /// Force sync with all extensions
    public func forceSync() {
        let message = SyncMessage(
            type: .sync,
            data: ["state": AnyCodable(getCurrentState())]
        )
        broadcast(message)
        lastSyncTime = Date()
    }
}
