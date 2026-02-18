//
//  SpotlightService.swift
//  Thea
//
//  Core Spotlight integration for indexing conversations and content
//

import Combine
import CoreSpotlight
import Foundation
#if canImport(MobileCoreServices)
    import MobileCoreServices
#endif
import UniformTypeIdentifiers

// MARK: - Spotlight Service

/// Service for managing Spotlight search integration
@MainActor
public class SpotlightService: ObservableObject {
    public static let shared = SpotlightService()

    // MARK: - Published State

    @Published public private(set) var indexedItemCount = 0
    @Published public private(set) var isIndexing = false
    @Published public private(set) var lastIndexDate: Date?

    // MARK: - Configuration

    public var indexConversations = true
    public var indexProjects = true
    public var indexKnowledge = true
    public var indexNotes = true

    // MARK: - Private Properties

    // CSSearchableIndex is thread-safe internally but not marked as Sendable
    nonisolated(unsafe) private let searchableIndex: CSSearchableIndex
    private let domainIdentifier = "app.thea"

    // MARK: - Initialization

    private init() {
        searchableIndex = CSSearchableIndex.default()
    }

    // MARK: - Indexing Methods

    /// Index a conversation for Spotlight search
    public func indexConversation(_ conversation: SpotlightConversation) async throws {
        guard indexConversations else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.message)
        attributeSet.title = conversation.title
        attributeSet.contentDescription = conversation.preview
        attributeSet.keywords = conversation.keywords
        attributeSet.lastUsedDate = conversation.lastUpdated
        attributeSet.creator = "Thea AI"
        attributeSet.contentCreationDate = conversation.createdAt
        attributeSet.contentModificationDate = conversation.lastUpdated
        attributeSet.relatedUniqueIdentifier = conversation.id.uuidString

        // Add custom attributes
        if let messageCountKey = CSCustomAttributeKey(keyName: "messageCount") {
            attributeSet.setValue(conversation.messageCount as NSNumber, forCustomKey: messageCountKey)
        }
        if let aiModelKey = CSCustomAttributeKey(keyName: "aiModel") {
            attributeSet.setValue(conversation.aiModel as NSString, forCustomKey: aiModelKey)
        }

