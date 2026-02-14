//
//  SessionChatService.swift
//  Thea
//
//  In-session text chat for remote desktop support sessions
//

import Combine
import Foundation

// MARK: - Session Chat Service

/// Manages text messaging during active remote desktop sessions
@MainActor
public class SessionChatService: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var messages: [ChatMessageData] = []
    @Published public private(set) var unreadCount: Int = 0
    @Published public private(set) var isActive = false

    // MARK: - Callbacks

    public var onMessageReceived: ((ChatMessageData) -> Void)?
    public var onSendMessage: ((ChatMessageData) -> Void)?

    // MARK: - Configuration

    public var maxMessageHistory: Int = 500
    public var localUserId: String = ""
    public var localUserName: String = ""

    // MARK: - Initialization

    public init() {}

    // MARK: - Session Lifecycle

    /// Start chat for a new session
    public func startSession(localUserId: String, localUserName: String) {
        self.localUserId = localUserId
        self.localUserName = localUserName
        messages.removeAll()
        unreadCount = 0
        isActive = true
    }

    /// End the chat session
    public func endSession() {
        isActive = false
    }

    // MARK: - Send Message

    /// Send a text message
    public func sendMessage(_ text: String) {
        guard isActive, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let message = ChatMessageData(
            senderId: localUserId,
            senderName: localUserName,
            text: text
        )

        messages.append(message)
        trimHistory()

        onSendMessage?(message)
    }

    // MARK: - Receive Message

    /// Handle a received message from remote
    public func receiveMessage(_ message: ChatMessageData) {
        messages.append(message)
        trimHistory()

        unreadCount += 1
        onMessageReceived?(message)
    }

    // MARK: - Read Status

    /// Mark all messages as read
    public func markAllAsRead() {
        unreadCount = 0
    }

    // MARK: - Clear

    /// Clear chat history
    public func clearHistory() {
        messages.removeAll()
        unreadCount = 0
    }

    // MARK: - Export

    /// Export chat history as plain text
    public func exportAsText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        return messages.map { msg in
            "[\(formatter.string(from: msg.timestamp))] \(msg.senderName): \(msg.text)"
        }.joined(separator: "\n")
    }

    // MARK: - Private

    private func trimHistory() {
        if messages.count > maxMessageHistory {
            messages.removeFirst(messages.count - maxMessageHistory)
        }
    }
}
