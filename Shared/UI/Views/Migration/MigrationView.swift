import SwiftUI

struct MigrationView: View {
    @State private var migrationEngine = MigrationEngine.shared
    @State private var detectedSources: [MigrationSourceInfo] = []
    @State private var isScanning = false
    @State private var selectedSource: (any MigrationSource)?
    @State private var showingMigrationProgress = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Import from Other Apps")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Seamlessly migrate your conversations, projects, and settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

            if isScanning {
                ProgressView("Scanning for installed apps...")
                    .padding()
            } else if detectedSources.isEmpty {
                ContentUnavailableView(
                    "No Apps Detected",
                    systemImage: "app.dashed",
                    description: Text("No compatible apps found on this system")
                )

                Button("Scan Again") {
                    scanForApps()
                }
                .buttonStyle(.borderedProminent)
            } else {
                // Detected apps
                List(detectedSources, id: \.source.sourceName) { sourceInfo in
                    MigrationSourceRow(sourceInfo: sourceInfo) {
                        selectedSource = sourceInfo.source
                        showingMigrationProgress = true

                        Task {
                            _ = try? await migrationEngine.startMigration(from: sourceInfo.source)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Migration")
        .task {
            scanForApps()
        }
        .sheet(isPresented: $showingMigrationProgress) {
            if let source = selectedSource {
                MigrationProgressView(source: source)
            }
        }
    }

    private func scanForApps() {
        isScanning = true

        Task {
            detectedSources = await migrationEngine.detectInstalledApps()
            isScanning = false
        }
    }
}

struct MigrationSourceRow: View {
    let sourceInfo: MigrationSourceInfo
    let onMigrate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: sourceInfo.source.sourceIcon)
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text(sourceInfo.source.sourceName)
                        .font(.headline)

                    Text(sourceInfo.source.sourceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if sourceInfo.isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Migration estimate
            VStack(alignment: .leading, spacing: 4) {
                Label("\(sourceInfo.estimate.conversationCount) conversations", systemImage: "bubble.left.and.bubble.right")
                Label("\(sourceInfo.estimate.projectCount) projects", systemImage: "folder")
                Label(ByteCountFormatter.string(fromByteCount: sourceInfo.estimate.totalSizeBytes, countStyle: .file), systemImage: "externaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button(action: onMigrate) {
                Label("Start Migration", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct MigrationProgressView: View {
    let source: any MigrationSource
    @State private var migrationEngine = MigrationEngine.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                if let job = migrationEngine.activeMigrations.first {
                    // Progress
                    VStack(spacing: 12) {
                        ProgressView(value: job.progress.percentage)
                            .frame(width: 200)

                        Text(job.progress.stage.rawValue)
                            .font(.headline)

                        Text(job.progress.currentItem)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(job.progress.itemsProcessed) / \(job.progress.totalItems)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Status
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Migration in progress...", systemImage: "hourglass")
                        Label("Do not close this window", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)

                    Spacer()
                } else if migrationEngine.completedMigrations.contains(where: { $0.source == source.sourceName }) {
                    // Complete
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("Migration Complete!")
                            .font(.title)
                            .fontWeight(.bold)

                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("Migrating from \(source.sourceName)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    NavigationStack {
        MigrationView()
    }
}
