// InteractionTracker.swift
// Thea V2 - People & Companies Interaction Tracking
//
// Aggregates ALL interactions with people and companies across:
// - Messages (iMessage, WhatsApp, Telegram, etc.)
// - Email (personal and business)
// - Social media (Instagram, Facebook, Twitter, etc.)
// - Dating apps (Tinder, Raya, Bumble, Hinge)
// - Calendar meetings
// - Phone calls (FaceTime, regular calls)
// - Professional networks (LinkedIn, Slack, Teams)
//
// Builds relationship intelligence and interaction patterns.

import Combine
import Contacts
import Foundation
import os.log

// MARK: - Interaction Tracker

/// Tracks all interactions with people and companies
@MainActor
public final class InteractionTracker: ObservableObject {
    public static let shared = InteractionTracker()

    private let logger = Logger(subsystem: "ai.thea.app", category: "InteractionTracker")

    // MARK: - Published State

    @Published public private(set) var isTracking = false
    @Published public private(set) var contacts: [TrackedContact] = []
    @Published public private(set) var companies: [TrackedCompany] = []
    @Published public private(set) var recentInteractions: [UnifiedInteraction] = []
    @Published public private(set) var relationshipInsights: [RelationshipInsight] = []

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var interactionBuffer: [UnifiedInteraction] = []

    // MARK: - Configuration

    public var configuration = InteractionTrackerConfiguration()

    // MARK: - Initialization

    private init() {
        logger.info("InteractionTracker initialized")
        setupSubscriptions()
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        // Subscribe to social media interactions
        SocialMediaMonitor.shared.$recentInteractions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interactions in
                for interaction in interactions.prefix(10) {
                    self?.processInteraction(from: interaction)
                }
            }
            .store(in: &cancellables)

        // Subscribe to life events for messages/email
        LifeMonitoringCoordinator.shared.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.processLifeEvent(event)
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    /// Start tracking interactions
    public func start() async {
        guard !isTracking else { return }

        logger.info("Starting interaction tracking...")

        // Load contacts from system
        await loadSystemContacts()

        // Start social media monitor
        await SocialMediaMonitor.shared.start()

        isTracking = true
        logger.info("Interaction tracking started")
    }

    /// Stop tracking
    public func stop() async {
        guard isTracking else { return }

        await SocialMediaMonitor.shared.stop()

        isTracking = false
        logger.info("Interaction tracking stopped")
    }

    // MARK: - Contact Loading

    private func loadSystemContacts() async {
        let store = CNContactStore()

        // Request access
        do {
            let authorized = try await store.requestAccess(for: .contacts)
            guard authorized else {
                logger.warning("Contact access not authorized")
                return
            }
        } catch {
            logger.error("Contact authorization error: \(error.localizedDescription)")
            return
        }

        // Fetch contacts
        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactNicknameKey,
            CNContactOrganizationNameKey,
            CNContactJobTitleKey,
            CNContactEmailAddressesKey,
            CNContactPhoneNumbersKey,
            CNContactSocialProfilesKey,
            CNContactIdentifierKey
        ] as [CNKeyDescriptor]

        let request = CNContactFetchRequest(keysToFetch: keys)

