//
//  PermissionsTypes.swift
//  Thea
//
//  Permission types and enums for the PermissionsManager
//  Categories match macOS Privacy & Security layout
//

import Foundation

// MARK: - Permission Status

public enum PermissionStatus: String, Codable, Sendable, CaseIterable {
    case notDetermined = "Not Set"
    case authorized = "Authorized"
    case denied = "Denied"
    case restricted = "Restricted"
    case limited = "Limited"
    case provisional = "Provisional"
    case notAvailable = "Not Available"
    case unknown = "Unknown"

    public var icon: String {
        switch self {
        case .notDetermined: return "questionmark.circle"
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .restricted: return "lock.circle.fill"
        case .limited: return "circle.lefthalf.filled"
        case .provisional: return "clock.circle"
        case .notAvailable: return "minus.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    public var color: String {
        switch self {
        case .notDetermined: return "gray"
        case .authorized: return "green"
        case .denied: return "red"
        case .restricted: return "orange"
        case .limited: return "yellow"
        case .provisional: return "blue"
        case .notAvailable: return "gray"
        case .unknown: return "gray"
        }
    }

    public var canRequest: Bool {
        self == .notDetermined
    }
}

// MARK: - Permission Category

/// Categories matching macOS System Settings > Privacy & Security layout
public enum PermissionCategory: String, CaseIterable, Identifiable, Sendable {
    /// Data & Privacy permissions (user data access)
    case dataPrivacy = "Data & Privacy"
    /// Security & Access permissions (system-level access)
    case securityAccess = "Security & Access"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .dataPrivacy: return "lock.shield.fill"
        case .securityAccess: return "gearshape.fill"
        }
    }
}

// MARK: - Permission Type

public enum PermissionType: String, CaseIterable, Identifiable, Sendable {
    // Data & Privacy (Group 1)
    case calendars = "Calendars"
    case contacts = "Contacts"
    case fullDiskAccess = "Full Disk Access"
    case homeKit = "Home"
    case mediaLibrary = "Media & Apple Music"
    case passkeys = "Passkeys Access for Web Browsers"
    case photoLibrary = "Photos"
    case reminders = "Reminders"
    case notes = "Notes"

    // Security & Access (Group 2)
    case accessibility = "Accessibility"
    case appManagement = "App Management"
    case automation = "Automation"
    case bluetooth = "Bluetooth"
    case camera = "Camera"
    case developerTools = "Developer Tools"
    case focusStatus = "Focus"
    case inputMonitoring = "Input Monitoring"
    case localNetwork = "Local Network"
    case microphone = "Microphone"
    case motionFitness = "Motion & Fitness"
    case remoteDesktop = "Remote Desktop"
    case screenRecording = "Screen & System Audio Recording"
    case speechRecognition = "Speech Recognition"

    // iOS-only (not shown on macOS)
    case locationWhenInUse = "Location (When In Use)"
    case locationAlways = "Location (Always)"
    case notifications = "Notifications"
    case criticalAlerts = "Critical Alerts"
    case healthRead = "Health Data (Read)"
    case healthWrite = "Health Data (Write)"
    case photoLibraryAddOnly = "Photos (Add Only)"
    case siri = "Siri & Shortcuts"
    case faceID = "Face ID / Touch ID"

    public var id: String { rawValue }

    public var category: PermissionCategory {
        switch self {
        // Data & Privacy
        case .calendars, .contacts, .fullDiskAccess, .homeKit,
             .mediaLibrary, .passkeys, .photoLibrary, .reminders, .notes:
            return .dataPrivacy
        // Security & Access
        case .accessibility, .appManagement, .automation, .bluetooth,
             .camera, .developerTools, .focusStatus, .inputMonitoring,
             .localNetwork, .microphone, .motionFitness, .remoteDesktop,
             .screenRecording, .speechRecognition:
            return .securityAccess
        // iOS-only mapped to closest category
        case .locationWhenInUse, .locationAlways:
            return .securityAccess
        case .notifications, .criticalAlerts:
            return .securityAccess
        case .healthRead, .healthWrite:
            return .dataPrivacy
        case .photoLibraryAddOnly:
            return .dataPrivacy
        case .siri:
            return .securityAccess
        case .faceID:
            return .securityAccess
        }
    }

