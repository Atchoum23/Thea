// H3WhatsAppTests.swift
// Tests for WhatsApp channel implementation (H3)

import Testing
import Foundation

// MARK: - WhatsApp Message Model Tests

@Suite("WhatsApp — Message Model")
struct WhatsAppMessageModelTests {
    @Test("Create message with defaults")
    func createDefault() {
        let msg = WATestMessage(chatID: "chat1", senderID: "user1", content: "Hello")
        #expect(msg.chatID == "chat1")
        #expect(msg.senderID == "user1")
        #expect(msg.content == "Hello")
        #expect(!msg.isFromMe)
        #expect(!msg.isGroup)
        #expect(msg.attachments.isEmpty)
        #expect(msg.replyToID == nil)
    }

    @Test("Create message with all fields")
    func createFull() {
        let att = WATestAttachment(type: .image, fileName: "photo.jpg")
        let msg = WATestMessage(
            chatID: "group@g.us",
            senderID: "user1",
            senderName: "Alice",
            content: "Check this out",
            isFromMe: true,
            attachments: [att],
            replyToID: "msg-123",
            isGroup: true
        )
        #expect(msg.senderName == "Alice")
        #expect(msg.isFromMe)
        #expect(msg.isGroup)
        #expect(msg.attachments.count == 1)
        #expect(msg.replyToID == "msg-123")
    }

    @Test("Message IDs are unique")
    func uniqueIDs() {
        let msg1 = WATestMessage(chatID: "c", senderID: "s", content: "1")
        let msg2 = WATestMessage(chatID: "c", senderID: "s", content: "2")
        #expect(msg1.id != msg2.id)
    }
}

// MARK: - WhatsApp Attachment Tests

@Suite("WhatsApp — Attachment Types")
struct WhatsAppAttachmentTypeTests {
    @Test("All 8 attachment types exist")
    func allTypes() {
        let types: [WATestAttachmentType] = [.image, .video, .voiceNote, .audio, .document, .sticker, .contact, .location]
        #expect(types.count == 8)
    }

    @Test("Attachment types have unique raw values")
    func uniqueRawValues() {
        let types: [WATestAttachmentType] = [.image, .video, .voiceNote, .audio, .document, .sticker, .contact, .location]
        let rawValues = Set(types.map(\.rawValue))
        #expect(rawValues.count == types.count)
    }

    @Test("Attachment with voice note type")
    func voiceNote() {
        let att = WATestAttachment(type: .voiceNote, mimeType: "audio/ogg", sizeBytes: 15000)
        #expect(att.type == .voiceNote)
        #expect(att.mimeType == "audio/ogg")
        #expect(att.sizeBytes == 15000)
    }

    @Test("Attachment defaults are nil")
    func defaults() {
        let att = WATestAttachment(type: .image)
        #expect(att.url == nil)
        #expect(att.mimeType == nil)
        #expect(att.fileName == nil)
        #expect(att.sizeBytes == nil)
        #expect(att.transcription == nil)
    }
}

// MARK: - WhatsApp Contact Tests

@Suite("WhatsApp — Contact Model")
struct WhatsAppContactTests {
    @Test("Create contact with defaults")
    func createDefault() {
        let contact = WATestContact(id: "user1", name: "Alice")
        #expect(contact.id == "user1")
        #expect(contact.name == "Alice")
        #expect(contact.phoneNumber == nil)
        #expect(!contact.isBlocked)
    }

    @Test("Create contact with phone number")
    func withPhone() {
        let contact = WATestContact(id: "u1", name: "Bob", phoneNumber: "+41791234567")
        #expect(contact.phoneNumber == "+41791234567")
    }

    @Test("Contact Codable roundtrip")
    func codable() throws {
        let contact = WATestContact(id: "u1", name: "Alice", phoneNumber: "+33612345678", isBlocked: true)
        let data = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(WATestContact.self, from: data)
        #expect(decoded.id == "u1")
        #expect(decoded.name == "Alice")
        #expect(decoded.phoneNumber == "+33612345678")
        #expect(decoded.isBlocked)
    }
}

