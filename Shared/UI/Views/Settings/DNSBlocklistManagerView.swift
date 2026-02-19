//
//  DNSBlocklistManagerView.swift
//  Thea
//
//  Manages DNS blocklist entries — add/remove custom domains,
//  toggle per-domain blocking, and view blocklist statistics.
//

import SwiftUI

/// DNS blocklist management view allowing users to add custom blocked domains,
/// toggle individual entries, filter by category, and review blocking statistics.
struct DNSBlocklistManagerView: View {
    @State private var entries: [DNSBlocklistService.BlocklistEntry] = []
    @State private var stats: DNSBlocklistService.BlocklistStats?
    @State private var isEnabled = true
    @State private var selectedCategory: DNSBlocklistService.BlockCategory?
    @State private var newDomain = ""
    @State private var newCategory: DNSBlocklistService.BlockCategory = .custom
    @State private var showingAddSheet = false

    var body: some View {
        Form {
            statusSection
            statsSection
            addDomainSection
            entriesSection
        }
        .formStyle(.grouped)
        .navigationTitle("DNS Blocklist")
        .task { await loadData() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var statusSection: some View {
        Section {
            Toggle("Blocklist Active", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, newValue in
                    Task { await DNSBlocklistService.shared.setEnabled(newValue) }
                }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        if let stats {
            Section("Statistics") {
                HStack(spacing: TheaSpacing.lg) {
                    VStack(spacing: 2) {
                        Text("\(stats.totalDomains)")
                            .font(.theaTitle2)
                            .foregroundStyle(Color.theaPrimaryDefault)
                        Text("Domains")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("\(stats.enabledDomains)")
                            .font(.theaTitle2)
                            .foregroundStyle(Color.theaSuccess)
                        Text("Active")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("\(stats.blockedToday)")
                            .font(.theaTitle2)
                            .foregroundStyle(Color.theaWarning)
                        Text("Today")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 2) {
                        Text("\(stats.blockedAllTime)")
                            .font(.theaTitle2)
                            .foregroundStyle(Color.theaError)
                        Text("All Time")
                            .font(.theaCaption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Per-category counts
                ForEach(DNSBlocklistService.BlockCategory.allCases, id: \.self) { category in
                    let count = stats.byCategory[category] ?? 0
                    if count > 0 {
                        HStack {
                            Image(systemName: category.sfSymbol)
                                .foregroundStyle(Color.theaPrimaryDefault)
                                .frame(width: 24)
                            Text(category.rawValue)
                            Spacer()
                            Text("\(count) domains")
                                .foregroundStyle(.secondary)
                                .font(.theaCaption1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var addDomainSection: some View {
        Section("Add Custom Domain") {
            HStack {
                TextField("example.com", text: $newDomain)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $newCategory) {
                    ForEach(DNSBlocklistService.BlockCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                .frame(width: 140)

                Button("Add") {
                    guard !newDomain.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Task {
                        await DNSBlocklistService.shared.addDomain(newDomain.trimmingCharacters(in: .whitespaces), category: newCategory)
                        newDomain = ""
                        await loadData()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        Section("Category Filter") {
            Picker("Filter", selection: $selectedCategory) {
                Text("All").tag(nil as DNSBlocklistService.BlockCategory?)
                ForEach(DNSBlocklistService.BlockCategory.allCases, id: \.self) { cat in
                    Text(cat.rawValue).tag(cat as DNSBlocklistService.BlockCategory?)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedCategory) { _, _ in
                Task { await loadData() }
            }
        }

        let filteredEntries = selectedCategory == nil ? entries : entries.filter { $0.category == selectedCategory }

        Section("Blocked Domains (\(filteredEntries.count))") {
            if filteredEntries.isEmpty {
                Text("No entries in this category")
                    .foregroundStyle(.secondary)
                    .font(.theaCaption1)
            } else {
                ForEach(filteredEntries) { entry in
                    HStack {
                        Image(systemName: entry.category.sfSymbol)
                            .foregroundStyle(entry.isEnabled ? Color.theaPrimaryDefault : .secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.domain)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                            HStack(spacing: TheaSpacing.xs) {
                                Text(entry.category.rawValue)
                                Text("·")
                                Text(entry.source.rawValue)
                            }
                            .font(.theaCaption2)
                            .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { entry.isEnabled },
                            set: { newValue in
                                Task {
                                    await DNSBlocklistService.shared.toggleDomain(entry.domain, enabled: newValue)
                                    await loadData()
                                }
                            }
                        ))
                        .labelsHidden()

                        if entry.source == .user {
                            Button(role: .destructive) {
                                Task {
                                    await DNSBlocklistService.shared.removeDomain(entry.domain)
                                    await loadData()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func loadData() async {
        isEnabled = await DNSBlocklistService.shared.isEnabled
        stats = await DNSBlocklistService.shared.getStats()
        entries = await DNSBlocklistService.shared.getEntries(category: selectedCategory)
    }
}
