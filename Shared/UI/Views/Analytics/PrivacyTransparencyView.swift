// PrivacyTransparencyView.swift
// Thea — Outbound Privacy Firewall Transparency Dashboard
//
// Surfaces real-time statistics from OutboundPrivacyGuard: channel registrations,
// audit statistics, firewall mode, and a rolling audit log excerpt.
// All data is fetched asynchronously from the actor-isolated guard.

import SwiftUI

// MARK: - Privacy Transparency View

struct PrivacyTransparencyView: View {
    @State private var stats: PrivacyAuditStatistics?
    @State private var recentEntries: [PrivacyAuditEntry] = []
    @State private var registeredChannels: [String] = []
    @State private var firewallMode: FirewallMode = .strict
    @State private var isEnabled: Bool = true
    @State private var isLoading = true
    @State private var refreshID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                if isLoading {
                    ProgressView("Loading privacy data…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    firewallStatusSection
                    if let s = stats { statsSection(s) }
                    channelsSection
                    auditLogSection
                }
            }
            .padding(20)
        }
        .navigationTitle("Privacy Transparency")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    refreshID = UUID()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task(id: refreshID) { await loadData() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Outbound Privacy Firewall")
                .font(.title2).bold()
            Text("Every piece of data leaving this device passes through this guard.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var firewallStatusSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isEnabled ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(isEnabled ? "Firewall Active" : "Firewall Disabled")
                        .font(.headline)
                }
                HStack(spacing: 6) {
                    Image(systemName: modeIcon(firewallMode))
                        .foregroundStyle(modeColor(firewallMode))
                    Text("Mode: \(firewallMode.rawValue.capitalized)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !isEnabled {
                Label("Warning: outbound data is unfiltered", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(isEnabled ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statsSection(_ s: PrivacyAuditStatistics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audit Statistics")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                PrivacyStatCard(value: "\(s.totalChecks)", label: "Total Checks", color: .blue, icon: "checkmark.seal.fill")
                PrivacyStatCard(value: "\(s.passed)", label: "Passed", color: .green, icon: "checkmark.circle.fill")
                PrivacyStatCard(value: "\(s.redacted)", label: "Redacted", color: .orange, icon: "pencil.slash")
                PrivacyStatCard(value: "\(s.blocked)", label: "Blocked", color: .red, icon: "xmark.shield.fill")
            }
            if s.totalChecks > 0 {
                let passRate = Double(s.passed) / Double(s.totalChecks)
                HStack {
                    Text("Pass rate: \(String(format: "%.1f%%", passRate * 100))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Total redactions applied: \(s.totalRedactions)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Registered Channels (\(registeredChannels.count))")
                .font(.headline)
            if registeredChannels.isEmpty {
                Text("No channels registered.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(registeredChannels, id: \.self) { channel in
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundStyle(.green)
                            .frame(width: 20)
                        Text(channel)
                            .font(.caption)
                            .fontDesign(.monospaced)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var auditLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Audit Log")
                    .font(.headline)
                Spacer()
                Text("Last \(recentEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if recentEntries.isEmpty {
                Text("No audit entries yet. Entries are created as data leaves the device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentEntries.reversed()) { entry in
                    AuditEntryRow(entry: entry)
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        let guard_ = OutboundPrivacyGuard.shared
        async let fetchStats = guard_.getPrivacyAuditStatistics()
        async let fetchLog = guard_.getAuditLog(limit: 30)
        async let fetchChannels = guard_.registeredChannelIds()
        async let fetchMode = guard_.mode
        async let fetchEnabled = guard_.isEnabled

        stats = await fetchStats
        recentEntries = await fetchLog
        registeredChannels = await fetchChannels
        firewallMode = await fetchMode
        isEnabled = await fetchEnabled
        isLoading = false
    }

    // MARK: - Helpers

    private func modeIcon(_ mode: FirewallMode) -> String {
        switch mode {
        case .strict:     "lock.shield.fill"
        case .standard:   "shield.fill"
        case .permissive: "shield.lefthalf.filled"
        }
    }

    private func modeColor(_ mode: FirewallMode) -> Color {
        switch mode {
        case .strict:     .blue
        case .standard:   .green
        case .permissive: .orange
        }
    }
}

// MARK: - Supporting Views

private struct PrivacyStatCard: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3).bold()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct AuditEntryRow: View {
    let entry: PrivacyAuditEntry
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: outcomeIcon)
                .foregroundStyle(outcomeColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.channel)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .bold()
                    Spacer()
                    Text(Self.formatter.localizedString(for: entry.timestamp, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(entry.outcome.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(outcomeColor)
                    if entry.redactionCount > 0 {
                        Text("· \(entry.redactionCount) redaction\(entry.redactionCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var outcomeIcon: String {
        switch entry.outcome {
        case .passed:   "checkmark.circle.fill"
        case .redacted: "pencil.slash"
        case .blocked:  "xmark.shield.fill"
        }
    }

    private var outcomeColor: Color {
        switch entry.outcome {
        case .passed:   .green
        case .redacted: .orange
        case .blocked:  .red
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        PrivacyTransparencyView()
    }
    .frame(width: 700, height: 600)
}
#endif
