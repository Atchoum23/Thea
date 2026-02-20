// MessagingGatewayStatusView.swift
// Thea — Messaging Gateway Status
// Shows live connection state for all 7 platform connectors via TheaMessagingGateway

import SwiftUI

#if os(macOS)
struct MessagingGatewayStatusView: View {
    @ObservedObject private var gateway = TheaMessagingGateway.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Messaging Gateway")
                    .font(.largeTitle.bold())

                GroupBox("Gateway Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(gateway.isRunning ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(gateway.isRunning ? "Running on port 18789" : "Stopped")
                                .fontWeight(.medium)
                            Spacer()
                            if !gateway.isRunning {
                                Button("Start") {
                                    Task { await gateway.start() }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        if let error = gateway.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(4)
                }

                GroupBox("Platform Connectors") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(MessagingPlatform.allCases, id: \.self) { platform in
                            HStack {
                                Image(systemName: gateway.connectedPlatforms.contains(platform)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(gateway.connectedPlatforms.contains(platform)
                                                     ? Color.green : Color.secondary)
                                Text(platform.displayName)
                                Spacer()
                                Text(gateway.connectedPlatforms.contains(platform) ? "Connected" : "Disconnected")
                                    .font(.caption)
                                    .foregroundStyle(gateway.connectedPlatforms.contains(platform)
                                                     ? Color.green : Color.secondary)
                            }
                        }
                    }
                    .padding(4)
                }

                Spacer()
            }
            .padding()
        }
    }
}
#endif
