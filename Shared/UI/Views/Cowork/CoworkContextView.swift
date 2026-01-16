import SwiftUI

/// View showing context information for the current Cowork session
struct CoworkContextView: View {
    @StateObject private var manager = CoworkManager.shared
    @State private var selectedSection: ContextSection = .files
    @State private var showingRuleEditor = false
    @State private var editingRule: CoworkContext.Rule?

    enum ContextSection: String, CaseIterable {
        case files = "Files"
        case urls = "URLs"
        case connectors = "Connectors"
        case rules = "Rules"
        case environment = "Environment"

        var icon: String {
            switch self {
            case .files: return "doc"
            case .urls: return "link"
            case .connectors: return "puzzlepiece"
            case .rules: return "list.bullet.rectangle"
            case .environment: return "gearshape.2"
            }
        }
    }

    var body: some View {
        HSplitView {
            // Section list
            sectionList
                .frame(minWidth: 150, maxWidth: 200)

            // Content
            contentView
        }
        .sheet(isPresented: $showingRuleEditor) {
            ruleEditorSheet
        }
    }

    // MARK: - Section List

    private var sectionList: some View {
        List(selection: $selectedSection) {
            ForEach(ContextSection.allCases, id: \.self) { section in
                HStack {
                    Image(systemName: section.icon)
                        .frame(width: 20)
                    Text(section.rawValue)
                    Spacer()
                    countBadge(for: section)
                }
                .tag(section)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func countBadge(for section: ContextSection) -> some View {
        if let session = manager.currentSession {
            let count: Int
            switch section {
            case .files:
                count = session.context.uniqueFilesAccessed.count
            case .urls:
                count = session.context.uniqueURLsAccessed.count
            case .connectors:
                count = session.context.activeConnectors.count
            case .rules:
                count = session.context.enabledRules.count
            case .environment:
                count = session.context.environmentVariables.count
            }

            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .files:
            filesView
        case .urls:
            urlsView
        case .connectors:
            connectorsView
        case .rules:
            rulesView
        case .environment:
            environmentView
        }
    }

    // MARK: - Files View

    private var filesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Accessed Files")
                    .font(.headline)
                Spacer()
                if let session = manager.currentSession {
                    Text("\(session.context.uniqueFilesAccessed.count) files")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            // File list
            if let session = manager.currentSession, !session.context.accessedFiles.isEmpty {
                List(session.context.accessedFiles) { access in
                    fileAccessRow(access)
                }
                .listStyle(.inset)
            } else {
                emptyStateView("No files accessed yet")
            }
        }
    }

    private func fileAccessRow(_ access: CoworkContext.FileAccess) -> some View {
        HStack(spacing: 12) {
            // Access type indicator
            accessTypeIcon(access.accessType)

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(access.url.lastPathComponent)
                    .font(.body)

                Text(access.url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Modification indicator
            if access.wasModified {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.orange)
            }

            // Time
            Text(access.accessedAt, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([access.url])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }

            Button {
                copyToClipboard(access.url.path)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
        }
    }

    @ViewBuilder
    private func accessTypeIcon(_ type: CoworkContext.FileAccess.AccessType) -> some View {
        let config: (icon: String, color: Color) = {
            switch type {
            case .read: return ("eye", .blue)
            case .write: return ("pencil", .green)
            case .execute: return ("play", .purple)
            case .delete: return ("trash", .red)
            }
        }()

        Image(systemName: config.icon)
            .foregroundStyle(config.color)
            .frame(width: 20)
    }

    // MARK: - URLs View

    private var urlsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Accessed URLs")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            if let session = manager.currentSession, !session.context.accessedURLs.isEmpty {
                List(session.context.accessedURLs) { access in
                    HStack {
                        Image(systemName: access.wasCached ? "arrow.clockwise.circle" : "globe")
                            .foregroundStyle(access.wasCached ? .orange : .blue)

                        VStack(alignment: .leading) {
                            if let title = access.title {
                                Text(title)
                                    .font(.body)
                            }
                            Text(access.url.absoluteString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(access.accessedAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button {
                            NSWorkspace.shared.open(access.url)
                        } label: {
                            Label("Open URL", systemImage: "arrow.up.forward.square")
                        }
                    }
                }
                .listStyle(.inset)
            } else {
                emptyStateView("No URLs accessed yet")
            }
        }
    }

    // MARK: - Connectors View

    private var connectorsView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Active Connectors")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            if let session = manager.currentSession, !session.context.activeConnectors.isEmpty {
                List(session.context.activeConnectors, id: \.self) { connector in
                    HStack {
                        Image(systemName: "puzzlepiece.fill")
                            .foregroundStyle(.purple)
                        Text(connector)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .listStyle(.inset)
            } else {
                emptyStateView("No connectors active")
            }
        }
    }

    // MARK: - Rules View

    private var rulesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Custom Rules")
                    .font(.headline)
                Spacer()
                Button {
                    editingRule = nil
                    showingRuleEditor = true
                } label: {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            if let session = manager.currentSession, !session.context.customRules.isEmpty {
                List {
                    ForEach(session.context.customRules) { rule in
                        ruleRow(rule)
                    }
                }
                .listStyle(.inset)
            } else {
                emptyStateView("No custom rules defined")
            }
        }
    }

    private func ruleRow(_ rule: CoworkContext.Rule) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { newValue in
                    if let index = manager.currentSession?.context.customRules.firstIndex(where: { $0.id == rule.id }) {
                        manager.currentSession?.context.customRules[index].isEnabled = newValue
                    }
                }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.body)
                Text(rule.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Priority: \(rule.priority)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button {
                editingRule = rule
                showingRuleEditor = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                manager.currentSession?.context.removeRule(rule.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Environment View

    private var environmentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Environment Variables")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            if let session = manager.currentSession, !session.context.environmentVariables.isEmpty {
                List {
                    ForEach(Array(session.context.environmentVariables.keys.sorted()), id: \.self) { key in
                        if let value = session.context.environmentVariables[key] {
                            HStack {
                                Text(key)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text("=")
                                    .foregroundStyle(.secondary)
                                Text(value)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            } else {
                emptyStateView("No environment variables set")
            }
        }
    }

    // MARK: - Rule Editor Sheet

    private var ruleEditorSheet: some View {
        RuleEditorView(rule: editingRule) { rule in
            if let existing = editingRule {
                // Update existing rule
                if let index = manager.currentSession?.context.customRules.firstIndex(where: { $0.id == existing.id }) {
                    manager.currentSession?.context.customRules[index] = rule
                }
            } else {
                // Add new rule
                manager.currentSession?.context.addRule(rule)
            }
            showingRuleEditor = false
        }
    }

    // MARK: - Empty State

    private func emptyStateView(_ message: String) -> some View {
        ContentUnavailableView {
            Label(message, systemImage: "tray")
        }
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Rule Editor View

struct RuleEditorView: View {
    let rule: CoworkContext.Rule?
    let onSave: (CoworkContext.Rule) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var priority: Int = 0
    @State private var isEnabled: Bool = true

    @Environment(\.dismiss) private var dismiss

    init(rule: CoworkContext.Rule?, onSave: @escaping (CoworkContext.Rule) -> Void) {
        self.rule = rule
        self.onSave = onSave

        if let rule = rule {
            _name = State(initialValue: rule.name)
            _description = State(initialValue: rule.description)
            _priority = State(initialValue: rule.priority)
            _isEnabled = State(initialValue: rule.isEnabled)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3)
                Stepper("Priority: \(priority)", value: $priority, in: 0...100)
                Toggle("Enabled", isOn: $isEnabled)
            }
            .formStyle(.grouped)
            .navigationTitle(rule == nil ? "New Rule" : "Edit Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newRule = CoworkContext.Rule(
                            name: name,
                            description: description,
                            isEnabled: isEnabled,
                            priority: priority
                        )
                        onSave(newRule)
                    }
                    .disabled(name.isEmpty || description.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    CoworkContextView()
        .frame(width: 700, height: 500)
}
