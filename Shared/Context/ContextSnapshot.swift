import CoreLocation
import Foundation
#if canImport(HealthKit)
    import HealthKit
#endif

// MARK: - Context Snapshot

/// A point-in-time snapshot of all available context about the user and device,
/// collected from location, health, calendar, communication, and other providers.
public struct ContextSnapshot: Codable, Sendable, Identifiable {
    /// Unique snapshot identifier.
    public let id: UUID
    /// When this snapshot was captured.
    public let timestamp: Date

    /// Current geographic location and place information.
    public var location: LocationContext?

    /// Currently active app and recent app usage.
    public var appActivity: AppActivityContext?

    /// Health metrics from HealthKit (steps, heart rate, sleep, etc.).
    public var health: HealthContext?

    /// Calendar events and schedule busyness.
    public var calendar: CalendarContext?

    /// Communication status (unread emails, messages, missed calls).
    public var communication: CommunicationContext?

    /// Clipboard content type and preview.
    public var clipboard: ClipboardContext?

    /// Focus mode / Do Not Disturb state.
    public var focus: FocusContext?

    /// Device hardware state (battery, network, thermal, etc.).
    public var deviceState: DeviceStateContext?

    /// Currently playing media information.
    public var media: MediaContext?

    /// Ambient environment (time of day, noise, weather, etc.).
    public var environment: EnvironmentContext?

    /// Arbitrary extension metadata as key-value pairs.
    public var metadata: [String: String]

    /// Creates a context snapshot with optional context from each provider.
    /// - Parameters:
    ///   - id: Snapshot identifier.
    ///   - timestamp: Capture time.
    ///   - location: Location context.
    ///   - appActivity: App activity context.
    ///   - health: Health metrics context.
    ///   - calendar: Calendar context.
    ///   - communication: Communication context.
    ///   - clipboard: Clipboard context.
    ///   - focus: Focus mode context.
    ///   - deviceState: Device state context.
    ///   - media: Media playback context.
    ///   - environment: Environment context.
    ///   - metadata: Additional metadata.
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

    /// Creates a concise text summary suitable for AI context injection.
    /// - Parameter maxLength: Maximum character length of the summary.
    /// - Returns: A pipe-separated summary of available context.
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

/// Geographic location and reverse-geocoded place information.
public struct LocationContext: Codable, Sendable {
    /// Latitude in degrees.
    public let latitude: Double
    /// Longitude in degrees.
    public let longitude: Double
    /// Altitude in meters above sea level.
    public let altitude: Double?
    /// Horizontal accuracy radius in meters.
    public let horizontalAccuracy: Double
    /// Human-readable place name (e.g. "Central Park").
    public let placeName: String?
    /// City or locality name.
    public let locality: String?
    /// State, province, or administrative area.
    public let administrativeArea: String?
    /// Country name.
    public let country: String?
    /// Whether the user is at their home location.
    public let isHome: Bool?
    /// Whether the user is at their work location.
    public let isWork: Bool?
    /// Current speed in meters per second.
    public let speed: Double?
    /// Current heading/course in degrees from true north.
    public let course: Double?

    /// Creates a location context.
    /// - Parameters:
    ///   - latitude: Latitude in degrees.
    ///   - longitude: Longitude in degrees.
    ///   - altitude: Altitude in meters.
    ///   - horizontalAccuracy: Accuracy radius in meters.
    ///   - placeName: Human-readable place name.
    ///   - locality: City or locality.
    ///   - administrativeArea: State or province.
    ///   - country: Country name.
    ///   - isHome: Whether at home.
    ///   - isWork: Whether at work.
    ///   - speed: Speed in m/s.
    ///   - course: Heading in degrees.
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

/// Information about the currently active app and recent app usage.
public struct AppActivityContext: Codable, Sendable {
    /// Bundle identifier of the active foreground app.
    public let activeAppBundleID: String?
    /// Display name of the active foreground app.
    public let activeAppName: String?
    /// Title of the active window or document.
    public let activeWindowTitle: String?
    /// File path of the active document, if applicable.
    public let activeDocumentPath: String?
    /// Recently used apps ordered by last-used time.
    public let recentApps: [RecentApp]
    /// Total screen time today in seconds.
    public let screenTimeToday: TimeInterval?

    /// A recently used app entry.
    public struct RecentApp: Codable, Sendable {
        /// Bundle identifier of the app.
        public let bundleID: String
        /// Display name of the app.
        public let name: String
        /// When the app was last used.
        public let lastUsed: Date
        /// Total usage time today in seconds.
        public let usageToday: TimeInterval?

