// TheaClipPanelView.swift
// Thea — Clipboard History Panel with sidebar navigation and visual grid

import SwiftUI

struct TheaClipPanelView: View {
    @StateObject private var clipManager = ClipboardHistoryManager.shared

    @State private var searchText: String = ""
    @State private var selectedFilter: ClipFilter = .all
    @State private var selectedEntry: TheaClipEntry?
    // periphery:ignore - Reserved: selectedPinboard property reserved for future feature activation
    @State private var selectedPinboard: TheaClipPinboard?
    @State private var showingNewPinboard = false
    @State private var newPinboardName = ""

    enum ClipFilter: Hashable {
        case all
        case favorites
        case pasteStack
        case contentType(TheaClipContentType)
        case pinboard(UUID)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
            sidebar
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            clipGrid
        }
        .frame(minWidth: 640, minHeight: 400)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search clips...")
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedFilter) {
            Section("Library") {
                Label("All Clips", systemImage: "doc.on.clipboard")
                    .tag(ClipFilter.all)
                Label("Favorites", systemImage: "star.fill")
                    .tag(ClipFilter.favorites)
                Label("Paste Stack", systemImage: "square.stack.3d.up")
                    .tag(ClipFilter.pasteStack)
            }

            Section("Content Type") {
                ForEach(TheaClipContentType.allCases, id: \.self) { type in
                    Label(type.rawValue.capitalized, systemImage: iconForType(type))
                        .tag(ClipFilter.contentType(type))
                }
            }

            Section {
                ForEach(clipManager.pinboards) { pinboard in
                    Label(pinboard.name, systemImage: pinboard.icon)
                        .tag(ClipFilter.pinboard(pinboard.id))
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                clipManager.deletePinboard(pinboard)
                            }
                        }
                }

                Button {
                    showingNewPinboard = true
                } label: {
                    Label("New Pinboard...", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } header: {
                Text("Pinboards")
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showingNewPinboard) {
            newPinboardSheet
        }
    }

    // MARK: - Clip Grid

    private var clipGrid: some View {
        ScrollView {
            let filtered = filteredEntries
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Clips" : "No Results",
                    systemImage: "doc.on.clipboard",
                    description: Text(searchText.isEmpty ? "Copy something to get started." : "Try a different search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(filtered) { entry in
                        TheaClipCardView(
                            entry: entry,
                            isSelected: selectedEntry?.id == entry.id
                        ) {
                            clipManager.pasteEntry(entry)
                        }
                        .onTapGesture {
                            selectedEntry = entry
                        }
                        .contextMenu {
                            entryContextMenu(for: entry)
                        }
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Text("\(filteredEntries.count) clips")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Filtering

    private var filteredEntries: [TheaClipEntry] {
        var entries: [TheaClipEntry]

        switch selectedFilter {
        case .all:
            entries = clipManager.recentEntries
        case .favorites:
            entries = clipManager.recentEntries.filter(\.isFavorite)
        case .pasteStack:
            entries = clipManager.pasteStack
        case let .contentType(type):
            entries = clipManager.recentEntries.filter { $0.contentType == type }
        case let .pinboard(id):
            entries = clipManager.recentEntries.filter { entry in
                entry.pinboardEntries.contains { $0.pinboard?.id == id }
            }
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

    // MARK: - Context Menu

    @ViewBuilder
    private func entryContextMenu(for entry: TheaClipEntry) -> some View {
        Button("Paste") {
            clipManager.pasteEntry(entry)
        }

        Divider()

        Button(entry.isPinned ? "Unpin" : "Pin") {
            clipManager.togglePin(entry)
        }

        Button(entry.isFavorite ? "Unfavorite" : "Favorite") {
            clipManager.toggleFavorite(entry)
        }

        if !clipManager.pinboards.isEmpty {
            Menu("Add to Pinboard") {
                ForEach(clipManager.pinboards) { pinboard in
                    Button(pinboard.name) {
                        clipManager.addToPinboard(entry, pinboard: pinboard)
                    }
                }
            }
        }

        Button("Add to Paste Stack") {
            clipManager.addToStack(entry)
        }

        Divider()

        Button("Delete", role: .destructive) {
            clipManager.deleteEntry(entry)
        }
    }

    // MARK: - New Pinboard Sheet

    private var newPinboardSheet: some View {
        VStack(spacing: 16) {
            Text("New Pinboard")
                .font(.headline)

            TextField("Pinboard Name", text: $newPinboardName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("Cancel") {
                    newPinboardName = ""
                    showingNewPinboard = false
                }

                Button("Create") {
                    let name = newPinboardName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    _ = clipManager.createPinboard(name: name)
                    newPinboardName = ""
                    showingNewPinboard = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newPinboardName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }

    // MARK: - Helpers

    private func iconForType(_ type: TheaClipContentType) -> String {
        switch type {
        case .text: "text.alignleft"
        case .richText: "text.badge.star"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .url: "link"
        case .image: "photo"
        case .file: "doc"
        case .color: "paintpalette"
        }
    }
}
