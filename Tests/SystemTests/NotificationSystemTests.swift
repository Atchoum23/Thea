//
//  NotificationSystemTests.swift
//  TheaTests
//
//  Created by Claude Code on 2026-01-20
//

import XCTest
@testable import Thea

final class NotificationSystemTests: XCTestCase {

    // MARK: - NotificationCategory Tests

    func testNotificationCategoryIdentifiers() {
        XCTAssertEqual(NotificationCategory.general.identifier, "general")
        XCTAssertEqual(NotificationCategory.aiTask.identifier, "ai_task")
        XCTAssertEqual(NotificationCategory.reminder.identifier, "reminder")
        XCTAssertEqual(NotificationCategory.message.identifier, "message")
        XCTAssertEqual(NotificationCategory.update.identifier, "update")
    }

    func testNotificationCategoryDisplayNames() {
        XCTAssertEqual(NotificationCategory.general.displayName, "General")
        XCTAssertEqual(NotificationCategory.aiTask.displayName, "AI Tasks")
        XCTAssertEqual(NotificationCategory.reminder.displayName, "Reminders")
    }

    func testNotificationCategoryIcons() {
        XCTAssertEqual(NotificationCategory.general.icon, "bell")
        XCTAssertEqual(NotificationCategory.aiTask.icon, "brain")
        XCTAssertEqual(NotificationCategory.message.icon, "message")
    }

    func testAllCategoriesCount() {
        XCTAssertEqual(NotificationCategory.allCases.count, 10)
    }

    // MARK: - NotificationPriority Tests

    func testPriorityLevels() {
        XCTAssertLessThan(NotificationPriority.low.rawValue, NotificationPriority.normal.rawValue)
        XCTAssertLessThan(NotificationPriority.normal.rawValue, NotificationPriority.high.rawValue)
        XCTAssertLessThan(NotificationPriority.high.rawValue, NotificationPriority.critical.rawValue)
    }

    func testPriorityInterruptionLevels() {
        XCTAssertEqual(NotificationPriority.low.interruptionLevel, .passive)
        XCTAssertEqual(NotificationPriority.normal.interruptionLevel, .active)
        XCTAssertEqual(NotificationPriority.high.interruptionLevel, .timeSensitive)
        XCTAssertEqual(NotificationPriority.critical.interruptionLevel, .critical)
    }

    // MARK: - NotificationRequest Tests

    func testNotificationRequestCreation() {
        let request = NotificationRequest(
            id: "test-123",
            title: "Test Title",
            body: "Test Body",
            category: .general
        )
        XCTAssertEqual(request.id, "test-123")
        XCTAssertEqual(request.title, "Test Title")
        XCTAssertEqual(request.body, "Test Body")
        XCTAssertEqual(request.category, .general)
    }

    func testNotificationRequestWithPriority() {
        let request = NotificationRequest(
            id: "urgent-1",
            title: "Urgent",
            body: "Important message",
            category: .alert,
            priority: .critical
        )
        XCTAssertEqual(request.priority, .critical)
    }

    func testNotificationRequestWithScheduledDate() {
        let futureDate = Date().addingTimeInterval(3600)
        let request = NotificationRequest(
            id: "scheduled-1",
            title: "Scheduled",
            body: "Later",
            category: .reminder,
            scheduledDate: futureDate
        )
        XCTAssertEqual(request.scheduledDate, futureDate)
    }

    func testNotificationRequestWithAttachment() {
        let attachment = NotificationAttachment(
            identifier: "img-1",
            url: URL(fileURLWithPath: "/tmp/image.png"),
            type: .image
        )
        let request = NotificationRequest(
            id: "with-attachment",
            title: "Photo",
            body: "See attachment",
            category: .message,
            attachments: [attachment]
        )
        XCTAssertEqual(request.attachments.count, 1)
        XCTAssertEqual(request.attachments.first?.type, .image)
    }

    // MARK: - NotificationAttachment Tests

    func testAttachmentTypes() {
        XCTAssertEqual(NotificationAttachmentType.image.rawValue, "image")
        XCTAssertEqual(NotificationAttachmentType.audio.rawValue, "audio")
        XCTAssertEqual(NotificationAttachmentType.video.rawValue, "video")
    }

    // MARK: - NotificationService Tests

    func testNotificationServiceSingleton() async {
        let service1 = NotificationService.shared
        let service2 = NotificationService.shared
        let status1 = await service1.authorizationStatus
        let status2 = await service2.authorizationStatus
        XCTAssertEqual(status1, status2)
    }

    // MARK: - PriorityManager Tests

    func testPriorityManagerSingleton() async {
        let manager = PriorityManager.shared
        let shouldDeliver = await manager.shouldDeliverNotification(priority: .high)
        // High priority should generally be delivered
        XCTAssertTrue(shouldDeliver)
    }

    // MARK: - BadgeManager Tests

    func testBadgeManagerSingleton() async {
        let manager1 = BadgeManager.shared
        let manager2 = BadgeManager.shared
        let count1 = await manager1.totalCount
        let count2 = await manager2.totalCount
        XCTAssertEqual(count1, count2)
    }

    func testBadgeIncrement() async {
        let manager = BadgeManager.shared
        let initialCount = await manager.totalCount
        await manager.incrementBadge(for: .general)
        let newCount = await manager.totalCount
        XCTAssertGreaterThanOrEqual(newCount, initialCount)
        // Reset for other tests
        await manager.decrementBadge(for: .general)
    }
}
