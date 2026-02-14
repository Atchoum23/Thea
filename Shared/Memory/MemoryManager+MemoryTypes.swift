// MemoryManager+MemoryTypes.swift
// Thea V2 - Memory type storage, preference learning, and pattern detection extensions

import Foundation
import os.log

// MARK: - Memory Types (Semantic, Episodic, Procedural, Prospective)

extension MemoryManager {
    /// Store a learned pattern or preference
    public func storeSemanticMemory(
        category: OmniSemanticCategory,
        key: String,
        value: String,
        confidence: Double = 1.0,
        source: OmniMemorySource = .inferred
    ) async {
        let record = OmniMemoryRecord(
            type: .semantic, category: category.rawValue,
            key: key, value: value, confidence: confidence, source: source
        )
        await store(record)
        logger.debug("Stored semantic memory: \(key) = \(value.prefix(50))...")
    }

    /// Retrieve semantic memories by category
    public func retrieveSemanticMemories(
        category: OmniSemanticCategory, limit: Int = 10
    ) async -> [OmniMemoryRecord] {
        await retrieve(type: .semantic, category: category.rawValue, limit: limit)
    }

    /// Store an episodic memory (a specific interaction/event)
    public func storeEpisodicMemory(
        event: String, context: String,
        outcome: String? = nil, emotionalValence: Double = 0.0
    ) async {
        let metadata = OmniEpisodicMetadata(outcome: outcome, emotionalValence: emotionalValence)
        let record = OmniMemoryRecord(
            type: .episodic, category: "event",
            key: event, value: context, metadata: metadata.encoded()
        )
        await store(record)
        logger.debug("Stored episodic memory: \(event.prefix(50))...")
    }

    /// Retrieve episodic memories within a time range
    public func retrieveEpisodicMemories(
        from startDate: Date? = nil, to endDate: Date? = nil, limit: Int = 20
    ) async -> [OmniMemoryRecord] {
        await retrieve(type: .episodic, startDate: startDate, endDate: endDate, limit: limit)
    }

    /// Store a learned workflow or procedure
    public func storeProceduralMemory(
        taskType: String, procedure: String,
        successRate: Double, averageDuration: TimeInterval
    ) async {
        let metadata = OmniProceduralMetadata(
            successRate: successRate, averageDuration: averageDuration, executionCount: 1
        )
        let record = OmniMemoryRecord(
            type: .procedural, category: taskType,
            key: "procedure_\(taskType)", value: procedure,
            confidence: successRate, metadata: metadata.encoded()
        )
        await store(record)
        logger.debug("Stored procedural memory: \(taskType)")
    }

    /// Retrieve best procedure for a task type
    public func retrieveBestProcedure(for taskType: String) async -> OmniMemoryRecord? {
        let procedures = await retrieve(type: .procedural, category: taskType, limit: 5)
        return procedures.max { $0.confidence < $1.confidence }
    }

    /// Store a future intention or reminder
    public func storeProspectiveMemory(
        intention: String, triggerCondition: MemoryTriggerCondition,
        priority: OmniMemoryPriority = .normal
    ) async {
        let metadata = OmniProspectiveMetadata(triggerCondition: triggerCondition, isTriggered: false)
        let record = OmniMemoryRecord(
            type: .prospective, category: priority.rawValue,
            key: intention, value: triggerCondition.description, metadata: metadata.encoded()
        )
        await store(record)
        logger.debug("Stored prospective memory: \(intention.prefix(50))...")
    }

    /// Check for triggered prospective memories
    public func checkProspectiveMemories(currentContext: MemoryContextSnapshot) async -> [OmniMemoryRecord] {
        let prospective = await retrieve(type: .prospective, limit: 100)
        return prospective.filter { record in
            guard let metadata = OmniProspectiveMetadata.decode(record.metadata),
                  !metadata.isTriggered else { return false }
            return metadata.triggerCondition.isSatisfied(by: currentContext)
        }
    }
}

// MARK: - User Preference Learning

extension MemoryManager {
    /// Learn a user preference from interaction
    public func learnPreference(
        category: OmniPreferenceCategory, preference: String, strength: Double = 0.5
    ) async {
        let key = "\(category.rawValue):\(preference)"
        if let existing = memoryCache[key] {
            let newStrength = min(1.0, existing.confidence + (strength * 0.2))
            await updateConfidence(recordId: existing.id, newConfidence: newStrength)
            logger.debug("Strengthened preference: \(preference) -> \(newStrength)")
        } else {
            await storeSemanticMemory(
                category: .userPreference, key: key, value: preference,
                confidence: strength, source: .inferred
            )
            logger.debug("Learned new preference: \(preference)")
        }
    }

    /// Get learned preferences for a category
    public func getPreferences(category: OmniPreferenceCategory) async -> [String: Double] {
        let memories = await retrieveSemanticMemories(category: .userPreference, limit: 50)
        var preferences: [String: Double] = [:]
        for memory in memories {
            if memory.key.hasPrefix("\(category.rawValue):") {
                preferences[memory.value] = memory.confidence
            }
        }
        return preferences
    }
}

// MARK: - Pattern Detection

extension MemoryManager {
    /// Analyze episodic memories for patterns
    public func detectPatterns(windowDays: Int = 30, minOccurrences: Int = 3) async -> [MemoryDetectedPattern] {
        let startDate = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date())
        let episodes = await retrieveEpisodicMemories(from: startDate, limit: 500)

        var timePatterns: [String: [OmniMemoryRecord]] = [:]
        for episode in episodes {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: episode.timestamp)
            let weekday = calendar.component(.weekday, from: episode.timestamp)
            let key = "hour:\(hour):weekday:\(weekday)"
            timePatterns[key, default: []].append(episode)
        }

        var patterns: [MemoryDetectedPattern] = []
        for (timeKey, entries) in timePatterns where entries.count >= minOccurrences {
            let eventGroups = Dictionary(grouping: entries) { $0.key }
            for (event, occurrences) in eventGroups where occurrences.count >= minOccurrences {
                let components = timeKey.split(separator: ":")
                if components.count >= 4,
                   let hour = Int(components[1]),
                   let weekday = Int(components[3]) {
                    patterns.append(MemoryDetectedPattern(
                        event: event, frequency: occurrences.count,
                        hourOfDay: hour, dayOfWeek: weekday,
                        confidence: Double(occurrences.count) / Double(entries.count)
                    ))
                }
            }
        }
        return patterns.sorted { $0.confidence > $1.confidence }
    }
}
