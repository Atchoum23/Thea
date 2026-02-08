import SwiftUI

// MARK: - Enhanced tvOS Home View
// Main navigation hub with all features from Tizen app ported to tvOS

struct TVEnhancedHomeView: View {
    @State private var selectedTab: TVTab = .dashboard
    @StateObject private var healthService = HealthMonitorService.shared

    enum TVTab: String, CaseIterable {
        case dashboard = "Dashboard"
        case chat = "Chat"
        case streaming = "Streaming"
        case media = "Media"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: "square.grid.2x2.fill"
            case .chat: "message.fill"
            case .streaming: "play.tv.fill"
            case .media: "film.stack.fill"
            case .settings: "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(TVTab.allCases, id: \.self) { tab in
                viewForTab(tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .overlay(alignment: .topTrailing) {
            alertBadge
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: TVTab) -> some View {
        switch tab {
        case .dashboard:
            TVDashboardView()
        case .chat:
            TVEnhancedChatView()
        case .streaming:
            TVStreamingView()
        case .media:
            TVMediaAutomationView()
        case .settings:
            TVEnhancedSettingsView()
        }
    }

    @ViewBuilder
    private var alertBadge: some View {
        let unacknowledged = healthService.alerts.filter { !$0.isAcknowledged }
        if !unacknowledged.isEmpty {
            Text("\(unacknowledged.count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(8)
                .background(.red)
                .clipShape(Circle())
                .padding()
        }
    }
}

// MARK: - Enhanced Chat View

struct TVEnhancedChatView: View {
    @StateObject private var inferenceClient = RemoteInferenceClient()
    @State private var messages: [TVChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var activeRequestId: String?
    @State private var suggestedPrompts: [String] = [
        "What's on my calendar today?",
        "Find new releases this week",
        "Check download queue status",
        "What should I watch tonight?"
    ]
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionBanner

                if messages.isEmpty {
                    welcomeView
                } else {
                    messagesList
                }

                inputArea
            }
            .navigationTitle("Thea")
        }
        .onAppear { setupStreamCallbacks() }
    }

    // MARK: - Connection Banner

    @ViewBuilder
    private var connectionBanner: some View {
        if !inferenceClient.connectionState.isConnected {
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Not connected to Mac — responses are simulated")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    private var welcomeView: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo
            Image(systemName: "brain.head.profile")
                .font(.system(size: 120))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Text("Welcome to THEA")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your AI Life Companion")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Suggested prompts
            VStack(spacing: 16) {
                Text("Try asking:")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    ForEach(suggestedPrompts.prefix(4), id: \.self) { prompt in
                        Button {
                            inputText = prompt
                            sendMessage()
                        } label: {
                            Text(prompt)
                                .font(.callout)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(messages) { message in
                        TVChatMessageRow(message: message)
                            .id(message.id)
                    }

                    if isProcessing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding()
                    }
                }
                .padding(40)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputArea: some View {
        HStack(spacing: 16) {
            // Voice input button
            Button {
                // Trigger Siri voice input
            } label: {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Text input
            TextField("Ask Thea anything...", text: $inputText)
                .font(.title3)
                .focused($isInputFocused)
                .onSubmit(sendMessage)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    // MARK: - Send Message

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = TVChatMessage(content: text, isUser: true)
        messages.append(userMessage)
        inputText = ""
        isProcessing = true

        if inferenceClient.connectionState.isConnected {
            sendViaRelay(text: text)
        } else {
            sendSimulated(text: text)
        }
    }

    /// Send chat via the macOS inference relay (real AI response).
    private func sendViaRelay(text: String) {
        // Build conversation context from recent messages
        let conversationMessages = messages.suffix(20).map { msg -> (role: String, content: String) in
            (role: msg.isUser ? "user" : "assistant", content: msg.content)
        }

        // Create a placeholder assistant message for streaming
        let assistantMessage = TVChatMessage(content: "", isUser: false, isStreaming: true)
        messages.append(assistantMessage)

        Task {
            do {
                let requestId = try await inferenceClient.sendInferenceRequest(
                    messages: conversationMessages
                )
                activeRequestId = requestId
            } catch {
                // Replace streaming placeholder with error message
                if let idx = messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                    messages[idx] = TVChatMessage(
                        content: "Failed to send request: \(error.localizedDescription)",
                        isUser: false
                    )
                }
                isProcessing = false
            }
        }
    }

    /// Fallback: simulated responses when not connected to a Mac server.
    private func sendSimulated(text: String) {
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            let response = TVChatMessage(
                content: generateFallbackResponse(for: text),
                isUser: false
            )
            messages.append(response)
            isProcessing = false
        }
    }

    // MARK: - Stream Callbacks

    private func setupStreamCallbacks() {
        inferenceClient.onStreamDelta = { [self] _, delta in
            Task { @MainActor in
                // Append delta to the last assistant (streaming) message
                if let idx = messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                    messages[idx].content += delta
                }
            }
        }

        inferenceClient.onStreamComplete = { [self] _, complete in
            Task { @MainActor in
                // Finalize the streaming message
                if let idx = messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                    messages[idx].content = complete.fullText
                    messages[idx].isStreaming = false
                    messages[idx].modelName = complete.model
                }
                isProcessing = false
                activeRequestId = nil
            }
        }

        inferenceClient.onStreamError = { [self] _, errorDesc in
            Task { @MainActor in
                if let idx = messages.lastIndex(where: { !$0.isUser && $0.isStreaming }) {
                    messages[idx].content = "Error: \(errorDesc)"
                    messages[idx].isStreaming = false
                }
                isProcessing = false
                activeRequestId = nil
            }
        }
    }

    // MARK: - Fallback Response

    private func generateFallbackResponse(for query: String) -> String {
        let lower = query.lowercased()

        if lower.contains("calendar") || lower.contains("today") {
            return "I'm not connected to your Mac right now, so I can't check your calendar. Connect to your Mac server in Settings → Mac Connection to enable AI responses."
        }

        if lower.contains("watch") || lower.contains("recommend") {
            return "I'd love to give you personalized recommendations, but I need to be connected to your Mac server for AI inference. Go to Settings → Mac Connection to set up the connection."
        }

        return "I'm running in offline mode without AI inference. To get real AI responses:\n\n1. Make sure Thea is running on your Mac\n2. Enable Remote Server in Thea's Mac settings\n3. Go to Settings → Mac Connection on this Apple TV\n4. Select your Mac from the list\n\nOnce connected, I'll route your questions through your Mac's AI models!"
    }
}

// MARK: - Chat Message Model

struct TVChatMessage: Identifiable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let timestamp = Date()
    var isStreaming = false
    var modelName: String?
}

struct TVChatMessageRow: View {
    let message: TVChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if message.isUser { Spacer(minLength: 200) }

