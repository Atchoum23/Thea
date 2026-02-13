//
//  TheaAssistantSchemas.swift
//  Thea
//
//  Assistant Schema conformance for Apple Intelligence / Siri integration
//  Requires iOS 18.0+ / macOS 15.0+ / watchOS 11.0+ / tvOS 18.0+
//

import AppIntents
import CoreLocation
import Foundation

// MARK: - System Search Intent

/// Search across Thea's conversations and knowledge base via Siri / Apple Intelligence
@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
@available(watchOS, unavailable)
@AppIntent(schema: .system.search)
public struct TheaSearchIntent: ShowInAppSearchResultsIntent {
    nonisolated(unsafe) public static var searchScopes: [StringSearchScope] = [.general]

    public var criteria: StringSearchCriteria

    public init() {
        self.criteria = StringSearchCriteria(term: "")
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Journal Entry Entity

/// Represents a knowledge base entry for Apple Intelligence
@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
@AppEntity(schema: .journal.entry)
public struct TheaKnowledgeEntryEntity: Identifiable {
    public struct TheaKnowledgeEntryQuery: EntityStringQuery {
        public init() {}

        @MainActor
        public func entities(for identifiers: [TheaKnowledgeEntryEntity.ID]) async throws -> [TheaKnowledgeEntryEntity] {
            []
        }

        public func entities(matching string: String) async throws -> [TheaKnowledgeEntryEntity] {
            []
        }

        public func suggestedEntities() async throws -> [TheaKnowledgeEntryEntity] {
            []
        }
    }

    nonisolated(unsafe) public static var defaultQuery = TheaKnowledgeEntryQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: title ?? "Untitled Entry")
    }

    public let id: UUID
    public var title: String?
    public var message: String?
    public var entryDate: Date?
    public var location: CLPlacemark?
    public var mediaItems: [IntentFile]

    public init(id: UUID, title: String?, message: String?, entryDate: Date?) {
        self.id = id
        self.title = title
        self.message = message
        self.entryDate = entryDate
        self.mediaItems = []
    }
}

// MARK: - Create Journal Entry Intent

/// Create a knowledge base entry via Siri / Apple Intelligence
@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
@AppIntent(schema: .journal.createEntry)
public struct TheaCreateEntryIntent: AppIntent {
    public var title: String?
    public var message: String
    public var entryDate: Date?
    public var location: CLPlacemark?
    public var mediaItems: [IntentFile]

    nonisolated(unsafe) public static var title: LocalizedStringResource = "Create Knowledge Entry"

    public init() {
        self.message = ""
        self.mediaItems = []
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TheaKnowledgeEntryEntity> {
        let entry = TheaKnowledgeEntryEntity(
            id: UUID(),
            title: title,
            message: message,
            entryDate: entryDate ?? Date()
        )
        return .result(value: entry)
    }
}

// MARK: - Search Journal Entries Intent

/// Search knowledge base entries via Siri / Apple Intelligence
@available(iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
@AppIntent(schema: .journal.search)
public struct TheaSearchEntriesIntent: AppIntent {
    public var criteria: StringSearchCriteria

    nonisolated(unsafe) public static var title: LocalizedStringResource = "Search Knowledge Base"

    public init() {
        self.criteria = StringSearchCriteria(term: "")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TheaKnowledgeEntryEntity]> {
        .result(value: [])
    }
}
