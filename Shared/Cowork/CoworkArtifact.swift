import Foundation
import UniformTypeIdentifiers

/// Represents a file artifact created during Cowork task execution
struct CoworkArtifact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var fileURL: URL
    var fileType: ArtifactType
    var createdAt: Date
    var modifiedAt: Date
    var size: Int64
    var isIntermediate: Bool
    var stepId: UUID?
    var description: String?
    var tags: [String]

    enum ArtifactType: String, Codable, CaseIterable {
        case document = "Document"
        case spreadsheet = "Spreadsheet"
        case presentation = "Presentation"
        case image = "Image"
        case code = "Code"
        case data = "Data"
        case archive = "Archive"
        case other = "Other"

        var icon: String {
            switch self {
            case .document: return "doc.fill"
            case .spreadsheet: return "tablecells.fill"
            case .presentation: return "play.rectangle.fill"
            case .image: return "photo.fill"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .data: return "cylinder.fill"
            case .archive: return "archivebox.fill"
            case .other: return "doc.fill"
            }
        }

        var color: String {
            switch self {
            case .document: return "blue"
            case .spreadsheet: return "green"
            case .presentation: return "orange"
            case .image: return "purple"
            case .code: return "cyan"
            case .data: return "yellow"
            case .archive: return "brown"
            case .other: return "gray"
            }
        }

        /// Determine artifact type from file extension
        static func from(extension ext: String) -> ArtifactType {
            switch ext.lowercased() {
            case "doc", "docx", "pdf", "txt", "rtf", "md", "markdown":
                return .document
            case "xls", "xlsx", "csv", "tsv", "numbers":
                return .spreadsheet
            case "ppt", "pptx", "key", "keynote":
                return .presentation
            case "jpg", "jpeg", "png", "gif", "svg", "webp", "heic", "tiff", "bmp":
                return .image
            case "swift", "py", "js", "ts", "java", "cpp", "c", "h", "go", "rs", "rb", "php", "html", "css", "json", "xml", "yaml", "yml":
                return .code
            case "sqlite", "db", "realm", "plist":
                return .data
            case "zip", "tar", "gz", "rar", "7z", "dmg":
                return .archive
            default:
                return .other
            }
        }

        static func from(url: URL) -> ArtifactType {
            from(extension: url.pathExtension)
        }

        static func from(utType: UTType?) -> ArtifactType {
            guard let type = utType else { return .other }

            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .presentation) { return .presentation }
            if type.conforms(to: .spreadsheet) { return .spreadsheet }
            if type.conforms(to: .sourceCode) { return .code }
            if type.conforms(to: .archive) { return .archive }
            if type.conforms(to: .database) { return .data }
            if type.conforms(to: .text) || type.conforms(to: .pdf) { return .document }

            return .other
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        fileURL: URL,
        fileType: ArtifactType? = nil,
        size: Int64 = 0,
        isIntermediate: Bool = false,
        stepId: UUID? = nil,
        description: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.fileType = fileType ?? ArtifactType.from(url: fileURL)
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.size = size
        self.isIntermediate = isIntermediate
        self.stepId = stepId
        self.description = description
        self.tags = tags
    }

    /// Create artifact from existing file
    static func from(url: URL, isIntermediate: Bool = false, stepId: UUID? = nil) -> CoworkArtifact? {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else { return nil }

        var size: Int64 = 0
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? Int64 {
            size = fileSize
        }

        return CoworkArtifact(
            name: url.lastPathComponent,
            fileURL: url,
            size: size,
            isIntermediate: isIntermediate,
            stepId: stepId
        )
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var fileExtension: String {
        fileURL.pathExtension.lowercased()
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    mutating func updateSize() {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let fileSize = attrs[.size] as? Int64 {
            size = fileSize
            modifiedAt = Date()
        }
    }

    mutating func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }

    mutating func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Artifact Collection Helpers

extension Array where Element == CoworkArtifact {
    var totalSize: Int64 {
        reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    func byType(_ type: CoworkArtifact.ArtifactType) -> [CoworkArtifact] {
        filter { $0.fileType == type }
    }

    var finalArtifacts: [CoworkArtifact] {
        filter { !$0.isIntermediate }
    }

    var intermediateArtifacts: [CoworkArtifact] {
        filter { $0.isIntermediate }
    }

    func forStep(_ stepId: UUID) -> [CoworkArtifact] {
        filter { $0.stepId == stepId }
    }
}
