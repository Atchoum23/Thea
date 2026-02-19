// DiscordConnectorTests.swift
// Phase O — Unit tests for DiscordConnector

@testable import TheaCore
import XCTest

final class DiscordConnectorTests: XCTestCase {

    // MARK: - Initial State

    func testConnectorInitiallyDisconnected() async {
        let connector = DiscordConnector()
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Platform Identity

    func testPlatformIsDiscord() async {
        let connector = DiscordConnector()
        let platform = await connector.platform
        XCTAssertEqual(platform, .discord)
    }

    // MARK: - Connect Without Token

    func testConnectWithNoTokenFails() async {
        let connector = DiscordConnector()
        do {
            try await connector.connect()
        } catch {
            // Expected: no bot token in test environment
        }
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Disconnect When Not Connected

    func testDisconnectWhenNotConnectedIsNoOp() async {
        let connector = DiscordConnector()
        await connector.disconnect()
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Send Throws When Disconnected

    func testSendThrowsWhenDisconnected() async {
        let connector = DiscordConnector()
        let msg = OutboundMessagingMessage(chatId: "channel-123", content: "Hello")
        do {
            try await connector.send(msg)
            XCTFail("Expected MessagingError when disconnected")
        } catch {
            XCTAssertTrue(error is MessagingError)
        }
    }
}
