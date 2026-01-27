// SpotlightIntegration.swift
// Deep Spotlight integration for searchable content and quick actions

import Foundation
import OSLog
#if canImport(CoreSpotlight)
    import CoreSpotlight
#endif
#if canImport(MobileCoreServices)
    import MobileCoreServices
#endif

// MARK: - Spotlight Integration

/// Deep Spotlight integration for indexing conversations, artifacts, and quick actions
@MainActor
public final class SpotlightIntegration: ObservableObject {
    public static let shared = SpotlightIntegration()

    private let logger = Logger(subsystem: "com.thea.app", category: "Spotlight")

    // Domain identifiers
    private let conversationDomain = "com.thea.conversations"
    private let artifactDomain = "com.thea.artifacts"
    private let memoryDomain = "com.thea.memories"
    private let agentDomain = "com.thea.agents"
    private let actionDomain = "com.thea.actions"

    // CSSearchableIndex is thread-safe internally but not marked as Sendable
    #if canImport(CoreSpotlight)
        nonisolated(unsafe) private let searchableIndex = CSSearchableIndex.default()
    #endif

    // MARK: - Published State

    @Published public private(set) var indexedItemCount = 0
    @Published public private(set) var isIndexing = false
    @Published public private(set) var lastIndexDate: Date?

    // MARK: - Initialization

    private init() {}

    // MARK: - Index Conversations

    /// Index a conversation for Spotlight search
    public func indexConversation(
        id: String,
        title: String,
        preview: String,
        messages: [String],
        createdAt: Date,
        modifiedAt: Date,
        agentName: String? = nil,
        tags: [String] = []
    ) async {
        #if canImport(CoreSpotlight)
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = title
            attributeSet.contentDescription = preview
            attributeSet.textContent = messages.joined(separator: "\n")

            // Metadata
            attributeSet.creator = agentName ?? "Thea"
            attributeSet.contentCreationDate = createdAt
            attributeSet.contentModificationDate = modifiedAt
            attributeSet.keywords = tags + ["conversation", "chat", "ai"]

            // Thumbnail
            attributeSet.thumbnailData = createConversationThumbnail()

            // Ranking
            attributeSet.relatedUniqueIdentifier = id
            attributeSet.domainIdentifier = conversationDomain

            let item = CSSearchableItem(
                uniqueIdentifier: "conversation:\(id)",
                domainIdentifier: conversationDomain,
                attributeSet: attributeSet
            )
            item.expirationDate = Date().addingTimeInterval(86400 * 365) // 1 year

            do {
                try await searchableIndex.indexSearchableItems([item])
                indexedItemCount += 1
                logger.debug("Indexed conversation: \(title)")
            } catch {
                logger.error("Failed to index conversation: \(error.localizedDescription)")
            }
        #endif
    }

    /// Index multiple conversations in batch
    public func indexConversations(_ conversations: [IndexableConversation]) async {
        #if canImport(CoreSpotlight)
            isIndexing = true
            defer { isIndexing = false }

            let domain = conversationDomain
            let count = await Self.performBatchIndexing(conversations: conversations, domain: domain)

            // swiftlint:disable:next empty_count
            guard count > 0 else { return }
            indexedItemCount += count
            lastIndexDate = Date()
            logger.info("Indexed \(count) conversations")
        #endif
    }

    #if canImport(CoreSpotlight)
    /// Perform the actual indexing in a static context to avoid Sendable issues
    nonisolated private static func performBatchIndexing(
        conversations: [IndexableConversation],
        domain: String
    ) async -> Int {
        let items = conversations.map { conversation -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = conversation.title
            attributeSet.contentDescription = conversation.preview
            attributeSet.textContent = conversation.content
            attributeSet.contentCreationDate = conversation.createdAt
            attributeSet.contentModificationDate = conversation.modifiedAt
            attributeSet.keywords = conversation.keywords + ["conversation", "chat", "ai"]
            attributeSet.domainIdentifier = domain

            return CSSearchableItem(
                uniqueIdentifier: "conversation:\(conversation.id)",
                domainIdentifier: domain,
                attributeSet: attributeSet
            )
        }

        do {
            try await CSSearchableIndex.default().indexSearchableItems(items)
            return items.count
        } catch {
            return 0
        }
    }
    #endif

    // MARK: - Index Artifacts

