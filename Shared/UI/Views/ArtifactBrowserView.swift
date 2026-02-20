// ArtifactBrowserView.swift
// Thea — Artifact Browser UI
//
// Browse, search, and re-use generated artifacts (code, plans, MCP configs, etc.)
// Accessible from the sidebar under "Artifacts".

import SwiftData
import SwiftUI

// MARK: - Artifact Browser View

struct ArtifactBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GeneratedArtifact.createdAt, order: .reverse) private var artifacts: [GeneratedArtifact]

    @State private var searchText = ""
    @State private var selectedType: ArtifactType?
    @State private var selectedArtifact: GeneratedArtifact?
    @State private var showFavoritesOnly = false

    private var filteredArtifacts: [GeneratedArtifact] {
        artifacts.filter { artifact in
            let typeMatch = selectedType == nil || artifact.type == selectedType
            let favMatch = !showFavoritesOnly || artifact.isFavorite
            let searchMatch = searchText.isEmpty ||
                artifact.title.localizedCaseInsensitiveContains(searchText) ||
                artifact.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ||
                artifact.content.localizedCaseInsensitiveContains(searchText)
            return typeMatch && favMatch && searchMatch
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("Artifacts")
                .frame(minWidth: 180)
        } detail: {
            detailContent
        }
        .searchable(text: $searchText, prompt: "Search artifacts")
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selectedArtifact) {
            Section("Filter") {
                Button {
                    selectedType = nil
                    showFavoritesOnly = false
                } label: {
                    HStack {
                        Label("All Artifacts", systemImage: "square.stack.3d.up")
                        Spacer()
                        Text("\(artifacts.count)").foregroundStyle(.secondary).font(.caption)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showFavoritesOnly.toggle()
                    selectedType = nil
                } label: {
                    HStack {
                        Label("Favorites", systemImage: showFavoritesOnly ? "star.fill" : "star")
                            .foregroundStyle(showFavoritesOnly ? .yellow : .primary)
                        Spacer()
                        Text("\(artifacts.filter(\.isFavorite).count)")
                            .foregroundStyle(.secondary).font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Types") {
                ForEach(ArtifactType.allCases, id: \.self) { type in
                    Button {
                        selectedType = type == selectedType ? nil : type
                        showFavoritesOnly = false
                    } label: {
                        HStack {
                            Label(type.displayName, systemImage: type.symbolName)
                                .foregroundStyle(selectedType == type ? .accentColor : .primary)
                            Spacer()
                            Text("\(artifacts.filter { $0.type == type }.count)")
                                .foregroundStyle(.secondary).font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }

    // MARK: - Detail / List

    @ViewBuilder
    private var detailContent: some View {
        if filteredArtifacts.isEmpty {
            ContentUnavailableView(
                "No Artifacts",
                systemImage: "square.stack.3d.up",
                description: Text(searchText.isEmpty ? "Generated code, plans, and exports will appear here." : "No results for \"\(searchText)\".")
            )
        } else {
            artifactList
        }
    }

    private var artifactList: some View {
        List(filteredArtifacts, selection: $selectedArtifact) { artifact in
            ArtifactRow(artifact: artifact)
                .tag(artifact)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(artifact)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        artifact.isFavorite.toggle()
                    } label: {
                        Label(artifact.isFavorite ? "Unfavorite" : "Favorite",
                              systemImage: artifact.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
        }
        .overlay(alignment: .bottom) {
            if let selected = selectedArtifact {
                ArtifactDetailSheet(artifact: selected)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .shadow(radius: 8)
            }
        }
    }
}

// MARK: - Artifact Row

struct ArtifactRow: View {
    let artifact: GeneratedArtifact

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: artifact.type.symbolName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(artifact.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if artifact.isFavorite {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                    }
                }
                HStack(spacing: 6) {
                    Text(artifact.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                    if !artifact.language.isEmpty {
                        Text(artifact.language).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(artifact.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Artifact Detail Sheet

struct ArtifactDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var artifact: GeneratedArtifact

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(artifact.type.displayName, systemImage: artifact.type.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(artifact.characterCount) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                copyButton
                favoriteButton
            }

            Text(artifact.title)
                .font(.headline)

            if !artifact.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(artifact.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.15), in: Capsule())
                        }
                    }
                }
            }

            ScrollView {
                Text(artifact.content.prefix(500) + (artifact.content.count > 500 ? "…" : ""))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
            .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }

    private var copyButton: some View {
        Button {
            artifact.touch()
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(artifact.content, forType: .string)
            #else
            UIPasteboard.general.string = artifact.content
            #endif
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var favoriteButton: some View {
        Button {
            artifact.isFavorite.toggle()
        } label: {
            Image(systemName: artifact.isFavorite ? "star.fill" : "star")
                .foregroundStyle(artifact.isFavorite ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ArtifactBrowserView()
        .modelContainer(for: GeneratedArtifact.self, inMemory: true)
}
