//
//  PrivacyProtectionSections.swift
//  Thea
//
//  PII Protection and AI Memory UI components for Privacy Settings
//  Extracted from PrivacySettingsView.swift for better code organization
//

import SwiftUI

// MARK: - PII Protection Section

extension PrivacySettingsView {
    var piiProtectionSection: some View {
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

    func piiToggle(_ label: String, keyPath: WritableKeyPath<PIISanitizer.Configuration, Bool>) -> some View {
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
}

// MARK: - AI Memory Section

extension PrivacySettingsView {
    var aiMemorySection: some View {
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

// MARK: - Custom Pattern Editor Sheet

extension PrivacySettingsView {
    var customPatternEditorSheet: some View {
        CustomPatternEditorView {
            showingCustomPatternSheet = false
        }
    }
}
