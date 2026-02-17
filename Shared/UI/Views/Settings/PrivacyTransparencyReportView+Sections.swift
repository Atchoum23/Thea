//
//  PrivacyTransparencyReportView+Sections.swift
//  Thea
//
//  Extended sections for the privacy transparency report: blocklist,
//  service breakdown, history, monthly reports, export, recommendations,
//  and the privacy score computation.
//

import SwiftUI

// MARK: - Additional Report Sections

extension PrivacyTransparencyReportView {

    // MARK: - Blocklist Report

    @ViewBuilder
    var blocklistReportSection: some View {
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
    var serviceBreakdownSection: some View {
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
    var historySection: some View {
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
    var monthlyReportsSection: some View {
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
    var exportSection: some View {
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
    var recommendationsSection: some View {
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

    /// Computes an overall privacy score (0-100) based on firewall mode,
    /// concern ratio, blocklist coverage, and channel registration count.
    func computePrivacyScore() -> Int {
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

    /// Formats a byte count into a human-readable string (B, KB, or MB).
    func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    /// Loads all data sources needed for the transparency report.
    func loadAllData() async {
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

/// Modal sheet for previewing and sharing exported privacy report data.
struct ExportDataSheet: View {
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
