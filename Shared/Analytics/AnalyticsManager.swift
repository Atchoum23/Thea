// AnalyticsManager.swift
// Privacy-first analytics and telemetry system

import Combine
import Foundation
import OSLog

// MARK: - Analytics Manager

/// Privacy-first analytics with local-first approach
@MainActor
public final class AnalyticsManager: ObservableObject {
    public static let shared = AnalyticsManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Analytics")

    // MARK: - Published State

    @Published public private(set) var isEnabled = true
    @Published public private(set) var sessionId: String = ""
    @Published public private(set) var eventCount: Int = 0
    @Published public private(set) var lastSyncTime: Date?

    // MARK: - Storage

    private var events: [AnalyticsEvent] = []
    private var userProperties: [String: Any] = [:]
    private var sessionProperties: [String: Any] = [:]
    private let maxEventsInMemory = 1000
    private let batchSize = 50

    // MARK: - Session

    private var sessionStartTime: Date?
    private var lastActivityTime: Date?
    private let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes

    // MARK: - Providers

    private var providers: [AnalyticsProvider] = []

    // MARK: - Initialization

    private init() {
        loadSettings()
        startSession()
        setupPeriodicSync()
    }

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "analytics.enabled")
        if UserDefaults.standard.object(forKey: "analytics.enabled") == nil {
            isEnabled = true // Default to enabled
        }
    }

    // MARK: - Configuration

    /// Enable or disable analytics
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "analytics.enabled")

        if enabled {
            startSession()
        } else {
            endSession()
            clearLocalData()
        }

        logger.info("Analytics \(enabled ? "enabled" : "disabled")")
    }

    /// Register analytics provider
    public func registerProvider(_ provider: AnalyticsProvider) {
        providers.append(provider)
        logger.info("Registered analytics provider: \(type(of: provider))")
    }

    // MARK: - Session Management

    private func startSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        lastActivityTime = Date()

        sessionProperties = [
            "session_id": sessionId,
            "session_start": ISO8601DateFormatter().string(from: sessionStartTime!),
            "platform": getPlatform(),
            "os_version": getOSVersion(),
            "app_version": getAppVersion(),
            "device_model": getDeviceModel(),
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier
        ]

        track("session_start")
        logger.info("Session started: \(self.sessionId)")
    }

    private func endSession() {
        guard let start = sessionStartTime else { return }

        let duration = Date().timeIntervalSince(start)
        track("session_end", properties: [
            "duration_seconds": duration,
            "event_count": eventCount
        ])

        sessionId = ""
        sessionStartTime = nil
        eventCount = 0

        logger.info("Session ended")
    }

    /// Check and refresh session if needed
    public func refreshSession() {
        guard let lastActivity = lastActivityTime else {
            startSession()
            return
        }

        if Date().timeIntervalSince(lastActivity) > sessionTimeout {
            endSession()
            startSession()
        } else {
            lastActivityTime = Date()
        }
    }

    // MARK: - Event Tracking

    /// Track an event
    public func track(_ eventName: String, properties: [String: Any]? = nil) {
        guard isEnabled else { return }

        refreshSession()

        var eventProperties = properties ?? [:]

        // Add session properties
        eventProperties.merge(sessionProperties) { current, _ in current }

        // Add timestamp
        eventProperties["timestamp"] = ISO8601DateFormatter().string(from: Date())

        let event = AnalyticsEvent(
            name: eventName,
            properties: eventProperties,
            timestamp: Date()
        )

        events.append(event)
        eventCount += 1

        // Send to providers
        for provider in providers {
            provider.track(event)
        }

        // Trim if too many events
        if events.count > maxEventsInMemory {
            events.removeFirst(events.count - maxEventsInMemory)
        }

        logger.debug("Tracked event: \(eventName)")
    }

    /// Track screen view
    public func trackScreen(_ screenName: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["screen_name"] = screenName
        track("screen_view", properties: props)
    }

    /// Track user action
    public func trackAction(_ action: String, target: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["action"] = action
        if let target {
            props["target"] = target
        }
        track("user_action", properties: props)
    }

    /// Track error
    public func trackError(_ error: Error, context: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["error_type"] = String(describing: type(of: error))
        props["error_message"] = error.localizedDescription
        if let context {
            props["context"] = context
        }
        track("error", properties: props)
    }

    /// Track performance metric
    public func trackPerformance(_ metric: String, value: Double, unit: String? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["metric"] = metric
        props["value"] = value
        if let unit {
            props["unit"] = unit
        }
        track("performance", properties: props)
    }

    /// Track timing
    public func trackTiming(_ category: String, variable: String, duration: TimeInterval, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["category"] = category
        props["variable"] = variable
        props["duration_ms"] = duration * 1000
        track("timing", properties: props)
    }

    // MARK: - User Properties

    /// Set user property
    public func setUserProperty(_ key: String, value: Any) {
        guard isEnabled else { return }

        userProperties[key] = value

        for provider in providers {
            provider.setUserProperty(key, value: value)
        }
    }

    /// Set user ID
    public func setUserId(_ userId: String?) {
        guard isEnabled else { return }

        if let id = userId {
            userProperties["user_id"] = id
        } else {
            userProperties.removeValue(forKey: "user_id")
        }

        for provider in providers {
            provider.setUserId(userId)
        }
    }

    /// Increment user property
    public func incrementUserProperty(_ key: String, by amount: Int = 1) {
        let current = (userProperties[key] as? Int) ?? 0
        setUserProperty(key, value: current + amount)
    }

    // MARK: - Funnel Tracking

    /// Track funnel step
    public func trackFunnelStep(_ funnelName: String, step: Int, stepName: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["funnel_name"] = funnelName
        props["step_number"] = step
        props["step_name"] = stepName
        track("funnel_step", properties: props)
    }

    /// Track conversion
    public func trackConversion(_ conversionName: String, value: Double? = nil, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["conversion_name"] = conversionName
        if let value {
            props["conversion_value"] = value
        }
        track("conversion", properties: props)
    }

    // MARK: - Feature Usage

    /// Track feature usage
    public func trackFeatureUsage(_ featureName: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["feature_name"] = featureName
        track("feature_usage", properties: props)

        // Also increment feature counter
        incrementUserProperty("feature_\(featureName)_count")
    }

    /// Track A/B test exposure
    public func trackExperiment(_ experimentName: String, variant: String, properties: [String: Any]? = nil) {
        var props = properties ?? [:]
        props["experiment_name"] = experimentName
        props["variant"] = variant
        track("experiment_exposure", properties: props)
    }

    // MARK: - AI-Specific Tracking

    /// Track AI conversation
    public func trackConversation(messageCount: Int, tokensUsed: Int, modelName: String, duration: TimeInterval) {
        track("ai_conversation", properties: [
            "message_count": messageCount,
            "tokens_used": tokensUsed,
            "model_name": modelName,
            "duration_seconds": duration
        ])
    }

    /// Track AI response quality feedback
    public func trackAIFeedback(responseId: String, rating: Int, feedbackType: String) {
        track("ai_feedback", properties: [
            "response_id": responseId,
            "rating": rating,
            "feedback_type": feedbackType
        ])
    }

    /// Track tool usage
    public func trackToolUsage(toolName: String, success: Bool, duration: TimeInterval) {
        track("tool_usage", properties: [
            "tool_name": toolName,
            "success": success,
            "duration_seconds": duration
        ])
    }

    // MARK: - Data Sync

    private func setupPeriodicSync() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Every minute
                await syncEvents()
            }
        }
    }

    /// Sync events to backend
    public func syncEvents() async {
        guard isEnabled, !events.isEmpty else { return }

        // Batch events
        let eventsToSync = Array(events.prefix(batchSize))

        // Send to providers
        for provider in providers {
            await provider.flush(eventsToSync)
        }

        // Remove synced events
        events.removeFirst(min(eventsSize, events.count))
        lastSyncTime = Date()

        logger.debug("Synced \(eventsToSync.count) events")
    }

    private var eventsSize: Int { min(batchSize, events.count) }

    // MARK: - Data Export

    /// Export analytics data
    public func exportData() -> AnalyticsExport {
        AnalyticsExport(
            events: events,
            userProperties: userProperties,
            sessionProperties: sessionProperties,
            exportTime: Date()
        )
    }

    /// Clear local analytics data
    public func clearLocalData() {
        events.removeAll()
        eventCount = 0
        logger.info("Local analytics data cleared")
    }

    // MARK: - Device Info

    private func getPlatform() -> String {
        #if os(macOS)
            return "macOS"
        #elseif os(iOS)
            return "iOS"
        #elseif os(watchOS)
            return "watchOS"
        #elseif os(tvOS)
            return "tvOS"
        #elseif os(visionOS)
            return "visionOS"
        #else
            return "unknown"
        #endif
    }

    private func getOSVersion() -> String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private func getDeviceModel() -> String {
        #if os(macOS)
            var size = 0
            sysctlbyname("hw.model", nil, &size, nil, 0)
            var model = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &model, &size, nil, 0)
            return String(decoding: model.map { UInt8(bitPattern: $0) }, as: UTF8.self).trimmingCharacters(in: .controlCharacters)
        #else
            var systemInfo = utsname()
            uname(&systemInfo)
            return withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }
        #endif
    }
}

