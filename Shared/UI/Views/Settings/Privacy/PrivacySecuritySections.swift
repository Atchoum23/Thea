//
//  PrivacySecuritySections.swift
//  Thea
//
//  Security and third-party service UI components for Privacy Settings
//  Extracted from PrivacySettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Security Section

extension PrivacySettingsView {
    var securitySection: some View {
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
}

// MARK: - Third Party Section

extension PrivacySettingsView {
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
}
