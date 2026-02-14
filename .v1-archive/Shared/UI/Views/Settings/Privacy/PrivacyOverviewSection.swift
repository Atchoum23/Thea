//
//  PrivacyOverviewSection.swift
//  Thea
//
//  Privacy overview UI components for Privacy Settings
//  Extracted from PrivacySettingsView.swift for better code organization
//

import SwiftUI

// MARK: - Privacy Overview

extension PrivacySettingsView {
    var privacyOverview: some View {
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

    func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
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
