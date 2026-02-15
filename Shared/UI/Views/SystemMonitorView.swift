// SystemMonitorView.swift
// Thea — System monitoring dashboard
// Replaces: iStat Menus

import SwiftUI

struct SystemMonitorView: View {
    @StateObject private var monitor = SystemMonitor.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with uptime and thermal
                headerSection

                // Key metrics grid
                metricsGrid

                // Anomalies
                if !monitor.anomalies.isEmpty {
                    anomalySection
                }

                // Controls
                controlsSection
            }
            .padding()
        }
        .navigationTitle("System Monitor")
        .task {
            if monitor.latestSnapshot == nil {
                await monitor.captureSnapshot()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Status")
                    .font(.headline)
                if let snap = monitor.latestSnapshot {
                    HStack(spacing: 8) {
                        Image(systemName: snap.thermal.icon)
                            .foregroundStyle(thermalColor(snap.thermal))
                        Text(snap.thermal.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("Uptime: \(monitor.formattedUptime)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if monitor.isMonitoring {
                Label("Live", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            if let snap = monitor.latestSnapshot {
                MetricCard(
                    title: "CPU",
                    value: String(format: "%.0f%%", snap.cpu.totalUsage),
                    detail: "\(snap.cpu.coreCount) cores (\(snap.cpu.activeProcessors) active)",
                    icon: "cpu",
                    percent: snap.cpu.totalUsage / 100,
                    color: gaugeColor(snap.cpu.totalUsage, warning: monitor.thresholds.cpuWarning, critical: monitor.thresholds.cpuCritical)
                )

                MetricCard(
                    title: "Memory",
                    value: String(format: "%.0f%%", snap.memory.usagePercent),
                    detail: "\(snap.memory.formattedUsed) / \(snap.memory.formattedTotal)",
                    icon: "memorychip",
                    percent: snap.memory.usagePercent / 100,
                    color: gaugeColor(snap.memory.usagePercent, warning: monitor.thresholds.memoryWarning, critical: monitor.thresholds.memoryCritical)
                )

                MetricCard(
                    title: "Disk",
                    value: String(format: "%.0f%%", snap.disk.usagePercent),
                    detail: "\(snap.disk.formattedAvailable) available",
                    icon: "internaldrive",
                    percent: snap.disk.usagePercent / 100,
                    color: gaugeColor(snap.disk.usagePercent, warning: monitor.thresholds.diskWarning, critical: monitor.thresholds.diskCritical)
                )

                MetricCard(
                    title: "Network",
                    value: "↓ \(snap.network.formattedBytesIn)",
                    detail: "↑ \(snap.network.formattedBytesOut)",
                    icon: "network",
                    percent: nil,
                    color: .blue
                )
            }
        }
    }

    // MARK: - Anomalies

    private var anomalySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Alerts")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    monitor.anomalies.removeAll()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            ForEach(monitor.anomalies.suffix(5)) { anomaly in
                HStack(spacing: 8) {
                    Image(systemName: anomaly.severity.icon)
                        .foregroundStyle(severityColor(anomaly.severity))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(anomaly.message)
                            .font(.caption)
                        Text(anomaly.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.theaSurface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack {
            Button {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    monitor.startMonitoring()
                }
            } label: {
                Label(
                    monitor.isMonitoring ? "Stop Monitoring" : "Start Live Monitoring",
                    systemImage: monitor.isMonitoring ? "stop.circle" : "play.circle"
                )
            }
            .buttonStyle(.bordered)

            Button {
                Task { await monitor.captureSnapshot() }
            } label: {
                Label("Refresh Now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Spacer()

            if let snap = monitor.latestSnapshot {
                Text("Last updated: \(snap.timestamp, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func gaugeColor(_ value: Double, warning: Double, critical: Double) -> Color {
        if value >= critical { return .red }
        if value >= warning { return .orange }
        return .green
    }

    private func thermalColor(_ state: ThermalState) -> Color {
        switch state {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }

    private func severityColor(_ severity: AnomalySeverity) -> Color {
        switch severity {
        case .info: .blue
        case .warning: .orange
        case .critical: .red
        }
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let percent: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            if let pct = percent {
                ProgressView(value: min(pct, 1.0))
                    .tint(color)
            }

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color.theaSurface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(detail)")
    }
}

#Preview("System Monitor") {
    SystemMonitorView()
        .frame(width: 500, height: 600)
}
