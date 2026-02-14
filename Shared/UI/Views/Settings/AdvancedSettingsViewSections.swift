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

// MARK: - Log Level Helpers

func advancedLogLevelIcon(_ level: AdvancedLogLevel) -> String {
    switch level {
    case .none: "circle"
    case .error: "xmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .info: "info.circle.fill"
    case .debug: "ladybug.fill"
    case .verbose: "text.alignleft"
    }
}

func advancedLogLevelColor(_ level: AdvancedLogLevel) -> Color {
    switch level {
    case .none: .secondary
    case .error: .red
    case .warning: .orange
    case .info: .blue
    case .debug: .purple
    case .verbose: .secondary
    }
}

// MARK: - Diagnostic Report Sheet

struct AdvancedDiagnosticReportSheet: View {
    let advancedConfig: AdvancedSettingsConfiguration
    let settingsManager: SettingsManager
    let cacheSize: String
    @Binding var isPresented: Bool
    let reportTextGenerator: () -> String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Diagnostic Report")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Generated: \(Date(), style: .date) \(Date(), style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    Group {
                        Text("System Information")
                            .font(.headline)

                        Text("""
                        Device: \(advancedConfig.deviceModel)
                        OS: \(advancedConfig.osVersion)
                        App: \(advancedConfig.appVersion) (\(advancedConfig.buildNumber))
                        Memory: \(advancedConfig.totalMemory)
                        Storage: \(advancedConfig.freeStorage) free
                        """)
                        .font(.system(.body, design: .monospaced))
                    }

                    Divider()

                    Group {
                        Text("Configuration")
                            .font(.headline)

                        Text("""
                        Debug Mode: \(settingsManager.debugMode ? "Enabled" : "Disabled")
                        Beta Features: \(settingsManager.betaFeaturesEnabled ? "Enabled" : "Disabled")
                        Log Level: \(advancedConfig.logLevel.rawValue)
                        Cache Size: \(cacheSize)
                        """)
                        .font(.system(.body, design: .monospaced))
                    }

                    Divider()

                    Group {
                        Text("Recent Errors")
                            .font(.headline)

                        if advancedConfig.recentErrors.isEmpty {
                            Text("No recent errors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(advancedConfig.recentErrors, id: \.timestamp) { error in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(error.message)
                                        .font(.system(.body, design: .monospaced))

                                    Text(error.timestamp, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Diagnostic Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: reportTextGenerator())
                }
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 600)
        #endif
    }
}

// MARK: - Log Viewer Sheet

struct AdvancedLogViewerSheet: View {
    let logEntries: [AdvancedLogEntry]
    @Binding var isPresented: Bool
    let onClearLogs: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(logEntries.reversed(), id: \.timestamp) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: advancedLogLevelIcon(entry.level))
                                .foregroundStyle(advancedLogLevelColor(entry.level))

                            Text(entry.level.rawValue.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(advancedLogLevelColor(entry.level))

                            Spacer()

                            Text(entry.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text(entry.message)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)

                        if let source = entry.source {
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Log Viewer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) {
                        onClearLogs()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 700, height: 600)
        #endif
    }
}

// MARK: - Actions

extension AdvancedSettingsView {

    func clearCache() {
        cacheSize = "0 MB"
        advancedConfig.apiCacheSize = "0 MB"
        advancedConfig.modelCacheSize = "0 MB"
        advancedConfig.imageCacheSize = "0 MB"
        advancedConfig.tempCacheSize = "0 MB"
    }

    func clearLogs() {
        advancedConfig.logEntries = []
        advancedConfig.logEntryCount = 0
    }

    func generateDiagnosticReport() {
        isGeneratingReport = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isGeneratingReport = false
                showingDiagnosticReport = true
            }
        }
    }

    func generateReportText() -> String {
        """
        THEA DIAGNOSTIC REPORT
        Generated: \(Date())

        SYSTEM INFORMATION
        Device: \(advancedConfig.deviceModel)
        OS: \(advancedConfig.osVersion)
        App: \(advancedConfig.appVersion) (\(advancedConfig.buildNumber))
        Memory: \(advancedConfig.totalMemory)
        Storage: \(advancedConfig.freeStorage) free

        CONFIGURATION
        Debug Mode: \(settingsManager.debugMode ? "Enabled" : "Disabled")
        Beta Features: \(settingsManager.betaFeaturesEnabled ? "Enabled" : "Disabled")
        Log Level: \(advancedConfig.logLevel.rawValue)
        Cache Size: \(cacheSize)
        """
    }

    func copySystemInfo() {
        let info = generateReportText()
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
        #else
        UIPasteboard.general.string = info
        #endif
    }

    func resetAdvancedSettings() {
        advancedConfig = AdvancedSettingsConfiguration()
        advancedConfig.save()
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    AdvancedSettingsView()
        .frame(width: 700, height: 900)
}
#else
#Preview {
    NavigationStack {
        AdvancedSettingsView()
            .navigationTitle("Advanced")
    }
}
#endif
