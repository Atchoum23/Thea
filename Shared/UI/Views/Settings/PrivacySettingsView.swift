// PrivacySettingsView.swift
// Comprehensive privacy settings for Thea

import SwiftUI
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State var settingsManager = SettingsManager.shared
    @State var privacyConfig = PrivacySettingsConfiguration.load()
    @State private var sanitizer = PIISanitizer.shared
    @State private var conversationMemory = ConversationMemory.shared
    @State var showingExportOptions = false
    @State var showingDeleteConfirmation = false
    @State var showingAuditLog = false
    @State var showingCustomPatternSheet = false
    @State private var showingClearMemoryConfirmation = false
    @State var isExporting = false
    @State var exportProgress: Double = 0
    @State var exportError: Error?
    @State var biometricsAvailable = false
    @State var biometricType: PrivacyBiometricType = .none

    var body: some View {
        Form {
            // MARK: - Overview
            Section("Privacy Overview") {
                privacyOverview
            }

            // MARK: - PII Protection
            piiProtectionSection

            // MARK: - AI Memory
            aiMemorySection

            // MARK: - Data Collection
            Section("Data Collection") {
                dataCollectionSection
            }

            // MARK: - Data Retention
            Section("Data Retention") {
                dataRetentionSection
            }

            // MARK: - Security
            Section("Security") {
                securitySection
            }

            // MARK: - Data Management
            Section("Data Management") {
                dataManagementSection
            }

            // MARK: - Privacy Audit
            Section("Privacy Audit") {
                privacyAuditSection
            }

            // MARK: - Third Party
            Section("Third-Party Services") {
                thirdPartySection
            }

            // MARK: - Reset
            Section {
                Button("Reset Privacy Settings", role: .destructive) {
                    resetPrivacySettings()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .onAppear {
            checkBiometrics()
        }
        .onChange(of: privacyConfig) { _, _ in
            privacyConfig.save()
        }
        .sheet(isPresented: $showingExportOptions) {
            exportOptionsSheet
        }
        .sheet(isPresented: $showingAuditLog) {
            auditLogSheet
        }
        .sheet(isPresented: $showingCustomPatternSheet) {
            customPatternEditorSheet
        }
        .confirmationDialog(
            "Clear AI Memory",
            isPresented: $showingClearMemoryConfirmation
        ) {
            Button("Clear Everything", role: .destructive) {
                conversationMemory.clearAllMemory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all learned facts, conversation summaries, and preferences. This cannot be undone.")
        }
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("This will permanently delete all your conversations, settings, and data. This action cannot be undone.")
        }
        .alert("Export Failed", isPresented: .constant(exportError != nil), presenting: exportError) { _ in
            Button("OK") { exportError = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - PII Protection Section

    private var piiProtectionSection: some View {
        Section {
            Toggle("Enable PII Protection", isOn: Binding(
                get: { sanitizer.configuration.enablePIISanitization },
                set: { newValue in
                    var config = sanitizer.configuration
                    config.enablePIISanitization = newValue
                    sanitizer.updateConfiguration(config)
                }
            ))

            if sanitizer.configuration.enablePIISanitization {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Automatically mask sensitive data before sending to AI")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    piiToggle("Email Addresses", keyPath: \.maskEmails)
                    piiToggle("Phone Numbers", keyPath: \.maskPhoneNumbers)
                    piiToggle("Credit Cards", keyPath: \.maskCreditCards)
                    piiToggle("Social Security Numbers", keyPath: \.maskSSNs)
                    piiToggle("IP Addresses", keyPath: \.maskIPAddresses)

                    Divider()

                    // Custom Patterns
                    HStack {
                        Text("Custom Patterns")
                            .font(.caption)
                        Spacer()
                        Text("\(sanitizer.configuration.customPatterns.count)")
                            .foregroundStyle(.secondary)
                        Button {
                            showingCustomPatternSheet = true
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                    }

                    // Stats
                    let stats = sanitizer.getStatistics()
                    if stats.totalDetections > 0 {
                        Text("\(stats.totalDetections) items redacted")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            HStack {
                Label("PII Protection", systemImage: "shield.lefthalf.filled")
                Spacer()
                if sanitizer.configuration.enablePIISanitization {
                    Text("Active")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .cornerRadius(4)
                }
            }
        }
    }

    private func piiToggle(_ label: String, keyPath: WritableKeyPath<PIISanitizer.Configuration, Bool>) -> some View {
        Toggle(label, isOn: Binding(
            get: { sanitizer.configuration[keyPath: keyPath] },
            set: { newValue in
                var config = sanitizer.configuration
                config[keyPath: keyPath] = newValue
                sanitizer.updateConfiguration(config)
            }
        ))
        .font(.callout)
    }

    // MARK: - AI Memory Section

    private var aiMemorySection: some View {
        Section {
            Toggle("Long-Term Memory", isOn: Binding(
                get: { conversationMemory.configuration.enableLongTermMemory },
                set: { newValue in
                    var config = conversationMemory.configuration
                    config.enableLongTermMemory = newValue
                    conversationMemory.updateConfiguration(config)
                }
            ))

            if conversationMemory.configuration.enableLongTermMemory {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remember facts and preferences across conversations")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let stats = conversationMemory.getStatistics()
                    HStack(spacing: 16) {
                        VStack {
                            Text("\(stats.totalFacts)")
                                .font(.headline)
                            Text("Facts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(stats.totalSummaries)")
                                .font(.headline)
                            Text("Summaries")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("\(stats.preferencesCount)")
                                .font(.headline)
                            Text("Preferences")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Button(role: .destructive) {
                        showingClearMemoryConfirmation = true
                    } label: {
                        Label("Clear Memory", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        } header: {
            Label("AI Memory", systemImage: "brain")
        }
    }

}

// Overview, Data Collection, Data Retention, Security sections and
// helper computed properties are in PrivacySettingsViewSections.swift

// MARK: - Data Management, Audit, and Actions

extension PrivacySettingsView {

    var dataManagementSection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Your Data")
                        .font(.subheadline)
                    Text("Download all your data in a portable format")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingExportOptions = true
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }

            if isExporting {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: exportProgress)
                    Text("Exporting... \(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete All Data")
                        .font(.subheadline)
                    Text("Permanently remove all conversations and settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            Text("This action cannot be undone. Make sure to export your data first if needed.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    var privacyAuditSection: some View {
        Group {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy Audit Log")
                        .font(.subheadline)
                    Text("\(privacyConfig.auditLogEntries.count) events recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingAuditLog = true
                } label: {
                    Label("View Log", systemImage: "list.bullet.rectangle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            Toggle("Enable Audit Logging", isOn: $privacyConfig.auditLoggingEnabled)

            Text("Track data access and modifications for security review")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !privacyConfig.auditLogEntries.isEmpty {
                Divider()
                Text("Recent Activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(privacyConfig.auditLogEntries.prefix(3), id: \.id) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: auditIcon(for: entry.type))
                            .foregroundStyle(auditColor(for: entry.type))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.description)
                                .font(.caption)
                            Text(entry.timestamp, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    func checkBiometrics() {
        #if canImport(LocalAuthentication)
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricsAvailable = true
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        } else {
            biometricsAvailable = false
            biometricType = .none
        }
        #endif
    }

    func cleanUpStorage() {
        privacyConfig.auditLogEntries.append(
            PrivacyAuditLogEntry(id: UUID(), type: .dataDelete, description: "Storage cleanup performed", timestamp: Date(), details: nil)
        )
    }

    func startExport() {
        isExporting = true
        exportProgress = 0

        Task {
            do {
                exportProgress = 0.1
                let fileURL = try await GDPRDataExporter.shared.exportAllData(modelContext: modelContext)
                exportProgress = 0.8

                #if os(macOS)
                let panel = NSSavePanel()
                panel.nameFieldStringValue = fileURL.lastPathComponent
                panel.allowedContentTypes = [.json]
                panel.canCreateDirectories = true
                if panel.runModal() == .OK, let destination = panel.url {
                    try FileManager.default.copyItem(at: fileURL, to: destination)
                }
                #endif

                exportProgress = 1.0
                try? await Task.sleep(nanoseconds: 300_000_000)

                isExporting = false
                privacyConfig.auditLogEntries.append(
                    PrivacyAuditLogEntry(id: UUID(), type: .dataExport, description: "Data export completed", timestamp: Date(), details: "Format: \(privacyConfig.exportFormat.rawValue)")
                )
                try? FileManager.default.removeItem(at: fileURL)
            } catch {
                isExporting = false
                exportError = error
            }
        }
    }

    func deleteAllData() {
        Task {
            do {
                try await GDPRDataExporter.shared.deleteAllData(modelContext: modelContext)
                privacyConfig.auditLogEntries.append(
                    PrivacyAuditLogEntry(id: UUID(), type: .dataDelete, description: "All data deleted", timestamp: Date(), details: nil)
                )
            } catch {
                exportError = error
            }
        }
    }

    func resetPrivacySettings() {
        privacyConfig = PrivacySettingsConfiguration()
        privacyConfig.save()
    }

    // MARK: - Helper Computed Properties

    var biometricIcon: String {
        switch biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .none: "lock.fill"
        }
    }

    var retentionPeriodText: String {
        switch privacyConfig.retentionPeriod {
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .oneYear: "1 year"
        case .forever: "Forever"
        }
    }

    var privacyScore: Double {
        var score: Double = 0
        if !settingsManager.analyticsEnabled { score += 25 }
        if privacyConfig.encryptionEnabled { score += 25 }
        if privacyConfig.biometricLockEnabled { score += 25 }
        if privacyConfig.retentionPeriod != .forever { score += 15 }
        if privacyConfig.clearClipboardAfterPaste { score += 5 }
        if privacyConfig.hidePreviewsInNotifications { score += 5 }
        return min(score, 100)
    }

    var privacyScoreColor: Color {
        if privacyScore >= 80 { return .green }
        if privacyScore >= 50 { return .orange }
        return .red
    }

    var privacyScoreDescription: String {
        if privacyScore >= 80 { return "Excellent privacy protection" }
        if privacyScore >= 50 { return "Moderate privacy protection" }
        return "Consider enabling more privacy features"
    }
}
