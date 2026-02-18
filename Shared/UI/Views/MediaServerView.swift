// MediaServerView.swift
// Thea — Media server management UI
// Replaces: Plex Media Server

import SwiftUI

struct MediaServerView: View {
    @StateObject private var server = MediaServer.shared
    @State private var showAddFolder = false
    @State private var selectedType: MediaFileType?
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        Group {
            #if os(macOS)
            HSplitView {
                sidebarContent
                    .frame(minWidth: 200, maxWidth: 280)
                libraryContent
                    .frame(minWidth: 400)
            }
            #else
            NavigationStack {
                libraryList
                    .navigationTitle("Media Server")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showAddFolder = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
            }
            #endif
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Sidebar (macOS)

    #if os(macOS)
    private var sidebarContent: some View {
        List {
            serverControlSection
            foldersSection
            statsSection
        }
    }

    private var serverControlSection: some View {
        Section("Server") {
            HStack {
                Image(systemName: server.status.icon)
                    .foregroundStyle(server.status == .running ? .green : .secondary)
                Text(server.status.displayName)
                Spacer()
                if server.status == .running {
                    Button("Stop") { server.stop() }
                        .buttonStyle(.bordered)
                } else {
                    Button("Start") {
                            do {
                                try server.start()
                            } catch {
                                errorMessage = "Failed to start server: \(error.localizedDescription)"
                                showError = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                }
            }

            if server.status == .running, let url = server.serverURL {
                HStack {
                    Text(url)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy server URL")
                }
            }

            HStack {
                Text("Port")
                Spacer()
                TextField("Port", value: $server.port, format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
    #endif

    private var foldersSection: some View {
        Section {
            if server.folders.isEmpty {
                Text("No folders added")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(server.folders) { folder in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                            .font(.callout.bold())
                        HStack {
                            Text("\(folder.itemCount) items")
                            if let scanned = folder.lastScannedAt {
                                Text("· Scanned \(scanned, style: .relative)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button("Remove", role: .destructive) {
                            server.removeFolder(id: folder.id)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Library Folders")
                Spacer()
                Button {
                    showAddFolder = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add library folder")
            }
        }
        .fileImporter(isPresented: $showAddFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                do {
                    try server.addFolder(url.path)
                } catch {
                    errorMessage = "Failed to add folder: \(error.localizedDescription)"
                    showError = true
                }
                Task { await server.scanLibrary() }
            }
        }
    }

    private var statsSection: some View {
        Section("Library Stats") {
            let stats = server.libraryStats
            Label("\(stats.totalItems) total items", systemImage: "square.stack")
            if stats.videos > 0 {
                Label("\(stats.videos) videos", systemImage: "film")
            }
            if stats.audio > 0 {
                Label("\(stats.audio) audio", systemImage: "music.note")
            }
            if stats.images > 0 {
                Label("\(stats.images) images", systemImage: "photo")
            }
            Label(formattedBytes(stats.totalSize), systemImage: "internaldrive")
        }
    }

    // MARK: - Library Content

    private var libraryContent: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack(spacing: 8) {
                filterChip("All", selected: selectedType == nil) { selectedType = nil }
                ForEach(MediaFileType.allCases, id: \.self) { type in
                    let count = server.items.filter { $0.type == type }.count
                    if count > 0 {
                        filterChip("\(type.displayName) (\(count))", selected: selectedType == type) {
                            selectedType = type
                        }
                    }
                }
                Spacer()
                if server.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await server.scanLibrary() }
                    } label: {
                        Label("Scan", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            libraryList
        }
    }

    private var libraryList: some View {
        let filtered = server.filteredItems(type: selectedType, search: searchText)

        return List {
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label("No Media", systemImage: "film.stack")
                } description: {
                    Text("Add a folder and scan to populate your library.")
                } actions: {
                    Button("Add Folder") { showAddFolder = true }
                }
            } else {
                ForEach(filtered) { item in
                    mediaItemRow(item)
                }
                .onDelete { indices in
                    let items = filtered
                    for index in indices {
                        server.removeItem(id: items[index].id)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search media")
    }

    private func mediaItemRow(_ item: MediaLibraryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.icon)
                .font(.title3)
                .foregroundStyle(typeColor(item.type))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let duration = item.formattedDuration {
                        Text(duration)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if item.playCount > 0 {
                        Label("\(item.playCount)", systemImage: "play.circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if item.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }

            #if os(macOS)
            if let url = server.streamURL(for: item) {
                Link(destination: url) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play \(item.name)")
            }
            #endif
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                server.toggleFavorite(id: item.id)
            } label: {
                Label(item.isFavorite ? "Unfavorite" : "Favorite", systemImage: item.isFavorite ? "star.slash" : "star")
            }
            #if os(macOS)
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
            }
            if let url = server.streamURL(for: item) {
                Button("Copy Stream URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }
            #endif
            Divider()
            Button("Remove from Library", role: .destructive) {
                server.removeItem(id: item.id)
            }
        }
    }

    // MARK: - Helpers

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(selected ? .primary : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func typeColor(_ type: MediaFileType) -> Color {
        switch type {
        case .video: .blue
        case .audio: .purple
        case .image: .pink
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
