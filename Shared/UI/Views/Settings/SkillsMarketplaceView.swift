// SkillsMarketplaceView.swift
// Thea — Phase E3: Skills Complete System
//
// Browse, install, and manage Skills from the marketplace.
// Uses SkillsRegistryService for all data operations.

import SwiftUI

// MARK: - Skills Marketplace View

/// Browse and install Skills from the marketplace.
/// NavigationSplitView: categories sidebar + skills list detail.
struct SkillsMarketplaceView: View {
    @StateObject private var registry = SkillsRegistryService.shared

    @State private var selectedCategory: MarketplaceSkillCategory?
    @State private var searchText: String = ""
    @State private var isSyncing: Bool = false
    @State private var syncError: String?
    @State private var installError: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationSplitView {
            categorySidebar
        } detail: {
            skillsListDetail
        }
        .navigationTitle("Skills")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await syncMarketplace() }
                } label: {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isSyncing)
                .help("Sync marketplace skills from remote")
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search skills")
        .overlay(alignment: .bottom) {
            if let msg = successMessage {
                toastBanner(msg, isError: false)
            } else if let err = installError {
                toastBanner(err, isError: true)
            }
        }
        .task {
            if registry.marketplaceSkills.isEmpty {
                await syncMarketplace()
            }
        }
    }

    // MARK: - Category Sidebar

    private var categorySidebar: some View {
        List(selection: $selectedCategory) {
            Label("All Skills", systemImage: "square.grid.2x2")
                .tag(Optional<MarketplaceSkillCategory>.none)

            Divider()

            ForEach(MarketplaceSkillCategory.allCases, id: \.self) { category in
                Label(category.displayName, systemImage: category.icon)
                    .tag(Optional(category))
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
#if os(macOS)
        .navigationTitle("Categories")
#endif
    }

    // MARK: - Skills List Detail

    private var skillsListDetail: some View {
        List {
            // Installed Skills section (always shown at top)
            if !registry.installedSkills.isEmpty {
                Section("Installed (\(registry.installedSkills.count))") {
                    ForEach(registry.installedSkills) { installed in
                        InstalledSkillRow(skill: installed) {
                            await uninstall(skillId: installed.id)
                        }
                    }
                }
            }

            // Marketplace browse section
            let results = filteredMarketplaceSkills
            Section(sectionTitle) {
                if registry.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading marketplace...")
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "No Skills Found",
                        systemImage: "magnifyingglass",
                        description: Text(searchText.isEmpty ? "No skills in this category." : "Try a different search term.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(results) { skill in
                        MarketplaceSkillRow(
                            skill: skill,
                            isInstalled: registry.installedSkills.contains { $0.id == skill.id },
                            onInstall: { await install(skill: skill) },
                            onUninstall: { await uninstall(skillId: skill.id) }
                        )
                    }
                }
            }
        }
        .listStyle(.inset)
#if os(macOS)
        .navigationTitle(selectedCategory?.displayName ?? "All Skills")
#endif
    }

    private var sectionTitle: String {
        if let category = selectedCategory {
            return category.displayName
        }
        return searchText.isEmpty ? "Marketplace" : "Search Results"
    }

    private var filteredMarketplaceSkills: [MarketplaceSkill] {
        var skills = registry.marketplaceSkills

        // Filter by category
        if let category = selectedCategory {
            skills = skills.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            skills = skills.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.tags.contains { $0.lowercased().contains(query) }
            }
        }

        return skills
    }

    // MARK: - Actions

    private func syncMarketplace() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await registry.syncMarketplace()
            showSuccess("Marketplace synced — \(registry.marketplaceSkills.count) skills available")
        } catch {
            installError = "Sync failed: \(error.localizedDescription)"
            clearErrorAfterDelay()
        }
    }

    private func install(skill: MarketplaceSkill) async {
        do {
            _ = try await registry.install(skill)
            showSuccess("Installed \"\(skill.name)\"")
        } catch {
            installError = "Install failed: \(error.localizedDescription)"
            clearErrorAfterDelay()
        }
    }

    private func uninstall(skillId: String) async {
        do {
            try await registry.uninstall(skillId: skillId)
            showSuccess("Skill uninstalled")
        } catch {
            installError = "Uninstall failed: \(error.localizedDescription)"
            clearErrorAfterDelay()
        }
    }

    private func showSuccess(_ message: String) {
        installError = nil
        successMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3))
            successMessage = nil
        }
    }

    private func clearErrorAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(4))
            installError = nil
        }
    }

    // MARK: - Toast Banner

    @ViewBuilder
    private func toastBanner(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .red : .green)
            Text(message)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: message)
    }
}

// MARK: - Installed Skill Row

private struct InstalledSkillRow: View {
    let skill: InstalledSkill
    let onUninstall: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(skill.name)
                        .font(.headline)
                    Spacer()
                    trustBadge(score: skill.trustScore)
                }
                Text(skill.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("v\(skill.version) · Installed \(skill.installedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button(role: .destructive) {
                Task { await onUninstall() }
            } label: {
                Text("Remove")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func trustBadge(score: Int) -> some View {
        let (color, label): (Color, String) = {
            switch score {
            case 7...10: return (.green, "Trusted")
            case 3..<7: return (.orange, "Medium")
            default: return (.red, "Low")
            }
        }()
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Marketplace Skill Row

private struct MarketplaceSkillRow: View {
    let skill: MarketplaceSkill
    let isInstalled: Bool
    let onInstall: () async -> Void
    let onUninstall: () async -> Void

    @State private var isWorking = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: skill.category.icon)
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.name)
                        .font(.headline)
                    if skill.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                            .help("Verified skill")
                    }
                    Spacer()
                    trustBadge(score: skill.trustScore)
                }

                Text(skill.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label("\(skill.downloads)", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("by \(skill.author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("v\(skill.version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if !skill.tags.isEmpty {
                        Text(skill.tags.prefix(3).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Group {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                } else if isInstalled {
                    Button(role: .destructive) {
                        Task {
                            isWorking = true
                            await onUninstall()
                            isWorking = false
                        }
                    } label: {
                        Text("Remove")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        Task {
                            isWorking = true
                            await onInstall()
                            isWorking = false
                        }
                    } label: {
                        Text("Install")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func trustBadge(score: Int) -> some View {
        let (color, label): (Color, String) = {
            switch score {
            case 7...10: return (.green, "Trust \(score)")
            case 3..<7: return (.orange, "Trust \(score)")
            default: return (.red, "Trust \(score)")
            }
        }()
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - MarketplaceSkillCategory Display Helpers

private extension MarketplaceSkillCategory {
    var displayName: String {
        switch self {
        case .coding: return "Coding"
        case .architecture: return "Architecture"
        case .testing: return "Testing"
        case .documentation: return "Documentation"
        case .devops: return "DevOps"
        case .security: return "Security"
        case .data: return "Data"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .architecture: return "building.columns"
        case .testing: return "checklist"
        case .documentation: return "doc.text"
        case .devops: return "gearshape.2"
        case .security: return "lock.shield"
        case .data: return "cylinder.split.1x2"
        case .other: return "square.dotted"
        }
    }
}

// MARK: - Preview

#Preview {
    SkillsMarketplaceView()
        .frame(width: 800, height: 600)
}
