// AdvancedPromptSettingsTypes.swift
// Supporting types for AdvancedPromptSettingsView

import Foundation

// MARK: - Custom Prompt

struct CustomPrompt: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var content: String
    var category: PromptCategory
    var scope: PromptScope
    var isActive: Bool
    var priority: Int // 1-10, higher = applied first
    var conditions: String? // Optional trigger conditions
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        content: String,
        category: PromptCategory,
        scope: PromptScope,
        isActive: Bool = true,
        priority: Int = 5,
        conditions: String? = nil
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.category = category
        self.scope = scope
        self.isActive = isActive
        self.priority = priority
        self.conditions = conditions
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func duplicate() -> CustomPrompt {
        CustomPrompt(
            name: "\(name) (Copy)",
            content: content,
            category: category,
            scope: scope,
            isActive: false,
            priority: priority,
            conditions: conditions
        )
    }

    static func == (lhs: CustomPrompt, rhs: CustomPrompt) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Prompt Library

struct PromptLibrary: Codable {
    var prompts: [CustomPrompt] = []

    private static let storageKey = "PromptLibrary"

    // MARK: - CRUD

    mutating func add(_ prompt: CustomPrompt) {
        prompts.append(prompt)
    }

    mutating func remove(_ prompt: CustomPrompt) {
        prompts.removeAll { $0.id == prompt.id }
    }

    mutating func update(_ prompt: CustomPrompt, transform: (inout CustomPrompt) -> Void) {
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            transform(&prompts[index])
            prompts[index].updatedAt = Date()
        }
    }

    mutating func setActive(_ prompt: CustomPrompt, active: Bool) {
        update(prompt) { $0.isActive = active }
    }

    mutating func move(in category: PromptCategory, from source: IndexSet, to destination: Int) {
        var categoryPrompts = prompts(for: category)
        categoryPrompts.move(fromOffsets: source, toOffset: destination)
        for (index, prompt) in categoryPrompts.enumerated() {
            update(prompt) { $0.priority = 10 - index }
        }
    }

    func prompts(for category: PromptCategory) -> [CustomPrompt] {
        prompts.filter { $0.category == category }.sorted { $0.priority > $1.priority }
    }

    func activePrompts(for scope: PromptScope) -> [CustomPrompt] {
        prompts.filter { $0.isActive && ($0.scope == scope || $0.scope == .all) }
            .sorted { $0.priority > $1.priority }
    }

    func combinedPrompt(for scope: PromptScope) -> String {
        activePrompts(for: scope).map(\.content).joined(separator: "\n\n")
    }

    // MARK: - Persistence

    static func load() -> PromptLibrary {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let library = try? JSONDecoder().decode(PromptLibrary.self, from: data) else {
            return PromptLibrary(prompts: defaultPrompts())
        }
        return library
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func defaultPrompts() -> [CustomPrompt] {
        [
            CustomPrompt(
                name: "Research Best Practices",
                content: "Before making any code changes, verify online the current year's best practices for the relevant framework, language, and platform.",
                category: .general,
                scope: .all,
                isActive: true,
                priority: 10
            ),
            CustomPrompt(
                name: "Swift Style Guide",
                content: "Follow Apple's Swift API Design Guidelines and use modern Swift concurrency patterns (async/await, actors).",
                category: .coding,
                scope: .all,
                isActive: true,
                priority: 8
            )
        ]
    }
}

// MARK: - Preview

#if canImport(SwiftUI)
import SwiftUI

#if os(macOS)
#Preview {
    AdvancedPromptSettingsView()
        .frame(width: 900, height: 600)
}
#else
#Preview {
    AdvancedPromptSettingsView()
}
#endif
#endif
