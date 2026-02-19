//
//  MultiModalAnalyzer.swift
//  Thea
//
//  Unified multi-modal analysis pipeline for documents, images, and screenshots.
//  Coordinates FileAttachmentManager, VisionOCR, and ScreenCapture for comprehensive analysis.
//
//  PIPELINE:
//  1. Input: Image, PDF, Document, or Screenshot
//  2. Extract: Text via OCR, metadata, structure
//  3. Analyze: Send to AI with appropriate context
//  4. Output: Structured analysis result
//
//  CREATED: February 6, 2026
//

import Foundation
import OSLog
import CoreGraphics

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Multi-Modal Analyzer

/// Unified pipeline for analyzing documents, images, and screen content
public actor MultiModalAnalyzer {
    public static let shared = MultiModalAnalyzer()

    private let logger = Logger(subsystem: "ai.thea.app", category: "MultiModal")

    // MARK: - Configuration

    public struct Configuration: Sendable {
        /// Maximum image dimension for processing
        public var maxImageDimension: Int = 2048

        /// Enable OCR for images
        public var enableOCR: Bool = true

        /// OCR confidence threshold (0.0-1.0)
        public var ocrConfidenceThreshold: Float = 0.5

        /// Enable document structure analysis
        public var enableStructureAnalysis: Bool = true

        /// Maximum text length for AI context
        public var maxTextLength: Int = 50000

        /// Enable caching of analysis results
        public var enableCaching: Bool = true

        /// Cache expiration (seconds)
        public var cacheExpiration: TimeInterval = 3600

        public init() {}
    }

    public var configuration = Configuration()

    // MARK: - Cache

    private var analysisCache: [String: CachedAnalysis] = [:]

    private struct CachedAnalysis {
        let result: AnalysisResult
        let timestamp: Date
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Analyze a file attachment
    func analyze(attachment: FileAttachment) async throws -> AnalysisResult {
        logger.info("Analyzing attachment: \(attachment.name)")

        // Check cache
        if configuration.enableCaching,
           let cached = analysisCache[attachment.id.uuidString],
           Date().timeIntervalSince(cached.timestamp) < configuration.cacheExpiration {
            logger.debug("Returning cached analysis for \(attachment.name)")
            return cached.result
        }

        let result: AnalysisResult

        switch attachment.fileType {
        case .image:
            result = try await analyzeImage(attachment: attachment)
        case .pdf:
            result = try await analyzePDF(attachment: attachment)
        case .document:
            result = try await analyzeDocument(attachment: attachment)
        case .spreadsheet:
            result = try await analyzeSpreadsheet(attachment: attachment)
        case .code:
            result = try await analyzeCode(attachment: attachment)
        case .audio, .video:
            result = AnalysisResult(
                type: .media,
                extractedText: nil,
                summary: "Media file: \(attachment.name). Audio/video analysis requires transcription.",
                metadata: ["fileName": attachment.name, "fileType": attachment.fileType.rawValue]
            )
        default:
            result = try await analyzeGenericFile(attachment: attachment)
        }

        // Cache result
        if configuration.enableCaching {
            analysisCache[attachment.id.uuidString] = CachedAnalysis(result: result, timestamp: Date())
        }

        return result
    }

    /// Analyze the current screen (macOS only)
    public func analyzeScreen() async throws -> ScreenAnalysisResult {
        #if os(macOS)
        logger.info("Capturing and analyzing screen")

        // Capture screen
        let capture = ScreenCapture.shared
        let cgImage = try await capture.captureScreen()

        // Extract text via OCR
        let ocrResults = try await VisionOCR.shared.recognizeText(in: cgImage)

        let extractedText = ocrResults
            .filter { $0.confidence >= configuration.ocrConfidenceThreshold }
            .map { $0.text }
            .joined(separator: "\n")

        // Analyze layout and structure
        let structure = analyzeScreenStructure(ocrResults: ocrResults, imageSize: CGSize(width: cgImage.width, height: cgImage.height))

        return ScreenAnalysisResult(
            extractedText: extractedText,
            textBlocks: ocrResults.map { AnalyzedTextBlock(text: $0.text, boundingBox: $0.boundingBox, confidence: $0.confidence) },
            structure: structure,
            timestamp: Date()
        )
        #else
        throw MultiModalAnalyzerError.notSupportedOnPlatform
        #endif
    }

    /// Extract text from an image
    public func extractText(from image: CGImage) async throws -> String {
        logger.info("Extracting text from image")

        let results = try await VisionOCR.shared.recognizeText(in: image)

        return results
            .filter { $0.confidence >= configuration.ocrConfidenceThreshold }
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y } // Top to bottom
            .map { $0.text }
            .joined(separator: "\n")
    }

    /// Summarize a document for AI context
    public func summarizeDocument(_ url: URL) async throws -> String {
        logger.info("Summarizing document: \(url.lastPathComponent)")

        // Add as attachment and process
        try await FileAttachmentManager.shared.addAttachment(from: url)

        // Get the attachment
        guard let attachment = await MainActor.run(body: {
            FileAttachmentManager.shared.attachments.last
        }) else {
            throw MultiModalAnalyzerError.attachmentNotFound
        }

        let analysis = try await analyze(attachment: attachment)

        // Build summary
        var summary = "Document: \(url.lastPathComponent)\n"

        if let text = analysis.extractedText, !text.isEmpty {
            // Truncate if too long
            let truncated = text.count > configuration.maxTextLength
                ? String(text.prefix(configuration.maxTextLength)) + "...[truncated]"
                : text
            summary += "\nContent:\n\(truncated)"
        } else if let analysisSum = analysis.summary {
            summary += "\n\(analysisSum)"
        }

        return summary
    }

    /// Clear analysis cache
    public func clearCache() {
        analysisCache.removeAll()
        logger.debug("Analysis cache cleared")
    }

    // MARK: - Private Analysis Methods

    private func analyzeImage(attachment: FileAttachment) async throws -> AnalysisResult {
        logger.debug("Analyzing image: \(attachment.name)")

        var extractedText: String?
        var metadata: [String: String] = [
            "fileName": attachment.name,
            "fileType": "image",
            "sizeBytes": String(attachment.sizeBytes)
        ]

        // Extract text via OCR if enabled
        if configuration.enableOCR, let attachmentUrl = attachment.url {
            if let cgImage = await loadCGImage(from: attachmentUrl) {
                let ocrResults = try await VisionOCR.shared.recognizeText(in: cgImage)
                extractedText = ocrResults
                    .filter { $0.confidence >= configuration.ocrConfidenceThreshold }
                    .map { $0.text }
                    .joined(separator: "\n")

                metadata["ocrConfidence"] = String(format: "%.2f", ocrResults.map { $0.confidence }.reduce(0, +) / Float(max(1, ocrResults.count)))
            }
        }

        // Get image dimensions
        if let attachmentUrl = attachment.url, let dimensions = await getImageDimensions(from: attachmentUrl) {
            metadata["width"] = String(Int(dimensions.width))
            metadata["height"] = String(Int(dimensions.height))
        }

        return AnalysisResult(
            type: .image,
            extractedText: extractedText,
            summary: extractedText?.isEmpty ?? true
                ? "Image file with no detected text"
                : "Image with \(extractedText?.components(separatedBy: "\n").count ?? 0) lines of text",
            metadata: metadata
        )
    }

    private func analyzePDF(attachment: FileAttachment) async throws -> AnalysisResult {
        logger.debug("Analyzing PDF: \(attachment.name)")

        // Use FileAttachmentManager's extracted text if available
        let extractedText = attachment.extractedText

        var metadata: [String: String] = [
            "fileName": attachment.name,
            "fileType": "pdf",
            "sizeBytes": String(attachment.sizeBytes)
        ]

        if let pageCount = attachment.extractedMetadata?["pageCount"] {
            metadata["pageCount"] = pageCount
        }

        return AnalysisResult(
            type: .document,
            extractedText: extractedText,
            summary: extractedText?.isEmpty ?? true
                ? "PDF document (text extraction may be needed)"
                : "PDF with \(extractedText?.count ?? 0) characters",
            metadata: metadata
        )
    }

    private func analyzeDocument(attachment: FileAttachment) async throws -> AnalysisResult {
        logger.debug("Analyzing document: \(attachment.name)")

        let extractedText = attachment.extractedText

        return AnalysisResult(
            type: .document,
            extractedText: extractedText,
            summary: extractedText?.isEmpty ?? true
                ? "Document file"
                : "Document with \(extractedText?.count ?? 0) characters",
            metadata: [
                "fileName": attachment.name,
                "fileType": attachment.fileType.rawValue
            ]
        )
    }

    private func analyzeSpreadsheet(attachment: FileAttachment) async throws -> AnalysisResult {
        logger.debug("Analyzing spreadsheet: \(attachment.name)")

        var metadata: [String: String] = [
            "fileName": attachment.name,
            "fileType": "spreadsheet"
        ]

        if let rows = attachment.extractedMetadata?["rows"] {
            metadata["rows"] = rows
        }
        if let cols = attachment.extractedMetadata?["columns"] {
            metadata["columns"] = cols
        }

        return AnalysisResult(
            type: .spreadsheet,
            extractedText: attachment.extractedText,
            summary: "Spreadsheet: \(attachment.name)",
            metadata: metadata
        )
    }

    private func analyzeCode(attachment: FileAttachment) async throws -> AnalysisResult {
        logger.debug("Analyzing code file: \(attachment.name)")

        let code = attachment.extractedText ?? ""
        let lineCount = code.components(separatedBy: "\n").count

        let fileExtension = attachment.url?.pathExtension.lowercased() ?? ""
        let language = detectLanguage(from: fileExtension)

        return AnalysisResult(
            type: .code,
            extractedText: code,
            summary: "\(language) code file with \(lineCount) lines",
            metadata: [
                "fileName": attachment.name,
                "language": language,
                "lineCount": String(lineCount)
            ]
        )
    }

    private func analyzeGenericFile(attachment: FileAttachment) async throws -> AnalysisResult {
        logger.debug("Analyzing generic file: \(attachment.name)")

        return AnalysisResult(
            type: .unknown,
            extractedText: attachment.extractedText,
            summary: "File: \(attachment.name) (\(formatBytes(attachment.sizeBytes)))",
            metadata: [
                "fileName": attachment.name,
                "mimeType": attachment.mimeType,
                "sizeBytes": String(attachment.sizeBytes)
            ]
        )
    }

    // MARK: - Helper Methods

    private func loadCGImage(from url: URL) async -> CGImage? {
        #if os(macOS)
        guard let nsImage = NSImage(contentsOf: url) else { return nil }
        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #elseif os(iOS)
        guard let uiImage = UIImage(contentsOfFile: url.path) else { return nil }
        return uiImage.cgImage
        #else
        return nil
        #endif
    }

    private func getImageDimensions(from url: URL) async -> CGSize? {
        #if os(macOS)
        guard let nsImage = NSImage(contentsOf: url) else { return nil }
        return nsImage.size
        #elseif os(iOS)
        guard let uiImage = UIImage(contentsOfFile: url.path) else { return nil }
        return uiImage.size
        #else
        return nil
        #endif
    }

    private func detectLanguage(from extension: String) -> String {
        let languageMap: [String: String] = [
            "swift": "Swift",
            "py": "Python",
            "js": "JavaScript",
            "ts": "TypeScript",
            "java": "Java",
            "kt": "Kotlin",
            "go": "Go",
            "rs": "Rust",
            "c": "C",
            "cpp": "C++",
            "h": "C/C++ Header",
            "cs": "C#",
            "rb": "Ruby",
            "php": "PHP",
            "html": "HTML",
            "css": "CSS",
            "json": "JSON",
            "xml": "XML",
            "yaml": "YAML",
            "yml": "YAML",
            "md": "Markdown",
            "sql": "SQL",
            "sh": "Shell",
            "bash": "Bash"
        ]

        return languageMap[`extension`] ?? "Unknown"
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024

        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.1f KB", kb)
        } else {
            return "\(bytes) bytes"
        }
    }

    #if os(macOS)
    // periphery:ignore - Reserved: imageSize parameter kept for API compatibility
    private func analyzeScreenStructure(ocrResults: [VisionOCR.OCRResult], imageSize: CGSize) -> ScreenStructure {
        // Group text blocks by vertical position (detect rows)
        let sortedBlocks = ocrResults.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

        // Detect potential UI regions
        var regions: [ScreenRegion] = []

        // Top region (likely menu/toolbar)
        let topBlocks = sortedBlocks.filter { $0.boundingBox.origin.y > 0.85 }
        if !topBlocks.isEmpty {
            regions.append(ScreenRegion(type: .toolbar, textCount: topBlocks.count))
        }

        // Main content (middle region)
        let middleBlocks = sortedBlocks.filter { $0.boundingBox.origin.y > 0.15 && $0.boundingBox.origin.y <= 0.85 }
        if !middleBlocks.isEmpty {
            regions.append(ScreenRegion(type: .content, textCount: middleBlocks.count))
        }

        // Bottom region (likely status bar/dock)
        let bottomBlocks = sortedBlocks.filter { $0.boundingBox.origin.y <= 0.15 }
        if !bottomBlocks.isEmpty {
            regions.append(ScreenRegion(type: .statusBar, textCount: bottomBlocks.count))
        }

        return ScreenStructure(
            totalTextBlocks: ocrResults.count,
            regions: regions,
            estimatedComplexity: estimateComplexity(blockCount: ocrResults.count)
        )
    }
    #endif

    private func estimateComplexity(blockCount: Int) -> ScreenComplexity {
        switch blockCount {
        case 0..<10: return .simple
        case 10..<50: return .moderate
        case 50..<100: return .complex
        default: return .veryComplex
        }
    }
}

