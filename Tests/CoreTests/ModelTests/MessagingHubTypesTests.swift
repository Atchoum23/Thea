// MessagingHubTypesTests.swift
// Tests for MessagingHub types, channel management, and message routing

import Testing
import Foundation

// MARK: - Test Doubles

private struct TestUnifiedMessage: Codable, Sendable {
    let id: UUID
    let channelType: TestChannelType
    let channelID: String
    let senderID: String
    let senderName: String?
    let content: String
    let timestamp: Date
    let isFromUser: Bool
    let isFromBot: Bool
    let replyToMessageID: String?
    let attachments: [TestAttachment]
    let metadata: [String: String]

    init(
        channelType: TestChannelType = .iMessage,
        channelID: String = "ch-1",
        senderID: String = "user-1",
        senderName: String? = nil,
        content: String = "Hello",
        timestamp: Date = Date(),
        isFromUser: Bool = false,
        isFromBot: Bool = false,
        replyToMessageID: String? = nil,
        attachments: [TestAttachment] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.channelType = channelType
        self.channelID = channelID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.isFromUser = isFromUser
        self.isFromBot = isFromBot
        self.replyToMessageID = replyToMessageID
        self.attachments = attachments
        self.metadata = metadata
    }
}

private struct TestAttachment: Codable, Sendable {
    let id: UUID
    let type: TestAttachmentType
    let url: String?
    let mimeType: String?
    let fileName: String?
    let sizeBytes: Int?

    enum TestAttachmentType: String, Codable, Sendable, CaseIterable {
        case image, audio, video, document, voiceNote, sticker, location, contact
    }

    init(type: TestAttachmentType, url: String? = nil, mimeType: String? = nil,
         fileName: String? = nil, sizeBytes: Int? = nil) {
        self.id = UUID()
        self.type = type
        self.url = url
        self.mimeType = mimeType
        self.fileName = fileName
        self.sizeBytes = sizeBytes
    }
}

private enum TestChannelType: String, Codable, Sendable, CaseIterable {
    case iMessage, whatsApp, telegram, discord, slack, signal, email, notification, phoneCall, physicalMail

    var displayName: String {
        switch self {
        case .iMessage: "iMessage"
        case .whatsApp: "WhatsApp"
        case .telegram: "Telegram"
        case .discord: "Discord"
        case .slack: "Slack"
        case .signal: "Signal"
        case .email: "Email"
        case .notification: "Notifications"
        case .phoneCall: "Phone Calls"
        case .physicalMail: "Physical Mail"
        }
    }

    var icon: String {
        switch self {
        case .iMessage: "message.fill"
        case .whatsApp: "phone.circle.fill"
        case .telegram: "paperplane.fill"
        case .discord: "headphones"
        case .slack: "number.square.fill"
        case .signal: "lock.fill"
        case .email: "envelope.fill"
        case .notification: "bell.fill"
        case .phoneCall: "phone.fill"
        case .physicalMail: "doc.text.fill"
        }
    }

    var usesBridge: Bool {
        switch self {
        case .whatsApp, .telegram, .discord, .slack, .signal: true
        case .iMessage, .email, .notification, .phoneCall, .physicalMail: false
        }
    }
}

private enum TestChannelStatus: String, Codable, Sendable {
    case connected, disconnected, connecting, error, disabled

    var isActive: Bool { self == .connected }
}

private struct TestRegisteredChannel: Codable, Sendable {
    let id: UUID
    let type: TestChannelType
    let name: String
    var status: TestChannelStatus
    var lastActivityAt: Date?
    var unreadCount: Int
    var isEnabled: Bool
    var autoReplyEnabled: Bool

    init(type: TestChannelType, name: String, status: TestChannelStatus = .disconnected,
         isEnabled: Bool = true, autoReplyEnabled: Bool = false) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.status = status
        self.lastActivityAt = nil
        self.unreadCount = 0
        self.isEnabled = isEnabled
        self.autoReplyEnabled = autoReplyEnabled
    }
}

private enum TestMsgIntent: String, Codable, Sendable, CaseIterable {
    case question, request, informational, socialGreeting, confirmation
    case scheduling, urgent, complaint, followUp

    var requiresResponse: Bool {
        switch self {
        case .question, .request, .scheduling, .urgent, .complaint: true
        case .informational, .socialGreeting, .confirmation, .followUp: false
        }
    }
}

private enum TestMsgUrgency: String, Codable, Sendable, CaseIterable, Comparable {
    case low, normal, high, critical

