// RemoteAccessSettingsView.swift
// Settings for remote session and device management - wired to TheaRemoteServer

import SwiftUI

struct RemoteAccessSettingsView: View {
    #if os(macOS)
        @ObservedObject private var server = TheaRemoteServer.shared
    #endif

    @State private var discoveredDevices: [DiscoveredDeviceInfo] = []
    @State private var isScanning = false
    @State private var showPairingCode = false

    var body: some View {
        Form {
            serverSection
            featureTogglesSection
            recordingSection
            securitySection
            unattendedSection
            twoFactorSection
            discoverySection
            wolSection
            sessionsSection
            auditSection
            qualitySection
        }
        .formStyle(.grouped)
        .navigationTitle("Remote Access")
    }

    // MARK: - Server Section

    @ViewBuilder
    private var serverSection: some View {
        Section("Server") {
            #if os(macOS)
                Toggle("Enable Remote Server", isOn: Binding(
                    get: { server.isRunning },
                    set: { enabled in
                        Task {
                            if enabled {
                                try? await server.start()
                            } else {
                                await server.stop()
                            }
                        }
                    }
                ))

                if server.isRunning {
                    LabeledContent("Status") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Running")
                                .foregroundStyle(.green)
                        }
                    }

                    if let address = server.serverAddress {
                        LabeledContent("Address", value: "\(address):\(server.serverPort)")
                    }

                    LabeledContent("Connected Clients", value: "\(server.connectedClients.count)")
                }

