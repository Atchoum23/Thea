import CoreLocation
import Foundation
#if canImport(HealthKit)
    import HealthKit
#endif

// MARK: - Context Snapshot

/// A point-in-time snapshot of all available context about the user and device
public struct ContextSnapshot: Codable, Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date

    // Location Context
    public var location: LocationContext?

    // App Activity Context
    public var appActivity: AppActivityContext?

    // Health Context
    public var health: HealthContext?

    // Calendar Context
    public var calendar: CalendarContext?

    // Communication Context
    public var communication: CommunicationContext?

    // Clipboard Context
    public var clipboard: ClipboardContext?

    // Focus Context
    public var focus: FocusContext?

    // Device State Context
    public var deviceState: DeviceStateContext?

    // Media Context
    public var media: MediaContext?

    // Environment Context
    public var environment: EnvironmentContext?

    // Arbitrary metadata for extension
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        location: LocationContext? = nil,
        appActivity: AppActivityContext? = nil,
        health: HealthContext? = nil,
        calendar: CalendarContext? = nil,
        communication: CommunicationContext? = nil,
        clipboard: ClipboardContext? = nil,
        focus: FocusContext? = nil,
        deviceState: DeviceStateContext? = nil,
        media: MediaContext? = nil,
        environment: EnvironmentContext? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.location = location
        self.appActivity = appActivity
        self.health = health
        self.calendar = calendar
        self.communication = communication
        self.clipboard = clipboard
        self.focus = focus
        self.deviceState = deviceState
        self.media = media
        self.environment = environment
        self.metadata = metadata
    }

    /// Creates a summary suitable for AI context injection
    public func summary(maxLength: Int = 500) -> String {
        var parts: [String] = []

        if let location {
            parts.append("Location: \(location.placeName ?? "Unknown")")
        }

        if let appActivity {
            parts.append("Active app: \(appActivity.activeAppName ?? "Unknown")")
        }

        if let calendar, let next = calendar.upcomingEvents.first {
            parts.append("Next event: \(next.title) at \(next.startDate.formatted(date: .omitted, time: .shortened))")
        }

        if let focus, focus.isActive {
            parts.append("Focus mode: \(focus.modeName)")
        }

        if let deviceState {
            parts.append("Battery: \(Int(deviceState.batteryLevel * 100))%")
        }

        if let health {
            if let steps = health.stepCount {
                parts.append("Steps today: \(Int(steps))")
            }
        }

        let result = parts.joined(separator: " | ")
        if result.count > maxLength {
            return String(result.prefix(maxLength - 3)) + "..."
        }
        return result
    }
}

// MARK: - Location Context

public struct LocationContext: Codable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    public let horizontalAccuracy: Double
    public let placeName: String?
    public let locality: String?
    public let administrativeArea: String?
    public let country: String?
    public let isHome: Bool?
    public let isWork: Bool?
    public let speed: Double?
    public let course: Double?

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        horizontalAccuracy: Double = 0,
        placeName: String? = nil,
        locality: String? = nil,
        administrativeArea: String? = nil,
        country: String? = nil,
        isHome: Bool? = nil,
        isWork: Bool? = nil,
        speed: Double? = nil,
        course: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.placeName = placeName
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
        self.isHome = isHome
        self.isWork = isWork
        self.speed = speed
        self.course = course
    }
}

// MARK: - App Activity Context

public struct AppActivityContext: Codable, Sendable {
    public let activeAppBundleID: String?
    public let activeAppName: String?
    public let activeWindowTitle: String?
    public let activeDocumentPath: String?
    public let recentApps: [RecentApp]
    public let screenTimeToday: TimeInterval?

    public struct RecentApp: Codable, Sendable {
        public let bundleID: String
        public let name: String
        public let lastUsed: Date
        public let usageToday: TimeInterval?

        public init(bundleID: String, name: String, lastUsed: Date, usageToday: TimeInterval? = nil) {
            self.bundleID = bundleID
            self.name = name
            self.lastUsed = lastUsed
            self.usageToday = usageToday
        }
    }

