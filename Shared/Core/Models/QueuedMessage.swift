// QueuedMessage.swift
// Thea
//
// Message queue types for prompt queuing system

import Foundation

// MARK: - Queued Message

struct QueuedMessage: Identifiable, Sendable {
    // periphery:ignore - Reserved: QueuedMessage type reserved for future feature activation
    let id: UUID
    var text: String
    var attachments: [QueuedAttachment]
    let queuedAt: Date
    var priority: Int // 0 = normal, higher = sooner
    var scheduledFor: Date?

    init(
        id: UUID = UUID(),
        text: String,
        attachments: [QueuedAttachment] = [],
        queuedAt: Date = Date(),
        priority: Int = 0,
        scheduledFor: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.attachments = attachments
        self.queuedAt = queuedAt
        self.priority = priority
        self.scheduledFor = scheduledFor
    }

    var isScheduled: Bool { scheduledFor != nil }

    var previewText: String {
        String(text.prefix(80)) + (text.count > 80 ? "..." : "")
    }
}

// MARK: - Queued Attachment

// periphery:ignore - Reserved: QueuedAttachment type reserved for future feature activation
struct QueuedAttachment: Identifiable, Sendable {
    let id: UUID
    let name: String
    let data: Data
    let mimeType: String

    init(
        id: UUID = UUID(),
        name: String,
        data: Data,
        mimeType: String
    ) {
        self.id = id
        self.name = name
        self.data = data
        self.mimeType = mimeType
    }
}