        /// Creates a recent app entry.
        /// - Parameters:
        ///   - bundleID: App bundle identifier.
        ///   - name: App display name.
        ///   - lastUsed: Last usage timestamp.
        ///   - usageToday: Usage time today.
        public init(bundleID: String, name: String, lastUsed: Date, usageToday: TimeInterval? = nil) {
            self.bundleID = bundleID
            self.name = name
            self.lastUsed = lastUsed
            self.usageToday = usageToday
        }
    }

    /// Creates an app activity context.
    /// - Parameters:
    ///   - activeAppBundleID: Active app bundle ID.
    ///   - activeAppName: Active app name.
    ///   - activeWindowTitle: Active window title.
    ///   - activeDocumentPath: Active document path.
    ///   - recentApps: Recently used apps.
    ///   - screenTimeToday: Screen time today.
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

/// Health metrics collected from HealthKit and activity sensors.
public struct HealthContext: Codable, Sendable {
    /// Total step count for today.
    public let stepCount: Double?
    /// Current heart rate in BPM.
    public let heartRate: Double?
    /// Heart rate variability (SDNN) in milliseconds.
    public let heartRateVariability: Double?
    /// Active energy burned today in kilocalories.
    public let activeEnergyBurned: Double?
    /// Resting heart rate in BPM.
    public let restingHeartRate: Double?
    /// Hours of sleep last night.
    public let sleepHoursLastNight: Double?
    /// Qualitative sleep quality assessment.
    public let sleepQuality: SleepQuality?
    /// Current physical activity level.
    public let activityLevel: ActivityLevel?
    /// Estimated stress level based on HRV and activity.
    public let stressLevel: StressLevel?
    /// Blood oxygen saturation percentage (SpO2).
    public let bloodOxygen: Double?
    /// Respiratory rate in breaths per minute.
    public let respiratoryRate: Double?

    /// Qualitative sleep quality rating.
    public enum SleepQuality: String, Codable, Sendable {
        /// Poor sleep quality.
        case poor
        /// Fair sleep quality.
        case fair
        /// Good sleep quality.
        case good
        /// Excellent sleep quality.
        case excellent
    }

    /// Physical activity intensity level.
    public enum ActivityLevel: String, Codable, Sendable {
        /// Mostly sitting or resting.
        case sedentary
        /// Light movement (walking, standing).
        case light
        /// Moderate activity (brisk walking, cycling).
        case moderate
        /// Vigorous activity (running, intense exercise).
        case vigorous
    }

    /// Estimated stress level.
    public enum StressLevel: String, Codable, Sendable {
        /// Low stress.
        case low
        /// Moderate stress.
        case moderate
        /// High stress.
        case high
        /// Very high stress.
        case veryHigh
    }

    /// Creates a health context.
    /// - Parameters:
    ///   - stepCount: Steps today.
    ///   - heartRate: Current heart rate.
    ///   - heartRateVariability: HRV in ms.
    ///   - activeEnergyBurned: Active calories today.
    ///   - restingHeartRate: Resting HR.
    ///   - sleepHoursLastNight: Sleep hours.
    ///   - sleepQuality: Sleep quality rating.
    ///   - activityLevel: Activity level.
    ///   - stressLevel: Stress level.
    ///   - bloodOxygen: SpO2 percentage.
    ///   - respiratoryRate: Breaths per minute.
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

/// Calendar schedule information including current and upcoming events.
public struct CalendarContext: Codable, Sendable {
    /// Currently active calendar event, if any.
    public let currentEvent: CalendarEvent?
    /// Upcoming events sorted by start time.
    public let upcomingEvents: [CalendarEvent]
    /// Free time until the next event in seconds.
    public let freeTimeUntilNextEvent: TimeInterval?
    /// Overall schedule busyness level.
    public let busyLevel: BusyLevel

    /// Schedule busyness classification.
    public enum BusyLevel: String, Codable, Sendable {
        /// No events scheduled.
        case free
        /// Light schedule with few events.
        case light
        /// Moderate schedule.
        case moderate
        /// Busy schedule with many events.
        case busy
        /// Very busy, back-to-back events.
        case veryBusy
    }

