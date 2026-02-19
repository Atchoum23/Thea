// MoltbookAgent.swift
// Thea — Moltbook Development Discussion Agent
//
// Privacy-preserving agent that participates in public development discussions
// on Moltbook. All outbound content passes through OutboundPrivacyGuard with
// MoltbookPolicy (paranoid level). Aggregates crowdsourced dev insights locally.

import Foundation
import OSLog

// MARK: - Moltbook Agent

actor MoltbookAgent {
    static let shared = MoltbookAgent()

    private let logger = Logger(subsystem: "com.thea.app", category: "MoltbookAgent")
    // periphery:ignore - Reserved: privacyGuard property — reserved for future feature activation
    private let privacyGuard = OutboundPrivacyGuard.shared

    // MARK: - Configuration

    /// Whether the agent is active
    private(set) var isEnabled = false

    /// Preview mode: user reviews every outbound post (default ON for first 2 weeks)
    var previewMode = true

    /// Topics of interest for monitoring
    var topicsOfInterest: Set<String> = [
        "swift", "swiftui", "ios", "macos",
        "mlx", "coreml", "ai", "llm",
        "architecture", "privacy", "performance"
    ]

    /// Auto-visit interval (seconds) — default 4 hours
    var heartbeatInterval: TimeInterval = 4 * 60 * 60

// periphery:ignore - Reserved: privacyGuard property reserved for future feature activation

    /// Maximum posts per day to avoid flooding
    var maxDailyPosts = 10

    // MARK: - State

    // periphery:ignore - Reserved: lastHeartbeat property — reserved for future feature activation
    private(set) var lastHeartbeat: Date?
    private(set) var pendingPosts: [MoltbookPost] = []
    private(set) var insights: [DevelopmentInsight] = []
    private var heartbeatTask: Task<Void, Never>?
    private var dailyPostCount = 0
    private var lastPostCountReset: Date?

    private init() {}

    /// Configure the agent settings from SettingsManager values
    func configure(previewMode: Bool, maxDailyPosts: Int) {
        self.previewMode = previewMode
        self.maxDailyPosts = maxDailyPosts
    }

    // MARK: - Lifecycle

    /// Enable the Moltbook agent
    // periphery:ignore - Reserved: lastHeartbeat property reserved for future feature activation
    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        logger.info("Moltbook agent enabled (preview mode: \(self.previewMode))")
        startHeartbeat()
    }

    /// Update preview mode setting
    func setPreviewMode(_ enabled: Bool) {
        previewMode = enabled
    }

    /// Update max daily posts setting
    func setMaxDailyPosts(_ count: Int) {
        maxDailyPosts = count
    }

    /// Disable the agent immediately (kill switch)
    func disable() {
        isEnabled = false
        heartbeatTask?.cancel()
        heartbeatTask = nil
        pendingPosts.removeAll()
        logger.info("Moltbook agent disabled — all pending posts cleared")
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let enabled = await self.isEnabled
                guard enabled else { return }

                await self.performHeartbeat()

                do {
                    try await Task.sleep(for: .seconds(self.heartbeatInterval))
                } catch {
                    break // Task cancelled — heartbeat loop ending
                }
            }
        }
    }

    private func performHeartbeat() async {
        lastHeartbeat = Date()
        resetDailyCountIfNeeded()

        logger.debug("Moltbook heartbeat — checking for relevant discussions")

        // Fetch recent discussions from Moltbook via OpenClaw
        do {
            let discussions = try await fetchRelevantDiscussions()
            for discussion in discussions {
                await processInboundDiscussion(discussion)
            }
        } catch {
            logger.error("Heartbeat failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Inbound Processing

    /// Process an incoming Moltbook discussion (from OpenClaw message stream)
    func processInboundMessage(_ message: OpenClawMessage) async {
        guard isEnabled else { return }

        // Sanitize inbound content against prompt injection
        let securityResult = await OpenClawSecurityGuard.shared.validate(message)
        guard securityResult.isAllowed else {
            logger.warning("Inbound Moltbook message blocked by security guard")
            return
        }

        // Check if the topic is relevant
        guard isRelevantTopic(message.content) else { return }

        // Extract development insight
        let insight = extractInsight(from: message)
        if let insight {
            insights.append(insight)
            trimInsights()
            logger.info("New dev insight: \(insight.title)")
        }
    }

    private func processInboundDiscussion(_ discussion: MoltbookDiscussion) async {
        guard isRelevantTopic(discussion.title + " " + discussion.summary) else { return }

        let insight = DevelopmentInsight(
            id: UUID(),
            timestamp: Date(),
            source: "moltbook:\(discussion.id)",
            title: discussion.title,
            summary: discussion.summary,
            topics: discussion.tags,
            actionability: .informational,
            isRead: false
        )
        insights.append(insight)
        trimInsights()
    }

    // MARK: - Outbound Processing

    /// Compose a response to a Moltbook discussion.
    /// All content is sanitized through OutboundPrivacyGuard with MoltbookPolicy.
    // periphery:ignore - Reserved: composeResponse(to:content:) instance method — reserved for future feature activation
    func composeResponse(to discussionID: String, content: String) async -> MoltbookPostResult {
        guard isEnabled else {
            return .rejected(reason: "Agent is disabled")
        }

        // Check daily limit
        resetDailyCountIfNeeded()
        guard dailyPostCount < maxDailyPosts else {
            return .rejected(reason: "Daily post limit reached (\(maxDailyPosts))")
        }

        // Sanitize through privacy guard with paranoid Moltbook policy
        let outcome = await privacyGuard.sanitize(content, channel: "moltbook")

        switch outcome {
        case let .clean(text):
            return await handleOutboundPost(discussionID: discussionID, text: text)

// periphery:ignore - Reserved: composeResponse(to:content:) instance method reserved for future feature activation

        case let .redacted(text, redactions):
            logger.info("Moltbook post redacted (\(redactions.count) redactions)")
            return await handleOutboundPost(discussionID: discussionID, text: text)

        case let .blocked(reason):
            logger.warning("Moltbook post blocked: \(reason)")
            return .rejected(reason: "Privacy guard blocked: \(reason)")
        }
    }

    // periphery:ignore - Reserved: handleOutboundPost(discussionID:text:) instance method — reserved for future feature activation
    private func handleOutboundPost(discussionID: String, text: String) async -> MoltbookPostResult {
        let post = MoltbookPost(
            id: UUID(),
            discussionID: discussionID,
            content: text,
            createdAt: Date(),
            status: previewMode ? .pendingReview : .approved
        )

        if previewMode {
            pendingPosts.append(post)
            return .pendingReview(post)
        }

        // Send directly if not in preview mode
        do {
            // periphery:ignore - Reserved: handleOutboundPost(discussionID:text:) instance method reserved for future feature activation
            try await sendPost(post)
            dailyPostCount += 1
            return .sent(post)
        } catch {
            return .rejected(reason: "Send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Pending Post Management

    /// Approve a pending post (user action)
    // periphery:ignore - Reserved: approvePendingPost(id:) instance method — reserved for future feature activation
    func approvePendingPost(id: UUID) async -> Bool {
        guard let index = pendingPosts.firstIndex(where: { $0.id == id }) else {
            return false
        }

        var post = pendingPosts.remove(at: index)
        post.status = .approved

        do {
            try await sendPost(post)
            dailyPostCount += 1
            return true
        } catch {
            logger.error("Failed to send approved post: \(error.localizedDescription)")
            return false
        // periphery:ignore - Reserved: approvePendingPost(id:) instance method reserved for future feature activation
        }
    }

    /// Reject a pending post (user action)
    // periphery:ignore - Reserved: rejectPendingPost(id:) instance method — reserved for future feature activation
    func rejectPendingPost(id: UUID) {
        pendingPosts.removeAll { $0.id == id }
    }

    /// Clear all pending posts
    // periphery:ignore - Reserved: clearPendingPosts() instance method — reserved for future feature activation
    func clearPendingPosts() {
        pendingPosts.removeAll()
    }

    // MARK: - Insights

    /// Get unread development insights
    // periphery:ignore - Reserved: getUnreadInsights() instance method — reserved for future feature activation
    func getUnreadInsights() -> [DevelopmentInsight] {
        insights.filter { !$0.isRead }
    // periphery:ignore - Reserved: rejectPendingPost(id:) instance method reserved for future feature activation
    }

    /// Mark insight as read
    // periphery:ignore - Reserved: markInsightRead(id:) instance method — reserved for future feature activation
    func markInsightRead(id: UUID) {
        // periphery:ignore - Reserved: clearPendingPosts() instance method reserved for future feature activation
        if let index = insights.firstIndex(where: { $0.id == id }) {
            insights[index].isRead = true
        }
    }

    // MARK: - Private Helpers

// periphery:ignore - Reserved: getUnreadInsights() instance method reserved for future feature activation

    private func isRelevantTopic(_ content: String) -> Bool {
        let lower = content.lowercased()
        return topicsOfInterest.contains { lower.contains($0) }
    // periphery:ignore - Reserved: markInsightRead(id:) instance method reserved for future feature activation
    }

    private func extractInsight(from message: OpenClawMessage) -> DevelopmentInsight? {
        let content = message.content
        guard content.count > 20 else { return nil }

        // Extract a title from the first line or sentence
        let firstLine = content.split(separator: "\n").first.map(String.init) ?? content
        let title = String(firstLine.prefix(100))

        let matchingTopics = topicsOfInterest.filter { content.lowercased().contains($0) }

        return DevelopmentInsight(
            id: UUID(),
            timestamp: Date(),
            source: "moltbook:\(message.channelID)",
            title: title,
            summary: String(content.prefix(500)),
            topics: Array(matchingTopics),
            actionability: .informational,
            isRead: false
        )
    }

    private func fetchRelevantDiscussions() async throws -> [MoltbookDiscussion] {
        // Fetch via OpenClaw Gateway — Moltbook channels
        // In practice this would query the OpenClaw API for Moltbook channel messages
        // For now, return empty — populated when OpenClaw connects to Moltbook
        []
    }

    // periphery:ignore - Reserved: sendPost(_:) instance method — reserved for future feature activation
    private func sendPost(_ post: MoltbookPost) async throws {
        // Send via OpenClaw to the Moltbook channel
        try await OpenClawIntegration.shared.sendMessage(
            to: post.discussionID,
            text: post.content
        )
    }

    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        // periphery:ignore - Reserved: sendPost(_:) instance method reserved for future feature activation
        if let lastReset = lastPostCountReset,
           calendar.isDateInToday(lastReset)
        {
            return
        }
        dailyPostCount = 0
        lastPostCountReset = Date()
    }

    private func trimInsights() {
        let maxInsights = 500
        if insights.count > maxInsights {
            insights = Array(insights.suffix(maxInsights))
        }
    }
}

// MARK: - Moltbook Types

struct MoltbookPost: Sendable, Identifiable {
    let id: UUID
    let discussionID: String
    let content: String
    // periphery:ignore - Reserved: createdAt property — reserved for future feature activation
    let createdAt: Date
    // periphery:ignore - Reserved: status property — reserved for future feature activation
    var status: PostStatus

    enum PostStatus: String, Sendable {
        case pendingReview
        case approved
        case rejected
        case sent
    }
// periphery:ignore - Reserved: createdAt property reserved for future feature activation
// periphery:ignore - Reserved: status property reserved for future feature activation
}

struct MoltbookDiscussion: Sendable {
    let id: String
    let title: String
    let summary: String
    let tags: [String]
    // periphery:ignore - Reserved: participantCount property — reserved for future feature activation
    let participantCount: Int
    // periphery:ignore - Reserved: lastActivityAt property — reserved for future feature activation
    let lastActivityAt: Date
}

struct DevelopmentInsight: Sendable, Identifiable {
    let id: UUID
    // periphery:ignore - Reserved: timestamp property — reserved for future feature activation
    let timestamp: Date
    // periphery:ignore - Reserved: participantCount property reserved for future feature activation
    // periphery:ignore - Reserved: lastActivityAt property reserved for future feature activation
    let source: String
    let title: String
    // periphery:ignore - Reserved: summary property — reserved for future feature activation
    let summary: String
    // periphery:ignore - Reserved: topics property — reserved for future feature activation
    let topics: [String]
    // periphery:ignore - Reserved: timestamp property reserved for future feature activation
    // periphery:ignore - Reserved: source property reserved for future feature activation
    let actionability: Actionability
    // periphery:ignore - Reserved: summary property reserved for future feature activation
    // periphery:ignore - Reserved: topics property reserved for future feature activation
    // periphery:ignore - Reserved: actionability property reserved for future feature activation
    var isRead: Bool

    enum Actionability: String, Sendable {
        case informational    // FYI — no action needed
        case suggestion       // Consider applying
        case recommended      // Strongly recommended
    }
}

// periphery:ignore - Reserved: MoltbookPostResult type reserved for future feature activation
enum MoltbookPostResult: Sendable {
    case sent(MoltbookPost)
    case pendingReview(MoltbookPost)
    case rejected(reason: String)
}
