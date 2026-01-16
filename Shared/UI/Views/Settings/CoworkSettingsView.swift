import SwiftUI

/// Settings view for Cowork feature configuration
struct CoworkSettingsView: View {
    @State private var manager = CoworkManager.shared
    @State private var folderAccess = FolderAccessManager.shared
    @State private var skills = CoworkSkillsManager.shared
    @State private var showingFolderPicker = false

    var body: some View {
        Form {
            // General section
            generalSection

            // Permissions section
            permissionsSection

            // Safety section
            safetySection

            // Skills section
            skillsSection

            // Reset section
            resetSection
        }
        .formStyle(.grouped)
        .navigationTitle("Cowork")
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                folderAccess.addAllowedFolder(url)
            }
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            Toggle("Enable Cowork", isOn: $manager.isEnabled)
                .onChange(of: manager.isEnabled) { _, _ in
                    manager.saveConfiguration()
                }

            // Default working directory
            HStack {
                VStack(alignment: .leading) {
                    Text("Default Working Directory")
                    Text(manager.defaultWorkingDirectory.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button("Change") {
                    showingFolderPicker = true
                }
            }

            Stepper("Max Concurrent Tasks: \(manager.maxConcurrentTasks)", value: $manager.maxConcurrentTasks, in: 1...10)
                .onChange(of: manager.maxConcurrentTasks) { _, _ in
                    manager.saveConfiguration()
                }

            Toggle("Auto-save Artifacts", isOn: $manager.autoSaveArtifacts)
                .onChange(of: manager.autoSaveArtifacts) { _, _ in
                    manager.saveConfiguration()
                }
        } header: {
            Text("General")
        } footer: {
            Text("Configure basic Cowork behavior and defaults.")
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        Section {
            // Allowed folders
            DisclosureGroup("Allowed Folders (\(folderAccess.allowedFolders.count))") {
                ForEach(folderAccess.allowedFolders) { folder in
                    HStack {
                        Image(systemName: "folder")
                        VStack(alignment: .leading) {
                            Text(folder.url.lastPathComponent)
                            Text(folder.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Permissions badges
                        permissionsBadges(folder.permissions)

                        Button(role: .destructive) {
                            folderAccess.removeAllowedFolder(folder.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    showingFolderPicker = true
                } label: {
                    Label("Add Folder", systemImage: "plus")
                }
            }

            // Recent folders
            if !folderAccess.recentFolders.isEmpty {
                DisclosureGroup("Recent Folders (\(folderAccess.recentFolders.count))") {
                    ForEach(folderAccess.recentFolders, id: \.self) { url in
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            Text(url.path)
                                .lineLimit(1)

                            Spacer()

                            if !folderAccess.isAllowed(url) {
                                Button("Add") {
                                    folderAccess.addAllowedFolder(url)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Control which folders Cowork can access.")
        }
    }

    @ViewBuilder
    private func permissionsBadges(_ permissions: FolderAccessManager.AllowedFolder.Permissions) -> some View {
        HStack(spacing: 4) {
            if permissions.contains(.read) {
                Text("R")
                    .font(.caption2.bold())
                    .padding(2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(2)
            }
            if permissions.contains(.write) {
                Text("W")
                    .font(.caption2.bold())
                    .padding(2)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(2)
            }
            if permissions.contains(.delete) {
                Text("D")
                    .font(.caption2.bold())
                    .padding(2)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(2)
            }
        }
    }

    // MARK: - Safety Section

    private var safetySection: some View {
        Section {
            Toggle("Require Confirmation for Deletions", isOn: $manager.requireConfirmationForDeletions)
                .onChange(of: manager.requireConfirmationForDeletions) { _, _ in
                    manager.saveConfiguration()
                }

            Toggle("Preview Plan Before Execution", isOn: $manager.previewPlanBeforeExecution)
                .onChange(of: manager.previewPlanBeforeExecution) { _, _ in
                    manager.saveConfiguration()
                }

            Stepper("Max Files Per Operation: \(manager.maxFilesPerOperation)", value: $manager.maxFilesPerOperation, in: 10...1_000, step: 10)
                .onChange(of: manager.maxFilesPerOperation) { _, _ in
                    manager.saveConfiguration()
                }

            Toggle("Backup Before Modification", isOn: $manager.backupBeforeModification)
                .onChange(of: manager.backupBeforeModification) { _, _ in
                    manager.saveConfiguration()
                }
        } header: {
            Text("Safety")
        } footer: {
            Text("Safety settings help prevent accidental data loss.")
        }
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        Section {
            ForEach(CoworkSkillsManager.SkillType.allCases, id: \.self) { skill in
                HStack {
                    Image(systemName: skill.icon)
                        .foregroundStyle(skills.isEnabled(skill) ? Color.accentColor : Color.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading) {
                        Text(skill.rawValue)
                        Text(skill.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { skills.isEnabled(skill) },
                        set: { _ in skills.toggle(skill) }
                    ))
                    .labelsHidden()
                }
            }

            HStack {
                Button("Enable All") {
                    for skill in CoworkSkillsManager.SkillType.allCases {
                        skills.enable(skill)
                    }
                }

                Button("Disable All") {
                    for skill in CoworkSkillsManager.SkillType.allCases {
                        skills.disable(skill)
                    }
                }
            }
        } header: {
            Text("Skills")
        } footer: {
            Text("Enable or disable specific file handling capabilities.")
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button("Clear Session History") {
                manager.sessions.removeAll()
                _ = manager.createSession()
            }

            Button("Reset Safety Settings to Defaults") {
                manager.requireConfirmationForDeletions = true
                manager.previewPlanBeforeExecution = true
                manager.maxFilesPerOperation = 100
                manager.backupBeforeModification = true
                manager.saveConfiguration()
            }

            Button("Remove All Allowed Folders", role: .destructive) {
                for folder in folderAccess.allowedFolders {
                    folderAccess.removeAllowedFolder(folder.id)
                }
            }
        } header: {
            Text("Reset")
        }
    }
}

#Preview {
    NavigationStack {
        CoworkSettingsView()
    }
    .frame(width: 600, height: 800)
}
