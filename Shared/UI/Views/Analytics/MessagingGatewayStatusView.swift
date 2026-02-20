// MessagingGatewayStatusView.swift
// Thea
//
// V3-3: Live health dashboard for the Thea Messaging Gateway.
// Shows 7-platform connector status, running state, and any errors.

import SwiftUI

// MARK: - Messaging Gateway Status View

struct MessagingGatewayStatusView: View {
    @StateObject private var gateway = TheaMessagingGateway.shared

    var body: some View {
        List {
            // Gateway lifecycle
            Section("Gateway Server") {
                LabeledContent("Port 18789") {
                    Label(
                        gateway.isRunning ? "Running" : "Stopped",
                        systemImage: gateway.isRunning ? "server.rack" : "xmark.circle"
                    )
                    .foregroundStyle(gateway.isRunning ? .green : .red)
                }

                if let error = gateway.lastError {
                    LabeledContent("Last Error") {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.theaCaption1)
                    }
                }

                HStack(spacing: TheaSpacing.md) {
                    Button(gateway.isRunning ? "Stop Gateway" : "Start Gateway") {
                        Task {
                            if gateway.isRunning {
                                await gateway.stop()
                            } else {
                                await gateway.start()
                            }
                        }
                    }
                    .tint(gateway.isRunning ? .red : .green)
                }
            }

            // Connector status for each platform
            Section("Connectors (\(MessagingPlatform.allCases.count))") {
                ForEach(MessagingPlatform.allCases, id: \.self) { platform in
                    ConnectorStatusRow(
                        platform: platform,
                        isConnected: gateway.connectedPlatforms.contains(platform),
                        onReconnect: {
                            Task { await gateway.restartConnector(for: platform) }
                        }
                    )
                }
            }

            // Connection summary
            Section("Summary") {
                LabeledContent("Active Connections",
                               value: "\(gateway.connectedPlatforms.count) / \(MessagingPlatform.allCases.count)")
                LabeledContent("Disconnected Platforms",
                               value: "\(MessagingPlatform.allCases.count - gateway.connectedPlatforms.count)")
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.grouped)
        #endif
        .navigationTitle("Messaging Gateway")
        #if os(macOS)
        .padding()
        #endif
        .refreshable {
            // Re-fetch status (gateway publishes changes automatically)
            await gateway.start()
        }
    }
}

// MARK: - Connector Status Row

struct ConnectorStatusRow: View {
    let platform: MessagingPlatform
    let isConnected: Bool
    let onReconnect: () -> Void

    var body: some View {
        HStack(spacing: TheaSpacing.md) {
            Image(systemName: platformIcon)
                .foregroundStyle(isConnected ? platformColor : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(platformName)
                    .font(.theaBody.weight(.medium))
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.theaCaption1)
                    .foregroundStyle(isConnected ? .green : .secondary)
            }

            Spacer()

            if !isConnected {
                Button("Reconnect") { onReconnect() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    private var platformName: String {
        switch platform {
        case .telegram:  "Telegram"
        case .discord:   "Discord"
        case .slack:     "Slack"
        case .imessage:  "iMessage (BlueBubbles)"
        case .whatsapp:  "WhatsApp"
        case .signal:    "Signal"
        case .matrix:    "Matrix"
        }
    }

    private var platformIcon: String {
        switch platform {
        case .telegram:  "paperplane.fill"
        case .discord:   "gamecontroller.fill"
        case .slack:     "number.square.fill"
        case .imessage:  "bubble.fill"
        case .whatsapp:  "phone.bubble.fill"
        case .signal:    "lock.shield.fill"
        case .matrix:    "network"
        }
    }

    private var platformColor: Color {
        switch platform {
        case .telegram:  .blue
        case .discord:   .purple
        case .slack:     .green
        case .imessage:  .green
        case .whatsapp:  .green
        case .signal:    .blue
        case .matrix:    .orange
        }
    }
}
