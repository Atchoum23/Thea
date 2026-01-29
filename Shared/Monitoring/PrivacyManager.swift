//
//  PrivacyManager.swift
//  Thea
//
//  Created by Claude Code on 2026-01-20
//  Copyright © 2026. All rights reserved.
//

import Foundation
#if os(macOS)
    import AppKit
    import ApplicationServices
#endif

// MARK: - Privacy Manager

/// Manages privacy permissions and user consent for monitoring features
public actor PrivacyManager {
    public static let shared = PrivacyManager()

    // MARK: - State

    private var permissionStatus: [PrivacyPermission: PrivacyPermissionStatus] = [:]
    private var consentGiven: Set<PrivacyPermission> = []
    private var isInitialized = false

    // MARK: - Storage

    private let defaults = UserDefaults.standard
    private let consentKey = "PrivacyManager.consentGiven"

    // MARK: - Initialization

    private init() {
        // Load consent synchronously from UserDefaults
        if let data = defaults.data(forKey: consentKey),
           let consent = try? JSONDecoder().decode(Set<String>.self, from: data)
        {
            consentGiven = Set(consent.compactMap { PrivacyPermission(rawValue: $0) })
        }
        isInitialized = true
    }

    private func loadConsentStatus() {
        if let data = defaults.data(forKey: consentKey),
           let consent = try? JSONDecoder().decode(Set<String>.self, from: data)
        {
            consentGiven = Set(consent.compactMap { PrivacyPermission(rawValue: $0) })
        }
    }

    private func saveConsentStatus() {
        let consentStrings = Set(consentGiven.map(\.rawValue))
        if let data = try? JSONEncoder().encode(consentStrings) {
            defaults.set(data, forKey: consentKey)
        }
    }

    // MARK: - Permission Checking

    /// Check all required permissions
    public func checkAllPermissions() async -> Bool {
        for permission in PrivacyPermission.allCases {
            let status = await checkPermission(permission)
            if status != .granted {
                return false
            }
        }
        return true
    }

    /// Check a specific permission
    public func checkPermission(_ permission: PrivacyPermission) async -> PrivacyPermissionStatus {
        #if os(macOS)
            let status = checkMacOSPermission(permission)
        #else
            let status: PrivacyPermissionStatus = .unknown
        #endif

        permissionStatus[permission] = status
        return status
    }

    #if os(macOS)
        private func checkMacOSPermission(_ permission: PrivacyPermission) -> PrivacyPermissionStatus {
            switch permission {
            case .accessibility:
                let trusted = AXIsProcessTrusted()
                return trusted ? .granted : .denied

            case .inputMonitoring:
                // Input monitoring is part of accessibility on macOS
                let trusted = AXIsProcessTrusted()
                return trusted ? .granted : .denied

            case .screenRecording:
                // Check screen recording permission
                if CGPreflightScreenCaptureAccess() {
                    return .granted
                }
                return .denied

            case .notifications:
                // Notifications are typically always available
                return .granted

            case .location:
                // Location services check
                return .unknown

            case .contacts:
                return .unknown

            case .calendar:
                return .unknown

            case .photos:
                return .unknown
            }
        }
    #endif

    // MARK: - Permission Requests

    /// Request a specific permission
    public func requestPermission(_ permission: PrivacyPermission) async -> PrivacyPermissionStatus {
        #if os(macOS)
            await requestMacOSPermission(permission)
        #else
            return .unknown
        #endif
    }

    #if os(macOS)
        // swiftlint:disable:next modifier_order
        private nonisolated func requestMacOSPermission(_ permission: PrivacyPermission) async -> PrivacyPermissionStatus {
            switch permission {
            case .accessibility, .inputMonitoring:
                // Open System Settings to Accessibility
                // Use string constant directly to avoid concurrency issues with kAXTrustedCheckOptionPrompt
                let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                let trusted = AXIsProcessTrustedWithOptions(options)
                return trusted ? .granted : .denied

            case .screenRecording:
                // Request screen capture access
                CGRequestScreenCaptureAccess()
                return CGPreflightScreenCaptureAccess() ? .granted : .denied

            case .notifications:
                return .granted

            default:
                return .unknown
            }
        }
    #endif

    // MARK: - Consent Management

    /// Record user consent for a permission
    public func recordConsent(_ permission: PrivacyPermission) {
        consentGiven.insert(permission)
        saveConsentStatus()
    }

    /// Revoke user consent for a permission
    public func revokeConsent(_ permission: PrivacyPermission) {
        consentGiven.remove(permission)
        saveConsentStatus()
    }

    /// Check if user has given consent for a permission
    public func hasConsent(_ permission: PrivacyPermission) -> Bool {
        consentGiven.contains(permission)
    }

    /// Get all permissions with consent status
    public func getConsentStatus() -> [PrivacyPermission: Bool] {
        var status: [PrivacyPermission: Bool] = [:]
        for permission in PrivacyPermission.allCases {
            status[permission] = consentGiven.contains(permission)
        }
        return status
    }

    // MARK: - Privacy Controls

    /// Open system privacy settings
    @MainActor
    public func openPrivacySettings(_ permission: PrivacyPermission) {
        #if os(macOS)
            let urlString = switch permission {
            case .accessibility, .inputMonitoring:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .screenRecording:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            default:
                "x-apple.systempreferences:com.apple.preference.security"
            }

            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        #endif
    }

    // MARK: - Status

    /// Get overall privacy status
    public func getPrivacyStatus() async -> PrivacyStatus {
        var statuses: [PrivacyPermission: PrivacyPermissionStatus] = [:]

        for permission in PrivacyPermission.allCases {
            statuses[permission] = await checkPermission(permission)
        }

        let allGranted = statuses.values.allSatisfy { $0 == .granted }

        return PrivacyStatus(
            permissionStatuses: statuses,
            consentGiven: consentGiven,
            allPermissionsGranted: allGranted
        )
    }
}

