// ConversationMemoryExtractor.swift
// Thea — Conversation → Knowledge Graph Memory Persistence
//
// Extracts key facts, preferences, and entities from conversations
// and persists them into PersonalKnowledgeGraph for session-to-session memory.
// The agent remembers what the user told it across conversations.

import Foundation
import OSLog

// MARK: - Conversation Memory Extractor

@MainActor
@Observable
final class ConversationMemoryExtractor {
    static let shared = ConversationMemoryExtractor()

    private let logger = Logger(subsystem: "com.thea.app", category: "ConversationMemory")

    // MARK: - Configuration

    /// Whether memory extraction is enabled
    var isEnabled = true

// periphery:ignore - Reserved: shared static property reserved for future feature activation

    // periphery:ignore - Reserved: logger property reserved for future feature activation
    /// Minimum message length to consider for extraction
    var minMessageLength = 20

    /// Maximum entities to extract per conversation
    var maxEntitiesPerConversation = 20

    // MARK: - State

    private(set) var extractedCount = 0
    private(set) var lastExtractionDate: Date?

    private init() {}

    // MARK: - Extraction

    /// Extract memorable facts from a completed conversation and persist to knowledge graph.
    func extractFromConversation(_ conversation: Conversation) async {
        guard isEnabled else { return }

        let graph = PersonalKnowledgeGraph.shared
        var extracted = 0

        // periphery:ignore - Reserved: extractFromConversation(_:) instance method reserved for future feature activation
        for message in conversation.messages {
            let text = message.content.textValue

            guard text.count >= minMessageLength else { continue }
            guard extracted < maxEntitiesPerConversation else { break }

            // Only extract from user messages (these contain the user's facts)
            guard message.role == "user" else { continue }

            // Extract preferences
            let preferences = extractPreferences(from: text)
            for pref in preferences {
                await graph.addEntity(KGEntity(
                    name: pref.key,
                    type: .preference,
                    attributes: [
                        "value": pref.value,
                        "source": "conversation",
                        "date": ISO8601DateFormatter().string(from: message.timestamp)
                    ]
                ))
                extracted += 1
            }

            // Extract people mentions
            let people = extractPeople(from: text)
            for person in people {
                await graph.addEntity(KGEntity(
                    name: person,
                    type: .person,
                    attributes: [
                        "source": "conversation",
                        "date": ISO8601DateFormatter().string(from: message.timestamp)
                    ]
                ))
                extracted += 1
            }

            // Extract goals
            let goals = extractGoals(from: text)
            for goal in goals {
                await graph.addEntity(KGEntity(
                    name: goal,
                    type: .goal,
                    attributes: [
                        "status": "active",
                        "source": "conversation",
                        "date": ISO8601DateFormatter().string(from: message.timestamp)
                    ]
                ))
                extracted += 1
            }

            // Extract topics of interest
            let topics = extractTopics(from: text)
            for topic in topics {
                await graph.addEntity(KGEntity(
                    name: topic,
                    type: .topic,
                    attributes: [
                        "source": "conversation",
                        "date": ISO8601DateFormatter().string(from: message.timestamp)
                    ]
                ))
                extracted += 1
            }
        }

        if extracted > 0 {
            extractedCount += extracted
            lastExtractionDate = Date()
            await graph.save()
            logger.info("Extracted \(extracted) entities from conversation \(conversation.id)")
        }
    }

    /// Quick extraction from a single user message (for real-time memory)
    func extractFromMessage(_ text: String, timestamp: Date = Date()) async {
        guard isEnabled, text.count >= minMessageLength else { return }

        let graph = PersonalKnowledgeGraph.shared
        let dateString = ISO8601DateFormatter().string(from: timestamp)
        // periphery:ignore - Reserved: extractFromMessage(_:timestamp:) instance method reserved for future feature activation
        var extracted = 0

        for pref in extractPreferences(from: text) {
            await graph.addEntity(KGEntity(
                name: pref.key,
                type: .preference,
                attributes: ["value": pref.value, "source": "message", "date": dateString]
            ))
            extracted += 1
        }

        for person in extractPeople(from: text) {
            await graph.addEntity(KGEntity(
                name: person,
                type: .person,
                attributes: ["source": "message", "date": dateString]
            ))
            extracted += 1
        }

        if extracted > 0 {
            extractedCount += extracted
            await graph.save()
        }
    }

    // MARK: - Preference Extraction