    public init(
        activeAppBundleID: String? = nil,
        activeAppName: String? = nil,
        activeWindowTitle: String? = nil,
        activeDocumentPath: String? = nil,
        recentApps: [RecentApp] = [],
        screenTimeToday: TimeInterval? = nil
    ) {
        self.activeAppBundleID = activeAppBundleID
        self.activeAppName = activeAppName
        self.activeWindowTitle = activeWindowTitle
        self.activeDocumentPath = activeDocumentPath
        self.recentApps = recentApps
        self.screenTimeToday = screenTimeToday
    }
}

// MARK: - Health Context

public struct HealthContext: Codable, Sendable {
    public let stepCount: Double?
    public let heartRate: Double?
    public let heartRateVariability: Double?
    public let activeEnergyBurned: Double?
    public let restingHeartRate: Double?
    public let sleepHoursLastNight: Double?
    public let sleepQuality: SleepQuality?
    public let activityLevel: ActivityLevel?
    public let stressLevel: StressLevel?
    public let bloodOxygen: Double?
    public let respiratoryRate: Double?

    public enum SleepQuality: String, Codable, Sendable {
        case poor, fair, good, excellent
    }

    public enum ActivityLevel: String, Codable, Sendable {
        case sedentary, light, moderate, vigorous
    }

    public enum StressLevel: String, Codable, Sendable {
        case low, moderate, high, veryHigh
    }

    public init(
        stepCount: Double? = nil,
        heartRate: Double? = nil,
        heartRateVariability: Double? = nil,
        activeEnergyBurned: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHoursLastNight: Double? = nil,
        sleepQuality: SleepQuality? = nil,
        activityLevel: ActivityLevel? = nil,
        stressLevel: StressLevel? = nil,
        bloodOxygen: Double? = nil,
        respiratoryRate: Double? = nil
    ) {
        self.stepCount = stepCount
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.activeEnergyBurned = activeEnergyBurned
        self.restingHeartRate = restingHeartRate
        self.sleepHoursLastNight = sleepHoursLastNight
        self.sleepQuality = sleepQuality
        self.activityLevel = activityLevel
        self.stressLevel = stressLevel
        self.bloodOxygen = bloodOxygen
        self.respiratoryRate = respiratoryRate
    }
}

// MARK: - Calendar Context

public struct CalendarContext: Codable, Sendable {
    public let currentEvent: CalendarEvent?
    public let upcomingEvents: [CalendarEvent]
    public let freeTimeUntilNextEvent: TimeInterval?
    public let busyLevel: BusyLevel

    public enum BusyLevel: String, Codable, Sendable {
        case free, light, moderate, busy, veryBusy
    }

    public struct CalendarEvent: Codable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let startDate: Date
        public let endDate: Date
        public let location: String?
        public let isAllDay: Bool
        public let attendeeCount: Int
        public let hasVideoCall: Bool
        public let calendarName: String?

        public init(
            id: String,
            title: String,
            startDate: Date,
            endDate: Date,
            location: String? = nil,
            isAllDay: Bool = false,
            attendeeCount: Int = 0,
            hasVideoCall: Bool = false,
            calendarName: String? = nil
        ) {
            self.id = id
            self.title = title
            self.startDate = startDate
            self.endDate = endDate
            self.location = location
            self.isAllDay = isAllDay
            self.attendeeCount = attendeeCount
            self.hasVideoCall = hasVideoCall
            self.calendarName = calendarName
        }
    }

    public init(
        currentEvent: CalendarEvent? = nil,
        upcomingEvents: [CalendarEvent] = [],
        freeTimeUntilNextEvent: TimeInterval? = nil,
        busyLevel: BusyLevel = .free
    ) {
        self.currentEvent = currentEvent
        self.upcomingEvents = upcomingEvents
        self.freeTimeUntilNextEvent = freeTimeUntilNextEvent
        self.busyLevel = busyLevel
    }
}

// MARK: - Communication Context

public struct CommunicationContext: Codable, Sendable {
    public let unreadEmailCount: Int
    public let unreadMessageCount: Int
    public let recentContacts: [RecentContact]
    public let missedCallCount: Int
    public let pendingReplies: Int

