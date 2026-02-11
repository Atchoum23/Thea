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
            AdvancedDiagnosticReportSheet(
                advancedConfig: advancedConfig,
                settingsManager: settingsManager,
                cacheSize: cacheSize,
                isPresented: $showingDiagnosticReport,
                reportTextGenerator: generateReportText
            )
        }
        .sheet(isPresented: $showingLogViewer) {
            AdvancedLogViewerSheet(
                logEntries: advancedConfig.logEntries,
                isPresented: $showingLogViewer,
                onClearLogs: clearLogs
            )
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
