// FileAttachmentManager.swift
// Universal file attachment system supporting unlimited files of any format
// Handles processing, previews, and AI-compatible formatting

import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - File Attachment Manager

/// Manages file attachments for AI prompts with unlimited files and any format support
@MainActor
@Observable
final class FileAttachmentManager {
    static let shared = FileAttachmentManager()
    private let logger = Logger(subsystem: "com.thea.app", category: "FileAttachmentManager")

    // MARK: - State

    private(set) var attachments: [FileAttachment] = []
    private(set) var isProcessing = false
    private(set) var processingProgress: Double = 0.0
    private(set) var errorMessage: String?

    // Configuration
    private(set) var configuration = Configuration()

    struct Configuration: Codable, Sendable {
        var maxFileSizeMB: Double = 100.0 // Per-file limit
        var maxTotalSizeMB: Double = 500.0 // Total attachment limit
        var enableImagePreviews = true
        var enableTextExtraction = true
        var enableOCR = false // Requires Vision framework
        var compressImagesForAI = true
        var maxImageDimension: Int = 2048
        var supportedFormats: [String] = [] // Empty = all formats
    }

    // MARK: - Initialization

    private init() {
        loadConfiguration()
    }

    // MARK: - Attachment Operations

    /// Add file from URL
    func addAttachment(from url: URL) async throws {
        isProcessing = true
        defer { isProcessing = false }
        errorMessage = nil

        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileAttachmentError.fileNotFound(url.path)
        }

        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        let fileSizeMB = Double(fileSize) / 1_048_576

        if fileSizeMB > configuration.maxFileSizeMB {
            throw FileAttachmentError.fileTooLarge(fileSizeMB, configuration.maxFileSizeMB)
        }

        // Check total size
        let currentTotalMB = attachments.reduce(0.0) { $0 + $1.sizeMB }
        if currentTotalMB + fileSizeMB > configuration.maxTotalSizeMB {
            throw FileAttachmentError.totalSizeLimitExceeded(currentTotalMB + fileSizeMB, configuration.maxTotalSizeMB)
        }

        // Detect file type
        let fileType = detectFileType(url: url)

        // Read file data
        let data = try Data(contentsOf: url)

        // Create attachment
        var attachment = FileAttachment(
            id: UUID(),
            name: url.lastPathComponent,
            url: url,
            fileType: fileType,
            sizeBytes: fileSize,
            mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream",
            addedAt: Date()
        )

        // Process based on type
        attachment = await processAttachment(attachment, data: data)