    /// A single calendar event.
    public struct CalendarEvent: Codable, Sendable, Identifiable {
        /// Unique event identifier.
        public let id: String
        /// Event title.
        public let title: String
        /// Event start time.
        public let startDate: Date
        /// Event end time.
        public let endDate: Date
        /// Event location, if specified.
        public let location: String?
        /// Whether this is an all-day event.
        public let isAllDay: Bool
        /// Number of attendees.
        public let attendeeCount: Int
        /// Whether the event includes a video call link.
        public let hasVideoCall: Bool
        /// Name of the calendar containing this event.
        public let calendarName: String?

        /// Creates a calendar event.
        /// - Parameters:
        ///   - id: Event identifier.
        ///   - title: Event title.
        ///   - startDate: Start time.
        ///   - endDate: End time.
        ///   - location: Event location.
        ///   - isAllDay: Whether all-day.
        ///   - attendeeCount: Number of attendees.
        ///   - hasVideoCall: Whether has video call.
        ///   - calendarName: Calendar name.
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

    /// Creates a calendar context.
    /// - Parameters:
    ///   - currentEvent: Currently active event.
    ///   - upcomingEvents: Upcoming events.
    ///   - freeTimeUntilNextEvent: Seconds until next event.
    ///   - busyLevel: Schedule busyness.
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

/// Status of the user's communication channels (email, messages, calls).
public struct CommunicationContext: Codable, Sendable {
    /// Number of unread emails.
    public let unreadEmailCount: Int
    /// Number of unread messages.
    public let unreadMessageCount: Int
    /// Recently contacted people.
    public let recentContacts: [RecentContact]
    /// Number of missed phone calls.
    public let missedCallCount: Int
    /// Number of messages awaiting a reply.
    public let pendingReplies: Int

    /// A recently contacted person.
    public struct RecentContact: Codable, Sendable {
        /// Contact's display name.
        public let name: String
        /// When the last communication occurred.
        public let lastContactDate: Date
        /// Channel of communication.
        public let communicationType: CommunicationType

        /// Communication channel type.
        public enum CommunicationType: String, Codable, Sendable {
            /// Email communication.
            case email
            /// Text/chat message.
            case message
            /// Voice phone call.
            case call
            /// Video call.
            case videoCall
        }

        /// Creates a recent contact entry.
        /// - Parameters:
        ///   - name: Contact name.
        ///   - lastContactDate: Last communication time.
        ///   - communicationType: Communication channel.
        public init(name: String, lastContactDate: Date, communicationType: CommunicationType) {
            self.name = name
            self.lastContactDate = lastContactDate
            self.communicationType = communicationType
        }
    }

    /// Creates a communication context.
    /// - Parameters:
    ///   - unreadEmailCount: Unread emails.
    ///   - unreadMessageCount: Unread messages.
    ///   - recentContacts: Recent contacts.
    ///   - missedCallCount: Missed calls.
    ///   - pendingReplies: Pending replies.
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

/// Information about the current clipboard contents.
public struct ClipboardContext: Codable, Sendable {
    /// Whether the clipboard has any content.
    public let hasContent: Bool
    /// Type of content on the clipboard.
    public let contentType: ClipboardContentType?
    /// Preview of text content (truncated for privacy).
    public let textPreview: String?
    /// Size of clipboard content in bytes.
    public let contentSize: Int?
    /// When the content was last copied.
    public let lastCopiedDate: Date?

    /// Classification of clipboard content types.
    public enum ClipboardContentType: String, Codable, Sendable {
        /// Plain text.
        case text
        /// URL.
        case url
        /// Image data.
        case image
        /// File reference.
        case file
        /// Rich text (RTF).
        case richText
        /// HTML content.
        case html
    }

    /// Creates a clipboard context.
    /// - Parameters:
    ///   - hasContent: Whether clipboard has content.
    ///   - contentType: Type of content.
    ///   - textPreview: Text preview.
    ///   - contentSize: Content size in bytes.
    ///   - lastCopiedDate: When last copied.
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

/// Current Focus mode / Do Not Disturb state.
public struct FocusContext: Codable, Sendable {
    /// Whether a Focus mode is currently active.
    public let isActive: Bool
    /// Display name of the active Focus mode.
    public let modeName: String
    /// System identifier of the Focus mode.
    public let modeIdentifier: String?
    /// When the Focus mode started.
    public let startTime: Date?
    /// When the Focus mode is scheduled to end.
    public let endTime: Date?
    /// Apps allowed to send notifications during Focus.
    public let allowedApps: [String]?
    /// Apps silenced during Focus.
    public let silencedApps: [String]?

