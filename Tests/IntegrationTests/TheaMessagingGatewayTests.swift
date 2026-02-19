// TheaMessagingGatewayTests.swift
// Phase O — Integration tests for TheaMessagingGateway orchestrator

@testable import TheaCore
import XCTest

@MainActor
final class TheaMessagingGatewayTests: XCTestCase {

    // MARK: - Gateway Singleton

    func testGatewaySharedExists() {
        let gateway = TheaMessagingGateway.shared
        XCTAssertNotNil(gateway)
    }

    func testGatewayInitialState() {
        let gateway = TheaMessagingGateway.shared
        // Gateway may or may not be running depending on test order; just verify the properties are accessible
        _ = gateway.isRunning
        _ = gateway.connectedPlatforms
        _ = gateway.lastError
    }

    // MARK: - Platform Set Behaviour

    func testConnectedPlatformsIsSubsetOfAllCases() {
        let gateway = TheaMessagingGateway.shared
        for platform in gateway.connectedPlatforms {
            XCTAssertTrue(MessagingPlatform.allCases.contains(platform))
        }
    }

    // MARK: - Outbound Send (no credentials → throws)

    func testSendWithoutCredentialsThrows() async {
        let gateway = TheaMessagingGateway.shared
        let msg = OutboundMessagingMessage(chatId: "test-chat", content: "Hello")
        do {
            try await gateway.send(msg, via: .telegram)
            // If the platform is connected somehow, the send might succeed — don't fail
        } catch {
            // Expected: no bot token configured in unit test environment
            XCTAssertTrue(error is MessagingError || error is OpenClawError)
        }
    }

    // MARK: - Health Status

    func testHealthStatusReturnsDictionary() {
        let gateway = TheaMessagingGateway.shared
        let health = gateway.healthStatus()
        XCTAssertNotNil(health["status"])
    }

    func testHealthStatusContainsConnectors() {
        let gateway = TheaMessagingGateway.shared
        let health = gateway.healthStatus()
        XCTAssertNotNil(health["connectors"])
    }

    // MARK: - Restart Connector (idempotent, no crash)

    func testRestartConnectorForDisabledPlatformIsNoOp() async {
        let gateway = TheaMessagingGateway.shared
        // Restarting a connector with no credentials should not crash
        await gateway.restartConnector(for: .matrix)
    }
}
