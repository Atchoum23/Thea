// RelationshipIntelligence.swift
// THEA - Relationship & Contact Intelligence
// Created by Claude - February 2026
//
// Understands your social graph and relationship dynamics:
// - Tracks communication frequency and patterns
// - Learns who's important to you
// - Detects relationship decay ("You haven't talked to X in 3 months")
// - Understands hierarchies (manager, family, close friends)
// - Suggests follow-ups and relationship maintenance
// - Provides context for urgency decisions

import Foundation
import Contacts

// MARK: - Relationship Model

public struct ContactRelationship: Identifiable, Codable, Sendable {
    public let id: String // Contact identifier
    public var name: String
    public var relationship: RelationshipType
    public var tier: RelationshipTier
    public var customLabel: String?

    // Communication Stats
    public var lastIncomingContact: Date?
    public var lastOutgoingContact: Date?
    public var totalIncomingMessages: Int
    public var totalOutgoingMessages: Int
    public var totalCalls: Int

    // Patterns
    public var averageResponseTime: TimeInterval?
    public var preferredContactMethod: ContactMethod?
    public var preferredTimeOfDay: Int? // Hour
    public var preferredDayOfWeek: Int? // 1-7

    // Intelligence
    public var importanceScore: Double // 0.0 - 1.0
    public var urgencyReliability: Double // How often their "urgent" is actually urgent
    public var communicationFrequency: CommunicationFrequency
    public var lastCalculatedAt: Date

    // Language & Preferences
    public var preferredLanguage: String?
    public var timezone: String?

    // Context
    public var notes: String?
    public var tags: [String]
    public var sharedProjects: [String]

    public enum RelationshipType: String, Codable, Sendable {
        case family = "family"
        case friend = "friend"
        case closeFriend = "close_friend"
        case colleague = "colleague"
        case manager = "manager"
        case directReport = "direct_report"
        case client = "client"
        case vendor = "vendor"
        case acquaintance = "acquaintance"
        case professional = "professional"
        case other = "other"
    }

    public enum RelationshipTier: Int, Codable, Sendable {
        case vip = 1 // Always available
        case inner = 2 // Close circle
        case regular = 3 // Normal contacts
        case outer = 4 // Acquaintances
        case unknown = 5 // New contacts

        public var description: String {
            switch self {
            case .vip: return "VIP"
            case .inner: return "Inner Circle"
            case .regular: return "Regular"
            case .outer: return "Outer Circle"
            case .unknown: return "Unknown"
            }
        }
    }

    public enum ContactMethod: String, Codable, Sendable {
        case call, text, email, whatsapp, telegram, signal, slack
    }

    public enum CommunicationFrequency: String, Codable, Sendable {
        case daily
        case weekly
        case monthly
        case quarterly
        case rarely
        case inactive // No contact in 6+ months

        public var expectedDaysBetweenContact: Int {
            switch self {
            case .daily: return 1
            case .weekly: return 7
            case .monthly: return 30
            case .quarterly: return 90
            case .rarely: return 180
            case .inactive: return 365
            }
        }
    }

    public init(id: String, name: String) {
        self.id = id
        self.name = name
        self.relationship = .other
        self.tier = .unknown
        self.customLabel = nil
        self.lastIncomingContact = nil
        self.lastOutgoingContact = nil
        self.totalIncomingMessages = 0
        self.totalOutgoingMessages = 0
        self.totalCalls = 0
        self.averageResponseTime = nil
        self.preferredContactMethod = nil
        self.preferredTimeOfDay = nil
        self.preferredDayOfWeek = nil
        self.importanceScore = 0.5
        self.urgencyReliability = 0.5
        self.communicationFrequency = .rarely
        self.lastCalculatedAt = Date()
        self.preferredLanguage = nil
        self.timezone = nil
        self.notes = nil
        self.tags = []
        self.sharedProjects = []
    }
}

// MARK: - Relationship Intelligence Actor

