import SwiftUI

struct iOSMigrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var migrationManager = MigrationManager.shared

    @State private var selectedSource: IOSMigrationSourceType?
    @State private var showingFilePicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(IOSMigrationSourceType.allCases, id: \.self) { source in
                        Button {
                            selectedSource = source
                            showingFilePicker = true
                        } label: {
                            HStack {
                                Image(systemName: source.icon)
                                    .font(.title2)
                                    .foregroundStyle(.theaPrimary)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.displayName)
                                        .font(.headline)

                                    Text(source.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Available Sources")
                } footer: {
                    Text("Import your conversations from other AI apps")
                }

                if migrationManager.isMigrating {
                    Section("Migration Progress") {
                        VStack(spacing: 12) {
                            ProgressView(value: migrationManager.migrationProgress)

                            HStack {
                                Text(migrationManager.migrationStatus)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(migrationManager.migrationProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(migrationManager.isMigrating)
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                if let source = selectedSource {
                    iOSMigrationImportView(source: source)
                }
            }
        }
    }
}

enum IOSMigrationSourceType: String, CaseIterable {
    case chatGPT
    case claude
    case cursor

    var displayName: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .claude: "Claude"
        case .cursor: "Cursor"
        }
    }

    var description: String {
        switch self {
        case .chatGPT: "Import from ChatGPT export"
        case .claude: "Import from Claude conversations"
        case .cursor: "Import from Cursor AI"
        }
    }

    var icon: String {
        switch self {
        case .chatGPT: "bubble.left.and.bubble.right.fill"
        case .claude: "brain.head.profile"
        case .cursor: "cursorarrow.click.2"
        }
    }
}

struct iOSMigrationImportView: View {
    @Environment(\.dismiss) private var dismiss
    let source: IOSMigrationSourceType

    @State private var migrationManager = MigrationManager.shared
    @State private var selectedURL: URL?
    @State private var isImporting = false
    @State private var importComplete = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: source.icon)
                            .font(.largeTitle)
                            .foregroundStyle(.theaPrimary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.displayName)
                                .font(.headline)

                            Text(source.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Source")
                }

                Section {
                    Button {
                        selectedURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    } label: {
                        HStack {
                            Text(selectedURL?.lastPathComponent ?? "Select Export File...")
                                .foregroundStyle(selectedURL == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "doc.badge.plus")
                        }
                    }
                } header: {
                    Text("Export File")
                } footer: {
                    Text("Select the exported JSON file from \(source.displayName)")
                }

                if migrationManager.isMigrating {
                    Section("Migration Progress") {
                        VStack(spacing: 12) {
                            ProgressView(value: migrationManager.migrationProgress)

                            HStack {
                                Text(migrationManager.migrationStatus)
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(migrationManager.migrationProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if importComplete {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title)

                            Text("Import Complete")
                                .font(.headline)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)

                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if migrationManager.isMigrating {
                            migrationManager.cancelMigration()
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(importComplete ? "Done" : "Import") {
                        if importComplete {
                            dismiss()
                        } else {
                            startImport()
                        }
                    }
                    .disabled(isImporting || selectedURL == nil)
                }
            }
        }
    }

    private func startImport() {
        guard let url = selectedURL else { return }

        isImporting = true
        errorMessage = nil

        Task {
            do {
                switch source {
                case .chatGPT:
                    try await migrationManager.migrateFromChatGPT(exportPath: url)
                case .claude:
                    try await migrationManager.migrateFromClaude(exportPath: url)
                case .cursor:
                    try await migrationManager.migrateFromCursor(path: url)
                }
                importComplete = true
                isImporting = false
            } catch {
                isImporting = false
                errorMessage = error.localizedDescription
                print("Import failed: \(error)")
            }
        }
    }
}