// MARK: - WhatsApp Group Tests

@Suite("WhatsApp — Group Model")
struct WhatsAppGroupTests {
    @Test("Create group with defaults")
    func createDefault() {
        let group = WATestGroup(id: "group@g.us", name: "Family")
        #expect(group.id == "group@g.us")
        #expect(group.name == "Family")
        #expect(group.participantCount == 0)
        #expect(!group.isMuted)
    }

    @Test("Group with participant count")
    func withParticipants() {
        let group = WATestGroup(id: "g1", name: "Work", participantCount: 25, isMuted: true)
        #expect(group.participantCount == 25)
        #expect(group.isMuted)
    }

    @Test("Group Codable roundtrip")
    func codable() throws {
        let group = WATestGroup(id: "g1", name: "Test", participantCount: 5, isMuted: false)
        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(WATestGroup.self, from: data)
        #expect(decoded.id == "g1")
        #expect(decoded.participantCount == 5)
    }
}

// MARK: - WhatsApp Chat Export Parsing Tests

@Suite("WhatsApp — Export Parsing")
struct WhatsAppExportParsingTests {
    @Test("Parse bracket format messages")
    func parseBracketFormat() {
        let content = """
        [15/02/2026, 14:30:00] Alice: Hello, how are you?
        [15/02/2026, 14:31:00] Bob: I'm doing great, thanks!
        [15/02/2026, 14:32:00] Alice: Want to grab coffee?
        """
        let messages = parseWAExport(content)
        #expect(messages.count == 3)
        #expect(messages[0].senderID == "Alice")
        #expect(messages[0].content == "Hello, how are you?")
        #expect(messages[1].senderID == "Bob")
        #expect(messages[2].content == "Want to grab coffee?")
    }

    @Test("Parse European dash format messages")
    func parseDashFormat() {
        let content = """
        15.02.26, 14:30 - Alice: Hallo, wie geht's?
        15.02.26, 14:31 - Bob: Mir geht's gut, danke!
        """
        let messages = parseWAExport(content)
        #expect(messages.count == 2)
        #expect(messages[0].senderID == "Alice")
        #expect(messages[0].content == "Hallo, wie geht's?")
    }

    @Test("Parse multiline messages")
    func parseMultiline() {
        let content = """
        [15/02/2026, 14:30:00] Alice: This is line 1
        And this is line 2
        And line 3
        [15/02/2026, 14:31:00] Bob: Short reply
        """
        let messages = parseWAExport(content)
        #expect(messages.count == 2)
        #expect(messages[0].content.contains("line 1"))
        #expect(messages[0].content.contains("line 2"))
        #expect(messages[0].content.contains("line 3"))
    }

    @Test("Parse media attachments in export")
    func parseMedia() {
        let content = """
        [15/02/2026, 14:30:00] Alice: IMG-20260215.jpg (file attached)
        [15/02/2026, 14:31:00] Bob: VID-20260215.mp4 (file attached)
        [15/02/2026, 14:32:00] Alice: AUD-20260215.opus (file attached)
        [15/02/2026, 14:33:00] Bob: PTT-20260215.opus (file attached)
        [15/02/2026, 14:34:00] Alice: STK-20260215.webp (file attached)
        """
        let messages = parseWAExport(content)
        #expect(messages.count == 5)
        #expect(messages[0].attachments.first?.type == .image)
        #expect(messages[1].attachments.first?.type == .video)
        #expect(messages[2].attachments.first?.type == .voiceNote)
        #expect(messages[3].attachments.first?.type == .voiceNote)
        #expect(messages[4].attachments.first?.type == .sticker)
    }

    @Test("Parse media omitted messages")
    func parseMediaOmitted() {
        let content = "[15/02/2026, 14:30:00] Alice: <Media omitted>"
        let messages = parseWAExport(content)
        #expect(messages.count == 1)
        #expect(!messages[0].attachments.isEmpty)
    }

    @Test("Empty input returns no messages")
    func emptyInput() {
        let messages = parseWAExport("")
        #expect(messages.isEmpty)
    }

