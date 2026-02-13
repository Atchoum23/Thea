@testable import TheaModels
import XCTest

final class QueuedMessageTests: XCTestCase {

    // MARK: - Initialization

    func testQueuedMessageDefaults() {
        let msg = QueuedMessage(text: "Hello")
        XCTAssertEqual(msg.text, "Hello")
        XCTAssertTrue(msg.attachments.isEmpty)
        XCTAssertEqual(msg.priority, 0)
        XCTAssertNil(msg.scheduledFor)
    }

    func testQueuedMessageWithPriority() {
        let msg = QueuedMessage(text: "Urgent", priority: 5)
        XCTAssertEqual(msg.priority, 5)
    }

    // MARK: - isScheduled

    func testIsScheduledWhenNotScheduled() {
        let msg = QueuedMessage(text: "Hello")
        XCTAssertFalse(msg.isScheduled)
    }

    func testIsScheduledWhenScheduled() {
        let msg = QueuedMessage(text: "Hello", scheduledFor: Date())
        XCTAssertTrue(msg.isScheduled)
    }

    // MARK: - previewText

    func testPreviewTextShortMessage() {
        let msg = QueuedMessage(text: "Short text")
        XCTAssertEqual(msg.previewText, "Short text")
        XCTAssertFalse(msg.previewText.hasSuffix("..."))
    }

    func testPreviewTextExactly80Characters() {
        let text = String(repeating: "a", count: 80)
        let msg = QueuedMessage(text: text)
        XCTAssertEqual(msg.previewText, text)
        XCTAssertFalse(msg.previewText.hasSuffix("..."))
    }

    func testPreviewTextLongMessage() {
        let text = String(repeating: "b", count: 200)
        let msg = QueuedMessage(text: text)
        XCTAssertTrue(msg.previewText.hasSuffix("..."))
        XCTAssertEqual(msg.previewText.count, 83) // 80 chars + "..."
    }

    func testPreviewTextEmptyMessage() {
        let msg = QueuedMessage(text: "")
        XCTAssertEqual(msg.previewText, "")
    }

    // MARK: - QueuedAttachment

    func testQueuedAttachmentCreation() {
        let data = Data("test data".utf8)
        let attachment = QueuedAttachment(name: "file.txt", data: data, mimeType: "text/plain")
        XCTAssertEqual(attachment.name, "file.txt")
        XCTAssertEqual(attachment.mimeType, "text/plain")
        XCTAssertEqual(attachment.data, data)
    }

    func testQueuedMessageWithAttachments() {
        let data = Data([0x00, 0x01])
        let attachment = QueuedAttachment(name: "img.png", data: data, mimeType: "image/png")
        let msg = QueuedMessage(text: "See attached", attachments: [attachment])
        XCTAssertEqual(msg.attachments.count, 1)
        XCTAssertEqual(msg.attachments[0].name, "img.png")
    }

    // MARK: - Identifiable

    func testQueuedMessageUniqueIDs() {
        let msg1 = QueuedMessage(text: "A")
        let msg2 = QueuedMessage(text: "B")
        XCTAssertNotEqual(msg1.id, msg2.id)
    }

    func testQueuedAttachmentUniqueIDs() {
        let data = Data()
        let a1 = QueuedAttachment(name: "a", data: data, mimeType: "text/plain")
        let a2 = QueuedAttachment(name: "b", data: data, mimeType: "text/plain")
        XCTAssertNotEqual(a1.id, a2.id)
    }
}
