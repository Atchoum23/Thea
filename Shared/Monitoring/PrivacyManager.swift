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

    private var permissionStatus: [PrivacyPermission: PermissionStatus] = [:]
    private var consentGiven: Set<PrivacyPermission> = []
    private var isInitialized = false

    // MARK: - Storage

    private let defaults = UserDefaults.standard
    private let consentKey = "PrivacyManager.consentGiven"

    // MARK: - Initialization

    private init() {
        // Load consent synchronously from UserDefaults
        if let data = defaults.data(forKey: consentKey),
           let consent = try? JSONDecoder().decode(Set<String>.self, from: data) {
            consentGiven = Set(consent.compactMap { PrivacyPermission(rawValue: $0) })
        }
        isInitialized = true
    }

    private func loadConsentStatus() {
        if let data = defaults.data(forKey: consentKey),
           let consent = try? JSONDecoder().decode(Set<String>.self, from: data) {
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
    public func checkPermission(_ permission: PrivacyPermission) async -> PermissionStatus {
        #if os(macOS)
        let status = checkMacOSPermission(permission)
        #else
        let status: PermissionStatus = .unknown
        #endif

        permissionStatus[permission] = status
        return status
    }

    #if os(macOS)
    private func checkMacOSPermission(_ permission: PrivacyPermission) -> PermissionStatus {
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
    public func requestPermission(_ permission: PrivacyPermission) async -> PermissionStatus {
        #if os(macOS)
        await requestMacOSPermission(permission)
        #else
        return .unknown
        #endif
    }

    #if os(macOS)
    // swiftlint:disable:next modifier_order
    private nonisolated func requestMacOSPermission(_ permission: PrivacyPermission) async -> PermissionStatus {
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
        let urlString: String
        switch permission {
        case .accessibility, .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        default:
            urlString = "x-apple.systempreferences:com.apple.preference.security"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    // MARK: - Status

    /// Get overall privacy status
    public func getPrivacyStatus() async -> PrivacyStatus {
        var statuses: [PrivacyPermission: PermissionStatus] = [:]

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
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        case .screenRecording: return "Screen Recording"
        case .notifications: return "Notifications"
        case .location: return "Location"
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .photos: return "Photos"
        }
    }

    public var description: String {
        switch self {
        case .accessibility:
            return "Required to monitor app switching and UI interactions"
        case .inputMonitoring:
            return "Required to detect keyboard and mouse activity"
        case .screenRecording:
            return "Required for screen capture features"
        case .notifications:
            return "Required to send notifications"
        case .location:
            return "Required for location-based features"
        case .contacts:
            return "Required for contact integration"
        case .calendar:
            return "Required for calendar integration"
        case .photos:
            return "Required for photo access"
        }
    }

    public var icon: String {
        switch self {
        case .accessibility: return "accessibility"
        case .inputMonitoring: return "keyboard"
        case .screenRecording: return "rectangle.dashed.badge.record"
        case .notifications: return "bell"
        case .location: return "location"
        case .contacts: return "person.crop.circle"
        case .calendar: return "calendar"
        case .photos: return "photo"
        }
    }

    public var isRequired: Bool {
        switch self {
        case .accessibility, .inputMonitoring:
            return true
        default:
            return false
        }
    }
}

// MARK: - Permission Status

public enum PermissionStatus: String, Codable, Sendable {
    case granted
    case denied
    case notDetermined
    case restricted
    case unknown

    public var displayName: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .notDetermined: return "Not Requested"
        case .restricted: return "Restricted"
        case .unknown: return "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle"
        case .restricted: return "lock.circle"
        case .unknown: return "circle"
        }
    }

    public var color: String {
        switch self {
        case .granted: return "green"
        case .denied: return "red"
        case .notDetermined: return "orange"
        case .restricted: return "gray"
        case .unknown: return "gray"
        }
    }
}

// MARK: - Privacy Status

public struct PrivacyStatus: Sendable {
    public let permissionStatuses: [PrivacyPermission: PermissionStatus]
    public let consentGiven: Set<PrivacyPermission>
    public let allPermissionsGranted: Bool

    public var requiredPermissionsGranted: Bool {
        PrivacyPermission.allCases
            .filter(\.isRequired)
            .allSatisfy { permissionStatuses[$0] == .granted }
    }
}
