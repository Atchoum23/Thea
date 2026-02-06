import SwiftUI

struct iOSKnowledgeView: View {
    @State private var knowledgeManager = KnowledgeManager.shared

    @State private var searchQuery = ""
    @State private var showingScanner = false
    @State private var searchResults: [IndexedFile] = []

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if knowledgeManager.isIndexing {
                scanningView
            } else if knowledgeManager.indexedFiles.isEmpty {
                emptyStateView
            } else if searchQuery.isEmpty {
                statsView
            } else {
                resultsView
            }
        }
        .sheet(isPresented: $showingScanner) {
            iOSKnowledgeScannerView()
        }
    }

    private var searchBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search your knowledge...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .onChange(of: searchQuery) { _, newValue in
                        performSearch(newValue)
                    }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()

            Divider()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.theaPrimary)

            Text("No Knowledge Indexed")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Scan your files to enable semantic search across your entire Mac")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showingScanner = true
            } label: {
                Label("Start Scanning", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.theaPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var scanningView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Scanning Files...")
                .font(.headline)

            Text("Indexing your knowledge base")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                statsCard

                Button {
                    showingScanner = true
                } label: {
                    Label("Scan More Files", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.theaPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                recentFilesSection
            }
            .padding(.vertical)
        }
    }

    private var statsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 32) {
                StatItem(
                    value: "\(knowledgeManager.indexedFiles.count)",
                    label: "Files",
                    icon: "doc.fill"
                )

                StatItem(
                    value: formatBytes(totalSize),
                    label: "Total Size",
                    icon: "internaldrive.fill"
                )

                StatItem(
                    value: "\(uniqueFileTypes)",
                    label: "File Types",
                    icon: "text.bubble.fill"
                )
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Indexed")
                .font(.headline)
                .padding(.horizontal)

            ForEach(Array(knowledgeManager.indexedFiles.prefix(10))) { file in
                FileRow(file: file)
            }
        }
    }

    private var resultsView: some View {
        ScrollView {
            if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No Results Found")
                        .font(.headline)

                    Text("Try a different search query")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 64)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(searchResults) { file in
                        SearchResultRow(file: file)
                    }
                }
                .padding()
            }
        }
    }

    private var totalSize: Int64 {
        knowledgeManager.indexedFiles.reduce(0) { $0 + $1.size }
    }

    private var uniqueFileTypes: Int {
        Set(knowledgeManager.indexedFiles.map(\.fileType)).count
    }

    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchResults = knowledgeManager.search(query: query)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.theaPrimary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct FileRow: View {
    let file: IndexedFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForFileType(file.fileType))
                .font(.title3)
                .foregroundStyle(.theaPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)

                Text(file.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatBytes(file.size))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    private func iconForFileType(_ fileType: String) -> String {
        switch fileType.lowercased() {
        case "swift": "swift"
        case "py": "terminal.fill"
        case "js", "ts": "curlybraces"
        case "md": "doc.text.fill"
        default: "doc.fill"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct SearchResultRow: View {
    let file: IndexedFile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.theaPrimary)

                Text(file.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(file.fileType.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.theaPrimary.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(file.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                Label(formatBytes(file.size), systemImage: "doc")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(file.indexedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Knowledge Scanner View

struct iOSKnowledgeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var knowledgeManager = KnowledgeManager.shared

    @State private var selectedPath: URL?
    @State private var isScanning = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        selectDirectory()
                    } label: {
                        HStack {
                            Text(selectedPath?.path ?? "Select Directory...")
                                .foregroundStyle(selectedPath == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "folder")
                        }
                    }
                } header: {
                    Text("Directory to Scan")
                } footer: {
                    Text("Choose a directory to scan for knowledge. All supported files will be indexed.")
                }

                if isScanning || knowledgeManager.isIndexing {
                    Section("Scanning Progress") {
                        VStack(spacing: 12) {
                            ProgressView(value: knowledgeManager.indexProgress)

                            HStack {
                                Text("Indexing files...")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(knowledgeManager.indexProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan Knowledge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isScanning)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isScanning ? "Scanning..." : "Start") {
                        startScanning()
                    }
                    .disabled(isScanning || selectedPath == nil)
                }
            }
        }
    }

    private func selectDirectory() {
        // In production, use UIDocumentPickerViewController
        // For now, default to Documents
        selectedPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private func startScanning() {
        guard let path = selectedPath else { return }

        isScanning = true

        Task {
            do {
                // Get all files from the directory
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isRegularFileKey])
                let files = contents.filter { url in
                    (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                }

                try await knowledgeManager.startIndexing(paths: files)
                isScanning = false
                dismiss()
            } catch {
                isScanning = false
                print("Scan failed: \(error)")
            }
        }
    }
}
