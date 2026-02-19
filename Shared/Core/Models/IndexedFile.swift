import Foundation
@preconcurrency import SwiftData

@Model
final class IndexedFile {
    @Attribute(.unique) var id: UUID
    var path: String
    var name: String
    var size: Int64
    var indexedAt: Date
    var lastModified: Date
    var contentHash: String?
    var fileType: String
    var isIndexed: Bool

    // periphery:ignore - Reserved: init(id:path:name:size:indexedAt:lastModified:contentHash:fileType:isIndexed:) initializer reserved for future feature activation
    init(
        id: UUID = UUID(),
        path: String,
        name: String,
        size: Int64,
        indexedAt: Date = Date(),
        lastModified: Date = Date(),
        contentHash: String? = nil,
        fileType _: String = "",
        isIndexed: Bool = true
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.size = size
        self.indexedAt = indexedAt
        self.lastModified = lastModified
        self.contentHash = contentHash
        fileType = URL(fileURLWithPath: path).pathExtension
        self.isIndexed = isIndexed
    }
}

extension IndexedFile: Identifiable {}