    public struct RecentContact: Codable, Sendable {
        public let name: String
        public let lastContactDate: Date
        public let communicationType: CommunicationType

        public enum CommunicationType: String, Codable, Sendable {
            case email, message, call, videoCall
        }

        public init(name: String, lastContactDate: Date, communicationType: CommunicationType) {
            self.name = name
            self.lastContactDate = lastContactDate
            self.communicationType = communicationType
        }
    }

    public init(
        unreadEmailCount: Int = 0,
        unreadMessageCount: Int = 0,
        recentContacts: [RecentContact] = [],
        missedCallCount: Int = 0,
        pendingReplies: Int = 0
    ) {
        self.unreadEmailCount = unreadEmailCount
        self.unreadMessageCount = unreadMessageCount
        self.recentContacts = recentContacts
        self.missedCallCount = missedCallCount
        self.pendingReplies = pendingReplies
    }
}

// MARK: - Clipboard Context

public struct ClipboardContext: Codable, Sendable {
    public let hasContent: Bool
    public let contentType: ClipboardContentType?
    public let textPreview: String?
    public let contentSize: Int?
    public let lastCopiedDate: Date?

    public enum ClipboardContentType: String, Codable, Sendable {
        case text, url, image, file, richText, html
    }

    public init(
        hasContent: Bool = false,
        contentType: ClipboardContentType? = nil,
        textPreview: String? = nil,
        contentSize: Int? = nil,
        lastCopiedDate: Date? = nil
    ) {
        self.hasContent = hasContent
        self.contentType = contentType
        self.textPreview = textPreview
        self.contentSize = contentSize
        self.lastCopiedDate = lastCopiedDate
    }
}

// MARK: - Focus Context

public struct FocusContext: Codable, Sendable {
    public let isActive: Bool
    public let modeName: String
    public let modeIdentifier: String?
    public let startTime: Date?
    public let endTime: Date?
    public let allowedApps: [String]?
    public let silencedApps: [String]?

    public init(
        isActive: Bool = false,
        modeName: String = "None",
        modeIdentifier: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        allowedApps: [String]? = nil,
        silencedApps: [String]? = nil
    ) {
        self.isActive = isActive
        self.modeName = modeName
        self.modeIdentifier = modeIdentifier
        self.startTime = startTime
        self.endTime = endTime
        self.allowedApps = allowedApps
        self.silencedApps = silencedApps
    }
}

// MARK: - Device State Context

public struct DeviceStateContext: Codable, Sendable {
    public let batteryLevel: Float
    public let batteryState: BatteryState
    public let isLowPowerMode: Bool
    public let thermalState: ThermalState
    public let networkType: NetworkType
    public let isWiFiConnected: Bool
    public let isCellularConnected: Bool
    public let wifiSSID: String?
    public let storageAvailableGB: Double?
    public let memoryPressure: MemoryPressure
    public let screenBrightness: Float?
    public let volumeLevel: Float?
    public let isHeadphonesConnected: Bool
    public let orientation: DeviceOrientation

    public enum BatteryState: String, Codable, Sendable {
        case unknown, unplugged, charging, full
    }

    public enum ThermalState: String, Codable, Sendable {
        case nominal, fair, serious, critical
    }

    public enum NetworkType: String, Codable, Sendable {
        case none, wifi, cellular, ethernet, unknown
    }

    public enum MemoryPressure: String, Codable, Sendable {
        case normal, warning, critical
    }

    public enum DeviceOrientation: String, Codable, Sendable {
        case portrait, portraitUpsideDown, landscapeLeft, landscapeRight, faceUp, faceDown, unknown
    }