// MARK: - Timing Helper

public final class AnalyticsTimer: @unchecked Sendable {
    private let startTime: Date
    private let category: String
    private let variable: String
    private var properties: [String: Any]

    public init(category: String, variable: String, properties: [String: Any] = [:]) {
        startTime = Date()
        self.category = category
        self.variable = variable
        self.properties = properties
    }

    public func stop() {
        let duration = Date().timeIntervalSince(startTime)
        // Capture values before async boundary to avoid data races
        let capturedCategory = category
        let capturedVariable = variable
        let capturedProperties = properties
        Task { @MainActor in
            AnalyticsManager.shared.trackTiming(capturedCategory, variable: capturedVariable, duration: duration, properties: capturedProperties)
        }
    }

    public func addProperty(_ key: String, value: Any) {
        properties[key] = value
    }
}

// MARK: - Types

public struct AnalyticsEvent: Identifiable, Codable, Sendable {
    public var id = UUID()
    public let name: String
    public let properties: [String: AnyCodable]
    public let timestamp: Date

    init(name: String, properties: [String: Any], timestamp: Date) {
        self.name = name
        self.properties = properties.mapValues { AnyCodable($0) }
        self.timestamp = timestamp
    }
}

public struct AnalyticsExport: Codable {
    public let events: [AnalyticsEvent]
    public let userProperties: [String: AnyCodable]
    public let sessionProperties: [String: AnyCodable]
    public let exportTime: Date