            if !message.isUser {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if message.content.isEmpty && message.isStreaming {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    HStack(spacing: 0) {
                        Text(message.content)
                            .font(.body)

                        if message.isStreaming {
                            Text("▊")
                                .foregroundStyle(.blue)
                                .opacity(0.8)
                        }
                    }
                    .padding(20)
                    .background(message.isUser ? Color.blue : Color.secondary.opacity(0.2))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                if let model = message.modelName {
                    Text(model)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if message.isUser {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }

            if !message.isUser { Spacer(minLength: 200) }
        }
    }
}

// MARK: - Media Automation View

struct TVMediaAutomationView: View {
    @StateObject private var mediaService = MediaAutomationService.shared
    @State private var selectedSection: MediaSection = .queue

    enum MediaSection: String, CaseIterable {
        case queue = "Queue"
        case wanted = "Wanted"
        case activity = "Activity"
        case profiles = "Profiles"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Section picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(MediaSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 60)

                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedSection {
                        case .queue:
                            queueContent
                        case .wanted:
                            wantedContent
                        case .activity:
                            activityContent
                        case .profiles:
                            profilesContent
                        }
                    }
                    .padding(60)
                }
            }
            .navigationTitle("Media Automation")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        mediaService.isMonitoring ? mediaService.stopMonitoring() : mediaService.startMonitoring()
                    } label: {
                        HStack {
                            Image(systemName: mediaService.isMonitoring ? "stop.fill" : "play.fill")
                            Text(mediaService.isMonitoring ? "Stop" : "Start")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        if mediaService.downloadQueue.isEmpty {
            emptyState(icon: "arrow.down.circle", title: "No downloads", subtitle: "Grabbed releases will appear here")
        } else {
            ForEach(mediaService.downloadQueue) { item in
                DownloadQueueRow(item: item)
            }
        }
    }

    @ViewBuilder
    private var wantedContent: some View {
        if mediaService.wantedItems.isEmpty {
            emptyState(icon: "magnifyingglass", title: "No wanted items", subtitle: "Add content to search automatically")
        } else {
            ForEach(mediaService.wantedItems) { item in
                WantedItemRow(item: item)
            }
        }
    }

    @ViewBuilder
    private var activityContent: some View {
        if mediaService.recentActivity.isEmpty {
            emptyState(icon: "clock", title: "No recent activity", subtitle: "Actions will be logged here")
        } else {
            ForEach(mediaService.recentActivity) { entry in
                ActivityRow(entry: entry)
            }
        }
    }

    private var profilesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quality Profiles")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(QualityProfile.presets) { profile in
                QualityProfileCard(
                    profile: profile,
                    isSelected: mediaService.selectedProfile.id == profile.id
                ) {
                    mediaService.selectedProfile = profile
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3)
                .fontWeight(.medium)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let entry: MediaAutomationService.ActivityLogEntry

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconForType)
                .foregroundStyle(colorForType)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var iconForType: String {
        switch entry.type {
        case .grabbed: "arrow.down.circle.fill"
        case .imported: "checkmark.circle.fill"
        case .upgraded: "arrow.up.circle.fill"
        case .failed: "xmark.circle.fill"
        case .searched: "magnifyingglass"
        case .added: "plus.circle.fill"
        case .removed: "minus.circle.fill"
        }
    }

    private var colorForType: Color {
        switch entry.type {
        case .grabbed: .blue
        case .imported: .green
        case .upgraded: .purple
        case .failed: .red
        case .searched: .orange
        case .added: .green
        case .removed: .secondary
        }
    }
}

// MARK: - Quality Profile Card

struct QualityProfileCard: View {
    let profile: QualityProfile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(profile.name)
                            .font(.headline)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    Text(profile.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Badge(text: profile.preferredResolution.rawValue, color: .blue)
                        Badge(text: profile.minSource.rawValue, color: .purple)
                        if profile.preferHDR {
                            Badge(text: "HDR", color: .orange)
                        }
                        if profile.preferAtmos {
                            Badge(text: "Atmos", color: .green)
                        }
                    }
                }

                Spacer()

                Text("Score: \(profile.cutoffScore)+")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Enhanced Settings View

struct TVEnhancedSettingsView: View {
    @StateObject private var inferenceClient = RemoteInferenceClient()

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
                        SettingsRow(icon: "play.rectangle.fill", color: .purple, title: "Streaming Accounts", subtitle: "Netflix, Disney+, Canal+...")
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
                        SettingsRow(icon: "slider.horizontal.3", color: .green, title: "Quality Profiles", subtitle: "TRaSH Guides presets")
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
                        // Would trigger OAuth flow
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

// MARK: - Preview

#Preview {
    TVEnhancedHomeView()
}
