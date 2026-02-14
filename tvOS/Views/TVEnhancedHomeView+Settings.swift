import SwiftUI

// MARK: - Enhanced Settings View

struct TVEnhancedSettingsView: View {
    @ObservedObject var inferenceClient: RemoteInferenceClient

    var body: some View {
        NavigationStack {
            List {
                Section("Services") {
                    NavigationLink {
                        TVTraktSettingsView()
                    } label: {
                        SettingsRow(icon: "play.tv", color: .red, title: "Trakt", subtitle: "Calendar, watchlist, scrobbling")
                    }

                    NavigationLink {
                        Text("Plex Settings")
                    } label: {
                        SettingsRow(icon: "server.rack", color: .orange, title: "Plex", subtitle: "Media server connection")
                    }

                    NavigationLink {
                        Text("qBittorrent Settings")
                    } label: {
                        SettingsRow(icon: "arrow.down.circle", color: .blue, title: "qBittorrent", subtitle: "Download client")
                    }
                }

                Section("Streaming") {
                    NavigationLink {
                        TVStreamingSettingsView()
                    } label: {
                        SettingsRow(
                            icon: "play.rectangle.fill",
                            color: .purple,
                            title: "Streaming Accounts",
                            subtitle: "Netflix, Disney+, Canal+..."
                        )
                    }

                    NavigationLink {
                        Text("SmartDNS Settings")
                    } label: {
                        SettingsRow(icon: "network", color: .cyan, title: "NordVPN SmartDNS", subtitle: "Geo-unblocking")
                    }
                }

                Section("Automation") {
                    NavigationLink {
                        Text("Quality Profiles")
                    } label: {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            color: .green,
                            title: "Quality Profiles",
                            subtitle: "TRaSH Guides presets"
                        )
                    }

                    NavigationLink {
                        Text("Indexers")
                    } label: {
                        SettingsRow(icon: "magnifyingglass", color: .orange, title: "Indexers", subtitle: "Torrent sources")
                    }
                }

                Section("AI & Connectivity") {
                    NavigationLink {
                        TVInferenceRelaySettingsView(client: inferenceClient)
                    } label: {
                        SettingsRow(
                            icon: "desktopcomputer",
                            color: .indigo,
                            title: "Mac Connection",
                            subtitle: inferenceClient.connectionState.isConnected
                                ? "Connected to \(inferenceClient.connectedServerName ?? "Mac")"
                                : "Connect to your Mac for AI inference"
                        )
                    }
                }

                Section("System") {
                    NavigationLink {
                        TVHealthSettingsView()
                    } label: {
                        SettingsRow(icon: "heart.fill", color: .red, title: "Health Monitor", subtitle: "Service status & alerts")
                    }

                    NavigationLink {
                        Text("iCloud Sync")
                    } label: {
                        SettingsRow(icon: "icloud.fill", color: .blue, title: "iCloud Sync", subtitle: "Sync across devices")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Trakt Settings View

struct TVTraktSettingsView: View {
    @StateObject private var traktService = TraktService.shared
    @State private var clientID = ""
    @State private var clientSecret = ""

    var body: some View {
        Form {
            Section {
                if traktService.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected to Trakt")
                    }

                    Button("Disconnect", role: .destructive) {
                        traktService.logout()
                    }
                } else {
                    TextField("Client ID", text: $clientID)
                    SecureField("Client Secret", text: $clientSecret)

                    Button("Connect") {
                        traktService.configure(clientID: clientID, clientSecret: clientSecret)
                    }
                    .disabled(clientID.isEmpty || clientSecret.isEmpty)
                }
            } header: {
                Text("Account")
            } footer: {
                Text("Get your API credentials at trakt.tv/oauth/applications")
            }

            if traktService.isAuthenticated {
                Section("Data") {
                    LabeledContent("Up Next", value: "\(traktService.upNext.count) shows")
                    LabeledContent("Calendar", value: "\(traktService.calendar.count) episodes")
                    LabeledContent("Watchlist", value: "\(traktService.watchlist.count) items")

                    Button("Refresh All") {
                        Task { await traktService.refreshAll() }
                    }
                }
            }
        }
        .navigationTitle("Trakt")
    }
}

// MARK: - Streaming Settings View

struct TVStreamingSettingsView: View {
    @StateObject private var streamingService = StreamingAvailabilityService.shared

    var body: some View {
        List {
            Section("Configured Accounts") {
                ForEach(streamingService.accounts) { account in
                    HStack {
                        Image(systemName: account.appID.iconName)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(account.appID.displayName)
                            Text(account.accountName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if account.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        streamingService.removeAccount(id: streamingService.accounts[index].id)
                    }
                }
            }

            Section("Swiss Bundle") {
                Text("Canal+ Switzerland includes HBO Max and Paramount+ content via your Swisscom TV subscription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Streaming Accounts")
    }
}

// MARK: - Health Settings View

struct TVHealthSettingsView: View {
    @StateObject private var healthService = HealthMonitorService.shared

    var body: some View {
        List {
            if let report = healthService.currentReport {
                Section("Services") {
                    ForEach(report.services) { service in
                        HStack {
                            Image(systemName: service.status.icon)
                                .foregroundStyle(statusColor(service.status))
                            Text(service.name)
                            Spacer()
                            if let latency = service.latency {
                                Text("\(Int(latency * 1000))ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(service.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Alerts") {
                    if healthService.alerts.isEmpty {
                        Text("No alerts")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(healthService.alerts.filter { !$0.isAcknowledged }) { alert in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(alert.severity == .critical ? .red : .orange)
                                VStack(alignment: .leading) {
                                    Text(alert.title)
                                    Text(alert.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Toggle("Auto-monitor", isOn: .constant(healthService.isMonitoring))

                Button("Check Now") {
                    Task { await healthService.performHealthCheck() }
                }
            }
        }
        .navigationTitle("Health Monitor")
    }

    private func statusColor(_ status: HealthStatus) -> Color {
        switch status {
        case .healthy: .green
        case .degraded: .yellow
        case .unhealthy: .red
        case .unknown: .gray
        }
    }
}
