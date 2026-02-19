// DiscordConnectorTests.swift
// Phase O — Unit tests for DiscordConnector

@testable import TheaCore
import XCTest

final class DiscordConnectorTests: XCTestCase {

    // MARK: - Initial State

    private func makeConnector() -> DiscordConnector {
        DiscordConnector(credentials: MessagingCredentials())
    }

    func testConnectorInitiallyDisconnected() async {
        let connector = makeConnector()
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Platform Identity

    func testPlatformIsDiscord() async {
        let connector = makeConnector()
        let platform = await connector.platform
        XCTAssertEqual(platform, MessagingPlatform.discord)
    }

    // MARK: - Connect Without Token

    func testConnectWithNoTokenFails() async {
        let connector = makeConnector()
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
        let connector = makeConnector()
        await connector.disconnect()
        let isConn = await connector.isConnected
        XCTAssertFalse(isConn)
    }

    // MARK: - Send Throws When Disconnected

    func testSendThrowsWhenDisconnected() async {
        let connector = makeConnector()
        let msg = OutboundMessagingMessage(chatId: "channel-123", content: "Hello")
        do {
            try await connector.send(msg)
            XCTFail("Expected MessagingError when disconnected")
        } catch {
            XCTAssertTrue(error is MessagingError)
        }
    }
}
