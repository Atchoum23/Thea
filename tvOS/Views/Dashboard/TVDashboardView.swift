import SwiftUI

// MARK: - TV Dashboard View
// Main dashboard with Up Next, Downloads, Health Status, and Quick Actions

struct TVDashboardView: View {
    @StateObject private var traktService = TraktService.shared
    @StateObject private var mediaService = MediaAutomationService.shared
    @StateObject private var healthService = HealthMonitorService.shared
    @StateObject private var streamingService = StreamingAvailabilityService.shared

    @State private var selectedSection: DashboardSection = .upNext
    @FocusState private var focusedSection: DashboardSection?

    enum DashboardSection: String, CaseIterable {
        case upNext = "Up Next"
        case downloads = "Downloads"
        case calendar = "Calendar"
        case wanted = "Wanted"

        var icon: String {
            switch self {
            case .upNext: "play.circle.fill"
            case .downloads: "arrow.down.circle.fill"
            case .calendar: "calendar"
            case .wanted: "magnifyingglass.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    // Health Status Bar
                    healthStatusBar

                    // Section Picker
                    sectionPicker

                    // Main Content
                    mainContent

                    // Quick Stats
                    quickStats
                }
                .padding(60)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await refreshAll()
            healthService.startMonitoring(interval: 120)
        }
    }

    // MARK: - Health Status Bar

    private var healthStatusBar: some View {
        HStack(spacing: 24) {
            if let report = healthService.currentReport {
                // Overall Status
                HStack(spacing: 12) {
                    Image(systemName: report.overallStatus.icon)
                        .font(.title2)
                        .foregroundStyle(statusColor(for: report.overallStatus))

                    Text("System \(report.overallStatus.rawValue.capitalized)")
                        .font(.headline)
                }

                Spacer()

                // Network Status
                HStack(spacing: 8) {
                    Image(systemName: report.networkStatus.isConnected ? "wifi" : "wifi.slash")
                        .foregroundStyle(report.networkStatus.isConnected ? .theaSuccess : .theaError)
                    Text(report.networkStatus.connectionType)
                        .font(.subheadline)
                }

                // Storage Status
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(report.storageStatus.percentUsed > 90 ? .theaWarning : .secondary)
                    Text("\(Int(100 - report.storageStatus.percentUsed))% free")
                        .font(.subheadline)
                }

                // Active Services
                let healthyCount = report.services.filter { $0.status == .healthy }.count
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.theaSuccess)
                    Text("\(healthyCount)/\(report.services.count) services")
                        .font(.subheadline)
                }
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Checking system health...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 20) {
            ForEach(DashboardSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: section.icon)
                            .font(.title2)
                        Text(section.rawValue)
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(selectedSection == section ? Color.theaPrimaryDefault : Color.clear)
                    .foregroundStyle(selectedSection == section ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .focused($focusedSection, equals: section)
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedSection {
        case .upNext:
            upNextSection
        case .downloads:
            downloadsSection
        case .calendar:
            calendarSection
        case .wanted:
            wantedSection
        }
    }

    // MARK: - Up Next Section

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Continue Watching", count: traktService.upNext.count)

            if traktService.isLoading {
                loadingView
            } else if traktService.upNext.isEmpty {
                emptyStateView(
                    icon: "tv",
                    title: "No shows in progress",
                    subtitle: "Start watching a show to see it here"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 30) {
                        ForEach(traktService.upNext) { item in
                            UpNextCard(item: item)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Downloads Section

    private var downloadsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Download Queue", count: mediaService.downloadQueue.count)

            if mediaService.downloadQueue.isEmpty {
                emptyStateView(
                    icon: "arrow.down.circle",
                    title: "No active downloads",
                    subtitle: "Grabbed releases will appear here"
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(mediaService.downloadQueue) { item in
                        DownloadQueueRow(item: item)
                    }
                }
            }
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Upcoming Episodes", count: traktService.calendar.count)

            if traktService.calendar.isEmpty {
                emptyStateView(
                    icon: "calendar",
                    title: "No upcoming episodes",
                    subtitle: "Add shows to your watchlist to see upcoming episodes"
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(traktService.calendar.prefix(10)) { entry in
                        CalendarRow(entry: entry)
                    }
                }
            }
        }
    }

    // MARK: - Wanted Section

    private var wantedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader("Wanted Items", count: mediaService.wantedItems.count)

            if mediaService.wantedItems.isEmpty {
                emptyStateView(
                    icon: "magnifyingglass",
                    title: "No wanted items",
                    subtitle: "Add movies or shows to automatically search for them"
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(mediaService.wantedItems) { item in
                        WantedItemRow(item: item)
                    }
                }
            }
        }
    }

    // MARK: - Quick Stats

    private var quickStats: some View {
        HStack(spacing: 30) {
            StatCard(
                icon: "play.tv.fill",
                value: "\(traktService.upNext.count)",
                label: "In Progress"
            )
            StatCard(
                icon: "arrow.down.circle.fill",
                value: "\(mediaService.downloadQueue.count)",
                label: "Downloading"
            )
            StatCard(
                icon: "calendar",
                value: "\(traktService.calendar.count)",
                label: "Upcoming"
            )
            StatCard(
                icon: "magnifyingglass",
                value: "\(mediaService.wantedItems.count)",
                label: "Wanted"
            )
        }
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            if count > 0 {
                Text("\(count)")
                    .font(.callout)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.theaInfo.opacity(0.2))
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Spacer()
        }
        .frame(height: 200)
    }

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
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
        .padding(.vertical, 60)
    }

    private func statusColor(for status: HealthStatus) -> Color {
        switch status {
        case .healthy: .theaSuccess
        case .degraded: .theaWarning
        case .unhealthy: .theaError
        case .unknown: .gray
        }
    }

    // MARK: - Actions

    private func refreshAll() async {
        await traktService.refreshAll()
        await healthService.performHealthCheck()
    }
}

