// SocialMediaMonitor.swift
// Thea V2 - Social Media & Communication Monitoring
//
// Monitors interactions across social platforms:
// - WhatsApp (via Notification/Accessibility on iOS, local DB on macOS if available)
// - Instagram (DMs, likes, comments via notifications)
// - Facebook (Messenger, notifications)
// - Tinder/Raya (matches, messages via notifications)
// - Other dating/social apps
//
// Uses multiple strategies:
// 1. Notification monitoring (all platforms)
// 2. Share Extension captures
// 3. Accessibility events (iOS)
// 4. Local database access (macOS where available)

import Combine
import Foundation
import os.log
#if canImport(UserNotifications)
    import UserNotifications
#endif
#if os(macOS)
    import AppKit
#endif

// MARK: - Social Media Monitor

/// Monitors social media and communication app interactions
@MainActor
public final class SocialMediaMonitor: ObservableObject {
    public static let shared = SocialMediaMonitor()

    private let logger = Logger(subsystem: "ai.thea.app", category: "SocialMediaMonitor")

    // MARK: - Published State

    @Published public private(set) var isMonitoring = false
    @Published public private(set) var recentInteractions: [SocialInteraction] = []
    @Published public private(set) var todayStats: SocialMediaStats = .empty
    @Published public private(set) var contacts: [SocialContact] = []

    // MARK: - Configuration

    public var configuration = SocialMediaConfiguration()

    // MARK: - Internal State

    private var notificationObserver: Any?

    // Known social app bundle identifiers
    private let socialAppIdentifiers: [String: SocialPlatform] = [
        // WhatsApp
        "net.whatsapp.WhatsApp": .whatsApp,
        "group.net.whatsapp.WhatsApp.shared": .whatsApp,

        // Instagram
        "com.burbn.instagram": .instagram,

        // Facebook / Messenger
        "com.facebook.Facebook": .facebook,
        "com.facebook.Messenger": .messenger,

        // Dating Apps
        "com.cardify.tinder": .tinder,
        "com.rfrapp.raya": .raya,
        "com.bumble.app": .bumble,
        "co.hinge.app": .hinge,

        // Other Social
        "com.twitter.twitter": .twitter,
        "com.atebits.Tweetie2": .twitter,
        "com.zhiliaoapp.musically": .tiktok,
        "com.toyopagroup.picaboo": .snapchat,
        "com.linkedin.LinkedIn": .linkedin,
        "ph.telegra.Telegraph": .telegram,
        "org.telegram.Telegram": .telegram,
        "com.hammerandchisel.discord": .discord,
        "net.slackhq.slack": .slack,
        "com.microsoft.teams": .teams,
        "us.zoom.videomeetings": .zoom
    ]

    // MARK: - Initialization

    private init() {
        logger.info("SocialMediaMonitor initialized")
    }

    // MARK: - Lifecycle

    /// Start monitoring social media interactions
    public func start() async {
        guard !isMonitoring else { return }

        logger.info("Starting social media monitoring...")

        // Start notification monitoring
        await startNotificationMonitoring()

        // Start platform-specific monitoring
        #if os(iOS)
            await startIOSMonitoring()
        #elseif os(macOS)
            await startMacOSMonitoring()
        #endif

        isMonitoring = true
        logger.info("Social media monitoring started")
    }

    /// Stop monitoring
    public func stop() async {
        guard isMonitoring else { return }

        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        isMonitoring = false
        logger.info("Social media monitoring stopped")
    }

    // MARK: - Notification Monitoring

