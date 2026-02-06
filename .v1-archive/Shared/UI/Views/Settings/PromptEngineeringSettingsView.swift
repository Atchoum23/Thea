import SwiftUI

// MARK: - Prompt Engineering Settings View
// Settings UI for automatic prompt engineering configuration

struct PromptEngineeringSettingsView: View {
    @State private var config = AutomaticPromptEngineering.shared.configuration
    @State private var showAdvancedSettings = false
    @State private var showOptimizationStats = false

    var body: some View {
        Form {
            // MARK: - Main Toggle
            Section {
                Toggle("Enable Automatic Prompt Engineering", isOn: $config.enableAutomaticOptimization)
                    .onChange(of: config.enableAutomaticOptimization) { _, _ in
                        saveConfiguration()
                    }

                if config.enableAutomaticOptimization {
                    Text("Thea automatically optimizes your prompts using advanced techniques like Chain-of-Thought reasoning, context injection, and pattern learning.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Automatic Optimization", systemImage: "wand.and.stars")
            }

            if config.enableAutomaticOptimization {
                // MARK: - Reasoning Techniques
                Section {
                    Toggle("Chain-of-Thought", isOn: $config.enableChainOfThought)
                        .onChange(of: config.enableChainOfThought) { _, _ in saveConfiguration() }

                    if config.enableChainOfThought {
                        Text("Breaks down complex problems into step-by-step reasoning")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Tree-of-Thoughts", isOn: $config.enableTreeOfThoughts)
                        .onChange(of: config.enableTreeOfThoughts) { _, _ in saveConfiguration() }

                    if config.enableTreeOfThoughts {
                        Text("Explores multiple reasoning paths for complex tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Self-Consistency", isOn: $config.enableSelfConsistency)
                        .onChange(of: config.enableSelfConsistency) { _, _ in saveConfiguration() }

                    if config.enableSelfConsistency {
                        Text("Uses multiple reasoning paths and selects the most consistent answer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("ReAct Pattern", isOn: $config.enableReActPattern)
                        .onChange(of: config.enableReActPattern) { _, _ in saveConfiguration() }

                    if config.enableReActPattern {
                        Text("Interleaves reasoning with actions for coding tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Reasoning Techniques", systemImage: "brain.head.profile")
                }

                // MARK: - Context Optimization
                Section {
                    Toggle("Context Injection", isOn: $config.enableContextInjection)
                        .onChange(of: config.enableContextInjection) { _, _ in saveConfiguration() }

                    Toggle("Few-Shot Examples", isOn: $config.enableFewShotSelection)
                        .onChange(of: config.enableFewShotSelection) { _, _ in saveConfiguration() }

                    Toggle("Role Assignment", isOn: $config.enableRoleAssignment)
                        .onChange(of: config.enableRoleAssignment) { _, _ in saveConfiguration() }

                    Toggle("Output Formatting", isOn: $config.enableOutputFormatting)
                        .onChange(of: config.enableOutputFormatting) { _, _ in saveConfiguration() }
                } header: {
                    Label("Context Optimization", systemImage: "doc.text.magnifyingglass")
                } footer: {
                    Text("Automatically adds relevant context, examples, and formatting instructions based on your task type.")
                }

                // MARK: - Learning
                Section {
                    Toggle("Track Outcomes", isOn: $config.enableOutcomeTracking)
                        .onChange(of: config.enableOutcomeTracking) { _, _ in saveConfiguration() }

                    Toggle("Pattern Learning", isOn: $config.enablePatternLearning)
                        .onChange(of: config.enablePatternLearning) { _, _ in saveConfiguration() }

                    if config.enablePatternLearning {
                        HStack {
                            Text("Learning Rate")
                            Spacer()
                            Text(String(format: "%.2f", config.learningRate))
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $config.learningRate, in: 0.01...0.3, step: 0.01)
                            .onChange(of: config.learningRate) { _, _ in saveConfiguration() }
                    }
                } header: {
                    Label("Continuous Learning", systemImage: "chart.line.uptrend.xyaxis")
                } footer: {
                    Text("Thea learns from your feedback to improve future prompt optimization.")
                }

                // MARK: - Advanced Settings
                Section {
                    DisclosureGroup("Advanced Settings", isExpanded: $showAdvancedSettings) {
                        // Self-Consistency Settings
                        Group {
                            Stepper(
                                "Consistency Paths: \(config.selfConsistencyPaths)",
                                value: $config.selfConsistencyPaths,
                                in: 2...5
                            )
                            .onChange(of: config.selfConsistencyPaths) { _, _ in saveConfiguration() }

                            HStack {
                                Text("Voting Threshold")
                                Spacer()
                                Text(String(format: "%.0f%%", config.majorityVotingThreshold * 100))
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $config.majorityVotingThreshold, in: 0.5...0.9, step: 0.1)
                                .onChange(of: config.majorityVotingThreshold) { _, _ in saveConfiguration() }
                        }

                        Divider()

                        // Tree-of-Thoughts Settings
                        Group {
                            Stepper(
                                "Branch Factor: \(config.totBranchFactor)",
                                value: $config.totBranchFactor,
                                in: 2...5
                            )
                            .onChange(of: config.totBranchFactor) { _, _ in saveConfiguration() }

                            Stepper(
                                "Max Depth: \(config.totMaxDepth)",
                                value: $config.totMaxDepth,
                                in: 2...5
                            )
                            .onChange(of: config.totMaxDepth) { _, _ in saveConfiguration() }

                            Picker("Evaluation Strategy", selection: $config.totEvaluationStrategy) {
                                Text("Best First").tag(AutomaticPromptEngineering.Configuration.EvaluationStrategy.bestFirst)
                                Text("Breadth First").tag(AutomaticPromptEngineering.Configuration.EvaluationStrategy.breadthFirst)
                                Text("Depth First").tag(AutomaticPromptEngineering.Configuration.EvaluationStrategy.depthFirst)
                            }
                            .onChange(of: config.totEvaluationStrategy) { _, _ in saveConfiguration() }
                        }
                    }
                } header: {
                    Label("Fine-Tuning", systemImage: "slider.horizontal.3")
                }

                // MARK: - Statistics
                Section {
                    Button {
                        showOptimizationStats = true
                    } label: {
                        HStack {
                            Text("View Optimization Statistics")
                            Spacer()
                            Image(systemName: "chart.bar")
                        }
                    }
                } header: {
                    Label("Analytics", systemImage: "chart.pie")
                }

                // MARK: - Reset
                Section {
                    Button(role: .destructive) {
                        resetToDefaults()
                    } label: {
                        Text("Reset to Defaults")
                    }
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(minWidth: 500)
        #endif
        .navigationTitle("Prompt Engineering")
        .sheet(isPresented: $showOptimizationStats) {
            OptimizationStatsView()
        }
    }

    private func saveConfiguration() {
        Task { @MainActor in
            AutomaticPromptEngineering.shared.updateConfiguration(config)
        }
    }

    private func resetToDefaults() {
        config = AutomaticPromptEngineering.Configuration()
        saveConfiguration()
    }
}

// MARK: - Optimization Stats View

struct OptimizationStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stats: OptimizationStats?
    @State private var lastDetails: OptimizationDetails?

    var body: some View {
        NavigationStack {
            List {
                if let stats {
                    Section("Overview") {
                        StatRow(title: "Total Templates", value: "\(stats.totalTemplates)")
                        StatRow(title: "Average Success Rate", value: String(format: "%.1f%%", stats.averageSuccessRate * 100))
                        StatRow(title: "Total Optimizations", value: "\(stats.totalOptimizations)")
                        StatRow(title: "Few-Shot Examples", value: "\(stats.fewShotExamplesCount)")
                    }
                }

                if let details = lastDetails {
                    Section("Last Optimization") {
                        StatRow(title: "Task Type", value: details.taskType.rawValue)
                        StatRow(title: "Strategy", value: details.strategyUsed.rawValue)
                        StatRow(title: "Complexity", value: details.estimatedComplexity.rawValue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Applied Contexts")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ForEach(details.contextsApplied, id: \.self) { context in
                                Label(context, systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                if stats == nil && lastDetails == nil {
                    ContentUnavailableView(
                        "No Statistics Yet",
                        systemImage: "chart.bar",
                        description: Text("Use Thea to start generating optimization statistics.")
                    )
                }
            }
            .navigationTitle("Optimization Statistics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadStats()
            }
        }
    }

    private func loadStats() async {
        stats = await PromptOptimizer.shared.getOptimizationStats()
        lastDetails = await MainActor.run {
            AutomaticPromptEngineering.shared.lastOptimizationDetails
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        PromptEngineeringSettingsView()
    }
}
