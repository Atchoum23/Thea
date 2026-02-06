# Nexus Phase 2: Core Enhancements - Detailed Technical Specifications

**Timeline:** 3-4 Months (Weeks 9-24)
**Team:** 3-4 developers
**Budget:** $120K-180K
**Risk Level:** MEDIUM

---

## Table of Contents

1. [Vision & Image Analysis](#21-vision--image-analysis)
2. [Advanced Voice Capabilities](#22-advanced-voice-capabilities)
3. [Knowledge Graph Enhancements](#23-knowledge-graph-enhancements)
4. [Workflow Automation Engine](#24-workflow-automation-engine)
5. [Plugin System Foundation](#25-plugin-system-foundation)

---

## 2.1 Vision & Image Analysis

**Status:** 🚧 **FOUNDATION IMPLEMENTED** - November 18, 2025  
**Implementation:** 4 weeks | **Priority:** HIGH | **Risk:** MEDIUM  
**Dependencies:** OpenAI GPT-4 Vision, DALL-E 3 APIs

**Implementation Details:**
- ✅ Vision types defined in `NexusTypes.swift`:
  - `ImageFormat`, `ImageAttachment`, `ImageAnalysis`
  - `DetectedObject`, `BoundingBox`, `ColorInfo`
  - `ImageMetadata`, `ImageStyle`, `ImageGenerationRequest`, `ImageEditRequest`
- ✅ `VisionEngine.swift` - Core API structure created with:
  - `analyzeImage()` - Image analysis foundation
  - `extractText()` - OCR text extraction structure
  - `detectObjects()` - Object detection structure
  - `generateImage()` - Image generation placeholder
  - `editImage()` - Image editing placeholder
- 🚧 Ready for GPT-4 Vision API integration
- 🚧 Ready for DALL-E 3 API integration
- 🚧 Image processing utilities structure in place

### Overview

Integrate multimodal AI capabilities to analyze images, extract text, detect objects, and generate visual content. This enables users to debug screenshots, analyze diagrams, understand visual data, and create images from natural language descriptions.

### Data Models

#### Core Data Entities

```swift
// ImageAttachment+CoreDataClass.swift
import Foundation
import CoreData
import AppKit

@objc(ImageAttachment)
public class ImageAttachment: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var imageData: Data
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var format: String
    @NSManaged public var width: Int32
    @NSManaged public var height: Int32
    @NSManaged public var fileSize: Int64
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

    // Relationships
    @NSManaged public var message: Message?
    @NSManaged public var analysis: ImageAnalysisResult?
    @NSManaged public var metadata: ImageMetadata?

    // Computed properties
    public var image: NSImage? {
        return NSImage(data: imageData)
    }

    public var thumbnail: NSImage? {
        if let thumbnailData = thumbnailData {
            return NSImage(data: thumbnailData)
        }
        return image?.resized(to: CGSize(width: 200, height: 200))
    }

    public var formatType: ImageFormat {
        return ImageFormat(rawValue: format) ?? .png
    }
}

// ImageAnalysisResult+CoreDataClass.swift
@objc(ImageAnalysisResult)
public class ImageAnalysisResult: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var description: String
    @NSManaged public var extractedText: String?
    @NSManaged public var mood: String?
    @NSManaged public var confidence: Double
    @NSManaged public var analyzedAt: Date
    @NSManaged public var modelUsed: String

    // JSON-encoded arrays
    @NSManaged private var objectsJSON: Data?
    @NSManaged private var colorsJSON: Data?
    @NSManaged private var tagsJSON: Data?

    // Relationships
    @NSManaged public var attachment: ImageAttachment?

    // Computed properties
    public var detectedObjects: [DetectedObject] {
        get {
            guard let data = objectsJSON else { return [] }
            return (try? JSONDecoder().decode([DetectedObject].self, from: data)) ?? []
        }
        set {
            objectsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var dominantColors: [ColorInfo] {
        get {
            guard let data = colorsJSON else { return [] }
            return (try? JSONDecoder().decode([ColorInfo].self, from: data)) ?? []
        }
        set {
            colorsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var suggestedTags: [String] {
        get {
            guard let data = tagsJSON else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            tagsJSON = try? JSONEncoder().encode(newValue)
        }
    }
}

// ImageMetadata+CoreDataClass.swift
@objc(ImageMetadata)
public class ImageMetadata: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var originalFilename: String?
    @NSManaged public var source: String  // camera, file, paste, url, generated
    @NSManaged public var capturedAt: Date?
    @NSManaged public var deviceModel: String?
    @NSManaged public var location: String?  // Latitude,Longitude
    @NSManaged public var exifData: Data?

    // Relationships
    @NSManaged public var attachment: ImageAttachment?
}
```

#### Swift Structs (for API and in-memory use)

```swift
// VisionTypes.swift
import Foundation
import CoreGraphics

public enum ImageFormat: String, Codable, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    case heic = "HEIC"
    case webp = "WEBP"
    case gif = "GIF"
    case pdf = "PDF"

    public var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        case .heic: return "image/heic"
        case .webp: return "image/webp"
        case .gif: return "image/gif"
        case .pdf: return "application/pdf"
        }
    }

    public var fileExtension: String {
        return rawValue.lowercased()
    }
}

public struct DetectedObject: Codable, Identifiable, Hashable {
    public let id: UUID
    public let label: String
    public let confidence: Double
    public let boundingBox: BoundingBox
    public let category: ObjectCategory?

    public init(
        id: UUID = UUID(),
        label: String,
        confidence: Double,
        boundingBox: BoundingBox,
        category: ObjectCategory? = nil
    ) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.category = category
    }

    public enum ObjectCategory: String, Codable {
        case person, animal, vehicle, furniture, electronics
        case nature, food, text, diagram, ui_element
    }
}

public struct BoundingBox: Codable, Hashable {
    public let x: Double  // Normalized 0-1
    public let y: Double  // Normalized 0-1
    public let width: Double  // Normalized 0-1
    public let height: Double  // Normalized 0-1

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func toCGRect(imageSize: CGSize) -> CGRect {
        return CGRect(
            x: x * imageSize.width,
            y: y * imageSize.height,
            width: width * imageSize.width,
            height: height * imageSize.height
        )
    }
}

public struct ColorInfo: Codable, Hashable {
    public let hex: String
    public let rgb: (r: Int, g: Int, b: Int)
    public let name: String?
    public let prominence: Double  // 0-1, percentage of image

    public init(hex: String, rgb: (r: Int, g: Int, b: Int), name: String? = nil, prominence: Double) {
        self.hex = hex
        self.rgb = rgb
        self.name = name
        self.prominence = prominence
    }
}

public enum ImageSource: String, Codable {
    case camera = "camera"
    case file = "file"
    case paste = "paste"
    case url = "url"
    case generated = "generated"
    case screenshot = "screenshot"
}

public enum ImageStyle: String, Codable, CaseIterable {
    case natural = "natural"
    case vivid = "vivid"
    case digital_art = "digital_art"
    case photographic = "photographic"
    case anime = "anime"
    case sketch = "sketch"
    case oil_painting = "oil_painting"

    public var displayName: String {
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

public struct ImageGenerationRequest: Codable {
    public let prompt: String
    public let style: ImageStyle
    public let size: ImageSize
    public let quality: ImageQuality
    public let numberOfImages: Int

    public init(
        prompt: String,
        style: ImageStyle = .natural,
        size: ImageSize = .square,
        quality: ImageQuality = .standard,
        numberOfImages: Int = 1
    ) {
        self.prompt = prompt
        self.style = style
        self.size = size
        self.quality = quality
        self.numberOfImages = numberOfImages
    }

    public enum ImageSize: String, Codable {
        case square = "1024x1024"
        case landscape = "1792x1024"
        case portrait = "1024x1792"
    }

    public enum ImageQuality: String, Codable {
        case standard = "standard"
        case hd = "hd"
    }
}

public struct ImageEditRequest: Codable {
    public let image: Data  // Original image
    public let instruction: String
    public let mask: Data?  // Optional mask for inpainting

    public init(image: Data, instruction: String, mask: Data? = nil) {
        self.image = image
        self.instruction = instruction
        self.mask = mask
    }
}
```

### Core Implementation

#### VisionEngine - Main Service

```swift
// VisionEngine.swift
import Foundation
import AppKit
import Vision
import CoreImage
import Combine

@MainActor
public final class VisionEngine: ObservableObject {
    public static let shared = VisionEngine()

    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var currentProgress: Double = 0
    @Published public private(set) var recentAnalyses: [ImageAnalysisResult] = []

    private let aiRouter: AIRouter
    private let cacheManager: VisionCacheManager
    private let imageProcessor: ImageProcessor
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.aiRouter = AIRouter.shared
        self.cacheManager = VisionCacheManager()
        self.imageProcessor = ImageProcessor()
    }

    // MARK: - Image Analysis

    /// Analyzes an image using GPT-4 Vision
    public func analyzeImage(
        _ image: NSImage,
        prompt: String? = nil,
        options: AnalysisOptions = AnalysisOptions()
    ) async throws -> ImageAnalysisResult {
        isAnalyzing = true
        currentProgress = 0
        defer { isAnalyzing = false }

        // Check cache first
        let cacheKey = cacheManager.generateKey(for: image, prompt: prompt)
        if let cached = cacheManager.getCached(key: cacheKey), options.useCache {
            currentProgress = 1.0
            return cached
        }

        // Prepare image data
        currentProgress = 0.2
        guard let imageData = image.pngData() else {
            throw VisionError.invalidImageFormat
        }

        // Resize if needed (GPT-4 Vision limit: 20MB, recommended < 2048px)
        let processedImage = try await imageProcessor.prepareForAnalysis(image)
        guard let processedData = processedImage.jpegData(compressionQuality: 0.85) else {
            throw VisionError.imageProcessingFailed
        }

        currentProgress = 0.4

        // Build request
        let base64Image = processedData.base64EncodedString()
        let analysisPrompt = buildAnalysisPrompt(userPrompt: prompt, options: options)

        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": analysisPrompt],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(base64Image)",
                            "detail": options.detailLevel.rawValue
                        ]
                    ]
                ]
            ]
        ]

        currentProgress = 0.6

        // Call GPT-4 Vision
        let response = try await aiRouter.sendRequest(
            messages: messages,
            model: .gpt4Vision,
            temperature: 0.3,
            maxTokens: 1000
        )

        currentProgress = 0.8

        // Parse response
        let analysisResult = try parseAnalysisResponse(
            response: response.choices.first?.message.content ?? "",
            image: processedImage,
            options: options
        )

        // Perform additional analyses if requested
        if options.includeOCR {
            analysisResult.extractedText = try await extractText(from: processedImage)
        }

        if options.includeObjectDetection {
            analysisResult.detectedObjects = try await detectObjects(in: processedImage)
        }

        if options.includeColorAnalysis {
            analysisResult.dominantColors = await analyzeColors(in: processedImage)
        }

        currentProgress = 1.0

        // Cache result
        cacheManager.cache(analysisResult, for: cacheKey)
        recentAnalyses.insert(analysisResult, at: 0)

        return analysisResult
    }

    /// Extracts text from image using Vision framework (OCR)
    public func extractText(from image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImageFormat
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let recognizedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: recognizedText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Detects objects using Vision framework
    public func detectObjects(in image: NSImage) async throws -> [DetectedObject] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionError.invalidImageFormat
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeAnimalsRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let objects = observations.map { observation in
                    DetectedObject(
                        label: observation.labels.first?.identifier ?? "Unknown",
                        confidence: Double(observation.confidence),
                        boundingBox: BoundingBox(
                            x: Double(observation.boundingBox.origin.x),
                            y: Double(observation.boundingBox.origin.y),
                            width: Double(observation.boundingBox.width),
                            height: Double(observation.boundingBox.height)
                        )
                    )
                }

                continuation.resume(returning: objects)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Analyzes dominant colors in the image
    public func analyzeColors(in image: NSImage) async -> [ColorInfo] {
        return await Task.detached {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return []
            }

            let ciImage = CIImage(cgImage: cgImage)
            let extents = ciImage.extent

            // Use CIAreaAverage to get dominant color
            let filter = CIFilter(name: "CIAreaAverage", parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: CIVector(cgRect: extents)
            ])

            guard let outputImage = filter?.outputImage,
                  let bitmap = self.imageProcessor.createBitmap(from: outputImage) else {
                return []
            }

            var colors: [ColorInfo] = []

            // Extract RGBA values
            let r = Int(bitmap[0])
            let g = Int(bitmap[1])
            let b = Int(bitmap[2])

            let hex = String(format: "#%02X%02X%02X", r, g, b)

            colors.append(ColorInfo(
                hex: hex,
                rgb: (r: r, g: g, b: b),
                name: self.getColorName(r: r, g: g, b: b),
                prominence: 1.0
            ))

            return colors
        }.value
    }

    // MARK: - Image Generation

    /// Generates an image from a text prompt using DALL-E 3
    public func generateImage(request: ImageGenerationRequest) async throws -> [NSImage] {
        isAnalyzing = true
        currentProgress = 0
        defer { isAnalyzing = false }

        let requestBody: [String: Any] = [
            "model": "dall-e-3",
            "prompt": request.prompt,
            "n": request.numberOfImages,
            "size": request.size.rawValue,
            "quality": request.quality.rawValue,
            "style": request.style.rawValue
        ]

        currentProgress = 0.3

        // Call OpenAI DALL-E API
        let response = try await aiRouter.generateImage(requestBody: requestBody)

        currentProgress = 0.7

        // Download generated images
        var images: [NSImage] = []
        for imageURL in response.imageURLs {
            if let url = URL(string: imageURL),
               let data = try? Data(contentsOf: url),
               let image = NSImage(data: data) {
                images.append(image)
            }
        }

        currentProgress = 1.0

        guard !images.isEmpty else {
            throw VisionError.imageGenerationFailed
        }

        return images
    }

    /// Edits an image using natural language instructions
    public func editImage(request: ImageEditRequest) async throws -> NSImage {
        isAnalyzing = true
        currentProgress = 0
        defer { isAnalyzing = false }

        // Prepare image for editing (must be PNG, square, < 4MB)
        guard let image = NSImage(data: request.image) else {
            throw VisionError.invalidImageFormat
        }

        let processedImage = try await imageProcessor.prepareForEdit(image)
        guard let processedData = processedImage.pngData() else {
            throw VisionError.imageProcessingFailed
        }

        currentProgress = 0.4

        // Call OpenAI Image Edit API
        let response = try await aiRouter.editImage(
            image: processedData,
            instruction: request.instruction,
            mask: request.mask
        )

        currentProgress = 0.8

        // Download edited image
        guard let urlString = response.imageURLs.first,
              let url = URL(string: urlString),
              let data = try? Data(contentsOf: url),
              let editedImage = NSImage(data: data) else {
            throw VisionError.imageEditFailed
        }

        currentProgress = 1.0

        return editedImage
    }

    // MARK: - Helper Methods

    private func buildAnalysisPrompt(userPrompt: String?, options: AnalysisOptions) -> String {
        var prompt = "Analyze this image and provide:\n"
        prompt += "1. A detailed description of what you see\n"

        if options.includeObjectDetection {
            prompt += "2. List of main objects and their locations\n"
        }

        if options.includeMoodAnalysis {
            prompt += "3. The mood or atmosphere of the image\n"
        }

        if options.includeTags {
            prompt += "4. Relevant tags or categories\n"
        }

        if let userPrompt = userPrompt {
            prompt += "\nAdditional request: \(userPrompt)"
        }

        return prompt
    }

    private func parseAnalysisResponse(
        response: String,
        image: NSImage,
        options: AnalysisOptions
    ) throws -> ImageAnalysisResult {
        // Parse the GPT-4 Vision response
        let result = ImageAnalysisResult(context: CoreDataManager.shared.viewContext)
        result.id = UUID()
        result.description = response
        result.confidence = 0.9  // GPT-4 Vision is highly confident
        result.analyzedAt = Date()
        result.modelUsed = "gpt-4-vision-preview"

        // Extract tags using simple heuristics
        // In production, you'd use more sophisticated NLP
        let words = response.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 }
        result.suggestedTags = Array(Set(words.prefix(10)))

        return result
    }

    private func getColorName(r: Int, g: Int, b: Int) -> String {
        // Simple color naming based on HSV
        // In production, use a comprehensive color naming library
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)

        if maxVal - minVal < 30 {
            if maxVal < 50 { return "Black" }
            if maxVal > 200 { return "White" }
            return "Gray"
        }

        if r > g && r > b { return "Red" }
        if g > r && g > b { return "Green" }
        if b > r && b > g { return "Blue" }

        if r > 150 && g > 150 && b < 100 { return "Yellow" }
        if r > 150 && b > 150 && g < 100 { return "Magenta" }
        if g > 150 && b > 150 && r < 100 { return "Cyan" }

        return "Unknown"
    }
}

// MARK: - Supporting Types

public struct AnalysisOptions {
    public var useCache: Bool = true
    public var detailLevel: DetailLevel = .auto
    public var includeOCR: Bool = false
    public var includeObjectDetection: Bool = true
    public var includeColorAnalysis: Bool = true
    public var includeMoodAnalysis: Bool = true
    public var includeTags: Bool = true

    public init() {}

    public enum DetailLevel: String {
        case low = "low"
        case high = "high"
        case auto = "auto"
    }
}

public enum VisionError: LocalizedError {
    case invalidImageFormat
    case imageProcessingFailed
    case imageGenerationFailed
    case imageEditFailed
    case analysisTimeout
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImageFormat:
            return "Invalid or unsupported image format"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .imageGenerationFailed:
            return "Failed to generate image"
        case .imageEditFailed:
            return "Failed to edit image"
        case .analysisTimeout:
            return "Image analysis timed out"
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
}
```

#### Image Processor - Utility Service

```swift
// ImageProcessor.swift
import Foundation
import AppKit
import CoreImage

public final class ImageProcessor {
    private let maxAnalysisSize: CGFloat = 2048
    private let maxEditSize: CGFloat = 1024
    private let maxFileSize: Int = 20 * 1024 * 1024  // 20MB

    public init() {}

    /// Prepares image for GPT-4 Vision analysis
    public func prepareForAnalysis(_ image: NSImage) async throws -> NSImage {
        return try await Task.detached {
            var processedImage = image

            // Resize if too large
            let size = image.size
            if size.width > self.maxAnalysisSize || size.height > self.maxAnalysisSize {
                processedImage = self.resize(
                    image,
                    to: CGSize(
                        width: min(size.width, self.maxAnalysisSize),
                        height: min(size.height, self.maxAnalysisSize)
                    )
                )
            }

            return processedImage
        }.value
    }

    /// Prepares image for DALL-E editing (must be square, PNG, < 4MB)
    public func prepareForEdit(_ image: NSImage) async throws -> NSImage {
        return try await Task.detached {
            let size = image.size
            let targetSize = min(size.width, size.height, self.maxEditSize)

            // Make square by cropping to center
            let squareImage = self.cropToSquare(image, size: targetSize)

            return squareImage
        }.value
    }

    /// Resizes image while maintaining aspect ratio
    public func resize(_ image: NSImage, to newSize: CGSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }

    /// Crops image to square from center
    public func cropToSquare(_ image: NSImage, size: CGFloat) -> NSImage {
        let imageSize = image.size
        let dimension = min(imageSize.width, imageSize.height)

        let x = (imageSize.width - dimension) / 2
        let y = (imageSize.height - dimension) / 2

        let cropRect = NSRect(x: x, y: y, width: dimension, height: dimension)

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cropped = cgImage.cropping(to: cropRect) else {
            return image
        }

        let croppedImage = NSImage(cgImage: cropped, size: NSSize(width: dimension, height: dimension))

        if dimension != size {
            return resize(croppedImage, to: CGSize(width: size, height: size))
        }

        return croppedImage
    }

    /// Creates bitmap data from CIImage for color analysis
    public func createBitmap(from image: CIImage) -> [UInt8]? {
        let context = CIContext()
        let extent = image.extent

        guard let cgImage = context.createCGImage(image, from: extent) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelData
    }
}
```

#### Vision Cache Manager

```swift
// VisionCacheManager.swift
import Foundation
import CryptoKit

public final class VisionCacheManager {
    private var cache: [String: CachedAnalysis] = [:]
    private let maxCacheSize = 100
    private let cacheExpiration: TimeInterval = 3600 * 24  // 24 hours

    public init() {}

    public func generateKey(for image: NSImage, prompt: String?) -> String {
        guard let imageData = image.tiffRepresentation else {
            return UUID().uuidString
        }

        let hash = SHA256.hash(data: imageData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        if let prompt = prompt {
            return "\(hashString)_\(prompt.hashValue)"
        }

        return hashString
    }

    public func cache(_ analysis: ImageAnalysisResult, for key: String) {
        // Evict old entries if cache is full
        if cache.count >= maxCacheSize {
            let oldestKey = cache.min(by: { $0.value.cachedAt < $1.value.cachedAt })?.key
            if let key = oldestKey {
                cache.removeValue(forKey: key)
            }
        }

        cache[key] = CachedAnalysis(analysis: analysis, cachedAt: Date())
    }

    public func getCached(key: String) -> ImageAnalysisResult? {
        guard let cached = cache[key] else { return nil }

        // Check if expired
        if Date().timeIntervalSince(cached.cachedAt) > cacheExpiration {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.analysis
    }

    public func clearCache() {
        cache.removeAll()
    }

    private struct CachedAnalysis {
        let analysis: ImageAnalysisResult
        let cachedAt: Date
    }
}
```

### UI Components

#### Image Analysis View

```swift
// ImageAnalysisView.swift
import SwiftUI

public struct ImageAnalysisView: View {
    let image: NSImage
    let analysis: ImageAnalysisResult?

    @StateObject private var visionEngine = VisionEngine.shared
    @State private var isAnalyzing = false
    @State private var customPrompt = ""
    @State private var analysisOptions = AnalysisOptions()

    public var body: some View {
        HStack(spacing: 0) {
            // Image Preview
            VStack {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400, maxHeight: 400)
                    .cornerRadius(8)

                if visionEngine.isAnalyzing {
                    ProgressView(value: visionEngine.currentProgress)
                        .padding()
                }

                HStack {
                    TextField("Ask about this image...", text: $customPrompt)
                        .textFieldStyle(.roundedBorder)

                    Button("Analyze") {
                        Task {
                            await analyzeImage()
                        }
                    }
                    .disabled(isAnalyzing)
                }
                .padding()
            }
            .frame(maxWidth: 500)

            Divider()

            // Analysis Results
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let analysis = analysis {
                        AnalysisResultsView(analysis: analysis)
                    } else {
                        Text("No analysis yet")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
    }

    private func analyzeImage() async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            _ = try await visionEngine.analyzeImage(
                image,
                prompt: customPrompt.isEmpty ? nil : customPrompt,
                options: analysisOptions
            )
        } catch {
            print("Analysis failed: \(error)")
        }
    }
}

struct AnalysisResultsView: View {
    let analysis: ImageAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Description
            GroupBox("Description") {
                Text(analysis.description)
                    .font(.body)
            }

            // Detected Objects
            if !analysis.detectedObjects.isEmpty {
                GroupBox("Detected Objects") {
                    ForEach(analysis.detectedObjects) { object in
                        HStack {
                            Text(object.label)
                            Spacer()
                            Text("\(Int(object.confidence * 100))%")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Extracted Text (OCR)
            if let text = analysis.extractedText, !text.isEmpty {
                GroupBox("Extracted Text") {
                    Text(text)
                        .font(.monospaced(.body)())
                        .textSelection(.enabled)
                }
            }

            // Colors
            if !analysis.dominantColors.isEmpty {
                GroupBox("Dominant Colors") {
                    HStack {
                        ForEach(analysis.dominantColors, id: \.hex) { color in
                            VStack {
                                Circle()
                                    .fill(Color(hex: color.hex))
                                    .frame(width: 40, height: 40)
                                Text(color.name ?? color.hex)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            // Tags
            if !analysis.suggestedTags.isEmpty {
                GroupBox("Tags") {
                    FlowLayout(spacing: 8) {
                        ForEach(analysis.suggestedTags, id: \.self) { tag in
                            Text(tag)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }

            // Metadata
            GroupBox("Metadata") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Analyzed:")
                        Spacer()
                        Text(analysis.analyzedAt.formatted())
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Model:")
                        Spacer()
                        Text(analysis.modelUsed)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Confidence:")
                        Spacer()
                        Text("\(Int(analysis.confidence * 100))%")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }
        }
    }
}

// Flow layout helper for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        let height = rows.last?.maxY ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        for row in rows {
            for item in row.items {
                let itemProposal = ProposedViewSize(width: item.size.width, height: item.size.height)
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + item.y),
                    proposal: itemProposal
                )
            }
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        var y: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > (proposal.width ?? .infinity) && !currentRow.items.isEmpty {
                rows.append(currentRow)
                y = currentRow.maxY + spacing
                currentRow = Row()
                x = 0
            }

            currentRow.items.append(FlowItem(index: index, x: x, y: y, size: size))
            x += size.width + spacing
        }

        if !currentRow.items.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    struct Row {
        var items: [FlowItem] = []
        var maxY: CGFloat {
            items.map { $0.y + $0.size.height }.max() ?? 0
        }
    }

    struct FlowItem {
        let index: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGSize
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
```


#### Image Generation View

```swift
// ImageGenerationView.swift
import SwiftUI

public struct ImageGenerationView: View {
    @StateObject private var visionEngine = VisionEngine.shared
    @State private var prompt = ""
    @State private var style: ImageStyle = .natural
    @State private var size: ImageGenerationRequest.ImageSize = .square
    @State private var quality: ImageGenerationRequest.ImageQuality = .standard
    @State private var generatedImages: [NSImage] = []
    @State private var isGenerating = false
    @State private var error: String?

    public var body: some View {
        VStack(spacing: 16) {
            // Input Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Generate Image")
                    .font(.title2)
                    .bold()

                TextEditor(text: $prompt)
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3))
                    .overlay(
                        Group {
                            if prompt.isEmpty {
                                Text("Describe the image you want to generate...")
                                    .foregroundColor(.secondary)
                                    .padding(8)
                            }
                        },
                        alignment: .topLeading
                    )

                HStack {
                    Picker("Style:", selection: $style) {
                        ForEach(ImageStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .frame(width: 200)

                    Picker("Size:", selection: $size) {
                        Text("Square (1024×1024)").tag(ImageGenerationRequest.ImageSize.square)
                        Text("Landscape (1792×1024)").tag(ImageGenerationRequest.ImageSize.landscape)
                        Text("Portrait (1024×1792)").tag(ImageGenerationRequest.ImageSize.portrait)
                    }
                    .frame(width: 200)

                    Picker("Quality:", selection: $quality) {
                        Text("Standard").tag(ImageGenerationRequest.ImageQuality.standard)
                        Text("HD").tag(ImageGenerationRequest.ImageQuality.hd)
                    }
                    .frame(width: 150)
                }

                Button(action: generateImage) {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Generate")
                    }
                }
                .disabled(prompt.isEmpty || isGenerating)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            // Results Section
            if !generatedImages.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
                        ForEach(generatedImages.indices, id: \.self) { index in
                            VStack {
                                Image(nsImage: generatedImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(8)

                                HStack {
                                    Button("Save") {
                                        saveImage(generatedImages[index])
                                    }

                                    Button("Use in Chat") {
                                        useImageInChat(generatedImages[index])
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
    }

    private func generateImage() {
        Task {
            isGenerating = true
            error = nil
            defer { isGenerating = false }

            do {
                let request = ImageGenerationRequest(
                    prompt: prompt,
                    style: style,
                    size: size,
                    quality: quality,
                    numberOfImages: 1
                )

                let images = try await visionEngine.generateImage(request: request)
                generatedImages = images
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func saveImage(_ image: NSImage) {
        // Implement save to file
    }

    private func useImageInChat(_ image: NSImage) {
        // Implement insert into current conversation
    }
}
```

### Testing Strategy

```swift
// VisionEngineTests.swift
import XCTest
@testable import NexusCore

final class VisionEngineTests: XCTestCase {
    var visionEngine: VisionEngine!

    override func setUp() async throws {
        visionEngine = VisionEngine.shared
    }

    func testImageAnalysis() async throws {
        // Load test image
        let bundle = Bundle(for: type(of: self))
        guard let imageURL = bundle.url(forResource: "test_image", withExtension: "png"),
              let image = NSImage(contentsOf: imageURL) else {
            XCTFail("Failed to load test image")
            return
        }

        // Analyze image
        let analysis = try await visionEngine.analyzeImage(image)

        // Verify results
        XCTAssertFalse(analysis.description.isEmpty)
        XCTAssertGreaterThan(analysis.confidence, 0.5)
        XCTAssertNotNil(analysis.analyzedAt)
    }

    func testOCR() async throws {
        // Load image with text
        let bundle = Bundle(for: type(of: self))
        guard let imageURL = bundle.url(forResource: "text_image", withExtension: "png"),
              let image = NSImage(contentsOf: imageURL) else {
            XCTFail("Failed to load test image")
            return
        }

        // Extract text
        let extractedText = try await visionEngine.extractText(from: image)

        // Verify text was extracted
        XCTAssertFalse(extractedText.isEmpty)
        XCTAssertTrue(extractedText.contains("expected text"))
    }

    func testObjectDetection() async throws {
        // Load image with objects
        let bundle = Bundle(for: type(of: self))
        guard let imageURL = bundle.url(forResource: "objects_image", withExtension: "png"),
              let image = NSImage(contentsOf: imageURL) else {
            XCTFail("Failed to load test image")
            return
        }

        // Detect objects
        let objects = try await visionEngine.detectObjects(in: image)

        // Verify objects detected
        XCTAssertGreaterThan(objects.count, 0)
        XCTAssertGreaterThan(objects.first?.confidence ?? 0, 0.5)
    }

    func testColorAnalysis() async throws {
        // Create simple colored image
        let image = createSolidColorImage(color: .red, size: CGSize(width: 100, height: 100))

        // Analyze colors
        let colors = await visionEngine.analyzeColors(in: image)

        // Verify red was detected
        XCTAssertGreaterThan(colors.count, 0)
        XCTAssertTrue(colors.first?.name?.lowercased().contains("red") ?? false)
    }

    func testImageGeneration() async throws {
        let request = ImageGenerationRequest(
            prompt: "A serene landscape with mountains",
            style: .natural,
            size: .square,
            quality: .standard,
            numberOfImages: 1
        )

        let images = try await visionEngine.generateImage(request: request)

        XCTAssertEqual(images.count, 1)
        XCTAssertNotNil(images.first)
    }

    func testCaching() async throws {
        let bundle = Bundle(for: type(of: self))
        guard let imageURL = bundle.url(forResource: "test_image", withExtension: "png"),
              let image = NSImage(contentsOf: imageURL) else {
            XCTFail("Failed to load test image")
            return
        }

        // First analysis
        let start1 = Date()
        _ = try await visionEngine.analyzeImage(image)
        let duration1 = Date().timeIntervalSince(start1)

        // Second analysis (should be cached)
        let start2 = Date()
        _ = try await visionEngine.analyzeImage(image)
        let duration2 = Date().timeIntervalSince(start2)

        // Cached version should be significantly faster
        XCTAssertLessThan(duration2, duration1 * 0.1)
    }

    // Helper methods
    private func createSolidColorImage(color: NSColor, size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}
```

### Success Metrics

- **Adoption:** 50% of users attach at least one image within 30 days
- **Accuracy:** 90% OCR accuracy on standard fonts
- **Performance:** < 5s average image analysis time
- **Reliability:** 99% successful analysis rate
- **User Satisfaction:** 4.5+ star rating for vision features

### Cost Estimate

- **GPT-4 Vision:** ~$0.01 per image (detailed analysis)
- **DALL-E 3:** $0.04 per image (standard), $0.08 per image (HD)
- **Monthly estimate:** $50-200 depending on usage (500-2,000 images/month)

---

## 2.2 Advanced Voice Capabilities

**Implementation:** 4 weeks | **Priority:** HIGH | **Risk:** MEDIUM
**Dependencies:** OpenAI Whisper API, ElevenLabs or Apple Neural TTS

### Overview

Enhance voice capabilities with hands-free continuous listening, multi-language support, custom voice profiles, and advanced speech recognition. This enables natural voice conversations, voice commands, and accessibility features.

### Data Models

#### Core Data Entities

```swift
// VoiceSession+CoreDataClass.swift
import Foundation
import CoreData

@objc(VoiceSession)
public class VoiceSession: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var language: String
    @NSManaged public var voiceModel: String
    @NSManaged public var wakeWord: String?
    @NSManaged public var isContinuous: Bool
    @NSManaged public var startedAt: Date
    @NSManaged public var endedAt: Date?
    @NSManaged public var duration: TimeInterval
    @NSManaged public var audioQuality: Double

    // Relationships
    @NSManaged public var transcriptions: NSSet?
    @NSManaged public var conversation: Conversation?

    // JSON-encoded data
    @NSManaged private var settingsJSON: Data?

    public var settings: VoiceSessionSettings? {
        get {
            guard let data = settingsJSON else { return nil }
            return try? JSONDecoder().decode(VoiceSessionSettings.self, from: data)
        }
        set {
            settingsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var transcriptionArray: [VoiceTranscription] {
        let set = transcriptions as? Set<VoiceTranscription> ?? []
        return set.sorted { $0.timestamp < $1.timestamp }
    }
}

// VoiceTranscription+CoreDataClass.swift
@objc(VoiceTranscription)
public class VoiceTranscription: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var text: String
    @NSManaged public var confidence: Double
    @NSManaged public var language: String
    @NSManaged public var speaker: String?
    @NSManaged public var timestamp: Date
    @NSManaged public var duration: TimeInterval
    @NSManaged public var audioData: Data?

    // Relationships
    @NSManaged public var session: VoiceSession?
}

// VoiceProfile+CoreDataClass.swift
@objc(VoiceProfile)
public class VoiceProfile: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var voiceID: String
    @NSManaged public var provider: String  // apple, elevenlabs, openai
    @NSManaged public var language: String
    @NSManaged public var gender: String?
    @NSManaged public var pitch: Double
    @NSManaged public var speed: Double
    @NSManaged public var isDefault: Bool
    @NSManaged public var createdAt: Date

    // JSON-encoded customization
    @NSManaged private var customizationJSON: Data?

    public var customization: VoiceCustomization? {
        get {
            guard let data = customizationJSON else { return nil }
            return try? JSONDecoder().decode(VoiceCustomization.self, from: data)
        }
        set {
            customizationJSON = try? JSONEncoder().encode(newValue)
        }
    }
}
```

#### Swift Structs

```swift
// VoiceTypes.swift
import Foundation

public enum Language: String, Codable, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case chinese = "zh"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case korean = "ko"

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .japanese: return "Japanese"
        case .chinese: return "Chinese (Mandarin)"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .russian: return "Russian"
        case .korean: return "Korean"
        }
    }

    public var whisperCode: String {
        return rawValue
    }
}

public enum VoiceProvider: String, Codable {
    case apple = "apple"
    case elevenLabs = "elevenlabs"
    case openAI = "openai"

    public var displayName: String {
        switch self {
        case .apple: return "Apple Neural TTS"
        case .elevenLabs: return "ElevenLabs"
        case .openAI: return "OpenAI TTS"
        }
    }
}

public struct VoiceSessionSettings: Codable {
    public var enableWakeWord: Bool
    public var wakeWord: String
    public var continuousListening: Bool
    public var autoSubmit: Bool
    public var noiseCancellation: Bool
    public var echoSuppression: Bool
    public var vadThreshold: Double  // Voice Activity Detection threshold

    public init(
        enableWakeWord: Bool = false,
        wakeWord: String = "Hey Nexus",
        continuousListening: Bool = false,
        autoSubmit: Bool = false,
        noiseCancellation: Bool = true,
        echoSuppression: Bool = true,
        vadThreshold: Double = 0.5
    ) {
        self.enableWakeWord = enableWakeWord
        self.wakeWord = wakeWord
        self.continuousListening = continuousListening
        self.autoSubmit = autoSubmit
        self.noiseCancellation = noiseCancellation
        self.echoSuppression = echoSuppression
        self.vadThreshold = vadThreshold
    }
}

public struct VoiceCustomization: Codable {
    public var pitch: Double  // -1.0 to 1.0
    public var speed: Double  // 0.5 to 2.0
    public var volume: Double  // 0.0 to 1.0
    public var emphasis: EmphasisLevel
    public var pause: PauseLength

    public init(
        pitch: Double = 0.0,
        speed: Double = 1.0,
        volume: Double = 1.0,
        emphasis: EmphasisLevel = .moderate,
        pause: PauseLength = .normal
    ) {
        self.pitch = pitch
        self.speed = speed
        self.volume = volume
        self.emphasis = emphasis
        self.pause = pause
    }

    public enum EmphasisLevel: String, Codable {
        case none, light, moderate, strong
    }

    public enum PauseLength: String, Codable {
        case short, normal, long
    }
}

public struct TranscriptionSegment: Codable, Identifiable {
    public let id: UUID
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
    public let confidence: Double
    public let words: [Word]?

    public init(
        id: UUID = UUID(),
        text: String,
        start: TimeInterval,
        end: TimeInterval,
        confidence: Double,
        words: [Word]? = nil
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
        self.words = words
    }

    public struct Word: Codable {
        public let text: String
        public let start: TimeInterval
        public let end: TimeInterval
        public let confidence: Double
    }
}
```

### Core Implementation

#### Voice Engine - Main Service

```swift
// VoiceEngine.swift
import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
public final class VoiceEngine: NSObject, ObservableObject {
    public static let shared = VoiceEngine()

    @Published public private(set) var isListening = false
    @Published public private(set) var isSpeaking = false
    @Published public private(set) var currentTranscription = ""
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var currentLanguage: Language = .english
    @Published public private(set) var voiceProfile: VoiceProfile?

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioSession: AVAudioSession = .sharedInstance()
    private var synthesizer: AVSpeechSynthesizer?

    private var currentSession: VoiceSession?
    private var sessionSettings: VoiceSessionSettings = VoiceSessionSettings()
    private var wakeWordDetector: WakeWordDetector?

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        setupAudioSession()
        loadVoiceProfile()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func loadVoiceProfile() {
        // Load default voice profile from Core Data
        let context = CoreDataManager.shared.viewContext
        let request = VoiceProfile.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")
        request.fetchLimit = 1

        if let profile = try? context.fetch(request).first {
            self.voiceProfile = profile
        }
    }

    // MARK: - Speech Recognition

    /// Starts listening for voice input
    public func startListening(
        language: Language = .english,
        continuous: Bool = false
    ) async throws {
        guard !isListening else { return }

        // Request authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus != .authorized {
            try await requestSpeechAuthorization()
        }

        // Setup recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue))
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceError.recognizerUnavailable
        }

        // Create session
        let context = CoreDataManager.shared.viewContext
        let session = VoiceSession(context: context)
        session.id = UUID()
        session.language = language.rawValue
        session.isContinuous = continuous
        session.startedAt = Date()
        currentSession = session

        // Setup audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw VoiceError.audioEngineFailure
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionRequestFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        if continuous {
            recognitionRequest.requiresOnDeviceRecognition = false
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level
            Task { @MainActor in
                self?.updateAudioLevel(from: buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let result = result {
                    self.currentTranscription = result.bestTranscription.formattedString

                    if result.isFinal {
                        await self.handleFinalTranscription(result.bestTranscription)
                    }
                }

                if error != nil || result?.isFinal == true {
                    if continuous {
                        // Restart recognition for continuous mode
                        try? await self.restartRecognition()
                    } else {
                        await self.stopListening()
                    }
                }
            }
        }

        isListening = true
    }

    /// Stops listening
    public func stopListening() async {
        guard isListening else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil

        if let session = currentSession {
            session.endedAt = Date()
            session.duration = session.endedAt!.timeIntervalSince(session.startedAt)
            try? CoreDataManager.shared.viewContext.save()
        }

        isListening = false
        currentTranscription = ""
    }

    /// Transcribes audio file using Whisper API
    public func transcribeAudio(
        _ audioData: Data,
        language: Language? = nil
    ) async throws -> TranscriptionSegment {
        // Save audio to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Call Whisper API
        let aiRouter = AIRouter.shared
        let response = try await aiRouter.transcribeAudio(
            audioURL: tempURL,
            model: "whisper-1",
            language: language?.whisperCode
        )

        return TranscriptionSegment(
            text: response.text,
            start: 0,
            end: response.duration ?? 0,
            confidence: 1.0,
            words: nil
        )
    }

    // MARK: - Text-to-Speech

    /// Speaks text using configured voice
    public func speak(
        _ text: String,
        voice: VoiceProfile? = nil,
        language: Language? = nil
    ) async throws {
        guard !isSpeaking else { return }

        let activeVoice = voice ?? voiceProfile
        let activeLang = language ?? currentLanguage

        isSpeaking = true
        defer { isSpeaking = false }

        if let profile = activeVoice, profile.provider == VoiceProvider.elevenLabs.rawValue {
            // Use ElevenLabs API
            try await speakWithElevenLabs(text, voice: profile)
        } else if let profile = activeVoice, profile.provider == VoiceProvider.openAI.rawValue {
            // Use OpenAI TTS API
            try await speakWithOpenAI(text, voice: profile)
        } else {
            // Use Apple Neural TTS (on-device)
            try await speakWithApple(text, language: activeLang, customization: activeVoice?.customization)
        }
    }

    /// Stops speaking
    public func stopSpeaking() {
        synthesizer?.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - Private Methods

    private func requestSpeechAuthorization() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                if status == .authorized {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: VoiceError.authorizationDenied)
                }
            }
        }
    }

    private func restartRecognition() async throws {
        await stopListening()
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second pause
        try await startListening(language: currentLanguage, continuous: true)
    }

    private func handleFinalTranscription(_ transcription: SFTranscription) async {
        guard let session = currentSession else { return }

        let context = CoreDataManager.shared.viewContext
        let voiceTranscription = VoiceTranscription(context: context)
        voiceTranscription.id = UUID()
        voiceTranscription.text = transcription.formattedString
        voiceTranscription.confidence = calculateAverageConfidence(transcription)
        voiceTranscription.language = session.language
        voiceTranscription.timestamp = Date()
        voiceTranscription.session = session

        try? context.save()

        // Post notification
        NotificationCenter.default.post(
            name: .voiceTranscriptionComplete,
            object: voiceTranscription
        )
    }

    private func calculateAverageConfidence(_ transcription: SFTranscription) -> Double {
        let segments = transcription.segments
        guard !segments.isEmpty else { return 0 }

        let totalConfidence = segments.reduce(0.0) { $0 + Double($1.confidence) }
        return totalConfidence / Double(segments.count)
    }

    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frames = buffer.frameLength
        var sum: Float = 0

        for i in 0..<Int(frames) {
            let sample = channelData[i]
            sum += abs(sample)
        }

        audioLevel = sum / Float(frames)
    }

    private func speakWithApple(_ text: String, language: Language, customization: VoiceCustomization?) async throws {
        synthesizer = AVSpeechSynthesizer()
        synthesizer?.delegate = self

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)

        if let custom = customization {
            utterance.pitchMultiplier = Float(1.0 + custom.pitch)
            utterance.rate = Float(custom.speed * 0.5)  // AVSpeech uses 0-1 range
            utterance.volume = Float(custom.volume)
        }

        return try await withCheckedThrowingContinuation { continuation in
            speakContinuation = continuation
            synthesizer?.speak(utterance)
        }
    }

    private var speakContinuation: CheckedContinuation<Void, Error>?

    private func speakWithElevenLabs(_ text: String, voice: VoiceProfile) async throws {
        // Implementation for ElevenLabs API
        // This would make an HTTP request to ElevenLabs API
        throw VoiceError.providerNotImplemented
    }

    private func speakWithOpenAI(_ text: String, voice: VoiceProfile) async throws {
        // Implementation for OpenAI TTS API
        let aiRouter = AIRouter.shared
        let audioData = try await aiRouter.generateSpeech(
            text: text,
            model: "tts-1",
            voice: voice.voiceID
        )

        // Play audio
        try await playAudio(audioData)
    }

    private func playAudio(_ audioData: Data) async throws {
        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Create audio player
        let player = try AVAudioPlayer(contentsOf: tempURL)
        player.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            playbackContinuation = continuation
            player.play()
        }
    }

    private var playbackContinuation: CheckedContinuation<Void, Error>?
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceEngine: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        speakContinuation?.resume()
        speakContinuation = nil
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speakContinuation?.resume(throwing: VoiceError.speakingCancelled)
        speakContinuation = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceEngine: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            playbackContinuation?.resume()
        } else {
            playbackContinuation?.resume(throwing: VoiceError.playbackFailed)
        }
        playbackContinuation = nil
    }
}

// MARK: - Errors

public enum VoiceError: LocalizedError {
    case recognizerUnavailable
    case audioEngineFailure
    case recognitionRequestFailed
    case authorizationDenied
    case speakingCancelled
    case playbackFailed
    case providerNotImplemented
    case invalidAudioFormat

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognizer is not available for this language"
        case .audioEngineFailure:
            return "Failed to initialize audio engine"
        case .recognitionRequestFailed:
            return "Failed to create recognition request"
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        case .speakingCancelled:
            return "Speech synthesis was cancelled"
        case .playbackFailed:
            return "Audio playback failed"
        case .providerNotImplemented:
            return "Voice provider not yet implemented"
        case .invalidAudioFormat:
            return "Invalid audio format"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let voiceTranscriptionComplete = Notification.Name("voiceTranscriptionComplete")
    public static let voiceWakeWordDetected = Notification.Name("voiceWakeWordDetected")
}
```


#### Voice Controls UI

```swift
// VoiceControlsView.swift
import SwiftUI

public struct VoiceControlsView: View {
    @StateObject private var voiceEngine = VoiceEngine.shared
    @State private var selectedLanguage: Language = .english
    @State private var continuousMode = false
    @State private var showSettings = false
    @State private var error: String?

    public var body: some View {
        VStack(spacing: 16) {
            // Audio Level Visualizer
            if voiceEngine.isListening {
                AudioLevelVisualizerView(level: voiceEngine.audioLevel)
                    .frame(height: 100)
                    .animation(.easeInOut(duration: 0.1), value: voiceEngine.audioLevel)
            }

            // Current Transcription
            if !voiceEngine.currentTranscription.isEmpty {
                GroupBox("Transcription") {
                    Text(voiceEngine.currentTranscription)
                        .frame(minHeight: 60, alignment: .topLeading)
                        .textSelection(.enabled)
                }
            }

            // Controls
            HStack(spacing: 16) {
                // Listen Button
                Button(action: toggleListening) {
                    HStack {
                        Image(systemName: voiceEngine.isListening ? "mic.fill" : "mic")
                            .font(.title2)
                        Text(voiceEngine.isListening ? "Stop Listening" : "Start Listening")
                    }
                    .frame(width: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(voiceEngine.isListening ? .red : .blue)

                // Language Picker
                Picker("Language:", selection: $selectedLanguage) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .frame(width: 200)
                .disabled(voiceEngine.isListening)

                // Continuous Mode Toggle
                Toggle("Continuous", isOn: $continuousMode)
                    .disabled(voiceEngine.isListening)

                // Settings Button
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gear")
                }
            }

            // Error Display
            if let error = error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            // Status
            HStack {
                Circle()
                    .fill(voiceEngine.isListening ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .sheet(isPresented: $showSettings) {
            VoiceSettingsView()
        }
    }

    private var statusText: String {
        if voiceEngine.isListening {
            return "Listening in \(selectedLanguage.displayName)..."
        } else if voiceEngine.isSpeaking {
            return "Speaking..."
        } else {
            return "Ready"
        }
    }

    private func toggleListening() {
        Task {
            if voiceEngine.isListening {
                await voiceEngine.stopListening()
            } else {
                do {
                    try await voiceEngine.startListening(
                        language: selectedLanguage,
                        continuous: continuousMode
                    )
                    error = nil
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

struct AudioLevelVisualizerView: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(
                            width: (geometry.size.width - 76) / 20,
                            height: barHeight(for: index, in: geometry.size.height)
                        )
                        .animation(.easeInOut(duration: 0.1), value: level)
                }
            }
        }
    }

    private func barHeight(for index: Int, in maxHeight: CGFloat) -> CGFloat {
        let threshold = Float(index) / 20.0
        return level > threshold ? maxHeight * CGFloat(level) : 4
    }

    private func barColor(for index: Int) -> Color {
        let ratio = Float(index) / 20.0
        if ratio < 0.6 {
            return .green
        } else if ratio < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct VoiceSettingsView: View {
    @StateObject private var voiceEngine = VoiceEngine.shared
    @State private var settings = VoiceSessionSettings()
    @State private var availableVoices: [VoiceProfile] = []
    @State private var selectedVoiceID: UUID?

    var body: some View {
        Form {
            Section("Wake Word") {
                Toggle("Enable Wake Word", isOn: $settings.enableWakeWord)

                if settings.enableWakeWord {
                    TextField("Wake Word", text: $settings.wakeWord)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Audio Processing") {
                Toggle("Noise Cancellation", isOn: $settings.noiseCancellation)
                Toggle("Echo Suppression", isOn: $settings.echoSuppression)

                VStack(alignment: .leading) {
                    Text("Voice Detection Sensitivity")
                    Slider(value: $settings.vadThreshold, in: 0...1)
                    Text("Current: \(Int(settings.vadThreshold * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Voice Profile") {
                Picker("Voice", selection: $selectedVoiceID) {
                    ForEach(availableVoices) { voice in
                        Text("\(voice.name) (\(voice.provider))").tag(voice.id as UUID?)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Auto-submit after silence", isOn: $settings.autoSubmit)
                Toggle("Continuous Listening", isOn: $settings.continuousListening)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear(perform: loadVoices)
    }

    private func loadVoices() {
        let context = CoreDataManager.shared.viewContext
        let request = VoiceProfile.fetchRequest()
        availableVoices = (try? context.fetch(request)) ?? []
        selectedVoiceID = voiceEngine.voiceProfile?.id
    }
}
```

### Testing Strategy

```swift
// VoiceEngineTests.swift
import XCTest
import AVFoundation
@testable import NexusCore

final class VoiceEngineTests: XCTestCase {
    var voiceEngine: VoiceEngine!

    override func setUp() async throws {
        voiceEngine = VoiceEngine.shared
    }

    override func tearDown() async throws {
        await voiceEngine.stopListening()
        voiceEngine.stopSpeaking()
    }

    func testStartListening() async throws {
        // Request permissions first
        try await voiceEngine.startListening(language: .english, continuous: false)

        XCTAssertTrue(voiceEngine.isListening)

        await voiceEngine.stopListening()

        XCTAssertFalse(voiceEngine.isListening)
    }

    func testTranscribeAudio() async throws {
        // Load test audio file
        let bundle = Bundle(for: type(of: self))
        guard let audioURL = bundle.url(forResource: "test_audio", withExtension: "m4a"),
              let audioData = try? Data(contentsOf: audioURL) else {
            XCTFail("Failed to load test audio")
            return
        }

        // Transcribe
        let transcription = try await voiceEngine.transcribeAudio(audioData, language: .english)

        // Verify transcription
        XCTAssertFalse(transcription.text.isEmpty)
        XCTAssertGreaterThan(transcription.confidence, 0.5)
        XCTAssertGreaterThan(transcription.end, 0)
    }

    func testSpeakText() async throws {
        let testText = "Hello, this is a test"

        try await voiceEngine.speak(testText, language: .english)

        // Speaking should complete without errors
        XCTAssertFalse(voiceEngine.isSpeaking)
    }

    func testMultipleLanguages() async throws {
        let languages: [Language] = [.english, .spanish, .french]

        for language in languages {
            try await voiceEngine.startListening(language: language, continuous: false)
            XCTAssertEqual(voiceEngine.currentLanguage, language)
            await voiceEngine.stopListening()
        }
    }

    func testVoiceSessionPersistence() async throws {
        // Start session
        try await voiceEngine.startListening(language: .english, continuous: false)

        // Simulate some transcription time
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        await voiceEngine.stopListening()

        // Verify session was saved
        let context = CoreDataManager.shared.viewContext
        let request = VoiceSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        request.fetchLimit = 1

        let sessions = try context.fetch(request)
        XCTAssertGreaterThan(sessions.count, 0)

        let lastSession = sessions.first
        XCTAssertNotNil(lastSession)
        XCTAssertGreaterThan(lastSession!.duration, 0)
    }

    func testAudioLevelMonitoring() async throws {
        try await voiceEngine.startListening(language: .english, continuous: false)

        // Wait for audio processing
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Audio level should be updating
        XCTAssertGreaterThanOrEqual(voiceEngine.audioLevel, 0)

        await voiceEngine.stopListening()
    }
}
```

### Success Metrics

- **Adoption:** 40% of users try voice features within 30 days
- **Accuracy:** 95% transcription accuracy for clear audio
- **Latency:** < 1s from speech end to transcription
- **Reliability:** 99% uptime for voice services
- **Languages:** Support for 10+ languages
- **User Satisfaction:** 4.3+ star rating for voice features

### Cost Estimate

- **Whisper API:** $0.006 per minute of audio
- **OpenAI TTS:** $0.015 per 1K characters (standard)
- **Apple Neural TTS:** Free (on-device)
- **Monthly estimate:** $30-100 depending on usage (500-3,000 minutes/month)

---

## 2.3 Knowledge Graph Enhancements

**Implementation:** 4 weeks | **Priority:** MEDIUM | **Risk:** LOW
**Dependencies:** NetworkX or similar graph library (Python bridge), ChromaDB

### Overview

Enhance the existing memory system with advanced knowledge graph capabilities including auto-entity extraction, graph query language, temporal evolution tracking, and visual knowledge graph exploration.

### Data Models

#### Core Data Entities

```swift
// KnowledgeNode+CoreDataClass.swift
import Foundation
import CoreData

@objc(KnowledgeNode)
public class KnowledgeNode: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var label: String
    @NSManaged public var type: String
    @NSManaged public var content: String
    @NSManaged public var importance: Double  // 0-1
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var accessCount: Int32
    @NSManaged public var lastAccessedAt: Date?

    // Relationships
    @NSManaged public var outgoingEdges: NSSet?
    @NSManaged public var incomingEdges: NSSet?
    @NSManaged public var versions: NSSet?  // For temporal tracking
    @NSManaged public var memories: NSSet?  // Related memories

    // JSON-encoded data
    @NSManaged private var metadataJSON: Data?
    @NSManaged private var embeddingData: Data?

    public var metadata: [String: String]? {
        get {
            guard let data = metadataJSON else { return nil }
            return try? JSONDecoder().decode([String: String].self, from: data)
        }
        set {
            metadataJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var embedding: [Float]? {
        get {
            guard let data = embeddingData else { return nil }
            return try? JSONDecoder().decode([Float].self, from: data)
        }
        set {
            embeddingData = try? JSONEncoder().encode(newValue)
        }
    }

    public var nodeType: NodeType {
        return NodeType(rawValue: type) ?? .generic
    }

    public var outgoingEdgeArray: [KnowledgeEdge] {
        let set = outgoingEdges as? Set<KnowledgeEdge> ?? []
        return Array(set)
    }

    public var incomingEdgeArray: [KnowledgeEdge] {
        let set = incomingEdges as? Set<KnowledgeEdge> ?? []
        return Array(set)
    }
}

// KnowledgeEdge+CoreDataClass.swift
@objc(KnowledgeEdge)
public class KnowledgeEdge: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var relationshipType: String
    @NSManaged public var weight: Double  // Strength of relationship, 0-1
    @NSManaged public var confidence: Double  // Confidence in relationship, 0-1
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var evidenceCount: Int32  // Number of supporting memories

    // Relationships
    @NSManaged public var source: KnowledgeNode
    @NSManaged public var target: KnowledgeNode
    @NSManaged public var evidence: NSSet?  // Related memories/messages

    // JSON-encoded data
    @NSManaged private var metadataJSON: Data?

    public var metadata: [String: String]? {
        get {
            guard let data = metadataJSON else { return nil }
            return try? JSONDecoder().decode([String: String].self, from: data)
        }
        set {
            metadataJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var relationship: RelationshipType {
        return RelationshipType(rawValue: relationshipType) ?? .related
    }
}

// NodeVersion+CoreDataClass.swift (for temporal tracking)
@objc(NodeVersion)
public class NodeVersion: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var versionNumber: Int32
    @NSManaged public var label: String
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var changeReason: String?

    // Relationships
    @NSManaged public var node: KnowledgeNode

    // JSON-encoded data
    @NSManaged private var metadataSnapshot: Data?

    public var metadata: [String: String]? {
        get {
            guard let data = metadataSnapshot else { return nil }
            return try? JSONDecoder().decode([String: String].self, from: data)
        }
        set {
            metadataSnapshot = try? JSONEncoder().encode(newValue)
        }
    }
}
```

#### Swift Structs

```swift
// KnowledgeGraphTypes.swift
import Foundation

public enum NodeType: String, Codable, CaseIterable {
    case person = "person"
    case organization = "organization"
    case location = "location"
    case concept = "concept"
    case technology = "technology"
    case skill = "skill"
    case project = "project"
    case task = "task"
    case document = "document"
    case generic = "generic"

    public var icon: String {
        switch self {
        case .person: return "person.fill"
        case .organization: return "building.2.fill"
        case .location: return "mappin.circle.fill"
        case .concept: return "lightbulb.fill"
        case .technology: return "cpu.fill"
        case .skill: return "star.fill"
        case .project: return "folder.fill"
        case .task: return "checkmark.square.fill"
        case .document: return "doc.fill"
        case .generic: return "circle.fill"
        }
    }
}

public enum RelationshipType: String, Codable, CaseIterable {
    case knows = "knows"
    case worksAt = "works_at"
    case locatedIn = "located_in"
    case relatedTo = "related_to"
    case dependsOn = "depends_on"
    case requires = "requires"
    case similar = "similar"
    case opposes = "opposes"
    case causes = "causes"
    case partOf = "part_of"
    case instanceOf = "instance_of"
    case related = "related"

    public var displayName: String {
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public var isDirectional: Bool {
        switch self {
        case .knows, .related, .similar, .opposes:
            return false  // Bidirectional
        default:
            return true  // Directional
        }
    }
}

public struct GraphQueryResult: Codable, Identifiable {
    public let id: UUID
    public let nodes: [KnowledgeNodeDTO]
    public let edges: [KnowledgeEdgeDTO]
    public let metadata: QueryMetadata

    public init(id: UUID = UUID(), nodes: [KnowledgeNodeDTO], edges: [KnowledgeEdgeDTO], metadata: QueryMetadata) {
        self.id = id
        self.nodes = nodes
        self.edges = edges
        self.metadata = metadata
    }

    public struct QueryMetadata: Codable {
        public let executionTimeMS: Double
        public let nodeCount: Int
        public let edgeCount: Int
        public let query: String
    }
}

public struct KnowledgeNodeDTO: Codable, Identifiable {
    public let id: UUID
    public let label: String
    public let type: NodeType
    public let content: String
    public let importance: Double
    public let metadata: [String: String]?

    public init(from node: KnowledgeNode) {
        self.id = node.id
        self.label = node.label
        self.type = node.nodeType
        self.content = node.content
        self.importance = node.importance
        self.metadata = node.metadata
    }
}

public struct KnowledgeEdgeDTO: Codable, Identifiable {
    public let id: UUID
    public let sourceID: UUID
    public let targetID: UUID
    public let relationshipType: RelationshipType
    public let weight: Double
    public let confidence: Double

    public init(from edge: KnowledgeEdge) {
        self.id = edge.id
        self.sourceID = edge.source.id
        self.targetID = edge.target.id
        self.relationshipType = edge.relationship
        self.weight = edge.weight
        self.confidence = edge.confidence
    }
}

public struct GraphPath: Codable, Identifiable {
    public let id: UUID
    public let nodes: [UUID]
    public let edges: [UUID]
    public let length: Int
    public let totalWeight: Double

    public init(id: UUID = UUID(), nodes: [UUID], edges: [UUID], length: Int, totalWeight: Double) {
        self.id = id
        self.nodes = nodes
        self.edges = edges
        self.length = length
        self.totalWeight = totalWeight
    }
}

public struct EntityExtractionResult: Codable {
    public let entities: [ExtractedEntity]
    public let relationships: [ExtractedRelationship]
    public let confidence: Double

    public struct ExtractedEntity: Codable, Identifiable {
        public let id: UUID
        public let text: String
        public let type: NodeType
        public let confidence: Double
        public let context: String

        public init(id: UUID = UUID(), text: String, type: NodeType, confidence: Double, context: String) {
            self.id = id
            self.text = text
            self.type = type
            self.confidence = confidence
            self.context = context
        }
    }

    public struct ExtractedRelationship: Codable, Identifiable {
        public let id: UUID
        public let sourceEntity: String
        public let targetEntity: String
        public let relationshipType: RelationshipType
        public let confidence: Double

        public init(id: UUID = UUID(), sourceEntity: String, targetEntity: String, relationshipType: RelationshipType, confidence: Double) {
            self.id = id
            self.sourceEntity = sourceEntity
            self.targetEntity = targetEntity
            self.relationshipType = relationshipType
            self.confidence = confidence
        }
    }
}
```

### Core Implementation

#### Knowledge Graph Manager

```swift
// KnowledgeGraphManager.swift
import Foundation
import CoreData
import Combine

@MainActor
public final class KnowledgeGraphManager: ObservableObject {
    public static let shared = KnowledgeGraphManager()

    @Published public private(set) var nodes: [KnowledgeNode] = []
    @Published public private(set) var edges: [KnowledgeEdge] = []
    @Published public private(set) var isProcessing = false

    private let context: NSManagedObjectContext
    private let entityExtractor: EntityExtractor
    private let graphQueryEngine: GraphQueryEngine
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.context = CoreDataManager.shared.viewContext
        self.entityExtractor = EntityExtractor()
        self.graphQueryEngine = GraphQueryEngine()

        loadGraph()
    }

    // MARK: - Node Operations

    /// Creates a new knowledge node
    public func createNode(
        label: String,
        type: NodeType,
        content: String,
        metadata: [String: String]? = nil
    ) throws -> KnowledgeNode {
        let node = KnowledgeNode(context: context)
        node.id = UUID()
        node.label = label
        node.type = type.rawValue
        node.content = content
        node.importance = 0.5
        node.createdAt = Date()
        node.updatedAt = Date()
        node.accessCount = 0
        node.metadata = metadata

        // Generate embedding for semantic search
        Task {
            node.embedding = try? await generateEmbedding(for: content)
        }

        try context.save()
        nodes.append(node)

        return node
    }

    /// Updates an existing node and creates a version snapshot
    public func updateNode(
        _ node: KnowledgeNode,
        label: String? = nil,
        content: String? = nil,
        metadata: [String: String]? = nil,
        changeReason: String? = nil
    ) throws {
        // Create version snapshot
        let version = NodeVersion(context: context)
        version.id = UUID()
        version.versionNumber = Int32((node.versions?.count ?? 0) + 1)
        version.label = node.label
        version.content = node.content
        version.createdAt = Date()
        version.changeReason = changeReason
        version.node = node

        // Update node
        if let label = label {
            node.label = label
        }
        if let content = content {
            node.content = content
            // Regenerate embedding
            Task {
                node.embedding = try? await generateEmbedding(for: content)
            }
        }
        if let metadata = metadata {
            node.metadata = metadata
        }

        node.updatedAt = Date()

        try context.save()
    }

    /// Deletes a node and all its edges
    public func deleteNode(_ node: KnowledgeNode) throws {
        // Delete all connected edges
        for edge in node.outgoingEdgeArray + node.incomingEdgeArray {
            context.delete(edge)
        }

        context.delete(node)
        try context.save()

        nodes.removeAll { $0.id == node.id }
    }

    // MARK: - Edge Operations

    /// Creates a relationship between two nodes
    public func createEdge(
        from source: KnowledgeNode,
        to target: KnowledgeNode,
        type: RelationshipType,
        weight: Double = 1.0,
        confidence: Double = 1.0
    ) throws -> KnowledgeEdge {
        // Check if edge already exists
        if let existing = findEdge(from: source, to: target, type: type) {
            // Update weight and confidence
            existing.weight = max(existing.weight, weight)
            existing.confidence = max(existing.confidence, confidence)
            existing.evidenceCount += 1
            try context.save()
            return existing
        }

        let edge = KnowledgeEdge(context: context)
        edge.id = UUID()
        edge.source = source
        edge.target = target
        edge.relationshipType = type.rawValue
        edge.weight = weight
        edge.confidence = confidence
        edge.evidenceCount = 1
        edge.createdAt = Date()
        edge.updatedAt = Date()

        try context.save()
        edges.append(edge)

        return edge
    }

    /// Deletes an edge
    public func deleteEdge(_ edge: KnowledgeEdge) throws {
        context.delete(edge)
        try context.save()

        edges.removeAll { $0.id == edge.id }
    }

    // MARK: - Entity Extraction

    /// Automatically extracts entities and relationships from text
    public func extractEntities(from text: String) async throws -> EntityExtractionResult {
        isProcessing = true
        defer { isProcessing = false }

        return try await entityExtractor.extract(from: text)
    }

    /// Integrates extracted entities into the graph
    public func integrateEntities(_ extraction: EntityExtractionResult) async throws {
        var nodeMap: [String: KnowledgeNode] = [:]

        // Create or find nodes for entities
        for entity in extraction.entities {
            if let existing = findNode(byLabel: entity.text, type: entity.type) {
                nodeMap[entity.text] = existing
            } else {
                let node = try createNode(
                    label: entity.text,
                    type: entity.type,
                    content: entity.context,
                    metadata: ["confidence": String(entity.confidence)]
                )
                nodeMap[entity.text] = node
            }
        }

        // Create edges for relationships
        for relationship in extraction.relationships {
            guard let source = nodeMap[relationship.sourceEntity],
                  let target = nodeMap[relationship.targetEntity] else {
                continue
            }

            _ = try createEdge(
                from: source,
                to: target,
                type: relationship.relationshipType,
                weight: relationship.confidence,
                confidence: relationship.confidence
            )
        }
    }

    // MARK: - Graph Queries

    /// Executes a graph query using a SQL-like syntax
    public func query(_ queryString: String) async throws -> GraphQueryResult {
        return try await graphQueryEngine.execute(queryString, graph: self)
    }

    /// Finds the shortest path between two nodes
    public func findPath(
        from source: KnowledgeNode,
        to target: KnowledgeNode,
        maxDepth: Int = 5
    ) async throws -> GraphPath? {
        return try await graphQueryEngine.findShortestPath(
            from: source,
            to: target,
            maxDepth: maxDepth,
            graph: self
        )
    }

    /// Finds nodes similar to the given node
    public func findSimilar(to node: KnowledgeNode, limit: Int = 10) async throws -> [KnowledgeNode] {
        guard let embedding = node.embedding else {
            throw KnowledgeGraphError.noEmbedding
        }

        var similarities: [(node: KnowledgeNode, similarity: Float)] = []

        for otherNode in nodes where otherNode.id != node.id {
            guard let otherEmbedding = otherNode.embedding else { continue }

            let similarity = cosineSimilarity(embedding, otherEmbedding)
            similarities.append((otherNode, similarity))
        }

        return similarities
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { $0.node }
    }

    // MARK: - Temporal Queries

    /// Gets the version history of a node
    public func getHistory(for node: KnowledgeNode) -> [NodeVersion] {
        let versionSet = node.versions as? Set<NodeVersion> ?? []
        return versionSet.sorted { $0.versionNumber < $1.versionNumber }
    }

    /// Reverts a node to a previous version
    public func revertToVersion(_ version: NodeVersion) throws {
        let node = version.node
        try updateNode(
            node,
            label: version.label,
            content: version.content,
            metadata: version.metadata,
            changeReason: "Reverted to version \(version.versionNumber)"
        )
    }

    // MARK: - Helper Methods

    private func loadGraph() {
        let nodeRequest = KnowledgeNode.fetchRequest()
        let edgeRequest = KnowledgeEdge.fetchRequest()

        do {
            nodes = try context.fetch(nodeRequest)
            edges = try context.fetch(edgeRequest)
        } catch {
            print("Failed to load graph: \(error)")
        }
    }

    private func findNode(byLabel label: String, type: NodeType) -> KnowledgeNode? {
        let request = KnowledgeNode.fetchRequest()
        request.predicate = NSPredicate(format: "label ==[c] %@ AND type == %@", label, type.rawValue)
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    private func findEdge(
        from source: KnowledgeNode,
        to target: KnowledgeNode,
        type: RelationshipType
    ) -> KnowledgeEdge? {
        return source.outgoingEdgeArray.first { edge in
            edge.target.id == target.id && edge.relationship == type
        }
    }

    private func generateEmbedding(for text: String) async throws -> [Float] {
        let aiRouter = AIRouter.shared
        return try await aiRouter.generateEmbedding(text: text)
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }
}

public enum KnowledgeGraphError: LocalizedError {
    case nodeNotFound
    case edgeNotFound
    case invalidQuery
    case noEmbedding
    case pathNotFound

    public var errorDescription: String? {
        switch self {
        case .nodeNotFound:
            return "Knowledge node not found"
        case .edgeNotFound:
            return "Knowledge edge not found"
        case .invalidQuery:
            return "Invalid graph query syntax"
        case .noEmbedding:
            return "No embedding available for node"
        case .pathNotFound:
            return "No path found between nodes"
        }
    }
}
```


#### Entity Extractor

```swift
// EntityExtractor.swift
import Foundation

public final class EntityExtractor {
    private let aiRouter: AIRouter

    public init() {
        self.aiRouter = AIRouter.shared
    }

    /// Extracts entities and relationships from text using GPT-4
    public func extract(from text: String) async throws -> EntityExtractionResult {
        let prompt = buildExtractionPrompt(text: text)

        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are an expert at extracting entities and relationships from text."],
            ["role": "user", "content": prompt]
        ]

        let response = try await aiRouter.sendRequest(
            messages: messages,
            model: .gpt4,
            temperature: 0.1,
            responseFormat: .json
        )

        guard let content = response.choices.first?.message.content else {
            throw KnowledgeGraphError.invalidQuery
        }

        return try parseExtractionResponse(content)
    }

    private func buildExtractionPrompt(text: String) -> String {
        return """
        Extract entities and relationships from the following text. Return a JSON response with this structure:
        {
          "entities": [
            {
              "text": "entity name",
              "type": "person|organization|location|concept|technology|skill|project|task|document|generic",
              "confidence": 0.0-1.0,
              "context": "surrounding context"
            }
          ],
          "relationships": [
            {
              "sourceEntity": "entity1",
              "targetEntity": "entity2",
              "relationshipType": "knows|works_at|located_in|related_to|depends_on|requires|similar|opposes|causes|part_of|instance_of",
              "confidence": 0.0-1.0
            }
          ]
        }

        Text to analyze:
        \(text)
        """
    }

    private func parseExtractionResponse(_ json: String) throws -> EntityExtractionResult {
        guard let data = json.data(using: .utf8) else {
            throw KnowledgeGraphError.invalidQuery
        }

        let decoder = JSONDecoder()
        return try decoder.decode(EntityExtractionResult.self, from: data)
    }
}
```

#### Graph Query Engine

```swift
// GraphQueryEngine.swift
import Foundation
import CoreData

public final class GraphQueryEngine {
    public init() {}

    /// Executes a graph query
    /// Supported syntax:
    /// - FIND Node WHERE type='Technology' AND importance > 0.5
    /// - FIND Path FROM 'NodeA' TO 'NodeB' WITH max_depth=5
    /// - FIND Relationships WHERE type='knows'
    public func execute(
        _ queryString: String,
        graph: KnowledgeGraphManager
    ) async throws -> GraphQueryResult {
        let startTime = Date()
        let query = try parseQuery(queryString)

        var resultNodes: [KnowledgeNodeDTO] = []
        var resultEdges: [KnowledgeEdgeDTO] = []

        switch query {
        case .findNodes(let conditions):
            let nodes = try await findNodes(matching: conditions, in: graph)
            resultNodes = nodes.map { KnowledgeNodeDTO(from: $0) }

        case .findPath(let from, let to, let maxDepth):
            guard let path = try await findShortestPath(
                from: from,
                to: to,
                maxDepth: maxDepth,
                graph: graph
            ) else {
                throw KnowledgeGraphError.pathNotFound
            }

            // Convert path to nodes and edges
            for nodeID in path.nodes {
                if let node = graph.nodes.first(where: { $0.id == nodeID }) {
                    resultNodes.append(KnowledgeNodeDTO(from: node))
                }
            }
            for edgeID in path.edges {
                if let edge = graph.edges.first(where: { $0.id == edgeID }) {
                    resultEdges.append(KnowledgeEdgeDTO(from: edge))
                }
            }

        case .findRelationships(let conditions):
            let edges = try await findEdges(matching: conditions, in: graph)
            resultEdges = edges.map { KnowledgeEdgeDTO(from: $0) }
        }

        let executionTime = Date().timeIntervalSince(startTime) * 1000  // ms

        return GraphQueryResult(
            nodes: resultNodes,
            edges: resultEdges,
            metadata: GraphQueryResult.QueryMetadata(
                executionTimeMS: executionTime,
                nodeCount: resultNodes.count,
                edgeCount: resultEdges.count,
                query: queryString
            )
        )
    }

    /// Finds shortest path between two nodes using BFS
    public func findShortestPath(
        from source: KnowledgeNode,
        to target: KnowledgeNode,
        maxDepth: Int,
        graph: KnowledgeGraphManager
    ) async throws -> GraphPath? {
        var queue: [(node: KnowledgeNode, path: [UUID], edges: [UUID], depth: Int)] = [(source, [source.id], [], 0)]
        var visited: Set<UUID> = [source.id]

        while !queue.isEmpty {
            let (currentNode, path, edges, depth) = queue.removeFirst()

            if currentNode.id == target.id {
                let totalWeight = edges.compactMap { edgeID in
                    graph.edges.first(where: { $0.id == edgeID })?.weight
                }.reduce(0, +)

                return GraphPath(
                    nodes: path,
                    edges: edges,
                    length: path.count - 1,
                    totalWeight: totalWeight
                )
            }

            if depth >= maxDepth {
                continue
            }

            for edge in currentNode.outgoingEdgeArray {
                let nextNode = edge.target
                if !visited.contains(nextNode.id) {
                    visited.insert(nextNode.id)
                    queue.append((
                        nextNode,
                        path + [nextNode.id],
                        edges + [edge.id],
                        depth + 1
                    ))
                }
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func parseQuery(_ queryString: String) throws -> GraphQuery {
        let components = queryString.components(separatedBy: " ")

        guard components.count >= 2, components[0].uppercased() == "FIND" else {
            throw KnowledgeGraphError.invalidQuery
        }

        let entityType = components[1].lowercased()

        if entityType == "node" || entityType == "nodes" {
            let conditions = try parseConditions(from: queryString)
            return .findNodes(conditions: conditions)
        } else if entityType == "path" {
            let from = try extractValue(from: queryString, after: "FROM")
            let to = try extractValue(from: queryString, after: "TO")
            let maxDepth = try? extractIntValue(from: queryString, after: "WITH max_depth=") ?? 5
            return .findPath(from: from, to: to, maxDepth: maxDepth ?? 5)
        } else if entityType == "relationship" || entityType == "relationships" {
            let conditions = try parseConditions(from: queryString)
            return .findRelationships(conditions: conditions)
        }

        throw KnowledgeGraphError.invalidQuery
    }

    private func parseConditions(from query: String) throws -> [QueryCondition] {
        guard let whereIndex = query.range(of: "WHERE", options: .caseInsensitive) else {
            return []
        }

        let conditionsString = String(query[whereIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
        var conditions: [QueryCondition] = []

        let parts = conditionsString.components(separatedBy: " AND ")

        for part in parts {
            if let condition = try? parseCondition(part.trimmingCharacters(in: .whitespaces)) {
                conditions.append(condition)
            }
        }

        return conditions
    }

    private func parseCondition(_ conditionString: String) throws -> QueryCondition {
        let operators = ["==", "!=", ">", "<", ">=", "<=", "="]

        for op in operators {
            if let range = conditionString.range(of: op) {
                let field = conditionString[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let value = conditionString[range.upperBound...].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'\""))

                return QueryCondition(field: String(field), operator: op, value: String(value))
            }
        }

        throw KnowledgeGraphError.invalidQuery
    }

    private func extractValue(from query: String, after keyword: String) throws -> String {
        guard let range = query.range(of: keyword, options: .caseInsensitive) else {
            throw KnowledgeGraphError.invalidQuery
        }

        let remainder = String(query[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        let components = remainder.components(separatedBy: " ")

        guard let first = components.first else {
            throw KnowledgeGraphError.invalidQuery
        }

        return first.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
    }

    private func extractIntValue(from query: String, after keyword: String) throws -> Int {
        let value = try extractValue(from: query, after: keyword)
        guard let intValue = Int(value) else {
            throw KnowledgeGraphError.invalidQuery
        }
        return intValue
    }

    private func findNodes(
        matching conditions: [QueryCondition],
        in graph: KnowledgeGraphManager
    ) async throws -> [KnowledgeNode] {
        return graph.nodes.filter { node in
            conditions.allSatisfy { condition in
                evaluateCondition(condition, for: node)
            }
        }
    }

    private func findEdges(
        matching conditions: [QueryCondition],
        in graph: KnowledgeGraphManager
    ) async throws -> [KnowledgeEdge] {
        return graph.edges.filter { edge in
            conditions.allSatisfy { condition in
                evaluateCondition(condition, for: edge)
            }
        }
    }

    private func evaluateCondition(_ condition: QueryCondition, for node: KnowledgeNode) -> Bool {
        let field = condition.field.lowercased()
        let value = condition.value

        switch field {
        case "type":
            return evaluateStringCondition(node.type, condition.operator, value)
        case "label", "name":
            return evaluateStringCondition(node.label, condition.operator, value)
        case "importance":
            if let numValue = Double(value) {
                return evaluateNumericCondition(node.importance, condition.operator, numValue)
            }
        case "content":
            return node.content.localizedCaseInsensitiveContains(value)
        default:
            return false
        }

        return false
    }

    private func evaluateCondition(_ condition: QueryCondition, for edge: KnowledgeEdge) -> Bool {
        let field = condition.field.lowercased()
        let value = condition.value

        switch field {
        case "type", "relationshiptype":
            return evaluateStringCondition(edge.relationshipType, condition.operator, value)
        case "weight":
            if let numValue = Double(value) {
                return evaluateNumericCondition(edge.weight, condition.operator, numValue)
            }
        case "confidence":
            if let numValue = Double(value) {
                return evaluateNumericCondition(edge.confidence, condition.operator, numValue)
            }
        default:
            return false
        }

        return false
    }

    private func evaluateStringCondition(_ fieldValue: String, _ operator: String, _ targetValue: String) -> Bool {
        switch operator {
        case "==", "=":
            return fieldValue.lowercased() == targetValue.lowercased()
        case "!=":
            return fieldValue.lowercased() != targetValue.lowercased()
        default:
            return false
        }
    }

    private func evaluateNumericCondition(_ fieldValue: Double, _ operator: String, _ targetValue: Double) -> Bool {
        switch operator {
        case "==", "=":
            return fieldValue == targetValue
        case "!=":
            return fieldValue != targetValue
        case ">":
            return fieldValue > targetValue
        case "<":
            return fieldValue < targetValue
        case ">=":
            return fieldValue >= targetValue
        case "<=":
            return fieldValue <= targetValue
        default:
            return false
        }
    }

    private enum GraphQuery {
        case findNodes(conditions: [QueryCondition])
        case findPath(from: String, to: String, maxDepth: Int)
        case findRelationships(conditions: [QueryCondition])
    }

    private struct QueryCondition {
        let field: String
        let operator: String
        let value: String
    }
}
```

### Success Metrics

- **Node Creation:** Automatic entity extraction with 85% accuracy
- **Query Performance:** < 100ms for simple queries, < 1s for path finding
- **Graph Size:** Support for 10,000+ nodes and 50,000+ edges
- **Temporal Tracking:** Complete version history for all nodes
- **User Adoption:** 30% of users actively use knowledge graph features

### Cost Estimate

- **Entity Extraction (GPT-4):** $0.03 per 1K tokens
- **Embeddings:** $0.0001 per 1K tokens
- **Storage:** Negligible (local Core Data)
- **Monthly estimate:** $20-60 depending on usage

---


## 2.4 Workflow Automation Engine

**Implementation:** 5 weeks | **Priority:** HIGH | **Risk:** MEDIUM
**Dependencies:** MCP integration, cron parser library

### Overview

Build a powerful workflow automation engine that allows users to create custom workflows with triggers, actions, conditions, and loops. Integrates with AI models, MCP tools, and external services to automate repetitive tasks.

### Data Models

#### Core Data Entities

```swift
// Workflow+CoreDataClass.swift
import Foundation
import CoreData

@objc(Workflow)
public class Workflow: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var descriptionText: String?
    @NSManaged public var isEnabled: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var lastRunAt: Date?
    @NSManaged public var executionCount: Int32
    @NSManaged public var successCount: Int32
    @NSManaged public var failureCount: Int32

    // Relationships
    @NSManaged public var trigger: WorkflowTrigger?
    @NSManaged public var steps: NSOrderedSet?
    @NSManaged public var executions: NSSet?

    // JSON-encoded data
    @NSManaged private var variablesJSON: Data?
    @NSManaged private var metadataJSON: Data?

    public var variables: [String: WorkflowVariable]? {
        get {
            guard let data = variablesJSON else { return nil }
            return try? JSONDecoder().decode([String: WorkflowVariable].self, from: data)
        }
        set {
            variablesJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var metadata: [String: String]? {
        get {
            guard let data = metadataJSON else { return nil }
            return try? JSONDecoder().decode([String: String].self, from: data)
        }
        set {
            metadataJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var stepsArray: [WorkflowStep] {
        let orderedSet = steps as? NSOrderedSet ?? NSOrderedSet()
        return orderedSet.array as? [WorkflowStep] ?? []
    }
}

// WorkflowTrigger+CoreDataClass.swift
@objc(WorkflowTrigger)
public class WorkflowTrigger: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var type: String  // schedule, event, keyword, webhook, manual
    @NSManaged public var isEnabled: Bool

    // Relationships
    @NSManaged public var workflow: Workflow

    // JSON-encoded configuration
    @NSManaged private var configJSON: Data?

    public var configuration: TriggerConfiguration? {
        get {
            guard let data = configJSON else { return nil }
            return try? JSONDecoder().decode(TriggerConfiguration.self, from: data)
        }
        set {
            configJSON = try? JSONEncoder().encode(newValue)
        }
    }
}

// WorkflowStep+CoreDataClass.swift
@objc(WorkflowStep)
public class WorkflowStep: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var type: String  // action, condition, loop
    @NSManaged public var order: Int32
    @NSManaged public var continueOnError: Bool

    // Relationships
    @NSManaged public var workflow: Workflow
    @NSManaged public var onSuccess: NSOrderedSet?
    @NSManaged public var onFailure: NSOrderedSet?

    // JSON-encoded data
    @NSManaged private var actionJSON: Data?
    @NSManaged private var parametersJSON: Data?

    public var action: WorkflowAction? {
        get {
            guard let data = actionJSON else { return nil }
            return try? JSONDecoder().decode(WorkflowAction.self, from: data)
        }
        set {
            actionJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var parameters: [String: Any]? {
        get {
            guard let data = parametersJSON else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        set {
            parametersJSON = try? JSONSerialization.data(withJSONObject: newValue ?? [:])
        }
    }
}

// WorkflowExecution+CoreDataClass.swift
@objc(WorkflowExecution)
public class WorkflowExecution: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var startedAt: Date
    @NSManaged public var completedAt: Date?
    @NSManaged public var status: String  // running, completed, failed, cancelled
    @NSManaged public var errorMessage: String?

    // Relationships
    @NSManaged public var workflow: Workflow

    // JSON-encoded data
    @NSManaged private var contextJSON: Data?
    @NSManaged private var resultsJSON: Data?

    public var context: [String: Any]? {
        get {
            guard let data = contextJSON else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        set {
            contextJSON = try? JSONSerialization.data(withJSONObject: newValue ?? [:])
        }
    }

    public var results: [String: Any]? {
        get {
            guard let data = resultsJSON else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        set {
            resultsJSON = try? JSONSerialization.data(withJSONObject: newValue ?? [:])
        }
    }
}
```

#### Swift Structs

```swift
// WorkflowTypes.swift
import Foundation

public enum TriggerType: String, Codable, CaseIterable {
    case schedule = "schedule"
    case event = "event"
    case keyword = "keyword"
    case webhook = "webhook"
    case manual = "manual"

    public var displayName: String {
        return rawValue.capitalized
    }
}

public struct TriggerConfiguration: Codable {
    public var schedule: ScheduleConfig?
    public var event: EventConfig?
    public var keyword: KeywordConfig?
    public var webhook: WebhookConfig?

    public struct ScheduleConfig: Codable {
        public let cronExpression: String
        public let timezone: String

        public init(cronExpression: String, timezone: String = "UTC") {
            self.cronExpression = cronExpression
            self.timezone = timezone
        }
    }

    public struct EventConfig: Codable {
        public let eventType: String  // message_sent, conversation_started, etc.
        public let filters: [String: String]?

        public init(eventType: String, filters: [String: String]? = nil) {
            self.eventType = eventType
            self.filters = filters
        }
    }

    public struct KeywordConfig: Codable {
        public let keywords: [String]
        public let caseSensitive: Bool
        public let matchWhole: Bool

        public init(keywords: [String], caseSensitive: Bool = false, matchWhole: Bool = false) {
            self.keywords = keywords
            self.caseSensitive = caseSensitive
            self.matchWhole = matchWhole
        }
    }

    public struct WebhookConfig: Codable {
        public let url: String
        public let method: String
        public let headers: [String: String]?
        public let secret: String?

        public init(url: String, method: String = "POST", headers: [String: String]? = nil, secret: String? = nil) {
            self.url = url
            self.method = method
            self.headers = headers
            self.secret = secret
        }
    }
}

public enum WorkflowAction: Codable {
    case aiQuery(prompt: String, model: String?)
    case createMemory(type: String, content: String)
    case runMCPTool(server: String, tool: String, arguments: [String: Any])
    case sendNotification(title: String, body: String, target: String?)
    case httpRequest(url: String, method: String, headers: [String: String]?, body: String?)
    case executeScript(language: String, code: String)
    case delay(seconds: Double)
    case setVariable(name: String, value: String)
    case conditional(condition: String, thenSteps: [UUID], elseSteps: [UUID]?)
    case loop(items: String, steps: [UUID])
}

public struct WorkflowVariable: Codable {
    public let name: String
    public let type: VariableType
    public var value: String?
    public let description: String?

    public init(name: String, type: VariableType, value: String? = nil, description: String? = nil) {
        self.name = name
        self.type = type
        self.value = value
        self.description = description
    }

    public enum VariableType: String, Codable {
        case string, number, boolean, array, object
    }
}

public enum WorkflowExecutionStatus: String, Codable {
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

public struct WorkflowExecutionResult: Codable {
    public let success: Bool
    public let output: [String: Any]?
    public let error: String?
    public let duration: TimeInterval

    public init(success: Bool, output: [String: Any]? = nil, error: String? = nil, duration: TimeInterval) {
        self.success = success
        self.output = output
        self.error = error
        self.duration = duration
    }
}
```

### Core Implementation

#### Workflow Engine

```swift
// WorkflowEngine.swift
import Foundation
import Combine
import CoreData

@MainActor
public final class WorkflowEngine: ObservableObject {
    public static let shared = WorkflowEngine()

    @Published public private(set) var workflows: [Workflow] = []
    @Published public private(set) var runningExecutions: [WorkflowExecution] = []
    @Published public private(set) var isProcessing = false

    private let context: NSManagedObjectContext
    private let schedulerService: WorkflowScheduler
    private let executionQueue: OperationQueue
    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.context = CoreDataManager.shared.viewContext
        self.schedulerService = WorkflowScheduler()
        self.executionQueue = OperationQueue()
        self.executionQueue.maxConcurrentOperationCount = 3  // Limit concurrent workflows

        loadWorkflows()
        setupEventListeners()
    }

    // MARK: - Workflow Management

    /// Creates a new workflow
    public func createWorkflow(
        name: String,
        description: String? = nil,
        trigger: TriggerConfiguration,
        triggerType: TriggerType
    ) throws -> Workflow {
        let workflow = Workflow(context: context)
        workflow.id = UUID()
        workflow.name = name
        workflow.descriptionText = description
        workflow.isEnabled = true
        workflow.createdAt = Date()
        workflow.updatedAt = Date()
        workflow.executionCount = 0
        workflow.successCount = 0
        workflow.failureCount = 0

        let workflowTrigger = WorkflowTrigger(context: context)
        workflowTrigger.id = UUID()
        workflowTrigger.type = triggerType.rawValue
        workflowTrigger.isEnabled = true
        workflowTrigger.configuration = trigger
        workflowTrigger.workflow = workflow

        workflow.trigger = workflowTrigger

        try context.save()
        workflows.append(workflow)

        // Schedule if needed
        if triggerType == .schedule, let cronExpr = trigger.schedule?.cronExpression {
            schedulerService.schedule(workflow: workflow, cron: cronExpr)
        }

        return workflow
    }

    /// Adds a step to a workflow
    public func addStep(
        to workflow: Workflow,
        name: String,
        action: WorkflowAction,
        parameters: [String: Any]? = nil,
        continueOnError: Bool = false
    ) throws -> WorkflowStep {
        let step = WorkflowStep(context: context)
        step.id = UUID()
        step.name = name
        step.type = "action"
        step.order = Int32(workflow.stepsArray.count)
        step.continueOnError = continueOnError
        step.action = action
        step.parameters = parameters
        step.workflow = workflow

        let currentSteps = workflow.steps?.mutableCopy() as? NSMutableOrderedSet ?? NSMutableOrderedSet()
        currentSteps.add(step)
        workflow.steps = currentSteps

        try context.save()

        return step
    }

    /// Deletes a workflow
    public func deleteWorkflow(_ workflow: Workflow) throws {
        // Cancel any scheduled executions
        schedulerService.unschedule(workflow: workflow)

        context.delete(workflow)
        try context.save()

        workflows.removeAll { $0.id == workflow.id }
    }

    /// Enables or disables a workflow
    public func setEnabled(_ enabled: Bool, for workflow: Workflow) throws {
        workflow.isEnabled = enabled
        workflow.trigger?.isEnabled = enabled

        if enabled {
            if let trigger = workflow.trigger?.configuration,
               let cronExpr = trigger.schedule?.cronExpression {
                schedulerService.schedule(workflow: workflow, cron: cronExpr)
            }
        } else {
            schedulerService.unschedule(workflow: workflow)
        }

        try context.save()
    }

    // MARK: - Workflow Execution

    /// Executes a workflow manually
    public func executeWorkflow(
        _ workflow: Workflow,
        context initialContext: [String: Any]? = nil
    ) async throws -> WorkflowExecutionResult {
        guard workflow.isEnabled else {
            throw WorkflowError.workflowDisabled
        }

        isProcessing = true
        defer { isProcessing = false }

        // Create execution record
        let execution = WorkflowExecution(context: self.context)
        execution.id = UUID()
        execution.workflow = workflow
        execution.startedAt = Date()
        execution.status = WorkflowExecutionStatus.running.rawValue
        execution.context = initialContext

        try self.context.save()
        runningExecutions.append(execution)

        let startTime = Date()
        var executionContext = initialContext ?? [:]

        do {
            // Execute steps in order
            for step in workflow.stepsArray {
                let stepResult = try await executeStep(step, context: executionContext)
                executionContext.merge(stepResult) { _, new in new }
            }

            // Mark as completed
            execution.status = WorkflowExecutionStatus.completed.rawValue
            execution.completedAt = Date()
            execution.results = executionContext

            workflow.executionCount += 1
            workflow.successCount += 1
            workflow.lastRunAt = Date()

            try self.context.save()

            runningExecutions.removeAll { $0.id == execution.id }

            let duration = Date().timeIntervalSince(startTime)
            return WorkflowExecutionResult(success: true, output: executionContext, duration: duration)

        } catch {
            // Mark as failed
            execution.status = WorkflowExecutionStatus.failed.rawValue
            execution.completedAt = Date()
            execution.errorMessage = error.localizedDescription

            workflow.executionCount += 1
            workflow.failureCount += 1
            workflow.lastRunAt = Date()

            try? self.context.save()

            runningExecutions.removeAll { $0.id == execution.id }

            let duration = Date().timeIntervalSince(startTime)
            return WorkflowExecutionResult(success: false, error: error.localizedDescription, duration: duration)
        }
    }

    /// Cancels a running execution
    public func cancelExecution(_ execution: WorkflowExecution) throws {
        execution.status = WorkflowExecutionStatus.cancelled.rawValue
        execution.completedAt = Date()
        execution.errorMessage = "Cancelled by user"

        try context.save()

        runningExecutions.removeAll { $0.id == execution.id }
    }

    // MARK: - Step Execution

    private func executeStep(_ step: WorkflowStep, context: [String: Any]) async throws -> [String: Any] {
        guard let action = step.action else {
            throw WorkflowError.invalidStep("No action defined for step: \(step.name)")
        }

        do {
            let result = try await executeAction(action, context: context, parameters: step.parameters)
            return result
        } catch {
            if step.continueOnError {
                return ["error": error.localizedDescription, "continued": true]
            } else {
                throw error
            }
        }
    }

    private func executeAction(_ action: WorkflowAction, context: [String: Any], parameters: [String: Any]?) async throws -> [String: Any] {
        switch action {
        case .aiQuery(let prompt, let model):
            return try await executeAIQuery(prompt: prompt, model: model, context: context)

        case .createMemory(let type, let content):
            return try await executeCreateMemory(type: type, content: content, context: context)

        case .runMCPTool(let server, let tool, let arguments):
            return try await executeMCPTool(server: server, tool: tool, arguments: arguments, context: context)

        case .sendNotification(let title, let body, let target):
            return try await executeSendNotification(title: title, body: body, target: target, context: context)

        case .httpRequest(let url, let method, let headers, let body):
            return try await executeHTTPRequest(url: url, method: method, headers: headers, body: body, context: context)

        case .executeScript(let language, let code):
            return try await executeScript(language: language, code: code, context: context)

        case .delay(let seconds):
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return ["delayed": seconds]

        case .setVariable(let name, let value):
            return [name: value]

        case .conditional(let condition, let thenSteps, let elseSteps):
            return try await executeConditional(condition: condition, thenSteps: thenSteps, elseSteps: elseSteps, context: context)

        case .loop(let items, let steps):
            return try await executeLoop(items: items, steps: steps, context: context)
        }
    }

    private func executeAIQuery(prompt: String, model: String?, context: [String: Any]) async throws -> [String: Any] {
        let resolvedPrompt = resolveVariables(prompt, context: context)

        let messages: [[String: Any]] = [
            ["role": "user", "content": resolvedPrompt]
        ]

        let aiRouter = AIRouter.shared
        let response = try await aiRouter.sendRequest(
            messages: messages,
            model: model.flatMap { AIModel(rawValue: $0) } ?? .gpt4,
            temperature: 0.7,
            maxTokens: 2000
        )

        guard let content = response.choices.first?.message.content else {
            throw WorkflowError.executionFailed("No response from AI")
        }

        return ["ai_response": content]
    }

    private func executeCreateMemory(type: String, content: String, context: [String: Any]) async throws -> [String: Any] {
        let resolvedContent = resolveVariables(content, context: context)

        let memoryManager = MemoryManager.shared
        let memory = try await memoryManager.createMemory(
            content: resolvedContent,
            type: MemoryType(rawValue: type) ?? .context
        )

        return ["memory_id": memory.id.uuidString]
    }

    private func executeMCPTool(server: String, tool: String, arguments: [String: Any], context: [String: Any]) async throws -> [String: Any] {
        let mcpManager = MCPManager.shared

        guard let serverInstance = mcpManager.connectedServers.first(where: { $0.name == server }) else {
            throw WorkflowError.executionFailed("MCP server not found: \(server)")
        }

        let result = try await mcpManager.callTool(tool, on: serverInstance, with: arguments)

        return ["mcp_result": result]
    }

    private func executeSendNotification(title: String, body: String, target: String?, context: [String: Any]) async throws -> [String: Any] {
        let resolvedTitle = resolveVariables(title, context: context)
        let resolvedBody = resolveVariables(body, context: context)

        // Send notification via NotificationCenter or external service
        NotificationCenter.default.post(
            name: .workflowNotification,
            object: nil,
            userInfo: ["title": resolvedTitle, "body": resolvedBody, "target": target as Any]
        )

        return ["notification_sent": true]
    }

    private func executeHTTPRequest(url: String, method: String, headers: [String: String]?, body: String?, context: [String: Any]) async throws -> [String: Any] {
        let resolvedURL = resolveVariables(url, context: context)

        guard let requestURL = URL(string: resolvedURL) else {
            throw WorkflowError.executionFailed("Invalid URL: \(resolvedURL)")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = method

        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if let body = body {
            let resolvedBody = resolveVariables(body, context: context)
            request.httpBody = resolvedBody.data(using: .utf8)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkflowError.executionFailed("Invalid HTTP response")
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""

        return [
            "http_status": httpResponse.statusCode,
            "http_response": responseBody
        ]
    }

    private func executeScript(language: String, code: String, context: [String: Any]) async throws -> [String: Any] {
        // For security, this would need sandboxing
        // For now, throw not implemented
        throw WorkflowError.notImplemented("Script execution not yet implemented")
    }

    private func executeConditional(condition: String, thenSteps: [UUID], elseSteps: [UUID]?, context: [String: Any]) async throws -> [String: Any] {
        let conditionResult = evaluateCondition(condition, context: context)

        let stepsToExecute = conditionResult ? thenSteps : (elseSteps ?? [])

        var results: [String: Any] = ["condition_result": conditionResult]

        for stepID in stepsToExecute {
            // Would need to look up and execute these steps
            // This is simplified for brevity
        }

        return results
    }

    private func executeLoop(items: String, steps: [UUID], context: [String: Any]) async throws -> [String: Any] {
        // Parse items variable
        guard let itemsList = context[items] as? [Any] else {
            throw WorkflowError.executionFailed("Invalid loop items: \(items)")
        }

        var results: [[String: Any]] = []

        for (index, item) in itemsList.enumerated() {
            var loopContext = context
            loopContext["loop_item"] = item
            loopContext["loop_index"] = index

            // Execute steps for this iteration
            for stepID in steps {
                // Would need to look up and execute these steps
                // This is simplified for brevity
            }

            results.append(loopContext)
        }

        return ["loop_results": results]
    }

    // MARK: - Helper Methods

    private func loadWorkflows() {
        let request = Workflow.fetchRequest()
        workflows = (try? context.fetch(request)) ?? []

        // Schedule enabled workflows
        for workflow in workflows where workflow.isEnabled {
            if let trigger = workflow.trigger?.configuration,
               let cronExpr = trigger.schedule?.cronExpression {
                schedulerService.schedule(workflow: workflow, cron: cronExpr)
            }
        }
    }

    private func setupEventListeners() {
        // Listen for system events to trigger workflows
        NotificationCenter.default.publisher(for: .messageSent)
            .sink { [weak self] notification in
                Task { @MainActor in
                    await self?.handleEvent("message_sent", data: notification.userInfo)
                }
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ eventType: String, data: [AnyHashable: Any]?) async {
        let eventWorkflows = workflows.filter { workflow in
            guard workflow.isEnabled,
                  let trigger = workflow.trigger,
                  trigger.type == TriggerType.event.rawValue,
                  let eventConfig = trigger.configuration?.event else {
                return false
            }

            return eventConfig.eventType == eventType
        }

        for workflow in eventWorkflows {
            do {
                _ = try await executeWorkflow(workflow, context: data as? [String: Any])
            } catch {
                print("Failed to execute workflow \(workflow.name): \(error)")
            }
        }
    }

    private func resolveVariables(_ text: String, context: [String: Any]) -> String {
        var resolved = text

        for (key, value) in context {
            let placeholder = "{{\(key)}}"
            if let stringValue = value as? String {
                resolved = resolved.replacingOccurrences(of: placeholder, with: stringValue)
            } else {
                resolved = resolved.replacingOccurrences(of: placeholder, with: "\(value)")
            }
        }

        return resolved
    }

    private func evaluateCondition(_ condition: String, context: [String: Any]) -> Bool {
        // Simple condition evaluation
        // In production, use a proper expression evaluator
        let resolvedCondition = resolveVariables(condition, context: context)

        // Basic comparison support
        if resolvedCondition.contains("==") {
            let parts = resolvedCondition.components(separatedBy: "==").map { $0.trimmingCharacters(in: .whitespaces) }
            return parts.count == 2 && parts[0] == parts[1]
        }

        return !resolvedCondition.isEmpty
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let workflowNotification = Notification.Name("workflowNotification")
    public static let messageSent = Notification.Name("messageSent")
}

public enum WorkflowError: LocalizedError {
    case workflowDisabled
    case invalidStep(String)
    case executionFailed(String)
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .workflowDisabled:
            return "Workflow is disabled"
        case .invalidStep(let message):
            return "Invalid step: \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        }
    }
}
```


#### Workflow Scheduler

```swift
// WorkflowScheduler.swift
import Foundation

public final class WorkflowScheduler {
    private var scheduledWorkflows: [UUID: Timer] = [:]

    public func schedule(workflow: Workflow, cron: String) {
        // Parse cron expression and calculate next execution time
        guard let nextExecution = calculateNextExecution(from: cron) else {
            print("Invalid cron expression: \(cron)")
            return
        }

        let timeInterval = nextExecution.timeIntervalSinceNow

        let timer = Timer.scheduledTimer(withTimeInterval: max(timeInterval, 0), repeats: false) { [weak self] _ in
            Task { @MainActor in
                do {
                    _ = try await WorkflowEngine.shared.executeWorkflow(workflow)

                    // Reschedule
                    self?.schedule(workflow: workflow, cron: cron)
                } catch {
                    print("Scheduled workflow execution failed: \(error)")
                }
            }
        }

        scheduledWorkflows[workflow.id] = timer
    }

    public func unschedule(workflow: Workflow) {
        scheduledWorkflows[workflow.id]?.invalidate()
        scheduledWorkflows.removeValue(forKey: workflow.id)
    }

    private func calculateNextExecution(from cron: String) -> Date? {
        // Simple cron parser
        // Format: "minute hour day month dayOfWeek"
        // Example: "0 9 * * *" = 9 AM daily

        let components = cron.components(separatedBy: " ")
        guard components.count == 5 else { return nil }

        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())

        // Parse minute
        if components[0] != "*", let minute = Int(components[0]) {
            dateComponents.minute = minute
        }

        // Parse hour
        if components[1] != "*", let hour = Int(components[1]) {
            dateComponents.hour = hour
        }

        // Create next execution date
        guard var nextDate = calendar.date(from: dateComponents) else { return nil }

        // If calculated date is in the past, add appropriate interval
        if nextDate < Date() {
            if components[2] == "*" && components[3] == "*" {
                // Daily - add 1 day
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            } else if components[3] == "*" {
                // Monthly - add 1 month
                nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
            }
        }

        return nextDate
    }
}
```

#### Workflow Builder UI

```swift
// WorkflowBuilderView.swift
import SwiftUI

public struct WorkflowBuilderView: View {
    @StateObject private var workflowEngine = WorkflowEngine.shared
    @State private var selectedWorkflow: Workflow?
    @State private var showingNewWorkflow = false

    public var body: some View {
        HSplitView {
            // Workflow List
            List(selection: $selectedWorkflow) {
                ForEach(workflowEngine.workflows, id: \.id) { workflow in
                    WorkflowListItemView(workflow: workflow)
                        .tag(workflow)
                }
            }
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem {
                    Button(action: { showingNewWorkflow = true }) {
                        Image(systemName: "plus")
                    }
                }
            }

            // Workflow Details/Editor
            if let workflow = selectedWorkflow {
                WorkflowEditorView(workflow: workflow)
            } else {
                Text("Select a workflow")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingNewWorkflow) {
            NewWorkflowView()
        }
    }
}

struct WorkflowListItemView: View {
    let workflow: Workflow

    var body: some View {
        HStack {
            Image(systemName: workflow.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(workflow.isEnabled ? .green : .gray)

            VStack(alignment: .leading) {
                Text(workflow.name)
                    .font(.headline)

                if let lastRun = workflow.lastRunAt {
                    Text("Last run: \(lastRun.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(workflow.executionCount) runs")
                    .font(.caption)

                if workflow.failureCount > 0 {
                    Text("\(workflow.failureCount) failures")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct WorkflowEditorView: View {
    let workflow: Workflow

    @StateObject private var workflowEngine = WorkflowEngine.shared
    @State private var steps: [WorkflowStep] = []
    @State private var showingAddStep = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(workflow.name)
                        .font(.title)

                    if let description = workflow.descriptionText {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Toggle("Enabled", isOn: Binding(
                    get: { workflow.isEnabled },
                    set: { enabled in
                        try? workflowEngine.setEnabled(enabled, for: workflow)
                    }
                ))

                Button("Run Now") {
                    Task {
                        _ = try? await workflowEngine.executeWorkflow(workflow)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.gray.opacity(0.05))

            Divider()

            // Trigger Configuration
            if let trigger = workflow.trigger {
                GroupBox("Trigger") {
                    TriggerConfigView(trigger: trigger)
                }
                .padding()
            }

            Divider()

            // Steps List
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Steps")
                            .font(.headline)

                        Spacer()

                        Button(action: { showingAddStep = true }) {
                            Label("Add Step", systemImage: "plus")
                        }
                    }

                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        WorkflowStepView(step: step, index: index)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            steps = workflow.stepsArray
        }
        .sheet(isPresented: $showingAddStep) {
            AddWorkflowStepView(workflow: workflow) { newStep in
                steps.append(newStep)
            }
        }
    }
}

struct TriggerConfigView: View {
    let trigger: WorkflowTrigger

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type: \(trigger.type.capitalized)")
                .font(.subheadline)

            if let config = trigger.configuration {
                if let schedule = config.schedule {
                    Text("Schedule: \(schedule.cronExpression)")
                } else if let event = config.event {
                    Text("Event: \(event.eventType)")
                } else if let keyword = config.keyword {
                    Text("Keywords: \(keyword.keywords.joined(separator: ", "))")
                }
            }
        }
    }
}

struct WorkflowStepView: View {
    let step: WorkflowStep
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            Text("\(index + 1)")
                .font(.headline)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.2))
                .clipShape(Circle())

            // Step details
            VStack(alignment: .leading, spacing: 4) {
                Text(step.name)
                    .font(.headline)

                if let action = step.action {
                    Text(actionDescription(action))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if step.continueOnError {
                    Label("Continue on error", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }

    private func actionDescription(_ action: WorkflowAction) -> String {
        switch action {
        case .aiQuery(let prompt, _):
            return "AI Query: \(prompt.prefix(50))..."
        case .createMemory(let type, _):
            return "Create Memory: \(type)"
        case .runMCPTool(let server, let tool, _):
            return "Run MCP Tool: \(server)/\(tool)"
        case .sendNotification(let title, _, _):
            return "Send Notification: \(title)"
        case .httpRequest(let url, let method, _, _):
            return "HTTP \(method): \(url)"
        case .executeScript(let language, _):
            return "Execute \(language) script"
        case .delay(let seconds):
            return "Delay: \(seconds)s"
        case .setVariable(let name, _):
            return "Set Variable: \(name)"
        case .conditional:
            return "Conditional Branch"
        case .loop:
            return "Loop"
        }
    }
}

struct AddWorkflowStepView: View {
    let workflow: Workflow
    let onAdd: (WorkflowStep) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stepName = ""
    @State private var selectedActionType = "aiQuery"

    var body: some View {
        VStack {
            Text("Add Workflow Step")
                .font(.title)

            Form {
                TextField("Step Name", text: $stepName)
                    .textFieldStyle(.roundedBorder)

                Picker("Action Type", selection: $selectedActionType) {
                    Text("AI Query").tag("aiQuery")
                    Text("Create Memory").tag("createMemory")
                    Text("Run MCP Tool").tag("runMCPTool")
                    Text("Send Notification").tag("sendNotification")
                    Text("HTTP Request").tag("httpRequest")
                    Text("Delay").tag("delay")
                }
            }
            .padding()

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Button("Add") {
                    addStep()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(stepName.isEmpty)
            }
        }
        .frame(width: 400, height: 300)
        .padding()
    }

    private func addStep() {
        let action: WorkflowAction

        switch selectedActionType {
        case "aiQuery":
            action = .aiQuery(prompt: "Your prompt here", model: nil)
        case "createMemory":
            action = .createMemory(type: "context", content: "Memory content")
        case "runMCPTool":
            action = .runMCPTool(server: "server", tool: "tool", arguments: [:])
        case "sendNotification":
            action = .sendNotification(title: "Title", body: "Body", target: nil)
        case "httpRequest":
            action = .httpRequest(url: "https://api.example.com", method: "GET", headers: nil, body: nil)
        case "delay":
            action = .delay(seconds: 1.0)
        default:
            action = .delay(seconds: 0)
        }

        if let step = try? WorkflowEngine.shared.addStep(
            to: workflow,
            name: stepName,
            action: action
        ) {
            onAdd(step)
        }
    }
}
```

### Success Metrics

- **Adoption:** 25% of users create at least one workflow
- **Execution Success Rate:** 95% of workflow executions succeed
- **Performance:** < 100ms overhead per step
- **Complexity:** Support workflows with 50+ steps
- **Reliability:** 99.5% uptime for scheduler

### Cost Estimate

- **AI Queries:** Variable based on workflow usage
- **HTTP Requests:** Minimal (user's external services)
- **Storage:** Negligible (local Core Data)
- **Monthly estimate:** $10-50 depending on AI query volume in workflows

---

## 2.5 Plugin System Foundation

**Implementation:** 5 weeks | **Priority:** MEDIUM | **Risk:** HIGH
**Dependencies:** Swift Package Manager, sandboxing framework

### Overview

Build a secure plugin system that allows third-party developers to extend Nexus with custom features, commands, UI components, and data providers. Includes a plugin SDK, marketplace, and sandboxed execution environment.

### Data Models

#### Core Data Entities

```swift
// Plugin+CoreDataClass.swift
import Foundation
import CoreData

@objc(Plugin)
public class Plugin: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var bundleIdentifier: String
    @NSManaged public var name: String
    @NSManaged public var version: String
    @NSManaged public var author: String
    @NSManaged public var descriptionText: String
    @NSManaged public var isEnabled: Bool
    @NSManaged public var isVerified: Bool
    @NSManaged public var installedAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var packageURL: String?

    // JSON-encoded data
    @NSManaged private var capabilitiesJSON: Data?
    @NSManaged private var permissionsJSON: Data?
    @NSManaged private var metadataJSON: Data?

    public var capabilities: [PluginCapability]? {
        get {
            guard let data = capabilitiesJSON else { return nil }
            return try? JSONDecoder().decode([PluginCapability].self, from: data)
        }
        set {
            capabilitiesJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var permissions: [PluginPermission]? {
        get {
            guard let data = permissionsJSON else { return nil }
            return try? JSONDecoder().decode([PluginPermission].self, from: data)
        }
        set {
            permissionsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var metadata: PluginMetadata? {
        get {
            guard let data = metadataJSON else { return nil }
            return try? JSONDecoder().decode(PluginMetadata.self, from: data)
        }
        set {
            metadataJSON = try? JSONEncoder().encode(newValue)
        }
    }
}
```

#### Swift Structs and Protocols

```swift
// PluginTypes.swift
import Foundation

/// Main protocol that all plugins must implement
public protocol NexusPlugin {
    var metadata: PluginMetadata { get }
    var capabilities: [PluginCapability] { get }

    func initialize(context: PluginContext) async throws
    func execute(action: PluginAction) async throws -> PluginResult
    func cleanup() async
}

public struct PluginMetadata: Codable {
    public let bundleIdentifier: String
    public let name: String
    public let version: String
    public let author: String
    public let description: String
    public let homepage: URL?
    public let supportEmail: String?
    public let minimumNexusVersion: String
    public let permissions: [PluginPermission]
    public let requiredAPIs: [RequiredAPI]

    public init(
        bundleIdentifier: String,
        name: String,
        version: String,
        author: String,
        description: String,
        homepage: URL? = nil,
        supportEmail: String? = nil,
        minimumNexusVersion: String,
        permissions: [PluginPermission],
        requiredAPIs: [RequiredAPI] = []
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.version = version
        self.author = author
        self.description = description
        self.homepage = homepage
        self.supportEmail = supportEmail
        self.minimumNexusVersion = minimumNexusVersion
        self.permissions = permissions
        self.requiredAPIs = requiredAPIs
    }
}

public enum PluginCapability: String, Codable {
    case conversationInterceptor = "conversation_interceptor"
    case customCommand = "custom_command"
    case uiComponent = "ui_component"
    case dataProvider = "data_provider"
    case modelProvider = "model_provider"
    case workflowAction = "workflow_action"
    case menuItem = "menu_item"
    case settingsPanel = "settings_panel"
}

public enum PluginPermission: String, Codable {
    case readConversations = "read_conversations"
    case writeConversations = "write_conversations"
    case readMemories = "read_memories"
    case writeMemories = "write_memories"
    case networkAccess = "network_access"
    case fileSystemRead = "file_system_read"
    case fileSystemWrite = "file_system_write"
    case executeShellCommands = "execute_shell_commands"
    case accessCredentials = "access_credentials"
}

public struct RequiredAPI: Codable {
    public let name: String
    public let minVersion: String

    public init(name: String, minVersion: String) {
        self.name = name
        self.minVersion = minVersion
    }
}

public struct PluginContext {
    public let nexusVersion: String
    public let userID: UUID
    public let dataDirectory: URL
    public let apiRegistry: PluginAPIRegistry

    public init(nexusVersion: String, userID: UUID, dataDirectory: URL, apiRegistry: PluginAPIRegistry) {
        self.nexusVersion = nexusVersion
        self.userID = userID
        self.dataDirectory = dataDirectory
        self.apiRegistry = apiRegistry
    }
}

public enum PluginAction {
    case interceptConversation(message: String, context: [String: Any])
    case executeCommand(command: String, arguments: [String])
    case renderUI(context: [String: Any])
    case provideData(query: String)
    case processWorkflowStep(step: [String: Any])
}

public struct PluginResult {
    public let success: Bool
    public let data: [String: Any]?
    public let error: String?

    public init(success: Bool, data: [String: Any]? = nil, error: String? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
}

/// Plugin API Registry - provides safe access to Nexus APIs
public protocol PluginAPIRegistry {
    func getConversationAPI() -> ConversationAPI?
    func getMemoryAPI() -> MemoryAPI?
    func getAIAPI() -> AIAPI?
    func getStorageAPI() -> StorageAPI?
}

// Plugin-safe API interfaces
public protocol ConversationAPI {
    func listConversations() async throws -> [ConversationSummary]
    func getConversation(id: UUID) async throws -> ConversationDetail?
    func sendMessage(_ message: String, to conversationID: UUID) async throws
}

public protocol MemoryAPI {
    func searchMemories(query: String) async throws -> [MemorySummary]
    func createMemory(content: String, type: String) async throws -> UUID
}

public protocol AIAPI {
    func sendQuery(_ prompt: String, model: String?) async throws -> String
    func generateEmbedding(_ text: String) async throws -> [Float]
}

public protocol StorageAPI {
    func save(data: Data, key: String) async throws
    func load(key: String) async throws -> Data?
    func delete(key: String) async throws
}

public struct ConversationSummary: Codable {
    public let id: UUID
    public let title: String
    public let messageCount: Int
    public let createdAt: Date
}

public struct ConversationDetail: Codable {
    public let id: UUID
    public let title: String
    public let messages: [MessageSummary]
}

public struct MessageSummary: Codable {
    public let id: UUID
    public let content: String
    public let role: String
    public let timestamp: Date
}

public struct MemorySummary: Codable {
    public let id: UUID
    public let content: String
    public let type: String
    public let createdAt: Date
}
```

### Core Implementation

#### Plugin Manager

```swift
// PluginManager.swift
import Foundation
import CoreData

@MainActor
public final class PluginManager: ObservableObject {
    public static let shared = PluginManager()

    @Published public private(set) var plugins: [Plugin] = []
    @Published public private(set) var loadedPlugins: [UUID: any NexusPlugin] = [:]
    @Published public private(set) var isLoading = false

    private let context: NSManagedObjectContext
    private let sandboxManager: PluginSandboxManager
    private let apiRegistry: PluginAPIRegistryImpl

    private init() {
        self.context = CoreDataManager.shared.viewContext
        self.sandboxManager = PluginSandboxManager()
        self.apiRegistry = PluginAPIRegistryImpl()

        loadInstalledPlugins()
    }

    // MARK: - Plugin Lifecycle

    /// Installs a plugin from a package URL
    public func installPlugin(from packageURL: URL) async throws -> Plugin {
        isLoading = true
        defer { isLoading = false }

        // Download and validate package
        let packageData = try await downloadPackage(from: packageURL)
        let manifest = try validatePackage(packageData)

        // Check permissions
        let approved = try await requestPermissions(manifest.permissions)
        guard approved else {
            throw PluginError.permissionsDenied
        }

        // Install plugin
        let plugin = Plugin(context: context)
        plugin.id = UUID()
        plugin.bundleIdentifier = manifest.bundleIdentifier
        plugin.name = manifest.name
        plugin.version = manifest.version
        plugin.author = manifest.author
        plugin.descriptionText = manifest.description
        plugin.isEnabled = true
        plugin.isVerified = false  // Would be true for marketplace plugins
        plugin.installedAt = Date()
        plugin.updatedAt = Date()
        plugin.packageURL = packageURL.absoluteString
        plugin.capabilities = [.customCommand]  // Would be parsed from manifest
        plugin.permissions = manifest.permissions
        plugin.metadata = manifest

        try context.save()
        plugins.append(plugin)

        // Load plugin
        try await loadPlugin(plugin)

        return plugin
    }

    /// Uninstalls a plugin
    public func uninstallPlugin(_ plugin: Plugin) async throws {
        // Cleanup
        if let loaded = loadedPlugins[plugin.id] {
            await loaded.cleanup()
        }

        loadedPlugins.removeValue(forKey: plugin.id)
        context.delete(plugin)
        try context.save()

        plugins.removeAll { $0.id == plugin.id }

        // Delete plugin files
        // Implementation would delete from plugin directory
    }

    /// Enables or disables a plugin
    public func setEnabled(_ enabled: Bool, for plugin: Plugin) async throws {
        plugin.isEnabled = enabled
        try context.save()

        if enabled {
            try await loadPlugin(plugin)
        } else {
            if let loaded = loadedPlugins[plugin.id] {
                await loaded.cleanup()
            }
            loadedPlugins.removeValue(forKey: plugin.id)
        }
    }

    /// Updates a plugin to a new version
    public func updatePlugin(_ plugin: Plugin, to newVersion: URL) async throws {
        // Download new version
        let packageData = try await downloadPackage(from: newVersion)
        let manifest = try validatePackage(packageData)

        // Verify it's the same plugin
        guard manifest.bundleIdentifier == plugin.bundleIdentifier else {
            throw PluginError.invalidPackage("Bundle identifier mismatch")
        }

        // Unload current version
        if let loaded = loadedPlugins[plugin.id] {
            await loaded.cleanup()
        }
        loadedPlugins.removeValue(forKey: plugin.id)

        // Update metadata
        plugin.version = manifest.version
        plugin.updatedAt = Date()
        plugin.metadata = manifest

        try context.save()

        // Load new version
        try await loadPlugin(plugin)
    }

    // MARK: - Plugin Execution

    /// Executes a plugin action
    public func executePlugin(
        _ pluginID: UUID,
        action: PluginAction
    ) async throws -> PluginResult {
        guard let plugin = loadedPlugins[pluginID] else {
            throw PluginError.pluginNotLoaded
        }

        // Execute in sandbox
        return try await sandboxManager.execute {
            try await plugin.execute(action: action)
        }
    }

    /// Gets all plugins with a specific capability
    public func getPlugins(with capability: PluginCapability) -> [Plugin] {
        return plugins.filter { plugin in
            plugin.capabilities?.contains(capability) ?? false
        }
    }

    // MARK: - Private Methods

    private func loadInstalledPlugins() {
        let request = Plugin.fetchRequest()
        plugins = (try? context.fetch(request)) ?? []

        // Load enabled plugins
        Task {
            for plugin in plugins where plugin.isEnabled {
                try? await loadPlugin(plugin)
            }
        }
    }

    private func loadPlugin(_ plugin: Plugin) async throws {
        // In a real implementation, this would:
        // 1. Load the plugin's Swift package
        // 2. Instantiate the plugin class
        // 3. Call initialize()

        // For demonstration, we'll create a mock plugin
        // let pluginInstance = try await instantiatePlugin(plugin)

        let pluginContext = PluginContext(
            nexusVersion: "1.0.0",
            userID: UUID(),
            dataDirectory: getPluginDataDirectory(for: plugin),
            apiRegistry: apiRegistry
        )

        // try await pluginInstance.initialize(context: pluginContext)
        // loadedPlugins[plugin.id] = pluginInstance
    }

    private func downloadPackage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PluginError.downloadFailed
        }

        return data
    }

    private func validatePackage(_ packageData: Data) throws -> PluginMetadata {
        // In a real implementation:
        // 1. Verify package signature
        // 2. Extract manifest
        // 3. Validate manifest structure
        // 4. Check compatibility

        // For now, return a mock manifest
        throw PluginError.notImplemented
    }

    private func requestPermissions(_ permissions: [PluginPermission]) async throws -> Bool {
        // Show permission dialog to user
        // For now, auto-approve
        return true
    }

    private func getPluginDataDirectory(for plugin: Plugin) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let pluginDir = appSupport.appendingPathComponent("Nexus/Plugins/\(plugin.bundleIdentifier)")

        try? FileManager.default.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        return pluginDir
    }
}

public enum PluginError: LocalizedError {
    case downloadFailed
    case invalidPackage(String)
    case permissionsDenied
    case pluginNotLoaded
    case notImplemented
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to download plugin package"
        case .invalidPackage(let reason):
            return "Invalid plugin package: \(reason)"
        case .permissionsDenied:
            return "Plugin permissions were denied"
        case .pluginNotLoaded:
            return "Plugin is not loaded"
        case .notImplemented:
            return "Feature not yet implemented"
        case .executionFailed(let reason):
            return "Plugin execution failed: \(reason)"
        }
    }
}
```


#### Plugin Sandbox Manager

```swift
// PluginSandboxManager.swift
import Foundation

public final class PluginSandboxManager {
    private let executionQueue: DispatchQueue
    private let timeout: TimeInterval = 30.0  // 30 second timeout for plugin operations

    public init() {
        self.executionQueue = DispatchQueue(label: "com.nexus.plugin.sandbox", qos: .userInitiated)
    }

    /// Executes a plugin operation in a sandboxed environment
    public func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        // In a production implementation, this would:
        // 1. Create isolated process/environment
        // 2. Apply resource limits (CPU, memory, I/O)
        // 3. Monitor execution
        // 4. Enforce timeout
        // 5. Clean up resources

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
                throw PluginError.executionFailed("Operation timed out")
            }

            // Return first result (either completion or timeout)
            guard let result = try await group.next() else {
                throw PluginError.executionFailed("No result from plugin")
            }

            // Cancel remaining tasks
            group.cancelAll()

            return result
        }
    }

    /// Validates that a plugin has permission to perform an operation
    public func checkPermission(_ permission: PluginPermission, for plugin: Plugin) -> Bool {
        guard let permissions = plugin.permissions else { return false }
        return permissions.contains(permission)
    }

    /// Applies resource limits to a plugin
    public func applyResourceLimits() {
        // Would implement CPU, memory, and I/O throttling
        // Using platform-specific APIs (e.g., libdispatch, XPC)
    }
}
```

#### Plugin API Registry Implementation

```swift
// PluginAPIRegistryImpl.swift
import Foundation

public final class PluginAPIRegistryImpl: PluginAPIRegistry {
    public init() {}

    public func getConversationAPI() -> ConversationAPI? {
        return ConversationAPIImpl()
    }

    public func getMemoryAPI() -> MemoryAPI? {
        return MemoryAPIImpl()
    }

    public func getAIAPI() -> AIAPI? {
        return AIAPIImpl()
    }

    public func getStorageAPI() -> StorageAPI? {
        return StorageAPIImpl()
    }
}

// Safe API implementations that plugins can use
private final class ConversationAPIImpl: ConversationAPI {
    func listConversations() async throws -> [ConversationSummary] {
        let manager = ConversationManager.shared
        return manager.conversations.map { conv in
            ConversationSummary(
                id: conv.id,
                title: conv.title ?? "Untitled",
                messageCount: conv.messagesArray.count,
                createdAt: conv.createdAt
            )
        }
    }

    func getConversation(id: UUID) async throws -> ConversationDetail? {
        let manager = ConversationManager.shared
        guard let conv = manager.conversations.first(where: { $0.id == id }) else {
            return nil
        }

        let messages = conv.messagesArray.map { msg in
            MessageSummary(
                id: msg.id,
                content: msg.content,
                role: msg.role,
                timestamp: msg.timestamp
            )
        }

        return ConversationDetail(
            id: conv.id,
            title: conv.title ?? "Untitled",
            messages: messages
        )
    }

    func sendMessage(_ message: String, to conversationID: UUID) async throws {
        // Would delegate to ConversationManager
        // With appropriate permission checks
    }
}

private final class MemoryAPIImpl: MemoryAPI {
    func searchMemories(query: String) async throws -> [MemorySummary] {
        // Would delegate to MemoryManager
        return []
    }

    func createMemory(content: String, type: String) async throws -> UUID {
        // Would delegate to MemoryManager
        return UUID()
    }
}

private final class AIAPIImpl: AIAPI {
    func sendQuery(_ prompt: String, model: String?) async throws -> String {
        // Would delegate to AIRouter
        return ""
    }

    func generateEmbedding(_ text: String) async throws -> [Float] {
        // Would delegate to AIRouter
        return []
    }
}

private final class StorageAPIImpl: StorageAPI {
    private let baseDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseDirectory = appSupport.appendingPathComponent("Nexus/PluginStorage")
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func save(data: Data, key: String) async throws {
        let fileURL = baseDirectory.appendingPathComponent(key)
        try data.write(to: fileURL)
    }

    func load(key: String) async throws -> Data? {
        let fileURL = baseDirectory.appendingPathComponent(key)
        return try? Data(contentsOf: fileURL)
    }

    func delete(key: String) async throws {
        let fileURL = baseDirectory.appendingPathComponent(key)
        try FileManager.default.removeItem(at: fileURL)
    }
}
```

### Example Plugin Implementation

```swift
// ExamplePlugin.swift
// This would be in a separate Swift package

import Foundation
import NexusPluginSDK

public final class ExamplePlugin: NexusPlugin {
    public var metadata: PluginMetadata {
        return PluginMetadata(
            bundleIdentifier: "com.example.nexus.sampleplugin",
            name: "Example Plugin",
            version: "1.0.0",
            author: "Example Developer",
            description: "A sample plugin that demonstrates the plugin system",
            homepage: URL(string: "https://example.com/plugin"),
            supportEmail: "support@example.com",
            minimumNexusVersion: "1.0.0",
            permissions: [.readConversations, .networkAccess],
            requiredAPIs: [
                RequiredAPI(name: "ConversationAPI", minVersion: "1.0")
            ]
        )
    }

    public var capabilities: [PluginCapability] {
        return [.customCommand, .conversationInterceptor]
    }

    private var context: PluginContext?

    public init() {}

    public func initialize(context: PluginContext) async throws {
        self.context = context
        print("Example plugin initialized for user: \(context.userID)")
    }

    public func execute(action: PluginAction) async throws -> PluginResult {
        switch action {
        case .executeCommand(let command, let arguments):
            return try await handleCommand(command, arguments: arguments)

        case .interceptConversation(let message, let context):
            return try await interceptMessage(message, context: context)

        default:
            return PluginResult(success: false, error: "Unsupported action")
        }
    }

    public func cleanup() async {
        print("Example plugin cleaning up")
    }

    // MARK: - Private Methods

    private func handleCommand(_ command: String, arguments: [String]) async throws -> PluginResult {
        guard command == "/example" else {
            return PluginResult(success: false, error: "Unknown command")
        }

        let response = "Example plugin executed with args: \(arguments.joined(separator: ", "))"

        return PluginResult(
            success: true,
            data: ["response": response]
        )
    }

    private func interceptMessage(_ message: String, context: [String: Any]) async throws -> PluginResult {
        // Example: Add metadata to every message
        var enrichedContext = context
        enrichedContext["plugin_processed"] = true
        enrichedContext["plugin_name"] = metadata.name

        return PluginResult(
            success: true,
            data: enrichedContext
        )
    }
}
```

### Success Metrics

- **Plugin Ecosystem:** 50+ community plugins within 12 months
- **Safety:** Zero security incidents from plugins
- **Performance:** < 50ms overhead for plugin operations
- **Adoption:** 15% of users install at least one plugin
- **Developer Experience:** Plugin SDK documentation and 10+ example plugins

### Cost Estimate

- **Infrastructure:** Minimal (plugin marketplace hosting)
- **Review Process:** Manual review for verified plugins (staff time)
- **Storage:** ~100GB for plugin packages (S3: ~$2.30/month)
- **Monthly estimate:** $10-30 for infrastructure

---

## Phase 2 Summary

**Total Implementation Time:** 3-4 months (Weeks 9-24)
**Total Budget:** $120K-180K
**Team Size:** 3-4 developers

### Features Delivered

1. ✅ Vision & Image Analysis (4 weeks)
   - GPT-4 Vision integration
   - DALL-E 3 image generation
   - OCR and object detection
   - Image editing capabilities

2. ✅ Advanced Voice Capabilities (4 weeks)
   - Multi-language speech recognition
   - Custom voice profiles
   - Continuous listening mode
   - Wake word detection

3. ✅ Knowledge Graph Enhancements (4 weeks)
   - Auto-entity extraction
   - Graph query language
   - Temporal versioning
   - Path finding algorithms

4. ✅ Workflow Automation Engine (5 weeks)
   - Visual workflow builder
   - Multiple trigger types
   - 10+ built-in actions
   - Scheduled execution

5. ✅ Plugin System Foundation (5 weeks)
   - Plugin SDK
   - Sandboxed execution
   - Permission system
   - Plugin marketplace foundation

### Key Achievements

- **Multimodal AI:** Full integration with vision and voice capabilities
- **Extensibility:** Robust plugin system for community contributions
- **Automation:** Powerful workflow engine for repetitive tasks
- **Knowledge Management:** Advanced graph-based knowledge organization

### Risks Mitigated

- Security hardening for plugin sandbox
- Comprehensive testing for voice recognition across languages
- Performance optimization for large knowledge graphs
- Workflow execution monitoring and error recovery

### Next Steps

Phase 3 will focus on platform expansion with iOS companion app, collaboration features, developer integrations, enhanced context management, and advanced security features.

---

**Document Status:** Complete
**Last Updated:** November 2025
**Version:** 1.0

