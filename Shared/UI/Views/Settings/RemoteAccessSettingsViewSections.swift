// RemoteAccessSettingsViewSections.swift
// Supporting types and views for RemoteAccessSettingsView

import SwiftUI

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
