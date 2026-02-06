// PreferenceSyncEngine.swift
// Thea
//
// Intelligent cross-device preference synchronisation using NSUbiquitousKeyValueStore.
// Categorises every setting into a SyncScope so the right data reaches the right devices.

import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Device Class

/// The broad class of Apple device running Thea.
public enum TheaDeviceClass: String, Codable, CaseIterable, Sendable {
    case mac
    case iPhone
    case iPad
    case appleTV
    case appleWatch

    /// The class of the device we are currently running on.
    public static var current: TheaDeviceClass {
        #if os(macOS)
        .mac
        #elseif os(watchOS)
        .appleWatch
        #elseif os(tvOS)
        .appleTV
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad { return .iPad }
        return .iPhone
        #else
        .mac
        #endif
    }

    /// Whether this class shares a sync group with another class.
    /// Mac ↔ Mac, iPhone ↔ iPad, TV standalone, Watch standalone.
    public func sharesSyncGroup(with other: TheaDeviceClass) -> Bool {
        switch (self, other) {
        case (.mac, .mac): true
        case (.iPhone, .iPad), (.iPad, .iPhone): true
        case (.iPhone, .iPhone): true
        case (.iPad, .iPad): true
        case (.appleTV, .appleTV): true
        case (.appleWatch, .appleWatch): true
        default: false
        }
    }

    public var displayName: String {
        switch self {
        case .mac: "Mac"
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .appleTV: "Apple TV"
        case .appleWatch: "Apple Watch"
        }
    }

    public var systemImage: String {
        switch self {
        case .mac: "desktopcomputer"
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .appleTV: "appletv"
        case .appleWatch: "applewatch"
        }
    }
}

// MARK: - Sync Scope

/// Determines how a preference is synchronised across devices.
public enum SyncScope: String, Codable, CaseIterable, Sendable {
    /// Synced to every device signed into the same iCloud account.
    case universal

    /// Synced only between devices of the same class-group
    /// (Mac ↔ Mac, iPhone ↔ iPad).
    case deviceClass

    /// Never synced. Stored only on this device.
    case deviceLocal

    public var displayName: String {
        switch self {
        case .universal: "All Devices"
        case .deviceClass: "Same Device Type"
        case .deviceLocal: "This Device Only"
        }
    }

    public var explanation: String {
        switch self {
        case .universal:
            "Synced across every Apple device signed into your iCloud."
        case .deviceClass:
            "Synced only between similar devices (e.g. Mac ↔ Mac, iPhone ↔ iPad)."
        case .deviceLocal:
            "Stays on this device and is never uploaded to iCloud."
        }
    }

    public var icon: String {
        switch self {
        case .universal: "icloud"
        case .deviceClass: "laptopcomputer.and.iphone"
        case .deviceLocal: "lock.shield"
        }
    }
}

// MARK: - Sync Category

/// Logical grouping of preferences for the settings UI.
public enum SyncCategory: String, Codable, CaseIterable, Sendable {
    case appearance
    case aiProviders
    case behavior
    case privacy
    case voice
    case localModels
    case execution
    case advanced

    public var displayName: String {
        switch self {
        case .appearance: "Appearance"
        case .aiProviders: "AI Providers"
        case .behavior: "Behavior"
        case .privacy: "Privacy"
        case .voice: "Voice"
        case .localModels: "Local Models"
        case .execution: "Execution & Permissions"
        case .advanced: "Advanced"
        }
    }

    public var icon: String {
        switch self {
        case .appearance: "paintbrush"
        case .aiProviders: "brain"
        case .behavior: "gearshape.2"
        case .privacy: "hand.raised"
        case .voice: "waveform"
        case .localModels: "cpu"
        case .execution: "terminal"
        case .advanced: "wrench.and.screwdriver"
        }
    }

    /// The default sync scope recommended for this category.
    public var defaultScope: SyncScope {
        switch self {
        case .appearance: .universal
        case .aiProviders: .universal
        case .behavior: .deviceClass
        case .privacy: .universal
        case .voice: .deviceClass
        case .localModels: .deviceLocal   // paths are machine-specific
        case .execution: .deviceClass
        case .advanced: .deviceLocal
        }
    }
}

// MARK: - Preference Descriptor

/// Metadata about a single syncable preference.
public struct PreferenceDescriptor: Sendable {
    public let key: String
    public let category: SyncCategory
    public let defaultScope: SyncScope
    public let displayName: String