    /// Creates a focus context.
    /// - Parameters:
    ///   - isActive: Whether Focus is active.
    ///   - modeName: Focus mode name.
    ///   - modeIdentifier: System identifier.
    ///   - startTime: Focus start time.
    ///   - endTime: Focus end time.
    ///   - allowedApps: Allowed app bundle IDs.
    ///   - silencedApps: Silenced app bundle IDs.
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

/// Hardware and system state of the current device.
public struct DeviceStateContext: Codable, Sendable {
    /// Battery charge level (0.0 - 1.0).
    public let batteryLevel: Float
    /// Current battery charging state.
    public let batteryState: BatteryState
    /// Whether Low Power Mode is enabled.
    public let isLowPowerMode: Bool
    /// Current thermal state of the device.
    public let thermalState: ThermalState
    /// Primary network connection type.
    public let networkType: NetworkType
    /// Whether connected to a WiFi network.
    public let isWiFiConnected: Bool
    /// Whether connected to a cellular network.
    public let isCellularConnected: Bool
    /// SSID of the connected WiFi network.
    public let wifiSSID: String?
    /// Available storage in gigabytes.
    public let storageAvailableGB: Double?
    /// Current memory pressure level.
    public let memoryPressure: MemoryPressure
    /// Screen brightness (0.0 - 1.0).
    public let screenBrightness: Float?
    /// System volume level (0.0 - 1.0).
    public let volumeLevel: Float?
    /// Whether headphones or AirPods are connected.
    public let isHeadphonesConnected: Bool
    /// Current device physical orientation.
    public let orientation: DeviceOrientation

    /// Battery charging state.
    public enum BatteryState: String, Codable, Sendable {
        /// Battery state cannot be determined.
        case unknown
        /// Running on battery power.
        case unplugged
        /// Connected to power and charging.
        case charging
        /// Fully charged.
        case full
    }

    /// Device thermal throttling state.
    public enum ThermalState: String, Codable, Sendable {
        /// Normal operating temperature.
        case nominal
        /// Slightly elevated temperature.
        case fair
        /// High temperature, performance may be reduced.
        case serious
        /// Critical temperature, significant throttling.
        case critical
    }

    /// Network connection type.
    public enum NetworkType: String, Codable, Sendable {
        /// No network connection.
        case none
        /// WiFi connection.
        case wifi
        /// Cellular data connection.
        case cellular
        /// Wired ethernet connection.
        case ethernet
        /// Connection type cannot be determined.
        case unknown
    }

    /// System memory pressure level.
    public enum MemoryPressure: String, Codable, Sendable {
        /// Normal memory availability.
        case normal
        /// Memory is getting low.
        case warning
        /// Memory is critically low.
        case critical
    }

    /// Physical orientation of the device.
    public enum DeviceOrientation: String, Codable, Sendable {
        /// Portrait orientation (home button at bottom).
        case portrait
        /// Upside-down portrait.
        case portraitUpsideDown
        /// Landscape with home button on left.
        case landscapeLeft
        /// Landscape with home button on right.
        case landscapeRight
        /// Screen facing up.
        case faceUp
        /// Screen facing down.
        case faceDown
        /// Orientation cannot be determined.
        case unknown
    }

    /// Creates a device state context.
    /// - Parameters:
    ///   - batteryLevel: Charge level (0.0-1.0).
    ///   - batteryState: Charging state.
    ///   - isLowPowerMode: Low Power Mode enabled.
    ///   - thermalState: Thermal throttling state.
    ///   - networkType: Network connection type.
    ///   - isWiFiConnected: WiFi connected.
    ///   - isCellularConnected: Cellular connected.
    ///   - wifiSSID: WiFi network name.
    ///   - storageAvailableGB: Available storage in GB.
    ///   - memoryPressure: Memory pressure level.
    ///   - screenBrightness: Screen brightness (0.0-1.0).
    ///   - volumeLevel: Volume level (0.0-1.0).
    ///   - isHeadphonesConnected: Headphones connected.
    ///   - orientation: Physical orientation.
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

/// Information about currently playing media.
public struct MediaContext: Codable, Sendable {
    /// Whether media is currently playing.
    public let isPlaying: Bool
    /// Title of the currently playing track.
    public let nowPlayingTitle: String?
    /// Artist of the currently playing track.
    public let nowPlayingArtist: String?
    /// Album of the currently playing track.
    public let nowPlayingAlbum: String?
    /// App playing the media (e.g. "Music", "Spotify").
    public let nowPlayingApp: String?
    /// Current playback position in seconds.
    public let playbackPosition: TimeInterval?
    /// Total duration of the track in seconds.
    public let duration: TimeInterval?