    var numericValue: Int {
        switch self {
        case .low: 0
        case .normal: 1
        case .high: 2
        case .critical: 3
        }
    }

    static func < (lhs: TestMsgUrgency, rhs: TestMsgUrgency) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}

private enum TestMsgAction: String, Codable, Sendable, CaseIterable {
    case reply, createCalendarEvent, setReminder, makePayment, openLink
    case callBack, forward, archive, trackPackage, reviewDocument

    var displayName: String {
        switch self {
        case .reply: "Reply"
        case .createCalendarEvent: "Create Event"
        case .setReminder: "Set Reminder"
        case .makePayment: "Make Payment"
        case .openLink: "Open Link"
        case .callBack: "Call Back"
        case .forward: "Forward"
        case .archive: "Archive"
        case .trackPackage: "Track Package"
        case .reviewDocument: "Review Document"
        }
    }
}

private enum TestMsgSentiment: String, Codable, Sendable, CaseIterable {
    case positive, neutral, negative, mixed
}

private struct TestMsgEntity: Codable, Sendable {
    let id: UUID
    let type: EntityType
    let value: String
    let confidence: Double

    enum EntityType: String, Codable, Sendable, CaseIterable {
        case person, organization, date, time, location
        case phoneNumber, email, url, amount, trackingNumber
    }

    init(type: EntityType, value: String, confidence: Double = 1.0) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.confidence = min(max(confidence, 0), 1)
    }
}

private struct TestMsgComprehension: Codable, Sendable {
    let intent: TestMsgIntent
    let urgency: TestMsgUrgency
    let requiredAction: TestMsgAction?
    let entities: [TestMsgEntity]
    let sentiment: TestMsgSentiment
    let summary: String?
    let suggestedResponse: String?
}

// Detection logic tests are in MsgComprehensionLogicTests.swift

// MARK: - Tests: MessagingChannelType

@Suite("MessagingChannelType — Enum Properties")
struct ChannelTypeTests {
    @Test("All 10 channel types exist")
    func allCases() {
        #expect(TestChannelType.allCases.count == 10)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestChannelType.allCases.map(\.rawValue))
        #expect(rawValues.count == TestChannelType.allCases.count)
    }

    @Test("Display names are non-empty")
    func displayNames() {
        for channel in TestChannelType.allCases {
            #expect(!channel.displayName.isEmpty)
        }
    }

    @Test("Icons are non-empty")
    func icons() {
        for channel in TestChannelType.allCases {
            #expect(!channel.icon.isEmpty)
        }
    }

    @Test("Bridge channels are WhatsApp, Telegram, Discord, Slack, Signal")
    func bridgeChannels() {
        let bridged = TestChannelType.allCases.filter(\.usesBridge)
        #expect(bridged.count == 5)
        #expect(bridged.contains(.whatsApp))
        #expect(bridged.contains(.telegram))
        #expect(bridged.contains(.discord))
        #expect(bridged.contains(.slack))
        #expect(bridged.contains(.signal))
    }

    @Test("Native channels are iMessage, Email, Notification, PhoneCall, PhysicalMail")
    func nativeChannels() {
        let native = TestChannelType.allCases.filter { !$0.usesBridge }
        #expect(native.count == 5)
        #expect(native.contains(.iMessage))
        #expect(native.contains(.email))
        #expect(native.contains(.notification))
        #expect(native.contains(.phoneCall))
        #expect(native.contains(.physicalMail))
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for channel in TestChannelType.allCases {
            let data = try JSONEncoder().encode(channel)
            let decoded = try JSONDecoder().decode(TestChannelType.self, from: data)
            #expect(decoded == channel)
        }
    }
}

// MARK: - Tests: MessagingChannelStatus

@Suite("MessagingChannelStatus — Status Properties")
struct ChannelStatusTests {
    @Test("Only connected is active")
    func isActive() {
        #expect(TestChannelStatus.connected.isActive)
        #expect(!TestChannelStatus.disconnected.isActive)
        #expect(!TestChannelStatus.connecting.isActive)
        #expect(!TestChannelStatus.error.isActive)
        #expect(!TestChannelStatus.disabled.isActive)
    }
}

// MARK: - Tests: RegisteredChannel

@Suite("RegisteredChannel — Channel Registration")
struct RegisteredChannelTests {
    @Test("Default values")
    func defaults() {
        let ch = TestRegisteredChannel(type: .iMessage, name: "Main")
        #expect(ch.status == .disconnected)
        #expect(ch.isEnabled == true)
        #expect(ch.autoReplyEnabled == false)
        #expect(ch.unreadCount == 0)
        #expect(ch.lastActivityAt == nil)
    }