    public init(key: String, category: SyncCategory, defaultScope: SyncScope, displayName: String) {
        self.key = key
        self.category = category
        self.defaultScope = defaultScope
        self.displayName = displayName
    }
}

// MARK: - Preference Registry

/// Central registry of every syncable preference and its metadata.
public enum PreferenceRegistry {
    public static let all: [PreferenceDescriptor] = [
        // Appearance
        PreferenceDescriptor(key: "theme", category: .appearance, defaultScope: .universal, displayName: "Theme"),
        PreferenceDescriptor(key: "fontSize", category: .appearance, defaultScope: .universal, displayName: "Font Size"),
        PreferenceDescriptor(key: "messageDensity", category: .appearance, defaultScope: .universal, displayName: "Message Density"),
        PreferenceDescriptor(key: "timestampDisplay", category: .appearance, defaultScope: .universal, displayName: "Timestamp Display"),

        // AI Providers
        PreferenceDescriptor(key: "defaultProvider", category: .aiProviders, defaultScope: .universal, displayName: "Default Provider"),
        PreferenceDescriptor(key: "streamResponses", category: .aiProviders, defaultScope: .universal, displayName: "Stream Responses"),

        // Behavior
        PreferenceDescriptor(key: "launchAtLogin", category: .behavior, defaultScope: .deviceLocal, displayName: "Launch at Login"),
        PreferenceDescriptor(key: "showInMenuBar", category: .behavior, defaultScope: .deviceClass, displayName: "Show in Menu Bar"),
        PreferenceDescriptor(key: "notificationsEnabled", category: .behavior, defaultScope: .universal, displayName: "Notifications"),
        PreferenceDescriptor(key: "windowFloatOnTop", category: .behavior, defaultScope: .deviceClass, displayName: "Float on Top"),
        PreferenceDescriptor(key: "rememberWindowPosition", category: .behavior, defaultScope: .deviceClass, displayName: "Remember Window Position"),
        PreferenceDescriptor(key: "defaultWindowSize", category: .behavior, defaultScope: .deviceClass, displayName: "Default Window Size"),
        PreferenceDescriptor(key: "autoScrollToBottom", category: .behavior, defaultScope: .universal, displayName: "Auto-Scroll to Bottom"),
        PreferenceDescriptor(key: "showSidebarOnLaunch", category: .behavior, defaultScope: .deviceClass, displayName: "Show Sidebar on Launch"),
        PreferenceDescriptor(key: "restoreLastSession", category: .behavior, defaultScope: .deviceClass, displayName: "Restore Last Session"),
        PreferenceDescriptor(key: "handoffEnabled", category: .behavior, defaultScope: .universal, displayName: "Handoff"),

        // Privacy
        PreferenceDescriptor(key: "iCloudSyncEnabled", category: .privacy, defaultScope: .deviceLocal, displayName: "iCloud Sync"),
        PreferenceDescriptor(key: "analyticsEnabled", category: .privacy, defaultScope: .universal, displayName: "Analytics"),

        // Voice
        PreferenceDescriptor(key: "readResponsesAloud", category: .voice, defaultScope: .deviceClass, displayName: "Read Aloud"),
        PreferenceDescriptor(key: "selectedVoice", category: .voice, defaultScope: .deviceClass, displayName: "Selected Voice"),

        // Local Models
        PreferenceDescriptor(key: "mlxModelsPath", category: .localModels, defaultScope: .deviceLocal, displayName: "Models Path"),
        PreferenceDescriptor(key: "ollamaEnabled", category: .localModels, defaultScope: .deviceLocal, displayName: "Ollama Enabled"),
        PreferenceDescriptor(key: "ollamaURL", category: .localModels, defaultScope: .deviceLocal, displayName: "Ollama URL"),

        // Execution
        PreferenceDescriptor(key: "executionMode", category: .execution, defaultScope: .deviceClass, displayName: "Execution Mode"),
        PreferenceDescriptor(key: "allowFileCreation", category: .execution, defaultScope: .deviceClass, displayName: "Allow File Creation"),
        PreferenceDescriptor(key: "allowFileEditing", category: .execution, defaultScope: .deviceClass, displayName: "Allow File Editing"),
        PreferenceDescriptor(key: "allowCodeExecution", category: .execution, defaultScope: .deviceClass, displayName: "Allow Code Execution"),
        PreferenceDescriptor(key: "allowExternalAPICalls", category: .execution, defaultScope: .deviceClass, displayName: "Allow External API Calls"),
        PreferenceDescriptor(key: "requireDestructiveApproval", category: .execution, defaultScope: .universal, displayName: "Require Destructive Approval"),
        PreferenceDescriptor(key: "enableRollback", category: .execution, defaultScope: .universal, displayName: "Enable Rollback"),
        PreferenceDescriptor(key: "createBackups", category: .execution, defaultScope: .universal, displayName: "Create Backups"),
        PreferenceDescriptor(key: "preventSleepDuringExecution", category: .execution, defaultScope: .deviceClass, displayName: "Prevent Sleep"),
        PreferenceDescriptor(key: "maxConcurrentTasks", category: .execution, defaultScope: .deviceClass, displayName: "Max Concurrent Tasks"),

        // Advanced
        PreferenceDescriptor(key: "debugMode", category: .advanced, defaultScope: .deviceLocal, displayName: "Debug Mode"),
        PreferenceDescriptor(key: "showPerformanceMetrics", category: .advanced, defaultScope: .deviceLocal, displayName: "Performance Metrics"),
        PreferenceDescriptor(key: "betaFeaturesEnabled", category: .advanced, defaultScope: .deviceLocal, displayName: "Beta Features")
    ]

