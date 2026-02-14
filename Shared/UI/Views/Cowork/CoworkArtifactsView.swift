#if os(macOS)
    import QuickLook
    import SwiftUI
    #if os(macOS)
        import AppKit
    #endif

    /// View for displaying artifacts (files) created during Cowork sessions
    struct CoworkArtifactsView: View {
        @State private var manager = CoworkManager.shared
        @State private var selectedArtifact: CoworkArtifact?
        @State private var viewMode: ViewMode = .grid
        @State private var filterType: CoworkArtifact.ArtifactType?
        @State private var showIntermediates = false

        enum ViewMode: String, CaseIterable {
            case grid = "Grid"
            case list = "List"

            var icon: String {
                switch self {
                case .grid: "square.grid.2x2"
                case .list: "list.bullet"
                }
            }
        }

        private var filteredArtifacts: [CoworkArtifact] {
            guard let session = manager.currentSession else { return [] }

            var artifacts = session.artifacts

            // Filter by type
            if let type = filterType {
                artifacts = artifacts.filter { $0.fileType == type }
            }

            // Filter intermediates
            if !showIntermediates {
                artifacts = artifacts.filter { !$0.isIntermediate }
            }

            return artifacts
        }

        var body: some View {
            VStack(spacing: 0) {
                // Toolbar
                toolbar

                Divider()

                // Content
                if filteredArtifacts.isEmpty {
                    emptyStateView
                } else {
                    switch viewMode {
                    case .grid:
                        gridView
                    case .list:
                        listView
                    }
                }
            }
            .quickLookPreview(Binding(
                get: { selectedArtifact?.fileURL },
                set: { _ in }
            ))
        }

        // MARK: - Toolbar

        private var toolbar: some View {
            HStack {
                // Filter by type
                Menu {
                    Button("All Types") {
                        filterType = nil
                    }

                    Divider()

                    ForEach(CoworkArtifact.ArtifactType.allCases, id: \.self) { type in
                        Button {
                            filterType = type
                        } label: {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .accessibilityHidden(true)
                        Text(filterType?.rawValue ?? "All Types")
                    }
                }
                .accessibilityLabel("Filter: \(filterType?.rawValue ?? "All Types")")

                Toggle("Show Intermediates", isOn: $showIntermediates)
                    .toggleStyle(.checkbox)

                Spacer()

                // Stats
                if let session = manager.currentSession {
                    Text("\(filteredArtifacts.count) artifacts")
                        .foregroundStyle(.secondary)

                    Text(session.artifacts.formattedTotalSize)
                        .foregroundStyle(.secondary)
                }

                // View mode picker
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
            }
            .padding()
        }

        // MARK: - Grid View

        private var gridView: some View {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 16)
                ], spacing: 16) {
                    ForEach(filteredArtifacts) { artifact in
                        artifactGridItem(artifact)
                    }
                }
                .padding()
            }
        }

        private func artifactGridItem(_ artifact: CoworkArtifact) -> some View {
            Button {
                selectedArtifact = artifact
            } label: {
                VStack(spacing: 8) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorForType(artifact.fileType).opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: artifact.fileType.icon)
                            .font(.title)
                            .foregroundStyle(colorForType(artifact.fileType))
                    }

                    // Name
                    Text(artifact.name)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    // Size
                    Text(artifact.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // Intermediate badge
                    if artifact.isIntermediate {
                        Text("Intermediate")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .cornerRadius(2)
                    }
                }
                .frame(width: 120)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(artifact.name), \(artifact.fileType.rawValue), \(artifact.formattedSize)\(artifact.isIntermediate ? ", intermediate" : "")")
            .contextMenu {
                artifactContextMenu(artifact)
            }
        }

        // MARK: - List View

        private var listView: some View {
            List(filteredArtifacts) { artifact in
                artifactListRow(artifact)
                    .contextMenu {
                        artifactContextMenu(artifact)
                    }
            }
            .listStyle(.inset)
        }

        private func artifactListRow(_ artifact: CoworkArtifact) -> some View {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: artifact.fileType.icon)
                    .font(.title2)
                    .foregroundStyle(colorForType(artifact.fileType))
                    .frame(width: 32)
                    .accessibilityHidden(true)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(artifact.name)
                            .font(.body)

                        if artifact.isIntermediate {
                            Text("Intermediate")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .cornerRadius(2)
                        }
                    }

                    Text(artifact.fileURL.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Size
                Text(artifact.formattedSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Date
                Text(artifact.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Preview button
                Button {
                    selectedArtifact = artifact
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview \(artifact.name)")
            }
            .padding(.vertical, 4)
        }

        // MARK: - Context Menu

        @ViewBuilder
        private func artifactContextMenu(_ artifact: CoworkArtifact) -> some View {
            Button {
                selectedArtifact = artifact
            } label: {
                Label("Preview", systemImage: "eye")
            }

            #if os(macOS)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([artifact.fileURL])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Button {
                    NSWorkspace.shared.open(artifact.fileURL)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.square")
                }
            #endif

            Divider()

            Button {
                copyToClipboard(artifact.fileURL.path)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                copyToClipboard(artifact.name)
            } label: {
                Label("Copy Name", systemImage: "textformat")
            }
        }

        // MARK: - Empty State

        private var emptyStateView: some View {
            ContentUnavailableView {
                Label("No Artifacts", systemImage: "doc.on.doc")
            } description: {
                Text("Files created during task execution will appear here")
            }
        }

        // MARK: - Helpers

        private func colorForType(_ type: CoworkArtifact.ArtifactType) -> Color {
            switch type {
            case .document: .blue
            case .spreadsheet: .green
            case .presentation: .orange
            case .image: .purple
            case .code: .cyan
            case .data: .yellow
            case .archive: .brown
            case .other: .secondary
            }
        }

        private func copyToClipboard(_ text: String) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    // MARK: - QuickLook Preview Extension

    extension Binding where Value: Equatable & Sendable {
        func map<T>(_ transform: @escaping @Sendable (Value) -> T?) -> Binding<T?> {
            Binding<T?>(
                get: { transform(self.wrappedValue) },
                set: { _ in }
            )
        }
    }

    #Preview {
        CoworkArtifactsView()
            .frame(width: 600, height: 500)
    }

#endif
