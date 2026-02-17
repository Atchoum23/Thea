//
//  PrivacyTransparencyReportView.swift
//  Thea
//
//  Comprehensive privacy transparency report showing firewall activity,
//  network traffic analysis, blocklist effectiveness, and recommendations.
//

import SwiftUI

/// Aggregated privacy transparency report combining firewall, network, and
/// blocklist statistics with a computed privacy score and actionable recommendations.
struct PrivacyTransparencyReportView: View {
    @State var firewallStats: (total: Int, passed: Int, redacted: Int, blocked: Int) = (0, 0, 0, 0)
    @State var networkStats: (total: Int, blocked: Int, concerns: Int, dailyBytes: Int) = (0, 0, 0, 0)
    @State var blocklistStats: DNSBlocklistService.BlocklistStats?
    @State var topDomains: [(domain: String, count: Int)] = []
    @State var trafficByCategory: [(category: NetworkPrivacyMonitor.TrafficCategory, count: Int)] = []
    @State var serviceStats: [NetworkPrivacyMonitor.ServiceStats] = []
    @State var dailySnapshots: [NetworkPrivacyMonitor.DailySnapshot] = []
    @State var monthlyReports: [NetworkPrivacyMonitor.MonthlyTransparencyReport] = []
    @State var channelCount = 0
    @State var firewallMode = ""
    @State var showingExportSheet = false
    @State var exportJSON: Data?

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
    var summarySection: some View {
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
    var privacyScoreBadge: some View {
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
    var firewallReportSection: some View {
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
    var networkReportSection: some View {
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
}