    private func extractPreferences(from text: String) -> [(key: String, value: String)] {
        var preferences: [(key: String, value: String)] = []
        let lower = text.lowercased()

        // periphery:ignore - Reserved: extractPreferences(from:) instance method reserved for future feature activation
        // "I prefer X" / "I like X" / "I love X"
        let preferPatterns = [
            "i prefer ", "i like ", "i love ", "i enjoy ",
            "i always ", "i usually ", "i tend to ", "my favorite "
        ]

        for pattern in preferPatterns {
            if let range = lower.range(of: pattern) {
                let after = String(text[range.upperBound...])
                let value = extractUntilStop(after)
                if !value.isEmpty, value.count < 100 {
                    let key = "preference_\(pattern.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_"))"
                    preferences.append((key: key, value: value))
                }
            }
        }

        // "My name is X"
        if let nameRange = lower.range(of: "my name is ") {
            let after = String(text[nameRange.upperBound...])
            let name = extractUntilStop(after)
            if !name.isEmpty, name.count < 50 {
                preferences.append((key: "user_name", value: name))
            }
        }

        // "I'm from X" / "I live in X"
        let locationPatterns = ["i'm from ", "i live in ", "i'm based in ", "i work at ", "i work for "]
        for pattern in locationPatterns {
            if let range = lower.range(of: pattern) {
                let after = String(text[range.upperBound...])
                let value = extractUntilStop(after)
                if !value.isEmpty, value.count < 100 {
                    let key = pattern.contains("work") ? "workplace" : "location"
                    preferences.append((key: key, value: value))
                }
            }
        }

        return preferences
    }

    // MARK: - People Extraction

    private func extractPeople(from text: String) -> [String] {
        var people: [String] = []
        let lower = text.lowercased()

// periphery:ignore - Reserved: extractPeople(from:) instance method reserved for future feature activation

        let personPatterns = [
            "my (wife|husband|partner|friend|brother|sister|mom|dad|mother|father|son|daughter|boss|colleague) ",
            "(?:called|named) ([A-Z][a-z]+)"
        ]

        for pattern in personPatterns {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [])
            } catch {
                logger.error("Invalid regex pattern '\(pattern)': \(error.localizedDescription)")
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                if match.numberOfRanges > 1, let captureRange = Range(match.range(at: 1), in: text) {
                    let name = String(text[captureRange])
                    if !name.isEmpty, name.count < 50 {
                        people.append(name)
                    }
                }
            }
        }

        // Simple name pattern: "with [Name]", "tell [Name]"
        let namePatterns = [
            "(?:with|tell|ask|call|email|message|meet) ([A-Z][a-z]+ [A-Z][a-z]+)",
            "(?:with|tell|ask|call|email|message|meet) ([A-Z][a-z]+)"
        ]

        for pattern in namePatterns {
            let regex: NSRegularExpression
            do {
                regex = try NSRegularExpression(pattern: pattern)
            } catch {
                logger.error("Invalid name regex pattern '\(pattern)': \(error.localizedDescription)")
                continue
            }
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, range: nsRange),
               match.numberOfRanges > 1,
               let captureRange = Range(match.range(at: 1), in: text)
            {
                let name = String(text[captureRange])
                if !name.isEmpty, name.count < 50, !people.contains(name) {
                    people.append(name)
                }
            }
        }

        // Suppress `lower` unused warning
        _ = lower

        return people
    }

    // MARK: - Goal Extraction

    private func extractGoals(from text: String) -> [String] {
        var goals: [String] = []
        // periphery:ignore - Reserved: extractGoals(from:) instance method reserved for future feature activation
        let lower = text.lowercased()

        let goalPatterns = [
            "i want to ", "i need to ", "my goal is ", "i'm trying to ",
            "i plan to ", "i'm working on ", "i hope to "
        ]

        for pattern in goalPatterns {
            if let range = lower.range(of: pattern) {
                let after = String(text[range.upperBound...])
                let goal = extractUntilStop(after)
                if !goal.isEmpty, goal.count < 150 {
                    goals.append(goal)
                }
            }
        }

        return goals
    }

    // MARK: - Topic Extraction

    private func extractTopics(from text: String) -> [String] {
        // periphery:ignore - Reserved: extractTopics(from:) instance method reserved for future feature activation
        var topics: [String] = []
        let lower = text.lowercased()

        let topicPatterns = [
            "interested in ", "curious about ", "learning about ",
            "studying ", "researching ", "working on "
        ]

        for pattern in topicPatterns {
            if let range = lower.range(of: pattern) {
                let after = String(text[range.upperBound...])
                let topic = extractUntilStop(after)
                if !topic.isEmpty, topic.count < 100 {
                    topics.append(topic)
                }
            }
        }

        return topics
    }

    // MARK: - Text Helpers

    // periphery:ignore - Reserved: extractUntilStop(_:) instance method reserved for future feature activation
    private func extractUntilStop(_ text: String) -> String {
        let stops: [String] = [". ", ", ", "! ", "? ", " and ", " but ", " or ", " because ", " since ", " when "]
        var result = text.trimmingCharacters(in: .whitespaces)

        for stop in stops {
            if let stopRange = result.lowercased().range(of: stop) {
                result = String(result[..<stopRange.lowerBound])
            }
        }

        // Remove trailing punctuation
        result = result.trimmingCharacters(in: .punctuationCharacters)
        result = result.trimmingCharacters(in: .whitespaces)

        return result
    }
}
