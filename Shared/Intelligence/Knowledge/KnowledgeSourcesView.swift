// KnowledgeSourcesView.swift
// Thea V2
//
// SwiftUI view for managing knowledge sources
// Features:
// - List of knowledge sources with status
// - Add/Edit/Delete sources
// - Manual and scheduled audits
// - Feature tracking

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Main View

@MainActor
public struct KnowledgeSourcesView: View {
    @StateObject private var manager = KnowledgeSourceManager.shared
    @State private var showingAddSheet = false
    @State private var editingSource: KnowledgeSource?
    @State private var searchText = ""
    @State private var selectedCategory: KnowledgeSourceCategory?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Statistics header
                statisticsHeader

                // Search and filter
                searchAndFilter

                // Source list
                sourceList
            }
            .navigationTitle("Knowledge Sources")
            #if os(macOS)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    toolbarItems
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        toolbarMenuItems
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            #endif
            .sheet(isPresented: $showingAddSheet) {
                KnowledgeSourceEditorView(source: nil) { newSource in
                    manager.add(newSource)
                }
            }
            .sheet(item: $editingSource) { source in
                KnowledgeSourceEditorView(source: source) { updatedSource in
                    manager.update(updatedSource)
                }
            }
        }
    }

    // MARK: - Subviews

    private var statisticsHeader: some View {
        let stats = manager.statistics

        return HStack(spacing: 20) {
            SourceStatCard(
                title: "Sources",
                value: "\(stats.enabledSources)/\(stats.totalSources)",
                icon: "globe"
            )

            SourceStatCard(
                title: "Features",
                value: "\(stats.implementedFeatures)/\(stats.totalFeatures)",
                icon: "star.fill"
            )

            SourceStatCard(
                title: "Progress",
                value: String(format: "%.0f%%", stats.implementationPercentage),
                icon: "chart.pie.fill"
            )

            if let lastAudit = stats.lastAuditDate {
                SourceStatCard(
                    title: "Last Audit",
                    value: lastAudit.formatted(date: .abbreviated, time: .shortened),
                    icon: "clock.fill"
                )
            }
        }
        .padding()
        #if os(macOS)
        .background(.bar)
        #else
        .background(Color(uiColor: .secondarySystemBackground))
        #endif
    }

    private var searchAndFilter: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search sources...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            #if os(macOS)
            .background(.bar)
            #else
            .background(Color(uiColor: .tertiarySystemBackground))
            #endif
            .cornerRadius(8)

            Picker("Category", selection: $selectedCategory) {
                Text("All").tag(nil as KnowledgeSourceCategory?)
                ForEach(KnowledgeSourceCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category as KnowledgeSourceCategory?)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var sourceList: some View {
        List {
            ForEach(filteredSources) { source in
                KnowledgeSourceRow(source: source)
                    .contextMenu {
                        Button("Edit") {
                            editingSource = source
                        }
                        Button("Audit Now") {
                            Task {
                                await manager.audit(source)
                            }
                        }
                        Divider()
                        Button("Open URL", systemImage: "safari") {
                            #if os(macOS)
                            NSWorkspace.shared.open(source.url)
                            #else
                            UIApplication.shared.open(source.url)
                            #endif
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            manager.delete(source)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            manager.delete(source)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task {
                                await manager.audit(source)
                            }
                        } label: {
                            Label("Audit", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .tint(.blue)
                    }
            }
            .onDelete { offsets in
                manager.delete(at: offsets)
            }
        }
        .listStyle(.inset)
        .overlay {
            if manager.isAuditing {
                auditProgressOverlay
            }
        }
    }

    private var auditProgressOverlay: some View {
        VStack(spacing: 12) {
            ProgressView(value: manager.auditProgress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text("Auditing sources...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder
    private var toolbarItems: some View {
        Button(action: { showingAddSheet = true }) {
            Label("Add Source", systemImage: "plus")
        }

        Button {
            Task {
                await manager.auditAll()
            }
        } label: {
            Label("Audit All", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(manager.isAuditing)
    }

    @ViewBuilder
    // periphery:ignore - Reserved: toolbarMenuItems property reserved for future feature activation
    private var toolbarMenuItems: some View {
        Button {
            Task {
                await manager.auditAll()
            }
        } label: {
            Label("Audit All Sources", systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(manager.isAuditing)

        Divider()

        Menu("Filter by Category") {
            Button("All Categories") {
                selectedCategory = nil
            }
            Divider()
            ForEach(KnowledgeSourceCategory.allCases, id: \.self) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.rawValue, systemImage: category.icon)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredSources: [KnowledgeSource] {
        var result = manager.sources

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.url.absoluteString.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }
}

// MARK: - Stat Card

private struct SourceStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Source Row

private struct KnowledgeSourceRow: View {
    let source: KnowledgeSource

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: source.category.icon)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(source.name)
                        .font(.headline)

                    if !source.isEnabled {
                        Text("Disabled")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(source.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(source.auditFrequency.rawValue, systemImage: "clock")
                    if let lastAudit = source.lastAuditedAt {
                        Text("•")
                        Text("Last: \(lastAudit.formatted(date: .abbreviated, time: .omitted))")
                    }
                    Text("•")
                    Text("\(source.extractedFeatures.count) features")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            HStack(spacing: 4) {
                Image(systemName: source.status.icon)
                Text(source.status.rawValue)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(for: source.status).opacity(0.2))
            .foregroundColor(statusColor(for: source.status))
            .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }

    private func statusColor(for status: KnowledgeSourceStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .auditing: return .blue
        case .upToDate: return .green
        case .changesDetected: return .orange
        case .needsAudit: return .yellow
        case .error: return .red
        }
    }
}

// MARK: - Editor View

private struct KnowledgeSourceEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let source: KnowledgeSource?
    let onSave: (KnowledgeSource) -> Void

    @State private var name: String
    @State private var urlString: String
    @State private var description: String
    @State private var category: KnowledgeSourceCategory
    @State private var frequency: AuditFrequency
    @State private var isEnabled: Bool

    init(source: KnowledgeSource?, onSave: @escaping (KnowledgeSource) -> Void) {
        self.source = source
        self.onSave = onSave

        _name = State(initialValue: source?.name ?? "")
        _urlString = State(initialValue: source?.url.absoluteString ?? "https://")
        _description = State(initialValue: source?.description ?? "")
        _category = State(initialValue: source?.category ?? .documentation)
        _frequency = State(initialValue: source?.auditFrequency ?? .weekly)
        _isEnabled = State(initialValue: source?.isEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    TextField("URL", text: $urlString)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Settings") {
                    Picker("Category", selection: $category) {
                        ForEach(KnowledgeSourceCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }

                    Picker("Audit Frequency", selection: $frequency) {
                        ForEach(AuditFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }

                    Toggle("Enabled", isOn: $isEnabled)
                }
            }
            .navigationTitle(source == nil ? "Add Source" : "Edit Source")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    private var isValid: Bool {
        !name.isEmpty && URL(string: urlString) != nil
    }

    private func save() {
        guard let url = URL(string: urlString) else { return }

        let updatedSource = KnowledgeSource(
            id: source?.id ?? UUID(),
            url: url,
            name: name,
            description: description,
            category: category,
            auditFrequency: frequency,
            isEnabled: isEnabled,
            lastAuditedAt: source?.lastAuditedAt,
            lastChangedAt: source?.lastChangedAt,
            sitemapUrls: source?.sitemapUrls ?? [],
            extractedFeatures: source?.extractedFeatures ?? [],
            status: source?.status ?? .pending,
            createdAt: source?.createdAt ?? Date(),
            webhookUrl: source?.webhookUrl
        )

        onSave(updatedSource)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    KnowledgeSourcesView()
}