        // Add thumbnail if available
        if let thumbnailData = conversation.thumbnailData {
            attributeSet.thumbnailData = thumbnailData
        }

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "conversation-\(conversation.id.uuidString)",
            domainIdentifier: "\(domainIdentifier).conversations",
            attributeSet: attributeSet
        )

        // Set expiration (optional)
        searchableItem.expirationDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())

        try await searchableIndex.indexSearchableItems([searchableItem])
        indexedItemCount += 1
        lastIndexDate = Date()
    }

    /// Index a project for Spotlight search
    public func indexProject(_ project: SpotlightProject) async throws {
        guard indexProjects else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.folder)
        attributeSet.title = project.name
        attributeSet.contentDescription = project.description
        attributeSet.keywords = project.tags
        attributeSet.lastUsedDate = project.lastModified
        attributeSet.contentCreationDate = project.createdAt
        attributeSet.path = project.path

        // Project-specific attributes
        if let fileCountKey = CSCustomAttributeKey(keyName: "fileCount") {
            attributeSet.setValue(project.fileCount as NSNumber, forCustomKey: fileCountKey)
        }
        if let languageKey = CSCustomAttributeKey(keyName: "language") {
            attributeSet.setValue(project.primaryLanguage as NSString, forCustomKey: languageKey)
        }

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "project-\(project.id.uuidString)",
            domainIdentifier: "\(domainIdentifier).projects",
            attributeSet: attributeSet
        )

        try await searchableIndex.indexSearchableItems([searchableItem])
        indexedItemCount += 1
    }

    /// Index a knowledge item for Spotlight search
    public func indexKnowledgeItem(_ item: SpotlightKnowledgeItem) async throws {
        guard indexKnowledge else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.text)
        attributeSet.title = item.title
        attributeSet.contentDescription = item.content
        attributeSet.keywords = item.tags
        attributeSet.subject = item.category
        attributeSet.contentCreationDate = item.createdAt

        // Knowledge-specific
        if let sourceKey = CSCustomAttributeKey(keyName: "source") {
            attributeSet.setValue(item.source as NSString, forCustomKey: sourceKey)
        }
        if let confidenceKey = CSCustomAttributeKey(keyName: "confidence") {
            attributeSet.setValue(item.confidence as NSNumber, forCustomKey: confidenceKey)
        }

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "knowledge-\(item.id.uuidString)",
            domainIdentifier: "\(domainIdentifier).knowledge",
            attributeSet: attributeSet
        )

        try await searchableIndex.indexSearchableItems([searchableItem])
        indexedItemCount += 1
    }

    /// Index an AI-generated note
    public func indexNote(_ note: SpotlightNote) async throws {
        guard indexNotes else { return }

        let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.plainText)
        attributeSet.title = note.title
        attributeSet.contentDescription = note.content.prefix(500).description
        attributeSet.textContent = note.content
        attributeSet.keywords = note.keywords
        attributeSet.contentCreationDate = note.createdAt
        attributeSet.contentModificationDate = note.modifiedAt

        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "note-\(note.id.uuidString)",
            domainIdentifier: "\(domainIdentifier).notes",
            attributeSet: attributeSet
        )

        try await searchableIndex.indexSearchableItems([searchableItem])
        indexedItemCount += 1
    }

    // MARK: - Batch Operations

    /// Re-index all content
    public func reindexAll() async throws {
        isIndexing = true
        defer { isIndexing = false }

        // Delete all existing items
        try await deleteAllItems()

        // Re-index all content types
        // This would integrate with data sources
    }

    /// Index multiple items efficiently
    public func batchIndex(
        conversations: [SpotlightConversation] = [],
        projects: [SpotlightProject] = [],
        knowledge _: [SpotlightKnowledgeItem] = [],
        notes _: [SpotlightNote] = []
    ) async throws {
        isIndexing = true
        defer { isIndexing = false }

        var items: [CSSearchableItem] = []

        // Prepare conversation items
        for conversation in conversations where indexConversations {
            let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.message)
            attributeSet.title = conversation.title
            attributeSet.contentDescription = conversation.preview
            attributeSet.keywords = conversation.keywords
            attributeSet.lastUsedDate = conversation.lastUpdated

            let item = CSSearchableItem(
                uniqueIdentifier: "conversation-\(conversation.id.uuidString)",
                domainIdentifier: "\(domainIdentifier).conversations",
                attributeSet: attributeSet
            )
            items.append(item)
        }

        // Prepare project items
        for project in projects where indexProjects {
            let attributeSet = CSSearchableItemAttributeSet(contentType: UTType.folder)
            attributeSet.title = project.name
            attributeSet.contentDescription = project.description
            attributeSet.keywords = project.tags

            let item = CSSearchableItem(
                uniqueIdentifier: "project-\(project.id.uuidString)",
                domainIdentifier: "\(domainIdentifier).projects",
                attributeSet: attributeSet
            )
            items.append(item)
        }

        // Index all at once
        if !items.isEmpty {
            try await searchableIndex.indexSearchableItems(items)
            indexedItemCount += items.count
        }

        lastIndexDate = Date()
    }

    // MARK: - Deletion

    /// Delete a specific item from the index
    public func deleteItem(withIdentifier identifier: String) async throws {
        try await searchableIndex.deleteSearchableItems(withIdentifiers: [identifier])
        indexedItemCount = max(0, indexedItemCount - 1)
    }

    /// Delete all items in a domain
    public func deleteItems(inDomain domain: String) async throws {
        try await searchableIndex.deleteSearchableItems(withDomainIdentifiers: ["\(domainIdentifier).\(domain)"])
    }

    /// Delete all indexed items
    public func deleteAllItems() async throws {
        try await searchableIndex.deleteAllSearchableItems()
        indexedItemCount = 0
    }

    // MARK: - Search

    /// Search indexed items
    public func search(query: String) async throws -> [SpotlightSearchResult] {
        try await withCheckedThrowingContinuation { continuation in
            let queryString = "title == \"*\(query)*\"cd || contentDescription == \"*\(query)*\"cd || keywords == \"*\(query)*\"cd"
            let queryContext = CSSearchQueryContext()
            queryContext.fetchAttributes = [
                "title",
                "contentDescription",
                "keywords",
                "lastUsedDate"
            ]
            let searchQuery = CSSearchQuery(queryString: queryString, queryContext: queryContext)

            var results: [SpotlightSearchResult] = []

            searchQuery.foundItemsHandler = { items in
                for item in items {
                    let result = SpotlightSearchResult(
                        identifier: item.uniqueIdentifier,
                        title: item.attributeSet.title ?? "",
                        description: item.attributeSet.contentDescription ?? "",
                        lastUsed: item.attributeSet.lastUsedDate
                    )
                    results.append(result)
                }
            }

            searchQuery.completionHandler = { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results)
                }
            }

            searchQuery.start()
        }
    }

    // MARK: - Activity Handling

    /// Handle Spotlight continuation activity
    public func handleActivity(_ activity: NSUserActivity) -> SpotlightActivityResult? {
        guard activity.activityType == CSSearchableItemActionType,
              let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else {
            return nil
        }

        // Parse the identifier to determine type
        let components = identifier.split(separator: "-")
        guard components.count >= 2 else { return nil }

        let type = String(components[0])
        let id = String(components.dropFirst().joined(separator: "-"))

        return SpotlightActivityResult(type: type, identifier: id)
    }
}

