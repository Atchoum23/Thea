// ImageIntelligence.swift
// Thea — AI-powered image processing via Vision + CoreImage
// Replaces: Pixelmator Pro (for AI-assisted quick edits)
//
// Background removal, upscaling, format conversion, metadata editing,
// image understanding, and batch processing.

import CoreImage
import Foundation
import OSLog
#if canImport(Vision)
import Vision
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

private let iiLogger = Logger(subsystem: "ai.thea.app", category: "ImageIntelligence")

// MARK: - Data Types

enum ImageOperation: String, CaseIterable, Codable, Sendable {
    case removeBackground = "Remove Background"
    case upscale = "Upscale"
    case convertFormat = "Convert Format"
    case compress = "Compress"
    case resize = "Resize"
    case crop = "Crop"
    case adjustColors = "Adjust Colors"
    case extractText = "Extract Text (OCR)"
    case analyzeContent = "Analyze Content"
    case generateThumbnail = "Generate Thumbnail"

    var icon: String {
        switch self {
        case .removeBackground: "person.crop.rectangle"
        case .upscale: "arrow.up.left.and.arrow.down.right"
        case .convertFormat: "arrow.triangle.2.circlepath"
        case .compress: "arrow.down.right.and.arrow.up.left"
        case .resize: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .crop: "crop"
        case .adjustColors: "slider.horizontal.3"
        case .extractText: "doc.text.viewfinder"
        case .analyzeContent: "eye"
        case .generateThumbnail: "photo"
        }
    }

    var description: String {
        switch self {
        case .removeBackground: "Remove background using subject isolation"
        case .upscale: "Increase resolution using AI upscaling"
        case .convertFormat: "Convert between PNG, JPEG, HEIC, TIFF, WebP"
        case .compress: "Reduce file size with quality control"
        case .resize: "Resize to specific dimensions"
        case .crop: "Crop to selection or aspect ratio"
        case .adjustColors: "Adjust brightness, contrast, saturation"
        case .extractText: "Extract text from image using OCR"
        case .analyzeContent: "Identify objects, scenes, and faces"
        case .generateThumbnail: "Create a thumbnail at specified size"
        }
    }
}

enum ImageFormat: String, CaseIterable, Codable, Sendable {
    case png, jpeg, heic, tiff, webp

    var fileExtension: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var mimeType: String {
        switch self {
        case .png: "image/png"
        case .jpeg: "image/jpeg"
        case .heic: "image/heic"
        case .tiff: "image/tiff"
        case .webp: "image/webp"
        }
    }
}

struct ColorAdjustment: Codable, Sendable {
    var brightness: Double  // -1.0 to 1.0
    var contrast: Double    // 0.0 to 4.0 (1.0 = no change)
    var saturation: Double  // 0.0 to 2.0 (1.0 = no change)
    var sharpness: Double   // 0.0 to 1.0

    static let identity = ColorAdjustment(brightness: 0, contrast: 1, saturation: 1, sharpness: 0)
}

struct ImageAnalysisResult: Codable, Sendable, Identifiable {
    let id: UUID
    let detectedObjects: [ImageDetectedObject]
    let dominantColors: [DominantColor]
    let textContent: String?
    let sceneClassification: String?
    let faceCount: Int
    let dimensions: ImageDimensions
    let fileSize: Int64
    let format: String
    let analyzedAt: Date

    init(
        detectedObjects: [ImageDetectedObject] = [],
        dominantColors: [DominantColor] = [],
        textContent: String? = nil,
        sceneClassification: String? = nil,
        faceCount: Int = 0,
        dimensions: ImageDimensions = ImageDimensions(width: 0, height: 0),
        fileSize: Int64 = 0,
        format: String = "unknown"
    ) {
        self.id = UUID()
        self.detectedObjects = detectedObjects
        self.dominantColors = dominantColors
        self.textContent = textContent
        self.sceneClassification = sceneClassification
        self.faceCount = faceCount
        self.dimensions = dimensions
        self.fileSize = fileSize
        self.format = format
        self.analyzedAt = Date()
    }
}

struct ImageDetectedObject: Codable, Sendable, Identifiable {
    let id: UUID
    let label: String
    let confidence: Float
    let boundingBox: BoundingBox