    public var description: String {
        switch self {
        case .calendars: return "Access calendar events and schedules."
        case .contacts: return "Access and manage your contacts."
        case .fullDiskAccess: return "Read files across your system."
        case .homeKit: return "Control HomeKit accessories and scenes."
        case .mediaLibrary: return "Access Apple Music and media library."
        case .passkeys: return "Access passkeys for web browser authentication."
        case .photoLibrary: return "Access your photo library."
        case .reminders: return "Access and manage your reminders."
        case .notes: return "Access and manage your notes."
        case .accessibility: return "Read screen content and control UI."
        case .appManagement: return "Update and delete other apps."
        case .automation: return "Control other apps via AppleScript."
        case .bluetooth: return "Connect to Bluetooth devices."
        case .camera: return "Access the camera for photos and video."
        case .developerTools: return "Run software that requires developer tools access."
        case .focusStatus: return "Access your Focus status."
        case .inputMonitoring: return "Monitor keyboard and mouse input."
        case .localNetwork: return "Discover devices on the local network."
        case .microphone: return "Access the microphone for voice input."
        case .motionFitness: return "Access motion and fitness activity data."
        case .remoteDesktop: return "Allow remote control of this Mac."
        case .screenRecording: return "Capture screen content and system audio."
        case .speechRecognition: return "On-device speech-to-text recognition."
        case .locationWhenInUse: return "Location access while using the app."
        case .locationAlways: return "Background location access."
        case .notifications: return "Send notifications and alerts."
        case .criticalAlerts: return "Bypass Do Not Disturb with critical alerts."
        case .healthRead: return "Read health and fitness data."
        case .healthWrite: return "Write health and fitness data."
        case .photoLibraryAddOnly: return "Save photos without viewing library."
        case .siri: return "Siri and Shortcuts integration."
        case .faceID: return "Biometric authentication."
        }
    }

    /// Icon for each permission type matching macOS system style
    public var icon: String {
        switch self {
        case .calendars: return "calendar"
        case .contacts: return "person.crop.circle"
        case .fullDiskAccess: return "internaldrive"
        case .homeKit: return "house"
        case .mediaLibrary: return "music.note"
        case .passkeys: return "key.fill"
        case .photoLibrary, .photoLibraryAddOnly: return "photo.on.rectangle"
        case .reminders: return "checklist"
        case .notes: return "note.text"
        case .accessibility: return "accessibility"
        case .appManagement: return "app.badge.checkmark"
        case .automation: return "gearshape.2"
        case .bluetooth: return "wave.3.right"
        case .camera: return "camera"
        case .developerTools: return "hammer"
        case .focusStatus: return "moon.fill"
        case .inputMonitoring: return "keyboard"
        case .localNetwork: return "network"
        case .microphone: return "mic"
        case .motionFitness: return "figure.walk"
        case .remoteDesktop: return "desktopcomputer"
        case .screenRecording: return "rectangle.dashed.badge.record"
        case .speechRecognition: return "waveform"
        case .locationWhenInUse, .locationAlways: return "location"
        case .notifications, .criticalAlerts: return "bell"
        case .healthRead, .healthWrite: return "heart"
        case .siri: return "mic.circle"
        case .faceID: return "faceid"
        }
    }

    /// Whether this permission can be programmatically requested via an API
    /// (as opposed to only being grantable through System Settings)
    public var canRequestProgrammatically: Bool {
        switch self {
        case .camera, .microphone, .photoLibrary, .photoLibraryAddOnly,
             .contacts, .calendars, .reminders, .notifications, .criticalAlerts,
             .speechRecognition, .locationWhenInUse, .locationAlways,
             .healthRead, .healthWrite, .siri, .faceID:
            return true
        case .accessibility, .screenRecording:
            // These have special request APIs on macOS
            return true
        case .fullDiskAccess, .inputMonitoring, .automation, .bluetooth,
             .localNetwork, .homeKit, .appManagement, .developerTools,
             .focusStatus, .motionFitness, .remoteDesktop, .passkeys,
             .mediaLibrary, .notes:
            return false
        }
    }
}

// MARK: - Permission Info

public struct PermissionInfo: Identifiable, Sendable {
    public let id: String
    public let type: PermissionType
    public var status: PermissionStatus
    public let category: PermissionCategory
    public let description: String

    public var canRequest: Bool {
        status == .notDetermined && type.canRequestProgrammatically
    }

    public var canOpenSettings: Bool {
        status == .denied || status == .restricted || status == .unknown
    }

    public init(type: PermissionType, status: PermissionStatus) {
        self.id = type.rawValue
        self.type = type
        self.status = status
        self.category = type.category
        self.description = type.description
    }
}
