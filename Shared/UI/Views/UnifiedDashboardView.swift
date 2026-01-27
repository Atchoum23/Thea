import SwiftUI

/// Unified dashboard showing all active integration modules
@MainActor
public struct UnifiedDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = IntegrationCoordinator.shared
    @State private var selectedModule: IntegrationModule?
    @State private var showingModuleSettings = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedModule) {
                Section("Active Modules") {
                    ForEach(coordinator.activeModules.sorted { $0.rawValue < $1.rawValue }) { module in
                        ModuleRow(module: module, status: coordinator.getModuleStatus(module))
                            .tag(module)
                    }
                }

                Section("Available Modules") {
                    ForEach(coordinator.getAllModules().filter { !coordinator.isModuleActive($0) }) { module in
                        ModuleRow(module: module, status: coordinator.getModuleStatus(module))
                            .tag(module)
                    }
                }
            }
            .navigationTitle("Integrations")
            .toolbar {
                Button {
                    showingModuleSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        } detail: {
            // Main content area
            if let module = selectedModule {
                moduleDetailView(module)
            } else {
                overviewContent
            }
        }
        .task {
            await coordinator.initialize(context: modelContext)
        }
        .sheet(isPresented: $showingModuleSettings) {
            ModuleSettingsView(coordinator: coordinator)
        }
    }

    private var overviewContent: some View {
        VStack(spacing: 16) {
            Text("Integration Dashboard")
                .font(.largeTitle)
                .bold()

            Text("\(coordinator.getActiveModuleCount()) of \(coordinator.getAllModules().count) modules active")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
    }

    @ViewBuilder
    private func moduleDetailView(_ module: IntegrationModule) -> some View {
        switch module {
        case .health:
            HealthDashboardView()
        case .wellness:
            CircadianEnhancementsView()
        case .cognitive:
            Text("Cognitive Module")
        case .financial:
            Text("Financial Module")
        case .career:
            Text("Career Module")
        case .assessment:
            AssessmentDashboardView()
        case .nutrition:
            NutritionDashboardView()
        case .display:
            #if os(macOS)
                DisplayDashboardView()
            #else
                Text("Display module only available on macOS")
            #endif
        case .income:
            IncomeDashboardView()
        }
    }
}

private struct ModuleRow: View {
    let module: IntegrationModule
    let status: ModuleStatus

    var body: some View {
        HStack {
            Image(systemName: module.icon)
                .foregroundStyle(module.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(module.rawValue)
                    .font(.subheadline)

                Text(status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
        }
    }
}

private struct ModuleSettingsView: View {
    @Bindable var coordinator: IntegrationCoordinator
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var featureFlags = FeatureFlags.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Health & Wellness") {
                    Toggle("Health Tracking", isOn: $featureFlags.healthEnabled)
                    Toggle("Wellness & Circadian", isOn: $featureFlags.wellnessEnabled)
                    Toggle("Cognitive Support", isOn: $featureFlags.cognitiveEnabled)
                }

                Section("Professional") {
                    Toggle("Financial Tracking", isOn: $featureFlags.financialEnabled)
                    Toggle("Career Development", isOn: $featureFlags.careerEnabled)
                    Toggle("Income Analytics", isOn: $featureFlags.incomeEnabled)
                }

                Section("Assessment & Nutrition") {
                    Toggle("Psychological Assessments", isOn: $featureFlags.assessmentEnabled)
                    Toggle("Nutrition Tracking", isOn: $featureFlags.nutritionEnabled)
                }

                #if os(macOS)
                    Section("Display (macOS)") {
                        Toggle("Display Control", isOn: $featureFlags.displayEnabled)
                    }
                #endif
            }
            .navigationTitle("Module Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UnifiedDashboardView()
}
