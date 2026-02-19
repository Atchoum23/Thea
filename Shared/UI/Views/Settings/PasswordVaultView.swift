// PasswordVaultView.swift
// Thea — Secure password vault UI
//
// Password management with Keychain-backed storage, strength
// analysis, and password generation.

import SwiftUI

struct PasswordVaultView: View {
    @ObservedObject private var manager = PasswordManager.shared
    @State private var showingAddEntry = false
    @State private var searchText = ""
    // periphery:ignore - Reserved: selectedCategory property reserved for future feature activation
    @State private var selectedCategory: CredentialCategory?

    var body: some View {
        List {
            overviewSection
            weakPasswordsSection
            credentialsList
        }
        .navigationTitle("Passwords")
        .searchable(text: $searchText, prompt: "Search credentials")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddEntry = true } label: {
                    Label("Add Credential", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddCredentialSheet { entry, password in
                manager.addEntry(entry, password: password)
            }
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section {
            HStack {
                PWStatCard(label: "Total", value: "\(manager.entries.count)",
                           icon: "key", color: .blue)
                PWStatCard(label: "Weak", value: "\(manager.weakPasswords.count)",
                           icon: "exclamationmark.triangle", color: .orange)
                PWStatCard(label: "Favorites", value: "\(manager.favoriteEntries.count)",
                           icon: "star", color: .yellow)
            }
        }
    }

    @ViewBuilder
    private var weakPasswordsSection: some View {
        let weak = manager.weakPasswords
        if !weak.isEmpty {
            Section {
                ForEach(weak) { entry in
                    credentialRow(entry, showStrength: true)
                }
            } header: {
                Label("Weak Passwords", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var credentialsList: some View {
        Section {
            let entries = filteredEntries
            if entries.isEmpty {
                ContentUnavailableView("No Credentials", systemImage: "lock.shield",
                                       description: Text("Add credentials to your vault."))
            } else {
                ForEach(entries) { entry in
                    credentialRow(entry)
                }
                .onDelete { offsets in
                    for idx in offsets {
                        manager.deleteEntry(id: entries[idx].id)
                    }
                }
            }
        } header: {
            Text("All Credentials")
        }
    }

    // MARK: - Row

    private func credentialRow(_ entry: PasswordEntry, showStrength: Bool = false) -> some View {
        HStack {
            Image(systemName: entry.category.icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.title)
                        .font(.body)
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(entry.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if showStrength, let strength = entry.passwordStrength {
                    Text(strength.displayName)
                        .font(.caption2)
                        .foregroundStyle(strengthColor(strength))
                }
            }

            Spacer()

            Text(entry.category.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var filteredEntries: [PasswordEntry] {
        if searchText.isEmpty { return manager.entries }
        return manager.search(query: searchText)
    }

    private func strengthColor(_ strength: PasswordStrength) -> Color {
        switch strength {
        case .veryWeak: .red
        case .weak: .orange
        case .fair: .yellow
        case .strong: .green
        case .veryStrong: .blue
        }
    }
}

// MARK: - Add Credential Sheet

private struct AddCredentialSheet: View {
    let onSave: (PasswordEntry, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var category: CredentialCategory = .website
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Credential") {
                    TextField("Title (e.g., GitHub)", text: $title)
                    TextField("Username / Email", text: $username)
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                    if !password.isEmpty {
                        let strength = PasswordAnalyzer.analyzeStrength(password)
                        HStack {
                            Text("Strength: \(strength.displayName)")
                                .font(.caption)
                            Spacer()
                            ForEach(0..<5) { idx in
                                Rectangle()
                                    .fill(idx <= strength.score ? strengthBarColor(strength) : Color.secondary.opacity(0.3))
                                    .frame(width: 20, height: 4)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                        }
                    }
                    Button("Generate Password") {
                        password = PasswordAnalyzer.generatePassword()
                        showPassword = true
                    }
                }
                Section("Details") {
                    TextField("URL (optional)", text: $url)
                    Picker("Category", selection: $category) {
                        ForEach(CredentialCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                }
            }
            .navigationTitle("Add Credential")
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 350)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = PasswordEntry(
                            title: title, username: username,
                            url: url.isEmpty ? nil : url, category: category
                        )
                        onSave(entry, password)
                        dismiss()
                    }
                    .disabled(title.isEmpty || password.isEmpty)
                }
            }
        }
    }

    private func strengthBarColor(_ strength: PasswordStrength) -> Color {
        switch strength {
        case .veryWeak: .red
        case .weak: .orange
        case .fair: .yellow
        case .strong: .green
        case .veryStrong: .blue
        }
    }
}

// MARK: - PW Stat Card

private struct PWStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
