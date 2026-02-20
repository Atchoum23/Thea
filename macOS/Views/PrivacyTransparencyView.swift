// PrivacyTransparencyView.swift
// Thea — Privacy Audit Log
// Shows the outbound data privacy audit log from OutboundPrivacyGuard

import SwiftUI

#if os(macOS)
struct PrivacyTransparencyView: View {
    @State private var auditEntries: [PrivacyAuditEntry] = []
    @State private var stats: PrivacyAuditStatistics?
    private let guard_ = OutboundPrivacyGuard.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Transparency")
                    .font(.largeTitle.bold())

                if let s = stats {
                    HStack(spacing: 16) {
                        statCard("Total", value: s.totalChecks, color: .primary)
                        statCard("Passed", value: s.passed, color: .green)
                        statCard("Redacted", value: s.redacted, color: .orange)
                    }
                }

                HStack {
                    Text("Outbound Data Audit Log")
                        .font(.headline)
                    Spacer()
                    Button("Clear Log") {
                        guard_.clearAuditLog()
                        refresh()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()

            Divider()

            if auditEntries.isEmpty {
                ContentUnavailableView(
                    "No Audit Entries",
                    systemImage: "shield.checkered",
                    description: Text("Privacy audit entries will appear as Thea sends data to AI providers.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(auditEntries) { entry in
                    HStack(alignment: .top) {
                        Image(systemName: entry.outcome == .passed ? "checkmark.shield.fill" : "shield.slash.fill")
                            .foregroundStyle(entry.outcome == .passed ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.channel).font(.caption.bold())
                            Text(entry.policyName).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.redactionCount > 0 {
                            Text("\(entry.redactionCount) redacted")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        Text(entry.timestamp, style: .relative)
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .listStyle(.inset)
            }
        }
        .task { refresh() }
    }

    private func refresh() {
        auditEntries = guard_.getAuditLog(limit: 200)
        stats = guard_.getPrivacyAuditStatistics()
    }

    private func statCard(_ label: String, value: Int, color: Color) -> some View {
        VStack {
            Text("\(value)").font(.title2.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
#endif
