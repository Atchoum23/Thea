import Foundation
import Observation
@preconcurrency import SwiftData

// MARK: - User Preference Model
// Learns and tracks user preferences for personalized prompt optimization

@MainActor
@Observable
final class UserPreferenceModel {
    static let shared = UserPreferenceModel()

    private var modelContext: ModelContext?
    private var preferencesCache: [String: [UserPromptPreference]] = [:]

    private init() {}

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        Task {
            await loadPreferences()
        }
    }

    // MARK: - Preference Management

    /// Gets all preferences for a specific category
    func getPreferences(for category: String) async -> [UserPromptPreference] {
        if let cached = preferencesCache[category] {
            return cached
        }

        await loadPreferences()
        return preferencesCache[category] ?? []
    }

    /// Updates a preference with reinforcement learning
    func updatePreference(
        category: String,
        key: String,
        value: String,
        reinforcement: Float
    ) async {
        guard let context = modelContext else { return }

        // Find existing preference
        let descriptor = FetchDescriptor<UserPromptPreference>(
            predicate: #Predicate {
                $0.category == category && $0.preferenceKey == key
            }
        )

        if let existing = try? context.fetch(descriptor).first {
            // Update existing preference
            if existing.preferenceValue == value {
                // Reinforce existing preference
                existing.confidence = min(1.0, existing.confidence + reinforcement)
            } else {
                // User changed preference
                existing.preferenceValue = value
                existing.confidence = max(0.5, existing.confidence - abs(reinforcement))
            }
            existing.lastUpdated = Date()
        } else {
            // Create new preference
            let preference = UserPromptPreference(
                category: category,
                preferenceKey: key,
                preferenceValue: value,
                confidence: 0.5 + abs(reinforcement),
                lastUpdated: Date()
            )
            context.insert(preference)
        }

        try? context.save()
        await loadPreferences()
    }

    /// Records user correction as negative feedback
    func recordUserCorrection(
        category: String,
        originalOutput: String,
        correctedOutput: String
    ) async {
        // Analyze what changed
        let changes = analyzeChanges(from: originalOutput, to: correctedOutput)

        for change in changes {
            await updatePreference(
                category: category,
                key: change.key,
                value: change.value,
                reinforcement: 0.15
            )
        }
    }

    /// Records user acceptance as positive feedback
    func recordUserAcceptance(category: String, output: String) async {
        // Extract characteristics from accepted output
        let characteristics = extractCharacteristics(from: output, category: category)

        for characteristic in characteristics {
            await updatePreference(
                category: category,
                key: characteristic.key,
                value: characteristic.value,
                reinforcement: 0.05
            )
        }
    }

    // MARK: - Preference Loading

    private func loadPreferences() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<UserPromptPreference>(
            sortBy: [SortDescriptor(\.confidence, order: .reverse)]
        )

        do {
            let preferences = try context.fetch(descriptor)

            preferencesCache.removeAll()
            for preference in preferences {
                preferencesCache[preference.category, default: []].append(preference)
            }
        } catch {
            print("Error loading preferences: \(error)")
        }
    }

    // MARK: - Analysis Helpers

    private func analyzeChanges(from original: String, to corrected: String) -> [(key: String, value: String)] {
        var changes: [(key: String, value: String)] = []

        // Length preference
        let lengthDiff = corrected.count - original.count
        if abs(lengthDiff) > original.count / 10 { // More than 10% change
            if lengthDiff > 0 {
                changes.append(("verbosity", "verbose"))
            } else {
                changes.append(("verbosity", "concise"))
            }
        }

        // Code blocks (for code category)
        if corrected.contains("```") && !original.contains("```") {
            changes.append(("formatting", "code_blocks"))
        }

        // Bullet points
        if corrected.contains("- ") || corrected.contains("• ") {
            if !(original.contains("- ") || original.contains("• ")) {
                changes.append(("formatting", "bullet_points"))
            }
        }

        // Numbered lists
        if corrected.contains(#/\d+\.\s/#) && !original.contains(#/\d+\.\s/#) {
            changes.append(("formatting", "numbered_lists"))
        }

        // Headings
        if corrected.contains("#") && !original.contains("#") {
            changes.append(("formatting", "markdown_headings"))
        }

        // Comments in code
        if corrected.contains("//") || corrected.contains("/*") {
            if !(original.contains("//") || original.contains("/*")) {
                changes.append(("code_style", "with_comments"))
            }
        }

        return changes
    }

    private func extractCharacteristics(from output: String, category: String) -> [(key: String, value: String)] {
        var characteristics: [(key: String, value: String)] = []

        // Length
        if output.count < 500 {
            characteristics.append(("length", "short"))
        } else if output.count < 2_000 {
            characteristics.append(("length", "medium"))
        } else {
            characteristics.append(("length", "long"))
        }

        // Tone
        if output.contains("please") || output.contains("kindly") || output.contains("would you") {
            characteristics.append(("tone", "polite"))
        }

        if output.contains("!") {
            characteristics.append(("tone", "enthusiastic"))
        }

        // Structure
        if output.contains("```") {
            characteristics.append(("formatting", "code_blocks"))
        }

        if output.contains("- ") || output.contains("• ") {
            characteristics.append(("formatting", "bullet_points"))
        }

        if output.contains(#/\d+\.\s/#) {
            characteristics.append(("formatting", "numbered_lists"))
        }

        // For code category
        if category == "code" || category == "Coder" {
            if output.contains("//") || output.contains("/*") {
                characteristics.append(("code_style", "with_comments"))
            } else {
                characteristics.append(("code_style", "minimal_comments"))
            }

            if output.contains("guard") {
                characteristics.append(("code_style", "guard_statements"))
            }

            if output.contains("@MainActor") || output.contains("@Sendable") {
                characteristics.append(("code_style", "strict_concurrency"))
            }

            if output.contains("enum") && output.contains("case") {
                characteristics.append(("code_style", "enums"))
            }
        }

        return characteristics
    }

    // MARK: - Preference Queries

    /// Gets top preferences for a category
    func getTopPreferences(for category: String, limit: Int = 5) async -> [UserPromptPreference] {
        let preferences = await getPreferences(for: category)
        return Array(preferences.prefix(limit))
    }

    /// Checks if user prefers a specific style
    func prefersStyle(_ style: String, in category: String) async -> Bool {
        let preferences = await getPreferences(for: category)
        return preferences.contains { $0.preferenceValue == style && $0.confidence > 0.7 }
    }

    // MARK: - Preference Reset

    /// Resets all preferences for a category
    func resetPreferences(for category: String) async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<UserPromptPreference>(
            predicate: #Predicate { $0.category == category }
        )

        do {
            let preferences = try context.fetch(descriptor)
            for preference in preferences {
                context.delete(preference)
            }
            try context.save()
            await loadPreferences()
        } catch {
            print("Error resetting preferences: \(error)")
        }
    }

    /// Resets all preferences across all categories
    func resetAllPreferences() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<UserPromptPreference>()

        do {
            let preferences = try context.fetch(descriptor)
            for preference in preferences {
                context.delete(preference)
            }
            try context.save()
            preferencesCache.removeAll()
        } catch {
            print("Error resetting all preferences: \(error)")
        }
    }

    // MARK: - Analytics

    /// Gets preference statistics
    func getPreferenceStats() async -> PreferenceStats {
        guard let context = modelContext else {
            return PreferenceStats(
                totalPreferences: 0,
                categoriesTracked: 0,
                averageConfidence: 0,
                mostConfidentPreference: nil
            )
        }

        let descriptor = FetchDescriptor<UserPromptPreference>()

        do {
            let preferences = try context.fetch(descriptor)
            let categories = Set(preferences.map { $0.category })
            let avgConfidence = preferences.isEmpty ? 0 : preferences.map { $0.confidence }.reduce(0, +) / Float(preferences.count)
            let mostConfident = preferences.max { a, b in a.confidence < b.confidence }

            return PreferenceStats(
                totalPreferences: preferences.count,
                categoriesTracked: categories.count,
                averageConfidence: avgConfidence,
                mostConfidentPreference: mostConfident
            )
        } catch {
            print("Error getting preference stats: \(error)")
            return PreferenceStats(
                totalPreferences: 0,
                categoriesTracked: 0,
                averageConfidence: 0,
                mostConfidentPreference: nil
            )
        }
    }

    /// Gets preference history for a specific key
    func getPreferenceHistory(category: String, key: String) async -> [PreferenceHistory] {
        let preferences = await getPreferences(for: category)
        let matching = preferences.filter { $0.preferenceKey == key }

        return matching.map { preference in
            PreferenceHistory(
                value: preference.preferenceValue,
                confidence: preference.confidence,
                lastUpdated: preference.lastUpdated
            )
        }
    }
}

// MARK: - Supporting Structures

struct PreferenceStats {
    let totalPreferences: Int
    let categoriesTracked: Int
    let averageConfidence: Float
    let mostConfidentPreference: UserPromptPreference?
}

struct PreferenceHistory {
    let value: String
    let confidence: Float
    let lastUpdated: Date
}