    /// Index a code artifact for Spotlight search
    public func indexArtifact(
        id: String,
        title: String,
        language: String,
        code: String,
        conversationId: String? = nil,
        createdAt: Date
    ) async {
        #if canImport(CoreSpotlight)
            let attributeSet = CSSearchableItemAttributeSet(contentType: .sourceCode)
            attributeSet.title = title
            attributeSet.contentDescription = "\(language) code artifact"
            attributeSet.textContent = code
            attributeSet.contentCreationDate = createdAt
            attributeSet.keywords = ["code", "artifact", language.lowercased(), "programming"]
            attributeSet.domainIdentifier = artifactDomain

            if let conversationId {
                attributeSet.relatedUniqueIdentifier = "conversation:\(conversationId)"
            }

            let item = CSSearchableItem(
                uniqueIdentifier: "artifact:\(id)",
                domainIdentifier: artifactDomain,
                attributeSet: attributeSet
            )

            do {
                try await searchableIndex.indexSearchableItems([item])
                indexedItemCount += 1
                logger.debug("Indexed artifact: \(title)")
            } catch {
                logger.error("Failed to index artifact: \(error.localizedDescription)")
            }
        #endif
    }

    // MARK: - Index Memories

    /// Index a memory for Spotlight search
    public func indexMemory(
        id: String,
        content: String,
        type: String,
        createdAt: Date
    ) async {
        #if canImport(CoreSpotlight)
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = "Memory: \(content.prefix(50))"
            attributeSet.contentDescription = content
            attributeSet.textContent = content
            attributeSet.contentCreationDate = createdAt
            attributeSet.keywords = ["memory", "fact", type, "knowledge"]
            attributeSet.domainIdentifier = memoryDomain

            let item = CSSearchableItem(
                uniqueIdentifier: "memory:\(id)",
                domainIdentifier: memoryDomain,
                attributeSet: attributeSet
            )

            do {
                try await searchableIndex.indexSearchableItems([item])
                indexedItemCount += 1
            } catch {
                logger.error("Failed to index memory: \(error.localizedDescription)")
            }
        #endif
    }

    // MARK: - Index Custom Agents

    /// Index a custom agent for Spotlight search
    public func indexAgent(
        id: String,
        name: String,
        description: String,
        capabilities: [String]
    ) async {
        #if canImport(CoreSpotlight)
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
            attributeSet.title = name
            attributeSet.contentDescription = description
            attributeSet.keywords = capabilities + ["agent", "assistant", "ai"]
            attributeSet.domainIdentifier = agentDomain

            let item = CSSearchableItem(
                uniqueIdentifier: "agent:\(id)",
                domainIdentifier: agentDomain,
                attributeSet: attributeSet
            )

            do {
                try await searchableIndex.indexSearchableItems([item])
                indexedItemCount += 1
                logger.debug("Indexed agent: \(name)")
            } catch {
                logger.error("Failed to index agent: \(error.localizedDescription)")
            }
        #endif
    }

    // MARK: - Index Quick Actions

    /// Index quick actions for Spotlight search
    public func indexQuickActions() async {
        #if canImport(CoreSpotlight)
            let actions: [(id: String, title: String, description: String, keywords: [String])] = [
                ("new_conversation", "New Conversation", "Start a new AI conversation", ["new", "chat", "conversation", "start"]),
                ("voice_input", "Voice Input", "Start voice conversation", ["voice", "speak", "microphone", "talk"]),
                ("quick_translate", "Quick Translate", "Translate text quickly", ["translate", "language", "convert"]),
                ("summarize_clipboard", "Summarize Clipboard", "Summarize copied text", ["summarize", "clipboard", "tldr"]),
                ("generate_code", "Generate Code", "Generate code snippet", ["code", "programming", "generate"]),
                ("explain_code", "Explain Code", "Explain code in clipboard", ["explain", "code", "understand"]),
                ("write_email", "Write Email", "Draft an email", ["email", "write", "compose", "mail"]),
                ("brainstorm", "Brainstorm Ideas", "Generate ideas on a topic", ["brainstorm", "ideas", "creative"]),
                ("proofread", "Proofread Text", "Check grammar and spelling", ["proofread", "grammar", "spelling", "check"]),
                ("ask_about_screen", "Ask About Screen", "Ask about visible content", ["screen", "visible", "screenshot"])
            ]

            var items: [CSSearchableItem] = []

            for action in actions {
                let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
                attributeSet.title = action.title
                attributeSet.contentDescription = action.description
                attributeSet.keywords = action.keywords + ["thea", "action", "quick"]
                attributeSet.domainIdentifier = actionDomain

                // Make actions rank higher
                attributeSet.rankingHint = 1.0

                let item = CSSearchableItem(
                    uniqueIdentifier: "action:\(action.id)",
                    domainIdentifier: actionDomain,
                    attributeSet: attributeSet
                )

                items.append(item)
            }

            do {
                try await searchableIndex.indexSearchableItems(items)
                indexedItemCount += items.count
                logger.info("Indexed \(items.count) quick actions")
            } catch {
                logger.error("Failed to index quick actions: \(error.localizedDescription)")
            }
        #endif
    }