    public init(
        batteryLevel: Float = 1.0,
        batteryState: BatteryState = .unknown,
        isLowPowerMode: Bool = false,
        thermalState: ThermalState = .nominal,
        networkType: NetworkType = .unknown,
        isWiFiConnected: Bool = false,
        isCellularConnected: Bool = false,
        wifiSSID: String? = nil,
        storageAvailableGB: Double? = nil,
        memoryPressure: MemoryPressure = .normal,
        screenBrightness: Float? = nil,
        volumeLevel: Float? = nil,
        isHeadphonesConnected: Bool = false,
        orientation: DeviceOrientation = .unknown
    ) {
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.isLowPowerMode = isLowPowerMode
        self.thermalState = thermalState
        self.networkType = networkType
        self.isWiFiConnected = isWiFiConnected
        self.isCellularConnected = isCellularConnected
        self.wifiSSID = wifiSSID
        self.storageAvailableGB = storageAvailableGB
        self.memoryPressure = memoryPressure
        self.screenBrightness = screenBrightness
        self.volumeLevel = volumeLevel
        self.isHeadphonesConnected = isHeadphonesConnected
        self.orientation = orientation
    }
}

// MARK: - Media Context

public struct MediaContext: Codable, Sendable {
    public let isPlaying: Bool
    public let nowPlayingTitle: String?
    public let nowPlayingArtist: String?
    public let nowPlayingAlbum: String?
    public let nowPlayingApp: String?
    public let playbackPosition: TimeInterval?
    public let duration: TimeInterval?

    public init(
        isPlaying: Bool = false,
        nowPlayingTitle: String? = nil,
        nowPlayingArtist: String? = nil,
        nowPlayingAlbum: String? = nil,
        nowPlayingApp: String? = nil,
        playbackPosition: TimeInterval? = nil,
        duration: TimeInterval? = nil
    ) {
        self.isPlaying = isPlaying
        self.nowPlayingTitle = nowPlayingTitle
        self.nowPlayingArtist = nowPlayingArtist
        self.nowPlayingAlbum = nowPlayingAlbum
        self.nowPlayingApp = nowPlayingApp
        self.playbackPosition = playbackPosition
        self.duration = duration
    }
}

// MARK: - Environment Context

public struct EnvironmentContext: Codable, Sendable {
    public let timeOfDay: TimeOfDay
    public let isWeekend: Bool
    public let isDaylight: Bool
    public let ambientLightLevel: Float?
    public let noiseLevel: Float?
    public let nearbyBluetoothDevices: [String]
    public let connectedAccessories: [String]
    public let homeKitScene: String?
    public let weatherCondition: String?
    public let temperature: Double?

    public enum TimeOfDay: String, Codable, Sendable {
        case earlyMorning // 5-8
        case morning // 8-12
        case afternoon // 12-17
        case evening // 17-21
        case night // 21-5
    }

    public init(
        timeOfDay: TimeOfDay = .morning,
        isWeekend: Bool = false,
        isDaylight: Bool = true,
        ambientLightLevel: Float? = nil,
        noiseLevel: Float? = nil,
        nearbyBluetoothDevices: [String] = [],
        connectedAccessories: [String] = [],
        homeKitScene: String? = nil,
        weatherCondition: String? = nil,
        temperature: Double? = nil
    ) {
        self.timeOfDay = timeOfDay
        self.isWeekend = isWeekend
        self.isDaylight = isDaylight
        self.ambientLightLevel = ambientLightLevel
        self.noiseLevel = noiseLevel
        self.nearbyBluetoothDevices = nearbyBluetoothDevices
        self.connectedAccessories = connectedAccessories
        self.homeKitScene = homeKitScene
        self.weatherCondition = weatherCondition
        self.temperature = temperature
    }
}

// MARK: - Context Update

/// Represents an incremental update to context from a single provider
public struct ContextUpdate: Sendable {
    public let providerId: String
    public let timestamp: Date
    public let updateType: UpdateType
    public let priority: Priority

    public enum UpdateType: Sendable {
        case location(LocationContext)
        case appActivity(AppActivityContext)
        case health(HealthContext)
        case calendar(CalendarContext)
        case communication(CommunicationContext)
        case clipboard(ClipboardContext)
        case focus(FocusContext)
        case deviceState(DeviceStateContext)
        case media(MediaContext)
        case environment(EnvironmentContext)
    }

    public enum Priority: Int, Sendable, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public init(providerId: String, timestamp: Date = Date(), updateType: UpdateType, priority: Priority = .normal) {
        self.providerId = providerId
        self.timestamp = timestamp
        self.updateType = updateType
        self.priority = priority
    }
}
