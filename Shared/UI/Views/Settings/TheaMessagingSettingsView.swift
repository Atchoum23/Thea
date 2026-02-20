import SwiftUI

// MARK: - Thea Messaging Settings View
// Credentials + settings for Thea's native messaging gateway.
// Accessible from MacSettingsView sidebar ("Messaging") and iOS Settings.

struct TheaMessagingSettingsView: View {
    @ObservedObject private var gateway = TheaMessagingGateway.shared
    @ObservedObject private var sessions = MessagingSessionManager.shared

    var body: some View {
        Form {
            gatewayStatusSection
            platformsSection
            sessionsSection
            securitySection
        }
        .formStyle(.grouped)
        .navigationTitle("Messaging Gateway")
    }

    // MARK: - Gateway Status Section

    private var gatewayStatusSection: some View {
        Section("Gateway Status") {
            HStack(spacing: 12) {
                Image(systemName: gateway.connectedPlatforms.isEmpty
                      ? "antenna.radiowaves.left.and.right.slash"
                      : "antenna.radiowaves.left.and.right")
                    .foregroundStyle(gateway.connectedPlatforms.isEmpty ? .red : .green)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(gateway.isRunning ? "Gateway Running" : "Gateway Stopped")
                        .font(.headline)
                    Text(gateway.connectedPlatforms.isEmpty
                         ? "No platforms connected"
                         : gateway.connectedPlatforms.map(\.displayName).sorted().joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Port 18789")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)

            if let err = gateway.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Platform Credentials Section

    private var platformsSection: some View {
        Section("Platform Credentials") {
            ForEach(MessagingPlatform.allCases, id: \.self) { platform in
                PlatformCredentialRow(platform: platform)
            }
        }
    }

    // MARK: - Sessions Section

    private var sessionsSection: some View {
        Section("Sessions") {
            LabeledContent("Active Sessions", value: "\(sessions.activeSessions.count)")
            Button(role: .destructive) {
                sessions.resetAll()
            } label: {
                Label("Reset All Sessions", systemImage: "trash")
            }
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section("Security") {
            Label("22-pattern injection guard active", systemImage: "shield.fill")
                .foregroundStyle(.green)
            Label("Rate limit: 5 responses/min/platform", systemImage: "timer")
                .foregroundStyle(.secondary)
            Label("Privacy guard on all outbound messages", systemImage: "lock.fill")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Platform Credential Row

private struct PlatformCredentialRow: View {
    let platform: MessagingPlatform
    @State private var credentials: MessagingCredentials
    @State private var isExpanded = false
    @ObservedObject private var gateway = TheaMessagingGateway.shared

    init(platform: MessagingPlatform) {
        self.platform = platform
        _credentials = State(initialValue: MessagingCredentialsStore.load(for: platform))
    }

    var isConnected: Bool { gateway.connectedPlatforms.contains(platform) }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            credentialFields
        } label: {
            HStack {
                Image(systemName: platform.symbolName)
                    .foregroundStyle(isConnected ? .green : .secondary)
                    .frame(width: 24)
                Text(platform.displayName)
                Spacer()
                Toggle("", isOn: $credentials.isEnabled)
                    .labelsHidden()
                    .onChange(of: credentials.isEnabled) { _, enabled in
                        credentials.isEnabled = enabled
                        saveAndRestart()
                    }
            }
        }
    }

    @ViewBuilder
    private var credentialFields: some View {
        switch platform {
        case .telegram:
            SecureField("Bot Token (from @BotFather)", text: bindToken)
                .textContentType(.password)
            saveButton

        case .discord:
            SecureField("Bot Token (Discord Developer Portal)", text: bindToken)
                .textContentType(.password)
            saveButton

        case .slack:
            SecureField("Bot Token (xoxb-…)", text: bindToken)
                .textContentType(.password)
            SecureField("App-Level Token (xapp-… for Socket Mode)", text: bindApiKey)
                .textContentType(.password)
            saveButton

        case .imessage:
            TextField("BlueBubbles Server URL (e.g. http://localhost:1234)", text: bindServerUrl)
                .textContentType(.URL)
            SecureField("BlueBubbles Password", text: bindApiKey)
                .textContentType(.password)
            saveButton

        case .whatsapp:
            SecureField("Access Token", text: bindToken)
                .textContentType(.password)
            TextField("Phone Number ID", text: bindApiKey)
            SecureField("Webhook Verify Token", text: bindWebhookSecret)
                .textContentType(.password)
            saveButton

        case .signal:
            TextField("Registered Phone (e.g. +15555550123)", text: bindServerUrl)
                .textContentType(.telephoneNumber)
            Text("Requires: brew install signal-cli && signal-cli -a <phone> register")
                .font(.caption)
                .foregroundStyle(.secondary)
            saveButton

        case .matrix:
            TextField("Homeserver URL (e.g. https://matrix.org)", text: bindServerUrl)
                .textContentType(.URL)
            SecureField("Access Token", text: bindApiKey)
                .textContentType(.password)
            saveButton

        case .browser:
            Text("Browser integration via Native Host extension — no credentials needed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var saveButton: some View {
        Button("Save & Connect") { saveAndRestart() }
            .buttonStyle(.borderedProminent)
    }

    private func saveAndRestart() {
        MessagingCredentialsStore.save(credentials, for: platform)
        Task { await TheaMessagingGateway.shared.restartConnector(for: platform) }
    }

    // MARK: Bindings

    private var bindToken: Binding<String> {
        Binding(get: { credentials.botToken ?? "" },
                set: { credentials.botToken = $0.isEmpty ? nil : $0 })
    }
    private var bindApiKey: Binding<String> {
        Binding(get: { credentials.apiKey ?? "" },
                set: { credentials.apiKey = $0.isEmpty ? nil : $0 })
    }
    private var bindServerUrl: Binding<String> {
        Binding(get: { credentials.serverUrl ?? "" },
                set: { credentials.serverUrl = $0.isEmpty ? nil : $0 })
    }
    private var bindWebhookSecret: Binding<String> {
        Binding(get: { credentials.webhookSecret ?? "" },
                set: { credentials.webhookSecret = $0.isEmpty ? nil : $0 })
    }
}
