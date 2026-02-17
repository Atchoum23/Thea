// MessagesMonitor.swift
// Thea V2 - Messages.app Monitoring Service
//
// Monitors the Messages chat.db database for new messages
// to enable THEA's communication awareness.
//
// IMPORTANT: Requires Full Disk Access permission in System Preferences
// Location: ~/Library/Messages/chat.db

#if os(macOS)

import Foundation
import os.log
import SQLite3

// MARK: - Messages Monitor Protocol

public protocol MessagesMonitorDelegate: AnyObject, Sendable {
    nonisolated func messagesMonitor(_ _monitor: MessagesMonitor, didReceive message: MonitoredMessageEvent)
}

// MARK: - Messages Monitor

/// Monitors Messages.app chat.db for new messages
public actor MessagesMonitor {
    private let logger = Logger(subsystem: "ai.thea.app", category: "MessagesMonitor")

    public weak var delegate: MessagesMonitorDelegate?

    /// Set the delegate (for use from MainActor contexts)
    public func setDelegate(_ delegate: MessagesMonitorDelegate?) {
        self.delegate = delegate
    }

    private var isRunning = false
    private var monitorTask: Task<Void, Never>?
    private var lastMessageRowId: Int64 = 0
    private var db: OpaquePointer?

    // Chat database path
    private let chatDbPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Messages/chat.db"
    }()

    // Poll interval — base 15s (was 5s), scaled by EnergyAdaptiveThrottler
    private let baseIntervalSeconds: Double = 15.0

    public init() {}

    // MARK: - Lifecycle

    public func start() async {
        guard !isRunning else {
            logger.warning("Messages monitor already running")
            return
        }

        // Check if chat.db exists and is accessible
        guard FileManager.default.fileExists(atPath: chatDbPath) else {
            logger.error("chat.db not found at: \(self.chatDbPath)")
            return
        }

        // Open database
        guard openDatabase() else {
            logger.error("Failed to open chat.db - Full Disk Access may be required")
            return
        }

        // Get the latest message row ID as baseline
        lastMessageRowId = getLatestMessageRowId()

        isRunning = true
        monitorTask = Task { [weak self] in
            await self?.monitorLoop()
        }

        logger.info("Messages monitor started (baseline rowid: \(self.lastMessageRowId))")
    }

    public func stop() async {
        isRunning = false
        monitorTask?.cancel()
        monitorTask = nil
        closeDatabase()
        logger.info("Messages monitor stopped")
    }

    // MARK: - Database Operations

    private func openDatabase() -> Bool {
        // Open in read-only mode
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX

        if sqlite3_open_v2(chatDbPath, &db, flags, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            logger.error("Failed to open database: \(errorMessage)")
            return false
        }

        return true
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    private func getLatestMessageRowId() -> Int64 {
        guard let db else { return 0 }

        let query = "SELECT MAX(ROWID) FROM message"
        var stmt: OpaquePointer?

        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            return 0
        }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int64(stmt, 0)
        }

        return 0
    }

    // MARK: - Monitoring Loop

    private func monitorLoop() async {
        while isRunning && !Task.isCancelled {
            await checkForNewMessages()
            let multiplier = await MainActor.run { EnergyAdaptiveThrottler.shared.intervalMultiplier }
            let interval = baseIntervalSeconds * multiplier
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    private func checkForNewMessages() async {
        guard let db else { return }

        // Query for new messages since last check
        let query = """
            SELECT
                m.ROWID,
                m.guid,
                m.text,
                m.is_from_me,
                m.date,
                m.service,
                m.cache_has_attachments,
                h.id as handle_id,
                h.service as handle_service,
                COALESCE(
                    (SELECT COALESCE(c.display_name, c.group_id)
                     FROM chat_message_join cmj
                     JOIN chat c ON cmj.chat_id = c.ROWID
                     WHERE cmj.message_id = m.ROWID
                     LIMIT 1),
                    h.id
                ) as chat_identifier
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.ROWID > ?
            ORDER BY m.ROWID ASC
            LIMIT 100
            """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            logger.error("Failed to prepare query: \(errorMessage)")
            return
        }

        sqlite3_bind_int64(stmt, 1, lastMessageRowId)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(stmt, 0)

            // Extract message data
            let messageEvent = extractMessageEvent(from: stmt, rowId: rowId)

            // Update last seen rowid
            lastMessageRowId = rowId

            // Notify delegate
            delegate?.messagesMonitor(self, didReceive: messageEvent)
        }
    }

    private func extractMessageEvent(from stmt: OpaquePointer?, rowId: Int64) -> MonitoredMessageEvent {
        // GUID
        let guid: String = {
            if let cStr = sqlite3_column_text(stmt, 1) {
                return String(cString: cStr)
            }
            return ""
        }()

        // Text content (may be nil for attachments-only messages)
        let text: String? = {
            if let cStr = sqlite3_column_text(stmt, 2) {
                return String(cString: cStr)
            }
            return nil
        }()

        // Is from me
        let isFromMe = sqlite3_column_int(stmt, 3) == 1

        // Date (Apple's date format: seconds since 2001-01-01)
        let appleDate = sqlite3_column_int64(stmt, 4)
        let date = convertAppleDateToDate(appleDate)

        // Service (iMessage, SMS)
        let service: String = {
            if let cStr = sqlite3_column_text(stmt, 5) {
                return String(cString: cStr)
            }
            return "unknown"
        }()

        // Has attachments
        let hasAttachment = sqlite3_column_int(stmt, 6) == 1

        // Handle ID (phone number or email)
        let handleId: String = {
            if let cStr = sqlite3_column_text(stmt, 7) {
                return String(cString: cStr)
            }
            return "unknown"
        }()

        // Chat identifier (group name or handle)
        let chatIdentifier: String = {
            if let cStr = sqlite3_column_text(stmt, 9) {
                return String(cString: cStr)
            }
            return handleId
        }()

        // Analyze sentiment (basic)
        let sentiment = analyzeSentiment(text ?? "")

        return MonitoredMessageEvent(
            rowId: rowId,
            guid: guid,
            text: text,
            isFromMe: isFromMe,
            timestamp: date,
            service: service,
            handleId: handleId,
            chatIdentifier: chatIdentifier,
            contactName: lookupContactName(handleId),
            hasAttachment: hasAttachment,
            sentiment: sentiment
        )
    }

    private func convertAppleDateToDate(_ appleDate: Int64) -> Date {
        // Apple's date epoch is 2001-01-01, and dates may be in nanoseconds
        // Check if it's in nanoseconds (very large number) or seconds
        let seconds: Double
        if appleDate > 1_000_000_000_000 {
            // Nanoseconds
            seconds = Double(appleDate) / 1_000_000_000.0
        } else {
            // Seconds
            seconds = Double(appleDate)
        }

        // Apple epoch: 2001-01-01 00:00:00 UTC
        let appleEpoch = Date(timeIntervalSinceReferenceDate: 0)
        return appleEpoch.addingTimeInterval(seconds)
    }

    private func lookupContactName(_ _handleId: String) -> String? {
        // In a full implementation, this would query the Contacts database
        // For now, return nil (use handleId as fallback)
        nil
    }

    // MARK: - Sentiment Analysis

    private func analyzeSentiment(_ text: String) -> Double {
        // Basic sentiment analysis
        let lowercased = text.lowercased()

        var score = 0.0

        // Positive indicators
        let positiveWords = [
            "love", "great", "awesome", "thanks", "thank you", "happy",
            "good", "nice", "wonderful", "amazing", "excited", "yes",
            "❤️", "😊", "😁", "👍", "🎉", "😍", "🥰", "👏"
        ]

        let negativeWords = [
            "hate", "bad", "terrible", "awful", "sorry", "sad",
            "angry", "frustrated", "annoyed", "no", "cancel", "problem",
            "😢", "😠", "😡", "👎", "😤", "😞", "💔"
        ]

        for word in positiveWords {
            if lowercased.contains(word) {
                score += 0.2
            }
        }

        for word in negativeWords {
            if lowercased.contains(word) {
                score -= 0.2
            }
        }

        return max(-1.0, min(1.0, score))
    }

    // MARK: - History Queries

    /// Get recent message history (for initial context)
    public func getRecentHistory(days: Int = 7, limit: Int = 100) async -> [MonitoredMessageEvent] {
        guard let db else { return [] }

        // Calculate date threshold (Apple date format)
        let threshold = Date().addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
        let appleThreshold = Int64(threshold.timeIntervalSinceReferenceDate)

        let query = """
            SELECT
                m.ROWID,
                m.guid,
                m.text,
                m.is_from_me,
                m.date,
                m.service,
                m.cache_has_attachments,
                h.id as handle_id,
                h.service as handle_service,
                COALESCE(
                    (SELECT COALESCE(c.display_name, c.group_id)
                     FROM chat_message_join cmj
                     JOIN chat c ON cmj.chat_id = c.ROWID
                     WHERE cmj.message_id = m.ROWID
                     LIMIT 1),
                    h.id
                ) as chat_identifier
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.date > ?
            ORDER BY m.date DESC
            LIMIT ?
            """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            return []
        }

        sqlite3_bind_int64(stmt, 1, appleThreshold)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var messages: [MonitoredMessageEvent] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(stmt, 0)
            let event = extractMessageEvent(from: stmt, rowId: rowId)
            messages.append(event)
        }

        return messages.reversed() // Chronological order
    }

    /// Get conversation summary (who you message most)
    public func getConversationSummary(days: Int = 30) async -> [ConversationSummary] {
        guard let db else { return [] }

        let threshold = Date().addingTimeInterval(TimeInterval(-days * 24 * 60 * 60))
        let appleThreshold = Int64(threshold.timeIntervalSinceReferenceDate)

        let query = """
            SELECT
                h.id as handle_id,
                COUNT(*) as message_count,
                SUM(CASE WHEN m.is_from_me = 1 THEN 1 ELSE 0 END) as sent_count,
                SUM(CASE WHEN m.is_from_me = 0 THEN 1 ELSE 0 END) as received_count,
                MAX(m.date) as last_message_date
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.date > ? AND h.id IS NOT NULL
            GROUP BY h.id
            ORDER BY message_count DESC
            LIMIT 20
            """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) != SQLITE_OK {
            return []
        }

        sqlite3_bind_int64(stmt, 1, appleThreshold)

        var summaries: [ConversationSummary] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let handleId: String = {
                if let cStr = sqlite3_column_text(stmt, 0) {
                    return String(cString: cStr)
                }
                return "unknown"
            }()

            let messageCount = sqlite3_column_int(stmt, 1)
            let sentCount = sqlite3_column_int(stmt, 2)
            let receivedCount = sqlite3_column_int(stmt, 3)
            let lastMessageDate = sqlite3_column_int64(stmt, 4)

            summaries.append(ConversationSummary(
                handleId: handleId,
                contactName: lookupContactName(handleId),
                totalMessages: Int(messageCount),
                sentMessages: Int(sentCount),
                receivedMessages: Int(receivedCount),
                lastMessageDate: convertAppleDateToDate(lastMessageDate)
            ))
        }

        return summaries
    }
}

// MARK: - Message Event

/// Message event for monitoring (prefixed to avoid conflict with EventBus.MessageEvent)
public struct MonitoredMessageEvent: Sendable {
    public let rowId: Int64
    public let guid: String
    public let text: String?
    public let isFromMe: Bool
    public let timestamp: Date
    public let service: String // "iMessage", "SMS"
    public let handleId: String
    public let chatIdentifier: String
    public let contactName: String?
    public let hasAttachment: Bool
    public let sentiment: Double

    public var displayName: String {
        contactName ?? chatIdentifier
    }

    public var isGroupChat: Bool {
        chatIdentifier.hasPrefix("chat")
    }
}

// MARK: - Conversation Summary

public struct ConversationSummary: Sendable {
    public let handleId: String
    public let contactName: String?
    public let totalMessages: Int
    public let sentMessages: Int
    public let receivedMessages: Int
    public let lastMessageDate: Date

    public var displayName: String {
        contactName ?? handleId
    }

    public var responseRatio: Double {
        guard receivedMessages > 0 else { return 0 }
        return Double(sentMessages) / Double(receivedMessages)
    }
}

#endif
