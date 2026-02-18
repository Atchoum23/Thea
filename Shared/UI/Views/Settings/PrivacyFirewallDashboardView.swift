//
//  PrivacyFirewallDashboardView.swift
//  Thea
//
//  Privacy Firewall Dashboard: transparency report, network monitor,
//  DNS blocklist manager, and audit detail views.
//

import SwiftUI

// MARK: - Network Activity Monitor

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
                    .fill(isMonitoring ? Color.green : Color.red)
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
                metricCard(label: "Total", value: "\(totalConnections)", icon: "network", color: .blue)
                metricCard(label: "Blocked", value: "\(blockedCount)", icon: "xmark.shield", color: .red)
                metricCard(label: "Concerns", value: "\(privacyConcernCount)", icon: "exclamationmark.triangle", color: .orange)
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
                            .foregroundStyle(item.category.isPrivacyConcern ? .red : Color.theaPrimaryDefault)
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
                            .foregroundStyle(record.wasBlocked ? .red : (record.category.isPrivacyConcern ? .orange : .secondary))
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
                                        .foregroundStyle(.red)
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


// MARK: - Privacy Transparency Report

struct PrivacyTransparencyReportView: View {
    @State private var firewallStats: (total: Int, passed: Int, redacted: Int, blocked: Int) = (0, 0, 0, 0)
    @State private var networkStats: (total: Int, blocked: Int, concerns: Int, dailyBytes: Int) = (0, 0, 0, 0)
    @State private var blocklistStats: DNSBlocklistService.BlocklistStats?
    @State private var topDomains: [(domain: String, count: Int)] = []
    @State private var trafficByCategory: [(category: NetworkPrivacyMonitor.TrafficCategory, count: Int)] = []
    @State private var serviceStats: [NetworkPrivacyMonitor.ServiceStats] = []
    @State private var dailySnapshots: [NetworkPrivacyMonitor.DailySnapshot] = []
    @State private var monthlyReports: [NetworkPrivacyMonitor.MonthlyTransparencyReport] = []
    @State private var channelCount = 0
    @State private var firewallMode = ""
    @State private var showingExportSheet = false
    @State private var exportJSON: Data?