    public static func descriptor(for key: String) -> PreferenceDescriptor? {
        all.first { $0.key == key }
    }

    public static func descriptors(for category: SyncCategory) -> [PreferenceDescriptor] {
        all.filter { $0.category == category }
    }
}

// MARK: - Device Profile

/// Identity of this specific device, persisted locally.
public struct DeviceProfile: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var model: String
    public var deviceClass: TheaDeviceClass
    public var osVersion: String
    public var lastActive: Date

    public static func current() -> DeviceProfile {
        let stored = load()
        if let existing = stored { return existing }
        let profile = DeviceProfile.detect()
        profile.save()
        return profile
    }

    private static func detect() -> DeviceProfile {
        let id = identifierForVendor()
        let name: String
        let model: String

        #if os(macOS)
        name = Host.current().localizedName ?? "Mac"
        model = macModelName()
        #elseif os(watchOS)
        name = WKInterfaceDevice.current().name
        model = WKInterfaceDevice.current().model
        #elseif os(iOS) || os(tvOS)
        name = UIDevice.current.name
        model = UIDevice.current.model
        #else
        name = "Unknown"
        model = "Unknown"
        #endif

        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        return DeviceProfile(
            id: id,
            name: name,
            model: model,
            deviceClass: TheaDeviceClass.current,
            osVersion: osVersion,
            lastActive: Date()
        )
    }

    private static func identifierForVendor() -> String {
        if let saved = UserDefaults.standard.string(forKey: "com.thea.deviceID") {
            return saved
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "com.thea.deviceID")
        return newID
    }

    #if os(macOS)
    private static func macModelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        let bytes = machine.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
    #endif

    // MARK: Persistence

    private static let storageKey = "com.thea.deviceProfile"

    private static func load() -> DeviceProfile? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              var profile = try? JSONDecoder().decode(DeviceProfile.self, from: data)
        else { return nil }
        profile.lastActive = Date()
        profile.save()
        return profile
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

// MARK: - Preference Sync Engine

/// Bridges SettingsManager ↔ NSUbiquitousKeyValueStore, respecting SyncScope per key.
///
/// Architecture:
/// - **Universal** keys are written to iCloud KVS as-is.
/// - **DeviceClass** keys are prefixed with the device class so only same-class devices read them.
/// - **DeviceLocal** keys are never written to iCloud KVS.
///
/// Uses NSUbiquitousKeyValueStore (1 MB / 1024 keys limit) which is ideal for preferences.
/// For heavier payloads (conversations, knowledge) the existing CloudKitService handles sync.
@MainActor
public final class PreferenceSyncEngine: ObservableObject {
    public static let shared = PreferenceSyncEngine()

    // MARK: Published State

    @Published public private(set) var isCloudAvailable = false
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var pendingSyncCount = 0
    @Published public private(set) var registeredDevices: [DeviceProfile] = []

    // MARK: User-Configurable Scope Overrides

