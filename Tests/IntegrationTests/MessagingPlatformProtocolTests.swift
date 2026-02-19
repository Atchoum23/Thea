// MessagingPlatformProtocolTests.swift
// Phase O — Tests for MessagingPlatform enum, TheaGatewayMessage, and MessagingCredentials

@testable import TheaCore
import XCTest

final class MessagingPlatformProtocolTests: XCTestCase {

    // MARK: - MessagingPlatform Enum

    func testAllCasesCount() {
        XCTAssertEqual(MessagingPlatform.allCases.count, 7)
    }

    func testAllCasesContainExpectedPlatforms() {
        let cases = MessagingPlatform.allCases
        XCTAssertTrue(cases.contains(.telegram))
        XCTAssertTrue(cases.contains(.discord))
        XCTAssertTrue(cases.contains(.slack))
        XCTAssertTrue(cases.contains(.imessage))
        XCTAssertTrue(cases.contains(.whatsapp))
        XCTAssertTrue(cases.contains(.signal))
        XCTAssertTrue(cases.contains(.matrix))
    }

    func testDisplayNamesAreNonEmpty() {
        for platform in MessagingPlatform.allCases {
            XCTAssertFalse(platform.displayName.isEmpty, "\(platform.rawValue) has empty displayName")
        }
    }

    func testSymbolNamesAreNonEmpty() {
        for platform in MessagingPlatform.allCases {
            XCTAssertFalse(platform.symbolName.isEmpty, "\(platform.rawValue) has empty symbolName")
        }
    }

    func testOpenClawPlatformBridgeCoversAllCases() {
        for platform in MessagingPlatform.allCases {
            let ocPlatform = platform.openClawPlatform
            XCTAssertNotNil(ocPlatform, "\(platform.rawValue) must have an openClawPlatform mapping")
        }
    }

    // MARK: - TheaGatewayMessage

    func testTheaGatewayMessageInit() {
        let id = UUID().uuidString
        let msg = TheaGatewayMessage(
            id: id,
            platform: .telegram,
            chatId: "chat-abc",
            senderId: "user-xyz",
            senderName: "Test User",
            content: "Hello, world!",
            timestamp: Date()
        )
        XCTAssertEqual(msg.id, id)
        XCTAssertEqual(msg.platform, .telegram)
        XCTAssertEqual(msg.chatId, "chat-abc")
        XCTAssertEqual(msg.content, "Hello, world!")
    }

    func testTheaGatewayMessageCodable() throws {
        let msg = TheaGatewayMessage(
            id: "test-id",
            platform: .discord,
            chatId: "channel-1",
            senderId: "u1",
            senderName: "Alice",
            content: "Test message",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(TheaGatewayMessage.self, from: data)
        XCTAssertEqual(decoded.id, msg.id)
        XCTAssertEqual(decoded.platform, msg.platform)
        XCTAssertEqual(decoded.content, msg.content)
    }

    // MARK: - MessagingCredentials

    func testMessagingCredentialsDefaultInit() {
        let creds = MessagingCredentials(isEnabled: false)
        XCTAssertFalse(creds.isEnabled)
        XCTAssertNil(creds.botToken)
        XCTAssertNil(creds.apiKey)
        XCTAssertNil(creds.serverUrl)
        XCTAssertNil(creds.webhookSecret)
    }

    func testMessagingCredentialsWithToken() {
        var creds = MessagingCredentials(isEnabled: true)
        creds.botToken = "bot12345"
        XCTAssertEqual(creds.botToken, "bot12345")
        XCTAssertTrue(creds.isEnabled)
    }

    // MARK: - OutboundMessagingMessage

    func testOutboundMessageInit() {
        let msg = OutboundMessagingMessage(chatId: "room-1", content: "Reply text")
        XCTAssertEqual(msg.chatId, "room-1")
        XCTAssertEqual(msg.content, "Reply text")
        XCTAssertNil(msg.replyToId)
    }

    func testOutboundMessageWithReplyTo() {
        let msg = OutboundMessagingMessage(chatId: "room-2", content: "Follow-up", replyToId: "msg-abc")
        XCTAssertEqual(msg.replyToId, "msg-abc")
    }

    // MARK: - MessagingError

    func testMessagingErrorIsError() {
        let err: Error = MessagingError.notConnected(platform: .telegram)
        XCTAssertNotNil(err.localizedDescription)
    }

    func testMessagingErrorPlatformUnavailable() {
        let err = MessagingError.platformUnavailable(platform: .discord, reason: "not supported on this OS")
        XCTAssertFalse(err.localizedDescription.isEmpty)
    }
}