        do {
            try store.enumerateContacts(with: request) { [weak self] contact, _ in
                guard let self = self else { return }

                let trackedContact = TrackedContact(
                    id: contact.identifier,
                    firstName: contact.givenName,
                    lastName: contact.familyName,
                    nickname: contact.nickname,
                    company: contact.organizationName.isEmpty ? nil : contact.organizationName,
                    jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle,
                    emails: contact.emailAddresses.map { $0.value as String },
                    phoneNumbers: contact.phoneNumbers.map { $0.value.stringValue },
                    socialProfiles: extractSocialProfiles(from: contact),
                    relationshipType: .unknown,
                    interactionCount: 0,
                    lastInteraction: nil
                )

                Task { @MainActor in
                    self.contacts.append(trackedContact)
                }
            }

            logger.info("Loaded \(self.contacts.count) contacts")
        } catch {
            logger.error("Failed to fetch contacts: \(error.localizedDescription)")
        }
    }

    private func extractSocialProfiles(from contact: CNContact) -> [SocialProfile] {
        var profiles: [SocialProfile] = []

        for profile in contact.socialProfiles {
            let service = profile.value.service.lowercased()
            let username = profile.value.username

            let platform: SocialPlatform?
            switch service {
            case "twitter", "x":
                platform = .twitter
            case "facebook":
                platform = .facebook
            case "linkedin":
                platform = .linkedin
            case "instagram":
                platform = .instagram
            default:
                platform = nil
            }

            if let platform = platform {
                profiles.append(SocialProfile(platform: platform, username: username))
            }
        }

        return profiles
    }

    // MARK: - Interaction Processing

    private func processInteraction(from social: SocialInteraction) {
        // Find or create contact
        let contact: TrackedContact
        if let existingContact = findContact(name: social.contact?.name) {
            contact = existingContact
        } else if let socialContact = social.contact {
            contact = TrackedContact(
                id: socialContact.id.uuidString,
                firstName: socialContact.name,
                lastName: nil,
                nickname: nil,
                company: nil,
                jobTitle: nil,
                emails: [],
                phoneNumbers: [],
                socialProfiles: [SocialProfile(platform: social.platform, username: socialContact.username ?? "unknown")],
                relationshipType: socialContact.relationshipType,
                interactionCount: 0,
                lastInteraction: nil
            )
            contacts.append(contact)
        } else {
            return
        }

        let interaction = UnifiedInteraction(
            id: UUID(),
            contactId: contact.id,
            contactName: contact.fullName,
            channel: channelFromPlatform(social.platform),
            type: interactionTypeFromSocial(social.type),
            direction: social.isIncoming ? .incoming : .outgoing,
            preview: social.preview,
            timestamp: social.timestamp,
            metadata: social.metadata
        )

        recordInteraction(interaction, for: contact)
    }

    private func processLifeEvent(_ event: LifeEvent) {
        switch event.type {
        case .messageReceived, .messageSent:
            if let contactName = event.data["contactName"] ?? event.data["contact"] {
                let interaction = UnifiedInteraction(
                    id: UUID(),
                    contactId: nil,
                    contactName: contactName,
                    channel: .imessage,
                    type: event.type == .messageReceived ? .message : .message,
                    direction: event.type == .messageReceived ? .incoming : .outgoing,
                    preview: event.summary,
                    timestamp: event.timestamp,
                    metadata: event.data
                )

                if let contact = findContact(name: contactName) {
                    recordInteraction(interaction, for: contact)
                } else {
                    recentInteractions.insert(interaction, at: 0)
                }
            }

        case .emailReceived, .emailSent:
            if let sender = event.data["sender"] {
                let interaction = UnifiedInteraction(
                    id: UUID(),
                    contactId: nil,
                    contactName: sender,
                    channel: .email,
                    type: .email,
                    direction: event.type == .emailReceived ? .incoming : .outgoing,
                    preview: event.data["subject"] ?? event.summary,
                    timestamp: event.timestamp,
                    metadata: event.data
                )

                if let contact = findContact(email: sender) {
                    recordInteraction(interaction, for: contact)
                } else if let company = findOrCreateCompany(from: sender) {
                    recordCompanyInteraction(interaction, for: company)
                } else {
                    recentInteractions.insert(interaction, at: 0)
                }
            }

        default:
            break
        }
    }

    // MARK: - Contact/Company Matching

    private func findContact(name: String?) -> TrackedContact? {
        guard let name = name, !name.isEmpty else { return nil }

        let lowercasedName = name.lowercased()

        return contacts.first { contact in
            contact.fullName.lowercased() == lowercasedName ||
                contact.firstName.lowercased() == lowercasedName ||
                (contact.nickname?.lowercased() == lowercasedName)
        }
    }

    private func findContact(email: String) -> TrackedContact? {
        let lowercasedEmail = email.lowercased()

        return contacts.first { contact in
            contact.emails.contains { $0.lowercased() == lowercasedEmail }
        }
    }

    private func findOrCreateCompany(from email: String) -> TrackedCompany? {
        // Extract domain from email
        guard let atIndex = email.firstIndex(of: "@") else { return nil }
        let domain = String(email[email.index(after: atIndex)...]).lowercased()

        // Skip personal email domains
        let personalDomains = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "icloud.com", "me.com"]
        guard !personalDomains.contains(domain) else { return nil }

        // Find existing company
        if let existing = companies.first(where: { $0.domain == domain }) {
            return existing
        }

        // Create new company
        let companyName = domain
            .replacingOccurrences(of: ".com", with: "")
            .replacingOccurrences(of: ".co", with: "")
            .replacingOccurrences(of: ".io", with: "")
            .capitalized

        let company = TrackedCompany(
            id: UUID().uuidString,
            name: companyName,
            domain: domain,
            industry: nil,
            contactEmails: [email],
            interactionCount: 0,
            lastInteraction: nil,
            type: .business
        )

        companies.append(company)
        return company
    }

    // MARK: - Recording

    private func recordInteraction(_ interaction: UnifiedInteraction, for contact: TrackedContact) {
        // Update contact
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
            contacts[index].interactionCount += 1
            contacts[index].lastInteraction = interaction.timestamp
        }

        // Add to recent interactions
        var updatedInteraction = interaction
        updatedInteraction.contactId = contact.id

        recentInteractions.insert(updatedInteraction, at: 0)

        // Trim
        if recentInteractions.count > 1000 {
            recentInteractions = Array(recentInteractions.prefix(1000))
        }

        // Check for relationship insights
        checkForInsights(contact: contact)
    }

    private func recordCompanyInteraction(_ interaction: UnifiedInteraction, for company: TrackedCompany) {
        // Update company
        if let index = companies.firstIndex(where: { $0.id == company.id }) {
            companies[index].interactionCount += 1
            companies[index].lastInteraction = interaction.timestamp
        }

        // Add to recent interactions
        recentInteractions.insert(interaction, at: 0)

        // Trim
        if recentInteractions.count > 1000 {
            recentInteractions = Array(recentInteractions.prefix(1000))
        }
    }

    // MARK: - Insights

    private func checkForInsights(contact: TrackedContact) {
        let contactInteractions = recentInteractions.filter { $0.contactId == contact.id }
        let recentCount = contactInteractions.filter {
            $0.timestamp > Date().addingTimeInterval(-7 * 24 * 3600)
        }.count

        // High engagement insight
        if recentCount >= 10 {
            let insight = RelationshipInsight(
                id: UUID(),
                contactId: contact.id,
                type: .highEngagement,
                title: "High engagement with \(contact.fullName)",
                description: "You've had \(recentCount) interactions in the past week.",
                confidence: 0.9,
                timestamp: Date()
            )

            if !relationshipInsights.contains(where: {
                $0.contactId == contact.id && $0.type == .highEngagement
            }) {
                relationshipInsights.append(insight)
            }
        }

        // One-sided communication
        let incoming = contactInteractions.filter { $0.direction == .incoming }.count
        let outgoing = contactInteractions.filter { $0.direction == .outgoing }.count

        if incoming > 0, outgoing == 0, incoming >= 5 {
            let insight = RelationshipInsight(
                id: UUID(),
                contactId: contact.id,
                type: .needsResponse,
                title: "Pending responses to \(contact.fullName)",
                description: "You have \(incoming) messages without a reply.",
                confidence: 0.85,
                timestamp: Date()
            )

            if !relationshipInsights.contains(where: {
                $0.contactId == contact.id && $0.type == .needsResponse
            }) {
                relationshipInsights.append(insight)
            }
        }
    }

    // MARK: - Helpers

    private func channelFromPlatform(_ platform: SocialPlatform) -> InteractionChannel {
        switch platform {
        case .whatsApp: return .whatsapp
        case .instagram: return .instagram
        case .facebook, .messenger: return .messenger
        case .tinder: return .tinder
        case .raya: return .raya
        case .bumble: return .bumble
        case .hinge: return .hinge
        case .twitter: return .twitter
        case .telegram: return .telegram
        case .discord: return .discord
        case .slack: return .slack
        case .teams: return .teams
        case .linkedin: return .linkedin
        default: return .other
        }
    }

    private func interactionTypeFromSocial(_ type: SocialInteractionType) -> UnifiedInteractionType {
        switch type {
        case .message: return .message
        case .call: return .call
        case .videoCall: return .videoCall
        case .like: return .reaction
        case .comment: return .comment
        case .match: return .match
        case .follow: return .follow
        default: return .other
        }
    }

    // MARK: - Analytics

    /// Get relationship summary for a contact
    public func getRelationshipSummary(for contactId: String) -> RelationshipSummary? {
        guard let contact = contacts.first(where: { $0.id == contactId }) else { return nil }

        let interactions = recentInteractions.filter { $0.contactId == contactId }

        let channelCounts = Dictionary(grouping: interactions) { $0.channel }
            .mapValues { $0.count }

        let preferredChannel = channelCounts.max { $0.value < $1.value }?.key

        return RelationshipSummary(
            contact: contact,
            totalInteractions: interactions.count,
            lastWeekInteractions: interactions.filter {
                $0.timestamp > Date().addingTimeInterval(-7 * 24 * 3600)
            }.count,
            preferredChannel: preferredChannel,
            channelBreakdown: channelCounts,
            relationshipStrength: calculateRelationshipStrength(interactions: interactions)
        )
    }

    private func calculateRelationshipStrength(interactions: [UnifiedInteraction]) -> Double {
        guard !interactions.isEmpty else { return 0 }

        // Factors: recency, frequency, reciprocity

        let now = Date()
        let recentInteractions = interactions.filter {
            $0.timestamp > now.addingTimeInterval(-30 * 24 * 3600)
        }

        // Frequency score (0-0.4)
        let frequencyScore = min(Double(recentInteractions.count) / 30.0, 1.0) * 0.4

        // Recency score (0-0.3)
        let mostRecent = interactions.max { $0.timestamp < $1.timestamp }
        let daysSinceLastInteraction = mostRecent.map {
            now.timeIntervalSince($0.timestamp) / (24 * 3600)
        } ?? 365

        let recencyScore = max(0, 1 - daysSinceLastInteraction / 30.0) * 0.3

        // Reciprocity score (0-0.3)
        let incoming = interactions.filter { $0.direction == .incoming }.count
        let outgoing = interactions.filter { $0.direction == .outgoing }.count
        let total = incoming + outgoing

        let reciprocityScore: Double
        if total > 0 {
            let ratio = Double(min(incoming, outgoing)) / Double(max(incoming, outgoing, 1))
            reciprocityScore = ratio * 0.3
        } else {
            reciprocityScore = 0
        }

        return frequencyScore + recencyScore + reciprocityScore
    }

    /// Get top contacts by interaction frequency
    public func getTopContacts(limit: Int = 10) -> [TrackedContact] {
        contacts
            .sorted { $0.interactionCount > $1.interactionCount }
            .prefix(limit)
            .map { $0 }
    }

    /// Get companies by interaction frequency
    public func getTopCompanies(limit: Int = 10) -> [TrackedCompany] {
        companies
            .sorted { $0.interactionCount > $1.interactionCount }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Supporting Types

public struct TrackedContact: Identifiable, Sendable {
    public let id: String
    public var firstName: String
    public var lastName: String?
    public var nickname: String?
    public var company: String?
    public var jobTitle: String?
    public var emails: [String]
    public var phoneNumbers: [String]
    public var socialProfiles: [SocialProfile]
    public var relationshipType: SocialContact.RelationshipType
    public var interactionCount: Int
    public var lastInteraction: Date?

    public var fullName: String {
        if let lastName = lastName, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        }
        return firstName
    }
}