    var body: some View {
        Form {
            summarySection
            serviceBreakdownSection
            firewallReportSection
            networkReportSection
            blocklistReportSection
            monthlyReportsSection
            historySection
            recommendationsSection
            exportSection
        }
        .formStyle(.grouped)
        .navigationTitle("Transparency Report")
        .task { await loadAllData() }
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        Section {
            VStack(spacing: TheaSpacing.md) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(Color.theaPrimaryDefault)
                    VStack(alignment: .leading) {
                        Text("Privacy Transparency Report")
                            .font(.theaTitle3)
                        Text("Generated \(Date(), style: .date)")
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    privacyScoreBadge
                }

                Text("This report shows what data Thea has sent externally, what was blocked, and recommendations for improving your privacy posture.")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var privacyScoreBadge: some View {
        let score = computePrivacyScore()
        VStack(spacing: 2) {
            Text("\(score)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(score >= 80 ? .green : score >= 50 ? .orange : .red)
            Text("/ 100")
                .font(.theaCaption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60)
    }

    // MARK: - Firewall Report

    @ViewBuilder
    private var firewallReportSection: some View {
        Section("Outbound Firewall") {
            LabeledContent("Mode", value: firewallMode.isEmpty ? "Unknown" : firewallMode.capitalized)
            LabeledContent("Registered Channels", value: "\(channelCount)")

            HStack(spacing: TheaSpacing.lg) {
                VStack(spacing: 2) {
                    Text("\(firewallStats.passed)")
                        .font(.theaTitle3)
                        .foregroundStyle(.green)
                    Text("Passed")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("\(firewallStats.redacted)")
                        .font(.theaTitle3)
                        .foregroundStyle(.orange)
                    Text("Redacted")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("\(firewallStats.blocked)")
                        .font(.theaTitle3)
                        .foregroundStyle(.red)
                    Text("Blocked")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if firewallStats.total > 0 {
                let passRate = Double(firewallStats.passed) / Double(firewallStats.total) * 100
                LabeledContent("Pass Rate", value: String(format: "%.1f%%", passRate))
            }
        }
    }

    // MARK: - Network Report

    @ViewBuilder
    private var networkReportSection: some View {
        Section("Network Traffic") {
            LabeledContent("Total Connections", value: "\(networkStats.total)")
            LabeledContent("Blocked Connections", value: "\(networkStats.blocked)")
            LabeledContent("Privacy Concerns", value: "\(networkStats.concerns)")

            if !topDomains.isEmpty {
                Divider()
                Text("Top Contacted Domains")
                    .font(.theaSubhead)
                    .foregroundStyle(.secondary)

                ForEach(topDomains.prefix(5), id: \.domain) { item in
                    HStack {
                        Text(item.domain)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !trafficByCategory.isEmpty {
                Divider()
                Text("Connections by Category")
                    .font(.theaSubhead)
                    .foregroundStyle(.secondary)

                ForEach(trafficByCategory, id: \.category) { item in
                    HStack {
                        Image(systemName: item.category.sfSymbol)
                            .foregroundStyle(item.category.isPrivacyConcern ? .red : .secondary)
                            .frame(width: 20)
                        Text(item.category.rawValue)
                        Spacer()
                        Text("\(item.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Blocklist Report

    @ViewBuilder
    private var blocklistReportSection: some View {
        if let stats = blocklistStats {
            Section("DNS Blocklist") {
                LabeledContent("Total Domains", value: "\(stats.totalDomains)")
                LabeledContent("Active Domains", value: "\(stats.enabledDomains)")
                LabeledContent("Blocked Today", value: "\(stats.blockedToday)")
                LabeledContent("Blocked All Time", value: "\(stats.blockedAllTime)")
            }
        }
    }

    // MARK: - Service Breakdown

    @ViewBuilder
    private var serviceBreakdownSection: some View {
        if !serviceStats.isEmpty {
            Section("Data by Service") {
                ForEach(serviceStats, id: \.service) { stats in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stats.service)
                                .font(.theaSubhead)
                            Text("\(stats.connectionCount) connections")
                                .font(.theaCaption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatBytes(stats.bytesEstimate))
                                .font(.subheadline.monospacedDigit())
                            if stats.blockedCount > 0 {
                                Text("\(stats.blockedCount) blocked")
                                    .font(.theaCaption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        if !dailySnapshots.isEmpty {
            Section("Daily History (last \(dailySnapshots.count) days)") {
                ForEach(dailySnapshots.suffix(7).reversed(), id: \.date) { snapshot in
                    HStack {
                        Text(snapshot.date)
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                        Text("\(snapshot.totalConnections) conn")
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                        Text(formatBytes(snapshot.totalBytes))
                            .font(.theaCaption1)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .trailing)
                        if snapshot.blockedConnections > 0 {
                            Text("\(snapshot.blockedConnections) blocked")
                                .font(.theaCaption2)
                                .foregroundStyle(.red)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Monthly Reports

    @ViewBuilder
    private var monthlyReportsSection: some View {
        Section("Monthly Reports") {
            if monthlyReports.isEmpty {
                Label("No monthly reports yet. Reports are auto-generated on the first app launch each month.",
                      systemImage: "calendar.badge.clock")
                    .font(.theaCaption1)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(monthlyReports.reversed(), id: \.id) { report in
                    VStack(alignment: .leading, spacing: TheaSpacing.xs) {
                        HStack {
                            Text(report.generatedAt, style: .date)
                                .font(.theaSubhead)
                            Spacer()
                            Text("Score: \(report.privacyScore)/100")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(report.privacyScore >= 80 ? .green : report.privacyScore >= 50 ? .orange : .red)
                        }
                        HStack(spacing: TheaSpacing.md) {
                            Label("\(report.totalConnections)", systemImage: "arrow.up.forward")
                                .font(.theaCaption2)
                            Label("\(report.blockedConnections)", systemImage: "hand.raised.fill")
                                .font(.theaCaption2)
                                .foregroundStyle(.red)
                            if report.privacyConcerns > 0 {
                                Label("\(report.privacyConcerns)", systemImage: "exclamationmark.triangle")
                                    .font(.theaCaption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        if !report.recommendations.isEmpty {
                            Text(report.recommendations.first ?? "")
                                .font(.theaCaption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Button {
                Task {
                    if let report = await NetworkPrivacyMonitor.shared.generateMonthlyReportIfDue() {
                        monthlyReports.append(report)
                    } else {
                        // Force generate for manual trigger
                        let reports = await NetworkPrivacyMonitor.shared.loadMonthlyReports()
                        monthlyReports = reports
                    }
                }
            } label: {
                Label("Generate Report Now", systemImage: "doc.badge.plus")
            }
        }
    }

    // MARK: - Export

    @ViewBuilder
    private var exportSection: some View {
        Section("Export Report") {
            Button {
                Task {
                    exportJSON = await NetworkPrivacyMonitor.shared.exportReportAsJSON()
                    showingExportSheet = true
                }
            } label: {
                Label("Export as JSON", systemImage: "doc.text")
            }

            Button {
                Task {
                    let csv = await NetworkPrivacyMonitor.shared.exportReportAsCSV()
                    if let data = csv.data(using: .utf8) {
                        exportJSON = data
                        showingExportSheet = true
                    }
                }
            } label: {
                Label("Export as CSV", systemImage: "tablecells")
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let data = exportJSON {
                ExportDataSheet(data: data)
            }
        }
    }

    // MARK: - Recommendations

    @ViewBuilder
    private var recommendationsSection: some View {
        Section("Recommendations") {
            if firewallMode != "strict" {
                Label("Enable strict firewall mode for maximum privacy protection", systemImage: "shield.checkered")
                    .font(.theaCaption1)
                    .foregroundStyle(.orange)
            }

            if networkStats.concerns > 0 {
                Label("\(networkStats.concerns) privacy-concerning connections detected. Review network activity.", systemImage: "exclamationmark.triangle")
                    .font(.theaCaption1)
                    .foregroundStyle(.orange)
            }

            if (blocklistStats?.enabledDomains ?? 0) < 20 {
                Label("Consider enabling more blocklist entries for better tracker protection", systemImage: "hand.raised")
                    .font(.theaCaption1)
                    .foregroundStyle(.orange)
            }

            let score = computePrivacyScore()
            if score >= 80 {
                Label("Your privacy posture is strong. Keep it up!", systemImage: "checkmark.seal.fill")
                    .font(.theaCaption1)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Helpers

    private func computePrivacyScore() -> Int {
        var score = 50

        // Firewall mode bonus
        switch firewallMode {
        case "strict": score += 20
        case "standard": score += 10
        default: break
        }

        // Low privacy concerns bonus
        if networkStats.total > 0 {
            let concernRatio = Double(networkStats.concerns) / Double(networkStats.total)
            if concernRatio < 0.05 { score += 15 }
            else if concernRatio < 0.15 { score += 10 }
            else if concernRatio < 0.30 { score += 5 }
        } else {
            score += 10
        }

        // Blocklist active bonus
        if let stats = blocklistStats, stats.enabledDomains >= 30 {
            score += 10
        }

        // Channel registration bonus
        if channelCount >= 5 {
            score += 5
        }

        return min(score, 100)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    private func loadAllData() async {
        // Firewall stats
        let auditStats = await OutboundPrivacyGuard.shared.getPrivacyAuditStatistics()
        firewallStats = (auditStats.totalChecks, auditStats.passed, auditStats.redacted, auditStats.blocked)
        channelCount = await OutboundPrivacyGuard.shared.registeredChannelIds().count
        let mode = await OutboundPrivacyGuard.shared.mode
        firewallMode = mode.rawValue

        // Network stats
        let total = await NetworkPrivacyMonitor.shared.getTotalConnections()
        let blocked = await NetworkPrivacyMonitor.shared.getBlockedTrafficCount()
        let concerns = await NetworkPrivacyMonitor.shared.getPrivacyConcernCount()
        let daily = await NetworkPrivacyMonitor.shared.getDailyTrafficBytes()
        networkStats = (total, blocked, concerns, daily)
        topDomains = await NetworkPrivacyMonitor.shared.getTopDomains(limit: 5)
        trafficByCategory = await NetworkPrivacyMonitor.shared.getTrafficByCategory()

        // Per-service stats
        serviceStats = await NetworkPrivacyMonitor.shared.getServiceStats()

        // Daily history
        await NetworkPrivacyMonitor.shared.loadDailySnapshots()
        dailySnapshots = await NetworkPrivacyMonitor.shared.getDailySnapshots()

        // Blocklist stats
        blocklistStats = await DNSBlocklistService.shared.getStats()

        // Monthly reports
        monthlyReports = await NetworkPrivacyMonitor.shared.loadMonthlyReports()
    }
}

// MARK: - Export Data Sheet

private struct ExportDataSheet: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let text = String(data: data, encoding: .utf8) {
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                } else {
                    Text("Binary data (\(data.count) bytes)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Export Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: dataAsTransferable, preview: SharePreview("Privacy Report")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var dataAsTransferable: String {
        String(data: data, encoding: .utf8) ?? ""
    }
}
// FirewallAuditDetailView is defined in FirewallAuditDetailView.swift