    /// Users can override the default scope for any category.
    @Published public var scopeOverrides: [SyncCategory: SyncScope] = [:] {
        didSet { saveScopeOverrides() }
    }

    // MARK: Private

    private let cloud = NSUbiquitousKeyValueStore.default
    private let deviceProfile = DeviceProfile.current()
    private var observers: Set<AnyCancellable> = []
    private let scopeOverridesKey = "com.thea.syncScopeOverrides"
    private let devicesKey = "com.thea.registeredDevices"
    private var isSyncing = false

    // MARK: Init

    private init() {
        loadScopeOverrides()
        registerDevice()
        checkCloudAvailability()
        observeCloudChanges()

        // Initial pull
        cloud.synchronize()
    }

    // MARK: - Scope Resolution

    /// Returns the effective scope for a key, respecting user overrides.
    public func effectiveScope(for key: String) -> SyncScope {
        guard let descriptor = PreferenceRegistry.descriptor(for: key) else {
            return .deviceLocal
        }
        return scopeOverrides[descriptor.category] ?? descriptor.defaultScope
    }

    /// Returns the effective scope for a category, respecting user overrides.
    public func effectiveScope(for category: SyncCategory) -> SyncScope {
        scopeOverrides[category] ?? category.defaultScope
    }

    // MARK: - Cloud Key Mapping

    /// Translates a local key into the cloud key, respecting scope.
    private func cloudKey(for localKey: String) -> String? {
        let scope = effectiveScope(for: localKey)
        switch scope {
        case .universal:
            return "u.\(localKey)"
        case .deviceClass:
            return "dc.\(TheaDeviceClass.current.rawValue).\(localKey)"
        case .deviceLocal:
            return nil // not synced
        }
    }

    /// Extracts the local key and scope from a cloud key.
    private func parseCloudKey(_ cloudKey: String) -> (localKey: String, scope: SyncScope, deviceClass: TheaDeviceClass?)? {
        if cloudKey.hasPrefix("u.") {
            let localKey = String(cloudKey.dropFirst(2))
            return (localKey, .universal, nil)
        } else if cloudKey.hasPrefix("dc.") {
            let rest = cloudKey.dropFirst(3)
            guard let dotIndex = rest.firstIndex(of: ".") else { return nil }
            let classStr = String(rest[rest.startIndex..<dotIndex])
            let localKey = String(rest[rest.index(after: dotIndex)...])
            guard let devClass = TheaDeviceClass(rawValue: classStr) else { return nil }
            return (localKey, .deviceClass, devClass)
        }
        return nil
    }

    // MARK: - Write to Cloud

    /// Called by SettingsManager after every didSet. Pushes the value to iCloud if appropriate.
    public func push(_ value: Any?, forKey localKey: String) {
        guard !isSyncing else { return } // prevent feedback loops
        guard let ck = cloudKey(for: localKey) else { return }

        if let value {
            cloud.set(value, forKey: ck)
        } else {
            cloud.removeObject(forKey: ck)
        }

        // Also stamp the modification time
        cloud.set(Date().timeIntervalSince1970, forKey: "\(ck).__ts")

        pendingSyncCount += 1
        cloud.synchronize()
    }

    /// Push a batch of key-value pairs (e.g. during initial sync).
    public func pushAll(from defaults: UserDefaults = .standard) {
        for descriptor in PreferenceRegistry.all {
            guard let ck = cloudKey(for: descriptor.key) else { continue }
            if let value = defaults.object(forKey: descriptor.key) {
                cloud.set(value, forKey: ck)
                cloud.set(Date().timeIntervalSince1970, forKey: "\(ck).__ts")
            }
        }
        cloud.synchronize()
        lastSyncDate = Date()
    }

    // MARK: - Read from Cloud

