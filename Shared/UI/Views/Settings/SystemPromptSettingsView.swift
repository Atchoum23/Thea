// SystemPromptSettingsView.swift
// User-editable system prompts for different task types

import SwiftUI

struct SystemPromptSettingsView: View {
    @State private var prompts = SystemPromptConfiguration.load()
    @State private var selectedTaskType: TaskType = .simpleQA
    @State private var showingSaveConfirmation = false
    @State private var showingResetConfirmation = false

    var body: some View {
        mainContent
            .alert("Settings Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") { showingSaveConfirmation = false }
            } message: {
                Text("System prompts have been saved.")
            }
            .alert("Reset to Defaults?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    prompts = SystemPromptConfiguration.defaults()
                    prompts.save()
                }
            } message: {
                Text("This will reset all system prompts to their default values.")
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        HSplitView {
            // Task type list
            taskTypeList
                .frame(minWidth: 200, maxWidth: 250)

            // Prompt editor
            promptEditor
                .frame(minWidth: 400)
        }
        .padding()
        #else
        NavigationStack {
            taskTypeListMobile
                .navigationTitle("System Prompts")
        }
        #endif
    }

    // MARK: - Task Type List

    #if os(macOS)
    private var taskTypeList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Types")
                .font(.headline)
                .padding(.bottom, 4)

            List(TaskType.allCases, id: \.self, selection: $selectedTaskType) { taskType in
                HStack {
                    Image(systemName: iconForTaskType(taskType))
                        .foregroundStyle(colorForTaskType(taskType))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(taskType.displayName)
                            .font(.body)

                        if prompts.isCustomized(for: taskType) {
                            Text("Customized")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.vertical, 4)
                .tag(taskType)
            }
            .listStyle(.sidebar)

            Divider()

            // Global settings
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Use Dynamic Prompts", isOn: $prompts.useDynamicPrompts)
                    .onChange(of: prompts.useDynamicPrompts) { _, _ in
                        savePrompts()
                    }

                Text("When enabled, system prompts change based on detected task type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
    }
    #endif

    // Mobile-friendly list for iOS/tvOS/watchOS
    #if !os(macOS)
    private var taskTypeListMobile: some View {
        List {
            Section {
                Toggle("Use Dynamic Prompts", isOn: $prompts.useDynamicPrompts)
                    .onChange(of: prompts.useDynamicPrompts) { _, _ in
                        savePrompts()
                    }

                Text("When enabled, system prompts change based on detected task type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Task Types") {
                ForEach(TaskType.allCases, id: \.self) { taskType in
                    NavigationLink(value: taskType) {
                        HStack {
                            Image(systemName: iconForTaskType(taskType))
                                .foregroundStyle(colorForTaskType(taskType))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(taskType.displayName)
                                    .font(.body)

                                if prompts.isCustomized(for: taskType) {
                                    Text("Customized")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button("Reset All to Defaults", role: .destructive) {
                    showingResetConfirmation = true
                }
            }
        }
        .navigationDestination(for: TaskType.self) { taskType in
            promptEditorMobile(for: taskType)
        }
    }

    private func promptEditorMobile(for taskType: TaskType) -> some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: iconForTaskType(taskType))
                            .font(.title2)
                            .foregroundStyle(colorForTaskType(taskType))
                        Text(taskType.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    Text(descriptionForTaskType(taskType))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Base System Prompt") {
                TextEditor(text: Binding(
                    get: { prompts.basePrompt },
                    set: { prompts.basePrompt = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
                .onChange(of: prompts.basePrompt) { _, _ in
                    savePrompts()
                }

                Text("This prompt is included for all task types.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Task-Specific Instructions") {
                TextEditor(text: Binding(
                    get: { prompts.prompt(for: taskType) },
                    set: { prompts.setPrompt($0, for: taskType) }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150)
                .onChange(of: prompts.prompt(for: taskType)) { _, _ in
                    savePrompts()
                }

                Text("These instructions are added when \(taskType.displayName.lowercased()) tasks are detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if prompts.isCustomized(for: taskType) {
                Section {
                    Button("Reset to Default") {
                        prompts.resetToDefault(for: taskType)
                        savePrompts()
                    }
                }
            }
        }
        .navigationTitle(taskType.displayName)
    }
    #endif

    // MARK: - Prompt Editor

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: iconForTaskType(selectedTaskType))
                    .font(.title2)
                    .foregroundStyle(colorForTaskType(selectedTaskType))

                Text(selectedTaskType.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if prompts.isCustomized(for: selectedTaskType) {
                    Button("Reset to Default") {
                        prompts.resetToDefault(for: selectedTaskType)
                        savePrompts()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Description
            Text(descriptionForTaskType(selectedTaskType))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            // Base prompt section
            VStack(alignment: .leading, spacing: 8) {
                Text("Base System Prompt")
                    .font(.headline)

                TextEditor(text: Binding(
                    get: { prompts.basePrompt },
                    set: { prompts.basePrompt = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .border(Color.secondary.opacity(0.3))
                .onChange(of: prompts.basePrompt) { _, _ in
                    savePrompts()
                }

                Text("This prompt is included for all task types.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Task-specific prompt section
            VStack(alignment: .leading, spacing: 8) {
                Text("Task-Specific Instructions")
                    .font(.headline)

                TextEditor(text: Binding(
                    get: { prompts.prompt(for: selectedTaskType) },
                    set: { prompts.setPrompt($0, for: selectedTaskType) }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .border(Color.secondary.opacity(0.3))
                .onChange(of: prompts.prompt(for: selectedTaskType)) { _, _ in
                    savePrompts()
                }

                Text("These instructions are added when \(selectedTaskType.displayName.lowercased()) tasks are detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Reset All to Defaults") {
                    showingResetConfirmation = true
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()

                Button("Preview Full Prompt") {
                    // Could show a sheet with the full combined prompt
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func savePrompts() {
        prompts.save()
        // Don't show confirmation for every keystroke
    }

    private func iconForTaskType(_ type: TaskType) -> String {
        switch type {
        case .simpleQA, .factual:
            return "questionmark.circle"
        case .codeGeneration:
            return "chevron.left.forwardslash.chevron.right"
        case .debugging:
            return "ladybug"
        case .complexReasoning:
            return "brain"
        case .analysis:
            return "chart.bar.xaxis"
        case .creativeWriting:
            return "pencil.and.outline"
        case .mathLogic:
            return "function"
        case .summarization:
            return "text.alignleft"
        case .planning:
            return "list.bullet.clipboard"
        case .research, .informationRetrieval:
            return "magnifyingglass"
        default:
            return "sparkles"
        }
    }

    private func colorForTaskType(_ type: TaskType) -> Color {
        switch type {
        case .codeGeneration, .debugging:
            return .blue
        case .complexReasoning, .analysis:
            return .purple
        case .creativeWriting:
            return .orange
        case .mathLogic:
            return .green
        case .research, .informationRetrieval:
            return .teal
        default:
            return .secondary
        }
    }

    private func descriptionForTaskType(_ type: TaskType) -> String {
        switch type {
        case .simpleQA:
            return "Simple questions with straightforward answers"
        case .factual:
            return "Factual lookups and information queries"
        case .codeGeneration:
            return "Writing new code, functions, or programs"
        case .debugging:
            return "Finding and fixing bugs in code"
        case .complexReasoning:
            return "Multi-step reasoning and logical analysis"
        case .analysis:
            return "Evaluating and comparing options"
        case .creativeWriting:
            return "Stories, poems, and creative content"
        case .mathLogic:
            return "Mathematical calculations and proofs"
        case .summarization:
            return "Condensing long content into summaries"
        case .planning:
            return "Creating plans and strategies"
        case .research:
            return "In-depth research and investigation"
        case .informationRetrieval:
            return "Finding specific information"
        default:
            return "General purpose tasks"
        }
    }
}

// MARK: - Preview

#if os(macOS)
#Preview {
    SystemPromptSettingsView()
        .frame(width: 800, height: 600)
}
#else
#Preview {
    SystemPromptSettingsView()
}
#endif
