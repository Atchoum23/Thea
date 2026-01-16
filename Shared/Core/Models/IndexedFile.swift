import Foundation
import SwiftData

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

  init(
    id: UUID = UUID(),
    path: String,
    name: String,
    size: Int64,
    indexedAt: Date = Date(),
    lastModified: Date = Date(),
    contentHash: String? = nil,
    fileType: String = "",
    isIndexed: Bool = true
  ) {
    self.id = id
    self.path = path
    self.name = name
    self.size = size
    self.indexedAt = indexedAt
    self.lastModified = lastModified
    self.contentHash = contentHash
    self.fileType = URL(fileURLWithPath: path).pathExtension
    self.isIndexed = isIndexed
  }
}

extension IndexedFile: Identifiable {}
