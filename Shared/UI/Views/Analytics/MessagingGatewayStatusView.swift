// MessagingGatewayStatusView.swift
// Thea — Native Messaging Gateway Status Dashboard
//
// Displays real-time connection status for all 7 messaging platform connectors
// managed by TheaMessagingGateway. Shows which platforms are live, which have
// errors, and provides quick restart actions.

import SwiftUI

// MARK: - Messaging Gateway Status View

struct MessagingGatewayStatusView: View {
    @ObservedObject private var gateway = TheaMessagingGateway.shared
    @State private var restartingPlatform: MessagingPlatform?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                gatewayOverview
                platformGrid
                if let error = gateway.lastError {
                    lastErrorSection(error)
                }
                technicalDetailsSection
            }
            .padding(20)
        }
        .navigationTitle("Messaging Gateway Status")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await gateway.start() }
                } label: {
                    Label("Start Gateway", systemImage: "play.circle")
                }
                .disabled(gateway.isRunning)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Thea Messaging Gateway")
                .font(.title2).bold()
            Text("Thea connects directly to each platform's API. No external daemon required.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gatewayOverview: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(gateway.isRunning ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .overlay(
                            gateway.isRunning ?
                                Circle().stroke(Color.green.opacity(0.4), lineWidth: 4) : nil
                        )
                    Text(gateway.isRunning ? "Gateway Running" : "Gateway Stopped")
                        .font(.headline)
                }
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .foregroundStyle(.secondary)
                    Text("WebSocket server on port 18789")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(gateway.connectedPlatforms.count)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(gateway.connectedPlatforms.isEmpty ? .secondary : .green)
                Text("/ \(MessagingPlatform.allCases.count) platforms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(gateway.isRunning ? Color.green.opacity(0.07) : Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var platformGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Platform Connectors")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MessagingPlatform.allCases, id: \.rawValue) { platform in
                    PlatformStatusCard(
                        platform: platform,
                        isConnected: gateway.connectedPlatforms.contains(platform),
                        isRestarting: restartingPlatform == platform,
                        onRestart: {
                            Task {
                                restartingPlatform = platform
                                await gateway.restartConnector(for: platform)
                                restartingPlatform = nil
                            }
                        }
                    )
                }
            }
        }
    }

    private func lastErrorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Last Error", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline).bold()
                .foregroundStyle(.orange)
            Text(error)
                .font(.caption)
                .fontDesign(.monospaced)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var technicalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Technical Details")
                .font(.subheadline).bold()
            TechDetailRow(label: "Gateway Port", value: "18789 (WebSocket)")
            TechDetailRow(label: "Security", value: "22-pattern injection guard on all inbound")
            TechDetailRow(label: "Session Storage", value: "SwiftData (per-platform · per-peer)")
            TechDetailRow(label: "External Dependency", value: "None — Thea is the gateway")
            TechDetailRow(label: "Connected Platforms", value: gateway.connectedPlatforms.map(\.displayName).sorted().joined(separator: ", ").ifEmpty("None"))
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Platform Status Card

private struct PlatformStatusCard: View {
    let platform: MessagingPlatform
    let isConnected: Bool
    let isRestarting: Bool
    let onRestart: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: platform.symbolName)
                .foregroundStyle(isConnected ? .green : .secondary)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(platform.displayName)
                    .font(.caption).bold()
                    .lineLimit(1)
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.caption2)
                    .foregroundStyle(isConnected ? .green : .secondary)
            }

            Spacer()

            if isRestarting {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Button {
                    onRestart()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Restart \(platform.displayName) connector")
            }
        }
        .padding(10)
        .background(isConnected ? Color.green.opacity(0.07) : Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isConnected ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Tech Detail Row

private struct TechDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
            Text(value)
                .font(.caption)
                .fontDesign(.monospaced)
            Spacer()
        }
        .padding(.vertical, 1)
    }
}

// MARK: - String Helper

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        MessagingGatewayStatusView()
    }
    .frame(width: 700, height: 600)
}
#endif