    /// Applies all cloud values to local UserDefaults.
    /// Called on launch and whenever NSUbiquitousKeyValueStoreDidChangeExternallyNotification fires.
    public func pullAll(into defaults: UserDefaults = .standard) {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        let cloudDict = cloud.dictionaryRepresentation

        for (ck, value) in cloudDict {
            guard let parsed = parseCloudKey(ck) else { continue }

            // Skip timestamp meta-keys
            if ck.hasSuffix(".__ts") { continue }

            // For deviceClass keys, only apply if we share the sync group
            if parsed.scope == .deviceClass,
               let devClass = parsed.deviceClass,
               !TheaDeviceClass.current.sharesSyncGroup(with: devClass)
            {
                continue
            }

            // Compare timestamps: cloud wins if newer
            let cloudTimestamp = cloudDict["\(ck).__ts"] as? TimeInterval ?? 0
            let localTimestamp = defaults.double(forKey: "\(parsed.localKey).__localTS")

            if cloudTimestamp > localTimestamp {
                defaults.set(value, forKey: parsed.localKey)
                defaults.set(cloudTimestamp, forKey: "\(parsed.localKey).__localTS")
            }
        }

        // Notify SettingsManager to reload from UserDefaults
        NotificationCenter.default.post(name: .preferenceSyncDidPull, object: nil)
        loadRegisteredDevices()
    }

    // MARK: - Cloud Change Observer

    private func observeCloudChanges() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] notification in
            // Extract values on the calling thread to avoid sending non-Sendable Notification
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int ?? -1
            let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

            Task { @MainActor [weak self] in
                guard let self else { return }

                switch reason {
                case NSUbiquitousKeyValueStoreServerChange,
                     NSUbiquitousKeyValueStoreInitialSyncChange:
                    self.pullAll()
                case NSUbiquitousKeyValueStoreAccountChange:
                    self.checkCloudAvailability()
                    self.pullAll()
                case NSUbiquitousKeyValueStoreQuotaViolationChange:
                    self.handleQuotaViolation(changedKeys: changedKeys)
                default:
                    break
                }
            }
        }
    }

    // MARK: - Cloud Availability

    private func checkCloudAvailability() {
        // NSUbiquitousKeyValueStore is available if iCloud is signed in
        // We test by attempting synchronize
        isCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Device Registration

    /// Registers this device in the cloud so other devices can discover it.
    private func registerDevice() {
        var profile = deviceProfile
        profile.lastActive = Date()
        profile.save()

        // Store in cloud
        if let data = try? JSONEncoder().encode(profile) {
            cloud.set(data, forKey: "device.\(profile.id)")
        }
        cloud.synchronize()
        loadRegisteredDevices()
    }

    private func loadRegisteredDevices() {
        let cloudDict = cloud.dictionaryRepresentation
        var devices: [DeviceProfile] = []

        for (key, value) in cloudDict where key.hasPrefix("device.") {
            guard let data = value as? Data,
                  let profile = try? JSONDecoder().decode(DeviceProfile.self, from: data)
            else { continue }
            devices.append(profile)
        }

        // Sort: current device first, then by last active
        registeredDevices = devices.sorted { lhs, rhs in
            if lhs.id == deviceProfile.id { return true }
            if rhs.id == deviceProfile.id { return false }
            return lhs.lastActive > rhs.lastActive
        }
    }

    // MARK: - Quota Handling

    private func handleQuotaViolation(changedKeys: [String]) {
        // Remove timestamp meta-keys first (they're expendable)
        let cloudDict = cloud.dictionaryRepresentation
        let tsKeys = cloudDict.keys.filter { $0.hasSuffix(".__ts") }
        for key in tsKeys {
            cloud.removeObject(forKey: key)
        }
        cloud.synchronize()
    }

    // MARK: - Scope Overrides Persistence

    private func saveScopeOverrides() {
        let dict = scopeOverrides.mapKeys { $0.rawValue }.mapValues { $0.rawValue }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: scopeOverridesKey)
        }
    }

    private func loadScopeOverrides() {
        guard let data = UserDefaults.standard.data(forKey: scopeOverridesKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }

        scopeOverrides = dict.compactMap { key, value -> (SyncCategory, SyncScope)? in
            guard let cat = SyncCategory(rawValue: key),
                  let scope = SyncScope(rawValue: value)
            else { return nil }
            return (cat, scope)
        }
        .reduce(into: [:]) { $0[$1.0] = $1.1 }
    }

    // MARK: - Force Sync

    /// Triggers an immediate full push + pull.
    public func forceSync() {
        pushAll()
        cloud.synchronize()
        pullAll()
    }
}

// MARK: - Notification

public extension Notification.Name {
    /// Posted when the sync engine has pulled new values into UserDefaults.
    /// SettingsManager should listen for this and reload its @Published properties.
    static let preferenceSyncDidPull = Notification.Name("com.thea.preferenceSyncDidPull")
}

// MARK: - Dictionary Helpers

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        [T: Value](uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
