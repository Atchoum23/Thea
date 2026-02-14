// IntegrationsSettingsViewSections.swift
// Supporting extensions for IntegrationsSettingsView

import SwiftUI

// MARK: - Module Status & Helpers

extension IntegrationsSettingsView {

    @ViewBuilder
    func moduleStatus(for module: IntegrationModuleType) -> some View {
        HStack {
            Text("Enabled")
            Spacer()
            Image(systemName: isModuleEnabled(module) ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isModuleEnabled(module) ? .green : .red)
        }

        HStack {
            Text("Active")
            Spacer()
            Image(systemName: integrationsManager.isModuleEnabled(module) ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(integrationsManager.isModuleEnabled(module) ? .green : .secondary)
        }

        HStack {
            Text("Platform")
            Spacer()
            Text(platformSupport(for: module))
                .foregroundStyle(.secondary)
        }
    }

    func isModuleEnabled(_ module: IntegrationModuleType) -> Bool {
        switch module {
        case .health: featureFlags.healthEnabled
        case .wellness: featureFlags.wellnessEnabled
        case .cognitive: featureFlags.cognitiveEnabled
        case .financial: featureFlags.financialEnabled
        case .career: featureFlags.careerEnabled
        case .assessment: featureFlags.assessmentEnabled
        case .nutrition: featureFlags.nutritionEnabled
        case .display: featureFlags.displayEnabled
        case .income: featureFlags.incomeEnabled
        case .automation: featureFlags.automationEnabled
        }
    }

    func platformSupport(for module: IntegrationModuleType) -> String {
        switch module {
        case .display, .automation:
            "macOS only"
        case .health:
            "iOS, watchOS"
        default:
            "All platforms"
        }
    }
}

// MARK: - Identifiable Extension

extension IntegrationModuleType: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    IntegrationsSettingsView()
        .frame(width: 700, height: 800)
}
#else
#Preview {
    NavigationStack {
        IntegrationsSettingsView()
            .navigationTitle("Integrations")
    }
}
#endif