    @Test("Custom values")
    func custom() {
        let ch = TestRegisteredChannel(type: .whatsApp, name: "WhatsApp Business",
                                       status: .connected, isEnabled: false, autoReplyEnabled: true)
        #expect(ch.type == .whatsApp)
        #expect(ch.name == "WhatsApp Business")
        #expect(ch.status == .connected)
        #expect(!ch.isEnabled)
        #expect(ch.autoReplyEnabled)
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let ch1 = TestRegisteredChannel(type: .telegram, name: "A")
        let ch2 = TestRegisteredChannel(type: .telegram, name: "B")
        #expect(ch1.id != ch2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var ch = TestRegisteredChannel(type: .slack, name: "Work", status: .connected)
        ch.unreadCount = 5
        ch.lastActivityAt = Date()
        let data = try JSONEncoder().encode(ch)
        let decoded = try JSONDecoder().decode(TestRegisteredChannel.self, from: data)
        #expect(decoded.type == .slack)
        #expect(decoded.name == "Work")
        #expect(decoded.unreadCount == 5)
    }
}

// MARK: - Tests: UnifiedMessage

@Suite("UnifiedMessage — Message Creation")
struct UnifiedMessageTests {
    @Test("Default values")
    func defaults() {
        let msg = TestUnifiedMessage(content: "Test")
        #expect(msg.channelType == .iMessage)
        #expect(msg.content == "Test")
        #expect(!msg.isFromUser)
        #expect(!msg.isFromBot)
        #expect(msg.replyToMessageID == nil)
        #expect(msg.attachments.isEmpty)
        #expect(msg.metadata.isEmpty)
    }

    @Test("Full construction")
    func fullConstruction() {
        let att = TestAttachment(type: .image, url: "https://example.com/photo.jpg", mimeType: "image/jpeg")
        let msg = TestUnifiedMessage(
            channelType: .whatsApp,
            channelID: "chat-123",
            senderID: "sender-456",
            senderName: "Alice",
            content: "Check this photo",
            isFromUser: true,
            replyToMessageID: "msg-789",
            attachments: [att],
            metadata: ["thread_id": "t1"]
        )
        #expect(msg.channelType == .whatsApp)
        #expect(msg.senderName == "Alice")
        #expect(msg.isFromUser)
        #expect(msg.attachments.count == 1)
        #expect(msg.metadata["thread_id"] == "t1")
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let msg1 = TestUnifiedMessage()
        let msg2 = TestUnifiedMessage()
        #expect(msg1.id != msg2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let msg = TestUnifiedMessage(
            channelType: .telegram,
            senderName: "Bob",
            content: "Hello world",
            isFromBot: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(msg)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestUnifiedMessage.self, from: data)
        #expect(decoded.channelType == .telegram)
        #expect(decoded.senderName == "Bob")
        #expect(decoded.content == "Hello world")
        #expect(decoded.isFromBot)
    }
}

// MARK: - Tests: UnifiedAttachment

@Suite("UnifiedAttachment — Attachment Types")
struct AttachmentTests {
    @Test("All 8 attachment types exist")
    func allCases() {
        #expect(TestAttachment.TestAttachmentType.allCases.count == 8)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestAttachment.TestAttachmentType.allCases.map(\.rawValue))
        #expect(rawValues.count == 8)
    }

    @Test("Default nil properties")
    func defaults() {
        let att = TestAttachment(type: .document)
        #expect(att.url == nil)
        #expect(att.mimeType == nil)
        #expect(att.fileName == nil)
        #expect(att.sizeBytes == nil)
    }

    @Test("Full construction")
    func full() {
        let att = TestAttachment(type: .video, url: "https://example.com/v.mp4",
                                 mimeType: "video/mp4", fileName: "video.mp4", sizeBytes: 1048576)
        #expect(att.type == .video)
        #expect(att.url == "https://example.com/v.mp4")
        #expect(att.sizeBytes == 1048576)
    }
}

// MARK: - Tests: MsgIntent

@Suite("MsgIntent — Intent Properties")
struct IntentTests {
    @Test("All 9 intents exist")
    func allCases() {
        #expect(TestMsgIntent.allCases.count == 9)
    }

