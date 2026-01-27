//
//  TheaImporter.swift
//  TheaSpotlightImporter
//
//  Created by Thea
//

#if os(macOS)
    import AppKit
    import CoreSpotlight
    import Foundation
    import os.log

    /// Spotlight Importer for Thea
    /// Indexes Thea artifacts, conversations, and memories for system-wide search
    ///
    /// This service provides spotlight indexing for Thea documents
    /// Note: Modern Spotlight uses CSSearchableIndex API rather than mdimporter plugins
    public final class TheaSpotlightIndexer {
        public static let shared = TheaSpotlightIndexer()
        private let logger = Logger(subsystem: "app.thea.spotlight", category: "Indexer")
        private let searchableIndex = CSSearchableIndex(name: "app.thea")

        private init() {}

        // MARK: - Public API

        /// Index a Thea artifact
        public func indexArtifact(_ artifact: SpotlightArtifact) async throws {
            let attributes = CSSearchableItemAttributeSet(contentType: .json)

            attributes.title = artifact.title
            attributes.contentDescription = artifact.content
            attributes.keywords = artifact.tags
            attributes.contentCreationDate = artifact.created
            attributes.contentModificationDate = artifact.modified
            attributes.displayName = artifact.title
            attributes.thumbnailData = createThumbnailData(for: "artifact")

            let item = CSSearchableItem(
                uniqueIdentifier: "artifact:\(artifact.id)",
                domainIdentifier: "app.thea.artifacts",
                attributeSet: attributes
            )

            try await searchableIndex.indexSearchableItems([item])
            logger.info("Indexed artifact: \(artifact.title)")
        }

        /// Index a Thea conversation
        public func indexConversation(_ conversation: SpotlightConversation) async throws {
            let attributes = CSSearchableItemAttributeSet(contentType: .json)

            attributes.title = conversation.title
            let messageContent = conversation.messages.map { "\($0.role): \($0.content)" }.joined(separator: "\n")
            attributes.contentDescription = String(messageContent.prefix(500))
            attributes.textContent = messageContent
            attributes.contentCreationDate = conversation.created
            attributes.contentModificationDate = conversation.lastActive
            attributes.displayName = conversation.title
            attributes.thumbnailData = createThumbnailData(for: "conversation")

            let item = CSSearchableItem(
                uniqueIdentifier: "conversation:\(conversation.id)",
                domainIdentifier: "app.thea.conversations",
                attributeSet: attributes
            )

            try await searchableIndex.indexSearchableItems([item])
            logger.info("Indexed conversation: \(conversation.title)")
        }

        /// Index a Thea memory
        public func indexMemory(_ memory: SpotlightMemory) async throws {
            let attributes = CSSearchableItemAttributeSet(contentType: .json)

            attributes.title = memory.title ?? "Memory"
            attributes.contentDescription = memory.content
            attributes.textContent = memory.content
            attributes.keywords = [memory.category]
            attributes.contentCreationDate = memory.created
            attributes.displayName = memory.title ?? "Thea Memory"
            attributes.thumbnailData = createThumbnailData(for: "memory")

            let item = CSSearchableItem(
                uniqueIdentifier: "memory:\(memory.id)",
                domainIdentifier: "app.thea.memories",
                attributeSet: attributes
            )

            try await searchableIndex.indexSearchableItems([item])
            logger.info("Indexed memory: \(memory.title ?? "untitled")")
        }

        /// Remove an item from the index
        public func removeItem(identifier: String) async throws {
            try await searchableIndex.deleteSearchableItems(withIdentifiers: [identifier])
            logger.info("Removed item: \(identifier)")
        }

        /// Remove all items in a domain
        public func removeAllItems(inDomain domain: String) async throws {
            try await searchableIndex.deleteSearchableItems(withDomainIdentifiers: [domain])
            logger.info("Removed all items in domain: \(domain)")
        }

        /// Remove all Thea items from Spotlight
        public func removeAllTheaItems() async throws {
            try await searchableIndex.deleteAllSearchableItems()
            logger.info("Removed all Thea items from Spotlight")
        }

        // MARK: - Helpers

        private func createThumbnailData(for type: String) -> Data? {
            let size: CGFloat = 128
            let image = NSImage(size: NSSize(width: size, height: size))

            image.lockFocus()

            let color: NSColor = switch type {
            case "artifact":
                .systemPurple
            case "conversation":
                .systemBlue
            case "memory":
                .systemOrange
            default:
                .systemGray
            }

            // Draw rounded rect background
            let rect = NSRect(x: 0, y: 0, width: size, height: size)
            let path = NSBezierPath(roundedRect: rect, xRadius: 20, yRadius: 20)
            color.setFill()
            path.fill()

            // Draw icon symbol
            let iconName = switch type {
            case "artifact":
                "doc.text.fill"
            case "conversation":
                "bubble.left.and.bubble.right.fill"
            case "memory":
                "brain.head.profile"
            default:
                "star.fill"
            }

            if let symbol = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                let symbolConfig = NSImage.SymbolConfiguration(pointSize: 48, weight: .medium)
                let configuredSymbol = symbol.withSymbolConfiguration(symbolConfig)

                NSColor.white.setFill()
                let symbolSize: CGFloat = 64
                let symbolRect = NSRect(
                    x: (size - symbolSize) / 2,
                    y: (size - symbolSize) / 2,
                    width: symbolSize,
                    height: symbolSize
                )
                configuredSymbol?.draw(in: symbolRect)
            }

            image.unlockFocus()

            // Convert to PNG data
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData)
            else {
                return nil
            }

            return bitmap.representation(using: .png, properties: [:])
        }
    }

    // MARK: - Data Models for Spotlight

    public struct SpotlightArtifact: Codable, Sendable {
        public let id: String
        public let title: String
        public let type: String
        public let content: String
        public let created: Date
        public let modified: Date
        public let tags: [String]

        public init(id: String, title: String, type: String, content: String, created: Date, modified: Date, tags: [String]) {
            self.id = id
            self.title = title
            self.type = type
            self.content = content
            self.created = created
            self.modified = modified
            self.tags = tags
        }
    }

    public struct SpotlightConversation: Codable, Sendable {
        public let id: String
        public let title: String
        public let messages: [SpotlightMessage]
        public let created: Date
        public let lastActive: Date

        public init(id: String, title: String, messages: [SpotlightMessage], created: Date, lastActive: Date) {
            self.id = id
            self.title = title
            self.messages = messages
            self.created = created
            self.lastActive = lastActive
        }
    }

    public struct SpotlightMessage: Codable, Sendable {
        public let role: String
        public let content: String

        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }

    public struct SpotlightMemory: Codable, Sendable {
        public let id: String
        public let title: String?
        public let content: String
        public let category: String
        public let importance: Int
        public let created: Date

        public init(id: String, title: String?, content: String, category: String, importance: Int, created: Date) {
            self.id = id
            self.title = title
            self.content = content
            self.category = category
            self.importance = importance
            self.created = created
        }
    }
#endif