    // MARK: - Remove Items

    /// Remove a specific item from the index
    public func removeItem(identifier: String) async {
        #if canImport(CoreSpotlight)
            do {
                try await searchableIndex.deleteSearchableItems(withIdentifiers: [identifier])
                indexedItemCount = max(0, indexedItemCount - 1)
                logger.debug("Removed item: \(identifier)")
            } catch {
                logger.error("Failed to remove item: \(error.localizedDescription)")
            }
        #endif
    }

    /// Remove all items in a domain
    public func removeAllItems(in domain: SpotlightDomain) async {
        #if canImport(CoreSpotlight)
            let domainIdentifier: String = switch domain {
            case .conversations: conversationDomain
            case .artifacts: artifactDomain
            case .memories: memoryDomain
            case .agents: agentDomain
            case .actions: actionDomain
            }

            do {
                try await searchableIndex.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier])
                logger.info("Removed all items in domain: \(domainIdentifier)")
            } catch {
                logger.error("Failed to remove domain items: \(error.localizedDescription)")
            }
        #endif
    }

    /// Remove all indexed items
    public func removeAllItems() async {
        #if canImport(CoreSpotlight)
            do {
                try await searchableIndex.deleteAllSearchableItems()
                indexedItemCount = 0
                logger.info("Removed all indexed items")
            } catch {
                logger.error("Failed to remove all items: \(error.localizedDescription)")
            }
        #endif
    }

    // MARK: - Handle Spotlight Results

    /// Handle when user taps a Spotlight result
    public func handleSpotlightActivity(_ userActivity: NSUserActivity) -> SpotlightResult? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else {
            return nil
        }

        let components = identifier.split(separator: ":")
        guard components.count == 2 else { return nil }

        let type = String(components[0])
        let id = String(components[1])

        switch type {
        case "conversation":
            return .conversation(id: id)
        case "artifact":
            return .artifact(id: id)
        case "memory":
            return .memory(id: id)
        case "agent":
            return .agent(id: id)
        case "action":
            return .action(id: id)
        default:
            return nil
        }
    }

    // MARK: - Full Index Rebuild

    /// Rebuild the entire Spotlight index
    public func rebuildIndex() async {
        isIndexing = true
        defer { isIndexing = false }

        // Clear existing index
        await removeAllItems()

        // Re-index quick actions
        await indexQuickActions()

        // Re-index other content (would be called from respective managers)
        lastIndexDate = Date()
        logger.info("Index rebuild complete")
    }

    // MARK: - Helpers

    private func createConversationThumbnail() -> Data? {
        // Create a simple thumbnail for conversations
        nil // Implement with CoreGraphics if needed
    }
}

// MARK: - Spotlight Domain

public enum SpotlightDomain: String, CaseIterable, Sendable {
    case conversations
    case artifacts
    case memories
    case agents
    case actions
}

// MARK: - Spotlight Result

public enum SpotlightResult: Sendable {
    case conversation(id: String)
    case artifact(id: String)
    case memory(id: String)
    case agent(id: String)
    case action(id: String)
}

// MARK: - Indexable Types

public struct IndexableConversation: Sendable {
    public let id: String
    public let title: String
    public let preview: String
    public let content: String
    public let createdAt: Date
    public let modifiedAt: Date
    public let keywords: [String]

    public init(
        id: String,
        title: String,
        preview: String,
        content: String,
        createdAt: Date,
        modifiedAt: Date,
        keywords: [String] = []
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.keywords = keywords
    }
}