// MARK: - Supporting Types

/// Result of multi-modal analysis
public struct AnalysisResult: Sendable {
    public let type: AnalysisType
    public let extractedText: String?
    public let summary: String?
    public let metadata: [String: String]

    public init(type: AnalysisType, extractedText: String?, summary: String?, metadata: [String: String]) {
        self.type = type
        self.extractedText = extractedText
        self.summary = summary
        self.metadata = metadata
    }
}

/// Type of content analyzed
public enum AnalysisType: String, Sendable {
    case image
    case document
    case spreadsheet
    case code
    case media
    case screenshot
    case unknown
}

/// Result of screen analysis
public struct ScreenAnalysisResult: Sendable {
    public let extractedText: String
    public let textBlocks: [AnalyzedTextBlock]
    public let structure: ScreenStructure
    public let timestamp: Date
}

/// A block of text detected in an image/screen (for MultiModalAnalyzer)
public struct AnalyzedTextBlock: Sendable {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float

    public init(text: String, boundingBox: CGRect, confidence: Float) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

/// Detected screen structure
public struct ScreenStructure: Sendable {
    public let totalTextBlocks: Int
    public let regions: [ScreenRegion]
    public let estimatedComplexity: ScreenComplexity
}

/// A detected region on screen
public struct ScreenRegion: Sendable {
    public let type: RegionType
    public let textCount: Int

    public enum RegionType: String, Sendable {
        case toolbar
        case sidebar
        case content
        case statusBar
        case dialog
        case menu
    }
}

/// Estimated screen complexity
public enum ScreenComplexity: String, Sendable {
    case simple = "Simple"
    case moderate = "Moderate"
    case complex = "Complex"
    case veryComplex = "Very Complex"
}

/// Multi-modal analyzer errors
public enum MultiModalAnalyzerError: LocalizedError {
    case screenCaptureFailed
    case imageConversionFailed
    case notSupportedOnPlatform
    case attachmentNotFound
    case ocrFailed(String)

    public var errorDescription: String? {
        switch self {
        case .screenCaptureFailed:
            return "Failed to capture screen"
        case .imageConversionFailed:
            return "Failed to convert image format"
        case .notSupportedOnPlatform:
            return "This feature is not supported on this platform"
        case .attachmentNotFound:
            return "Attachment not found"
        case .ocrFailed(let reason):
            return "OCR failed: \(reason)"
        }
    }
}