    private func startNotificationMonitoring() async {
        // Monitor for notifications from social apps
        // This captures incoming messages, likes, comments, matches, etc.

        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TheaNotificationReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let userInfo = notification.userInfo,
               let bundleId = userInfo["bundleIdentifier"] as? String,
               let platform = self.socialAppIdentifiers[bundleId]
            {
                // Extract values before entering Task to avoid Sendable issues
                let title = userInfo["title"] as? String
                let body = userInfo["body"] as? String
                let senderId = userInfo["senderId"] as? String
                let senderName = userInfo["senderName"] as? String

                Task { @MainActor in
                    self.processNotificationData(
                        platform: platform,
                        title: title,
                        body: body,
                        senderId: senderId,
                        senderName: senderName
                    )
                }
            }
        }
    }

    /// Process notification data with pre-extracted values (Sendable-safe)
    private func processNotificationData(
        platform: SocialPlatform,
        title: String?,
        body: String?,
        senderId: String?,
        senderName: String?
    ) {
        let interactionType = inferInteractionType(
            platform: platform,
            title: title,
            body: body
        )

        let contact = extractContact(
            platform: platform,
            title: title,
            body: body
        )

        var metadata: [String: String] = [:]
        if let senderId = senderId {
            metadata["senderId"] = senderId
        }
        if let senderName = senderName {
            metadata["senderName"] = senderName
        }

        let interaction = SocialInteraction(
            id: UUID(),
            platform: platform,
            type: interactionType,
            contact: contact,
            preview: body,
            timestamp: Date(),
            isIncoming: true,
            metadata: metadata
        )

        recordInteraction(interaction)
    }

    private func inferInteractionType(
        platform: SocialPlatform,
        title: String?,
        body: String?
    ) -> SocialInteractionType {
        let combinedText = "\(title ?? "") \(body ?? "")".lowercased()

        // Dating app specific
        if platform.isDatingApp {
            if combinedText.contains("match") || combinedText.contains("liked you") {
                return .match
            }
            if combinedText.contains("super like") {
                return .superLike
            }
        }

        // Instagram specific
        if platform == .instagram {
            if combinedText.contains("liked your") {
                return .like
            }
            if combinedText.contains("commented") {
                return .comment
            }
            if combinedText.contains("started following") {
                return .follow
            }
            if combinedText.contains("mentioned you") {
                return .mention
            }
            if combinedText.contains("story") {
                return .storyView
            }
        }

        // Facebook specific
        if platform == .facebook || platform == .messenger {
            if combinedText.contains("liked your") || combinedText.contains("reacted") {
                return .like
            }
            if combinedText.contains("commented") {
                return .comment
            }
            if combinedText.contains("tagged you") || combinedText.contains("mentioned") {
                return .mention
            }
        }

        // Default to message for most notifications
        return .message
    }

    private func extractContact(
        platform: SocialPlatform,
        title: String?,
        body _: String?
    ) -> SocialContact? {
        // Try to extract contact name from notification title
        guard let title = title, !title.isEmpty else { return nil }

        // Common patterns: "John sent you a message", "John Smith", "John: Hello"
        var name = title

        // Remove common suffixes
        let suffixes = [
            " sent you a message",
            " sent a photo",
            " sent a video",
            " is typing",
            " liked your",
            " commented on",
            " mentioned you",
            " started following",
            " sent you a match",
            " wants to chat"
        ]

        for suffix in suffixes {
            if name.contains(suffix) {
                name = name.replacingOccurrences(of: suffix, with: "")
                break
            }
        }

        // Handle "Name: message" format
        if let colonIndex = name.firstIndex(of: ":") {
            name = String(name[..<colonIndex])
        }

        // Clean up
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { return nil }

        // Check if we have this contact already
        if let existing = contacts.first(where: {
            $0.name.lowercased() == name.lowercased() && $0.platform == platform
        }) {
            return existing
        }

        // Create new contact
        let contact = SocialContact(
            id: UUID(),
            name: name,
            platform: platform,
            username: nil,
            lastInteraction: Date(),
            interactionCount: 1,
            relationshipType: platform.isDatingApp ? .romantic : .social
        )

        // Store for future reference
        contacts.append(contact)

        return contact
    }

    // periphery:ignore - Reserved: extractMetadata(_:) instance method reserved for future feature activation
    private func extractMetadata(_ userInfo: [AnyHashable: Any]) -> [String: String] {
        var metadata: [String: String] = [:]

        if let threadId = userInfo["threadId"] as? String {
            metadata["threadId"] = threadId
        }
        if let messageId = userInfo["messageId"] as? String {
            metadata["messageId"] = messageId
        }
        if let category = userInfo["category"] as? String {
            metadata["category"] = category
        }

        return metadata
    }

    // MARK: - iOS Specific

    #if os(iOS)
        private func startIOSMonitoring() async {
            // Request notification access to see what apps are sending
            // This gives us insight into social interactions

            // Also monitor app launches via accessibility
            // to track time spent in social apps
        }
    #endif

    // MARK: - macOS Specific

    #if os(macOS)
        private func startMacOSMonitoring() async {
            // On macOS, we can potentially access:
            // - WhatsApp Web local storage
            // - Facebook Messenger local cache
            // - Notification Center database

            // Monitor for app activations
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      let bundleId = app.bundleIdentifier,
                      let platform = self?.socialAppIdentifiers[bundleId]
                else { return }

                Task { @MainActor [weak self] in
                    self?.recordAppUsage(platform: platform, appName: app.localizedName ?? bundleId)
                }
            }
        }

        private func recordAppUsage(platform: SocialPlatform, appName: String) {
            logger.debug("Social app activated: \(appName) (\(platform.rawValue))")

            // Create a usage interaction
            let interaction = SocialInteraction(
                id: UUID(),
                platform: platform,
                type: .appUsage,
                contact: nil,
                preview: "Opened \(appName)",
                timestamp: Date(),
                isIncoming: false,
                metadata: [:]
            )

            recordInteraction(interaction)
        }
    #endif

    // MARK: - Interaction Recording

    private func recordInteraction(_ interaction: SocialInteraction) {
        // Add to recent interactions
        recentInteractions.insert(interaction, at: 0)

        // Trim to max size
        if recentInteractions.count > 500 {
            recentInteractions = Array(recentInteractions.prefix(500))
        }

        // Update today's stats
        updateTodayStats(with: interaction)

        // Update contact's last interaction
        if let contact = interaction.contact {
            if let index = contacts.firstIndex(where: { $0.id == contact.id }) {
                contacts[index].lastInteraction = Date()
                contacts[index].interactionCount += 1
            }
        }

        // Publish to event stream
        publishInteraction(interaction)

        logger.debug("Recorded \(interaction.type.rawValue) from \(interaction.platform.rawValue)")
    }

    private func updateTodayStats(with interaction: SocialInteraction) {
        var stats = todayStats

        // Check if we need to reset for a new day
        if !Calendar.current.isDateInToday(stats.date) {
            stats = .empty
        }

        stats.totalInteractions += 1

        switch interaction.type {
        case .message:
            if interaction.isIncoming {
                stats.messagesReceived += 1
            } else {
                stats.messagesSent += 1
            }
        case .like:
            stats.likesReceived += 1
        case .comment:
            stats.commentsReceived += 1
        case .match:
            stats.matchesReceived += 1
        case .follow:
            stats.followsReceived += 1
        default:
            break
        }

        stats.platformBreakdown[interaction.platform, default: 0] += 1
        stats.date = Date()

        todayStats = stats
    }

    private func publishInteraction(_ interaction: SocialInteraction) {
        // Convert to LifeEvent and publish
        let event = LifeEvent(
            type: interaction.isIncoming ? .messageReceived : .messageSent,
            source: .messages,
            summary: "\(interaction.platform.displayName): \(interaction.type.displayName)",
            data: [
                "platform": interaction.platform.rawValue,
                "interactionType": interaction.type.rawValue,
                "contact": interaction.contact?.name ?? "Unknown",
                "isIncoming": String(interaction.isIncoming)
            ],
            significance: interaction.type.significance
        )

        LifeMonitoringCoordinator.shared.submitEvent(event)
    }

    // MARK: - Manual Entry

    /// Record a manual interaction (e.g., from Share Extension)
    public func recordManualInteraction(
        platform: SocialPlatform,
        type: SocialInteractionType,
        contactName: String?,
        content: String?
    ) {
        let contact = contactName.map { name in
            SocialContact(
                id: UUID(),
                name: name,
                platform: platform,
                username: nil,
                lastInteraction: Date(),
                interactionCount: 1,
                relationshipType: platform.isDatingApp ? .romantic : .social
            )
        }

        let interaction = SocialInteraction(
            id: UUID(),
            platform: platform,
            type: type,
            contact: contact,
            preview: content,
            timestamp: Date(),
            isIncoming: false,
            metadata: [:]
        )

        recordInteraction(interaction)
    }

    // MARK: - Analytics

    /// Get interaction statistics for a contact
    public func getContactStats(_ contact: SocialContact) -> ContactStats {
        let contactInteractions = recentInteractions.filter {
            $0.contact?.id == contact.id
        }

        return ContactStats(
            contact: contact,
            totalInteractions: contactInteractions.count,
            lastWeekCount: contactInteractions.filter {
                $0.timestamp > Date().addingTimeInterval(-7 * 24 * 3600)
            }.count,
            averageResponseTime: nil, // Would need more data to calculate
            sentimentScore: 0.0 // Would need NLP analysis
        )
    }

    /// Get platform usage statistics
    public func getPlatformStats(for platform: SocialPlatform, days: Int = 7) -> PlatformStats {
        let cutoff = Date().addingTimeInterval(TimeInterval(-days * 24 * 3600))
        let platformInteractions = recentInteractions.filter {
            $0.platform == platform && $0.timestamp > cutoff
        }

        let uniqueContacts = Set(platformInteractions.compactMap { $0.contact?.id })

        return PlatformStats(
            platform: platform,
            totalInteractions: platformInteractions.count,
            uniqueContacts: uniqueContacts.count,
            messagesReceived: platformInteractions.filter { $0.type == .message && $0.isIncoming }.count,
            messagesSent: platformInteractions.filter { $0.type == .message && !$0.isIncoming }.count,
            matchesReceived: platformInteractions.filter { $0.type == .match }.count,
            period: days
        )
    }
}

