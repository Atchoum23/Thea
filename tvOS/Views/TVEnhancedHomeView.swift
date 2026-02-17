import SwiftUI

// MARK: - Enhanced tvOS Home View

struct TVEnhancedHomeView: View {
    @State private var selectedTab: TVTab = .dashboard
    @StateObject private var healthService = HealthMonitorService.shared
    @StateObject private var inferenceClient = RemoteInferenceClient()

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
                    .accessibilityLabel(tab.rawValue)
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
            TVEnhancedChatView(inferenceClient: inferenceClient)
        case .streaming:
            TVStreamingView()
        case .media:
            TVMediaAutomationView()
        case .settings:
            TVEnhancedSettingsView(inferenceClient: inferenceClient)
        }
    }

    @ViewBuilder
    private var alertBadge: some View {
        let unacknowledged = healthService.alerts.filter { !$0.isAcknowledged }
        if !unacknowledged.isEmpty {
            Text("\(unacknowledged.count)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color(white: 1.0))
                .padding(8)
                .background(Color.theaError)
                .clipShape(Circle())
                .padding()
                .accessibilityLabel("\(unacknowledged.count) unacknowledged health alerts")
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
                Picker("Section", selection: $selectedSection) {
                    ForEach(MediaSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 60)

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
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
            Text(title)
                .font(.title3)
                .fontWeight(.medium)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
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
        case .grabbed: Color.theaInfo
        case .imported: Color.theaSuccess
        case .upgraded: Color.theaPurpleDefault
        case .failed: Color.theaError
        case .searched: Color.theaWarning
        case .added: Color.theaSuccess
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
                                .foregroundStyle(Color.theaSuccess)
                        }
                    }

                    Text(profile.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Badge(text: profile.preferredResolution.rawValue, color: .theaInfo)
                        Badge(text: profile.minSource.rawValue, color: .purple)
                        if profile.preferHDR {
                            Badge(text: "HDR", color: .theaWarning)
                        }
                        if profile.preferAtmos {
                            Badge(text: "Atmos", color: .theaSuccess)
                        }
                    }
                }

                Spacer()

                Text("Score: \(profile.cutoffScore)+")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(isSelected ? Color.theaPrimaryDefault.opacity(0.1) : Color.clear)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.theaPrimaryDefault : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(profile.name) quality profile")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

// MARK: - Badge

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

// MARK: - Preview

#Preview {
    TVEnhancedHomeView()
}
