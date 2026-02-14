// AdvancedPromptSettingsView.swift
// Comprehensive prompt management - add, view, manage, edit, delete, order, classify

import SwiftUI

struct AdvancedPromptSettingsView: View {
    @State private var promptLibrary = PromptLibrary.load()
    @State private var selectedPrompt: CustomPrompt?
    @State private var showingAddPrompt = false
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""

    var body: some View {
        mainContent
            .sheet(isPresented: $showingAddPrompt) {
                AddPromptView(library: $promptLibrary) { newPrompt in
                    selectedPrompt = newPrompt
                }
            }
            .alert("Delete Prompt?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let prompt = selectedPrompt {
                        promptLibrary.remove(prompt)
                        selectedPrompt = nil
                        promptLibrary.save()
                    }
                }
            } message: {
                Text("This prompt will be permanently deleted.")
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        HSplitView {
            // Left: Prompt list
            promptListView
                .frame(minWidth: 250, maxWidth: 300)

            // Right: Prompt editor
            if let prompt = selectedPrompt {
                promptEditorView(prompt)
            } else {
                emptyStateView
            }
        }
        #else
        NavigationStack {
            promptListView
                .navigationTitle("Custom Prompts")
                .navigationDestination(item: $selectedPrompt) { prompt in
                    promptEditorView(prompt)
                }
        }
        #endif
    }

    // MARK: - Prompt List

    private var promptListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Custom Prompts")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddPrompt = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            // Search
            TextField("Search prompts...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Divider()
                .padding(.top, 8)

            // Categories
            List(selection: $selectedPrompt) {
                ForEach(PromptCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(filteredPrompts(for: category)) { prompt in
                            promptRow(prompt)
                                .tag(prompt)
                        }
                        .onMove { indices, destination in
                            promptLibrary.move(in: category, from: indices, to: destination)
                            promptLibrary.save()
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Stats
            HStack {
                Text("\(promptLibrary.prompts.count) prompts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(8)
        }
    }

    private func promptRow(_ prompt: CustomPrompt) -> some View {
        HStack {
            Image(systemName: prompt.category.icon)
                .foregroundStyle(prompt.category.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.name)
                    .font(.body)

                if prompt.isActive {
                    Text("Active")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .contextMenu {
            Button("Duplicate") {
                let duplicate = prompt.duplicate()
                promptLibrary.add(duplicate)
                selectedPrompt = duplicate
                promptLibrary.save()
            }

            Toggle("Active", isOn: Binding(
                get: { prompt.isActive },
                set: { newValue in
                    promptLibrary.setActive(prompt, active: newValue)
                    promptLibrary.save()
                }
            ))

            Divider()

            Button("Delete", role: .destructive) {
                selectedPrompt = prompt
                showingDeleteConfirmation = true
            }
        }
    }

    private func filteredPrompts(for category: PromptCategory) -> [CustomPrompt] {
        promptLibrary.prompts(for: category).filter { prompt in
            searchText.isEmpty || prompt.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Prompt Editor

    private func promptEditorView(_ prompt: CustomPrompt) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                promptEditorHeader(prompt)
                Divider()
                promptEditorCategoryScope(prompt)
                promptEditorContent(prompt)
                promptEditorPriority(prompt)
                promptEditorConditions(prompt)
                Spacer()
                promptEditorActions
            }
            .padding()
        }
    }

    @ViewBuilder
    private func promptEditorHeader(_ prompt: CustomPrompt) -> some View {
        HStack {
            Image(systemName: prompt.category.icon)
                .font(.title)
                .foregroundStyle(prompt.category.color)

            VStack(alignment: .leading) {
                TextField("Prompt Name", text: Binding(
                    get: { prompt.name },
                    set: { newValue in
                        promptLibrary.update(prompt) { $0.name = newValue }
                        promptLibrary.save()
                    }
                ))
                .font(.title2)
                .textFieldStyle(.plain)

                Text("Category: \(prompt.category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Active", isOn: Binding(
                get: { prompt.isActive },
                set: { newValue in
                    promptLibrary.setActive(prompt, active: newValue)
                    promptLibrary.save()
                }
            ))
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func promptEditorCategoryScope(_ prompt: CustomPrompt) -> some View {
        Picker("Category", selection: Binding(
            get: { prompt.category },
            set: { newValue in
                promptLibrary.update(prompt) { $0.category = newValue }
                promptLibrary.save()
            }
        )) {
            ForEach(PromptCategory.allCases, id: \.self) { cat in
                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
            }
        }
        .pickerStyle(.menu)

        Picker("Applies To", selection: Binding(
            get: { prompt.scope },
            set: { newValue in
                promptLibrary.update(prompt) { $0.scope = newValue }
                promptLibrary.save()
            }
        )) {
            ForEach(PromptScope.allCases, id: \.self) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func promptEditorContent(_ prompt: CustomPrompt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt Content")
                .font(.headline)

            TextEditor(text: Binding(
                get: { prompt.content },
                set: { newValue in
                    promptLibrary.update(prompt) { $0.content = newValue }
                    promptLibrary.save()
                }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 200)
            .border(Color.secondary.opacity(0.3))

            Text("\(prompt.content.count) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func promptEditorPriority(_ prompt: CustomPrompt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Priority")
                    .font(.headline)
                Spacer()
                Text("\(prompt.priority)")
                    .foregroundStyle(.secondary)
            }

            Slider(value: Binding(
                get: { Double(prompt.priority) },
                set: { newValue in
                    promptLibrary.update(prompt) { $0.priority = Int(newValue) }
                    promptLibrary.save()
                }
            ), in: 1...10, step: 1)

            Text("Higher priority prompts are applied first")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func promptEditorConditions(_ prompt: CustomPrompt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conditions (Optional)")
                .font(.headline)

            TextField("e.g., when message contains 'code'", text: Binding(
                get: { prompt.conditions ?? "" },
                set: { newValue in
                    promptLibrary.update(prompt) { $0.conditions = newValue.isEmpty ? nil : newValue }
                    promptLibrary.save()
                }
            ))
            .textFieldStyle(.roundedBorder)

            Text("Prompt is only applied when conditions are met")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var promptEditorActions: some View {
        HStack {
            Button("Delete", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Test Prompt") {
                // Could open a test dialog
            }
            .buttonStyle(.bordered)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Prompt Selected")
                .font(.headline)

            Text("Select a prompt from the list or create a new one")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Create New Prompt") {
                showingAddPrompt = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Add Prompt View

struct AddPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var library: PromptLibrary
    var onAdd: (CustomPrompt) -> Void

    @State private var name = ""
    @State private var content = ""
    @State private var category: PromptCategory = .general
    @State private var scope: PromptScope = .all

    var body: some View {
        VStack(spacing: 20) {
            Text("New Custom Prompt")
                .font(.headline)

            Form {
                TextField("Name", text: $name)

                Picker("Category", selection: $category) {
                    ForEach(PromptCategory.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }

                Picker("Scope", selection: $scope) {
                    ForEach(PromptScope.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }

                TextEditor(text: $content)
                    .frame(height: 150)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add") {
                    let prompt = CustomPrompt(
                        name: name,
                        content: content,
                        category: category,
                        scope: scope,
                        isActive: true,
                        priority: 5
                    )
                    library.add(prompt)
                    library.save()
                    onAdd(prompt)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || content.isEmpty)
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 500, height: 400)
        #endif
    }
}

// MARK: - Data Models

enum PromptCategory: String, Codable, CaseIterable {
    case general = "General"
    case coding = "Coding"
    case writing = "Writing"
    case analysis = "Analysis"
    case research = "Research"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .general: return "text.bubble"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil"
        case .analysis: return "chart.bar"
        case .research: return "magnifyingglass"
        case .custom: return "star"
        }
    }

    var color: Color {
        switch self {
        case .general: return .blue
        case .coding: return .green
        case .writing: return .orange
        case .analysis: return .purple
        case .research: return .teal
        case .custom: return .yellow
        }
    }
}

enum PromptScope: String, Codable, CaseIterable {
    case all = "All Chats"
    case project = "Current Project"
    case conversation = "Current Conversation"
}

// CustomPrompt, PromptLibrary, and Preview are in AdvancedPromptSettingsTypes.swift
