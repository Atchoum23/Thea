// ActiveMemoryRetrieval+Helpers.swift
// Thea
//
// Helper methods for ActiveMemoryRetrieval
// Deduplication, context prompt building, and category mapping

import Foundation

// MARK: - Helper Methods

extension ActiveMemoryRetrieval {

    func deduplicateAndLimit(_ sources: [RetrievalSource]) -> [RetrievalSource] {
        var seen = Set<String>()
        var unique: [RetrievalSource] = []

        for source in sources {
            let key = source.content.prefix(100).lowercased()
            if !seen.contains(String(key)) {
                seen.insert(String(key))
                unique.append(source)

                if unique.count >= config.maxTotalResults {
                    break
                }
            }
        }

        return unique
    }

    func buildContextPrompt(from sources: [RetrievalSource]) -> String {
        guard !sources.isEmpty else { return "" }

        var sections: [String: [String]] = [:]

        for source in sources {
            let sectionName = source.tier.displayName
            if sections[sectionName] == nil {
                sections[sectionName] = []
            }
            sections[sectionName]?.append("• \(source.content)")
        }

        var prompt = ""
        for (section, items) in sections.sorted(by: { $0.key < $1.key }) {
            prompt += "**\(section):**\n"
            prompt += items.joined(separator: "\n")
            prompt += "\n\n"
        }

        return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func mapToFactCategory(_ category: String) -> ConversationMemory.FactCategory {
        switch category.lowercased() {
        case "preference": return .userPreference
        case "info": return .userInfo
        case "technical": return .technicalContext
        case "project": return .projectDetails
        default: return .domainKnowledge
        }
    }
}
