// TheaClipHistoryView.swift
// Thea — Clipboard History for iOS

import SwiftUI

// periphery:ignore - Reserved: AD3 audit — wired in future integration
struct TheaClipHistoryView: View {
    @StateObject private var clipManager = ClipboardHistoryManager.shared

    @State private var searchText: String = ""
    @State private var selectedFilter: String = "all"
    var onSelectEntry: ((TheaClipEntry) -> Void)?

    var body: some View {
        NavigationStack {
            List {
                if !clipManager.pinboards.isEmpty {
                    pinboardsSection
                }
                recentSection
            }
            .navigationTitle("Clipboard")
            .searchable(text: $searchText, prompt: "Search clips...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .overlay {
                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Clips" : "No Results",
                        systemImage: "doc.on.clipboard",
                        description: Text(searchText.isEmpty ? "Copy something to get started." : "Try a different search.")
                    )
                }
            }
        }
    }

    // MARK: - Pinboards

    private var pinboardsSection: some View {
        Section("Pinboards") {
            ForEach(clipManager.pinboards) { pinboard in
                NavigationLink {
                    pinboardDetail(pinboard)
                } label: {
                    Label(pinboard.name, systemImage: pinboard.icon)
                        .badge(pinboard.entries.count)
                }
            }
        }
    }

    private func pinboardDetail(_ pinboard: TheaClipPinboard) -> some View {
        List {
            ForEach(pinboard.entries.sorted { $0.sortOrder < $1.sortOrder }) { junction in
                if let entry = junction.clipEntry {
                    TheaClipRowView(entry: entry)
                        .swipeActions(edge: .trailing) {
                            Button("Remove", role: .destructive) {
                                clipManager.removeFromPinboard(entry, pinboard: pinboard)
                            }
                        }
                }
            }
        }
        .navigationTitle(pinboard.name)
    }

    // MARK: - Recent

    private var recentSection: some View {
        Section("Recent") {
            ForEach(filteredEntries) { entry in
                TheaClipRowView(entry: entry)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectEntry?(entry)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            clipManager.deleteEntry(entry)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            clipManager.toggleFavorite(entry)
                        } label: {
                            Label(
                                entry.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: entry.isFavorite ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(.yellow)
                    }
            }
        }
    }

    // MARK: - Filter

    private var filterMenu: some View {
        Menu {
            Button("All") { selectedFilter = "all" }
            Button("Favorites") { selectedFilter = "favorites" }
            Divider()
            Button("Text") { selectedFilter = "text" }
            Button("URLs") { selectedFilter = "url" }
            Button("Images") { selectedFilter = "image" }
            Button("Files") { selectedFilter = "file" }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private var filteredEntries: [TheaClipEntry] {
        var entries = clipManager.recentEntries

        switch selectedFilter {
        case "favorites":
            entries = entries.filter(\.isFavorite)
        case "text":
            entries = entries.filter { $0.contentType == .text || $0.contentType == .richText }
        case "url":
            entries = entries.filter { $0.contentType == .url }
        case "image":
            entries = entries.filter { $0.contentType == .image }
        case "file":
            entries = entries.filter { $0.contentType == .file }
        default:
            break
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            entries = entries.filter { entry in
                entry.textContent?.lowercased().contains(query) == true
                    || entry.previewText.lowercased().contains(query)
                    || entry.sourceAppName?.lowercased().contains(query) == true
            }
        }

        return entries
    }
}
