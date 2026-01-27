//
//  TheaSharePlay.swift
//  Thea
//
//  SharePlay support for collaborative AI sessions
//

import Combine
import Foundation
import GroupActivities
#if canImport(UIKit)
    import UIKit
#endif
#if os(macOS)
    import AppKit
#endif

// MARK: - Thea Group Activity

/// SharePlay activity for collaborative AI sessions
public struct TheaGroupActivity: GroupActivity {
    public static let activityIdentifier = "app.thea.shareplay"

    public var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Thea AI Session"
        metadata.subtitle = sessionDescription
        metadata.type = .generic
        metadata.previewImage = nil // Could add app icon
        metadata.fallbackURL = URL(string: "https://theathe.app")
        return metadata
    }

    public let sessionId: String
    public let sessionDescription: String
    public let hostName: String

    public init(sessionId: String = UUID().uuidString, sessionDescription: String = "Collaborative AI Session", hostName: String) {
        self.sessionId = sessionId
        self.sessionDescription = sessionDescription
        self.hostName = hostName
    }
}

// MARK: - SharePlay Message Types

/// Messages exchanged during SharePlay sessions
public enum SharePlayMessage: Codable, Sendable {
    case chatMessage(ChatContent)
    case aiResponse(AIResponseContent)
    case typing(TypingIndicator)
    case reaction(Reaction)
    case syncRequest
    case syncResponse(SyncData)
    case participantJoined(ParticipantInfo)
    case participantLeft(String)

    public struct ChatContent: Codable, Sendable {
        public let id: String
        public let senderId: String
        public let senderName: String
        public let text: String
        public let timestamp: Date

        public init(id: String = UUID().uuidString, senderId: String, senderName: String, text: String, timestamp: Date = Date()) {
            self.id = id
            self.senderId = senderId
            self.senderName = senderName
            self.text = text
            self.timestamp = timestamp
        }
    }

    public struct AIResponseContent: Codable, Sendable {
        public let id: String
        public let promptId: String
        public let response: String
        public let isComplete: Bool
        public let timestamp: Date

        public init(id: String = UUID().uuidString, promptId: String, response: String, isComplete: Bool, timestamp: Date = Date()) {
            self.id = id
            self.promptId = promptId
            self.response = response
            self.isComplete = isComplete
            self.timestamp = timestamp
        }
    }

    public struct TypingIndicator: Codable, Sendable {
        public let participantId: String
        public let participantName: String
        public let isTyping: Bool

        public init(participantId: String, participantName: String, isTyping: Bool) {
            self.participantId = participantId
            self.participantName = participantName
            self.isTyping = isTyping
        }
    }

    public struct Reaction: Codable, Sendable {
        public let participantId: String
        public let messageId: String
        public let emoji: String

        public init(participantId: String, messageId: String, emoji: String) {
            self.participantId = participantId
            self.messageId = messageId
            self.emoji = emoji
        }
    }

    public struct SyncData: Codable, Sendable {
        public let messages: [ChatContent]
        public let aiResponses: [AIResponseContent]
        public let conversationTitle: String

        public init(messages: [ChatContent], aiResponses: [AIResponseContent], conversationTitle: String) {
            self.messages = messages
            self.aiResponses = aiResponses
            self.conversationTitle = conversationTitle
        }
    }

    public struct ParticipantInfo: Codable, Sendable {
        public let id: String
        public let name: String
        public let deviceType: String

        public init(id: String, name: String, deviceType: String) {
            self.id = id
            self.name = name
            self.deviceType = deviceType
        }
    }
}

// MARK: - SharePlay Manager

@MainActor
public class TheaSharePlayManager: ObservableObject {
    public static let shared = TheaSharePlayManager()

    // MARK: - Published State

    @Published public private(set) var isSessionActive = false
    @Published public private(set) var isHost = false
    @Published public private(set) var participants: [SharePlayParticipant] = []
    @Published public private(set) var sharedMessages: [SharePlayMessage.ChatContent] = []
    @Published public private(set) var sharedAIResponses: [SharePlayMessage.AIResponseContent] = []
    @Published public private(set) var typingParticipants: Set<String> = []

    // MARK: - Private Properties

    private var groupSession: GroupSession<TheaGroupActivity>?
    private var messenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    private var tasks = Set<Task<Void, Never>>()

    // MARK: - Participant Info

    private var localParticipantId: String {
        #if os(macOS)
            return Host.current().localizedName ?? UUID().uuidString
        #elseif os(iOS)
            return UIDevice.current.name
        #else
            return UUID().uuidString
        #endif
    }

    private var localDeviceType: String {
        #if os(macOS)
            return "Mac"
        #elseif os(iOS)
            return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #elseif os(watchOS)
            return "Apple Watch"
        #elseif os(tvOS)
            return "Apple TV"
        #else
            return "Unknown"
        #endif
    }

    // MARK: - Initialization

    private init() {
        setupGroupActivityObserver()
    }

    // MARK: - Activity Observer

    nonisolated private func setupGroupActivityObserver() {
        Task { @MainActor [weak self] in
            for await session in TheaGroupActivity.sessions() {
                await self?.configureGroupSession(session)
            }
        }
    }

    // MARK: - Session Management

    /// Start a new SharePlay session
    public func startSession(description: String = "Collaborative AI Session") async throws {
        let activity = TheaGroupActivity(
            sessionDescription: description,
            hostName: localParticipantId
        )

        let result = await activity.prepareForActivation()

        switch result {
        case .activationDisabled:
            throw SharePlayError.activationDisabled
        case .activationPreferred:
            _ = try await activity.activate()
        case .cancelled:
            throw SharePlayError.cancelled
        @unknown default:
            break
        }
    }

