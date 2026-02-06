// PrivacySettingsView.swift
// Comprehensive privacy settings for Thea

import SwiftUI
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

struct PrivacySettingsView: View {
    @State var settingsManager = SettingsManager.shared
    @State var privacyConfig = PrivacySettingsConfiguration.load()
    @State var sanitizer = PIISanitizer.shared
    @State var conversationMemory = ConversationMemory.shared
    @State var showingExportOptions = false
    @State var showingDeleteConfirmation = false
    @State var showingAuditLog = false
    @State var showingCustomPatternSheet = false
    @State var showingClearMemoryConfirmation = false
    @State var isExporting = false
    @State var exportProgress: Double = 0
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
    }

    // MARK: - Actions

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
        // Implement storage cleanup
        privacyConfig.auditLogEntries.append(
            PrivacyAuditLogEntry(id: UUID(), type: .dataDelete, description: "Storage cleanup performed", timestamp: Date(), details: nil)
        )
    }

    func startExport() {
        isExporting = true
        exportProgress = 0

        // Simulate export progress
        Task {
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    exportProgress = Double(i) / 10.0
                }
            }

            await MainActor.run {
                isExporting = false
                privacyConfig.auditLogEntries.append(
                    PrivacyAuditLogEntry(id: UUID(), type: .dataExport, description: "Data export completed", timestamp: Date(), details: "Format: \(privacyConfig.exportFormat.rawValue)")
                )
            }
        }
    }

    func deleteAllData() {
        // Implement data deletion
        privacyConfig.auditLogEntries.append(
            PrivacyAuditLogEntry(id: UUID(), type: .dataDelete, description: "All data deleted", timestamp: Date(), details: nil)
        )
    }

    func resetPrivacySettings() {
        privacyConfig = PrivacySettingsConfiguration()
        privacyConfig.save()
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
