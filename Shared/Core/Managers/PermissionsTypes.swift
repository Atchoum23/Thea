//
//  PermissionsTypes.swift
//  Thea
//
//  Permission types and enums for the PermissionsManager
//  Extracted from PermissionsManager.swift for better code organization
//

import Foundation

// MARK: - Permission Status

public enum PermissionStatus: String, Codable, Sendable, CaseIterable {
    case notDetermined = "Not Determined"
    case authorized = "Authorized"
    case denied = "Denied"
    case restricted = "Restricted"
    case limited = "Limited"
    case provisional = "Provisional"
    case notAvailable = "Not Available"

    public var icon: String {
        switch self {
        case .notDetermined: return "questionmark.circle"
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .restricted: return "lock.circle.fill"
        case .limited: return "circle.lefthalf.filled"
        case .provisional: return "clock.circle"
        case .notAvailable: return "minus.circle"
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
        }
    }

    public var canRequest: Bool {
        self == .notDetermined
    }
}

// MARK: - Permission Category

public enum PermissionCategory: String, CaseIterable, Identifiable, Sendable {
    case privacy = "Privacy"
    case hardware = "Hardware"
    case location = "Location"
    case health = "Health & Fitness"
    case communication = "Communication"
    case media = "Media"
    case homeAutomation = "Home & Automation"
    case system = "System"
    case network = "Network"
    case security = "Security"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .privacy: return "hand.raised.fill"
        case .hardware: return "cpu"
        case .location: return "location.fill"
        case .health: return "heart.fill"
        case .communication: return "message.fill"
        case .media: return "photo.fill"
        case .homeAutomation: return "house.fill"
        case .system: return "gearshape.fill"
        case .network: return "network"
        case .security: return "lock.shield.fill"
        }
    }
}

// MARK: - Permission Type

public enum PermissionType: String, CaseIterable, Identifiable, Sendable {
    // Privacy
    case camera = "Camera"
    case microphone = "Microphone"
    case photoLibrary = "Photo Library"
    case photoLibraryAddOnly = "Photo Library (Add Only)"
    case contacts = "Contacts"
    case calendars = "Calendars"
    case reminders = "Reminders"

    // Location
    case locationWhenInUse = "Location (When In Use)"
    case locationAlways = "Location (Always)"

    // Health & Fitness
    case healthRead = "Health Data (Read)"
    case healthWrite = "Health Data (Write)"
    case motionFitness = "Motion & Fitness"

    // Communication
    case notifications = "Notifications"
    case criticalAlerts = "Critical Alerts"

    // Media
    case mediaLibrary = "Apple Music & Media"
    case speechRecognition = "Speech Recognition"

    // Home & Automation
    case homeKit = "HomeKit"
    case siri = "Siri & Shortcuts"

    // Hardware
    case bluetooth = "Bluetooth"
    case localNetwork = "Local Network"
    case faceID = "Face ID / Touch ID"

    // System (macOS specific)
    case accessibility = "Accessibility"
    case fullDiskAccess = "Full Disk Access"
    case screenRecording = "Screen Recording"
    case inputMonitoring = "Input Monitoring"
    case automation = "Automation"

    // Focus
    case focusStatus = "Focus Status"

    public var id: String { rawValue }

    public var category: PermissionCategory {
        switch self {
        case .camera, .microphone, .photoLibrary, .photoLibraryAddOnly, .contacts, .calendars, .reminders:
            return .privacy
        case .locationWhenInUse, .locationAlways:
            return .location
        case .healthRead, .healthWrite, .motionFitness:
            return .health
        case .notifications, .criticalAlerts:
            return .communication
        case .mediaLibrary, .speechRecognition:
            return .media
        case .homeKit, .siri:
            return .homeAutomation
        case .bluetooth, .localNetwork, .faceID:
            return .hardware
        case .accessibility, .fullDiskAccess, .screenRecording, .inputMonitoring, .automation:
            return .system
        case .focusStatus:
            return .privacy
        }
    }

    public var description: String {
        switch self {
        case .camera: return "Access camera for photos and video"
        case .microphone: return "Access microphone for voice input"
        case .photoLibrary: return "Full access to photo library"
        case .photoLibraryAddOnly: return "Save photos without viewing library"
        case .contacts: return "Access your contacts"
        case .calendars: return "Access calendar events"
        case .reminders: return "Access reminders"
        case .locationWhenInUse: return "Location while using the app"
        case .locationAlways: return "Background location access"
        case .healthRead: return "Read health and fitness data"
        case .healthWrite: return "Write health and fitness data"
        case .motionFitness: return "Motion and fitness activity"
        case .notifications: return "Send notifications"
        case .criticalAlerts: return "Bypass Do Not Disturb"
        case .mediaLibrary: return "Access Apple Music"
        case .speechRecognition: return "On-device speech recognition"
        case .homeKit: return "Control HomeKit accessories"
        case .siri: return "Siri and Shortcuts integration"
        case .bluetooth: return "Connect to Bluetooth devices"
        case .localNetwork: return "Discover local network devices"
        case .faceID: return "Biometric authentication"
        case .accessibility: return "Control other apps"
        case .fullDiskAccess: return "Access all files"
        case .screenRecording: return "Record screen content"
        case .inputMonitoring: return "Monitor keyboard/mouse"
        case .automation: return "Run automations"
        case .focusStatus: return "Share Focus status"
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

    public var canRequest: Bool { status == .notDetermined }
    public var canOpenSettings: Bool { status == .denied || status == .restricted }

    public init(type: PermissionType, status: PermissionStatus) {
        self.id = type.rawValue
        self.type = type
        self.status = status
        self.category = type.category
        self.description = type.description
    }
}
