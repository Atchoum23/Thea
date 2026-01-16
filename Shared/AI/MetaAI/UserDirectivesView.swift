import SwiftUI

// MARK: - User Directives View
// Settings panel for managing user behavioral directives

@MainActor
public struct UserDirectivesView: View {
    @State private var config = UserDirectivesConfiguration.shared
    @State private var showingAddDirective = false
    @State private var newDirectiveText = ""
    @State private var newDirectiveCategory: DirectiveCategory = .quality
    @State private var selectedCategory: DirectiveCategory? = nil
    @State private var showingImportExport = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with description
                headerSection
                
                Divider()
                
                // Category filter
                categoryFilter
                
                Divider()
                
                // Directives list
                directivesList
            }
            .navigationTitle("User Directives")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddDirective = true }) {
                        Label("Add Directive", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(action: exportDirectives) {
                            Label("Export Directives", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { showingImportExport = true }) {
                            Label("Import Directives", systemImage: "square.and.arrow.down")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: resetToDefaults) {
                            Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddDirective) {
                addDirectiveSheet
            }
            .fileImporter(
                isPresented: $showingImportExport,
                allowedContentTypes: [.json],
                onCompletion: handleImport
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Behavioral Directives")
                .font(.headline)
            
            Text("Define persistent preferences that Meta-AI must always follow. These are injected into all AI prompts.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Label("\(config.getActiveDirectives().count) active", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                
                Spacer()
                
                Label("\(config.directives.count) total", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All categories button
                CategoryButton(
                    category: nil,
                    isSelected: selectedCategory == nil,
                    count: config.directives.count,
                    action: {
                        selectedCategory = nil
                    }
                )
                
                // Individual category buttons
                ForEach(DirectiveCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category,
                        count: config.getDirectives(for: category).count,
                        action: {
                            selectedCategory = category
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Directives List
    
    private var directivesList: some View {
        List {
            ForEach(filteredDirectives) { directive in
                DirectiveRow(
                    directive: directive,
                    onToggle: { config.toggleDirective(id: directive.id) },
                    onDelete: { config.deleteDirective(id: directive.id) }
                )
            }
        }
        .listStyle(.plain)
    }
    
    private var filteredDirectives: [UserDirective] {
        if let category = selectedCategory {
            return config.getDirectives(for: category)
        }
        return config.directives
    }
    
    // MARK: - Add Directive Sheet
    
    private var addDirectiveSheet: some View {
        NavigationStack {
            Form {
                Section("Directive Text") {
                    TextEditor(text: $newDirectiveText)
                        .frame(minHeight: 100)
                }
                
                Section("Category") {
                    Picker("Category", selection: $newDirectiveCategory) {
                        ForEach(DirectiveCategory.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(newDirectiveCategory.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Directive")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddDirective = false
                        newDirectiveText = ""
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addDirective()
                    }
                    .disabled(newDirectiveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func addDirective() {
        let directive = UserDirective(
            directive: newDirectiveText.trimmingCharacters(in: .whitespacesAndNewlines),
            category: newDirectiveCategory
        )
        config.addDirective(directive)
        showingAddDirective = false
        newDirectiveText = ""
    }
    
    private func exportDirectives() {
        do {
            let data = try config.exportDirectives()
            
            #if os(macOS)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "user-directives.json"
            
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    try? data.write(to: url)
                }
            }
            #endif
        } catch {
            print("Export failed: \(error)")
        }
    }
    
    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                try config.importDirectives(from: data)
            } catch {
                print("Import failed: \(error)")
            }
            
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
    
    private func resetToDefaults() {
        config.resetToDefaults()
    }
}

// MARK: - Category Button

private struct CategoryButton: View {
    let category: DirectiveCategory?
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                } else {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                }
                
                Text(category?.rawValue ?? "All")
                    .font(.subheadline)
                
                Text("(\(count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Directive Row

private struct DirectiveRow: View {
    let directive: UserDirective
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Toggle button
            Button(action: onToggle) {
                Image(systemName: directive.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(directive.isEnabled ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // Directive content
            VStack(alignment: .leading, spacing: 4) {
                Text(directive.directive)
                    .font(.body)
                    .strikethrough(!directive.isEnabled)
                    .foregroundStyle(directive.isEnabled ? .primary : .secondary)
                
                HStack {
                    Label(directive.category.rawValue, systemImage: directive.category.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if !directive.isEnabled {
                        Text("Disabled")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview {
    UserDirectivesView()
}
