import SwiftUI

struct iOSSyncSettingsView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var config = iOSSyncConfig.load()

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Image(systemName: settingsManager.iCloudSyncEnabled ? "checkmark.icloud.fill" : "xmark.icloud")
                            .font(.title)
                            .foregroundStyle(settingsManager.iCloudSyncEnabled ? .green : .red)
                        Text(settingsManager.iCloudSyncEnabled ? "Synced" : "Off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("2")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // iCloud Sync
            Section {
                Toggle("iCloud Sync", isOn: $settingsManager.iCloudSyncEnabled)
            } header: {
                Text("iCloud")
            } footer: {
                Text("Sync your conversations and settings across all your Apple devices")
            }

            // What to Sync
            Section {
                Toggle("Conversations", isOn: $config.syncConversations)
                Toggle("Settings", isOn: $config.syncSettings)
                Toggle("Knowledge", isOn: $config.syncKnowledge)
            } header: {
                Text("Sync Content")
            }

            // Conflict Resolution
            Section {
                Picker("Conflict Resolution", selection: $config.conflictResolution) {
                    Text("Keep Most Recent").tag("recent")
                    Text("Keep Local").tag("local")
                    Text("Keep Remote").tag("remote")
                }
            } header: {
                Text("Conflicts")
            }

            // Actions
            Section {
                Button("Sync Now") {
                    // Trigger sync
                }
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = iOSSyncConfig()
                }
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
    }
}

struct iOSSyncConfig: Equatable, Codable {
    var syncConversations: Bool = true
    var syncSettings: Bool = true
    var syncKnowledge: Bool = true
    var conflictResolution: String = "recent"

    private static let storageKey = "iOSSyncConfig"

    static func load() -> iOSSyncConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(iOSSyncConfig.self, from: data) {
            return config
        }
        return iOSSyncConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

struct iOSBackupSettingsView: View {
    @State private var config = iOSBackupConfig.load()
    @State private var showingCreateBackup = false

    var body: some View {
        Form {
            // Overview
            Section {
                HStack(spacing: 16) {
                    VStack {
                        Text("3")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Backups")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack {
                        Text("1.2 GB")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Total Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Overview")
            }

            // Quick Actions
            Section {
                Button {
                    showingCreateBackup = true
                } label: {
                    Label("Create Backup", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Actions")
            }

            // Auto Backup
            Section {
                Toggle("Auto Backup", isOn: $config.autoBackupEnabled)

                if config.autoBackupEnabled {
                    Picker("Frequency", selection: $config.backupFrequency) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                }
            } header: {
                Text("Automatic Backup")
            }

            // Backup Contents
            Section {
                Toggle("Conversations", isOn: $config.backupConversations)
                Toggle("Settings", isOn: $config.backupSettings)
                Toggle("Knowledge", isOn: $config.backupKnowledge)
            } header: {
                Text("What to Back Up")
            }

            // Storage
            Section {
                Picker("Storage Location", selection: $config.storageLocation) {
                    Text("iCloud").tag("icloud")
                    Text("Local").tag("local")
                }
            } header: {
                Text("Storage")
            }

            // Reset
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    config = iOSBackupConfig()
                }
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, _ in
            config.save()
        }
        .alert("Create Backup", isPresented: $showingCreateBackup) {
            Button("Create") {
                // Create backup
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create a new backup of your data.")
        }
    }
}

struct iOSBackupConfig: Equatable, Codable {
    var autoBackupEnabled: Bool = true
    var backupFrequency: String = "weekly"
    var backupConversations: Bool = true
    var backupSettings: Bool = true
    var backupKnowledge: Bool = true
    var storageLocation: String = "icloud"

    private static let storageKey = "iOSBackupConfig"

    static func load() -> iOSBackupConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(iOSBackupConfig.self, from: data) {
            return config
        }
        return iOSBackupConfig()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
