// MoltbookSettingsView.swift
// Thea — Moltbook Agent Configuration

import SwiftUI

struct MoltbookSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var pendingPostCount = 0
    @State private var insightCount = 0
    @State private var unreadInsightCount = 0
    @State private var isRefreshing = false

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
                    LabeledContent("Unread Insights", value: "\(unreadInsightCount)")

                    Button("Refresh Status") {
                        isRefreshing = true
                        Task {
                            await refreshStatus()
                            isRefreshing = false
                        }
                    }
                    .disabled(isRefreshing)
                }

                if pendingPostCount > 0 {
                    Section("Pending Post Actions") {
                        Button("Approve All Pending Posts") {
                            Task {
                                let posts = await MoltbookAgent.shared.pendingPosts
                                for post in posts {
                                    _ = await MoltbookAgent.shared.approvePendingPost(id: post.id)
                                }
                                await refreshStatus()
                            }
                        }

                        Button("Reject All Pending Posts", role: .destructive) {
                            Task {
                                let posts = await MoltbookAgent.shared.pendingPosts
                                for post in posts {
                                    await MoltbookAgent.shared.rejectPendingPost(id: post.id)
                                }
                                await refreshStatus()
                            }
                        }

                        Button("Clear All Pending Posts", role: .destructive) {
                            Task {
                                await MoltbookAgent.shared.clearPendingPosts()
                                await refreshStatus()
                            }
                        }
                    }
                }

                if unreadInsightCount > 0 {
                    Section("Insight Actions") {
                        Button("Mark All Insights Read") {
                            Task {
                                let unread = await MoltbookAgent.shared.getUnreadInsights()
                                for insight in unread {
                                    await MoltbookAgent.shared.markInsightRead(id: insight.id)
                                }
                                await refreshStatus()
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            if settings.moltbookAgentEnabled {
                await refreshStatus()
            }
        }
    }

    private func refreshStatus() async {
        pendingPostCount = await MoltbookAgent.shared.pendingPosts.count
        insightCount = await MoltbookAgent.shared.insights.count
        unreadInsightCount = await MoltbookAgent.shared.getUnreadInsights().count
    }
}
