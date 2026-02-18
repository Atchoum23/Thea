// MailMonitor.swift
// Thea V2 - Mail.app Monitoring Service
//
// Monitors Apple Mail for new emails via AppleScript
// to enable THEA's email awareness.

#if os(macOS)

import AppKit
import Foundation
import os.log

// MARK: - Mail Monitor Protocol

public protocol MailMonitorDelegate: AnyObject, Sendable {
    nonisolated func mailMonitor(_ _monitor: MailMonitor, didReceive email: MailEvent)
}

// MARK: - Mail Monitor

/// Monitors Mail.app for new emails
public actor MailMonitor {
    private let logger = Logger(subsystem: "ai.thea.app", category: "MailMonitor")

    public weak var delegate: MailMonitorDelegate?

    /// Set the delegate (for use from MainActor contexts)
    public func setDelegate(_ delegate: MailMonitorDelegate?) {
        self.delegate = delegate
    }

    private var isRunning = false
    private var monitorTask: Task<Void, Never>?
    private var lastSeenMessageIds: Set<String> = []

    // Poll interval
    private let pollIntervalSeconds: UInt64 = 30 // Check every 30 seconds

    public init() {}

    // MARK: - Lifecycle

    public func start() async {
        guard !isRunning else {
            logger.warning("Mail monitor already running")
            return
        }

        // Get initial set of message IDs
        let existingIds = await getRecentMessageIds()
        lastSeenMessageIds = Set(existingIds)

        isRunning = true
        monitorTask = Task { [weak self] in
            await self?.monitorLoop()
        }

        logger.info("Mail monitor started (tracking \(self.lastSeenMessageIds.count) existing messages)")
    }

    public func stop() async {
        isRunning = false
        monitorTask?.cancel()
        monitorTask = nil
        logger.info("Mail monitor stopped")
    }

    // MARK: - Monitoring Loop

    private func monitorLoop() async {
        while isRunning && !Task.isCancelled {
            await checkForNewMail()
            do {
                try await Task.sleep(nanoseconds: pollIntervalSeconds * 1_000_000_000)
            } catch {
                break
            }
        }
    }

    private func checkForNewMail() async {
        // Get current message IDs
        let currentIds = await getRecentMessageIds()
        let currentSet = Set(currentIds)

        // Find new messages
        let newIds = currentSet.subtracting(lastSeenMessageIds)

        // Fetch details for new messages
        for messageId in newIds {
            if let email = await getEmailDetails(messageId: messageId) {
                delegate?.mailMonitor(self, didReceive: email)
            }
        }

        // Update tracking
        lastSeenMessageIds = currentSet
    }

    // MARK: - AppleScript Execution

    private func getRecentMessageIds() async -> [String] {
        let script = """
            tell application "Mail"
                set msgIds to {}
                try
                    set inboxMsgs to messages of inbox
                    repeat with i from 1 to min(100, count of inboxMsgs)
                        set end of msgIds to message id of item i of inboxMsgs
                    end repeat
                end try
                return msgIds
            end tell
            """

        guard let result = await executeAppleScript(script) else {
            return []
        }

        // Parse AppleScript list result
        return parseAppleScriptList(result)
    }

    private func getEmailDetails(messageId: String) async -> MailEvent? {
        let escapedId = messageId.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
            tell application "Mail"
                try
                    set msg to first message of inbox whose message id is "\(escapedId)"
                    set msgSender to sender of msg
                    set msgSubject to subject of msg
                    set msgDate to date received of msg
                    set msgRead to read status of msg
                    set msgContent to content of msg

                    -- Get first 500 chars of content
                    if length of msgContent > 500 then
                        set msgContent to text 1 thru 500 of msgContent
                    end if

                    return {msgSender, msgSubject, msgDate as string, msgRead, msgContent}
                on error
                    return {}
                end try
            end tell
            """

        guard let result = await executeAppleScript(script) else {
            return nil
        }

        return parseEmailResult(messageId: messageId, result: result)
    }

    private func executeAppleScript(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    let result = script.executeAndReturnError(&error)
                    if let error {
                        // Log but don't crash - Mail may not be running
                        let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                        print("[MailMonitor] AppleScript error: \(errorMessage)")
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: result.stringValue)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Parsing

    private func parseAppleScriptList(_ result: String) -> [String] {
        // AppleScript returns lists as "item1, item2, item3" or "{item1, item2}"
        let cleaned = result
            .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
            .replacingOccurrences(of: "\"", with: "")

        return cleaned
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func parseEmailResult(messageId: String, result: String) -> MailEvent? {
        // Parse the result tuple
        let components = parseAppleScriptList(result)

        guard components.count >= 4 else {
            return nil
        }

        let sender = components[0]
        let subject = components[1]
        let dateString = components[2]
        let isReadString = components[3]
        let content = components.count > 4 ? components[4] : ""

        // Parse date
        let date = parseAppleScriptDate(dateString) ?? Date()

        // Parse read status
        let isRead = isReadString.lowercased() == "true"

        // Determine importance
        let isImportant = determineImportance(sender: sender, subject: subject)

        return MailEvent(
            messageId: messageId,
            sender: extractEmailAddress(from: sender),
            senderName: extractSenderName(from: sender),
            subject: subject,
            preview: String(content.prefix(200)),
            receivedDate: date,
            isRead: isRead,
            isImportant: isImportant
        )
    }

    private func parseAppleScriptDate(_ dateString: String) -> Date? {
        // AppleScript date format varies by locale
        // Try common formats
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateStyle = .long
                f.timeStyle = .long
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    private func extractEmailAddress(from sender: String) -> String {
        // Format: "Name <email@example.com>" or just "email@example.com"
        if let start = sender.firstIndex(of: "<"),
           let end = sender.firstIndex(of: ">") {
            return String(sender[sender.index(after: start)..<end])
        }
        return sender
    }

    private func extractSenderName(from sender: String) -> String? {
        if let start = sender.firstIndex(of: "<") {
            let name = String(sender[..<start]).trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    private func determineImportance(sender _sender: String, subject: String) -> Bool {
        let lowercasedSubject = subject.lowercased()

        // Keywords that indicate importance
        let importantKeywords = [
            "urgent", "important", "action required", "asap",
            "deadline", "time sensitive", "priority"
        ]

        for keyword in importantKeywords {
            if lowercasedSubject.contains(keyword) {
                return true
            }
        }

        // Could also check sender against contacts marked as VIP
        // For now, just return false
        return false
    }

    // MARK: - Public Queries

    /// Get unread count
    public func getUnreadCount() async -> Int {
        let script = """
            tell application "Mail"
                return unread count of inbox
            end tell
            """

        guard let result = await executeAppleScript(script),
              let count = Int(result) else {
            return 0
        }

        return count
    }

    /// Get recent emails summary
    public func getRecentEmailsSummary(count: Int = 10) async -> [MailEvent] {
        var emails: [MailEvent] = []

        let ids = await getRecentMessageIds()
        for id in ids.prefix(count) {
            if let email = await getEmailDetails(messageId: id) {
                emails.append(email)
            }
        }

        return emails
    }
}

// MARK: - Mail Event

public struct MailEvent: Sendable {
    public let messageId: String
    public let sender: String
    public let senderName: String?
    public let subject: String
    public let preview: String
    public let receivedDate: Date
    public let isRead: Bool
    public let isImportant: Bool

    public var displaySender: String {
        senderName ?? sender
    }

    public var domain: String {
        guard let atIndex = sender.firstIndex(of: "@") else { return sender }
        return String(sender[sender.index(after: atIndex)...])
    }
}

#endif
