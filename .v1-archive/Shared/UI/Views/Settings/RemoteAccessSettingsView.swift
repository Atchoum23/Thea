// RemoteAccessSettingsView.swift
// Settings for remote session and device management

import SwiftUI

struct RemoteAccessSettingsView: View {
    @State private var serverEnabled = false
    @State private var serverPort: Int = 8081
    @State private var requireAuthentication = true
    @State private var discoveryEnabled = true
    @State private var deviceName = ""
    @State private var discoveredDevices: [DiscoveredDeviceInfo] = []
    @State private var isScanning = false

    var body: some View {
        Form {
            Section("Remote Access") {
                Text("Connect to Thea running on other devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Server") {
                Toggle("Enable Remote Server", isOn: $serverEnabled)
                    .onChange(of: serverEnabled) { _, enabled in
                        if enabled {
                            startServer()
                        } else {
                            stopServer()
                        }
                    }

                if serverEnabled {
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("Port", value: $serverPort, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("Require Authentication", isOn: $requireAuthentication)

                    LabeledContent("Server Status", value: "Running")
                        .foregroundStyle(.green)
                }
            }

            Section("Device Discovery") {
                Toggle("Enable Discovery", isOn: $discoveryEnabled)
                    .help("Allow other devices to find this Thea instance")

                TextField("Device Name", text: $deviceName)
                    .textFieldStyle(.roundedBorder)

                if discoveryEnabled {
                    LabeledContent("Broadcast Status", value: "Active")
                        .foregroundStyle(.green)
                }
            }

            Section("Discovered Devices") {
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

            Section("Connected Sessions") {
                Text("No active sessions")
                    .foregroundStyle(.secondary)
            }

            Section("Security") {
                NavigationLink("Authentication Settings") {
                    RemoteAuthenticationSettingsView()
                }

                NavigationLink("Connection History") {
                    ConnectionHistoryView()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Remote Access")
        .onAppear {
            loadDeviceName()
        }
    }

    private func loadDeviceName() {
        #if os(macOS)
        deviceName = Host.current().localizedName ?? "Mac"
        #else
        deviceName = UIDevice.current.name
        #endif
    }

    private func startServer() {
        // Would start the remote server
    }

    private func stopServer() {
        // Would stop the remote server
    }

    private func scanForDevices() {
        isScanning = true
        // Simulate scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isScanning = false
        }
    }

    private func connectToDevice(_ device: DiscoveredDeviceInfo) {
        // Would establish connection
    }
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
                    Text("•")
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
        // Generate a random token
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
