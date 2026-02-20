//
//  TVInferenceRelaySettingsView.swift
//  Thea TV
//
//  Settings view for discovering and connecting to a macOS Thea inference server.
//
//  CREATED: February 8, 2026
//

import SwiftUI

// MARK: - Inference Relay Settings View

struct TVInferenceRelaySettingsView: View {
    @ObservedObject var client: RemoteInferenceClient
    // periphery:ignore - Reserved: AD3 audit — wired in future integration
    @State private var isScanning = false

    var body: some View {
        List {
            connectionStatusSection

            if client.connectionState.isConnected {
                connectedServerSection
            } else {
                discoveredServersSection
            }

            if !client.availableModels.isEmpty {
                modelsSection
            }
        }
        .navigationTitle("Mac Connection")
        .onAppear {
            if !client.connectionState.isConnected {
                client.startDiscovery()
            }
        }
        .onDisappear {
            if !client.connectionState.isConnected {
                client.stopDiscovery()
            }
        }
    }

    // MARK: - Connection Status

    private var connectionStatusSection: some View {
        Section {
            HStack(spacing: 16) {
                connectionStatusIcon
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Status")
                        .font(.headline)
                    Text(client.connectionState.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if client.connectionState.isConnected {
                    Button("Disconnect", role: .destructive) {
                        client.disconnect()
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Status")
        }
    }

    @ViewBuilder
    private var connectionStatusIcon: some View {
        switch client.connectionState {
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .connecting:
            ProgressView()
        case .discovering:
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .disconnected:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Discovered Servers

    private var discoveredServersSection: some View {
        Section {
            if client.discoveredServers.isEmpty {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Searching for Thea servers...")
                            .font(.headline)
                        Text("Make sure Thea is running on your Mac and Remote Server is enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } else {
                ForEach(client.discoveredServers) { server in
                    Button {
                        client.connect(to: server)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "desktopcomputer")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 44, height: 44)
                                .background(.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(server.name)
                                    .font(.headline)
                                Text(server.platform)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                client.stopDiscovery()
                client.startDiscovery()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Available Servers")
        }
    }

    // MARK: - Connected Server

    private var connectedServerSection: some View {
        Section {
            if let name = client.connectedServerName {
                HStack(spacing: 16) {
                    Image(systemName: "desktopcomputer")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 44, height: 44)
                        .background(.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.headline)
                        if let caps = client.serverCapabilities {
                            Text("\(caps.availableProviderCount) AI provider(s) • \(caps.deviceName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Button("Refresh Models") {
                Task { await client.requestModelList() }
            }
        } header: {
            Text("Connected Server")
        }
    }

    // MARK: - Models

    private var modelsSection: some View {
        Section {
            ForEach(client.availableModels) { model in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.name)
                            .font(.headline)
                        Text(model.provider)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if model.isDefault {
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Available Models")
        }
    }
}
