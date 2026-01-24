// SpotlightIntegration.swift
// Spotlight search integration for conversations and content

import Foundation
import CoreSpotlight
import MobileCoreServices
import OSLog

// MARK: - Spotlight Integration Manager

/// Manages Spotlight indexing for Thea content
@MainActor
public final class SpotlightIntegration: ObservableObject {
    public static let shared = SpotlightIntegration()

    private let logger = Logger(subsystem: "com.thea.app", category: "Spotlight")

    // MARK: - Published State

    @Published public private(set) var isIndexing = false
    @Published public private(set) var indexedItemCount = 0
    @Published public private(set) var lastIndexDate: Date?

    // MARK: - Configuration

    private let domainIdentifier = "com.thea.app.conversations"

    // MARK: - Initialization

    private init() {
        loadIndexStats()
    }

    private func loadIndexStats() {
        indexedItemCount = UserDefaults.standard.integer(forKey: "spotlight.indexedCount")
        if let timestamp = UserDefaults.standard.object(forKey: "spotlight.lastIndexDate") as? Date {
            lastIndexDate = timestamp
        }
    }

    private func saveIndexStats() {
        UserDefaults.standard.set(indexedItemCount, forKey: "spotlight.indexedCount")
        UserDefaults.standard.set(lastIndexDate, forKey: "spotlight.lastIndexDate")
    }

    // MARK: - Indexing

    /// Index a conversation for Spotlight search
    public func indexConversation(_ conversation: IndexableConversation) async {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        // Basic metadata
        attributeSet.title = conversation.title
        attributeSet.contentDescription = conversation.summary
        attributeSet.keywords = conversation.keywords

        // Timestamps
        attributeSet.contentCreationDate = conversation.createdAt
        attributeSet.contentModificationDate = conversation.updatedAt

        // Custom attributes
        attributeSet.creator = "Thea AI"
        attributeSet.kind = "AI Conversation"

        // Thumbnail if available
        if let thumbnailData = conversation.thumbnailData {
            attributeSet.thumbnailData = thumbnailData
        }

        let item = CSSearchableItem(
            uniqueIdentifier: conversation.id,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        // Set expiration (optional)
        item.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())

        do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
            logger.info("Indexed conversation: \(conversation.id)")
            indexedItemCount += 1
            saveIndexStats()
        } catch {
            logger.error("Failed to index conversation: \(error.localizedDescription)")
        }
    }

    /// Index multiple conversations
    public func indexConversations(_ conversations: [IndexableConversation]) async {
        isIndexing = true
        defer {
            isIndexing = false
            lastIndexDate = Date()
            saveIndexStats()
        }

        let items = conversations.map { conversation -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = conversation.title
            attributeSet.contentDescription = conversation.summary
            attributeSet.keywords = conversation.keywords
            attributeSet.contentCreationDate = conversation.createdAt
            attributeSet.contentModificationDate = conversation.updatedAt
            attributeSet.creator = "Thea AI"
            attributeSet.kind = "AI Conversation"

            return CSSearchableItem(
                uniqueIdentifier: conversation.id,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
            logger.info("Indexed \(items.count) conversations")
            indexedItemCount += items.count
        } catch {
            logger.error("Failed to index conversations: \(error.localizedDescription)")
        }
    }

    /// Remove a conversation from index
    public func removeConversation(_ conversationId: String) async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [conversationId])
            logger.info("Removed conversation from index: \(conversationId)")
            indexedItemCount = max(0, indexedItemCount - 1)
            saveIndexStats()
        } catch {
            logger.error("Failed to remove conversation: \(error.localizedDescription)")
        }
    }

    /// Remove all indexed conversations
    public func removeAllConversations() async {
        do {
            try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
            logger.info("Removed all conversations from index")
            indexedItemCount = 0
            saveIndexStats()
        } catch {
            logger.error("Failed to remove all conversations: \(error.localizedDescription)")
        }
    }

    /// Reindex all content
    public func reindexAll() async {
        isIndexing = true
        defer { isIndexing = false }

        // First, clear existing index
        await removeAllConversations()

        // Then reindex from data store
        // This would integrate with your conversation storage
        // let conversations = await ConversationStore.shared.getAllConversations()
        // await indexConversations(conversations.map { IndexableConversation(from: $0) })

        logger.info("Reindex complete")
        lastIndexDate = Date()
        saveIndexStats()
    }

    // MARK: - Search Continuation

    /// Handle user activity from Spotlight search
    public func handleSpotlightActivity(_ userActivity: NSUserActivity) -> String? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }

        logger.info("Opening conversation from Spotlight: \(identifier)")
        return identifier
    }
}

// MARK: - Types

public struct IndexableConversation {
    public let id: String
    public let title: String
    public let summary: String
    public let keywords: [String]
    public let createdAt: Date
    public let updatedAt: Date
    public let thumbnailData: Data?

    public init(
        id: String,
        title: String,
        summary: String,
        keywords: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.keywords = keywords
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.thumbnailData = thumbnailData
    }
}
