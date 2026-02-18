// WebClipperView.swift
// Thea — Article clipping UI
// Replaces: PrintFriendly

import SwiftUI

struct WebClipperView: View {
    @State private var clipper = WebClipper.shared
    @State private var urlInput = ""
    @State private var searchQuery = ""
    @State private var selectedArticle: ClippedArticle?
    @State private var showExportSheet = false

    var body: some View {
        #if os(macOS)
        HSplitView {
            articleList
                .frame(minWidth: 250, maxWidth: 350)
            detailView
                .frame(minWidth: 400)
        }
        #else
        NavigationStack {
            articleList
                .navigationTitle("Web Clipper")
        }
        #endif
    }

    // MARK: - Article List

    private var articleList: some View {
        VStack(spacing: 0) {
            // URL input
            HStack {
                TextField("Paste URL to clip...", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { clipURL() }

                Button(action: clipURL) {
                    if clipper.isClipping {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperclip")
                    }
                }
                .disabled(urlInput.isEmpty || clipper.isClipping)
            }
            .padding()

            // Search
            TextField("Search articles...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // Stats
            HStack {
                Text("\(filteredArticles.count) articles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                let totalWords = filteredArticles.reduce(0) { $0 + $1.wordCount }
                Text("\(totalWords) words total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            Divider()

            // Article list
            List(selection: Binding(
                get: { selectedArticle?.id },
                set: { id in selectedArticle = clipper.articles.first { $0.id == id } }
            )) {
                ForEach(filteredArticles) { article in
                    articleRow(article)
                        .tag(article.id)
                        .contextMenu {
                            Button("Toggle Favorite") { clipper.toggleFavorite(article.id) }
                            Divider()
                            Button("Delete", role: .destructive) { clipper.deleteArticle(article) }
                        }
                }
            }
            .overlay {
                if filteredArticles.isEmpty {
                    ContentUnavailableView(
                        clipper.articles.isEmpty ? "No Clipped Articles" : "No Results",
                        systemImage: clipper.articles.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass",
                        description: Text(clipper.articles.isEmpty
                            ? "Paste a URL above to clip an article."
                            : "No articles match your search.")
                    )
                }
            }
        }
    }

    private func articleRow(_ article: ClippedArticle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if article.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                Text(article.title)
                    .font(.body)
                    .lineLimit(2)
            }
            HStack {
                if let site = article.siteName {
                    Text(site)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text("\(article.readingTimeMinutes) min read")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(article.excerpt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail View

    private var detailView: some View {
        Group {
            if let article = selectedArticle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(article.title)
                                .font(.title)
                                .fontWeight(.bold)

                            HStack {
                                if let author = article.author {
                                    Label(author, systemImage: "person")
                                        .font(.subheadline)
                                }
                                if let site = article.siteName {
                                    Label(site, systemImage: "globe")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                                Spacer()
                                Text("\(article.wordCount) words")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let date = article.publishDate {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            // Tags
                            if !article.tags.isEmpty {
                                FlowLayoutView(items: article.tags) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Divider()

                        // Content
                        Text(article.content)
                            .font(.body)
                            .lineSpacing(4)
                            .textSelection(.enabled)

                        Divider()

                        // Actions
                        HStack {
                            Button("Copy as Markdown") {
                                let md = clipper.export(article, format: .markdown)
                                copyToClipboard(md)
                            }
                            Button("Copy as Text") {
                                let text = clipper.export(article, format: .plainText)
                                copyToClipboard(text)
                            }
                            Spacer()
                            Link("Open Original", destination: URL(string: article.url)!)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "Select an Article",
                    systemImage: "doc.richtext",
                    description: Text("Paste a URL above to clip an article, or select from the list")
                )
            }
        }
    }

    // MARK: - Helpers

    private var filteredArticles: [ClippedArticle] {
        if searchQuery.isEmpty { return clipper.articles }
        return clipper.searchArticles(query: searchQuery)
    }

    private func clipURL() {
        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        var normalized = url
        if !normalized.contains("://") {
            normalized = "https://\(normalized)"
        }

        Task {
            if let article = await clipper.clipFromURL(normalized) {
                selectedArticle = article
                urlInput = ""
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Flow Layout Helper

private struct FlowLayoutView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    var body: some View {
        var width: CGFloat = 0
        var rows: [[Data.Element]] = [[]]

        // Simple horizontal wrapping
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element) { _, item in
                content(item)
            }
        }
    }
}
