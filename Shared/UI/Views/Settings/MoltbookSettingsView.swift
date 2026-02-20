// MoltbookSettingsView.swift
// Thea — Moltbook Agent Configuration

import SwiftUI

struct MoltbookSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var pendingPostCount = 0
    @State private var insightCount = 0
    @State private var isRefreshing = false

    // W3-7: Activity log loaded from actor
    @State private var recentInsights: [DevelopmentInsight] = []
    @State private var lastHeartbeat: Date?

    var body: some View {
        Form {
            Section("Moltbook Agent") {
                Toggle("Enable Moltbook Agent", isOn: $settings.moltbookAgentEnabled)
                    .onChange(of: settings.moltbookAgentEnabled) { _, enabled in
                        Task {
                            if enabled {
                                await MoltbookAgent.shared.enable()
                            } else {
                                await MoltbookAgent.shared.disable()
                            }
                        }
                    }

                if settings.moltbookAgentEnabled {
                    Toggle("Preview Mode", isOn: $settings.moltbookPreviewMode)
                        .help("Review every outbound post before sending")
                        .onChange(of: settings.moltbookPreviewMode) { _, preview in
                            Task {
                                await MoltbookAgent.shared.setPreviewMode(preview)
                            }
                        }

                    Stepper(
                        "Max Daily Posts: \(settings.moltbookMaxDailyPosts)",
                        value: $settings.moltbookMaxDailyPosts,
                        in: 1 ... 50
                    )
                    .onChange(of: settings.moltbookMaxDailyPosts) { _, maxPosts in
                        Task {
                            await MoltbookAgent.shared.setMaxDailyPosts(maxPosts)
                        }
                    }
                }

                Text(
                    "Participates in public dev discussions on Moltbook while keeping personal, "
                        + "confidential, and proprietary information private via OutboundPrivacyGuard "
                        + "(paranoid mode)."
                )
                .font(.theaCaption2)
                .foregroundStyle(.secondary)
            }

            if settings.moltbookAgentEnabled {
                Section("Privacy Protection") {
                    Label("6-layer sanitization active", systemImage: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Label(
                        "Paranoid policy: no PII, no file paths, no code snippets",
                        systemImage: "eye.slash"
                    )
                    Label("Topic allowlist: 34 dev topics only", systemImage: "list.bullet.clipboard")
                    Label("Max 2048 chars per post", systemImage: "text.badge.checkmark")
                }

                Section("Status") {
                    LabeledContent("Pending Posts", value: "\(pendingPostCount)")
                    LabeledContent("Collected Insights", value: "\(insightCount)")
                    LabeledContent("Daily Limit", value: "\(pendingPostCount)/\(settings.moltbookMaxDailyPosts)")

                    if let heartbeat = lastHeartbeat {
                        LabeledContent("Last Active") {
                            Text(heartbeat, style: .relative)
                                .foregroundStyle(.secondary)
                                .font(.theaCaption1)
                        }
                    }

                    Button("Refresh Status") {
                        isRefreshing = true
                        Task {
                            pendingPostCount = await MoltbookAgent.shared.pendingPosts.count
                            insightCount = await MoltbookAgent.shared.insights.count
                            lastHeartbeat = await MoltbookAgent.shared.lastHeartbeat
                            recentInsights = Array((await MoltbookAgent.shared.insights)
                                .sorted { $0.timestamp > $1.timestamp }
                                .prefix(5))
                            isRefreshing = false
                        }
                    }
                    .disabled(isRefreshing)
                }

                // W3-7: Activity log — recent insights
                if !recentInsights.isEmpty {
                    Section("Recent Insights") {
                        ForEach(recentInsights) { insight in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(insight.title)
                                        .font(.theaCaption1)
                                        .fontWeight(.medium)
                                    Spacer()
                                    actionabilityBadge(insight.actionability)
                                }
                                if !insight.topics.isEmpty {
                                    Text(insight.topics.prefix(3).joined(separator: " · "))
                                        .font(.theaCaption2)
                                        .foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text(insight.source)
                                        .font(.theaCaption2)
                                        .foregroundStyle(.tertiary)
                                    Spacer()
                                    Text(insight.timestamp, style: .relative)
                                        .font(.theaCaption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            if settings.moltbookAgentEnabled {
                pendingPostCount = await MoltbookAgent.shared.pendingPosts.count
                insightCount = await MoltbookAgent.shared.insights.count
                lastHeartbeat = await MoltbookAgent.shared.lastHeartbeat
                recentInsights = Array((await MoltbookAgent.shared.insights)
                    .sorted { $0.timestamp > $1.timestamp }
                    .prefix(5))
            }
        }
    }

    @ViewBuilder
    private func actionabilityBadge(_ actionability: DevelopmentInsight.Actionability) -> some View {
        let (label, color): (String, Color) = switch actionability {
        case .informational: ("FYI", .secondary)
        case .suggestion: ("Suggestion", .blue)
        case .recommended: ("Recommended", .green)
        }
        Text(label)
            .font(.theaCaption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