    init(label: String, confidence: Float, boundingBox: BoundingBox = BoundingBox()) {
        self.id = UUID()
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

struct BoundingBox: Codable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(x: Double = 0, y: Double = 0, width: Double = 0, height: Double = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

struct DominantColor: Codable, Sendable, Identifiable {
    let id: UUID
    let red: Double
    let green: Double
    let blue: Double
    let percentage: Double

    var hexString: String {
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    init(red: Double, green: Double, blue: Double, percentage: Double) {
        self.id = UUID()
        self.red = red
        self.green = green
        self.blue = blue
        self.percentage = percentage
    }
}

struct ImageDimensions: Codable, Sendable {
    let width: Int
    let height: Int

    var aspectRatio: Double {
        guard height > 0 else { return 0 }
        return Double(width) / Double(height)
    }

    var megapixels: Double {
        Double(width * height) / 1_000_000
    }

    var displayString: String {
        "\(width) × \(height)"
    }
}

struct ProcessedImage: Sendable {
    let data: Data
    let format: ImageFormat
    let dimensions: ImageDimensions
    let operation: ImageOperation
    let originalSize: Int64
    let processedSize: Int64
}

enum ImageIntelligenceError: Error, LocalizedError, Sendable {
    case fileNotFound(String)
    case unsupportedFormat(String)
    case processingFailed(String)
    case invalidDimensions
    case ciContextCreationFailed
    case visionRequestFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): "Image file not found: \(path)"
        case .unsupportedFormat(let fmt): "Unsupported image format: \(fmt)"
        case .processingFailed(let msg): "Image processing failed: \(msg)"
        case .invalidDimensions: "Invalid image dimensions"
        case .ciContextCreationFailed: "Failed to create CoreImage context"
        case .visionRequestFailed(let msg): "Vision request failed: \(msg)"
        }
    }
}

// MARK: - ImageIntelligence Service

actor ImageIntelligence {
    static let shared = ImageIntelligence()

    private let ciContext: CIContext
    private var processingHistory: [ImageProcessingRecord] = []
    private let historyFile: URL

    init() {
        self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let theaDir = appSupport.appendingPathComponent("Thea/ImageIntelligence")
        do {
            try FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        } catch {
            iiLogger.debug("Could not create ImageIntelligence directory: \(error.localizedDescription)")
        }
        let file = theaDir.appendingPathComponent("history.json")
        self.historyFile = file
        // Inline loadHistory to avoid calling actor-isolated method from init
        do {
            let data = try Data(contentsOf: file)
            self.processingHistory = ErrorLogger.tryOrDefault(
                [],
                context: "ImageIntelligence.init.decodeHistory"
            ) {
                try JSONDecoder().decode([ImageProcessingRecord].self, from: data)
            }
        } catch {
            iiLogger.debug("Could not load image processing history: \(error.localizedDescription)")
        }
    }

    // MARK: - Core Operations

    func analyzeImage(at url: URL) async throws -> ImageAnalysisResult {
        let data = try Data(contentsOf: url)
        let dimensions = try getImageDimensions(from: data)
        let fileSize = Int64(data.count)
        let format = url.pathExtension.lowercased()

        var textContent: String?
        var faceCount = 0
        var detectedObjects: [ImageDetectedObject] = []
        var sceneClassification: String?

        #if canImport(Vision)
        // OCR
        do {
            textContent = try await extractTextFromData(data)
        } catch {
            iiLogger.debug("Text extraction failed: \(error.localizedDescription)")
        }

        // Face detection
        faceCount = try await detectFaces(in: data)

        // Object classification
        if #available(macOS 14.0, iOS 17.0, *) {
            detectedObjects = try await classifyObjects(in: data)
            sceneClassification = detectedObjects.first?.label
        }
        #endif

        let dominantColors = extractDominantColors(from: data)

        let result = ImageAnalysisResult(
            detectedObjects: detectedObjects,
            dominantColors: dominantColors,
            textContent: textContent,
            sceneClassification: sceneClassification,
            faceCount: faceCount,
            dimensions: dimensions,
            fileSize: fileSize,
            format: format
        )

        recordOperation(.analyzeContent, inputSize: fileSize, outputSize: fileSize, url: url)
        return result
    }

    func extractText(from url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        return try await extractTextFromData(data)
    }