public actor RelationshipIntelligence {
    public static let shared = RelationshipIntelligence()

    // MARK: - Properties

    private var relationships: [String: ContactRelationship] = [:]
    private var communicationLog: [CommunicationEvent] = []
    private var relationshipDecayAlerts: [String: Date] = [:] // Last alert sent per contact

    // Callbacks
    private var onRelationshipDecay: ((ContactRelationship) -> Void)?
    private var onFollowUpSuggested: ((ContactRelationship, String) -> Void)?
    private var onNewContactDetected: ((ContactRelationship) -> Void)?

    // MARK: - Types

    public struct CommunicationEvent: Codable, Sendable {
        let id: UUID
        let contactId: String
        let timestamp: Date
        let direction: Direction
        let type: EventType
        let platform: String
        let durationSeconds: Int?
        let messageLength: Int?
        let wasUrgent: Bool
        let wasActuallyUrgent: Bool?

        public enum Direction: String, Codable, Sendable {
            case incoming, outgoing
        }

        public enum EventType: String, Codable, Sendable {
            case message, call, email, meeting
        }
    }

    // MARK: - Initialization

    private init() {}

    public func configure(
        onRelationshipDecay: @escaping @Sendable (ContactRelationship) -> Void,
        onFollowUpSuggested: @escaping @Sendable (ContactRelationship, String) -> Void,
        onNewContactDetected: @escaping @Sendable (ContactRelationship) -> Void
    ) {
        self.onRelationshipDecay = onRelationshipDecay
        self.onFollowUpSuggested = onFollowUpSuggested
        self.onNewContactDetected = onNewContactDetected
    }

    // MARK: - Communication Logging

    public func logCommunication(
        contactId: String,
        contactName: String,
        direction: CommunicationEvent.Direction,
        type: CommunicationEvent.EventType,
        platform: String,
        durationSeconds: Int? = nil,
        messageLength: Int? = nil,
        wasUrgent: Bool = false
    ) async {
        // Create or update relationship
        var relationship = relationships[contactId] ?? ContactRelationship(id: contactId, name: contactName)

        // Update stats
        switch direction {
        case .incoming:
            relationship.lastIncomingContact = Date()
            relationship.totalIncomingMessages += 1
        case .outgoing:
            relationship.lastOutgoingContact = Date()
            relationship.totalOutgoingMessages += 1
        }

        if type == .call {
            relationship.totalCalls += 1
        }

        // Detect patterns
        let hour = Calendar.current.component(.hour, from: Date())
        let day = Calendar.current.component(.weekday, from: Date())

        // Update preferred time/day if we see a pattern
        relationship.preferredTimeOfDay = hour
        relationship.preferredDayOfWeek = day

        // Log event
        let event = CommunicationEvent(
            id: UUID(),
            contactId: contactId,
            timestamp: Date(),
            direction: direction,
            type: type,
            platform: platform,
            durationSeconds: durationSeconds,
            messageLength: messageLength,
            wasUrgent: wasUrgent,
            wasActuallyUrgent: nil
        )
        communicationLog.append(event)

        // Recalculate relationship metrics
        relationship = await recalculateMetrics(for: relationship)

        relationships[contactId] = relationship

        // Check if this is a new contact
        if relationship.totalIncomingMessages + relationship.totalOutgoingMessages == 1 {
            onNewContactDetected?(relationship)
        }

        await saveData()
    }

    // MARK: - Metrics Calculation

    private func recalculateMetrics(for relationship: ContactRelationship) async -> ContactRelationship {
        var updated = relationship
        updated.lastCalculatedAt = Date()

        // Calculate communication frequency
        updated.communicationFrequency = calculateFrequency(for: relationship)

        // Calculate importance score
        updated.importanceScore = calculateImportance(for: relationship)

        // Calculate urgency reliability
        updated.urgencyReliability = calculateUrgencyReliability(for: relationship.id)

        // Calculate response time
        updated.averageResponseTime = calculateAverageResponseTime(for: relationship.id)

        // Auto-detect tier based on patterns
        updated.tier = detectTier(for: updated)

        return updated
    }

    private func calculateFrequency(for relationship: ContactRelationship) -> ContactRelationship.CommunicationFrequency {
        guard let lastContact = relationship.lastIncomingContact ?? relationship.lastOutgoingContact else {
            return .inactive
        }

        let daysSinceContact = Calendar.current.dateComponents([.day], from: lastContact, to: Date()).day ?? 365

        // Also consider total volume
        let totalContacts = relationship.totalIncomingMessages + relationship.totalOutgoingMessages
        let avgDaysPerContact = totalContacts > 0 ? daysSinceContact / totalContacts : daysSinceContact

        if avgDaysPerContact <= 1 { return .daily }
        if avgDaysPerContact <= 7 { return .weekly }
        if avgDaysPerContact <= 30 { return .monthly }
        if avgDaysPerContact <= 90 { return .quarterly }
        if daysSinceContact < 180 { return .rarely }
        return .inactive
    }

    private func calculateImportance(for relationship: ContactRelationship) -> Double {
        var score: Double = 0.5

        // Tier matters most
        switch relationship.tier {
        case .vip: score = 1.0
        case .inner: score = 0.85
        case .regular: score = 0.6
        case .outer: score = 0.4
        case .unknown: score = 0.3
        }

        // Relationship type adjusts
        switch relationship.relationship {
        case .family: score = max(score, 0.9)
        case .closeFriend: score = max(score, 0.85)
        case .manager: score = max(score, 0.8)
        case .client: score = max(score, 0.75)
        default: break
        }

        // Communication frequency adjusts
        switch relationship.communicationFrequency {
        case .daily: score += 0.1
        case .weekly: score += 0.05
        case .inactive: score -= 0.1
        default: break
        }

        return min(1.0, max(0.0, score))
    }

    private func calculateUrgencyReliability(for contactId: String) -> Double {
        let events = communicationLog.filter { $0.contactId == contactId && $0.wasUrgent }

        guard !events.isEmpty else { return 0.5 } // Default

        let confirmedUrgent = events.filter { $0.wasActuallyUrgent == true }.count
        let confirmedNotUrgent = events.filter { $0.wasActuallyUrgent == false }.count

        let total = confirmedUrgent + confirmedNotUrgent
        guard total > 0 else { return 0.5 }

        return Double(confirmedUrgent) / Double(total)
    }

    private func calculateAverageResponseTime(for contactId: String) -> TimeInterval? {
        // Would analyze message pairs to find response times
        nil
    }

    private func detectTier(for relationship: ContactRelationship) -> ContactRelationship.RelationshipTier {
        // Don't override manual VIP setting
        if relationship.tier == .vip { return .vip }

        // Auto-detect based on patterns
        let total = relationship.totalIncomingMessages + relationship.totalOutgoingMessages

        if total > 100 || relationship.relationship == .family || relationship.relationship == .closeFriend {
            return .inner
        } else if total > 30 || relationship.relationship == .manager || relationship.relationship == .client {
            return .regular
        } else if total > 5 {
            return .outer
        }

        return .unknown
    }

    // MARK: - Relationship Decay Detection

    public func checkForRelationshipDecay() async -> [ContactRelationship] {
        var decayingRelationships: [ContactRelationship] = []
        let now = Date()

        for (_, relationship) in relationships {
            guard let lastContact = relationship.lastIncomingContact ?? relationship.lastOutgoingContact else {
                continue
            }

            let daysSinceContact = Calendar.current.dateComponents([.day], from: lastContact, to: now).day ?? 0
            let expectedDays = relationship.communicationFrequency.expectedDaysBetweenContact

            // If we're 50% over the expected time, it's decaying
            if daysSinceContact > Int(Double(expectedDays) * 1.5) {
                // Only alert once per month
                if let lastAlert = relationshipDecayAlerts[relationship.id] {
                    let daysSinceAlert = Calendar.current.dateComponents([.day], from: lastAlert, to: now).day ?? 0
                    if daysSinceAlert < 30 { continue }
                }

                decayingRelationships.append(relationship)
                relationshipDecayAlerts[relationship.id] = now
                onRelationshipDecay?(relationship)
            }
        }

        return decayingRelationships
    }

    // MARK: - Follow-up Suggestions

    public func getSuggestedFollowUps() async -> [(ContactRelationship, String)] {
        var suggestions: [(ContactRelationship, String)] = []

        for (_, relationship) in relationships {
            if let suggestion = generateFollowUpSuggestion(for: relationship) {
                suggestions.append((relationship, suggestion))
            }
        }

        return suggestions.sorted { $0.0.importanceScore > $1.0.importanceScore }
    }

    private func generateFollowUpSuggestion(for relationship: ContactRelationship) -> String? {
        guard let lastContact = relationship.lastIncomingContact ?? relationship.lastOutgoingContact else {
            return nil
        }

        let daysSince = Calendar.current.dateComponents([.day], from: lastContact, to: Date()).day ?? 0
        let expectedDays = relationship.communicationFrequency.expectedDaysBetweenContact

        if daysSince > expectedDays {
            let tierContext: String
            switch relationship.tier {
            case .vip, .inner:
                tierContext = "It's been \(daysSince) days. They're important to you."
            case .regular:
                tierContext = "Consider reaching out after \(daysSince) days."
            default:
                return nil // Don't suggest for outer/unknown
            }

            return tierContext
        }

        return nil
    }

    // MARK: - Queries

    public func getRelationship(for contactId: String) -> ContactRelationship? {
        relationships[contactId]
    }

    public func getVIPContacts() -> [ContactRelationship] {
        relationships.values.filter { $0.tier == .vip }.sorted { $0.importanceScore > $1.importanceScore }
    }

    public func getInnerCircle() -> [ContactRelationship] {
        relationships.values.filter { $0.tier == .inner || $0.tier == .vip }
            .sorted { $0.importanceScore > $1.importanceScore }
    }

    public func getContactsByRelationshipType(_ type: ContactRelationship.RelationshipType) -> [ContactRelationship] {
        relationships.values.filter { $0.relationship == type }
    }

    public func getRecentlyContactedPeople(days: Int = 7) -> [ContactRelationship] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return relationships.values.filter { relationship in
            guard let last = relationship.lastIncomingContact ?? relationship.lastOutgoingContact else { return false }
            return last > cutoff
        }.sorted { ($0.lastIncomingContact ?? .distantPast) > ($1.lastIncomingContact ?? .distantPast) }
    }

    public func getPeopleToReconnectWith() async -> [ContactRelationship] {
        await checkForRelationshipDecay()
    }

    // MARK: - Manual Configuration

    public func setRelationshipType(_ contactId: String, type: ContactRelationship.RelationshipType) async {
        guard var relationship = relationships[contactId] else { return }
        relationship.relationship = type
        relationship = await recalculateMetrics(for: relationship)
        relationships[contactId] = relationship
        await saveData()
    }

    public func setTier(_ contactId: String, tier: ContactRelationship.RelationshipTier) async {
        guard var relationship = relationships[contactId] else { return }
        relationship.tier = tier
        relationship = await recalculateMetrics(for: relationship)
        relationships[contactId] = relationship
        await saveData()
    }

    public func markAsVIP(_ contactId: String) async {
        await setTier(contactId, tier: .vip)
    }

    public func recordUrgencyFeedback(contactId: String, wasActuallyUrgent: Bool) async {
        // Find the most recent urgent event from this contact
        if let index = communicationLog.lastIndex(where: { $0.contactId == contactId && $0.wasUrgent }) {
            let event = communicationLog[index]
            // Note: CommunicationEvent is a struct, we'd need to make it mutable or recreate
            communicationLog[index] = CommunicationEvent(
                id: event.id,
                contactId: event.contactId,
                timestamp: event.timestamp,
                direction: event.direction,
                type: event.type,
                platform: event.platform,
                durationSeconds: event.durationSeconds,
                messageLength: event.messageLength,
                wasUrgent: event.wasUrgent,
                wasActuallyUrgent: wasActuallyUrgent
            )
        }

        // Recalculate reliability
        if var relationship = relationships[contactId] {
            relationship.urgencyReliability = calculateUrgencyReliability(for: contactId)
            relationships[contactId] = relationship
            await saveData()
        }
    }

    // MARK: - Urgency Boosting

    /// Get urgency boost based on relationship
    public func getUrgencyBoost(for contactId: String) -> Double {
        guard let relationship = relationships[contactId] else { return 0.0 }

        var boost: Double = 0.0

        // Tier boost
        switch relationship.tier {
        case .vip: boost += 0.3
        case .inner: boost += 0.2
        case .regular: boost += 0.1
        default: break
        }

        // Relationship type boost
        switch relationship.relationship {
        case .family: boost += 0.2
        case .manager: boost += 0.15
        case .client: boost += 0.1
        default: break
        }

        // Reliability boost (if they're usually right about urgency)
        if relationship.urgencyReliability > 0.7 {
            boost += 0.15
        } else if relationship.urgencyReliability < 0.3 {
            boost -= 0.1 // Penalty for cry-wolf contacts
        }

        return min(0.5, max(-0.2, boost)) // Cap at ±0.5
    }

    // MARK: - Persistence

    private func saveData() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe") {
            if let encoded = try? JSONEncoder().encode(Array(relationships.values)) {
                defaults.set(encoded, forKey: "contactRelationships")
            }
            // Keep only last 1000 communication events
            let recentLog = Array(communicationLog.suffix(1000))
            if let logEncoded = try? JSONEncoder().encode(recentLog) {
                defaults.set(logEncoded, forKey: "communicationLog")
            }
            defaults.synchronize()
        }
    }

    public func loadData() async {
        if let defaults = UserDefaults(suiteName: "group.app.theathe") {
            if let data = defaults.data(forKey: "contactRelationships"),
               let loaded = try? JSONDecoder().decode([ContactRelationship].self, from: data) {
                for rel in loaded {
                    relationships[rel.id] = rel
                }
            }
            if let logData = defaults.data(forKey: "communicationLog"),
               let loadedLog = try? JSONDecoder().decode([CommunicationEvent].self, from: logData) {
                communicationLog = loadedLog
            }
        }
    }
}
