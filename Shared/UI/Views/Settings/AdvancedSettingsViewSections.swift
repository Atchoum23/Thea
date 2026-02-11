// AdvancedSettingsViewSections.swift
// Supporting types for AdvancedSettingsView

import SwiftUI

// MARK: - Supporting Types

struct AdvancedSettingsConfiguration: Equatable, Codable {
    // Development
    var showTokenCounts = false
    var showModelLatency = false
    var showMemoryUsage = false

    // Network
    var useProxy = false
    var proxyHost = ""
    var proxyPort = 8080
    var proxyType: AdvancedProxyType = .http
    var requestTimeout: Double = 60
    var connectionTimeout: Double = 15
    var useCustomHeaders = false
    var customHeaders: [AdvancedHTTPHeader] = []

    // Logging
    var logLevel: AdvancedLogLevel = .info
    var logAPIRequests = false
    var logAPIResponses = false
    var logToFile = false
    var logFileSize = "1.2 MB"
    var maxLogFiles = 5
    var logEntryCount = 42
    var logEntries: [AdvancedLogEntry] = [
        AdvancedLogEntry(level: .info, message: "Application started", timestamp: Date().addingTimeInterval(-3600), source: "AppDelegate"),
        AdvancedLogEntry(level: .debug, message: "Loading configuration", timestamp: Date().addingTimeInterval(-3500), source: "ConfigManager"),
        AdvancedLogEntry(level: .warning, message: "Network retry attempted", timestamp: Date().addingTimeInterval(-1800), source: "NetworkService")
    ]

    // Performance
    var memoryLimit: Double = 512
    var maxBackgroundTasks = 3
    var preloadModels = true
    var gpuAcceleration = true
    var reduceMotion = false
    var lowPowerMode = false

    // Cache
    var maxCacheSize: Double = 200
    var cacheAPIResponses = true
    var cacheModelOutputs = true
    var cacheImages = true
    var apiCacheSize = "25.3 MB"
    var modelCacheSize = "45.1 MB"
    var imageCacheSize = "12.8 MB"
    var tempCacheSize = "8.4 MB"

    // Experimental
    var experimentalUI = false
    var advancedCodeEditor = false
    var multiModelConversations = false
    var parallelProcessing = false
    var featureFlags: [String: Bool] = [
        "new_chat_ui": false,
        "voice_streaming": false,
        "smart_suggestions": true,
        "auto_tagging": false
    ]

    // System info
    var appVersion = "2.0.0"
    var buildNumber = "2024.01.29"
    var deviceModel = "Mac"
    var osVersion = "macOS 14.3"
    var platform = "macOS"
    var freeStorage = "156.2 GB"
    var totalMemory = "16 GB"
    var recentErrors: [AdvancedErrorEntry] = []

    private static let storageKey = "com.thea.advancedConfiguration"

    @MainActor
    static func load() -> AdvancedSettingsConfiguration {
        var config: AdvancedSettingsConfiguration
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode(AdvancedSettingsConfiguration.self, from: data)
        {
            config = loaded
        } else {
            config = AdvancedSettingsConfiguration()
        }

        // Update system info
        #if os(macOS)
        config.platform = "macOS"
        config.deviceModel = "Mac"
        config.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #elseif os(iOS)
        config.platform = "iOS"
        config.deviceModel = UIDevice.current.model
        config.osVersion = UIDevice.current.systemVersion
        #endif

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            config.appVersion = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            config.buildNumber = build
        }

        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

enum AdvancedProxyType: String, Codable {
    case http
    case https
    case socks5
}

enum AdvancedLogLevel: String, Codable {
    case none
    case error
    case warning
    case info
    case debug
    case verbose
}

struct AdvancedHTTPHeader: Equatable, Codable, Identifiable {
    var id = UUID()
    var key: String
    var value: String
}

struct AdvancedLogEntry: Equatable, Codable {
    var level: AdvancedLogLevel
    var message: String
    var timestamp: Date
    var source: String?
}

struct AdvancedErrorEntry: Equatable, Codable {
    var message: String
    var timestamp: Date
}