// MARK: - Supporting Types

public enum SocialPlatform: String, Codable, CaseIterable, Sendable {
    case whatsApp = "whatsapp"
    case instagram = "instagram"
    case facebook = "facebook"
    case messenger = "messenger"
    case tinder = "tinder"
    case raya = "raya"
    case bumble = "bumble"
    case hinge = "hinge"
    case twitter = "twitter"
    case tiktok = "tiktok"
    case snapchat = "snapchat"
    case linkedin = "linkedin"
    case telegram = "telegram"
    case discord = "discord"
    case slack = "slack"
    case teams = "teams"
    case zoom = "zoom"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .whatsApp: return "WhatsApp"
        case .instagram: return "Instagram"
        case .facebook: return "Facebook"
        case .messenger: return "Messenger"
        case .tinder: return "Tinder"
        case .raya: return "Raya"
        case .bumble: return "Bumble"
        case .hinge: return "Hinge"
        case .twitter: return "Twitter/X"
        case .tiktok: return "TikTok"
        case .snapchat: return "Snapchat"
        case .linkedin: return "LinkedIn"
        case .telegram: return "Telegram"
        case .discord: return "Discord"
        case .slack: return "Slack"
        case .teams: return "Microsoft Teams"
        case .zoom: return "Zoom"
        case .unknown: return "Unknown"
        }
    }

    public var isDatingApp: Bool {
        [.tinder, .raya, .bumble, .hinge].contains(self)
    }

    public var isMessagingApp: Bool {
        [.whatsApp, .messenger, .telegram, .discord, .slack, .teams].contains(self)
    }
}

