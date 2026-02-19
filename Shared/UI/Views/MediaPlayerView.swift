// MediaPlayerView.swift
// Thea — Intelligent media player UI
// Replaces: IINA (video player)
//
// AVKit-based player with playback controls, bookmarks,
// chapters, history, and file import.

import AVKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaPlayerView: View {
    @StateObject private var player = MediaPlayer.shared
    @State private var showFileImporter = false
    @State private var showBookmarkSheet = false
    @State private var bookmarkLabel = ""
    @State private var bookmarkNote = ""
    @State private var selectedTab: MediaViewTab = .nowPlaying
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showError = false

    enum MediaViewTab: String, CaseIterable {
        case nowPlaying = "Now Playing"
        case history = "History"
        case favorites = "Favorites"

        var icon: String {
            switch self {
            case .nowPlaying: "play.circle"
            case .history: "clock"
            case .favorites: "heart"
            }
        }
    }

    var body: some View {
        #if os(macOS)
        macOSLayout
            .navigationTitle("Media Player")
            .alert("Playback Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        #else
        iOSLayout
            .navigationTitle("Media Player")
            .alert("Playback Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        #endif
    }

    // MARK: - macOS Layout

    #if os(macOS)
    private var macOSLayout: some View {
        HSplitView {
            // Left: Sidebar with tabs
            VStack(spacing: 0) {
                sidebarTabPicker
                Divider()
                sidebarContent
            }
            .frame(minWidth: 260, idealWidth: 300)

            // Right: Player and controls
            VStack(spacing: 0) {
                playerArea
                Divider()
                controlBar
                Divider()
                detailsArea
            }
            .frame(minWidth: 450)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: MediaPlayer.supportedUTTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    #endif

    // MARK: - iOS Layout

    // periphery:ignore - Reserved: iOSLayout property — reserved for future feature activation
    private var iOSLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Player area
                if player.currentItem != nil {
                    // periphery:ignore - Reserved: iOSLayout property reserved for future feature activation
                    compactPlayerArea
                    Divider()
                    compactControlBar
                    Divider()
                }

                // Content tabs
                Picker("Tab", selection: $selectedTab) {
                    ForEach(MediaViewTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    switch selectedTab {
                    case .nowPlaying:
                        nowPlayingSection
                    case .history:
                        historySection
                    case .favorites:
                        favoritesSection
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Open File", systemImage: "folder.badge.plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: MediaPlayer.supportedUTTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarTabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(MediaViewTab.allCases, id: \.self) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(8)
    }

    @ViewBuilder
    private var sidebarContent: some View {
        switch selectedTab {
        case .nowPlaying:
            nowPlayingSidebar
        case .history:
            historySidebar
        case .favorites:
            favoritesSidebar
        }
    }

    private var nowPlayingSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stats
            statsBar

            Divider()

            // Open file button
            Button {
                showFileImporter = true
            } label: {
                Label("Open Media File", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 8)

            Divider()

            // Bookmarks for current item
            if let item = player.currentItem, !item.bookmarks.isEmpty {
                Text("Bookmarks")
                    .font(.headline)
                    .padding(.horizontal, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(item.bookmarks) { bookmark in
                            bookmarkRow(bookmark)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            // Chapters
            if let item = player.currentItem, !item.chapters.isEmpty {
                Text("Chapters")
                    .font(.headline)
                    .padding(.horizontal, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(item.chapters) { chapter in
                            chapterRow(chapter)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            Spacer()
        }
        .padding(.top, 8)
    }

    private var historySidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search history...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            List {
                ForEach(filteredHistory) { item in
                    historyRow(item)
                }
                .onDelete { offsets in
                    deleteHistoryItems(at: offsets)
                }
            }
            .listStyle(.plain)
        }
    }

    private var favoritesSidebar: some View {
        List {
            ForEach(player.favorites()) { item in
                historyRow(item)
            }
        }
        .listStyle(.plain)
        .overlay {
            if player.favorites().isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "heart",
                    description: Text("Mark items as favorites to see them here")
                )
            }
        }
    }

    // MARK: - Player Area

    #if os(macOS)
    private var playerArea: some View {
        Group {
            if let avPlayer = player.player {
                VideoPlayer(player: avPlayer)
                    .frame(minHeight: 250)
                    .accessibilityLabel("Video player")
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("Open a media file to start playing")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Button("Open File") {
                        showFileImporter = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.05))
            }
        }
    }
    #endif

    // periphery:ignore - Reserved: compactPlayerArea property — reserved for future feature activation
    private var compactPlayerArea: some View {
        Group {
            if let avPlayer = player.player, player.currentItem?.mediaType == .video {
                VideoPlayer(player: avPlayer)
                    // periphery:ignore - Reserved: compactPlayerArea property reserved for future feature activation
                    .frame(height: 220)
                    .accessibilityLabel("Video player")
            } else if let item = player.currentItem {
                VStack(spacing: 8) {
                    Image(systemName: item.mediaType.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color.black.opacity(0.05))
            }
        }
    }

    // MARK: - Control Bar

    #if os(macOS)
    private var controlBar: some View {
        VStack(spacing: 8) {
            // Progress slider
            HStack(spacing: 8) {
                Text(MediaPlayer.formatDuration(player.currentTime))
                    .font(.caption.monospacedDigit())
                    .frame(width: 60, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )
                .accessibilityLabel("Playback position")

                Text(MediaPlayer.formatDuration(player.duration))
                    .font(.caption.monospacedDigit())
                    .frame(width: 60, alignment: .leading)
            }
            .padding(.horizontal, 12)

            // Transport controls
            HStack(spacing: 16) {
                // Speed
                Menu {
                    ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                        Button {
                            player.setSpeed(speed)
                        } label: {
                            HStack {
                                Text(speed.displayName)
                                if player.speed == speed {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(player.speed.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .accessibilityLabel("Playback speed")

                Spacer()

                Button { player.skipBackward() } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                }
                .accessibilityLabel("Skip back 10 seconds")

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.status == .playing ? "pause.fill" : "play.fill")
                        .font(.title)
                }
                .accessibilityLabel(player.status == .playing ? "Pause" : "Play")

                Button { player.skipForward() } label: {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                }
                .accessibilityLabel("Skip forward 10 seconds")

                Spacer()

                // Volume
                HStack(spacing: 4) {
                    Button { player.toggleMute() } label: {
                        Image(systemName: volumeIcon)
                            .font(.caption)
                    }
                    .accessibilityLabel("Toggle mute")

                    Slider(
                        value: Binding(
                            get: { Double(player.volume) },
                            set: { player.setVolume(Float($0)) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 80)
                    .accessibilityLabel("Volume")
                }

                // Bookmark
                Button {
                    bookmarkLabel = "Bookmark at \(MediaPlayer.formatDuration(player.currentTime))"
                    bookmarkNote = ""
                    showBookmarkSheet = true
                } label: {
                    Image(systemName: "bookmark")
                        .font(.caption)
                }
                .accessibilityLabel("Add bookmark")
                .disabled(player.currentItem == nil)

                // Favorite
                Button { player.toggleFavorite() } label: {
                    Image(systemName: player.currentItem?.isFavorite == true ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundStyle(player.currentItem?.isFavorite == true ? .red : .secondary)
                }
                .accessibilityLabel("Toggle favorite")
                .disabled(player.currentItem == nil)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showBookmarkSheet) {
            bookmarkSheet
        }
    }
    #endif

    // periphery:ignore - Reserved: compactControlBar property — reserved for future feature activation
    private var compactControlBar: some View {
        VStack(spacing: 8) {
            // Progress
            // periphery:ignore - Reserved: compactControlBar property reserved for future feature activation
            HStack(spacing: 4) {
                Text(MediaPlayer.formatDuration(player.currentTime))
                    .font(.caption2.monospacedDigit())

                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )

                Text(MediaPlayer.formatDuration(player.duration))
                    .font(.caption2.monospacedDigit())
            }
            .padding(.horizontal)

            // Controls
            HStack(spacing: 24) {
                Button { player.skipBackward() } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title3)
                }

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.status == .playing ? "pause.fill" : "play.fill")
                        .font(.title2)
                }

                Button { player.skipForward() } label: {
                    Image(systemName: "goforward.10")
                        .font(.title3)
                }

                Spacer()

                Menu {
                    ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                        Button(speed.displayName) { player.setSpeed(speed) }
                    }
                } label: {
                    Text(player.speed.displayName)
                        .font(.caption)
                }

                Button {
                    bookmarkLabel = "Bookmark at \(MediaPlayer.formatDuration(player.currentTime))"
                    bookmarkNote = ""
                    showBookmarkSheet = true
                } label: {
                    Image(systemName: "bookmark")
                }
                .disabled(player.currentItem == nil)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showBookmarkSheet) {
            bookmarkSheet
        }
    }

    // MARK: - Details Area

    #if os(macOS)
    private var detailsArea: some View {
        Group {
            if let item = player.currentItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: item.mediaType.icon)
                            Text(item.title)
                                .font(.headline)
                            Spacer()
                            if let res = item.resolution {
                                Text(res)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }

                        HStack(spacing: 16) {
                            if let size = item.formattedFileSize {
                                Label(size, systemImage: "doc")
                                    .font(.caption)
                            }
                            Label(item.formattedDuration, systemImage: "clock")
                                .font(.caption)
                            Label("\(item.playCount) plays", systemImage: "play.circle")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding(12)
                }
                .frame(maxHeight: 80)
            } else {
                EmptyView()
            }
        }
    }
    #endif

    // MARK: - List Sections (iOS / Sidebar)

    // periphery:ignore - Reserved: nowPlayingSection property — reserved for future feature activation
    private var nowPlayingSection: some View {
        Group {
            // periphery:ignore - Reserved: nowPlayingSection property reserved for future feature activation
            if let item = player.currentItem {
                Section("Now Playing") {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(item.title, systemImage: item.mediaType.icon)
                            .font(.headline)
                        HStack {
                            Text(item.formattedLastPosition)
                            Text("/")
                            Text(item.formattedDuration)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        ProgressView(value: item.progress)
                    }
                }

                if !item.bookmarks.isEmpty {
                    Section("Bookmarks") {
                        ForEach(item.bookmarks) { bookmark in
                            bookmarkRow(bookmark)
                        }
                    }
                }

                if !item.chapters.isEmpty {
                    Section("Chapters") {
                        ForEach(item.chapters) { chapter in
                            chapterRow(chapter)
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "No Media Playing",
                        systemImage: "play.rectangle",
                        description: Text("Open a file to start playing")
                    )
                }
            }
        }
    }

    // periphery:ignore - Reserved: historySection property — reserved for future feature activation
    private var historySection: some View {
        // periphery:ignore - Reserved: historySection property reserved for future feature activation
        Section("Recent (\(player.history.count))") {
            ForEach(filteredHistory) { item in
                historyRow(item)
            }
            .onDelete { offsets in
                deleteHistoryItems(at: offsets)
            }
        }
    }

    // periphery:ignore - Reserved: favoritesSection property reserved for future feature activation
    private var favoritesSection: some View {
        Section("Favorites") {
            ForEach(player.favorites()) { item in
                historyRow(item)
            }
        }
    }

    // MARK: - Stats

    private var statsBar: some View {
        let stats = player.getStats()
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("\(stats.totalItemsPlayed)", systemImage: "film.stack")
                    .font(.caption)
                Spacer()
                Label(stats.formattedPlayTime, systemImage: "clock")
                    .font(.caption)
            }
            HStack {
                Label("\(stats.videoCount)", systemImage: "film")
                    .font(.caption2)
                Label("\(stats.audioCount)", systemImage: "music.note")
                    .font(.caption2)
                Label("\(stats.favoriteCount)", systemImage: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Row Builders

    private func bookmarkRow(_ bookmark: MediaBookmark) -> some View {
        Button {
            player.jumpToBookmark(bookmark)
        } label: {
            HStack {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text(bookmark.label)
                        .font(.caption)
                        .lineLimit(1)
                    Text(bookmark.formattedTimestamp)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                player.removeBookmark(id: bookmark.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func chapterRow(_ chapter: MediaChapter) -> some View {
        Button {
            player.jumpToChapter(chapter)
        } label: {
            HStack {
                Image(systemName: "list.number")
                    .font(.caption)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading) {
                    Text(chapter.title)
                        .font(.caption)
                        .lineLimit(1)
                    Text(chapter.formattedStart)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func historyRow(_ item: PlayedMediaItem) -> some View {
        Button {
            Task {
                do {
                    guard let url = URL(string: item.url) else { return }
                    try await player.open(url: url)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.mediaType.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.caption)
                        .lineLimit(1)
                    HStack {
                        Text(item.formattedDuration)
                        if item.progress > 0 && item.progress < 1 {
                            ProgressView(value: item.progress)
                                .frame(width: 40)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if item.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { player.toggleFavorite(id: item.id) } label: {
                Label(
                    item.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: item.isFavorite ? "heart.slash" : "heart"
                )
            }
            Button(role: .destructive) {
                player.removeFromHistory(id: item.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    // MARK: - Bookmark Sheet

    private var bookmarkSheet: some View {
        VStack(spacing: 16) {
            Text("Add Bookmark")
                .font(.headline)

            TextField("Label", text: $bookmarkLabel)
                .textFieldStyle(.roundedBorder)

            TextField("Note (optional)", text: $bookmarkNote)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showBookmarkSheet = false
                }

                Spacer()

                Button("Save") {
                    player.addBookmark(
                        label: bookmarkLabel,
                        note: bookmarkNote.isEmpty ? nil : bookmarkNote
                    )
                    showBookmarkSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(bookmarkLabel.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Helpers

    private var filteredHistory: [PlayedMediaItem] {
        if searchText.isEmpty {
            return player.history
        }
        return player.search(query: searchText)
    }

    private var volumeIcon: String {
        if player.volume == 0 { return "speaker.slash.fill" }
        if player.volume < 0.33 { return "speaker.fill" }
        if player.volume < 0.66 { return "speaker.wave.1.fill" }
        return "speaker.wave.3.fill"
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            Task {
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    try await player.open(url: url)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteHistoryItems(at offsets: IndexSet) {
        let items = filteredHistory
        for offset in offsets {
            player.removeFromHistory(id: items[offset].id)
        }
    }
}