    /// Leave the current SharePlay session
    public func leaveSession() {
        groupSession?.leave()
        resetState()
    }

    /// End the SharePlay session for all participants
    public func endSession() {
        groupSession?.end()
        resetState()
    }

    private func resetState() {
        groupSession = nil
        messenger = nil
        isSessionActive = false
        isHost = false
        participants = []
        sharedMessages = []
        sharedAIResponses = []
        typingParticipants = []
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    // MARK: - Configure Session

    @MainActor
    private func configureGroupSession(_ session: GroupSession<TheaGroupActivity>) async {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)
        isHost = session.activity.hostName == localParticipantId

        // Observe session state
        session.$state
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.handleSessionState(state)
                }
            }
            .store(in: &subscriptions)

        // Observe participants
        session.$activeParticipants
            .sink { [weak self] activeParticipants in
                Task { @MainActor in
                    self?.updateParticipants(activeParticipants)
                }
            }
            .store(in: &subscriptions)

        // Start receiving messages
        startReceivingMessages()

        // Join the session
        session.join()

        // Announce presence
        await sendMessage(.participantJoined(SharePlayMessage.ParticipantInfo(
            id: localParticipantId,
            name: localParticipantId,
            deviceType: localDeviceType
        )))

        // Request sync if not host
        if !isHost {
            await sendMessage(.syncRequest)
        }
    }

    private func handleSessionState(_ state: GroupSession<TheaGroupActivity>.State) {
        switch state {
        case .waiting:
            isSessionActive = false
        case .joined:
            isSessionActive = true
        case .invalidated:
            resetState()
        @unknown default:
            break
        }
    }

    private func updateParticipants(_ activeParticipants: Set<GroupActivities.Participant>) {
        participants = activeParticipants.map { participant in
            SharePlayParticipant(
                id: participant.id.hashValue.description,
                isLocal: participant == groupSession?.localParticipant
            )
        }
    }

    // MARK: - Message Handling

    private func startReceivingMessages() {
        guard let messenger else { return }

        let task = Task {
            for await (message, _) in messenger.messages(of: SharePlayMessage.self) {
                await handleMessage(message)
            }
        }
        tasks.insert(task)
    }

    private func handleMessage(_ message: SharePlayMessage) async {
        switch message {
        case let .chatMessage(content):
            sharedMessages.append(content)

        case let .aiResponse(content):
            if let index = sharedAIResponses.firstIndex(where: { $0.promptId == content.promptId }) {
                sharedAIResponses[index] = content
            } else {
                sharedAIResponses.append(content)
            }

        case let .typing(indicator):
            if indicator.isTyping {
                typingParticipants.insert(indicator.participantName)
            } else {
                typingParticipants.remove(indicator.participantName)
            }

        case .reaction:
            // Handle reaction (could update message reactions)
            return

        case .syncRequest:
            if isHost {
                await sendSyncData()
            }

        case let .syncResponse(data):
            sharedMessages = data.messages
            sharedAIResponses = data.aiResponses

        case .participantJoined:
            // Could show notification
            return

        case .participantLeft:
            // Could show notification
            return
        }
    }

    // MARK: - Send Messages

    /// Send a chat message to all participants
    public func sendChatMessage(_ text: String) async {
        let content = SharePlayMessage.ChatContent(
            senderId: localParticipantId,
            senderName: localParticipantId,
            text: text
        )

        sharedMessages.append(content)
        await sendMessage(.chatMessage(content))
    }

    /// Share an AI response with all participants
    public func shareAIResponse(promptId: String, response: String, isComplete: Bool) async {
        let content = SharePlayMessage.AIResponseContent(
            promptId: promptId,
            response: response,
            isComplete: isComplete
        )

        if let index = sharedAIResponses.firstIndex(where: { $0.promptId == promptId }) {
            sharedAIResponses[index] = content
        } else {
            sharedAIResponses.append(content)
        }

        await sendMessage(.aiResponse(content))
    }

    /// Send typing indicator
    public func sendTypingIndicator(_ isTyping: Bool) async {
        let indicator = SharePlayMessage.TypingIndicator(
            participantId: localParticipantId,
            participantName: localParticipantId,
            isTyping: isTyping
        )
        await sendMessage(.typing(indicator))
    }

    /// Send reaction to a message
    public func sendReaction(to messageId: String, emoji: String) async {
        let reaction = SharePlayMessage.Reaction(
            participantId: localParticipantId,
            messageId: messageId,
            emoji: emoji
        )
        await sendMessage(.reaction(reaction))
    }

    private func sendSyncData() async {
        let data = SharePlayMessage.SyncData(
            messages: sharedMessages,
            aiResponses: sharedAIResponses,
            conversationTitle: "Shared Session"
        )
        await sendMessage(.syncResponse(data))
    }

    private func sendMessage(_ message: SharePlayMessage) async {
        guard let messenger else { return }

        do {
            try await messenger.send(message)
        } catch {
            print("Failed to send SharePlay message: \(error)")
        }
    }
}

// MARK: - Participant

public struct SharePlayParticipant: Identifiable, Sendable {
    public let id: String
    public let isLocal: Bool

    public init(id: String, isLocal: Bool) {
        self.id = id
        self.isLocal = isLocal
    }
}

// MARK: - Errors

public enum SharePlayError: Error, LocalizedError {
    case activationDisabled
    case cancelled
    case notInSession
    case messageFailed

    public var errorDescription: String? {
        switch self {
        case .activationDisabled:
            "SharePlay is not available. Make sure you're on a FaceTime call."
        case .cancelled:
            "SharePlay session was cancelled"
        case .notInSession:
            "Not currently in a SharePlay session"
        case .messageFailed:
            "Failed to send message to participants"
        }
    }
}