public struct SocialProfile: Codable, Sendable {
    public let platform: SocialPlatform
    public let username: String
}

public struct TrackedCompany: Identifiable, Sendable {
    public let id: String
    public var name: String
    public var domain: String
    public var industry: String?
    public var contactEmails: [String]
    public var interactionCount: Int
    public var lastInteraction: Date?
    public var type: CompanyType

    public enum CompanyType: String, Codable, Sendable {
        case business
        case service
        case subscription
        case vendor
        case employer
        case client
        case other
    }
}

public struct UnifiedInteraction: Identifiable, Sendable {
    public let id: UUID
    public var contactId: String?
    public let contactName: String
    public let channel: InteractionChannel
    public let type: UnifiedInteractionType
    public let direction: InteractionDirection
    public let preview: String?
    public let timestamp: Date
    public let metadata: [String: String]
}

public enum InteractionChannel: String, Codable, Sendable {
    case imessage
    case whatsapp
    case telegram
    case messenger
    case instagram
    case twitter
    case linkedin
    case discord
    case slack
    case teams
    case zoom
    case facetime
    case phone
    case email
    case tinder
    case raya
    case bumble
    case hinge
    case inPerson
    case other
}

public enum UnifiedInteractionType: String, Codable, Sendable {
    case message
    case call
    case videoCall
    case email
    case meeting
    case reaction
    case comment
    case match
    case follow
    case share
    case other
}

public enum InteractionDirection: String, Codable, Sendable {
    case incoming
    case outgoing
    case mutual
}

public struct RelationshipInsight: Identifiable, Sendable {
    public let id: UUID
    public let contactId: String
    public let type: InsightType
    public let title: String
    public let description: String
    public let confidence: Double
    public let timestamp: Date

    public enum InsightType: String, Codable, Sendable {
        case highEngagement
        case decliningEngagement
        case needsResponse
        case anniversaryReminder
        case reconnectSuggestion
        case relationshipMilestone
    }
}

public struct RelationshipSummary: Sendable {
    public let contact: TrackedContact
    public let totalInteractions: Int
    public let lastWeekInteractions: Int
    public let preferredChannel: InteractionChannel?
    public let channelBreakdown: [InteractionChannel: Int]
    public let relationshipStrength: Double
}

public struct InteractionTrackerConfiguration: Codable, Sendable {
    public var enabled: Bool = true
    public var trackMessages: Bool = true
    public var trackEmails: Bool = true
    public var trackSocial: Bool = true
    public var trackCalls: Bool = true
    public var trackCalendar: Bool = true
    public var generateInsights: Bool = true

    public init() {}
}
