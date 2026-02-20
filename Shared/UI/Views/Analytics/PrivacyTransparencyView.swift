// PrivacyTransparencyView.swift
// Thea
//
// V3-2: Audit log of blocked/redacted outbound data, PII masking stats.
// Uses OutboundPrivacyGuard (actor) — fetches data asynchronously in .task{}.

import SwiftUI

// MARK: - Privacy Transparency View

struct PrivacyTransparencyView: View {
    @State private var stats: PrivacyAuditStatistics?
    @State private var auditLog: [PrivacyAuditEntry] = []
    @State private var isLoading = true
    @State private var isEnabled = false
    @State private var mode = FirewallMode.standard

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading privacy data…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .navigationTitle("Privacy Transparency")
        #if os(macOS)
        .padding()
        #endif
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    // MARK: - Content

    private var content: some View {
        List {
            // Guard status
            Section("Outbound Firewall") {
                LabeledContent("Status") {
                    Label(isEnabled ? "Active" : "Disabled",
                          systemImage: isEnabled ? "checkmark.shield.fill" : "xmark.shield")
                        .foregroundStyle(isEnabled ? .green : .secondary)
                }
                LabeledContent("Mode", value: mode.rawValue.capitalized)
            }

            // Stats overview
            if let stats {
                Section("Statistics (All Time)") {
                    statRow("Total Checks", value: stats.totalChecks, color: .primary)
                    statRow("Passed", value: stats.passed, color: .green)
                    statRow("Redacted", value: stats.redacted, color: .orange)
                    statRow("Blocked", value: stats.blocked, color: .red)
                    statRow("Total Redactions Applied", value: stats.totalRedactions, color: .orange)
                }
            }

            // Audit log
            Section("Recent Audit Log (\(auditLog.count))") {
                if auditLog.isEmpty {
                    Text("No audit entries yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(auditLog) { entry in
                        PrivacyAuditRow(entry: entry)
                    }
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.grouped)
        #endif
    }

    // MARK: - Helpers

    private func statRow(_ label: String, value: Int, color: Color) -> some View {
        LabeledContent(label) {
            Text("\(value)")
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private func loadData() async {
        isLoading = true
        let guard_ = OutboundPrivacyGuard.shared
        async let statsResult = guard_.getPrivacyAuditStatistics()
        async let logResult = guard_.getAuditLog(limit: 50)
        async let enabledResult = guard_.isEnabled
        async let modeResult = guard_.mode
        stats = await statsResult
        auditLog = await logResult
        isEnabled = await enabledResult
        mode = await modeResult
        isLoading = false
    }
}

// MARK: - Privacy Audit Row

struct PrivacyAuditRow: View {
    let entry: PrivacyAuditEntry

    var body: some View {
        HStack(alignment: .top, spacing: TheaSpacing.sm) {
            Image(systemName: outcomeIcon)
                .foregroundStyle(outcomeColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.channel)
                    .font(.theaBody.weight(.medium))
                HStack(spacing: TheaSpacing.sm) {
                    Text(entry.policyName)
                        .font(.theaCaption1)
                        .foregroundStyle(.secondary)
                    if entry.redactionCount > 0 {
                        Text("(\(entry.redactionCount) redactions)")
                            .font(.theaCaption1)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            Text(entry.timestamp, style: .relative)
                .font(.theaCaption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var outcomeIcon: String {
        switch entry.outcome {
        case .passed:  "checkmark.circle.fill"
        case .redacted: "pencil.slash"
        case .blocked:  "xmark.circle.fill"
        }
    }

    private var outcomeColor: Color {
        switch entry.outcome {
        case .passed:  .green
        case .redacted: .orange
        case .blocked:  .red
        }
    }
}
