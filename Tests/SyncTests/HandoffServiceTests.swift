//
//  HandoffServiceTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

import XCTest
@testable import Thea

final class HandoffServiceTests: XCTestCase {

    // MARK: - HandoffType Tests

    func testHandoffTypeIcons() {
        XCTAssertEqual(HandoffType.conversation.icon, "bubble.left.and.bubble.right")
        XCTAssertEqual(HandoffType.project.icon, "folder")
        XCTAssertEqual(HandoffType.search.icon, "magnifyingglass")
        XCTAssertEqual(HandoffType.settings.icon, "gear")
    }

    func testHandoffTypeRawValues() {
        XCTAssertEqual(HandoffType.conversation.rawValue, "conversation")
        XCTAssertEqual(HandoffType.project.rawValue, "project")
        XCTAssertEqual(HandoffType.search.rawValue, "search")
        XCTAssertEqual(HandoffType.settings.rawValue, "settings")
    }

    // MARK: - HandoffConfiguration Tests

    func testDefaultConfiguration() {
        let config = HandoffConfiguration()
        XCTAssertTrue(config.handoffEnabled)
        XCTAssertTrue(config.allowConversationHandoff)
        XCTAssertTrue(config.allowProjectHandoff)
        XCTAssertTrue(config.allowSearchHandoff)
        XCTAssertFalse(config.requireSameNetwork)
    }

    func testCustomConfiguration() {
        let config = HandoffConfiguration(
            handoffEnabled: false,
            allowConversationHandoff: true,
            allowProjectHandoff: false,
            allowSearchHandoff: true,
            requireSameNetwork: true
        )
        XCTAssertFalse(config.handoffEnabled)
        XCTAssertFalse(config.allowProjectHandoff)
        XCTAssertTrue(config.requireSameNetwork)
    }

    // MARK: - HandoffContext Tests

    func testHandoffContextCreation() {
        let context = HandoffContext(
            type: .conversation,
            id: "conv-123",
            title: "Test Conversation",
            metadata: ["messageCount": 10]
        )
        XCTAssertEqual(context.type, .conversation)
        XCTAssertEqual(context.id, "conv-123")
        XCTAssertEqual(context.title, "Test Conversation")
    }

    // MARK: - Activity Types Tests

    func testActivityTypes() {
        XCTAssertEqual(HandoffService.conversationActivityType, "app.thea.conversation")
        XCTAssertEqual(HandoffService.projectActivityType, "app.thea.project")
        XCTAssertEqual(HandoffService.searchActivityType, "app.thea.search")
    }

    // MARK: - HandoffService Tests

    @MainActor
    func testHandoffServiceSingleton() {
        let service1 = HandoffService.shared
        let service2 = HandoffService.shared
        XCTAssertTrue(service1 === service2)
    }

    @MainActor
    func testGetConfiguration() {
        let config = HandoffService.shared.getConfiguration()
        XCTAssertNotNil(config)
    }

    // MARK: - PresenceMonitor Tests

    func testPresenceMonitorSingleton() async {
        let monitor1 = PresenceMonitor.shared
        let monitor2 = PresenceMonitor.shared
        let devices1 = await monitor1.getOnlineDevices()
        let devices2 = await monitor2.getOnlineDevices()
        // Same singleton should return same data
        XCTAssertEqual(devices1, devices2)
    }

    func testIsDeviceOnline() async {
        let isOnline = await PresenceMonitor.shared.isDeviceOnline("fake-device-id")
        // A fake device should not be online
        XCTAssertFalse(isOnline)
    }
}
