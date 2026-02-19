#if os(macOS)
    import Foundation
    import OSLog
    import UniformTypeIdentifiers

    private let coworkArtifactLogger = Logger(subsystem: "ai.thea.app", category: "CoworkArtifact")

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
                case .document: "doc.fill"
                case .spreadsheet: "tablecells.fill"
                case .presentation: "play.rectangle.fill"
                case .image: "photo.fill"
                case .code: "chevron.left.forwardslash.chevron.right"
                case .data: "cylinder.fill"
                case .archive: "archivebox.fill"
                case .other: "doc.fill"
                }
            }

            var color: String {
                switch self {
                case .document: "blue"
                case .spreadsheet: "green"
                case .presentation: "orange"
                case .image: "purple"
                case .code: "cyan"
                case .data: "yellow"
                case .archive: "brown"
                case .other: "gray"
                }
            }

            /// Determine artifact type from file extension
            static func from(extension ext: String) -> ArtifactType {
                switch ext.lowercased() {
                case "doc", "docx", "pdf", "txt", "rtf", "md", "markdown":
                    .document
                case "xls", "xlsx", "csv", "tsv", "numbers":
                    .spreadsheet
                case "ppt", "pptx", "key", "keynote":
                    .presentation
                case "jpg", "jpeg", "png", "gif", "svg", "webp", "heic", "tiff", "bmp":
                    .image
                case "swift", "py", "js", "ts", "java", "cpp", "c", "h", "go", "rs", "rb", "php", "html", "css", "json", "xml", "yaml", "yml":
                    .code
                case "sqlite", "db", "realm", "plist":
                    .data
                case "zip", "tar", "gz", "rar", "7z", "dmg":
                    .archive
                default:
                    .other
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
                // periphery:ignore - Reserved: from(utType:) static method reserved for future feature activation
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
            createdAt = Date()
            modifiedAt = Date()
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
            do {
                let attrs = try fileManager.attributesOfItem(atPath: url.path)
                if let fileSize = attrs[.size] as? Int64 {
                    size = fileSize
                }
            } catch {
                coworkArtifactLogger.error("Failed to get file attributes for \(url.lastPathComponent): \(error)")
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
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attrs[.size] as? Int64 {
                    size = fileSize
                    modifiedAt = Date()
                // periphery:ignore - Reserved: updateSize() instance method reserved for future feature activation
                }
            } catch {
                let filename = fileURL.lastPathComponent; let errMsg = error.localizedDescription
                coworkArtifactLogger.error("Failed to get file size for \(filename): \(errMsg)")
            }
        }

        mutating func addTag(_ tag: String) {
            if !tags.contains(tag) {
                tags.append(tag)
            }
        }

// periphery:ignore - Reserved: addTag(_:) instance method reserved for future feature activation

        mutating func removeTag(_ tag: String) {
            tags.removeAll { $0 == tag }
        }
    }

// periphery:ignore - Reserved: removeTag(_:) instance method reserved for future feature activation

    // MARK: - Artifact Collection Helpers

    extension [CoworkArtifact] {
        var totalSize: Int64 {
            reduce(0) { $0 + $1.size }
        }

        var formattedTotalSize: String {
            ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }

        func byType(_ type: CoworkArtifact.ArtifactType) -> [CoworkArtifact] {
            filter { $0.fileType == type }
        }

// periphery:ignore - Reserved: byType(_:) instance method reserved for future feature activation

        var finalArtifacts: [CoworkArtifact] {
            filter { !$0.isIntermediate }
        // periphery:ignore - Reserved: finalArtifacts property reserved for future feature activation
        }

        var intermediateArtifacts: [CoworkArtifact] {
            // periphery:ignore - Reserved: intermediateArtifacts property reserved for future feature activation
            filter(\.isIntermediate)
        }

        // periphery:ignore - Reserved: forStep(_:) instance method reserved for future feature activation
        func forStep(_ stepId: UUID) -> [CoworkArtifact] {
            filter { $0.stepId == stepId }
        }
    }

#endif
