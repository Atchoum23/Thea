// TerminalSettingsViewSections.swift
// Supporting views for TerminalSettingsView

#if os(macOS)
import SwiftUI

// MARK: - Quick Commands Editor

struct QuickCommandsEditorView: View {
    @StateObject private var manager = TerminalIntegrationManager.shared
    @State private var showingAddSheet = false
    @State private var editingCommand: QuickCommand?

    @State private var newName = ""
    @State private var newCommand = ""
    @State private var newIcon = "terminal"
    @State private var newCategory: QuickCommand.Category = .custom

    var body: some View {
        List {
            ForEach(QuickCommand.Category.allCases, id: \.self) { category in
                let commands = manager.quickCommands.filter { $0.category == category }
                if !commands.isEmpty {
                    Section(category.rawValue) {
                        ForEach(commands) { command in
                            HStack {
                                Image(systemName: command.icon)
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(command.name)
                                    Text(command.command)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingCommand = command
                            }
                        }
                        .onDelete { indexSet in
                            let categoryCommands = commands
                            for index in indexSet {
                                let commandToDelete = categoryCommands[index]
                                manager.quickCommands.removeAll { $0.id == commandToDelete.id }
                            }
                            manager.saveConfiguration()
                        }
                    }
                }
            }
        }
        .navigationTitle("Quick Commands")
        .toolbar {
            Button {
                resetAddForm()
                showingAddSheet = true
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            addCommandSheet
        }
        .sheet(item: $editingCommand) { command in
            editCommandSheet(command)
        }
    }

    private var addCommandSheet: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $newName)
                TextField("Command", text: $newCommand)
                    .font(.system(.body, design: .monospaced))

                Picker("Category", selection: $newCategory) {
                    ForEach(QuickCommand.Category.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }

                TextField("Icon (SF Symbol)", text: $newIcon)
            }
            .navigationTitle("Add Quick Command")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let command = QuickCommand(
                            name: newName,
                            command: newCommand,
                            icon: newIcon,
                            category: newCategory
                        )
                        manager.addQuickCommand(command)
                        showingAddSheet = false
                    }
                    .disabled(newName.isEmpty || newCommand.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 300)
    }

    private func editCommandSheet(_ command: QuickCommand) -> some View {
        NavigationStack {
            Form {
                TextField("Name", text: Binding(
                    get: { command.name },
                    set: { newValue in
                        if let index = manager.quickCommands.firstIndex(where: { $0.id == command.id }) {
                            manager.quickCommands[index].name = newValue
                        }
                    }
                ))

                TextField("Command", text: Binding(
                    get: { command.command },
                    set: { newValue in
                        if let index = manager.quickCommands.firstIndex(where: { $0.id == command.id }) {
                            manager.quickCommands[index].command = newValue
                        }
                    }
                ))
                .font(.system(.body, design: .monospaced))

                Picker("Category", selection: Binding(
                    get: { command.category },
                    set: { newValue in
                        if let index = manager.quickCommands.firstIndex(where: { $0.id == command.id }) {
                            manager.quickCommands[index].category = newValue
                        }
                    }
                )) {
                    ForEach(QuickCommand.Category.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }

                TextField("Icon (SF Symbol)", text: Binding(
                    get: { command.icon },
                    set: { newValue in
                        if let index = manager.quickCommands.firstIndex(where: { $0.id == command.id }) {
                            manager.quickCommands[index].icon = newValue
                        }
                    }
                ))

                Section {
                    Button("Delete Command", role: .destructive) {
                        manager.removeQuickCommand(command)
                        editingCommand = nil
                    }
                }
            }
            .navigationTitle("Edit Command")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        manager.saveConfiguration()
                        editingCommand = nil
                    }
                }
            }
        }
        .frame(width: 400, height: 350)
    }

    private func resetAddForm() {
        newName = ""
        newCommand = ""
        newIcon = "terminal"
        newCategory = .custom
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TerminalSettingsView()
    }
    .frame(width: 600, height: 800)
}
#endif
