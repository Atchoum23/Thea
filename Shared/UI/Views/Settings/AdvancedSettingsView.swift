// AdvancedSettingsView.swift
// Comprehensive advanced settings for Thea

import SwiftUI

struct AdvancedSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var advancedConfig = AdvancedSettingsConfiguration.load()
    @State private var showingDiagnosticReport = false
    @State private var showingLogViewer = false
    @State private var isGeneratingReport = false
    @State private var cacheSize = "Calculating..."
    @State private var memoryUsage = "Calculating..."

    var body: some View {
        Form {
            // MARK: - Overview
            Section("System Overview") {
                systemOverview
            }

            // MARK: - Development
            Section("Development") {
                developmentSection
            }

            // MARK: - Network
            Section("Network") {
                networkSection
            }

            // MARK: - Logging
            Section("Logging") {
                loggingSection
            }

            // MARK: - Performance
            Section("Performance") {
                performanceSection
            }

            // MARK: - Cache
            Section("Cache & Storage") {
                cacheSection
            }

            // MARK: - Experimental
            Section("Experimental Features") {
                experimentalSection
            }

            // MARK: - Diagnostics
            Section("Diagnostics") {
                diagnosticsSection
            }

            // MARK: - Reset
            Section {
                Button("Reset Advanced Settings", role: .destructive) {
                    resetAdvancedSettings()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .onAppear {
            calculateCacheSize()
            calculateMemoryUsage()
        }
        .onChange(of: advancedConfig) { _, _ in
            advancedConfig.save()
        }
        .sheet(isPresented: $showingDiagnosticReport) {
            diagnosticReportSheet
        }
        .sheet(isPresented: $showingLogViewer) {
            logViewerSheet
        }
    }

    // MARK: - System Overview

    private var systemOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(
                    title: "Debug Mode",
                    value: settingsManager.debugMode ? "On" : "Off",
                    icon: "ladybug.fill",
                    color: settingsManager.debugMode ? .orange : .secondary
                )

                overviewCard(
                    title: "Memory",
                    value: memoryUsage,
                    icon: "memorychip",
                    color: .blue
                )

                overviewCard(
                    title: "Cache",
                    value: cacheSize,
                    icon: "internaldrive",
                    color: .purple
                )

                overviewCard(
                    title: "Logs",
                    value: "\(advancedConfig.logEntryCount)",
                    icon: "doc.text",
                    color: .green
                )
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCard(
                    title: "Debug Mode",
                    value: settingsManager.debugMode ? "On" : "Off",
                    icon: "ladybug.fill",
                    color: settingsManager.debugMode ? .orange : .secondary
                )

                overviewCard(
                    title: "Memory",
                    value: memoryUsage,
                    icon: "memorychip",
                    color: .blue
                )

                overviewCard(
                    title: "Cache",
                    value: cacheSize,
                    icon: "internaldrive",
                    color: .purple
                )

                overviewCard(
                    title: "Logs",
                    value: "\(advancedConfig.logEntryCount)",
                    icon: "doc.text",
                    color: .green
                )
            }
            #endif

            // Version info
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thea \(advancedConfig.appVersion)")
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("Build \(advancedConfig.buildNumber)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(advancedConfig.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Development Section

    private var developmentSection: some View {
        Group {
            Toggle("Enable Debug Mode", isOn: $settingsManager.debugMode)

            Text("Shows additional debugging information in the UI")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Show Performance Metrics", isOn: $settingsManager.showPerformanceMetrics)

            Text("Display real-time performance data in conversations")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Show Token Counts", isOn: $advancedConfig.showTokenCounts)

            Toggle("Show Model Latency", isOn: $advancedConfig.showModelLatency)

            Toggle("Show Memory Usage", isOn: $advancedConfig.showMemoryUsage)
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        Group {
            Toggle("Use Proxy", isOn: $advancedConfig.useProxy)

            if advancedConfig.useProxy {
                TextField("Proxy Host", text: $advancedConfig.proxyHost)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Proxy Port")
                    Spacer()
                    TextField("Port", value: $advancedConfig.proxyPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                Picker("Proxy Type", selection: $advancedConfig.proxyType) {
                    Text("HTTP").tag(AdvancedProxyType.http)
                    Text("HTTPS").tag(AdvancedProxyType.https)
                    Text("SOCKS5").tag(AdvancedProxyType.socks5)
                }
            }

            Divider()

            // Timeout settings
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Request Timeout")
                    Spacer()
                    Text("\(Int(advancedConfig.requestTimeout)) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $advancedConfig.requestTimeout, in: 10 ... 300, step: 10)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Connection Timeout")
                    Spacer()
                    Text("\(Int(advancedConfig.connectionTimeout)) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $advancedConfig.connectionTimeout, in: 5 ... 60, step: 5)
            }

            Divider()

            // Custom headers
            Toggle("Custom HTTP Headers", isOn: $advancedConfig.useCustomHeaders)

            if advancedConfig.useCustomHeaders {
                ForEach(advancedConfig.customHeaders.indices, id: \.self) { index in
                    HStack {
                        TextField("Header", text: $advancedConfig.customHeaders[index].key)
                            .textFieldStyle(.roundedBorder)

                        TextField("Value", text: $advancedConfig.customHeaders[index].value)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            advancedConfig.customHeaders.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    advancedConfig.customHeaders.append(AdvancedHTTPHeader(key: "", value: ""))
                } label: {
                    Label("Add Header", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Logging Section

    private var loggingSection: some View {
        Group {
            Picker("Log Level", selection: $advancedConfig.logLevel) {
                Text("None").tag(AdvancedLogLevel.none)
                Text("Error").tag(AdvancedLogLevel.error)
                Text("Warning").tag(AdvancedLogLevel.warning)
                Text("Info").tag(AdvancedLogLevel.info)
                Text("Debug").tag(AdvancedLogLevel.debug)
                Text("Verbose").tag(AdvancedLogLevel.verbose)
            }

            Toggle("Log API Requests", isOn: $advancedConfig.logAPIRequests)

            Toggle("Log API Responses", isOn: $advancedConfig.logAPIResponses)

            Text("API logging may include sensitive data. Use with caution.")
                .font(.caption)
                .foregroundStyle(.orange)

            Toggle("Log to File", isOn: $advancedConfig.logToFile)

            if advancedConfig.logToFile {
                HStack {
                    Text("Log File Size")
                    Spacer()
                    Text("\(advancedConfig.logFileSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Max Log Files")
                    Spacer()
                    Stepper("\(advancedConfig.maxLogFiles)", value: $advancedConfig.maxLogFiles, in: 1 ... 10)
                }
            }

            Divider()

            HStack {
                Button {
                    showingLogViewer = true
                } label: {
                    Label("View Logs", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)

                Button {
                    clearLogs()
                } label: {
                    Label("Clear Logs", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        Group {
            // Memory limit
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Memory Limit")
                    Spacer()
                    Text("\(Int(advancedConfig.memoryLimit)) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $advancedConfig.memoryLimit, in: 256 ... 2048, step: 128)

                Text("Maximum memory usage before automatic cleanup")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Background tasks
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Max Background Tasks")
                    Spacer()
                    Stepper("\(advancedConfig.maxBackgroundTasks)", value: $advancedConfig.maxBackgroundTasks, in: 1 ... 10)
                }

                Text("Number of concurrent background operations allowed")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            Toggle("Preload Models", isOn: $advancedConfig.preloadModels)

            Text("Keep frequently used models in memory for faster responses")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("GPU Acceleration", isOn: $advancedConfig.gpuAcceleration)

            Text("Use GPU for local model inference when available")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Reduce Motion", isOn: $advancedConfig.reduceMotion)

            Toggle("Low Power Mode", isOn: $advancedConfig.lowPowerMode)

            Text("Reduces performance to extend battery life")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
        Group {
            HStack {
                Text("Cache Size")
                Spacer()
                Text(cacheSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Max Cache Size")
                    Spacer()
                    Text("\(Int(advancedConfig.maxCacheSize)) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $advancedConfig.maxCacheSize, in: 50 ... 1000, step: 50)
            }

            Divider()

            Toggle("Cache API Responses", isOn: $advancedConfig.cacheAPIResponses)

            Toggle("Cache Model Outputs", isOn: $advancedConfig.cacheModelOutputs)

            Toggle("Cache Images", isOn: $advancedConfig.cacheImages)

            Divider()

            // Cache breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Cache Breakdown")
                    .font(.subheadline)
                    .fontWeight(.medium)

                cacheBreakdownRow(title: "API Responses", size: advancedConfig.apiCacheSize)
                cacheBreakdownRow(title: "Model Outputs", size: advancedConfig.modelCacheSize)
                cacheBreakdownRow(title: "Images", size: advancedConfig.imageCacheSize)
                cacheBreakdownRow(title: "Temporary Files", size: advancedConfig.tempCacheSize)
            }

            Button {
                clearCache()
            } label: {
                Label("Clear All Cache", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    private func cacheBreakdownRow(title: String, size: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)

            Spacer()

            Text(size)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Experimental Section

    private var experimentalSection: some View {
        Group {
            Toggle("Enable Beta Features", isOn: $settingsManager.betaFeaturesEnabled)

            Text("Beta features may be unstable and are subject to change")
                .font(.caption)
                .foregroundStyle(.orange)

            Divider()

            Toggle("Experimental UI", isOn: $advancedConfig.experimentalUI)

            Toggle("Advanced Code Editor", isOn: $advancedConfig.advancedCodeEditor)

            Toggle("Multi-Model Conversations", isOn: $advancedConfig.multiModelConversations)

            Toggle("Parallel Processing", isOn: $advancedConfig.parallelProcessing)

            Text("Process multiple requests simultaneously")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Feature flags
            DisclosureGroup("Feature Flags") {
                ForEach(advancedConfig.featureFlags.sorted { $0.key < $1.key }, id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.caption)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { value },
                            set: { advancedConfig.featureFlags[key] = $0 }
                        ))
                        .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Diagnostics Section

    private var diagnosticsSection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diagnostic Report")
                        .font(.subheadline)

                    Text("Generate a detailed report for troubleshooting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    generateDiagnosticReport()
                } label: {
                    if isGeneratingReport {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Generate", systemImage: "doc.badge.gearshape")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isGeneratingReport)
            }

            Divider()

            // System info
            VStack(alignment: .leading, spacing: 8) {
                Text("System Information")
                    .font(.subheadline)
                    .fontWeight(.medium)

                systemInfoRow(title: "Device", value: advancedConfig.deviceModel)
                systemInfoRow(title: "OS Version", value: advancedConfig.osVersion)
                systemInfoRow(title: "App Version", value: advancedConfig.appVersion)
                systemInfoRow(title: "Build", value: advancedConfig.buildNumber)
                systemInfoRow(title: "Free Storage", value: advancedConfig.freeStorage)
                systemInfoRow(title: "Total Memory", value: advancedConfig.totalMemory)
            }

            Divider()

            // Copy system info
            Button {
                copySystemInfo()
            } label: {
                Label("Copy System Info", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.bordered)
        }
    }

    private func systemInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)

            Spacer()

            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Diagnostic Report Sheet

    private var diagnosticReportSheet: some View {
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
                        showingDiagnosticReport = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: generateReportText())
                }
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 600)
        #endif
    }

    // MARK: - Log Viewer Sheet

    private var logViewerSheet: some View {
        NavigationStack {
            List {
                ForEach(advancedConfig.logEntries.reversed(), id: \.timestamp) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: logLevelIcon(entry.level))
                                .foregroundStyle(logLevelColor(entry.level))

                            Text(entry.level.rawValue.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(logLevelColor(entry.level))

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
                        showingLogViewer = false
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) {
                        clearLogs()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 700, height: 600)
        #endif
    }

    private func logLevelIcon(_ level: AdvancedLogLevel) -> String {
        switch level {
        case .none: "circle"
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .debug: "ladybug.fill"
        case .verbose: "text.alignleft"
        }
    }

    private func logLevelColor(_ level: AdvancedLogLevel) -> Color {
        switch level {
        case .none: .secondary
        case .error: .red
        case .warning: .orange
        case .info: .blue
        case .debug: .purple
        case .verbose: .secondary
        }
    }

    // MARK: - Actions

    private func calculateCacheSize() {
        // Simulate cache calculation
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                cacheSize = "~\(Int.random(in: 20...150)) MB"
            }
        }
    }

    private func calculateMemoryUsage() {
        // Simulate memory calculation
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                memoryUsage = "\(Int.random(in: 80...300)) MB"
            }
        }
    }

    private func clearCache() {
        cacheSize = "0 MB"
        advancedConfig.apiCacheSize = "0 MB"
        advancedConfig.modelCacheSize = "0 MB"
        advancedConfig.imageCacheSize = "0 MB"
        advancedConfig.tempCacheSize = "0 MB"
    }

    private func clearLogs() {
        advancedConfig.logEntries = []
        advancedConfig.logEntryCount = 0
    }

    private func generateDiagnosticReport() {
        isGeneratingReport = true

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isGeneratingReport = false
                showingDiagnosticReport = true
            }
        }
    }

    private func generateReportText() -> String {
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

    private func copySystemInfo() {
        let info = generateReportText()
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
        #else
        UIPasteboard.general.string = info
        #endif
    }

    private func resetAdvancedSettings() {
        advancedConfig = AdvancedSettingsConfiguration()
        advancedConfig.save()
    }
}

// MARK: - Supporting Types (Private to this file)

private struct AdvancedSettingsConfiguration: Equatable, Codable {
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

private enum AdvancedProxyType: String, Codable {
    case http
    case https
    case socks5
}

private enum AdvancedLogLevel: String, Codable {
    case none
    case error
    case warning
    case info
    case debug
    case verbose
}

private struct AdvancedHTTPHeader: Equatable, Codable, Identifiable {
    var id = UUID()
    var key: String
    var value: String
}

private struct AdvancedLogEntry: Equatable, Codable {
    var level: AdvancedLogLevel
    var message: String
    var timestamp: Date
    var source: String?
}

private struct AdvancedErrorEntry: Equatable, Codable {
    var message: String
    var timestamp: Date
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