                HStack {
                    Text("Port")
                    Spacer()
                    TextField("Port", value: Binding(
                        get: { Int(server.configuration.port) },
                        set: { server.configuration.port = UInt16($0) }
                    ), format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                }

                TextField("Server Name", text: Binding(
                    get: { server.configuration.serverName },
                    set: { server.configuration.serverName = $0 }
                ))
                .textFieldStyle(.roundedBorder)

                Stepper("Max Connections: \(server.configuration.maxConnections)", value: Binding(
                    get: { server.configuration.maxConnections },
                    set: { server.configuration.maxConnections = $0 }
                ), in: 1 ... 20)
            #else
                Text("Remote server is only available on macOS")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    // MARK: - Feature Toggles

    @ViewBuilder
    private var featureTogglesSection: some View {
        Section("Features") {
            #if os(macOS)
                Toggle("Screen Sharing", isOn: $server.configuration.enableScreenSharing)
                Toggle("Input Control", isOn: $server.configuration.enableInputControl)
                Toggle("File Access", isOn: $server.configuration.enableFileAccess)
                Toggle("System Control", isOn: $server.configuration.enableSystemControl)
                Toggle("Clipboard Sync", isOn: $server.configuration.enableClipboardSync)
                Toggle("Audio Streaming", isOn: $server.configuration.enableAudioStreaming)
                Toggle("Chat & Annotations", isOn: $server.configuration.enableChatAnnotations)
            #else
                Text("Feature toggles available on macOS only")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    @ViewBuilder
    private var recordingSection: some View {
        Section("Recording") {
            #if os(macOS)
                Toggle("Enable Session Recording", isOn: $server.configuration.enableSessionRecording)
                if server.configuration.enableSessionRecording {
                    Toggle("Auto-Record Sessions", isOn: $server.configuration.autoRecordSessions)
                    LabeledContent("Recordings") {
                        Text("\(server.sessionRecording.recordings.count) sessions")
                    }
                    LabeledContent("Storage Used") {
                        Text(formatBytes(server.sessionRecording.totalStorageBytes))
                    }
                }
            #else
                Text("Recording available on macOS only")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    // MARK: - Security Section

    @ViewBuilder
    private var securitySection: some View {
        Section("Authentication") {
            #if os(macOS)
                Picker("Method", selection: $server.configuration.authMethod) {
                    ForEach(AuthenticationMethod.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }

                Toggle("Require Confirmation", isOn: $server.configuration.requireConfirmation)
                Toggle("Encryption Required", isOn: $server.configuration.encryptionRequired)
                Toggle("IP Whitelist", isOn: $server.configuration.useWhitelist)

                Button("Generate Pairing Code") {
                    showPairingCode = true
                    _ = server.connectionManager.generatePairingCode()
                }

                if showPairingCode, let code = server.connectionManager.activePairingCode {
                    HStack {
                        Text("Pairing Code:")
                            .font(.headline)
                        Text(code)
                            .font(.system(.title2, design: .monospaced))
                            .foregroundStyle(.blue)
                            .textSelection(.enabled)
                    }
                }
            #else
                Text("Authentication settings available on macOS only")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    @ViewBuilder
    private var unattendedSection: some View {
        Section("Unattended Access") {
            #if os(macOS)
                Toggle("Enable Unattended Access", isOn: $server.configuration.enableUnattendedAccess)

                if server.configuration.enableUnattendedAccess {
                    LabeledContent("Password Status") {
                        Text(server.connectionManager.hasUnattendedPassword ? "Set" : "Not Configured")
                            .foregroundStyle(server.connectionManager.hasUnattendedPassword ? .green : .orange)
                    }

                    LabeledContent("Device Profiles", value: "\(server.unattendedAccess.profiles.count)")
                }
            #else
                Text("Unattended access available on macOS only")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    @ViewBuilder
    private var twoFactorSection: some View {
        Section("Two-Factor Authentication") {
            #if os(macOS)
                Toggle("Enable TOTP (2FA)", isOn: $server.configuration.enableTwoFactor)

                if server.configuration.enableTwoFactor {
                    LabeledContent("Status") {
                        Text(server.totpAuth.isEnabled ? "Enabled" : "Not Set Up")
                            .foregroundStyle(server.totpAuth.isEnabled ? .green : .orange)
                    }

                    if server.totpAuth.isEnabled {
                        LabeledContent("Recovery Codes", value: "\(server.totpAuth.remainingRecoveryCodes) remaining")

                        Button("Disable 2FA", role: .destructive) {
                            server.totpAuth.disable()
                        }
                    }
                }
            #else
                Text("2FA available on macOS only")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    // MARK: - Discovery & WoL

    @ViewBuilder
    private var discoverySection: some View {
        Section("Device Discovery") {
            #if os(macOS)
                Toggle("Enable Discovery", isOn: $server.configuration.enableDiscovery)
                    .help("Allow other devices to find this Thea instance via Bonjour")
            #else
                Toggle("Enable Discovery", isOn: .constant(false))
                    .disabled(true)
            #endif

            if discoveredDevices.isEmpty {
                if isScanning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Scanning for devices...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No devices found")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(discoveredDevices) { device in
                    DeviceRow(device: device) {
                        connectToDevice(device)
                    }
                }
            }

            Button {
                scanForDevices()
            } label: {
                Label("Scan for Devices", systemImage: "antenna.radiowaves.left.and.right")
            }
            .disabled(isScanning)
        }
    }

    @ViewBuilder
    private var wolSection: some View {
        #if os(macOS)
            Section("Wake-on-LAN") {
                if server.wakeOnLan.knownDevices.isEmpty {
                    Text("No WoL devices configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(server.wakeOnLan.knownDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.body)
                                Text(device.macAddress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Wake") {
                                Task {
                                    _ = await server.wakeOnLan.wake(macAddress: device.macAddress)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Button {
                    Task {
                        _ = await server.wakeOnLan.discoverMACAddresses()
                    }
                } label: {
                    Label("Discover Devices", systemImage: "network")
                }
            }
        #endif
    }

    // MARK: - Sessions Section

    @ViewBuilder
    private var sessionsSection: some View {
        Section("Connected Sessions") {
            #if os(macOS)
                if server.connectedClients.isEmpty {
                    Text("No active sessions")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(server.connectedClients) { client in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.name)
                                    .font(.body)
                                HStack(spacing: 8) {
                                    Text(client.deviceType.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(client.ipAddress)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Disconnect", role: .destructive) {
                                Task {
                                    await server.sessionManager.terminateSession(client.id, reason: "Disconnected by admin")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            #else
                Text("Sessions available on macOS only")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    // MARK: - Audit & Quality

    @ViewBuilder
    private var auditSection: some View {
        Section("Audit & Logging") {
            #if os(macOS)
                Stepper("Retention: \(server.configuration.auditLogRetentionDays) days", value: Binding(
                    get: { server.configuration.auditLogRetentionDays },
                    set: { server.configuration.auditLogRetentionDays = $0 }
                ), in: 7 ... 365, step: 30)

                let stats = server.auditLog.statistics
                LabeledContent("Total Entries", value: "\(stats.totalEntries)")
                LabeledContent("Last 24h", value: "\(stats.entriesLast24Hours)")
                LabeledContent("Failed Auth", value: "\(stats.failedAuthentications)")

                HStack {
                    Button("Export CSV") {
                        _ = server.auditLog.saveExport(format: .csv)
                    }
                    Button("Export JSON") {
                        _ = server.auditLog.saveExport(format: .json)
                    }
                }

                Button("Purge Old Entries") {
                    server.auditLog.purgeExpiredEntries()
                }
            #else
                Text("Audit logging available on macOS only")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    @ViewBuilder
    private var qualitySection: some View {
        Section("Connection Quality") {
            #if os(macOS)
                let monitor = server.qualityMonitor
                LabeledContent("Quality") {
                    Text(monitor.quality.rawValue.capitalized)
                        .foregroundStyle(qualityColor(monitor.quality))
                }
                LabeledContent("Latency", value: String(format: "%.0f ms", monitor.latencyMs))
                LabeledContent("FPS", value: String(format: "%.1f", monitor.currentFPS))
                LabeledContent("Bandwidth", value: formatBytes(Int64(monitor.bandwidthBytesPerSec)) + "/s")
            #else
                Text("Quality monitor available on macOS only")
                    .foregroundStyle(.secondary)
            #endif
        }
    }

    // MARK: - Actions

    private func scanForDevices() {
        isScanning = true
        #if os(macOS)
            Task {
                await server.networkDiscovery.startDiscovery()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                isScanning = false
            }
        #else
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isScanning = false
            }
        #endif
    }

    private func connectToDevice(_: DiscoveredDeviceInfo) {
        // Would establish connection
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    #if os(macOS)
        private func qualityColor(_ quality: ConnectionQuality) -> Color {
            switch quality {
            case .excellent: .green
            case .good: .blue
            case .fair: .orange
            case .poor: .red
            case .unknown: .gray
            }
        }
    #endif
}

// MARK: - Device Info

struct DiscoveredDeviceInfo: Identifiable {
    let id = UUID()
    let name: String
    let host: String
    let port: Int
    let platform: String
    let lastSeen: Date
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: DiscoveredDeviceInfo
    let onConnect: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.body)
                HStack(spacing: 8) {
                    Text(device.platform)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(device.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Connect", action: onConnect)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Remote Authentication Settings

struct RemoteAuthenticationSettingsView: View {
    @State private var authMethod = AuthMethod.token
    @State private var accessToken = ""
    @State private var showToken = false

    enum AuthMethod: String, CaseIterable {
        case none = "None"
        case token = "Access Token"
        case certificate = "Certificate"
    }

    var body: some View {
        Form {
            Section("Authentication Method") {
                Picker("Method", selection: $authMethod) {
                    ForEach(AuthMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
            }

            if authMethod == .token {
                Section("Access Token") {
                    HStack {
                        if showToken {
                            TextField("Token", text: $accessToken)
                        } else {
                            SecureField("Token", text: $accessToken)
                        }
                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Generate New Token") {
                        generateToken()
                    }
                }
            }

            if authMethod == .certificate {
                Section("Certificate") {
                    Button("Import Certificate") {
                        // Would open file picker
                    }

                    Button("Generate Self-Signed") {
                        // Would generate certificate
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Authentication")
    }

    private func generateToken() {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        accessToken = Data(bytes).base64EncodedString()
    }
}

// MARK: - Connection History

struct ConnectionHistoryView: View {
    @State private var connections: [ConnectionRecord] = []

    struct ConnectionRecord: Identifiable {
        let id = UUID()
        let deviceName: String
        let timestamp: Date
        let duration: TimeInterval
        let wasSuccessful: Bool
    }

    var body: some View {
        Form {
            if connections.isEmpty {
                Section {
                    Text("No connection history")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(connections) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.deviceName)
                                Text(record.timestamp, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: record.wasSuccessful ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(record.wasSuccessful ? .green : .red)
                        }
                    }
                }

                Section {
                    Button("Clear History", role: .destructive) {
                        connections.removeAll()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Connection History")
    }
}

#if os(iOS)
    import UIKit
#endif
