// PrivacySettingsView.swift
// Comprehensive privacy settings for Thea

import SwiftUI
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var settingsManager = SettingsManager.shared
    @State var privacyConfig = PrivacySettingsConfiguration.load()
    @State private var sanitizer = PIISanitizer.shared
    @State private var conversationMemory = ConversationMemory.shared
    @State var showingExportOptions = false
    @State private var showingDeleteConfirmation = false
    @State var showingAuditLog = false
    @State var showingCustomPatternSheet = false
    @State private var showingClearMemoryConfirmation = false
    @State var isExporting = false
    @State var exportProgress: Double = 0
    @State private var exportError: Error?
    @State private var biometricsAvailable = false
    @State private var biometricType: PrivacyBiometricType = .none

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

    // MARK: - Privacy Overview

    private var privacyOverview: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(
                    title: "Analytics",
                    value: settingsManager.analyticsEnabled ? "On" : "Off",
                    icon: "chart.bar.fill",
                    color: settingsManager.analyticsEnabled ? .orange : .green
                )

                overviewCard(
                    title: "Encryption",
                    value: privacyConfig.encryptionEnabled ? "Enabled" : "Disabled",
                    icon: "lock.shield.fill",
                    color: privacyConfig.encryptionEnabled ? .green : .red
                )

                overviewCard(
                    title: "Biometric",
                    value: privacyConfig.biometricLockEnabled ? "On" : "Off",
                    icon: biometricIcon,
                    color: privacyConfig.biometricLockEnabled ? .blue : .secondary
                )

                overviewCard(
                    title: "Retention",
                    value: retentionPeriodText,
                    icon: "clock.fill",
                    color: .purple
                )
            }
            #else
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                overviewCard(
                    title: "Analytics",
                    value: settingsManager.analyticsEnabled ? "On" : "Off",
                    icon: "chart.bar.fill",
                    color: settingsManager.analyticsEnabled ? .orange : .green
                )

                overviewCard(
                    title: "Encryption",
                    value: privacyConfig.encryptionEnabled ? "Enabled" : "Disabled",
                    icon: "lock.shield.fill",
                    color: privacyConfig.encryptionEnabled ? .green : .red
                )

                overviewCard(
                    title: "Biometric",
                    value: privacyConfig.biometricLockEnabled ? "On" : "Off",
                    icon: biometricIcon,
                    color: privacyConfig.biometricLockEnabled ? .blue : .secondary
                )

                overviewCard(
                    title: "Retention",
                    value: retentionPeriodText,
                    icon: "clock.fill",
                    color: .purple
                )
            }
            #endif

            // Privacy score
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy Score")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(privacyScoreDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: privacyScore / 100)
                        .stroke(privacyScoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(privacyScore))")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .none: "lock.fill"
        }
    }

    private var retentionPeriodText: String {
        switch privacyConfig.retentionPeriod {
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .oneYear: "1 year"
        case .forever: "Forever"
        }
    }

    private var privacyScore: Double {
        var score: Double = 0
        if !settingsManager.analyticsEnabled { score += 25 }
        if privacyConfig.encryptionEnabled { score += 25 }
        if privacyConfig.biometricLockEnabled { score += 25 }
        if privacyConfig.retentionPeriod != .forever { score += 15 }
        if privacyConfig.clearClipboardAfterPaste { score += 5 }
        if privacyConfig.hidePreviewsInNotifications { score += 5 }
        return min(score, 100)
    }

    private var privacyScoreColor: Color {
        if privacyScore >= 80 { return .green }
        if privacyScore >= 50 { return .orange }
        return .red
    }

    private var privacyScoreDescription: String {
        if privacyScore >= 80 { return "Excellent privacy protection" }
        if privacyScore >= 50 { return "Moderate privacy protection" }
        return "Consider enabling more privacy features"
    }

    // MARK: - Data Collection Section

    private var dataCollectionSection: some View {
        Group {
            Toggle("Analytics", isOn: $settingsManager.analyticsEnabled)

            Text("Help improve Thea by sharing anonymous usage data")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Crash Reports", isOn: $privacyConfig.crashReportsEnabled)

            Text("Automatically send crash reports to help fix issues")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Usage Statistics", isOn: $privacyConfig.usageStatisticsEnabled)

            Text("Collect anonymous feature usage to improve the app")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // What we collect
            DisclosureGroup("What We Collect") {
                VStack(alignment: .leading, spacing: 8) {
                    collectionItem(icon: "checkmark.circle.fill", text: "App version and OS version", collected: true)
                    collectionItem(icon: "checkmark.circle.fill", text: "Feature usage counts", collected: settingsManager.analyticsEnabled)
                    collectionItem(icon: "checkmark.circle.fill", text: "Crash logs", collected: privacyConfig.crashReportsEnabled)
                    collectionItem(icon: "xmark.circle.fill", text: "Conversation content", collected: false)
                    collectionItem(icon: "xmark.circle.fill", text: "Personal information", collected: false)
                    collectionItem(icon: "xmark.circle.fill", text: "Location data", collected: false)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func collectionItem(icon: String, text: String, collected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(collected ? .orange : .green)
                .frame(width: 20)

            Text(text)
                .font(.caption)

            Spacer()

            Text(collected ? "Collected" : "Never collected")
                .font(.caption2)
                .foregroundStyle(collected ? .orange : .green)
        }
    }

    // MARK: - Data Retention Section

    private var dataRetentionSection: some View {
        Group {
            Picker("Retention Period", selection: $privacyConfig.retentionPeriod) {
                Text("7 Days").tag(PrivacyRetentionPeriod.sevenDays)
                Text("30 Days").tag(PrivacyRetentionPeriod.thirtyDays)
                Text("90 Days").tag(PrivacyRetentionPeriod.ninetyDays)
                Text("1 Year").tag(PrivacyRetentionPeriod.oneYear)
                Text("Forever").tag(PrivacyRetentionPeriod.forever)
            }

            Text("Automatically delete conversations older than this period")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Auto-Delete Empty Conversations", isOn: $privacyConfig.autoDeleteEmptyConversations)

            Toggle("Delete Attachments with Conversations", isOn: $privacyConfig.deleteAttachmentsWithConversations)

            Divider()

            // Storage used
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Used")
                        .font(.subheadline)

                    Text("\(privacyConfig.storageUsed) used")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clean Up") {
                    cleanUpStorage()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Group {
            Toggle("End-to-End Encryption", isOn: $privacyConfig.encryptionEnabled)

            Text("Encrypt all conversations and data stored on device")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            if biometricsAvailable {
                Toggle("Require \(biometricType.displayName) to Open", isOn: $privacyConfig.biometricLockEnabled)

                Text("Require biometric authentication to access Thea")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if privacyConfig.biometricLockEnabled {
                    Picker("Lock Timeout", selection: $privacyConfig.lockTimeout) {
                        Text("Immediately").tag(PrivacyLockTimeout.immediately)
                        Text("After 1 minute").tag(PrivacyLockTimeout.oneMinute)
                        Text("After 5 minutes").tag(PrivacyLockTimeout.fiveMinutes)
                        Text("After 15 minutes").tag(PrivacyLockTimeout.fifteenMinutes)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "faceid")
                        .foregroundStyle(.secondary)

                    Text("Biometric authentication not available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Toggle("Hide Previews in Notifications", isOn: $privacyConfig.hidePreviewsInNotifications)

            Toggle("Clear Clipboard After Paste", isOn: $privacyConfig.clearClipboardAfterPaste)

            Toggle("Secure Keyboard", isOn: $privacyConfig.secureKeyboard)

            Text("Prevent third-party keyboards from learning your input")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Group {
            // Export
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

            // Delete
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

    // MARK: - Privacy Audit Section

    private var privacyAuditSection: some View {
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

            // Recent activity
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

    // MARK: - Actions

    private func checkBiometrics() {
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

    private func cleanUpStorage() {
        // Implement storage cleanup
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
                // Present save panel so user can choose where to save
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

                // Clean up temp file
                try? FileManager.default.removeItem(at: fileURL)
            } catch {
                isExporting = false
                exportError = error
            }
        }
    }

    private func deleteAllData() {
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

    private func resetPrivacySettings() {
        privacyConfig = PrivacySettingsConfiguration()
        privacyConfig.save()
    }
}
