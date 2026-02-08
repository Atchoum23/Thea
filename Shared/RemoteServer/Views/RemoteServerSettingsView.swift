//
//  RemoteServerSettingsView.swift
//  Thea
//
//  Created by Claude Code on 2026-01-22
//  Copyright © 2026. All rights reserved.
//

import SwiftUI

#if os(macOS)

    // MARK: - Remote Server Settings View

    /// Main settings view for configuring the Thea remote server
    public struct RemoteServerSettingsView: View {
        @ObservedObject private var server = TheaRemoteServer.shared
        @State private var showPairingCode = false
        @State private var generatedPairingCode: String?

        public init() {}

        public var body: some View {
            Form {
                // Server Status Section
                Section {
                    ServerStatusRow(server: server)

                    if server.isRunning {
                        LabeledContent("Address") {
                            Text("\(server.serverAddress ?? "Unknown"):\(server.serverPort)")
                                .font(.system(.body, design: .monospaced))
                        }

                        LabeledContent("Connected Clients") {
                            Text("\(server.connectedClients.count)")
                        }
                    }
                } header: {
                    Text("Server Status")
                }

                // Configuration Section
                Section {
                    TextField("Server Name", text: Binding(
                        get: { server.configuration.serverName },
                        set: { server.configuration.serverName = $0 }
                    ))

                    Stepper("Port: \(server.configuration.port)", value: Binding(
                        get: { Int(server.configuration.port) },
                        set: { server.configuration.port = UInt16($0) }
                    ), in: 1024 ... 65535)

                    Stepper("Max Connections: \(server.configuration.maxConnections)", value: Binding(
                        get: { server.configuration.maxConnections },
                        set: { server.configuration.maxConnections = $0 }
                    ), in: 1 ... 20)
                } header: {
                    Text("Configuration")
                }

                // Authentication Section
                Section {
                    Picker("Authentication Method", selection: Binding(
                        get: { server.configuration.authMethod },
                        set: { server.configuration.authMethod = $0 }
                    )) {
                        ForEach(AuthenticationMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }

                    if server.configuration.authMethod == .pairingCode {
                        Button("Generate Pairing Code") {
                            generatedPairingCode = server.connectionManager.generatePairingCode()
                            showPairingCode = true
                        }
                    }

                    Toggle("Require Confirmation for Actions", isOn: Binding(
                        get: { server.configuration.requireConfirmation },
                        set: { server.configuration.requireConfirmation = $0 }
                    ))
                } header: {
                    Text("Authentication")
                }

                // Features Section
                Section {
                    Toggle("Enable Network Discovery", isOn: Binding(
                        get: { server.configuration.enableDiscovery },
                        set: { server.configuration.enableDiscovery = $0 }
                    ))

                    Toggle("Screen Sharing", isOn: Binding(
                        get: { server.configuration.enableScreenSharing },
                        set: { server.configuration.enableScreenSharing = $0 }
                    ))

                    Toggle("Input Control", isOn: Binding(
                        get: { server.configuration.enableInputControl },
                        set: { server.configuration.enableInputControl = $0 }
                    ))

                    Toggle("File Access", isOn: Binding(
                        get: { server.configuration.enableFileAccess },
                        set: { server.configuration.enableFileAccess = $0 }
                    ))

                    Toggle("System Control", isOn: Binding(
                        get: { server.configuration.enableSystemControl },
                        set: { server.configuration.enableSystemControl = $0 }
                    ))

                    Toggle("Network Proxy", isOn: Binding(
                        get: { server.configuration.enableNetworkProxy },
                        set: { server.configuration.enableNetworkProxy = $0 }
                    ))
                } header: {
                    Text("Features")
                } footer: {
                    Text("System Control allows remote reboot, shutdown, and other system operations.")
                }

                // Security Section
                Section {
                    Toggle("Require Encryption", isOn: Binding(
                        get: { server.configuration.encryptionRequired },
                        set: { server.configuration.encryptionRequired = $0 }
                    ))

                    Toggle("Use IP Whitelist", isOn: Binding(
                        get: { server.configuration.useWhitelist },
                        set: { server.configuration.useWhitelist = $0 }
                    ))

                    if server.configuration.useWhitelist {
                        NavigationLink("Manage Whitelist") {
                            WhitelistView(connectionManager: server.connectionManager)
                        }
                    }

                    LabeledContent("Session Timeout") {
                        Picker("", selection: Binding(
                            get: { server.configuration.sessionTimeout },
                            set: { server.configuration.sessionTimeout = $0 }
                        )) {
                            Text("15 minutes").tag(TimeInterval(900))
                            Text("1 hour").tag(TimeInterval(3600))
                            Text("4 hours").tag(TimeInterval(14400))
                            Text("Never").tag(TimeInterval(86400 * 365))
                        }
                        .labelsHidden()
                    }
                } header: {
                    Text("Security")
                }

                // Connected Clients Section
                if !server.connectedClients.isEmpty {
                    Section {
                        ForEach(server.connectedClients) { client in
                            ClientRow(client: client) {
                                Task {
                                    await server.sessionManager.terminateSession(client.id, reason: "Disconnected by user")
                                }
                            }
                        }
                    } header: {
                        Text("Connected Clients")
                    }
                }

                // Security Events Section
                if !server.securityEvents.isEmpty {
                    Section {
                        ForEach(server.securityEvents.prefix(10)) { event in
                            SecurityEventRow(event: event)
                        }

                        if server.securityEvents.count > 10 {
                            NavigationLink("View All Events") {
                                SecurityEventsListView(events: server.securityEvents)
                            }
                        }
                    } header: {
                        Text("Recent Security Events")
                    }
                }
            }
            .navigationTitle("Remote Server")
            #if os(macOS)
                .formStyle(.grouped)
            #endif
                .sheet(isPresented: $showPairingCode) {
                    PairingCodeView(code: generatedPairingCode ?? "------")
                }
        }
    }

    // MARK: - Server Status Row

    private struct ServerStatusRow: View {
        @ObservedObject var server: TheaRemoteServer

        var body: some View {
            HStack {
                statusIndicator

                VStack(alignment: .leading) {
                    Text(statusText)
                        .font(.headline)

                    if case let .error(message) = server.serverStatus {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: toggleServer) {
                    Text(server.isRunning ? "Stop" : "Start")
                }
                .buttonStyle(.borderedProminent)
                .tint(server.isRunning ? .red : .green)
            }
            .padding(.vertical, 4)
        }

        @ViewBuilder
        private var statusIndicator: some View {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
        }

        private var statusColor: Color {
            switch server.serverStatus {
            case .running: .green
            case .starting, .stopping: .yellow
            case .stopped: .gray
            case .error: .red
            }
        }

        private var statusText: String {
            switch server.serverStatus {
            case .running: "Running"
            case .starting: "Starting..."
            case .stopping: "Stopping..."
            case .stopped: "Stopped"
            case .error: "Error"
            }
        }

        private func toggleServer() {
            Task {
                if server.isRunning {
                    await server.stop()
                } else {
                    try? await server.start()
                }
            }
        }
    }

    // MARK: - Client Row

    private struct ClientRow: View {
        let client: RemoteClient
        let onDisconnect: () -> Void

        var body: some View {
            HStack {
                Image(systemName: deviceIcon)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading) {
                    Text(client.name)
                        .font(.headline)

                    Text(client.ipAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(action: onDisconnect) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }

        private var deviceIcon: String {
            switch client.deviceType {
            case .mac: "desktopcomputer"
            case .iPhone: "iphone"
            case .iPad: "ipad"
            case .unknown: "questionmark.circle"
            }
        }

        private var timeAgo: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: client.connectedAt, relativeTo: Date())
        }
    }

    // MARK: - Security Event Row

    private struct SecurityEventRow: View {
        let event: SecurityEvent

        var body: some View {
            HStack {
                Image(systemName: eventIcon)
                    .foregroundStyle(eventColor)

                VStack(alignment: .leading) {
                    Text(event.type.rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).trimmingCharacters(in: .whitespaces).capitalized)
                        .font(.subheadline)

                    Text(event.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        private var eventIcon: String {
            switch event.type {
            case .serverStarted, .serverStopped: "power"
            case .clientConnected: "person.badge.plus"
            case .clientDisconnected: "person.badge.minus"
            case .connectionRejected, .authenticationFailed: "exclamationmark.shield"
            case .permissionDenied: "lock.shield"
            case .rateLimitExceeded: "speedometer"
            case .suspiciousActivity: "exclamationmark.triangle"
            case .fileAccessBlocked, .commandBlocked: "xmark.shield"
            case .serverError: "exclamationmark.circle"
            case .totpFailed, .totpVerified: "key"
            case .unattendedAccessUsed: "person.slash"
            case .privacyModeEnabled, .privacyModeDisabled: "eye.slash"
            case .recordingStarted, .recordingStopped: "record.circle"
            case .clipboardSynced: "doc.on.clipboard"
            case .configurationChanged: "gearshape"
            }
        }

        private var eventColor: Color {
            switch event.type {
            case .serverStarted, .clientConnected, .totpVerified: .green
            case .serverStopped, .clientDisconnected, .configurationChanged: .gray
            case .connectionRejected, .authenticationFailed, .permissionDenied, .totpFailed: .orange
            case .rateLimitExceeded, .suspiciousActivity, .fileAccessBlocked, .commandBlocked: .red
            case .serverError: .red
            case .unattendedAccessUsed, .clipboardSynced: .blue
            case .privacyModeEnabled, .privacyModeDisabled, .recordingStarted, .recordingStopped: .purple
            }
        }

        private var timeAgo: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: event.timestamp, relativeTo: Date())
        }
    }

    // MARK: - Pairing Code View

    private struct PairingCodeView: View {
        let code: String
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            VStack(spacing: 24) {
                Image(systemName: "qrcode")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Pairing Code")
                    .font(.title)

                Text(formattedCode)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .tracking(8)

                Text("Enter this code on the device you want to connect")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("This code expires in 5 minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(40)
            #if os(macOS)
                .frame(width: 400, height: 350)
            #endif
        }

        private var formattedCode: String {
            let chars = Array(code)
            if chars.count == 6 {
                return "\(chars[0])\(chars[1])\(chars[2]) \(chars[3])\(chars[4])\(chars[5])"
            }
            return code
        }
    }

    // MARK: - Whitelist View

    private struct WhitelistView: View {
        @ObservedObject var connectionManager: SecureConnectionManager
        @State private var newIP = ""

        var body: some View {
            List {
                Section {
                    ForEach(Array(connectionManager.whitelist), id: \.self) { ip in
                        HStack {
                            Text(ip)
                                .font(.system(.body, design: .monospaced))

                            Spacer()

                            Button(action: { connectionManager.removeFromWhitelist(ip) }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Allowed IPs")
                }

                Section {
                    HStack {
                        TextField("IP Address", text: $newIP)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            if !newIP.isEmpty {
                                connectionManager.addToWhitelist(newIP)
                                newIP = ""
                            }
                        }
                        .disabled(newIP.isEmpty)
                    }
                } header: {
                    Text("Add IP")
                }
            }
            .navigationTitle("IP Whitelist")
        }
    }

    // MARK: - Security Events List View

    private struct SecurityEventsListView: View {
        let events: [SecurityEvent]

        var body: some View {
            List(events) { event in
                SecurityEventRow(event: event)
            }
            .navigationTitle("Security Events")
        }
    }

    // MARK: - Preview

    #Preview {
        NavigationStack {
            RemoteServerSettingsView()
        }
    }

#endif // os(macOS)
