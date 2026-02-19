// SlackConnectorTests.swift
// Phase O — Unit tests for SlackConnector

@testable import TheaCore
import XCTest

final class SlackConnectorTests: XCTestCase {

    // MARK: - Initial State

    func testConnectorInitiallyDisconnected() async {
        let connector = SlackConnector()
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Platform Identity

    func testPlatformIsSlack() async {
        let connector = SlackConnector()
        let platform = await connector.platform
        XCTAssertEqual(platform, .slack)
    }

    // MARK: - Connect Without Tokens

    func testConnectWithNoTokensFails() async {
        let connector = SlackConnector()
        // Missing both botToken and apiKey (Socket Mode app token)
        do {
            try await connector.connect()
        } catch {
            // Expected: no tokens in test environment
        }
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Disconnect Is Safe

    func testDisconnectWhenNotConnectedIsNoOp() async {
        let connector = SlackConnector()
        await connector.disconnect()
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Send Throws When Disconnected

    func testSendThrowsWhenDisconnected() async {
        let connector = SlackConnector()
        let msg = OutboundMessagingMessage(chatId: "C01234567", content: "Hello from Thea")
        do {
            try await connector.send(msg)
            XCTFail("Expected MessagingError when disconnected")
        } catch {
            XCTAssertTrue(error is MessagingError)
        }
    }
}