        attachments.append(attachment)
    }

    /// Add multiple files
    // periphery:ignore - Reserved: addAttachments(from:) instance method — reserved for future feature activation
    func addAttachments(from urls: [URL]) async throws {
        for (index, url) in urls.enumerated() {
            processingProgress = Double(index) / Double(urls.count)
            try await addAttachment(from: url)
        }
        processingProgress = 1.0
    }

    // periphery:ignore - Reserved: addAttachments(from:) instance method reserved for future feature activation
    /// Add file from data
    func addAttachment(data: Data, name: String, mimeType: String) async throws {
        isProcessing = true
        defer { isProcessing = false }

        let fileSizeMB = Double(data.count) / 1_048_576

        if fileSizeMB > configuration.maxFileSizeMB {
            // periphery:ignore - Reserved: addAttachment(data:name:mimeType:) instance method reserved for future feature activation
            throw FileAttachmentError.fileTooLarge(fileSizeMB, configuration.maxFileSizeMB)
        }

        let fileType = detectFileType(from: mimeType, name: name)

        var attachment = FileAttachment(
            id: UUID(),
            name: name,
            url: nil,
            fileType: fileType,
            sizeBytes: UInt64(data.count),
            mimeType: mimeType,
            addedAt: Date()
        )

        attachment = await processAttachment(attachment, data: data)
        attachments.append(attachment)
    }

    /// Remove attachment
    func removeAttachment(id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    /// Remove all attachments
    func clearAllAttachments() {
        attachments.removeAll()
        errorMessage = nil
    }

    // MARK: - Processing

    private func processAttachment(_ attachment: FileAttachment, data: Data) async -> FileAttachment {
        var result = attachment
        result.rawData = data

        switch attachment.fileType {
        case .image:
            result = await processImage(result, data: data)
        case .text, .code:
            result = processTextFile(result, data: data)
        case .pdf:
            result = await processPDF(result, data: data)
        case .document:
            result = await processDocument(result, data: data)
        case .spreadsheet:
            result = processSpreadsheet(result, data: data)
        case .audio:
            result = await processAudio(result)
        case .video:
            result = await processVideo(result)
        case .archive:
            result = processArchive(result)
        case .data:
            result = processDataFile(result, data: data)
        case .unknown:
            // Keep as binary
            break
        }

        return result
    }

    private func processImage(_ attachment: FileAttachment, data: Data) async -> FileAttachment {
        var result = attachment

        #if os(macOS)
        if let image = NSImage(data: data) {
            result.previewImage = image
            result.extractedMetadata = [
                "width": "\(Int(image.size.width))",
                "height": "\(Int(image.size.height))"
            ]

            // Compress for AI if needed
            if configuration.compressImagesForAI {
                let maxDim = CGFloat(configuration.maxImageDimension)
                if image.size.width > maxDim || image.size.height > maxDim {
                    let scale = min(maxDim / image.size.width, maxDim / image.size.height)
                    let newSize = NSSize(
                        width: image.size.width * scale,
                        height: image.size.height * scale
                    )
                    let resizedImage = NSImage(size: newSize)
                    resizedImage.lockFocus()
                    image.draw(in: NSRect(origin: .zero, size: newSize))
                    resizedImage.unlockFocus()
                    result.previewImage = resizedImage

                    if let tiffData = resizedImage.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                        result.processedData = jpegData
                    }
                }
            }
        }
        #elseif os(iOS) || os(tvOS)
        if let image = UIImage(data: data) {
            result.previewUIImage = image
            result.extractedMetadata = [
                "width": "\(Int(image.size.width))",
                "height": "\(Int(image.size.height))"
            ]

            if configuration.compressImagesForAI {
                let maxDim = CGFloat(configuration.maxImageDimension)
                if image.size.width > maxDim || image.size.height > maxDim {
                    let scale = min(maxDim / image.size.width, maxDim / image.size.height)
                    let newSize = CGSize(
                        width: image.size.width * scale,
                        height: image.size.height * scale
                    )
                    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                    let resized = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()

                    if let resized, let jpegData = resized.jpegData(compressionQuality: 0.8) {
                        result.processedData = jpegData
                        result.previewUIImage = resized
                    }
                }
            }
        }
        #endif

        return result
    }

    private func processTextFile(_ attachment: FileAttachment, data: Data) -> FileAttachment {
        var result = attachment

        // Try to decode as text
        if let text = String(data: data, encoding: .utf8) {
            result.extractedText = text
            result.extractedMetadata = [
                "lines": "\(text.components(separatedBy: .newlines).count)",
                "characters": "\(text.count)"
            ]
        } else if let text = String(data: data, encoding: .isoLatin1) {
            result.extractedText = text
        }

        return result
    }

    private func processPDF(_ attachment: FileAttachment, data: Data) async -> FileAttachment {
        var result = attachment

        #if os(macOS)
        // Use PDFKit for text extraction
        if let pdfDoc = PDFDocument(data: data) {
            var extractedText = ""
            for i in 0..<pdfDoc.pageCount {
                if let page = pdfDoc.page(at: i), let text = page.string {
                    extractedText += text + "\n\n"
                }
            }
            result.extractedText = extractedText
            result.extractedMetadata = [
                "pages": "\(pdfDoc.pageCount)"
            ]

            // Generate preview of first page
            if let firstPage = pdfDoc.page(at: 0) {
                let pageRect = firstPage.bounds(for: .mediaBox)
                let image = NSImage(size: pageRect.size)
                image.lockFocus()
                NSColor.white.set()
                pageRect.fill()
                if let context = NSGraphicsContext.current?.cgContext {
                    firstPage.draw(with: .mediaBox, to: context)
                }
                image.unlockFocus()
                result.previewImage = image
            }
        }
        #endif

        return result
    }

    private func processDocument(_ attachment: FileAttachment, data: Data) async -> FileAttachment {
        var result = attachment

        // For .docx, .rtf, etc. - basic text extraction
        if attachment.name.hasSuffix(".rtf") {
            do {
                let attributedString = try NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
                result.extractedText = attributedString.string
            } catch {
                logger.debug("Could not parse RTF document: \(error.localizedDescription)")
            }
        }

        return result
    }

    private func processSpreadsheet(_ attachment: FileAttachment, data: Data) -> FileAttachment {
        var result = attachment

        // For CSV files
        if attachment.name.hasSuffix(".csv") {
            if let text = String(data: data, encoding: .utf8) {
                result.extractedText = text
                let lines = text.components(separatedBy: .newlines)
                result.extractedMetadata = [
                    "rows": "\(lines.count)",
                    "columns": "\(lines.first?.components(separatedBy: ",").count ?? 0)"
                ]
            }
        }

        return result
    }

    private func processAudio(_ attachment: FileAttachment) async -> FileAttachment {
        var result = attachment
        result.extractedMetadata = [
            "type": "audio",
            "format": attachment.url?.pathExtension ?? "unknown"
        ]
        return result
    }

    private func processVideo(_ attachment: FileAttachment) async -> FileAttachment {
        var result = attachment
        result.extractedMetadata = [
            "type": "video",
            "format": attachment.url?.pathExtension ?? "unknown"
        ]
        return result
    }

    private func processArchive(_ attachment: FileAttachment) -> FileAttachment {
        var result = attachment
        result.extractedMetadata = [
            "type": "archive",
            "format": attachment.url?.pathExtension ?? "unknown"
        ]
        return result
    }

    private func processDataFile(_ attachment: FileAttachment, data: Data) -> FileAttachment {
        var result = attachment

        // Try JSON
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            result.extractedText = String(data: jsonData, encoding: .utf8)
            result.extractedMetadata = ["format": "JSON"]
        } catch {
            logger.debug("Could not parse JSON data file: \(error.localizedDescription)")
        }

        return result
    }

    // MARK: - File Type Detection

    private func detectFileType(url: URL) -> AttachmentFileType {
        let ext = url.pathExtension.lowercased()
        return detectFileType(extension: ext)
    }

    private func detectFileType(from mimeType: String, name: String) -> AttachmentFileType {
        // Check MIME type first
        if mimeType.hasPrefix("image/") { return .image }
        if mimeType.hasPrefix("text/") { return .text }
        if mimeType.hasPrefix("audio/") { return .audio }
        if mimeType.hasPrefix("video/") { return .video }
        // periphery:ignore - Reserved: detectFileType(from:name:) instance method reserved for future feature activation
        if mimeType == "application/pdf" { return .pdf }
        if mimeType == "application/json" { return .data }

        // Fall back to extension
        let ext = (name as NSString).pathExtension.lowercased()
        return detectFileType(extension: ext)
    }

    private func detectFileType(extension ext: String) -> AttachmentFileType {
        switch ext {
        // Images
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff", "svg":
            return .image

        // Text
        case "txt", "md", "markdown", "rtf":
            return .text

        // Code
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h", "m", "mm", "go",
             "rs", "rb", "php", "html", "css", "scss", "json", "xml", "yaml", "yml",
             "sh", "bash", "zsh", "sql", "kt", "scala", "r", "lua", "perl":
            return .code

        // PDF
        case "pdf":
            return .pdf

        // Documents
        case "doc", "docx", "odt", "pages":
            return .document

        // Spreadsheets
        case "csv", "xls", "xlsx", "numbers":
            return .spreadsheet

        // Audio
        case "mp3", "wav", "aac", "m4a", "flac", "ogg", "wma":
            return .audio

        // Video
        case "mp4", "mov", "avi", "mkv", "webm", "m4v", "wmv":
            return .video

        // Archives
        case "zip", "tar", "gz", "7z", "rar", "bz2":
            return .archive

        // Data
        case "plist", "sqlite", "db":
            return .data

        default:
            return .unknown
        }
    }

    // MARK: - AI Formatting

    /// Format all attachments for AI context
    // periphery:ignore - Reserved: formatForAI() instance method — reserved for future feature activation
    func formatForAI() -> String {
        guard !attachments.isEmpty else { return "" }

        var context = "## Attached Files (\(attachments.count))\n\n"

        // periphery:ignore - Reserved: formatForAI() instance method reserved for future feature activation
        for attachment in attachments {
            context += "### \(attachment.name)\n"
            context += "- Type: \(attachment.fileType.displayName)\n"
            context += "- Size: \(attachment.formattedSize)\n"

            if let metadata = attachment.extractedMetadata, !metadata.isEmpty {
                for (key, value) in metadata {
                    context += "- \(key.capitalized): \(value)\n"
                }
            }

            if let text = attachment.extractedText {
                let truncated = text.prefix(10000)
                context += "\n```\n\(truncated)\n```\n"
                if text.count > 10000 {
                    context += "\n*[Content truncated - \(text.count) total characters]*\n"
                }
            }

            context += "\n"
        }

        return context
    }

    /// Get base64 encoded images for vision models
    // periphery:ignore - Reserved: getBase64Images() instance method — reserved for future feature activation
    func getBase64Images() -> [(name: String, base64: String, mimeType: String)] {
        attachments
            .filter { $0.fileType == .image }
            .compactMap { attachment -> (String, String, String)? in
                // periphery:ignore - Reserved: getBase64Images() instance method reserved for future feature activation
                let data = attachment.processedData ?? attachment.rawData
                guard let data else { return nil }
                return (attachment.name, data.base64EncodedString(), attachment.mimeType)
            }
    }

    // MARK: - Configuration

    // periphery:ignore - Reserved: updateConfiguration(_:) instance method — reserved for future feature activation
    func updateConfiguration(_ config: Configuration) {
        configuration = config
        saveConfiguration()
    // periphery:ignore - Reserved: updateConfiguration(_:) instance method reserved for future feature activation
    }

    private func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: "FileAttachment.config") else { return }
        do {
            configuration = try JSONDecoder().decode(Configuration.self, from: data)
        } catch {
            logger.debug("Could not load FileAttachment configuration: \(error.localizedDescription)")
        }
    }

    // periphery:ignore - Reserved: saveConfiguration() instance method — reserved for future feature activation
    private func saveConfiguration() {
        do {
            // periphery:ignore - Reserved: saveConfiguration() instance method reserved for future feature activation
            let data = try JSONEncoder().encode(configuration)
            UserDefaults.standard.set(data, forKey: "FileAttachment.config")
        } catch {
            logger.debug("Could not save FileAttachment configuration: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

struct FileAttachment: Identifiable, Sendable {
    let id: UUID
    let name: String
    let url: URL?
    let fileType: AttachmentFileType
    let sizeBytes: UInt64
    let mimeType: String
    // periphery:ignore - Reserved: addedAt property — reserved for future feature activation
    let addedAt: Date

// periphery:ignore - Reserved: addedAt property reserved for future feature activation

    var rawData: Data?
    var processedData: Data?
    var extractedText: String?
    var extractedMetadata: [String: String]?

    #if os(macOS)
    // periphery:ignore - Reserved: previewImage property reserved for future feature activation
    @MainActor var previewImage: NSImage?
    #elseif os(iOS) || os(tvOS)
    @MainActor var previewUIImage: UIImage?
    #endif

    var sizeMB: Double {
        Double(sizeBytes) / 1_048_576
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}

enum AttachmentFileType: String, Codable, Sendable {
    case image
    case text
    case code
    case pdf
    case document
    case spreadsheet
    case audio
    case video
    case archive
    case data
    case unknown

    var displayName: String {
        switch self {
        case .image: "Image"
        case .text: "Text"
        case .code: "Code"
        case .pdf: "PDF"
        case .document: "Document"
        case .spreadsheet: "Spreadsheet"
        case .audio: "Audio"
        case .video: "Video"
        case .archive: "Archive"
        case .data: "Data"
        case .unknown: "File"
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo"
        case .text: "doc.text"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .pdf: "doc.richtext"
        case .document: "doc"
        case .spreadsheet: "tablecells"
        case .audio: "waveform"
        case .video: "video"
        case .archive: "archivebox"
        case .data: "cylinder"
        case .unknown: "doc.questionmark"
        }
    }
}

enum FileAttachmentError: Error, LocalizedError {
    case fileNotFound(String)
    case fileTooLarge(Double, Double)
    case totalSizeLimitExceeded(Double, Double)
    case unsupportedFormat(String)
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            "File not found: \(path)"
        case .fileTooLarge(let size, let max):
            "File too large (\(String(format: "%.1f", size))MB). Maximum is \(String(format: "%.0f", max))MB."
        case .totalSizeLimitExceeded(let total, let max):
            "Total attachments too large (\(String(format: "%.1f", total))MB). Maximum is \(String(format: "%.0f", max))MB."
        case .unsupportedFormat(let format):
            "Unsupported file format: \(format)"
        case .processingFailed(let reason):
            "Failed to process file: \(reason)"
        }
    }
}

#if os(macOS)
import Quartz
typealias PDFDocument = PDFKit.PDFDocument
import PDFKit
#endif
