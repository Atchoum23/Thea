// ResourceAllocationSettingsView.swift
// Settings UI for dynamic AI-powered resource allocation

import SwiftUI

struct ResourceAllocationSettingsView: View {
    @State private var allocator = DynamicResourceAllocator.shared
    @State private var configuration = DynamicResourceAllocator.shared.configuration
    @State private var showingAdvanced = false

    var body: some View {
        Form {
            // Current Status Section
            Section {
                statusOverview
                currentAllocationDetails
            } header: {
                Text("Current Status")
            } footer: {
                if let reason = allocator.lastAdjustmentReason {
                    Text("Last adjustment: \(reason)")
                }
            }

            // System Metrics Section
            Section {
                metricsGrid
            } header: {
                HStack {
                    Text("System Metrics")
                    Spacer()
                    if allocator.isMonitoring {
                        Text("Live")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.theaSuccess.opacity(0.2))
                            .foregroundStyle(.theaSuccess)
                            .clipShape(Capsule())
                    }
                }
            }

            // Configuration Section
            Section {
                Toggle("Dynamic Allocation", isOn: $configuration.enableDynamicAllocation)
                    .onChange(of: configuration.enableDynamicAllocation) { _, _ in
                        saveConfiguration()
                    }

                Picker("Aggressiveness", selection: $configuration.aggressivenessLevel) {
                    ForEach(DynamicResourceAllocator.Configuration.AggressivenessLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .onChange(of: configuration.aggressivenessLevel) { _, _ in
                    saveConfiguration()
                }

                Toggle("Battery Awareness", isOn: $configuration.enableBatteryAwareness)
                    .onChange(of: configuration.enableBatteryAwareness) { _, _ in
                        saveConfiguration()
                    }

                Toggle("Thermal Throttling", isOn: $configuration.enableThermalThrottling)
                    .onChange(of: configuration.enableThermalThrottling) { _, _ in
                        saveConfiguration()
                    }

                Toggle("Memory Pressure Response", isOn: $configuration.enableMemoryPressureResponse)
                    .onChange(of: configuration.enableMemoryPressureResponse) { _, _ in
                        saveConfiguration()
                    }
            } header: {
                Text("Behavior")
            } footer: {
                Text("Dynamic allocation automatically adjusts memory and performance based on system state.")
            }

            // Advanced Settings Section
            Section {
                DisclosureGroup("Advanced Settings", isExpanded: $showingAdvanced) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Max memory slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Model Memory")
                                Spacer()
                                Text("\(Int(configuration.maxModelMemoryPercent * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $configuration.maxModelMemoryPercent, in: 0.3...0.8, step: 0.05)
                                .onChange(of: configuration.maxModelMemoryPercent) { _, _ in
                                    saveConfiguration()
                                }
                        }

                        // Min memory slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Min Model Memory")
                                Spacer()
                                Text("\(Int(configuration.minModelMemoryPercent * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $configuration.minModelMemoryPercent, in: 0.1...0.4, step: 0.05)
                                .onChange(of: configuration.minModelMemoryPercent) { _, _ in
                                    saveConfiguration()
                                }
                        }

                        // KV Cache allocation
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("KV Cache Allocation")
                                Spacer()
                                Text("\(Int(configuration.kvCacheMemoryPercent * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $configuration.kvCacheMemoryPercent, in: 0.05...0.3, step: 0.05)
                                .onChange(of: configuration.kvCacheMemoryPercent) { _, _ in
                                    saveConfiguration()
                                }
                        }

                        // Reserve system memory
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Reserved System Memory")
                                Spacer()
                                Text("\(String(format: "%.1f", configuration.reserveSystemMemoryGB)) GB")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $configuration.reserveSystemMemoryGB, in: 2...16, step: 1)
                                .onChange(of: configuration.reserveSystemMemoryGB) { _, _ in
                                    saveConfiguration()
                                }
                        }

                        // Update interval
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Update Interval")
                                Spacer()
                                Text("\(Int(configuration.updateIntervalSeconds))s")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $configuration.updateIntervalSeconds, in: 1...30, step: 1)
                                .onChange(of: configuration.updateIntervalSeconds) { _, _ in
                                    saveConfiguration()
                                }
                        }

