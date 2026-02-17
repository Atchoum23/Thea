// ResponseStylesSettingsView.swift
// Thea — Manage named response-style presets that shape how Thea writes replies.

import SwiftUI

// MARK: - Response Styles Settings View

struct ResponseStylesSettingsView: View {
    @StateObject private var settings = SettingsManager.shared

    // Sheet state for adding/editing custom styles
    @State private var isAddingStyle = false
    @State private var editingStyle: ResponseStyle?
    @State private var showDeleteConfirmation = false
    @State private var styleToDelete: ResponseStyle?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            // Style list
            ScrollView {
                LazyVStack(spacing: 12) {
                    // "None" option — clears the active style
                    noneStyleRow

                    // Built-in styles
                    Section {
                        ForEach(ResponseStyle.builtInStyles) { style in
                            StyleRow(
                                style: style,
                                isSelected: settings.selectedResponseStyleID == style.id,
                                onSelect: { selectStyle(style) },
                                onEdit: nil,
                                onDelete: nil
                            )
                        }
                    } header: {
                        sectionHeader("Built-in Styles")
                    }

                    // Custom styles
                    if !settings.customResponseStyles.isEmpty {
                        Section {
                            ForEach(settings.customResponseStyles) { style in
                                StyleRow(
                                    style: style,
                                    isSelected: settings.selectedResponseStyleID == style.id,
                                    onSelect: { selectStyle(style) },
                                    onEdit: { editingStyle = style },
                                    onDelete: { confirmDelete(style) }
                                )
                            }
                        } header: {
                            sectionHeader("Custom Styles")
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer toolbar
            footerBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .navigationTitle("Response Styles")
        .sheet(isPresented: $isAddingStyle) {
            StyleEditorView(mode: .new) { newStyle in
                settings.customResponseStyles.append(newStyle)
            }
        }
        .sheet(item: $editingStyle) { style in
            StyleEditorView(mode: .edit(style)) { updated in
                if let index = settings.customResponseStyles.firstIndex(where: { $0.id == updated.id }) {
                    settings.customResponseStyles[index] = updated
                    // If the edited style was active, keep it active
                    if settings.selectedResponseStyleID == updated.id {
                        settings.selectedResponseStyleID = updated.id
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Style",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let style = styleToDelete {
                    deleteCustomStyle(style)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(styleToDelete?.name ?? "")\"? This cannot be undone.")
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Response Styles")
                .font(.title2.bold())
            Text("Choose a preset style that shapes every response Thea writes. The active style appends instructions to the system prompt.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var noneStyleRow: some View {
        Button {
            settings.selectedResponseStyleID = nil
        } label: {
            HStack {
                Image(systemName: settings.selectedResponseStyleID == nil ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(settings.selectedResponseStyleID == nil ? Color.accentColor : .secondary)
                    .imageScale(.medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text("None")
                        .font(.body.bold())
                    Text("No style active — Thea uses its default response format.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                settings.selectedResponseStyleID == nil
                    ? Color.accentColor.opacity(0.1)
                    : Color(nsColor: .controlBackgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        settings.selectedResponseStyleID == nil ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: settings.selectedResponseStyleID == nil ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No style")
        .accessibilityHint("Removes the active response style")
        .accessibilityAddTraits(settings.selectedResponseStyleID == nil ? .isSelected : [])
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.uppercaseSmallCaps())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private var footerBar: some View {
        HStack {
            if let active = settings.activeResponseStyle {
                Label("Active: \(active.name)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("No style active", systemImage: "circle.dashed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                isAddingStyle = true
            } label: {
                Label("Add Custom Style", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel("Add custom response style")
            .accessibilityHint("Opens editor to create a new response style")
        }
    }

    // MARK: - Actions

    private func selectStyle(_ style: ResponseStyle) {
        settings.selectedResponseStyleID = style.id
    }

    private func confirmDelete(_ style: ResponseStyle) {
        styleToDelete = style
        showDeleteConfirmation = true
    }

    private func deleteCustomStyle(_ style: ResponseStyle) {
        settings.customResponseStyles.removeAll { $0.id == style.id }
        // Clear selection if the deleted style was active
        if settings.selectedResponseStyleID == style.id {
            settings.selectedResponseStyleID = nil
        }
    }
}

// MARK: - Style Row

private struct StyleRow: View {
    let style: ResponseStyle
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection indicator
            Button {
                onSelect()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .imageScale(.medium)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(style.name), \(isSelected ? "selected" : "not selected")")
            .accessibilityHint("Select this style")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(style.name)
                        .font(.body.bold())

                    if style.isBuiltIn {
                        Text("Built-in")
                            .font(.caption2.uppercaseSmallCaps())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    // Edit/Delete buttons for custom styles (visible on hover)
                    if isHovering, !style.isBuiltIn {
                        HStack(spacing: 6) {
                            if let onEdit {
                                Button {
                                    onEdit()
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Edit \(style.name)")
                            }

                            if let onDelete {
                                Button {
                                    onDelete()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(style.name)")
                            }
                        }
                        .transition(.opacity)
                    }
                }

                Text(style.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Preview suffix (collapsed to 2 lines)
                Text(style.systemPromptSuffix)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.08)
                : Color(nsColor: .controlBackgroundColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isSelected ? 1.5 : 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Style Editor View

enum StyleEditorMode {
    case new
    case edit(ResponseStyle)
}

struct StyleEditorView: View {
    let mode: StyleEditorMode
    let onSave: (ResponseStyle) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var systemPromptSuffix: String = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String { isEditing ? "Edit Style" : "New Style" }

    var body: some View {
        NavigationStack {
            Form {
                Section("Style Name") {
                    TextField("e.g. Executive Summary", text: $name)
                        .accessibilityLabel("Style name")
                }

                Section("Description") {
                    TextField("Brief description of when to use this style", text: $description)
                        .accessibilityLabel("Style description")
                }

                Section {
                    TextEditor(text: $systemPromptSuffix)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .accessibilityLabel("System prompt suffix")
                } header: {
                    Text("System Prompt Suffix")
                } footer: {
                    Text("This text is appended to the system prompt when the style is active. Use imperative instructions: \"Be concise. Use bullet points.\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel editing")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  systemPromptSuffix.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel("Save style")
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .onAppear { populateFields() }
    }

    private func populateFields() {
        if case let .edit(style) = mode {
            name = style.name
            description = style.description
            systemPromptSuffix = style.systemPromptSuffix
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedSuffix = systemPromptSuffix.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedSuffix.isEmpty else { return }

        let styleID: String
        if case let .edit(existing) = mode {
            styleID = existing.id
        } else {
            styleID = UUID().uuidString
        }

        let style = ResponseStyle(
            id: styleID,
            name: trimmedName,
            description: description.trimmingCharacters(in: .whitespaces),
            systemPromptSuffix: trimmedSuffix,
            isBuiltIn: false
        )
        onSave(style)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResponseStylesSettingsView()
    }
    .frame(width: 600, height: 600)
}
