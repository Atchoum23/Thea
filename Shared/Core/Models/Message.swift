import Foundation
import OSLog
@preconcurrency import SwiftData

/// Shared JSON coders to avoid repeated instantiation in computed properties.
/// JSONDecoder/JSONEncoder are reference types and thread-safe for concurrent reads.
private let sharedDecoder = JSONDecoder()
private let sharedEncoder = JSONEncoder()
private let messageLogger = Logger(subsystem: "com.thea.app", category: "Message")

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID
    var role: String // "user", "assistant", "system"
    var contentData: Data // Encoded MessageContent
    var timestamp: Date
    var model: String?
    var tokenCount: Int?
    var metadataData: Data? // Encoded MessageMetadata

    /// Order index for deterministic message sorting within a conversation
    /// This ensures messages appear in correct chronological order even when
    /// timestamps might be identical (e.g., rapid message creation)
    var orderIndex: Int = 0

    // MARK: - Device Origin

    /// Unique device identifier that created this message (from DeviceRegistry)
    var deviceID: String?

    /// Human-readable name of the originating device (e.g. "Mac Studio", "Alexis's iPhone")
    var deviceName: String?

    /// Device type string for the originating device (e.g. "mac", "iPhone", "iPad")
    var deviceType: String?

    // MARK: - Branching Support

    /// ID of the parent message this was branched from (nil for original messages)
    var parentMessageId: UUID?

    /// Branch index (0 = original/main branch, 1+ = alternative branches)
    var branchIndex: Int = 0

    /// Whether this message was edited to create a branch
    var isEdited: Bool = false

    /// Original content before editing (for showing "edited" indicator)
    var originalContentData: Data?

    @Relationship var conversation: Conversation?

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: MessageRole,
        content: MessageContent,
        timestamp: Date = Date(),
        model: String? = nil,
        tokenCount: Int? = nil,
        metadata: MessageMetadata? = nil,
        orderIndex: Int = 0,
        parentMessageId: UUID? = nil,
        branchIndex: Int = 0,
        deviceID: String? = nil,
        deviceName: String? = nil,
        deviceType: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role.rawValue
        do {
            contentData = try sharedEncoder.encode(content)
        } catch {
            messageLogger.error("Failed to encode message content: \(error.localizedDescription)")
            contentData = Data()
        }
        self.timestamp = timestamp
        self.model = model
        self.tokenCount = tokenCount
        if let metadata {
            do {
                metadataData = try sharedEncoder.encode(metadata)
            } catch {
                messageLogger.error("Failed to encode message metadata: \(error.localizedDescription)")
                metadataData = nil
            }
        } else {
            metadataData = nil
        }
        self.orderIndex = orderIndex
        self.parentMessageId = parentMessageId
        self.branchIndex = branchIndex
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceType = deviceType
    }

    // Computed properties for easy access
    var messageRole: MessageRole {
        MessageRole(rawValue: role) ?? .user
    }

    var content: MessageContent {
        do {
            return try sharedDecoder.decode(MessageContent.self, from: contentData)
        } catch {
            messageLogger.error("Failed to decode message content: \(error.localizedDescription)")
            return .text("")
        }
    }

    var metadata: MessageMetadata? {
        guard let data = metadataData else { return nil }
        do {
            return try sharedDecoder.decode(MessageMetadata.self, from: data)
        } catch {
            messageLogger.error("Failed to decode message metadata: \(error.localizedDescription)")
            return nil
        }
    }

    #if !THEA_MODELS_ONLY
    /// The parsed device type for this message's origin device
    var originDeviceType: DeviceType? {
        guard let raw = deviceType else { return nil }
        return DeviceType(rawValue: raw)
    }

    /// SF Symbol name for this message's origin device
    var deviceIcon: String? {
        originDeviceType?.icon
    }

    /// Stamps the current device identity onto this message
    @MainActor
    func stampCurrentDevice() {
        let device = DeviceRegistry.shared.currentDevice
        deviceID = device.id
        deviceName = device.name
        deviceType = device.type.rawValue
    }
    #endif

    /// Original content if this message was edited
    var originalContent: MessageContent? {
        guard let data = originalContentData else { return nil }
        do {
            return try sharedDecoder.decode(MessageContent.self, from: data)
        } catch {
            messageLogger.error("Failed to decode original message content: \(error.localizedDescription)")
            return nil
        }
    }

    /// Create an edited version of this message (for branching)
    func createBranch(newContent: MessageContent, branchIndex: Int) -> Message {
        let branchedMessage = Message(
            conversationID: conversationID,
            role: messageRole,
            content: newContent,
            model: model,
            tokenCount: nil,
            metadata: nil,
            orderIndex: orderIndex,
            parentMessageId: id,
            branchIndex: branchIndex,
            deviceID: deviceID,
            deviceName: deviceName,
            deviceType: deviceType
        )
        branchedMessage.isEdited = true
        branchedMessage.originalContentData = contentData
        return branchedMessage
    }
}

