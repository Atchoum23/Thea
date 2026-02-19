// TelegramConnectorTests.swift
// Phase O — Unit tests for TelegramConnector

@testable import TheaCore
import XCTest

final class TelegramConnectorTests: XCTestCase {

    // MARK: - Connector Init

    func testConnectorInitialState() async {
        let connector = TelegramConnector(credentials: MessagingCredentials())
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Connect Without Token (should not crash, returns error state)

    func testConnectWithoutTokenSetsDisconnected() async {
        let connector = TelegramConnector(credentials: MessagingCredentials())
        // No token → should fail gracefully (connect() reads credentials set on the connector)
        do {
            try await connector.connect()
        } catch {
            // Expected: no bot token configured in unit test environment
        }
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Disconnect Is Safe When Not Connected

    func testDisconnectWhenNotConnectedIsNoOp() async {
        let connector = TelegramConnector(credentials: MessagingCredentials())
        await connector.disconnect() // Must not throw or crash
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Send Without Connection Throws

    func testSendWithoutConnectionThrows() async {
        let connector = TelegramConnector(credentials: MessagingCredentials())
        let msg = OutboundMessagingMessage(chatId: "123456", content: "Test")
        do {
            try await connector.send(msg)
            XCTFail("Expected error when not connected")
        } catch {
            XCTAssertTrue(error is MessagingError)
        }
    }

    // MARK: - Platform Identity

    func testPlatformIsTelegram() async {
        let connector = TelegramConnector(credentials: MessagingCredentials())
        let platform = await connector.platform
        XCTAssertEqual(platform, MessagingPlatform.telegram)
    }
}
