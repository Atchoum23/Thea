// DownloadManagerView.swift
// Thea — Unified download management UI
// Replaces: qBittorrent (for HTTP downloads)
//
// Download queue, progress tracking, category filters, stats.

import SwiftUI

struct DownloadManagerView: View {
    @State private var downloads: [DownloadItem] = []
    @State private var stats = DownloadStats(totalDownloads: 0, completedDownloads: 0, failedDownloads: 0, totalBytesDownloaded: 0, activeDownloads: 0)
    @State private var selectedCategory: DownloadCategory?
    @State private var urlInput = ""
    @State private var showAddSheet = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var searchText = ""

    var body: some View {
        #if os(macOS)
        HSplitView {
            sidebarPanel
                .frame(minWidth: 240, idealWidth: 280)
            downloadListPanel
                .frame(minWidth: 400)
        }
        .navigationTitle("Downloads")
        .task { await refresh() }
        #else
        NavigationStack {
            List {
                statsSection
                addSection
                activeSection
                completedSection
            }
            .navigationTitle("Downloads")
            .task { await refresh() }
            .refreshable { await refresh() }
        }
        #endif
    }

    // MARK: - macOS Panels

    #if os(macOS)
    private var sidebarPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("\(stats.totalDownloads)", systemImage: "arrow.down.circle")
                    Spacer()
                    Label(stats.formattedTotalSize, systemImage: "internaldrive")
                }
                .font(.caption)

                if stats.activeDownloads > 0 {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("\(stats.activeDownloads) active")
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            // Add URL
            HStack {
                TextField("URL to download", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await addURL() } }
                    .accessibilityLabel("Download URL")
                Button {
                    Task { await addURL() }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(urlInput.isEmpty)
                .accessibilityLabel("Add download")
            }
            .padding(.horizontal)

            Divider()

            // Category filters
            Text("Categories")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                selectedCategory = nil
            } label: {
                HStack {
                    Image(systemName: "tray.fill")
                    Text("All Downloads")
                    Spacer()
                    Text("\(downloads.count)")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .fontWeight(selectedCategory == nil ? .semibold : .regular)

            ForEach(DownloadCategory.allCases, id: \.self) { category in
                let count = downloads.filter { $0.category == category }.count
                if count > 0 {
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
                            Spacer()
                            Text("\(count)")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .fontWeight(selectedCategory == category ? .semibold : .regular)
                }
            }

            Spacer()

            // Clear button
            Button {
                Task {
                    await TheaDownloadManager.shared.clearHistory()
                    await refresh()
                }
            } label: {
                Label("Clear History", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.vertical)
    }

    private var downloadListPanel: some View {
        Group {
            if filteredDownloads.isEmpty {
                ContentUnavailableView(
                    "No Downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Paste a URL in the sidebar to start downloading")
                )
            } else {
                List {
                    ForEach(filteredDownloads) { item in
                        downloadRow(item)
                            .contextMenu {
                                downloadContextMenu(item)
                            }
                    }
                }
            }
        }
    }
    #endif

    // MARK: - iOS Sections

    private var statsSection: some View {
        Section("Overview") {
            HStack {
                Label("\(stats.completedDownloads)/\(stats.totalDownloads)", systemImage: "checkmark.circle")
                Spacer()
                Text(stats.formattedTotalSize)
                    .foregroundStyle(.secondary)
            }
            if stats.activeDownloads > 0 {
                HStack {
                    ProgressView()
                    Text("\(stats.activeDownloads) downloading")
                }
            }
        }
    }

    private var addSection: some View {
        Section("Add Download") {
            TextField("URL", text: $urlInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await addURL() } }
            Button {
                Task { await addURL() }
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .disabled(urlInput.isEmpty)
        }
    }

    @ViewBuilder
    private var activeSection: some View {
        let active = downloads.filter { !$0.status.isTerminal }
        if !active.isEmpty {
            Section("Active") {
                ForEach(active) { item in
                    downloadRow(item)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await TheaDownloadManager.shared.cancelDownload(item.id)
                                    await refresh()
                                }
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        let completed = downloads.filter { $0.status.isTerminal }
        if !completed.isEmpty {
            Section("Completed") {
                ForEach(completed.suffix(20)) { item in
                    downloadRow(item)
                }
            }
        }
    }

    // MARK: - Shared Components

    private func downloadRow(_ item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.category.icon)
                    .foregroundStyle(statusColor(item.status))
                    .frame(width: 20)
                Text(item.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: item.status.icon)
                    .foregroundStyle(statusColor(item.status))
            }

            if item.status == .downloading {
                ProgressView(value: item.progress)
                    .accessibilityLabel("Download progress \(Int(item.progress * 100))%")
                HStack {
                    Text("\(Int(item.progress * 100))%")
                    Spacer()
                    if !item.formattedSpeed.isEmpty {
                        Text(item.formattedSpeed)
                    }
                    if !item.formattedETA.isEmpty {
                        Text("ETA: \(item.formattedETA)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                HStack {
                    Text(item.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let error = item.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    } else if item.status == .completed {
                        Text(item.completedAt?.formatted(.relative(presentation: .named)) ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func downloadContextMenu(_ item: DownloadItem) -> some View {
        if item.status == .downloading {
            Button {
                Task {
                    await TheaDownloadManager.shared.pauseDownload(item.id)
                    await refresh()
                }
            } label: {
                Label("Pause", systemImage: "pause.circle")
            }
        }

        if item.status == .paused || item.status == .queued {
            Button {
                Task {
                    try? await TheaDownloadManager.shared.startDownload(item.id)
                    await refresh()
                }
            } label: {
                Label("Resume", systemImage: "play.circle")
            }
        }

        if item.status == .failed {
            Button {
                Task {
                    try? await TheaDownloadManager.shared.retryDownload(item.id)
                    await refresh()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }

        if !item.status.isTerminal {
            Button(role: .destructive) {
                Task {
                    await TheaDownloadManager.shared.cancelDownload(item.id)
                    await refresh()
                }
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        }

        Divider()

        Button(role: .destructive) {
            Task {
                await TheaDownloadManager.shared.removeDownload(item.id)
                await refresh()
            }
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func addURL() async {
        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        do {
            let item = try await TheaDownloadManager.shared.addDownload(url: url)
            urlInput = ""
            try await TheaDownloadManager.shared.startDownload(item.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func refresh() async {
        downloads = await TheaDownloadManager.shared.getDownloads()
        stats = await TheaDownloadManager.shared.getStats()
    }

    // MARK: - Helpers

    private var filteredDownloads: [DownloadItem] {
        var items = downloads
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            items = items.filter { $0.fileName.lowercased().contains(lower) }
        }
        return items.sorted { a, b in
            if a.status == .downloading && b.status != .downloading { return true }
            if a.status != .downloading && b.status == .downloading { return false }
            return a.createdAt > b.createdAt
        }
    }

    private func statusColor(_ status: DLStatus) -> Color {
        switch status {
        case .queued: .gray
        case .downloading: .blue
        case .paused: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: .gray
        }
    }
}