// MARK: - Message Role

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

// MARK: - Message Content

enum MessageContent: Codable, Sendable {
    case text(String)
    case multimodal([ContentPart])

    var textValue: String {
        switch self {
        case let .text(string):
            string
        case let .multimodal(parts):
            parts.compactMap { part in
                if case let .text(text) = part.type {
                    return text
                }
                return nil
            }.joined(separator: "\n")
        }
    }
}

struct ContentPart: Codable, Sendable {
    enum PartType: Codable, Sendable {
        case text(String)
        case image(Data)
        case file(String) // File path
    }

    let type: PartType
}

// MARK: - Message Metadata

struct MessageMetadata: Codable, Sendable {
    var finishReason: String?
    var systemFingerprint: String?
    var cachedTokens: Int?
    var reasoningTokens: Int?

    // Device context captured at generation time (for assistant messages)
    var respondingDeviceID: String?
    var respondingDeviceName: String?
    var respondingDeviceType: String?

    // Verification confidence score (0.0-1.0) from ConfidenceSystem
    var confidence: Double?

    // Hallucination detection flags from ConfidenceSystem.detectHallucinations
    var hallucinationFlags: [String]?

    // Token usage (input tokens counted before send, output tokens from response)
    var inputTokens: Int?

    // Follow-up suggestions generated after AI response
    var followUpSuggestions: [FollowUpSuggestion]?

    /// Raw Anthropic content blocks (JSON-encoded `[[String: Any]]`) for assistant messages
    /// that contain extended thinking. The Anthropic API requires these blocks to be passed
    /// back verbatim in subsequent turns — they must never be stripped or replaced with
    /// plain text when thinking was active. Nil for messages without thinking blocks.
    var rawContentBlocksData: Data?

    init(
        finishReason: String? = nil,
        systemFingerprint: String? = nil,
        cachedTokens: Int? = nil,
        reasoningTokens: Int? = nil,
        respondingDeviceID: String? = nil,
        respondingDeviceName: String? = nil,
        respondingDeviceType: String? = nil,
        confidence: Double? = nil,
        inputTokens: Int? = nil,
        followUpSuggestions: [FollowUpSuggestion]? = nil,
        rawContentBlocksData: Data? = nil
    ) {
        self.finishReason = finishReason
        self.systemFingerprint = systemFingerprint
        self.cachedTokens = cachedTokens
        self.reasoningTokens = reasoningTokens
        self.respondingDeviceID = respondingDeviceID
        self.respondingDeviceName = respondingDeviceName
        self.respondingDeviceType = respondingDeviceType
        self.confidence = confidence
        self.inputTokens = inputTokens
        self.followUpSuggestions = followUpSuggestions
        self.rawContentBlocksData = rawContentBlocksData
    }
}

// MARK: - Follow-Up Suggestion Types

struct FollowUpSuggestion: Codable, Sendable, Identifiable {
    let id: UUID
    let text: String
    let icon: String
    let source: SuggestionGenerationSource

    init(text: String, icon: String = "arrow.turn.down.right", source: SuggestionGenerationSource = .heuristic) {
        self.id = UUID()
        self.text = text
        self.icon = icon
        self.source = source
    }
}

enum SuggestionGenerationSource: String, Codable, Sendable {
    case heuristic
    case ai
    case learnedPattern
}

// MARK: - Identifiable

extension Message: Identifiable {}
