import SwiftUI

struct KnowledgeManagementView: View {
    @State private var scanner = HDKnowledgeScanner.shared
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var showingPathSelector = false

    var body: some View {
        NavigationSplitView {
            // Sidebar - Configuration
            Form {
                Section("Indexed Paths") {
                    ForEach(scanner.scanPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder")
                            Text(path.lastPathComponent)

                            Spacer()

                            Button(action: {
                                scanner.addExcludedPath(path)
                            }) {
                                Image(systemName: "xmark.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button("Add Path") {
                        showingPathSelector = true
                    }
                }

                Section("Statistics") {
                    let stats = scanner.getStatistics()

                    LabeledContent("Total Files", value: "\(stats.totalFiles)")
                    LabeledContent("Total Size", value: ByteCountFormatter.string(fromByteCount: stats.totalSize, countStyle: .file))

                    if let newest = stats.newestFile {
                        LabeledContent("Last Indexed", value: newest.indexedAt, format: .relative(presentation: .named))
                    }
                }

                Section {
                    if scanner.isIndexing {
                        HStack {
                            ProgressView(value: scanner.indexingProgress)
                            Text("\(Int(scanner.indexingProgress * 100))%")
                                .font(.caption)
                        }

                        Button("Stop Indexing") {
                            scanner.stopIndexing()
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button("Start Indexing") {
                            Task {
                                try? await scanner.startIndexing()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Knowledge Base")

        } detail: {
            // Main content - Search
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search knowledge base", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            performSearch()
                        }

                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                if searchResults.isEmpty && !searchQuery.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No files match your search")
                    )
                } else if !searchResults.isEmpty {
                    List(searchResults) { result in
                        SearchResultRow(result: result)
                    }
                } else {
                    ContentUnavailableView(
                        "Search Your Knowledge",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Search across all indexed documents using semantic search")
                    )
                }
            }
        }
        .fileImporter(
            isPresented: $showingPathSelector,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                scanner.configureScanPaths(scanner.scanPaths + [url])
            }
        }
    }

    private func performSearch() {
        Task {
            searchResults = try await scanner.semanticSearch(searchQuery, topK: 20)
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForFileType(result.file.fileType))
                    .foregroundStyle(colorForFileType(result.file.fileType))

                Text(result.file.filename)
                    .font(.headline)

                Spacer()

                Text("\(Int(result.relevanceScore * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(result.file.content.prefix(200))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack {
                Label(result.file.fileType.rawValue, systemImage: "doc")
                Spacer()
                Text(result.file.lastModified, style: .relative)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func iconForFileType(_ type: FileType) -> String {
        switch type {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .markdown: return "doc.text"
        case .pdf: return "doc.fill"
        case .data: return "tablecells"
        case .text: return "doc.plaintext"
        }
    }

    private func colorForFileType(_ type: FileType) -> Color {
        switch type {
        case .code: return .blue
        case .markdown: return .green
        case .pdf: return .red
        case .data: return .orange
        case .text: return .secondary
        }
    }
}

#Preview {
    KnowledgeManagementView()
}