                        Divider()

                        Toggle("GPU Offload", isOn: $configuration.enableGPUOffload)
                            .onChange(of: configuration.enableGPUOffload) { _, _ in
                                saveConfiguration()
                            }

                        Toggle("Neural Engine Optimization", isOn: $configuration.enableNeuralEngineOptimization)
                            .onChange(of: configuration.enableNeuralEngineOptimization) { _, _ in
                                saveConfiguration()
                            }

                        Toggle("Predictive Adjustment", isOn: $configuration.enablePredictiveAdjustment)
                            .onChange(of: configuration.enablePredictiveAdjustment) { _, _ in
                                saveConfiguration()
                            }
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Performance Tuning")
            }

            // Recommendations Section
            if !allocator.recommendations.isEmpty {
                Section {
                    ForEach(allocator.recommendations) { rec in
                        recommendationRow(rec)
                    }
                } header: {
                    Text("Recommendations")
                }
            }

            // Adjustment History Section
            if !allocator.adjustmentHistory.isEmpty {
                Section {
                    ForEach(allocator.adjustmentHistory.suffix(5).reversed()) { adjustment in
                        adjustmentHistoryRow(adjustment)
                    }
                } header: {
                    Text("Recent Adjustments")
                }
            }

            // Actions Section
            Section {
                Button {
                    Task {
                        await allocator.recalculateAllocation()
                    }
                } label: {
                    Label("Recalculate Now", systemImage: "arrow.clockwise")
                }

                Button {
                    configuration = DynamicResourceAllocator.Configuration()
                    saveConfiguration()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Resource Allocation")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            configuration = allocator.configuration
        }
    }

    // MARK: - Status Views

    @ViewBuilder
    private var statusOverview: some View {
        HStack(spacing: 16) {
            // Memory indicator
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: allocator.systemMetrics.memoryUsagePercent)
                        .stroke(memoryColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(allocator.systemMetrics.memoryUsagePercent * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .frame(width: 50, height: 50)
                Text("Memory")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Thermal indicator
            VStack(spacing: 4) {
                Image(systemName: thermalIcon)
                    .font(.title2)
                    .foregroundStyle(thermalColor)
                    .frame(height: 50)
                Text("Thermal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Throttle indicator
            VStack(spacing: 4) {
                Image(systemName: throttleIcon)
                    .font(.title2)
                    .foregroundStyle(throttleColor)
                    .frame(height: 50)
                Text("Throttle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Battery indicator (if applicable)
            #if os(macOS) || os(iOS)
            VStack(spacing: 4) {
                Image(systemName: batteryIcon)
                    .font(.title2)
                    .foregroundStyle(batteryColor)
                    .frame(height: 50)
                Text("Power")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            #endif
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var currentAllocationDetails: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Max Model Memory")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f GB", allocator.currentAllocation.maxModelMemoryGB))
                    .fontWeight(.medium)
            }

            HStack {
                Text("KV Cache Size")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f GB", allocator.currentAllocation.kvCacheSizeGB))
                    .fontWeight(.medium)
            }

            HStack {
                Text("Context Length")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(formatNumber(allocator.currentAllocation.recommendedContextLength)) tokens")
                    .fontWeight(.medium)
            }

            HStack {
                Text("Quantization")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(allocator.currentAllocation.quantizationLevel.rawValue)
                    .fontWeight(.medium)
            }

            HStack {
                Text("Est. Speed")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "~%.0f tok/s", allocator.currentAllocation.effectiveTokensPerSecond))
                    .fontWeight(.medium)
            }
        }
    }

    @ViewBuilder
    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            metricCard(
                title: "Total Memory",
                value: String(format: "%.0f GB", allocator.systemMetrics.totalMemoryGB),
                icon: "memorychip"
            )
            metricCard(
                title: "Available",
                value: String(format: "%.1f GB", allocator.systemMetrics.availableMemoryGB),
                icon: "square.stack.3d.up"
            )
            metricCard(
                title: "CPU Usage",
                value: String(format: "%.0f%%", allocator.systemMetrics.cpuUsagePercent),
                icon: "cpu"
            )
            metricCard(
                title: "GPU Usage",
                value: String(format: "%.0f%%", allocator.systemMetrics.gpuUsagePercent),
                icon: "gpu"
            )
        }
    }

    @ViewBuilder
    private func metricCard(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func recommendationRow(_ rec: DynamicResourceAllocator.ResourceRecommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: impactIcon(rec.impact))
                .foregroundStyle(impactColor(rec.impact))

            VStack(alignment: .leading, spacing: 4) {
                Text(rec.title)
                    .fontWeight(.medium)
                Text(rec.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func adjustmentHistoryRow(_ adjustment: DynamicResourceAllocator.ResourceAdjustment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(adjustment.reason)
                .font(.subheadline)
            HStack {
                Text(adjustment.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(String(format: "%.1f", adjustment.previousAllocation.maxModelMemoryGB)) → \(String(format: "%.1f", adjustment.newAllocation.maxModelMemoryGB)) GB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

}

// MARK: - Helpers

extension ResourceAllocationSettingsView {

    var memoryColor: Color {
        switch allocator.systemMetrics.memoryPressure {
        case .nominal: .theaSuccess
        case .warning: .theaWarning
        case .critical: .theaError
        }
    }

    var thermalIcon: String {
        switch allocator.systemMetrics.thermalState {
        case .nominal: "thermometer.medium"
        case .fair: "thermometer.medium"
        case .serious: "thermometer.high"
        case .critical: "thermometer.sun.fill"
        }
    }

    var thermalColor: Color {
        switch allocator.systemMetrics.thermalState {
        case .nominal: .theaSuccess
        case .fair: .yellow
        case .serious: .theaWarning
        case .critical: .theaError
        }
    }

    var throttleIcon: String {
        switch allocator.currentAllocation.throttleLevel {
        case .none: "bolt.fill"
        case .light: "bolt"
        case .moderate: "bolt.slash"
        case .heavy, .severe: "bolt.trianglebadge.exclamationmark"
        }
    }

    var throttleColor: Color {
        switch allocator.currentAllocation.throttleLevel {
        case .none: .theaSuccess
        case .light: .yellow
        case .moderate: .theaWarning
        case .heavy, .severe: .theaError
        }
    }

    var batteryIcon: String {
        if allocator.systemMetrics.isCharging {
            return "battery.100.bolt"
        }
        let level = allocator.systemMetrics.batteryLevel
        return switch level {
        case 0.75...: "battery.100"
        case 0.5..<0.75: "battery.75"
        case 0.25..<0.5: "battery.50"
        default: "battery.25"
        }
    }

    var batteryColor: Color {
        if allocator.systemMetrics.isCharging { return .theaSuccess }
        let level = allocator.systemMetrics.batteryLevel
        return switch level {
        case 0.5...: .theaSuccess
        case 0.2..<0.5: .yellow
        default: .theaError
        }
    }

    func impactIcon(_ impact: DynamicResourceAllocator.ResourceRecommendation.ImpactLevel) -> String {
        switch impact {
        case .low: "info.circle"
        case .medium: "exclamationmark.triangle"
        case .high: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }

    func impactColor(_ impact: DynamicResourceAllocator.ResourceRecommendation.ImpactLevel) -> Color {
        switch impact {
        case .low: .theaInfo
        case .medium: .yellow
        case .high: .theaWarning
        case .critical: .theaError
        }
    }

    func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.0fK", Double(num) / 1000)
        }
        return "\(num)"
    }

    func saveConfiguration() {
        allocator.updateConfiguration(configuration)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResourceAllocationSettingsView()
    }
}