// MARK: - Privacy Permission

public enum PrivacyPermission: String, Codable, Sendable, CaseIterable {
    case accessibility
    case inputMonitoring
    case screenRecording
    case notifications
    case location
    case contacts
    case calendar
    case photos

    public var displayName: String {
        switch self {
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        case .screenRecording: "Screen Recording"
        case .notifications: "Notifications"
        case .location: "Location"
        case .contacts: "Contacts"
        case .calendar: "Calendar"
        case .photos: "Photos"
        }
    }

    public var description: String {
        switch self {
        case .accessibility:
            "Required to monitor app switching and UI interactions"
        case .inputMonitoring:
            "Required to detect keyboard and mouse activity"
        case .screenRecording:
            "Required for screen capture features"
        case .notifications:
            "Required to send notifications"
        case .location:
            "Required for location-based features"
        case .contacts:
            "Required for contact integration"
        case .calendar:
            "Required for calendar integration"
        case .photos:
            "Required for photo access"
        }
    }

    public var icon: String {
        switch self {
        case .accessibility: "accessibility"
        case .inputMonitoring: "keyboard"
        case .screenRecording: "rectangle.dashed.badge.record"
        case .notifications: "bell"
        case .location: "location"
        case .contacts: "person.crop.circle"
        case .calendar: "calendar"
        case .photos: "photo"
        }
    }

    public var isRequired: Bool {
        switch self {
        case .accessibility, .inputMonitoring:
            true
        default:
            false
        }
    }
}

// MARK: - Privacy Permission Status

/// Status of privacy permissions specific to PrivacyManager
/// Note: This is separate from the comprehensive PermissionStatus in PermissionsManager
public enum PrivacyPermissionStatus: String, Codable, Sendable {
    case granted
    case denied
    case notDetermined
    case restricted
    case unknown

    public var displayName: String {
        switch self {
        case .granted: "Granted"
        case .denied: "Denied"
        case .notDetermined: "Not Requested"
        case .restricted: "Restricted"
        case .unknown: "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .granted: "checkmark.circle.fill"
        case .denied: "xmark.circle.fill"
        case .notDetermined: "questionmark.circle"
        case .restricted: "lock.circle"
        case .unknown: "circle"
        }
    }

    public var color: String {
        switch self {
        case .granted: "green"
        case .denied: "red"
        case .notDetermined: "orange"
        case .restricted: "gray"
        case .unknown: "gray"
        }
    }
}

// MARK: - Privacy Status

public struct PrivacyStatus: Sendable {
    public let permissionStatuses: [PrivacyPermission: PrivacyPermissionStatus]
    public let consentGiven: Set<PrivacyPermission>
    public let allPermissionsGranted: Bool

    public var requiredPermissionsGranted: Bool {
        PrivacyPermission.allCases
            .filter(\.isRequired)
            .allSatisfy { permissionStatuses[$0] == .granted }
    }
}
