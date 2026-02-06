import SwiftUI

struct PluginManagerView: View {
    @State private var pluginSystem = PluginSystem.shared
    @State private var selectedTab = 0
    @State private var showingPluginMarketplace = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Installed").tag(0)
                Text("Available").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            TabView(selection: $selectedTab) {
                InstalledPluginsView(plugins: pluginSystem.installedPlugins)
                    .tag(0)

                AvailablePluginsView()
                    .tag(1)
            }
            .tabViewStyle(.automatic)
        }
        .navigationTitle("Plugin Manager")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingPluginMarketplace = true }) {
                    Label("Browse Marketplace", systemImage: "square.grid.2x2")
                }
            }
        }
        .sheet(isPresented: $showingPluginMarketplace) {
            PluginMarketplaceSheet()
        }
    }
}

// MARK: - Installed Plugins

struct InstalledPluginsView: View {
    let plugins: [Plugin]

    var body: some View {
        if plugins.isEmpty {
            ContentUnavailableView(
                "No Plugins Installed",
                systemImage: "puzzlepiece.extension",
                description: Text("Install plugins from the marketplace to extend THEA's capabilities")
            )
        } else {
            List(plugins) { plugin in
                PluginRowView(plugin: plugin)
            }
        }
    }
}

struct PluginRowView: View {
    let plugin: Plugin
    @State private var showingDetails = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plugin.manifest.name)
                        .font(.headline)

                    if plugin.isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                Text(plugin.manifest.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Label(plugin.manifest.type.rawValue, systemImage: typeIcon(plugin.manifest.type))
                    Spacer()
                    Text("v\(plugin.manifest.version)")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(action: { showingDetails = true }) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingDetails) {
            PluginDetailsSheet(plugin: plugin)
        }
    }

    private func typeIcon(_ type: PluginType) -> String {
        switch type {
        case .aiProvider: "brain"
        case .tool: "wrench"
        case .uiComponent: "rectangle.3.group"
        case .dataSource: "cylinder"
        case .workflow: "flowchart"
        }
    }
}

// MARK: - Available Plugins

struct AvailablePluginsView: View {
    @State private var availablePlugins: [PluginManifest] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Discovering plugins...")
            } else if availablePlugins.isEmpty {
                ContentUnavailableView(
                    "No Plugins Available",
                    systemImage: "puzzlepiece.extension",
                    description: Text("Check back later for new plugins")
                )
            } else {
                List(availablePlugins, id: \.name) { manifest in
                    AvailablePluginRowView(manifest: manifest)
                }
            }
        }
        .task {
            await discoverPlugins()
        }
    }

    private func discoverPlugins() async {
        isLoading = true
        do {
            availablePlugins = try await PluginSystem.shared.discoverPlugins()
        } catch {
            print("Failed to discover plugins: \(error)")
        }
        isLoading = false
    }
}

struct AvailablePluginRowView: View {
    let manifest: PluginManifest
    @State private var isInstalling = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(manifest.name)
                    .font(.headline)

                Text(manifest.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Label(manifest.type.rawValue, systemImage: "puzzlepiece")
                    Spacer()
                    Text("by \(manifest.author)")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            if isInstalling {
                ProgressView()
            } else {
                Button("Install") {
                    installPlugin()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private func installPlugin() {
        isInstalling = true
        Task {
            do {
                _ = try await PluginSystem.shared.installPlugin(from: manifest)
                isInstalling = false
            } catch {
                print("Installation failed: \(error)")
                isInstalling = false
            }
        }
    }
}

// MARK: - Plugin Details

struct PluginDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plugin: Plugin

    var body: some View {
        NavigationStack {
            Form {
                Section("Information") {
                    LabeledContent("Name", value: plugin.manifest.name)
                    LabeledContent("Version", value: plugin.manifest.version)
                    LabeledContent("Author", value: plugin.manifest.author)
                    LabeledContent("Type", value: plugin.manifest.type.rawValue)
                }

                Section("Description") {
                    Text(plugin.manifest.description)
                }

                Section("Permissions") {
                    ForEach(plugin.grantedPermissions, id: \.rawValue) { permission in
                        Label(permission.rawValue, systemImage: "checkmark.shield")
                    }
                }

                Section("Status") {
                    Toggle("Enabled", isOn: .constant(plugin.isEnabled))
                        .onChange(of: plugin.isEnabled) { _, newValue in
                            togglePlugin(newValue)
                        }

                    LabeledContent("Installed", value: plugin.installedAt, format: .dateTime)

                    if let lastExecuted = plugin.lastExecuted {
                        LabeledContent("Last Executed", value: lastExecuted, format: .relative(presentation: .named))
                    }
                }

                Section {
                    Button("Uninstall Plugin", role: .destructive) {
                        uninstallPlugin()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Plugin Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func togglePlugin(_ enabled: Bool) {
        do {
            if enabled {
                try PluginSystem.shared.enablePlugin(plugin.id)
            } else {
                try PluginSystem.shared.disablePlugin(plugin.id)
            }
        } catch {
            print("Failed to toggle plugin: \(error)")
        }
    }

    private func uninstallPlugin() {
        do {
            try PluginSystem.shared.uninstallPlugin(plugin.id)
            dismiss()
        } catch {
            print("Failed to uninstall: \(error)")
        }
    }
}

// MARK: - Plugin Marketplace

struct PluginMarketplaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: PluginType?
    @State private var plugins: [PluginManifest] = []

    var body: some View {
        NavigationStack {
            VStack {
                // Search and filters
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search plugins", text: $searchText)
                }
                .padding(8)
                .background(.quaternary)
                .cornerRadius(8)
                .padding()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        CategoryButton(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }

                        CategoryButton(title: "AI Providers", isSelected: selectedCategory == .aiProvider) {
                            selectedCategory = .aiProvider
                        }

                        CategoryButton(title: "Tools", isSelected: selectedCategory == .tool) {
                            selectedCategory = .tool
                        }

                        CategoryButton(title: "UI", isSelected: selectedCategory == .uiComponent) {
                            selectedCategory = .uiComponent
                        }

                        CategoryButton(title: "Data", isSelected: selectedCategory == .dataSource) {
                            selectedCategory = .dataSource
                        }

                        CategoryButton(title: "Workflows", isSelected: selectedCategory == .workflow) {
                            selectedCategory = .workflow
                        }
                    }
                    .padding(.horizontal)
                }

                // Plugin grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
                        ForEach(filteredPlugins, id: \.name) { manifest in
                            PluginCardView(manifest: manifest)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Plugin Marketplace")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadPlugins()
            }
        }
    }

    private var filteredPlugins: [PluginManifest] {
        var filtered = plugins

        if let category = selectedCategory {
            filtered = filtered.filter { $0.type == category }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }

    private func loadPlugins() async {
        do {
            plugins = try await PluginSystem.shared.discoverPlugins()
        } catch {
            print("Failed to load plugins: \(error)")
        }
    }
}

private struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

struct PluginCardView: View {
    let manifest: PluginManifest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.title)
                    .foregroundStyle(.blue)

                Spacer()

                Text(manifest.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(manifest.name)
                .font(.headline)

            Text(manifest.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack {
                Label(manifest.type.rawValue, systemImage: "tag")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("by \(manifest.author)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Button(action: {}) {
                Text("Install")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

#Preview {
    PluginManagerView()
}
