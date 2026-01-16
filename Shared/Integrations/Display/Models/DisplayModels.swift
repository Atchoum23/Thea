import Foundation

#if os(macOS)
import AppKit
import CoreGraphics

// MARK: - Display

/// Represents a physical display
public struct Display: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public var displayID: CGDirectDisplayID
    public var name: String
    public var manufacturer: String?
    public var model: String?
    public var serialNumber: String?
    public var isBuiltIn: Bool
    public var supportsHardwareControl: Bool // DDC/CI support
    public var currentProfile: DisplayProfile?

    public init(
        id: UUID = UUID(),
        displayID: CGDirectDisplayID,
        name: String,
        manufacturer: String? = nil,
        model: String? = nil,
        serialNumber: String? = nil,
        isBuiltIn: Bool = false,
        supportsHardwareControl: Bool = false,
        currentProfile: DisplayProfile? = nil
    ) {
        self.id = id
        self.displayID = displayID
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.serialNumber = serialNumber
        self.isBuiltIn = isBuiltIn
        self.supportsHardwareControl = supportsHardwareControl
        self.currentProfile = currentProfile
    }
}

// MARK: - Display Profile

/// Display settings profile
public struct DisplayProfile: Sendable, Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var brightness: Int // 0-100
    public var contrast: Int // 0-100
    public var colorTemperature: ColorTemperature
    public var hdrEnabled: Bool
    public var nightShiftStrength: Int // 0-100

    public init(
        id: UUID = UUID(),
        name: String,
        brightness: Int = 50,
        contrast: Int = 50,
        colorTemperature: ColorTemperature = .standard,
        hdrEnabled: Bool = false,
        nightShiftStrength: Int = 0
    ) {
        self.id = id
        self.name = name
        self.brightness = brightness
        self.contrast = contrast
        self.colorTemperature = colorTemperature
        self.hdrEnabled = hdrEnabled
        self.nightShiftStrength = nightShiftStrength
    }

    // MARK: - Preset Profiles

    /// Daytime profile (bright, cool)
    public static let daytime = DisplayProfile(
        name: "Daytime",
        brightness: 80,
        contrast: 75,
        colorTemperature: .cool,
        hdrEnabled: true,
        nightShiftStrength: 0
    )

    /// Evening profile (medium, warm)
    public static let evening = DisplayProfile(
        name: "Evening",
        brightness: 50,
        contrast: 60,
        colorTemperature: .warm,
        hdrEnabled: false,
        nightShiftStrength: 50
    )

    /// Night profile (dim, very warm)
    public static let night = DisplayProfile(
        name: "Night",
        brightness: 20,
        contrast: 50,
        colorTemperature: .veryWarm,
        hdrEnabled: false,
        nightShiftStrength: 100
    )

    /// Reading profile (high contrast, warm)
    public static let reading = DisplayProfile(
        name: "Reading",
        brightness: 60,
        contrast: 85,
        colorTemperature: .warm,
        hdrEnabled: false,
        nightShiftStrength: 30
    )

    /// Movie profile (HDR, standard temp)
    public static let movie = DisplayProfile(
        name: "Movie",
        brightness: 70,
        contrast: 80,
        colorTemperature: .standard,
        hdrEnabled: true,
        nightShiftStrength: 0
    )
}

// MARK: - Color Temperature

public enum ColorTemperature: String, Sendable, Codable, CaseIterable {
    case cool = "Cool (6500K)"
    case standard = "Standard (5500K)"
    case warm = "Warm (4500K)"
    case veryWarm = "Very Warm (3500K)"

    public var kelvin: Int {
        switch self {
        case .cool: return 6500
        case .standard: return 5500
        case .warm: return 4500
        case .veryWarm: return 3500
        }
    }
}

// MARK: - Display Adjustment

/// Represents a display adjustment event
public struct DisplayAdjustment: Sendable, Codable, Identifiable {
    public let id: UUID
    public var timestamp: Date
    public var displayID: CGDirectDisplayID
    public var profileApplied: DisplayProfile
    public var trigger: AdjustmentTrigger

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        displayID: CGDirectDisplayID,
        profileApplied: DisplayProfile,
        trigger: AdjustmentTrigger
    ) {
        self.id = id
        self.timestamp = timestamp
        self.displayID = displayID
        self.profileApplied = profileApplied
        self.trigger = trigger
    }
}

public enum AdjustmentTrigger: String, Sendable, Codable {
    case manual = "Manual"
    case circadian = "Circadian Rhythm"
    case ambientLight = "Ambient Light"
    case schedule = "Scheduled"
    case appContext = "App Context"
}

// MARK: - Display Schedule

/// Scheduled profile changes
public struct DisplaySchedule: Sendable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var isEnabled: Bool
    public var rules: [ScheduleRule]

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        rules: [ScheduleRule]
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.rules = rules
    }

    /// Default circadian schedule
    public static let circadian = DisplaySchedule(
        name: "Circadian",
        rules: [
            ScheduleRule(time: "06:00", profile: .daytime),
            ScheduleRule(time: "18:00", profile: .evening),
            ScheduleRule(time: "22:00", profile: .night)
        ]
    )
}

public struct ScheduleRule: Sendable, Codable, Identifiable {
    public let id: UUID
    public var time: String // HH:MM format
    public var profile: DisplayProfile

    public init(
        id: UUID = UUID(),
        time: String,
        profile: DisplayProfile
    ) {
        self.id = id
        self.time = time
        self.profile = profile
    }
}

// MARK: - Errors

public enum DisplayError: Error, LocalizedError, Sendable {
    case noDisplaysFound
    case hardwareControlNotSupported
    case ddcCommandFailed(String)
    case invalidBrightnessValue
    case displayNotFound(CGDirectDisplayID)

    public var errorDescription: String? {
        switch self {
        case .noDisplaysFound:
            return "No displays found"
        case .hardwareControlNotSupported:
            return "Hardware control (DDC/CI) not supported on this display"
        case .ddcCommandFailed(let reason):
            return "DDC command failed: \(reason)"
        case .invalidBrightnessValue:
            return "Brightness value must be between 0 and 100"
        case .displayNotFound(let id):
            return "Display with ID \(id) not found"
        }
    }
}

#endif
