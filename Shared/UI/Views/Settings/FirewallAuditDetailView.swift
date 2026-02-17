//
//  FirewallAuditDetailView.swift
//  Thea
//
//  Detailed audit log for the outbound privacy firewall showing
//  per-entry outcomes (passed, redacted, blocked) with summary statistics.
//

import SwiftUI

/// Detailed firewall audit log view displaying a summary of pass/redact/block
/// counts and a chronological list of recent audit entries.
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