// MARK: - Up Next Card

struct UpNextCard: View {
    let item: TraktUpNextItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Poster placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 200, height: 300)
                .overlay {
                    Image(systemName: "tv")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                }

            // Show info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.show.title)
                    .font(.headline)
                    .lineLimit(1)

                Text("S\(item.nextEpisode.season)E\(item.nextEpisode.number)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let title = item.nextEpisode.title {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 200, alignment: .leading)

            // Progress bar
            ProgressView(value: item.progress.percentComplete, total: 100)
                .tint(.theaInfo)
                .frame(width: 200)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Download Queue Row

struct DownloadQueueRow: View {
    let item: DownloadQueueItem

    var body: some View {
        HStack(spacing: 20) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)

                Text(item.release.rawName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Progress
            if item.status == .downloading {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(item.progress * 100))%")
                        .font(.headline)
                        .monospacedDigit()

                    if let speed = item.speed {
                        Text(formatSpeed(speed))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(item.status.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusIcon: String {
        switch item.status {
        case .queued: "clock"
        case .downloading: "arrow.down.circle"
        case .paused: "pause.circle"
        case .seeding: "arrow.up.circle"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle"
        case .importing: "folder"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .queued: .secondary
        case .downloading: .theaInfo
        case .paused: .theaWarning
        case .seeding: .theaSuccess
        case .completed: .theaSuccess
        case .failed: .theaError
        case .importing: .purple
        }
    }

    private func formatSpeed(_ bytesPerSecond: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytesPerSecond) + "/s"
    }
}

// MARK: - Calendar Row

struct CalendarRow: View {
    let entry: TraktCalendarEntry

    var body: some View {
        HStack(spacing: 20) {
            // Date
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dayOfMonth)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(width: 60)

            // Show info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.show.title)
                    .font(.headline)

                HStack {
                    Text("S\(entry.episode.season)E\(entry.episode.number)")
                        .font(.subheadline)
                        .foregroundStyle(.theaInfo)

                    if let title = entry.episode.title {
                        Text("• \(title)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Time
            Text(timeString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: entry.firstAired)
    }

    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: entry.firstAired)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.firstAired)
    }
}

// MARK: - Wanted Item Row

struct WantedItemRow: View {
    let item: MediaAutomationService.WantedItem

    var body: some View {
        HStack(spacing: 20) {
            // Type icon
            Image(systemName: item.type == .movie ? "film" : "tv")
                .font(.title2)
                .foregroundStyle(.theaInfo)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)

                if let season = item.season {
                    Text("Season \(season)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Search count
            VStack(alignment: .trailing, spacing: 4) {
                Text("Searched \(item.searchCount)x")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let lastSearched = item.lastSearched {
                    Text(lastSearched, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.theaInfo)

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(width: 160)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    TVDashboardView()
}