    /// Creates a media context.
    /// - Parameters:
    ///   - isPlaying: Whether media is playing.
    ///   - nowPlayingTitle: Track title.
    ///   - nowPlayingArtist: Track artist.
    ///   - nowPlayingAlbum: Track album.
    ///   - nowPlayingApp: Media player app.
    ///   - playbackPosition: Current position.
    ///   - duration: Track duration.
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

/// Ambient environment information (time, light, noise, weather, accessories).
public struct EnvironmentContext: Codable, Sendable {
    /// Current time-of-day period.
    public let timeOfDay: TimeOfDay
    /// Whether today is a weekend day.
    public let isWeekend: Bool
    /// Whether it is currently daylight outside.
    public let isDaylight: Bool
    /// Ambient light sensor reading (0.0 - 1.0).
    public let ambientLightLevel: Float?
    /// Ambient noise level in decibels.
    public let noiseLevel: Float?
    /// Names of nearby Bluetooth devices.
    public let nearbyBluetoothDevices: [String]
    /// Names of connected accessories (keyboards, mice, etc.).
    public let connectedAccessories: [String]
    /// Active HomeKit scene name, if any.
    public let homeKitScene: String?
    /// Current weather condition description.
    public let weatherCondition: String?
    /// Current temperature in the user's preferred unit.
    public let temperature: Double?

    /// Coarse time-of-day period.
    public enum TimeOfDay: String, Codable, Sendable {
        /// 5:00 - 8:00.
        case earlyMorning
        /// 8:00 - 12:00.
        case morning
        /// 12:00 - 17:00.
        case afternoon
        /// 17:00 - 21:00.
        case evening
        /// 21:00 - 5:00.
        case night
    }

    /// Creates an environment context.
    /// - Parameters:
    ///   - timeOfDay: Time-of-day period.
    ///   - isWeekend: Whether it is a weekend.
    ///   - isDaylight: Whether it is daylight.
    ///   - ambientLightLevel: Light level (0.0-1.0).
    ///   - noiseLevel: Noise in decibels.
    ///   - nearbyBluetoothDevices: Nearby BT devices.
    ///   - connectedAccessories: Connected accessories.
    ///   - homeKitScene: Active HomeKit scene.
    ///   - weatherCondition: Weather description.
    ///   - temperature: Current temperature.
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

/// An incremental update to context from a single provider.
public struct ContextUpdate: Sendable {
    /// Identifier of the provider that generated this update.
    public let providerId: String
    /// When the update was generated.
    public let timestamp: Date
    /// The context data being updated.
    public let updateType: UpdateType
    /// Urgency of this update.
    public let priority: Priority

    /// Discriminated union of context update payloads.
    public enum UpdateType: Sendable {
        /// Location context update.
        case location(LocationContext)
        /// App activity context update.
        case appActivity(AppActivityContext)
        /// Health metrics context update.
        case health(HealthContext)
        /// Calendar context update.
        case calendar(CalendarContext)
        /// Communication context update.
        case communication(CommunicationContext)
        /// Clipboard context update.
        case clipboard(ClipboardContext)
        /// Focus mode context update.
        case focus(FocusContext)
        /// Device state context update.
        case deviceState(DeviceStateContext)
        /// Media playback context update.
        case media(MediaContext)
        /// Environment context update.
        case environment(EnvironmentContext)
    }

    /// Priority level for context updates, determining processing order.
    public enum Priority: Int, Sendable, Comparable {
        /// Low priority, processed when idle.
        case low = 0
        /// Normal priority.
        case normal = 1
        /// High priority, processed promptly.
        case high = 2
        /// Critical priority, processed immediately.
        case critical = 3

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Creates a context update.
    /// - Parameters:
    ///   - providerId: Source provider identifier.
    ///   - timestamp: Update timestamp.
    ///   - updateType: Context data payload.
    ///   - priority: Update priority.
    public init(providerId: String, timestamp: Date = Date(), updateType: UpdateType, priority: Priority = .normal) {
        self.providerId = providerId
        self.timestamp = timestamp
        self.updateType = updateType
        self.priority = priority
    }
}
