// IntegrationsSettingsView.swift
// Comprehensive integrations management for Thea

import SwiftUI

struct IntegrationsSettingsView: View {
    @State private var featureFlags = FeatureFlags.shared
    @State private var integrationsManager = IntegrationsManager.shared
    @State private var showingModuleDetail: IntegrationModuleType?
    @State private var showingResetConfirmation = false

    var body: some View {
        Form {
            // MARK: - Overview Section
            Section("Overview") {
                overviewGrid
            }

            // MARK: - Core Integrations
            Section("Core Integrations") {
                integrationToggle(
                    module: .health,
                    binding: Binding(
                        get: { featureFlags.healthEnabled },
                        set: { featureFlags.healthEnabled = $0 }
                    )
                )

                integrationToggle(
                    module: .wellness,
                    binding: Binding(
                        get: { featureFlags.wellnessEnabled },
                        set: { featureFlags.wellnessEnabled = $0 }
                    )
                )

                integrationToggle(
                    module: .cognitive,
                    binding: Binding(
                        get: { featureFlags.cognitiveEnabled },
                        set: { featureFlags.cognitiveEnabled = $0 }
                    )
                )

                integrationToggle(
                    module: .nutrition,
                    binding: Binding(
                        get: { featureFlags.nutritionEnabled },
                        set: { featureFlags.nutritionEnabled = $0 }
                    )
                )
            }

            // MARK: - Productivity Integrations
            Section("Productivity & Career") {
                integrationToggle(
                    module: .career,
                    binding: Binding(
                        get: { featureFlags.careerEnabled },
                        set: { featureFlags.careerEnabled = $0 }
                    )
                )

                integrationToggle(
                    module: .assessment,
                    binding: Binding(
                        get: { featureFlags.assessmentEnabled },
                        set: { featureFlags.assessmentEnabled = $0 }
                    )
                )

                #if os(macOS)
                integrationToggle(
                    module: .automation,
                    binding: Binding(
                        get: { featureFlags.automationEnabled },
                        set: { featureFlags.automationEnabled = $0 }
                    )
                )
                #endif
            }

            // MARK: - Financial Integrations
            Section("Financial") {
                integrationToggle(
                    module: .financial,
                    binding: Binding(
                        get: { featureFlags.financialEnabled },
                        set: { featureFlags.financialEnabled = $0 }
                    )
                )

                integrationToggle(
                    module: .income,
                    binding: Binding(
                        get: { featureFlags.incomeEnabled },
                        set: { featureFlags.incomeEnabled = $0 }
                    )
                )
            }

            // MARK: - System Integrations
            #if os(macOS)
            Section("System") {
                integrationToggle(
                    module: .display,
                    binding: Binding(
                        get: { featureFlags.displayEnabled },
                        set: { featureFlags.displayEnabled = $0 }
                    )
                )
            }
            #endif

            // MARK: - AI Features
            Section("AI Features") {
                aiFeatureToggles
            }

            // MARK: - Platform Integrations
            Section("Platform Integrations") {
                platformIntegrations
            }

            // MARK: - Actions
            Section {
                Button("Reset All to Defaults", role: .destructive) {
                    showingResetConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .padding()
        #endif
        .sheet(item: $showingModuleDetail) { module in
            moduleDetailSheet(module)
        }
        .alert("Reset All Integrations?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                featureFlags.resetToDefaults()
            }
        } message: {
            Text("This will reset all integration settings to their default values.")
        }
    }

    // MARK: - Overview Grid

    private var overviewGrid: some View {
        VStack(spacing: 12) {
            #if os(macOS)
            HStack(spacing: 16) {
                overviewCard(
                    title: "Enabled",
                    count: enabledModulesCount,
                    total: IntegrationModuleType.allCases.count,
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                overviewCard(
                    title: "Available",
                    count: IntegrationModuleType.allCases.count,
                    total: IntegrationModuleType.allCases.count,
                    icon: "square.grid.2x2.fill",
                    color: .blue
                )

                overviewCard(
                    title: "Active",
                    count: integrationsManager.enabledModulesCount,
                    total: enabledModulesCount,
                    icon: "bolt.fill",
                    color: .orange
                )
            }
            #else
            HStack(spacing: 12) {
                overviewCard(
                    title: "Enabled",
                    count: enabledModulesCount,
                    total: IntegrationModuleType.allCases.count,
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                overviewCard(
                    title: "Active",
                    count: integrationsManager.enabledModulesCount,
                    total: enabledModulesCount,
                    icon: "bolt.fill",
                    color: .orange
                )
            }
            #endif
        }
    }

    private func overviewCard(title: String, count: Int, total: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if total > 0 {
                ProgressView(value: Double(count), total: Double(total))
                    .tint(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(count) of \(total)")
    }

    private var enabledModulesCount: Int {
        var count = 0
        if featureFlags.healthEnabled { count += 1 }
        if featureFlags.wellnessEnabled { count += 1 }
        if featureFlags.cognitiveEnabled { count += 1 }
        if featureFlags.financialEnabled { count += 1 }
        if featureFlags.careerEnabled { count += 1 }
        if featureFlags.assessmentEnabled { count += 1 }
        if featureFlags.nutritionEnabled { count += 1 }
        if featureFlags.displayEnabled { count += 1 }
        if featureFlags.incomeEnabled { count += 1 }
        if featureFlags.automationEnabled { count += 1 }
        return count
    }

    // MARK: - Integration Toggle

    private func integrationToggle(module: IntegrationModuleType, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: module.icon)
                .font(.title2)
                .foregroundStyle(binding.wrappedValue ? moduleColor(for: module) : .secondary)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(module.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if integrationsManager.isModuleEnabled(module) {
                Text("Active")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .cornerRadius(4)
            }

            Toggle("", isOn: binding)
                .labelsHidden()

            Button {
                showingModuleDetail = module
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Details for \(module.displayName)")
        }
        .padding(.vertical, 4)
    }

    private func moduleColor(for module: IntegrationModuleType) -> Color {
        switch module {
        case .health: .red
        case .wellness: .green
        case .cognitive: .purple
        case .financial: .blue
        case .career: .orange
        case .assessment: .teal
        case .nutrition: .pink
        case .display: .gray
        case .income: .mint
        case .automation: .indigo
        }
    }

    // MARK: - AI Feature Toggles

    private var aiFeatureToggles: some View {
        Group {
            featureToggle(
                title: "AI Vision",
                description: "Image and document analysis",
                icon: "eye.fill",
                isEnabled: featureFlags.aiVision
            )

            featureToggle(
                title: "AI Speech",
                description: "Voice recognition and synthesis",
                icon: "waveform",
                isEnabled: featureFlags.aiSpeech
            )

            featureToggle(
                title: "Document Intelligence",
                description: "Advanced document understanding",
                icon: "doc.text.fill",
                isEnabled: featureFlags.documentIntelligence
            )

            featureToggle(
                title: "MCP Servers",
                description: "Model Context Protocol integration",
                icon: "server.rack",
                isEnabled: featureFlags.mcpServers
            )

            featureToggle(
                title: "Custom Agents",
                description: "Create and use custom AI agents",
                icon: "person.2.fill",
                isEnabled: featureFlags.customAgents
            )

            featureToggle(
                title: "Multi-Modal Input",
                description: "Support for images, audio, and more",
                icon: "square.grid.3x3.fill",
                isEnabled: featureFlags.multiModalInput
            )
        }
    }

    private func featureToggle(title: String, description: String, icon: String, isEnabled: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isEnabled ? .blue : .secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isEnabled ? .green : .secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isEnabled ? "enabled" : "disabled")")
    }

    // MARK: - Platform Integrations

    private var platformIntegrations: some View {
        Group {
            featureToggle(
                title: "Spotlight",
                description: "Search conversations via Spotlight",
                icon: "magnifyingglass",
                isEnabled: featureFlags.spotlightIntegration
            )

            featureToggle(
                title: "Handoff",
                description: "Continue on other Apple devices",
                icon: "hand.raised.fill",
                isEnabled: featureFlags.handoff
            )

            featureToggle(
                title: "Focus Filters",
                description: "Integrate with Focus modes",
                icon: "moon.fill",
                isEnabled: featureFlags.focusFilters
            )

            featureToggle(
                title: "Universal Clipboard",
                description: "Share clipboard across devices",
                icon: "doc.on.clipboard",
                isEnabled: featureFlags.universalClipboard
            )

            featureToggle(
                title: "Widgets",
                description: "Home screen and Lock Screen widgets",
                icon: "square.grid.2x2",
                isEnabled: featureFlags.widgets
            )

            featureToggle(
                title: "Live Activities",
                description: "Dynamic Island and Live Activities",
                icon: "livephoto",
                isEnabled: featureFlags.liveActivities
            )
        }
    }

    // MARK: - Module Detail Sheet

    private func moduleDetailSheet(_ module: IntegrationModuleType) -> some View {
        NavigationStack {
            Form {
                Section("About") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: module.icon)
                                .font(.largeTitle)
                                .foregroundStyle(moduleColor(for: module))

                            VStack(alignment: .leading) {
                                Text(module.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text(integrationsManager.isModuleEnabled(module) ? "Active" : "Inactive")
                                    .font(.caption)
                                    .foregroundStyle(integrationsManager.isModuleEnabled(module) ? .green : .secondary)
                            }
                        }

                        Text(module.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Features") {
                    moduleFeatures(for: module)
                }

                Section("Status") {
                    moduleStatus(for: module)
                }
            }
            .navigationTitle(module.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingModuleDetail = nil
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 500)
        #endif
    }

    @ViewBuilder
    private func moduleFeatures(for module: IntegrationModuleType) -> some View {
        switch module {
        case .health:
            Text("Sleep tracking and analysis")
            Text("Heart rate monitoring")
            Text("Activity and workout data")
            Text("Mindfulness minutes")

        case .wellness:
            Text("Circadian rhythm optimization")
            Text("Focus mode integration")
            Text("Ambient audio generation")
            Text("Wellness reminders")

        case .cognitive:
            Text("Task breakdown and planning")
            Text("Visual timer with Pomodoro")
            Text("Focus Forest gamification")
            Text("Productivity analytics")

        case .financial:
            Text("Zero-based budgeting")
            Text("Transaction categorization")
            Text("Subscription monitoring")
            Text("Financial insights")

        case .career:
            Text("SMART goal tracking")
            Text("Skill development")
            Text("Daily reflections")
            Text("Growth recommendations")

        case .assessment:
            Text("EQ assessments")
            Text("HSP scale evaluation")
            Text("Cognitive benchmarking")
            Text("Progress tracking")

        case .nutrition:
            Text("84-nutrient tracking")
            Text("Meal planning")
            Text("Barcode scanning")
            Text("Nutritional insights")

        case .display:
            Text("DDC/CI hardware control")
            Text("Brightness management")
            Text("Contrast adjustment")
            Text("Display presets")

        case .income:
            Text("Passive income tracking")
            Text("Side hustle management")
            Text("Revenue analytics")
            Text("Growth projections")

        case .automation:
            Text("GUI automation")
            Text("Browser control")
            Text("Task scheduling")
            Text("Workflow automation")
        }
    }

    @ViewBuilder
    private func moduleStatus(for module: IntegrationModuleType) -> some View {
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

    private func isModuleEnabled(_ module: IntegrationModuleType) -> Bool {
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

    private func platformSupport(for module: IntegrationModuleType) -> String {
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
