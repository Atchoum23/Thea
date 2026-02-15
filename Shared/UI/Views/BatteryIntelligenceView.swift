// BatteryIntelligenceView.swift
// Thea — Battery health monitoring + charge management UI
// Replaces: AlDente

import SwiftUI

struct BatteryIntelligenceView: View {
    @State private var optimizer = BatteryOptimizer.shared
    @State private var powerManager = PowerStateManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                batteryOverview
                optimizationModeSelector
                currentSettingsSection
                featureImpactSection
            }
            .padding()
        }
        .navigationTitle("Battery Intelligence")
    }

    // MARK: - Battery Overview

    private var batteryOverview: some View {
        GroupBox("Battery Status") {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(batteryColor)

                    VStack(alignment: .leading, spacing: 4) {
                        if let level = powerManager.batteryLevel {
                            Text("\(level)%")
                                .font(.title.bold())
                        } else {
                            Text("N/A")
                                .font(.title.bold())
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            Label(
                                powerManager.powerSource.displayName,
                                systemImage: powerManager.isCharging ? "bolt.fill" : "battery.100"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let remaining = powerManager.timeRemainingMinutes {
                                Text("~\(remaining) min remaining")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Label(optimizer.optimizationMode.displayName, systemImage: optimizer.optimizationMode.icon)
                            .font(.subheadline.bold())
                            .foregroundStyle(modeColor)

                        Text(optimizer.configuration.automaticOptimization ? "Automatic" : "Manual")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let level = powerManager.batteryLevel {
                    ProgressView(value: Double(level), total: 100)
                        .tint(batteryColor)
                }

                // Thermal state
                HStack {
                    Label("Thermal: \(powerManager.thermalState.displayName)", systemImage: "thermometer")
                        .font(.caption)
                        .foregroundStyle(thermalColor)

                    Spacer()

                    if powerManager.isLowPowerMode {
                        Label("Low Power Mode", systemImage: "bolt.slash")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Optimization Mode

    private var optimizationModeSelector: some View {
        GroupBox("Optimization Mode") {
            VStack(spacing: 12) {
                Toggle("Automatic Mode", isOn: Binding(
                    get: { optimizer.configuration.automaticOptimization },
                    set: { newValue in
                        if newValue {
                            optimizer.enableAutomaticOptimization()
                        } else {
                            optimizer.setManualMode(optimizer.optimizationMode)
                        }
                    }
                ))

                if !optimizer.configuration.automaticOptimization {
                    Picker("Mode", selection: Binding(
                        get: { optimizer.optimizationMode },
                        set: { optimizer.setManualMode($0) }
                    )) {
                        ForEach(OptimizationMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(optimizer.optimizationMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Current Settings

    private var currentSettingsSection: some View {
        GroupBox("Current Settings") {
            let settings = optimizer.currentSettings

            VStack(spacing: 8) {
                settingRow("Reduce Animations", value: settings.reduceAnimations)
                settingRow("Reduce Sync Frequency", value: settings.reduceSyncFrequency)
                settingRow("Reduce Background Activity", value: settings.reduceBackgroundActivity)
                settingRow("Defer Non-Critical Work", value: settings.deferNonCriticalWork)
                settingRow("Compress Network Data", value: settings.compressNetworkData)
                settingRow("Reduce Fetch Frequency", value: settings.reduceFetchFrequency)
                settingRow("Disable Prefetching", value: settings.disablePrefetching)
                settingRow("Reduce Image Quality", value: settings.reduceImageQuality)
            }
            .padding(.vertical, 4)
        }
    }

    private func settingRow(_ label: String, value: Bool) -> some View {
        HStack {
            Text(label)
                .font(.body)
            Spacer()
            Image(systemName: value ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(value ? .orange : .green)
        }
    }

    // MARK: - Feature Impact

    private var featureImpactSection: some View {
        GroupBox("Feature Impact") {
            VStack(spacing: 8) {
                ForEach(BatteryFeature.allCases, id: \.rawValue) { feature in
                    HStack {
                        Text(featureDisplayName(feature))
                            .font(.body)
                        Spacer()
                        let disabled = optimizer.shouldDisableFeature(feature)
                        Text(disabled ? "Disabled" : "Active")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(disabled ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                            .foregroundStyle(disabled ? .red : .green)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func featureDisplayName(_ feature: BatteryFeature) -> String {
        switch feature {
        case .animations: "UI Animations"
        case .backgroundSync: "Background Sync"
        case .prefetching: "Data Prefetching"
        case .hdImages: "HD Images"
        case .liveActivity: "Live Activity"
        case .voiceActivation: "Voice Activation"
        case .continuousMonitoring: "Continuous Monitoring"
        }
    }

    // MARK: - Computed Properties

    private var batteryIcon: String {
        guard let level = powerManager.batteryLevel else { return "battery.0" }
        if powerManager.isCharging { return "battery.100.bolt" }
        if level >= 75 { return "battery.100" }
        if level >= 50 { return "battery.75" }
        if level >= 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        guard let level = powerManager.batteryLevel else { return .secondary }
        if level >= 50 { return .green }
        if level >= 20 { return .orange }
        return .red
    }

    private var modeColor: Color {
        switch optimizer.optimizationMode {
        case .performance: .blue
        case .balanced: .green
        case .maxSaver: .orange
        case .ultraSaver: .red
        }
    }

    private var thermalColor: Color {
        switch powerManager.thermalState {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        case .unknown: .secondary
        }
    }
}

// MARK: - BatteryFeature CaseIterable

extension BatteryFeature: CaseIterable {
    public static var allCases: [BatteryFeature] {
        [.animations, .backgroundSync, .prefetching, .hdImages, .liveActivity, .voiceActivation, .continuousMonitoring]
    }
}
