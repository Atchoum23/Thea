//
//  NetworkActivityMonitorView.swift
//  Thea
//
//  Displays real-time network traffic monitoring with category breakdown,
//  top domains, and recent activity log.
//

import SwiftUI

/// Real-time network activity monitor showing traffic statistics,
/// category breakdowns, top contacted domains, and a scrollable activity log.
struct NetworkActivityMonitorView: View {
    @State private var recentTraffic: [NetworkPrivacyMonitor.TrafficRecord] = []
    @State private var trafficByCategory: [(category: NetworkPrivacyMonitor.TrafficCategory, count: Int)] = []
    @State private var topDomains: [(domain: String, count: Int)] = []
    @State private var totalConnections = 0
    @State private var blockedCount = 0
    @State private var privacyConcernCount = 0
    @State private var dailyBytes = 0
    @State private var isMonitoring = false
    @State private var selectedCategory: NetworkPrivacyMonitor.TrafficCategory?
    @State private var refreshTimer: Timer?

    var body: some View {
        Form {
            monitoringSection
            overviewSection
            categoryBreakdownSection
            topDomainsSection
            recentTrafficSection
        }
        .formStyle(.grouped)
        .navigationTitle("Network Activity")
        .task { await loadData() }
        .onDisappear { refreshTimer?.invalidate() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var monitoringSection: some View {
        Section {
            HStack {
                Circle()
                    .fill(isMonitoring ? Color.theaSuccess : Color.theaError)
                    .frame(width: 8, height: 8)
                Text(isMonitoring ? "Monitoring Active" : "Monitoring Inactive")
                    .font(.theaSubhead)
                Spacer()
                Button(isMonitoring ? "Stop" : "Start") {
                    Task {
                        if isMonitoring {
                            await NetworkPrivacyMonitor.shared.stopMonitoring()
                        } else {
                            await NetworkPrivacyMonitor.shared.startMonitoring()
                        }
                        isMonitoring = await NetworkPrivacyMonitor.shared.isMonitoring
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var overviewSection: some View {
        Section("Overview") {
            HStack(spacing: TheaSpacing.lg) {
                metricCard(label: "Total", value: "\(totalConnections)", icon: "network", color: .theaInfo)
                metricCard(label: "Blocked", value: "\(blockedCount)", icon: "xmark.shield", color: .theaError)
                metricCard(label: "Concerns", value: "\(privacyConcernCount)", icon: "exclamationmark.triangle", color: .theaWarning)
                metricCard(label: "Today", value: formatBytes(dailyBytes), icon: "arrow.up.arrow.down", color: .purple)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var categoryBreakdownSection: some View {
        Section("Traffic by Category") {
            if trafficByCategory.isEmpty {
                Text("No traffic recorded yet")
                    .foregroundStyle(.secondary)
                    .font(.theaCaption1)
            } else {
                ForEach(trafficByCategory, id: \.category) { item in
                    HStack {
                        Image(systemName: item.category.sfSymbol)
                            .foregroundStyle(item.category.isPrivacyConcern ? Color.theaError : Color.theaPrimaryDefault)
                            .frame(width: 24)
                        Text(item.category.rawValue)
                            .font(.theaBody)
                        Spacer()
                        Text("\(item.count)")
                            .font(.theaSubhead)
                            .foregroundStyle(.secondary)

                        let total = max(totalConnections, 1)
                        let pct = Double(item.count) / Double(total) * 100
                        Text("\(Int(pct))%")
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var topDomainsSection: some View {
        Section("Top Domains") {
            if topDomains.isEmpty {
                Text("No domains recorded yet")
                    .foregroundStyle(.secondary)
                    .font(.theaCaption1)
            } else {
                ForEach(topDomains, id: \.domain) { item in
                    HStack {
                        Text(item.domain)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.count) requests")
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentTrafficSection: some View {
        Section("Recent Activity (\(recentTraffic.count))") {
            if recentTraffic.isEmpty {
                Text("No recent activity")
                    .foregroundStyle(.secondary)
                    .font(.theaCaption1)
            } else {
                ForEach(recentTraffic.prefix(50)) { record in
                    HStack {
                        Image(systemName: record.wasBlocked ? "xmark.circle.fill" : record.category.sfSymbol)
                            .foregroundStyle(record.wasBlocked ? Color.theaError : (record.category.isPrivacyConcern ? Color.theaWarning : .secondary))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.hostname)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                            HStack(spacing: TheaSpacing.xs) {
                                Text(record.category.rawValue)
                                    .font(.theaCaption2)
                                    .foregroundStyle(.secondary)
                                if record.wasBlocked, let reason = record.blockReason {
                                    Text("— \(reason)")
                                        .font(.theaCaption2)
                                        .foregroundStyle(Color.theaError)
                                }
                            }
                        }
                        Spacer()
                        Text(record.timestamp, style: .time)
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !recentTraffic.isEmpty {
                Button("Clear Activity Log") {
                    Task {
                        await NetworkPrivacyMonitor.shared.clearLog()
                        await loadData()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func metricCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.theaTitle3)
                .foregroundStyle(color)
            Text(label)
                .font(.theaCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    private func loadData() async {
        isMonitoring = await NetworkPrivacyMonitor.shared.isMonitoring
        recentTraffic = await NetworkPrivacyMonitor.shared.getRecentTraffic(limit: 50)
        trafficByCategory = await NetworkPrivacyMonitor.shared.getTrafficByCategory()
        topDomains = await NetworkPrivacyMonitor.shared.getTopDomains(limit: 10)
        totalConnections = await NetworkPrivacyMonitor.shared.getTotalConnections()
        blockedCount = await NetworkPrivacyMonitor.shared.getBlockedTrafficCount()
        privacyConcernCount = await NetworkPrivacyMonitor.shared.getPrivacyConcernCount()
        dailyBytes = await NetworkPrivacyMonitor.shared.getDailyTrafficBytes()
    }
}
