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

// MARK: - DNS Blocklist Manager

struct DNSBlocklistManagerView: View {
    @State private var entries: [DNSBlocklistService.BlocklistEntry] = []
    @State private var stats: DNSBlocklistService.BlocklistStats?
    @State private var isEnabled = true
    @State private var selectedCategory: DNSBlocklistService.BlockCategory?
    @State private var newDomain = ""
    @State private var newCategory: DNSBlocklistService.BlockCategory = .custom
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            statusSection
            statsSection
            addDomainSection
            entriesSection
        }
        .formStyle(.grouped)
        .navigationTitle("DNS Blocklist")
        .task { await loadData() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var statusSection: some View {
        Section {
            Toggle("Blocklist Active", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, newValue in
                    Task { await DNSBlocklistService.shared.setEnabled(newValue) }
                }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        if let stats {
            Section("Statistics") {
                HStack(spacing: TheaSpacing.lg) {
                    VStack(spacing: 2) {
                        Text("\(stats.totalDomains)")
                            .font(.theaTitle2)
                            .foregroundStyle(Color.theaPrimaryDefault)
                        Text("Domains")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("\(stats.enabledDomains)")
                            .font(.theaTitle2)
                            .foregroundStyle(Color.theaSuccess)
                        Text("Active")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("\(stats.blockedToday)")
                            .font(.theaTitle2)
                            .foregroundStyle(Color.theaWarning)
                        Text("Today")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("\(stats.blockedAllTime)")
                            .font(.theaTitle2)
                            .foregroundStyle(Color.theaError)
                        Text("All Time")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Per-category counts
                ForEach(DNSBlocklistService.BlockCategory.allCases, id: \.self) { category in
                    let count = stats.byCategory[category] ?? 0
                    if count > 0 {
                        HStack {
                            Image(systemName: category.sfSymbol)
                                .foregroundStyle(Color.theaPrimaryDefault)
                                .frame(width: 24)
                            Text(category.rawValue)
                            Spacer()
                            Text("\(count) domains")
                                .foregroundStyle(.secondary)
                                .font(.theaCaption1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var addDomainSection: some View {
        Section("Add Custom Domain") {
            HStack {
                TextField("example.com", text: $newDomain)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $newCategory) {
                    ForEach(DNSBlocklistService.BlockCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .frame(width: 140)

                Button("Add") {
                    guard !newDomain.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task {
                        await DNSBlocklistService.shared.addDomain(newDomain.trimmingCharacters(in: .whitespaces), category: newCategory)
                        newDomain = ""
                        await loadData()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        Section("Category Filter") {
            Picker("Filter", selection: $selectedCategory) {
                Text("All").tag(nil as DNSBlocklistService.BlockCategory?)
                ForEach(DNSBlocklistService.BlockCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat as DNSBlocklistService.BlockCategory?)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedCategory) { _, _ in
                Task { await loadData() }
            }
        }

        let filteredEntries = selectedCategory == nil ? entries : entries.filter { $0.category == selectedCategory }

        Section("Blocked Domains (\(filteredEntries.count))") {
            if filteredEntries.isEmpty {
                Text("No entries in this category")
                    .foregroundStyle(.secondary)
                    .font(.theaCaption1)
            } else {
                ForEach(filteredEntries) { entry in
                    HStack {
                        Image(systemName: entry.category.sfSymbol)
                            .foregroundStyle(entry.isEnabled ? Color.theaPrimaryDefault : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.domain)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                            HStack(spacing: TheaSpacing.xs) {
                                Text(entry.category.rawValue)
                                Text("·")
                                Text(entry.source.rawValue)
                            }
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { entry.isEnabled },
                            set: { newValue in
                                Task {
                                    await DNSBlocklistService.shared.toggleDomain(entry.domain, enabled: newValue)
                                    await loadData()
                                }
                            }
                        ))
                        .labelsHidden()

                        if entry.source == .user {
                            Button(role: .destructive) {
                                Task {
                                    await DNSBlocklistService.shared.removeDomain(entry.domain)
                                    await loadData()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func loadData() async {
        isEnabled = await DNSBlocklistService.shared.isEnabled
        stats = await DNSBlocklistService.shared.getStats()
        entries = await DNSBlocklistService.shared.getEntries(category: selectedCategory)
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
                .foregroundStyle(score >= 80 ? Color.theaSuccess : score >= 50 ? Color.theaWarning : Color.theaError)
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
                        .foregroundStyle(Color.theaSuccess)
                    Text("Passed")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("\(firewallStats.redacted)")
                        .font(.theaTitle3)
                        .foregroundStyle(Color.theaWarning)
                    Text("Redacted")
                        .font(.theaCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("\(firewallStats.blocked)")
                        .font(.theaTitle3)
                        .foregroundStyle(Color.theaError)
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
                            .foregroundStyle(item.category.isPrivacyConcern ? Color.theaError : .secondary)
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
                                    .foregroundStyle(Color.theaError)
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
                                .foregroundStyle(Color.theaError)
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
                                .foregroundStyle(report.privacyScore >= 80 ? Color.theaSuccess : report.privacyScore >= 50 ? Color.theaWarning : Color.theaError)
                        }
                        HStack(spacing: TheaSpacing.md) {
                            Label("\(report.totalConnections)", systemImage: "arrow.up.forward")
                                .font(.theaCaption2)
                            Label("\(report.blockedConnections)", systemImage: "hand.raised.fill")
                                .font(.theaCaption2)
                                .foregroundStyle(Color.theaError)
                            if report.privacyConcerns > 0 {
                                Label("\(report.privacyConcerns)", systemImage: "exclamationmark.triangle")
                                    .font(.theaCaption2)
                                    .foregroundStyle(Color.theaWarning)
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
                    .foregroundStyle(Color.theaWarning)
            }

            if networkStats.concerns > 0 {
                Label("\(networkStats.concerns) privacy-concerning connections detected. Review network activity.", systemImage: "exclamationmark.triangle")
                    .font(.theaCaption1)
                    .foregroundStyle(Color.theaWarning)
            }

            if (blocklistStats?.enabledDomains ?? 0) < 20 {
                Label("Consider enabling more blocklist entries for better tracker protection", systemImage: "hand.raised")
                    .font(.theaCaption1)
                    .foregroundStyle(Color.theaWarning)
            }

            let score = computePrivacyScore()
            if score >= 80 {
                Label("Your privacy posture is strong. Keep it up!", systemImage: "checkmark.seal.fill")
                    .font(.theaCaption1)
                    .foregroundStyle(Color.theaSuccess)
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
            if concernRatio < 0.05 { score += 15 } else if concernRatio < 0.15 { score += 10 } else if concernRatio < 0.30 { score += 5 }
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

// MARK: - Firewall Audit Detail View

struct FirewallAuditDetailView: View {
    @State private var auditEntries: [PrivacyAuditEntry] = []
    @State private var stats: PrivacyAuditStatistics?

    var body: some View {
        Form {
            if let stats {
                Section("Summary") {
                    HStack(spacing: TheaSpacing.lg) {
                        VStack(spacing: 2) {
                            Text("\(stats.totalChecks)")
                                .font(.theaTitle2)
                            Text("Total")
                                .font(.theaCaption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("\(stats.passed)")
                                .font(.theaTitle2)
                                .foregroundStyle(Color.theaSuccess)
                            Text("Passed")
                                .font(.theaCaption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("\(stats.redacted)")
                                .font(.theaTitle2)
                                .foregroundStyle(Color.theaWarning)
                            Text("Redacted")
                                .font(.theaCaption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 2) {
                            Text("\(stats.blocked)")
                                .font(.theaTitle2)
                                .foregroundStyle(Color.theaError)
                            Text("Blocked")
                                .font(.theaCaption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Section("Recent Audit Entries (\(auditEntries.count))") {
                if auditEntries.isEmpty {
                    Text("No audit entries recorded")
                        .foregroundStyle(.secondary)
                        .font(.theaCaption1)
                } else {
                    ForEach(auditEntries) { entry in
                        HStack {
                            Image(systemName: iconForOutcome(entry.outcome))
                                .foregroundStyle(colorForOutcome(entry.outcome))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.channel)
                                    .font(.theaSubhead)
                                HStack(spacing: TheaSpacing.xs) {
                                    Text(entry.outcome.rawValue.capitalized)
                                        .font(.theaCaption2)
                                        .foregroundStyle(colorForOutcome(entry.outcome))
                                    if entry.redactionCount > 0 {
                                        Text("— \(entry.redactionCount) redactions")
                                            .font(.theaCaption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Text(entry.timestamp, style: .time)
                                .font(.theaCaption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if !auditEntries.isEmpty {
                Section {
                    Button("Clear Audit Log") {
                        Task {
                            await OutboundPrivacyGuard.shared.clearAuditLog()
                            await loadData()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Firewall Audit Log")
        .task { await loadData() }
    }

    private func iconForOutcome(_ outcome: PrivacyAuditEntry.AuditOutcome) -> String {
        switch outcome {
        case .passed: "checkmark.circle.fill"
        case .redacted: "pencil.circle.fill"
        case .blocked: "xmark.circle.fill"
        }
    }

    private func colorForOutcome(_ outcome: PrivacyAuditEntry.AuditOutcome) -> Color {
        switch outcome {
        case .passed: .theaSuccess
        case .redacted: .theaWarning
        case .blocked: .theaError
        }
    }

    private func loadData() async {
        auditEntries = await OutboundPrivacyGuard.shared.getAuditLog(limit: 100)
        stats = await OutboundPrivacyGuard.shared.getPrivacyAuditStatistics()
    }
}