    @Test("Intents that require response")
    func requiresResponse() {
        let responding = TestMsgIntent.allCases.filter(\.requiresResponse)
        #expect(responding.count == 5)
        #expect(responding.contains(.question))
        #expect(responding.contains(.request))
        #expect(responding.contains(.scheduling))
        #expect(responding.contains(.urgent))
        #expect(responding.contains(.complaint))
    }

    @Test("Intents that don't require response")
    func noResponse() {
        let silent = TestMsgIntent.allCases.filter { !$0.requiresResponse }
        #expect(silent.count == 4)
        #expect(silent.contains(.informational))
        #expect(silent.contains(.socialGreeting))
        #expect(silent.contains(.confirmation))
        #expect(silent.contains(.followUp))
    }
}

// MARK: - Tests: MsgUrgency

@Suite("MsgUrgency — Urgency Ordering")
struct UrgencyTests {
    @Test("Numeric values ascending")
    func numericValues() {
        #expect(TestMsgUrgency.low.numericValue == 0)
        #expect(TestMsgUrgency.normal.numericValue == 1)
        #expect(TestMsgUrgency.high.numericValue == 2)
        #expect(TestMsgUrgency.critical.numericValue == 3)
    }

    @Test("Comparable ordering")
    func ordering() {
        #expect(TestMsgUrgency.low < .normal)
        #expect(TestMsgUrgency.normal < .high)
        #expect(TestMsgUrgency.high < .critical)
        #expect(!(TestMsgUrgency.critical < .low))
    }

    @Test("Sorting")
    func sorting() {
        let urgencies: [TestMsgUrgency] = [.critical, .low, .high, .normal]
        let sorted = urgencies.sorted()
        #expect(sorted == [.low, .normal, .high, .critical])
    }
}

// MARK: - Tests: MsgAction

@Suite("MsgAction — Action Types")
struct ActionTests {
    @Test("All 10 actions exist")
    func allCases() {
        #expect(TestMsgAction.allCases.count == 10)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestMsgAction.allCases.map(\.rawValue))
        #expect(rawValues.count == 10)
    }

    @Test("Non-empty display names")
    func displayNames() {
        for action in TestMsgAction.allCases {
            #expect(!action.displayName.isEmpty)
        }
    }
}

// MARK: - Tests: MsgEntity

@Suite("MsgEntity — Entity Extraction Types")
struct EntityTests {
    @Test("All 10 entity types exist")
    func allCases() {
        #expect(TestMsgEntity.EntityType.allCases.count == 10)
    }

    @Test("Confidence clamped to 0-1")
    func confidenceClamped() {
        let over = TestMsgEntity(type: .person, value: "Alice", confidence: 1.5)
        #expect(over.confidence == 1.0)
        let under = TestMsgEntity(type: .person, value: "Bob", confidence: -0.5)
        #expect(under.confidence == 0.0)
    }

    @Test("Default confidence is 1.0")
    func defaultConfidence() {
        let entity = TestMsgEntity(type: .email, value: "test@example.com")
        #expect(entity.confidence == 1.0)
    }

    @Test("Unique IDs")
    func uniqueIDs() {
        let e1 = TestMsgEntity(type: .url, value: "https://example.com")
        let e2 = TestMsgEntity(type: .url, value: "https://example.com")
        #expect(e1.id != e2.id)
    }
}

// MARK: - Tests: MsgComprehension

@Suite("MsgComprehension — Comprehension Result")
struct ComprehensionTests {
    @Test("Default values")
    func defaults() {
        let comp = TestMsgComprehension(
            intent: .informational,
            urgency: .normal,
            requiredAction: nil,
            entities: [],
            sentiment: .neutral,
            summary: nil,
            suggestedResponse: nil
        )
        #expect(comp.intent == .informational)
        #expect(comp.urgency == .normal)
        #expect(comp.requiredAction == nil)
        #expect(comp.entities.isEmpty)
        #expect(comp.sentiment == .neutral)
    }

    @Test("Full comprehension")
    func full() {
        let entity = TestMsgEntity(type: .email, value: "test@example.com")
        let comp = TestMsgComprehension(
            intent: .request,
            urgency: .high,
            requiredAction: .reply,
            entities: [entity],
            sentiment: .positive,
            summary: "A request for help",
            suggestedResponse: "I'll look into it."
        )
        #expect(comp.intent == .request)
        #expect(comp.urgency == .high)
        #expect(comp.requiredAction == .reply)
        #expect(comp.entities.count == 1)
        #expect(comp.sentiment == .positive)
        #expect(comp.summary == "A request for help")
        #expect(comp.suggestedResponse == "I'll look into it.")
    }
}