// MARK: - Supporting Types

/// Spotlight-indexable representation of a Thea conversation.
public struct SpotlightConversation: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let preview: String
    public let keywords: [String]
    public let messageCount: Int
    public let aiModel: String
    public let createdAt: Date
    public let lastUpdated: Date
    public let thumbnailData: Data?

    public init(
        id: UUID = UUID(),
        title: String,
        preview: String,
        keywords: [String] = [],
        messageCount: Int = 0,
        aiModel: String = "Claude",
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.keywords = keywords
        self.messageCount = messageCount
        self.aiModel = aiModel
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.thumbnailData = thumbnailData
    }
}

/// Spotlight-indexable representation of a code project.
public struct SpotlightProject: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let path: String
    public let tags: [String]
    public let fileCount: Int
    public let primaryLanguage: String
    public let createdAt: Date
    public let lastModified: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        path: String,
        tags: [String] = [],
        fileCount: Int = 0,
        primaryLanguage: String = "Swift",
        createdAt: Date = Date(),
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.path = path
        self.tags = tags
        self.fileCount = fileCount
        self.primaryLanguage = primaryLanguage
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

/// Spotlight-indexable representation of a knowledge base entry.
public struct SpotlightKnowledgeItem: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let content: String
    public let category: String
    public let tags: [String]
    public let source: String
    public let confidence: Double
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: String,
        tags: [String] = [],
        source: String,
        confidence: Double = 1.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

/// Spotlight-indexable representation of a user note.
public struct SpotlightNote: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let content: String
    public let keywords: [String]
    public let createdAt: Date
    public let modifiedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        keywords: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.keywords = keywords
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// A single result returned from a Core Spotlight search query.
public struct SpotlightSearchResult: Identifiable, Sendable {
    public let id: String
    public let identifier: String
    public let title: String
    public let description: String
    public let lastUsed: Date?

    public init(identifier: String, title: String, description: String, lastUsed: Date?) {
        id = identifier
        self.identifier = identifier
        self.title = title
        self.description = description
        self.lastUsed = lastUsed
    }
}

/// The decoded content of an NSUserActivity handed off from Spotlight.
public struct SpotlightActivityResult: Sendable {
    public let type: String
    public let identifier: String
}