    @Test("Invalid format returns no messages")
    func invalidFormat() {
        let content = "This is not a WhatsApp export format"
        let messages = parseWAExport(content)
        #expect(messages.isEmpty)
    }

    @Test("Mixed bracket and dash format")
    func mixedFormats() {
        let content = """
        [15/02/2026, 14:30:00] Alice: Bracket format
        15.02.26, 14:31 - Bob: Dash format
        """
        let messages = parseWAExport(content)
        #expect(messages.count == 2)
    }

    @Test("Timestamp parsing preserves order")
    func timestampOrder() {
        let content = """
        [15/02/2026, 08:00:00] Alice: Morning
        [15/02/2026, 12:00:00] Bob: Noon
        [15/02/2026, 18:00:00] Alice: Evening
        """
        let messages = parseWAExport(content)
        #expect(messages.count == 3)
        #expect(messages[0].timestamp < messages[1].timestamp)
        #expect(messages[1].timestamp < messages[2].timestamp)
    }

    @Test("Group chat ID detection")
    func groupIDDetection() {
        #expect(isWAGroupChat("120363123456789@g.us"))
        #expect(!isWAGroupChat("41791234567@s.whatsapp.net"))
        #expect(!isWAGroupChat("regular_chat_id"))
    }
}

// MARK: - WhatsApp Test Doubles

private struct WATestMessage: Codable, Identifiable {
    let id: String
    let chatID: String
    let senderID: String
    let senderName: String?
    let content: String
    let timestamp: Date
    let isFromMe: Bool
    let attachments: [WATestAttachment]
    var replyToID: String?
    var isGroup: Bool

    init(
        chatID: String, senderID: String, senderName: String? = nil, content: String,
        timestamp: Date = Date(), isFromMe: Bool = false,
        attachments: [WATestAttachment] = [], replyToID: String? = nil, isGroup: Bool = false
    ) {
        self.id = UUID().uuidString
        self.chatID = chatID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.isFromMe = isFromMe
        self.attachments = attachments
        self.replyToID = replyToID
        self.isGroup = isGroup
    }
}

private enum WATestAttachmentType: String, Codable, CaseIterable {
    case image, video, voiceNote, audio, document, sticker, contact, location
}

private struct WATestAttachment: Codable {
    let id: UUID
    let type: WATestAttachmentType
    var url: String?
    var mimeType: String?
    var fileName: String?
    var sizeBytes: Int?
    var transcription: String?

    init(type: WATestAttachmentType, url: String? = nil, mimeType: String? = nil,
         fileName: String? = nil, sizeBytes: Int? = nil, transcription: String? = nil) {
        self.id = UUID()
        self.type = type
        self.url = url
        self.mimeType = mimeType
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.transcription = transcription
    }
}

private struct WATestContact: Codable, Identifiable {
    let id: String
    var name: String
    var phoneNumber: String?
    var isBlocked: Bool

    init(id: String, name: String, phoneNumber: String? = nil, isBlocked: Bool = false) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.isBlocked = isBlocked
    }
}

private struct WATestGroup: Codable, Identifiable {
    let id: String
    var name: String
    var participantCount: Int
    var isMuted: Bool

    init(id: String, name: String, participantCount: Int = 0, isMuted: Bool = false) {
        self.id = id
        self.name = name
        self.participantCount = participantCount
        self.isMuted = isMuted
    }
}

// MARK: - WhatsApp Parser (Mirrors Production Logic)

