// SquadsView.swift
// Thea — F3: Squads Management UI
//
// Persistent squads (user-created, multi-session) for long-running goals.
// Distinct from ephemeral AgentTeams created automatically per-request.

import SwiftUI

// MARK: - Squads Root View

struct SquadsView: View {
    // SquadOrchestrator is @Observable — use @State, not @StateObject
    @State private var orchestrator = SquadOrchestrator.shared
    @State private var showCreateSquad = false
    @State private var selectedSquad: SquadDefinition?
    @State private var showDeleteConfirm = false
    @State private var squadToDelete: SquadDefinition?

    var body: some View {
        NavigationSplitView {
            squadList
        } detail: {
            if let squad = selectedSquad {
                SquadDetailView(squad: squad, orchestrator: orchestrator)
            } else {
                ContentUnavailableView(
                    "Select a Squad",
                    systemImage: "person.3.sequence.fill",
                    description: Text("Choose a squad from the list or create a new one.")
                )
            }
        }
        .navigationTitle("Squads")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSquad = true
                } label: {
                    Label("New Squad", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSquad) {
            SquadCreationView(orchestrator: orchestrator)
        }
        .confirmationDialog(
            "Delete Squad",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let squad = squadToDelete {
                    orchestrator.deleteSquad(id: squad.id)
                    if selectedSquad?.id == squad.id { selectedSquad = nil }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(squadToDelete?.name ?? "this squad")\"? This cannot be undone.")
        }
    }

    private var squadList: some View {
        List(selection: $selectedSquad) {
            // Built-in squads section
            Section("Built-in Squads") {
                ForEach(orchestrator.activeSquads.isEmpty ? builtinSquads : builtinSquads) { squad in
                    SquadRow(squad: squad)
                        .tag(squad)
                }
            }

            // User-created persistent squads
            if !orchestrator.persistentSquads.isEmpty {
                Section("My Squads") {
                    ForEach(orchestrator.persistentSquads) { squad in
                        SquadRow(squad: squad)
                            .tag(squad)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    squadToDelete = squad
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var builtinSquads: [SquadDefinition] {
        SquadRegistry.shared.sortedSquads.filter { $0.scope == .builtin }
    }
}

// MARK: - Squad Row

private struct SquadRow: View {
    let squad: SquadDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: squad.scope == .builtin ? "star.circle" : "person.3.sequence.fill")
                    .foregroundStyle(squad.scope == .builtin ? .yellow : .blue)
                Text(squad.name)
                    .font(.headline)
                Spacer()
                if squad.scope != .builtin {
                    Text("\(squad.sessionCount) sessions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let goal = squad.goal {
                Text(goal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(squad.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Label("\(squad.members.count) agents", systemImage: "person.2")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if squad.scope != .builtin {
                    Label(squad.communicationStrategy.displayName, systemImage: "network")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Squad Detail View

private struct SquadDetailView: View {
    let squad: SquadDefinition
    let orchestrator: SquadOrchestrator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: squad.scope == .builtin ? "star.circle.fill" : "person.3.sequence.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(squad.name)
                                .font(.title2.bold())
                            if let goal = squad.goal {
                                Text("Goal: \(goal)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if squad.scope != .builtin {
                        HStack(spacing: 16) {
                            StatBadge(label: "Strategy", value: squad.communicationStrategy.displayName, color: .blue)
                            StatBadge(label: "Mode", value: squad.coordinationMode.displayName, color: .purple)
                            StatBadge(label: "Sessions", value: "\(squad.sessionCount)", color: .green)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Members
                VStack(alignment: .leading, spacing: 12) {
                    Text("Squad Members (\(squad.members.count))")
                        .font(.headline)
                    ForEach(squad.members) { member in
                        MemberCard(member: member, isLeader: member.id == squad.firstMemberId)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Handoff Rules
                if !squad.handoffRules.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Handoff Rules")
                            .font(.headline)
                        ForEach(squad.handoffRules) { rule in
                            HStack {
                                Text(squad.members.first { $0.id == rule.fromMemberId }?.name ?? rule.fromMemberId)
                                    .font(.subheadline)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Text(squad.members.first { $0.id == rule.toMemberId }?.name ?? rule.toMemberId)
                                    .font(.subheadline)
                                Spacer()
                                Text(rule.trigger.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle(squad.name)
    }
}

// MARK: - Member Card

private struct MemberCard: View {
    let member: SquadMember
    let isLeader: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                Image(systemName: isLeader ? "star.circle.fill" : "person.circle")
                    .font(.title2)
                    .foregroundStyle(isLeader ? .yellow : .secondary)
                if isLeader {
                    Text("Lead")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.name)
                        .font(.subheadline.bold())
                    Text("· \(member.role)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !member.tools.isEmpty {
                    Text("Tools: \(member.tools.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if !member.handoffDestinations.isEmpty {
                    Text("Can hand off to: \(member.handoffDestinations.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Squad Creation View

struct SquadCreationView: View {
    let orchestrator: SquadOrchestrator
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var goal = ""
    @State private var communicationStrategy = CommunicationStrategy.broadcast
    @State private var coordinationMode = CoordinationMode.leader
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Squad Identity") {
                    TextField("Squad Name", text: $name)
                    TextField("Long-running Goal (optional)", text: $goal, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Communication") {
                    Picker("Strategy", selection: $communicationStrategy) {
                        ForEach(CommunicationStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    Picker("Coordination", selection: $coordinationMode) {
                        ForEach(CoordinationMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section {
                    Text("Members will be automatically assigned based on your goal. You can customize them after creation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Squad")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSquad()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    private func createSquad() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isCreating = true
        let definition = SquadDefinition(
            id: UUID().uuidString,
            name: trimmedName,
            description: goal.isEmpty ? "Custom squad: \(trimmedName)" : goal,
            members: [],
            firstMemberId: "",
            goal: goal.isEmpty ? nil : goal,
            communicationStrategy: communicationStrategy,
            coordinationMode: coordinationMode
        )
        Task { @MainActor in
            do {
                let created = try await orchestrator.createSquad(definition)
                if !goal.isEmpty {
                    await orchestrator.assignOptimalMembers(to: created.id, goal: goal)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}
