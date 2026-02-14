// TheaClipModels.swift
// Thea — Clipboard History & Pinboard Models
//
// Persistent clipboard history inspired by Paste.app, integrated natively into Thea.

import CryptoKit
import Foundation
@preconcurrency import SwiftData

// MARK: - Content Type

enum TheaClipContentType: String, Codable, Sendable, CaseIterable {
    case text
    case richText
    case html
    case url
    case image
    case file
    case color
}

// MARK: - Clipboard Entry

@Model
final class TheaClipEntry {
    @Attribute(.unique) var id: UUID

    // Content
    var contentTypeRaw: String
    var textContent: String?
    var htmlContent: String?
    var urlString: String?
    @Attribute(.externalStorage) var imageData: Data?
    var originalImageHash: String?
    var fileNames: [String]
    var filePaths: [String]

    // Source
    var sourceAppBundleID: String?
    var sourceAppName: String?

    // Metrics
    var characterCount: Int
    var byteCount: Int
    var createdAt: Date
    var lastAccessedAt: Date
    var accessCount: Int

    // Organization
    var isPinned: Bool
    var isFavorite: Bool
    var tags: [String]
    var previewText: String

    // Privacy
    var isSensitive: Bool
    var sensitiveExpiresAt: Date?

    // AI (Phase 2)
    var aiSummary: String?
    var aiCategory: String?

    // Relationships
    @Relationship(inverse: \TheaClipPinboardEntry.clipEntry)
    var pinboardEntries: [TheaClipPinboardEntry]

    // Computed
    var contentType: TheaClipContentType {
        get { TheaClipContentType(rawValue: contentTypeRaw) ?? .text }
        set { contentTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        contentType: TheaClipContentType = .text,
        textContent: String? = nil,
        htmlContent: String? = nil,
        urlString: String? = nil,
        imageData: Data? = nil,
        originalImageHash: String? = nil,
        fileNames: [String] = [],
        filePaths: [String] = [],
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        characterCount: Int = 0,
        byteCount: Int = 0,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        accessCount: Int = 0,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        isSensitive: Bool = false,
        sensitiveExpiresAt: Date? = nil,
        tags: [String] = [],
        previewText: String = ""
    ) {
        self.id = id
        self.contentTypeRaw = contentType.rawValue
        self.textContent = textContent
        self.htmlContent = htmlContent
        self.urlString = urlString
        self.imageData = imageData
        self.originalImageHash = originalImageHash
        self.fileNames = fileNames
        self.filePaths = filePaths
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.characterCount = characterCount
        self.byteCount = byteCount
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.isSensitive = isSensitive
        self.sensitiveExpiresAt = sensitiveExpiresAt
        self.tags = tags
        self.previewText = previewText
        self.pinboardEntries = []
    }

    /// Compute a content hash for deduplication
    static func contentHash(text: String?, imageData: Data?, fileNames: [String]) -> String {
        var hasher = SHA256()
        if let text { hasher.update(data: Data(text.utf8)) }
        if let data = imageData { hasher.update(data: data) }
        for name in fileNames { hasher.update(data: Data(name.utf8)) }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Pinboard

@Model
final class TheaClipPinboard {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \TheaClipPinboardEntry.pinboard)
    var entries: [TheaClipPinboardEntry]

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "pin.fill",
        colorHex: String = "#F5A623",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.entries = []
    }
}

// MARK: - Pinboard Entry (Junction)

@Model
final class TheaClipPinboardEntry {
    @Attribute(.unique) var id: UUID
    var addedAt: Date
    var sortOrder: Int
    var note: String?

    var clipEntry: TheaClipEntry?
    var pinboard: TheaClipPinboard?

    init(
        id: UUID = UUID(),
        addedAt: Date = Date(),
        sortOrder: Int = 0,
        note: String? = nil,
        clipEntry: TheaClipEntry? = nil,
        pinboard: TheaClipPinboard? = nil
    ) {
        self.id = id
        self.addedAt = addedAt
        self.sortOrder = sortOrder
        self.note = note
        self.clipEntry = clipEntry
        self.pinboard = pinboard
    }
}

// MARK: - Identifiable Conformance

extension TheaClipEntry: Identifiable {}
extension TheaClipPinboard: Identifiable {}
extension TheaClipPinboardEntry: Identifiable {}