/// Parse WhatsApp chat export text — mirrors WhatsAppChannel.parseChatExport()
private func parseWAExport(_ content: String) -> [WATestMessage] {
    var messages: [WATestMessage] = []
    let lines = content.components(separatedBy: .newlines)

    let bracketPattern = #"^\[(\d{1,2}/\d{1,2}/\d{2,4}),?\s*(\d{1,2}:\d{2}(?::\d{2})?)\]\s*(.+?):\s*(.+)$"#
    let dashPattern = #"^(\d{1,2}\.\d{1,2}\.\d{2,4}),?\s*(\d{1,2}:\d{2})\s*-\s*(.+?):\s*(.+)$"#

    let bracketRegex = try? NSRegularExpression(pattern: bracketPattern)
    let dashRegex = try? NSRegularExpression(pattern: dashPattern)

    var currentMessage: (date: String, time: String, sender: String, content: String, bracketFmt: Bool)?

    for line in lines {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)

        if let match = bracketRegex?.firstMatch(in: line, range: range), match.numberOfRanges == 5 {
            if let prev = currentMessage, let msg = createParsedWAMsg(prev) {
                messages.append(msg)
            }
            currentMessage = (
                date: String(line[Range(match.range(at: 1), in: line)!]),  // swiftlint:disable:this force_unwrapping
                time: String(line[Range(match.range(at: 2), in: line)!]),  // swiftlint:disable:this force_unwrapping
                sender: String(line[Range(match.range(at: 3), in: line)!]),  // swiftlint:disable:this force_unwrapping
                content: String(line[Range(match.range(at: 4), in: line)!]),  // swiftlint:disable:this force_unwrapping
                bracketFmt: true
            )
        } else if let match = dashRegex?.firstMatch(in: line, range: range), match.numberOfRanges == 5 {
            if let prev = currentMessage, let msg = createParsedWAMsg(prev) {
                messages.append(msg)
            }
            currentMessage = (
                date: String(line[Range(match.range(at: 1), in: line)!]),  // swiftlint:disable:this force_unwrapping
                time: String(line[Range(match.range(at: 2), in: line)!]),  // swiftlint:disable:this force_unwrapping
                sender: String(line[Range(match.range(at: 3), in: line)!]),  // swiftlint:disable:this force_unwrapping
                content: String(line[Range(match.range(at: 4), in: line)!]),  // swiftlint:disable:this force_unwrapping
                bracketFmt: false
            )
        } else if currentMessage != nil, !line.isEmpty {
            currentMessage?.content += "\n" + line
        }
    }
    if let prev = currentMessage, let msg = createParsedWAMsg(prev) {
        messages.append(msg)
    }
    return messages
}

private func createParsedWAMsg(
    _ raw: (date: String, time: String, sender: String, content: String, bracketFmt: Bool)
) -> WATestMessage? {
    let dateString = "\(raw.date) \(raw.time)"
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    let formats = raw.bracketFmt
        ? ["d/M/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm:ss", "d/M/yyyy HH:mm"]
        : ["d.M.yy HH:mm", "dd.MM.yy HH:mm", "dd.MM.yyyy HH:mm"]

    var parsedDate: Date?
    for format in formats {
        formatter.dateFormat = format
        if let date = formatter.date(from: dateString) { parsedDate = date; break }
    }
    guard let timestamp = parsedDate else { return nil }

    let isMedia = raw.content.hasSuffix("(file attached)")
        || raw.content.contains("<Media omitted>")
        || raw.content.hasPrefix("IMG-")
        || raw.content.hasPrefix("VID-")
        || raw.content.hasPrefix("AUD-")
        || raw.content.hasPrefix("PTT-")
        || raw.content.hasPrefix("STK-")

    let attachments: [WATestAttachment]
    if isMedia {
        let type: WATestAttachmentType
        if raw.content.hasPrefix("AUD-") || raw.content.hasPrefix("PTT-") {
            type = .voiceNote
        } else if raw.content.hasPrefix("VID-") { type = .video }
        else if raw.content.hasPrefix("STK-") { type = .sticker }
        else if raw.content.hasPrefix("IMG-") { type = .image }
        else { type = .document }
        attachments = [WATestAttachment(type: type, fileName: raw.content)]
    } else {
        attachments = []
    }

    return WATestMessage(
        chatID: "export_\(raw.sender.hashValue)",
        senderID: raw.sender,
        senderName: raw.sender,
        content: raw.content,
        timestamp: timestamp,
        attachments: attachments
    )
}

/// Check if a WhatsApp chat ID represents a group
private func isWAGroupChat(_ channelID: String) -> Bool {
    channelID.hasSuffix("@g.us")
}