public enum SocialInteractionType: String, Codable, Sendable {
    case message = "message"
    case like = "like"
    case comment = "comment"
    case follow = "follow"
    case mention = "mention"
    case match = "match"
    case superLike = "super_like"
    case storyView = "story_view"
    case storyReply = "story_reply"
    case call = "call"
    case videoCall = "video_call"
    case appUsage = "app_usage"
    case unknown = "unknown"

    public var displayName: String {
        switch self {
        case .message: return "Message"
        case .like: return "Like"
        case .comment: return "Comment"
        case .follow: return "Follow"
        case .mention: return "Mention"
        case .match: return "Match"
        case .superLike: return "Super Like"
        case .storyView: return "Story View"
        case .storyReply: return "Story Reply"
        case .call: return "Call"
        case .videoCall: return "Video Call"
        case .appUsage: return "App Usage"
        case .unknown: return "Unknown"
        }
    }

    public var significance: EventSignificance {
        switch self {
        case .match, .superLike:
            return .significant
        case .message, .call, .videoCall:
            return .moderate
        case .like, .comment, .follow, .mention:
            return .minor
        default:
            return .trivial
        }
    }
}

public struct SocialInteraction: Identifiable, Sendable {
    public let id: UUID
    public let platform: SocialPlatform
    public let type: SocialInteractionType
    public let contact: SocialContact?
    public let preview: String?
    public let timestamp: Date
    public let isIncoming: Bool
    public let metadata: [String: String]
}

public struct SocialContact: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public let platform: SocialPlatform
    public var username: String?
    public var lastInteraction: Date
    public var interactionCount: Int
    public var relationshipType: RelationshipType

    public enum RelationshipType: String, Codable, Sendable {
        case romantic
        case friend
        case family
        case colleague
        case acquaintance
        case business
        case social
        case unknown
    }
}

public struct SocialMediaStats: Sendable {
    public var date: Date
    public var totalInteractions: Int
    public var messagesReceived: Int
    public var messagesSent: Int
    public var likesReceived: Int
    public var commentsReceived: Int
    public var matchesReceived: Int
    public var followsReceived: Int
    public var platformBreakdown: [SocialPlatform: Int]

    public static var empty: SocialMediaStats {
        SocialMediaStats(
            date: Date(),
            totalInteractions: 0,
            messagesReceived: 0,
            messagesSent: 0,
            likesReceived: 0,
            commentsReceived: 0,
            matchesReceived: 0,
            followsReceived: 0,
            platformBreakdown: [:]
        )
    }
}

public struct ContactStats: Sendable {
    public let contact: SocialContact
    public let totalInteractions: Int
    public let lastWeekCount: Int
    public let averageResponseTime: TimeInterval?
    public let sentimentScore: Double
}

public struct PlatformStats: Sendable {
    public let platform: SocialPlatform
    public let totalInteractions: Int
    public let uniqueContacts: Int
    public let messagesReceived: Int
    public let messagesSent: Int
    public let matchesReceived: Int
    public let period: Int // days
}

public struct SocialMediaConfiguration: Codable, Sendable {
    public var enabled: Bool = true
    public var enabledPlatforms: Set<SocialPlatform> = Set(SocialPlatform.allCases)
    public var trackNotifications: Bool = true
    public var trackAppUsage: Bool = true
    public var recordContactNames: Bool = true
    public var recordMessagePreviews: Bool = false // Privacy option

    public init() {}
}