    func convertFormat(at url: URL, to format: ImageFormat, quality: Double = 0.85) async throws -> ProcessedImage {
        let data = try Data(contentsOf: url)
        let dimensions = try getImageDimensions(from: data)

        guard let ciImage = CIImage(data: data) else {
            throw ImageIntelligenceError.processingFailed("Cannot create CIImage from data")
        }

        let outputData = try renderToFormat(ciImage, format: format, quality: quality)

        let result = ProcessedImage(
            data: outputData,
            format: format,
            dimensions: dimensions,
            operation: .convertFormat,
            originalSize: Int64(data.count),
            processedSize: Int64(outputData.count)
        )

        recordOperation(.convertFormat, inputSize: Int64(data.count), outputSize: Int64(outputData.count), url: url)
        return result
    }

    func compress(at url: URL, quality: Double = 0.7) async throws -> ProcessedImage {
        let data = try Data(contentsOf: url)
        let dimensions = try getImageDimensions(from: data)

        guard let ciImage = CIImage(data: data) else {
            throw ImageIntelligenceError.processingFailed("Cannot create CIImage from data")
        }

        let outputData = try renderToFormat(ciImage, format: .jpeg, quality: quality)

        let result = ProcessedImage(
            data: outputData,
            format: .jpeg,
            dimensions: dimensions,
            operation: .compress,
            originalSize: Int64(data.count),
            processedSize: Int64(outputData.count)
        )

        recordOperation(.compress, inputSize: Int64(data.count), outputSize: Int64(outputData.count), url: url)
        return result
    }

    func resize(at url: URL, to targetSize: ImageDimensions) async throws -> ProcessedImage {
        let data = try Data(contentsOf: url)
        guard targetSize.width > 0, targetSize.height > 0 else {
            throw ImageIntelligenceError.invalidDimensions
        }

        guard let ciImage = CIImage(data: data) else {
            throw ImageIntelligenceError.processingFailed("Cannot create CIImage from data")
        }

        let scaleX = CGFloat(targetSize.width) / ciImage.extent.width
        let scaleY = CGFloat(targetSize.height) / ciImage.extent.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let outputData = try renderToFormat(scaled, format: .png, quality: 1.0)

        let result = ProcessedImage(
            data: outputData,
            format: .png,
            dimensions: targetSize,
            operation: .resize,
            originalSize: Int64(data.count),
            processedSize: Int64(outputData.count)
        )

        recordOperation(.resize, inputSize: Int64(data.count), outputSize: Int64(outputData.count), url: url)
        return result
    }

    func adjustColors(at url: URL, adjustment: ColorAdjustment) async throws -> ProcessedImage {
        let data = try Data(contentsOf: url)
        let dimensions = try getImageDimensions(from: data)

        guard var ciImage = CIImage(data: data) else {
            throw ImageIntelligenceError.processingFailed("Cannot create CIImage from data")
        }

        // Apply brightness + contrast
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(adjustment.brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(adjustment.contrast, forKey: kCIInputContrastKey)
            filter.setValue(adjustment.saturation, forKey: kCIInputSaturationKey)
            if let output = filter.outputImage {
                ciImage = output
            }
        }

        // Apply sharpness
        if adjustment.sharpness > 0 {
            if let filter = CIFilter(name: "CISharpenLuminance") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(adjustment.sharpness * 2.0, forKey: kCIInputSharpnessKey)
                if let output = filter.outputImage {
                    ciImage = output
                }
            }
        }

        let outputData = try renderToFormat(ciImage, format: .png, quality: 1.0)

        let result = ProcessedImage(
            data: outputData,
            format: .png,
            dimensions: dimensions,
            operation: .adjustColors,
            originalSize: Int64(data.count),
            processedSize: Int64(outputData.count)
        )

