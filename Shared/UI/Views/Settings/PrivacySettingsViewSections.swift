// PrivacySettingsViewSections.swift
// Supporting types and section views for PrivacySettingsView

import SwiftUI

// MARK: - Supporting Types

struct PrivacySettingsConfiguration: Equatable, Codable {
    // Data Collection
    var crashReportsEnabled = true
    var usageStatisticsEnabled = false

    // Data Retention
    var retentionPeriod: PrivacyRetentionPeriod = .forever
    var autoDeleteEmptyConversations = false
    var deleteAttachmentsWithConversations = true
    var storageUsed = "127.3 MB"

    // Security
    var encryptionEnabled = true
    var biometricLockEnabled = false
    var lockTimeout: PrivacyLockTimeout = .immediately
    var hidePreviewsInNotifications = false
    var clearClipboardAfterPaste = false
    var secureKeyboard = false

    // Audit
    var auditLoggingEnabled = true
    var auditLogEntries: [PrivacyAuditLogEntry] = [
        PrivacyAuditLogEntry(id: UUID(), type: .login, description: "App opened", timestamp: Date().addingTimeInterval(-3600), details: nil),
        PrivacyAuditLogEntry(id: UUID(), type: .dataAccess, description: "Conversations accessed", timestamp: Date().addingTimeInterval(-7200), details: "5 conversations viewed"),
        PrivacyAuditLogEntry(id: UUID(), type: .settingsChange, description: "Settings modified", timestamp: Date().addingTimeInterval(-86400), details: "Privacy settings updated")
    ]

    // Export
    var exportFormat: PrivacyExportFormat = .json
    var exportConversations = true
    var exportSettings = true
    var exportKnowledge = true
    var exportProjects = true
    var includeEncryptionKey = false
    var includeAttachments = true
    var includeMetadata = true

    private static let storageKey = "com.thea.privacyConfiguration"

    static func load() -> PrivacySettingsConfiguration {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let config = try? JSONDecoder().decode(PrivacySettingsConfiguration.self, from: data)
        {
            return config
        }
        return PrivacySettingsConfiguration()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

enum PrivacyRetentionPeriod: String, Codable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case oneYear
    case forever
}

enum PrivacyLockTimeout: String, Codable {
    case immediately
    case oneMinute
    case fiveMinutes
    case fifteenMinutes
}

enum PrivacyBiometricType {
    case faceID
    case touchID
    case none

    var displayName: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .none: "Biometric"
        }
    }
}

enum PrivacyExportFormat: String, Codable {
    case json
    case csv
    case encrypted
}

enum PrivacyAuditEventType: String, Codable {
    case dataAccess
    case dataExport
    case dataDelete
    case settingsChange
    case login
    case syncEvent
}

struct PrivacyAuditLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let type: PrivacyAuditEventType
    let description: String
    let timestamp: Date
    let details: String?
}

// MARK: - Sheet and Section Extensions

extension PrivacySettingsView {

    // MARK: - Custom Pattern Editor Sheet

    var customPatternEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Add Custom Pattern") {
                    Text("Define regex patterns to detect and mask custom sensitive data")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Placeholder - full implementation in PIISanitizer
                    Text("Coming soon: Custom pattern editor")
                        .foregroundStyle(.tertiary)
                }

                Section("Example Patterns") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• API Key: [A-Za-z0-9]{32,}")
                        Text("• JWT Token: eyJ[A-Za-z0-9_-]+")
                        Text("• UUID: [0-9a-f]{8}-...")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Custom Patterns")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingCustomPatternSheet = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 300)
        #endif
    }

    // MARK: - Export Options Sheet

    var exportOptionsSheet: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $privacyConfig.exportFormat) {
                        Text("JSON").tag(PrivacyExportFormat.json)
                        Text("CSV").tag(PrivacyExportFormat.csv)
                        Text("Encrypted Archive").tag(PrivacyExportFormat.encrypted)
                    }
                    .pickerStyle(.inline)
                }

                Section("What to Export") {
                    Toggle("Conversations", isOn: $privacyConfig.exportConversations)
                    Toggle("Settings", isOn: $privacyConfig.exportSettings)
                    Toggle("Knowledge Base", isOn: $privacyConfig.exportKnowledge)
                    Toggle("Projects", isOn: $privacyConfig.exportProjects)
                }

                Section("Options") {
                    if privacyConfig.exportFormat == .encrypted {
                        Toggle("Include Encryption Key", isOn: $privacyConfig.includeEncryptionKey)

                        Text("The encryption key will be required to import this data later")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Include Attachments", isOn: $privacyConfig.includeAttachments)

                    Toggle("Include Metadata", isOn: $privacyConfig.includeMetadata)
                }

                Section {
                    Button {
                        startExport()
                        showingExportOptions = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("Start Export")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Export Data")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingExportOptions = false
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }

    // MARK: - Audit Log Sheet

    var auditLogSheet: some View {
        NavigationStack {
            List {
                if privacyConfig.auditLogEntries.isEmpty {
                    Text("No audit events recorded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(privacyConfig.auditLogEntries, id: \.id) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: auditIcon(for: entry.type))
                                .foregroundStyle(auditColor(for: entry.type))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.description)
                                    .font(.body)

                                HStack {
                                    Text(entry.timestamp, style: .date)
                                    Text(entry.timestamp, style: .time)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if let details = entry.details {
                                    Text(details)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Privacy Audit Log")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingAuditLog = false
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear Log", role: .destructive) {
                        privacyConfig.auditLogEntries = []
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 500)
        #endif
    }

    // MARK: - Third Party Section

    var thirdPartySection: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Providers")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Conversations are sent to your chosen AI provider for processing. We do not store or analyze this data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                thirdPartyRow(name: "OpenAI", description: "GPT models", privacyUrl: "https://openai.com/privacy")
                thirdPartyRow(name: "Anthropic", description: "Claude models", privacyUrl: "https://anthropic.com/privacy")
                thirdPartyRow(name: "Google", description: "Gemini models", privacyUrl: "https://policies.google.com/privacy")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Other Services")
                    .font(.subheadline)
                    .fontWeight(.medium)

                thirdPartyRow(name: "Apple iCloud", description: "Sync & backup", privacyUrl: "https://apple.com/privacy")
                thirdPartyRow(name: "HuggingFace", description: "Local model downloads", privacyUrl: "https://huggingface.co/privacy")
            }
        }
    }

    func thirdPartyRow(name: String, description: String, privacyUrl: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let url = URL(string: privacyUrl) {
                Link(destination: url) {
                    Text("Privacy Policy")
                        .font(.caption2)
                }
            }
        }
    }

    // MARK: - Audit Helpers

    func auditIcon(for type: PrivacyAuditEventType) -> String {
        switch type {
        case .dataAccess: "eye.fill"
        case .dataExport: "square.and.arrow.up"
        case .dataDelete: "trash.fill"
        case .settingsChange: "gearshape.fill"
        case .login: "person.fill"
        case .syncEvent: "arrow.triangle.2.circlepath"
        }
    }

    func auditColor(for type: PrivacyAuditEventType) -> Color {
        switch type {
        case .dataAccess: .blue
        case .dataExport: .green
        case .dataDelete: .red
        case .settingsChange: .orange
        case .login: .purple
        case .syncEvent: .teal
        }
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    PrivacySettingsView()
        .frame(width: 700, height: 900)
}
#else
#Preview {
    NavigationStack {
        PrivacySettingsView()
            .navigationTitle("Privacy")
    }
}
#endif