    init(events: [AnalyticsEvent], userProperties: [String: Any], sessionProperties: [String: Any], exportTime: Date) {
        self.events = events
        self.userProperties = userProperties.mapValues { AnyCodable($0) }
        self.sessionProperties = sessionProperties.mapValues { AnyCodable($0) }
        self.exportTime = exportTime
    }
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encode(String(describing: value))
        }
    }
}

// MARK: - Analytics Provider Protocol

public protocol AnalyticsProvider: Sendable {
    func track(_ event: AnalyticsEvent)
    func setUserProperty(_ key: String, value: Any)
    func setUserId(_ userId: String?)
    func flush(_ events: [AnalyticsEvent]) async
}

// MARK: - Local Analytics Provider

public final class LocalAnalyticsProvider: AnalyticsProvider, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.thea.app", category: "Analytics.Local")
    private let fileURL: URL

    public init() {
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            fileURL = documentsPath.appendingPathComponent("analytics.json")
        } else {
            // Fallback to temporary directory if documents directory is unavailable
            logger.error("Unable to access documents directory, falling back to temp directory")
            fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("analytics.json")
        }
    }

    public func track(_: AnalyticsEvent) {
        // Already stored in AnalyticsManager
    }

    public func setUserProperty(_: String, value _: Any) {
        // Stored in AnalyticsManager
    }

    public func setUserId(_: String?) {
        // Stored in AnalyticsManager
    }

    public func flush(_ events: [AnalyticsEvent]) async {
        // Save to local file
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: fileURL)
            logger.debug("Saved \(events.count) events to local storage")
        } catch {
            logger.error("Failed to save events: \(error.localizedDescription)")
        }
    }
}

// MARK: - Console Analytics Provider (Debug)

public final class ConsoleAnalyticsProvider: AnalyticsProvider, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.thea.app", category: "Analytics.Console")

    public init() {}

    public func track(_ event: AnalyticsEvent) {
        #if DEBUG
            logger.info("📊 [\(event.name)] \(event.properties)")
        #endif
    }

    public func setUserProperty(_ key: String, value: Any) {
        #if DEBUG
            logger.info("👤 User property: \(key) = \(String(describing: value))")
        #endif
    }

    public func setUserId(_ userId: String?) {
        #if DEBUG
            logger.info("👤 User ID: \(userId ?? "nil")")
        #endif
    }

    public func flush(_ events: [AnalyticsEvent]) async {
        #if DEBUG
            logger.info("📤 Flushing \(events.count) events")
        #endif
    }
}