        recordOperation(.adjustColors, inputSize: Int64(data.count), outputSize: Int64(outputData.count), url: url)
        return result
    }

    func generateThumbnail(at url: URL, maxDimension: Int = 256) async throws -> ProcessedImage {
        let data = try Data(contentsOf: url)
        let dimensions = try getImageDimensions(from: data)

        guard let ciImage = CIImage(data: data) else {
            throw ImageIntelligenceError.processingFailed("Cannot create CIImage from data")
        }

        let scale: CGFloat
        if dimensions.width > dimensions.height {
            scale = CGFloat(maxDimension) / ciImage.extent.width
        } else {
            scale = CGFloat(maxDimension) / ciImage.extent.height
        }

        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let thumbDims = ImageDimensions(
            width: Int(scaled.extent.width),
            height: Int(scaled.extent.height)
        )

        let outputData = try renderToFormat(scaled, format: .jpeg, quality: 0.8)

        return ProcessedImage(
            data: outputData,
            format: .jpeg,
            dimensions: thumbDims,
            operation: .generateThumbnail,
            originalSize: Int64(data.count),
            processedSize: Int64(outputData.count)
        )
    }

    #if os(macOS)
    func removeBackground(at url: URL) async throws -> ProcessedImage {
        let data = try Data(contentsOf: url)
        let dimensions = try getImageDimensions(from: data)

        guard let ciImage = CIImage(data: data) else {
            throw ImageIntelligenceError.processingFailed("Cannot create CIImage from data")
        }

        // Use Vision to generate a person/subject segmentation mask
        if #available(macOS 14.0, *) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([request])

            if let result = request.results?.first {
                let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)

                // Blend: use mask to composite subject over transparent background
                if let blendFilter = CIFilter(name: "CIBlendWithMask") {
                    let transparentBackground = CIImage.empty()
                    blendFilter.setValue(ciImage, forKey: kCIInputImageKey)
                    blendFilter.setValue(transparentBackground, forKey: kCIInputBackgroundImageKey)
                    blendFilter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)

                    if let output = blendFilter.outputImage {
                        let outputData = try renderToFormat(output, format: .png, quality: 1.0)
                        let result = ProcessedImage(
                            data: outputData,
                            format: .png,
                            dimensions: dimensions,
                            operation: .removeBackground,
                            originalSize: Int64(data.count),
                            processedSize: Int64(outputData.count)
                        )
                        recordOperation(.removeBackground, inputSize: Int64(data.count), outputSize: Int64(outputData.count), url: url)
                        return result
                    }
                }
            }
        }

        throw ImageIntelligenceError.processingFailed("Background removal requires macOS 14.0+")
    }
    #endif

    // MARK: - History

    func getHistory() -> [ImageProcessingRecord] {
        processingHistory
    }

    func clearHistory() {
        processingHistory.removeAll()
        saveHistory()
    }

    func totalBytesProcessed() -> Int64 {
        processingHistory.reduce(0) { $0 + $1.inputSize }
    }

    func totalBytesSaved() -> Int64 {
        processingHistory.reduce(0) { $0 + max(0, $1.inputSize - $1.outputSize) }
    }

    // MARK: - Private Helpers

    private func extractTextFromData(_ data: Data) async throws -> String {
        #if canImport(Vision)
        guard let ciImage = CIImage(data: data) else {
            throw ImageIntelligenceError.processingFailed("Cannot create CIImage for OCR")
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ImageIntelligenceError.visionRequestFailed(error.localizedDescription))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en", "de", "fr", "it", "ru"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ImageIntelligenceError.visionRequestFailed(error.localizedDescription))
            }
        }
        #else
        throw ImageIntelligenceError.processingFailed("Vision framework not available")
        #endif
    }

    private func detectFaces(in data: Data) async throws -> Int {
        #if canImport(Vision)
        guard let ciImage = CIImage(data: data) else { return 0 }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: ImageIntelligenceError.visionRequestFailed(error.localizedDescription))
                    return
                }
                let count = (request.results as? [VNFaceObservation])?.count ?? 0
                continuation.resume(returning: count)
            }

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
        #else
        return 0
        #endif
    }

    @available(macOS 14.0, iOS 17.0, *)
    private func classifyObjects(in data: Data) async throws -> [ImageDetectedObject] {
        #if canImport(Vision)
        guard let ciImage = CIImage(data: data) else { return [] }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ImageDetectedObject], Error>) in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: ImageIntelligenceError.visionRequestFailed(error.localizedDescription))
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let objects = observations
                    .filter { $0.confidence > 0.3 }
                    .prefix(10)
                    .map { ImageDetectedObject(label: $0.identifier, confidence: $0.confidence) }
                continuation.resume(returning: Array(objects))
            }

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
        #else
        return []
        #endif
    }

    private func extractDominantColors(from data: Data) -> [DominantColor] {
        guard let ciImage = CIImage(data: data) else { return [] }

        // Sample colors from the image center area
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return [] }

        // Use CIAreaAverage to get the dominant color of the whole image
        var colors: [DominantColor] = []

        if let filter = CIFilter(name: "CIAreaAverage") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
            if let output = filter.outputImage {
                var pixel = [UInt8](repeating: 0, count: 4)
                ciContext.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
                colors.append(DominantColor(
                    red: Double(pixel[0]) / 255.0,
                    green: Double(pixel[1]) / 255.0,
                    blue: Double(pixel[2]) / 255.0,
                    percentage: 1.0
                ))
            }
        }

        return colors
    }

    private func getImageDimensions(from data: Data) throws -> ImageDimensions {
        guard let ciImage = CIImage(data: data) else {
            throw ImageIntelligenceError.processingFailed("Cannot read image dimensions")
        }
        return ImageDimensions(
            width: Int(ciImage.extent.width),
            height: Int(ciImage.extent.height)
        )
    }

    private func renderToFormat(_ image: CIImage, format: ImageFormat, quality: Double) throws -> Data {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        switch format {
        case .png:
            guard let data = ciContext.pngRepresentation(of: image, format: .RGBA8, colorSpace: colorSpace) else {
                throw ImageIntelligenceError.processingFailed("PNG rendering failed")
            }
            return data

        case .jpeg:
            guard let data = ciContext.jpegRepresentation(of: image, colorSpace: colorSpace, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]) else {
                throw ImageIntelligenceError.processingFailed("JPEG rendering failed")
            }
            return data

        case .heic:
            guard let data = ciContext.heifRepresentation(of: image, format: .RGBA8, colorSpace: colorSpace, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]) else {
                throw ImageIntelligenceError.processingFailed("HEIC rendering failed")
            }
            return data

        case .tiff:
            guard let data = ciContext.tiffRepresentation(of: image, format: .RGBA8, colorSpace: colorSpace, options: [:]) else {
                throw ImageIntelligenceError.processingFailed("TIFF rendering failed")
            }
            return data

        case .webp:
            // WebP not directly supported by CIContext — fall back to PNG
            guard let data = ciContext.pngRepresentation(of: image, format: .RGBA8, colorSpace: colorSpace) else {
                throw ImageIntelligenceError.processingFailed("WebP rendering failed (PNG fallback)")
            }
            return data
        }
    }

    private func recordOperation(_ operation: ImageOperation, inputSize: Int64, outputSize: Int64, url: URL) {
        let record = ImageProcessingRecord(
            operation: operation,
            fileName: url.lastPathComponent,
            inputSize: inputSize,
            outputSize: outputSize
        )
        processingHistory.append(record)
        if processingHistory.count > 500 {
            processingHistory = Array(processingHistory.suffix(500))
        }
        saveHistory()
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFile.path) else { return }
        let data: Data
        do {
            data = try Data(contentsOf: historyFile)
        } catch {
            iiLogger.debug("Could not load image history: \(error.localizedDescription)")
            return
        }
        processingHistory = ErrorLogger.tryOrDefault(
            [],
            context: "ImageIntelligence.loadHistory.decode"
        ) {
            try JSONDecoder().decode([ImageProcessingRecord].self, from: data)
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(processingHistory)
            try data.write(to: historyFile, options: .atomic)
        } catch {
            ErrorLogger.log(error, context: "ImageIntelligence.saveHistory")
        }
    }
}

// MARK: - Processing Record

struct ImageProcessingRecord: Codable, Sendable, Identifiable {
    let id: UUID
    let operation: ImageOperation
    let fileName: String
    let inputSize: Int64
    let outputSize: Int64
    let processedAt: Date

    init(operation: ImageOperation, fileName: String, inputSize: Int64, outputSize: Int64) {
        self.id = UUID()
        self.operation = operation
        self.fileName = fileName
        self.inputSize = inputSize
        self.outputSize = outputSize
        self.processedAt = Date()
    }

    var compressionRatio: Double {
        guard inputSize > 0 else { return 0 }
        return 1.0 - (Double(outputSize) / Double(inputSize))
    }

    var formattedInputSize: String {
        imageFormatFileSize(inputSize)
    }

    var formattedOutputSize: String {
        imageFormatFileSize(outputSize)
    }
}

func imageFormatFileSize(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024, unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    if unitIndex == 0 { return "\(bytes) B" }
    return String(format: "%.1f %@", value, units[unitIndex])
}
